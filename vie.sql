-- ===========================================================================
--  vie.sql — le Jeu de la vie (et toute la famille « B/S ») en SQL pur.
--
--  Pas une ligne de code impératif : la grille est une chaîne de caractères,
--  chaque génération est une ligne d'une requête récursive (WITH RECURSIVE),
--  le motif RLE est analysé par une autre requête récursive, et le bilan
--  (cycles, extinction, courbe de population) est une requête comme une autre.
--
--  Entrée : une table temporaire `param` (voir vie.sh) :
--    regle    'B3/S23' ou ancienne notation '23/3' ('' = celle du motif)
--    gens     nombre de générations
--    w, h     taille de la grille
--    tore     1 : les bords se rejoignent, 0 : dehors = mort
--    densite  proportion de cellules vivantes si le motif est vide (soupe)
--    anim     1 : afficher chaque génération, 0 : seulement le bilan
--    motif    texte RLE (éventuellement avec en-tête « x = .., rule = .. »)
--  Demande SQLite ≥ 3.44 (group_concat(... ORDER BY ...)).
-- ===========================================================================

-- --------------------------------------------------------------- la grille
-- Toutes les cases 0 .. w·h-1 et leurs coordonnées.
CREATE TEMP TABLE cases AS
WITH RECURSIVE n(i) AS (
  SELECT 0
  UNION ALL
  SELECT i + 1 FROM n, param WHERE i + 1 < w * h
)
SELECT i, i % (SELECT w FROM param) AS x, i / (SELECT w FROM param) AS y FROM n;

-- Les 8 voisins de chaque case (repliés sur le tore, ou coupés aux bords).
CREATE TEMP TABLE voisins AS
SELECT c.i AS i, ((c.y + dy + p.h) % p.h) * p.w + ((c.x + dx + p.w) % p.w) AS j
FROM cases c, param p,
     (SELECT -1 AS dx UNION ALL SELECT 0 UNION ALL SELECT 1) AS ddx,
     (SELECT -1 AS dy UNION ALL SELECT 0 UNION ALL SELECT 1) AS ddy
WHERE (dx <> 0 OR dy <> 0)
  AND (p.tore OR (c.x + dx BETWEEN 0 AND p.w - 1 AND c.y + dy BETWEEN 0 AND p.h - 1));
CREATE INDEX voisins_i ON voisins (i);

-- ------------------------------------------------------------ lire le RLE
-- Découpage en lignes, pour écarter les commentaires (#...) et l'en-tête (x = ...).
CREATE TEMP TABLE lignes AS
WITH RECURSIVE l(num, ligne, reste) AS (
  SELECT 0, NULL, replace((SELECT motif FROM param), char(13), '') || char(10)
  UNION ALL
  SELECT num + 1,
         trim(substr(reste, 1, instr(reste, char(10)) - 1)),
         substr(reste, instr(reste, char(10)) + 1)
  FROM l WHERE reste <> ''
)
SELECT num, ligne FROM l WHERE num > 0;

CREATE TEMP TABLE corps AS
SELECT coalesce(group_concat(replace(ligne, ' ', ''), '' ORDER BY num), '') AS rle
FROM lignes WHERE ligne NOT LIKE '#%' AND ligne NOT LIKE 'x%=%';

-- La règle : celle demandée, sinon celle de l'en-tête « rule = ... », sinon Conway.
CREATE TEMP TABLE regle AS
WITH entete(t) AS (
  SELECT trim(replace(substr(ligne, instr(lower(ligne), 'rule') + 4), '=', ''))
  FROM lignes WHERE ligne LIKE 'x%=%' AND instr(lower(ligne), 'rule') > 0
),
choix(t) AS (
  SELECT upper(replace(coalesce(nullif((SELECT regle FROM param), ''), (SELECT t FROM entete), 'B3/S23'), ' ', ''))
)
SELECT t AS texte,
       CASE WHEN t LIKE 'B%' THEN substr(t, 2, instr(t, '/') - 2) ELSE substr(t, instr(t, '/') + 1) END AS naissance,
       CASE WHEN t LIKE 'B%' THEN substr(t, instr(t, '/S') + 2)    ELSE substr(t, 1, instr(t, '/') - 1) END AS survie
FROM choix;

-- Automate qui lit le RLE caractère par caractère. Chaque étape garde la
-- position (x, y), le nombre en cours de lecture, et émet éventuellement
-- une « série » de cellules vivantes (sx, sy, sn).
CREATE TEMP TABLE series AS
WITH RECURSIVE a(pos, c, x, y, nombre, sx, sy, sn) AS (
  SELECT 1, substr((SELECT rle FROM corps), 1, 1), 0, 0, '', NULL, NULL, NULL
  UNION ALL
  SELECT pos + 1,
         substr((SELECT rle FROM corps), pos + 1, 1),
         CASE WHEN c = '$' THEN 0
              WHEN c GLOB '[A-Za-z.]' THEN x + coalesce(nullif(nombre, ''), 1)
              ELSE x END,
         CASE WHEN c = '$' THEN y + coalesce(nullif(nombre, ''), 1) ELSE y END,
         CASE WHEN c GLOB '[0-9]' THEN nombre || c ELSE '' END,
         CASE WHEN c GLOB '[A-Za-z]' AND c NOT IN ('b', 'B') THEN x END,
         CASE WHEN c GLOB '[A-Za-z]' AND c NOT IN ('b', 'B') THEN y END,
         CASE WHEN c GLOB '[A-Za-z]' AND c NOT IN ('b', 'B') THEN coalesce(nullif(nombre, ''), 1) END
  FROM a
  WHERE c <> '!' AND c <> ''
)
SELECT sx, sy, CAST(sn AS INTEGER) AS sn FROM a WHERE sn IS NOT NULL;

-- Séries -> cellules, puis centrage du motif dans la grille.
CREATE TEMP TABLE cellules AS
SELECT s.sx + k.i AS x, s.sy AS y FROM series s JOIN cases k ON k.i < s.sn;

CREATE TEMP TABLE depart AS
WITH dim AS (
  SELECT (p.w - coalesce(max(x) + 1, 0)) / 2 AS ox, (p.h - coalesce(max(y) + 1, 0)) / 2 AS oy
  FROM cellules, param p
),
places AS (
  SELECT (y + oy) * (SELECT w FROM param) + (x + ox) AS i
  FROM cellules, dim, param p
  WHERE x + ox BETWEEN 0 AND p.w - 1 AND y + oy BETWEEN 0 AND p.h - 1
)
SELECT group_concat(
         CASE WHEN (SELECT count(*) FROM cellules) = 0
              THEN CASE WHEN abs(random()) % 1000000 < (SELECT densite FROM param) * 1000000 THEN '#' ELSE '.' END
              WHEN c.i IN (SELECT i FROM places) THEN '#'
              ELSE '.' END,
         '' ORDER BY c.i) AS etat
FROM cases c;

-- ------------------------------------------------------------ l'évolution
-- Une ligne par génération : n, l'état (w·h caractères '#' ou '.'), la population.
-- Pour chaque case : on compte les '#' parmi ses voisins, puis la règle décide.
CREATE TEMP TABLE generations AS
WITH RECURSIVE g(n, s) AS (
  SELECT 0, (SELECT etat FROM depart)
  UNION ALL
  SELECT g.n + 1,
         (SELECT group_concat(
                   CASE WHEN instr(
                          CASE WHEN substr(g.s, c.i + 1, 1) = '#' THEN r.survie ELSE r.naissance END,
                          (SELECT sum(substr(g.s, v.j + 1, 1) = '#') FROM voisins v WHERE v.i = c.i)
                        ) > 0
                        THEN '#' ELSE '.' END,
                   '' ORDER BY c.i)
          FROM cases c, regle r)
  FROM g, param p
  WHERE g.n < p.gens
)
SELECT n, s, length(s) - length(replace(s, '#', '')) AS pop FROM g;
CREATE INDEX generations_s ON generations (s);

-- --------------------------------------------------------------- affichage
-- Chaque génération devient une image texte (2 caractères par case pour
-- avoir des cases carrées). ESC[H ramène le curseur en haut : animation.
SELECT char(27) || '[H' || char(27) || '[1m génération ' || g.n || char(27) || '[0m · population ' || g.pop
       || ' · règle ' || r.texte || char(27) || '[K' || char(10)
       || (SELECT group_concat('▕' || replace(replace(substr(g.s, y * p.w + 1, p.w), '.', '  '), '#', '██') || '▏',
                               char(10) ORDER BY y)
           FROM (SELECT DISTINCT y FROM cases))
FROM generations g, param p, regle r
WHERE p.anim
ORDER BY g.n;

-- ------------------------------------------------------------------ bilan
WITH premier_retour AS (
  SELECT a.n AS vu, b.n AS revu
  FROM generations a JOIN generations b ON a.s = b.s AND a.n < b.n
  ORDER BY b.n, a.n LIMIT 1
),
extinction AS (SELECT min(n) AS n FROM generations WHERE pop = 0),
chiffres AS (
  -- '36' -> '3 ou 6' : un chiffre par ligne, puis recollés
  SELECT quoi, group_concat(d, ' ou ' ORDER BY d) AS liste FROM (
    SELECT 'n' AS quoi, substr(r.naissance, c.i + 1, 1) AS d FROM regle r, cases c WHERE c.i < length(r.naissance)
    UNION ALL
    SELECT 's', substr(r.survie, c.i + 1, 1) FROM regle r, cases c WHERE c.i < length(r.survie)
  ) GROUP BY quoi
),
courbe AS (
  -- courbe de population en 60 colonnes au plus, avec les blocs ▁▂▃▄▅▆▇█
  SELECT group_concat(substr('▁▂▃▄▅▆▇█', 1 + CAST(7.0 * m / max(1, (SELECT max(pop) FROM generations)) AS INTEGER), 1), '' ORDER BY b) AS s
  FROM (SELECT n * 60 / ((SELECT max(n) FROM generations) + 1) AS b, max(pop) AS m FROM generations GROUP BY b)
)
SELECT char(10) || ' ── bilan ──' || char(10)
  || ' règle ' || r.texte || ' : une case ' || coalesce('naît avec ' || (SELECT liste FROM chiffres WHERE quoi = 'n') || ' voisins', 'ne naît jamais')
  || ', ' || coalesce('survit avec ' || (SELECT liste FROM chiffres WHERE quoi = 's'), 'ne survit jamais') || char(10)
  || ' grille ' || p.w || '×' || p.h || CASE WHEN p.tore THEN ' torique' ELSE ' à bords morts' END
  || ', population ' || (SELECT pop FROM generations WHERE n = 0) || ' → ' || (SELECT pop FROM generations ORDER BY n DESC LIMIT 1)
  || ' (max ' || (SELECT max(pop) FROM generations) || ')' || char(10)
  || ' ' || CASE
       WHEN (SELECT n FROM extinction) IS NOT NULL THEN 'tout est mort à la génération ' || (SELECT n FROM extinction)
       WHEN (SELECT revu - vu FROM premier_retour) = 1 THEN 'figé (nature morte) depuis la génération ' || (SELECT vu FROM premier_retour)
       WHEN (SELECT vu FROM premier_retour) IS NOT NULL THEN 'cycle de période ' || (SELECT revu - vu FROM premier_retour)
            || ' : l''état de la génération ' || (SELECT vu FROM premier_retour) || ' revient à la génération ' || (SELECT revu FROM premier_retour)
       ELSE 'aucune répétition en ' || p.gens || ' générations'
     END || char(10)
  || ' population ' || (SELECT s FROM courbe) || char(10)
FROM param p, regle r;
