-- Bibliothèque de motifs, au format RLE (celui de LifeWiki et de Golly).
-- b = cellule morte, o = vivante, $ = ligne suivante, ! = fin, un nombre répète.
CREATE TEMP TABLE motifs (nom TEXT PRIMARY KEY, regle TEXT, description TEXT, rle TEXT);
INSERT INTO motifs VALUES
  ('planeur',        'B3/S23',  'le plus petit vaisseau : traverse la grille en diagonale',
   'bo$2bo$3o!'),
  ('vaisseau',       'B3/S23',  'vaisseau léger (LWSS), avance de 2 cases toutes les 4 générations',
   'bo2bo$o4b$o3bo$4o!'),
  ('clignotant',     'B3/S23',  'oscillateur de période 2',
   '3o!'),
  ('pulsar',         'B3/S23',  'oscillateur de période 3',
   '2b3o3b3o2b2$o4bobo4bo$o4bobo4bo$o4bobo4bo$2b3o3b3o2b2$2b3o3b3o2b$o4bobo4bo$o4bobo4bo$o4bobo4bo2$2b3o3b3o!'),
  ('pentadecathlon', 'B3/S23',  'oscillateur de période 15',
   '2bo4bo$2ob4ob2o$2bo4bo!'),
  ('canon',          'B3/S23',  'canon à planeurs de Gosper : un planeur toutes les 30 générations',
   '24bo$22bobo$12b2o6b2o12b2o$11bo3bo4b2o12b2o$2o8bo5bo3b2o$2o8bo3bob2o4bobo$10bo5bo7bo$11bo3bo$12b2o!'),
  ('diehard',        'B3/S23',  'disparaît entièrement à la génération 130',
   '6bo$2o$bo3b3o!'),
  ('gland',          'B3/S23',  'mathusalem : 7 cellules qui s''agitent pendant 5206 générations',
   'bo$3bo$2o2b3o!'),
  ('r-pentomino',    'B3/S23',  'mathusalem : 5 cellules, 1103 générations de chaos',
   'b2o$2o$bo!'),
  ('replicateur',    'B36/S23', 'HighLife : une forme qui fabrique des copies d''elle-même',
   '2b3o$bo2bo$o3bo$o2bo$3o!'),
  ('soupe',          '',        'cellules tirées au hasard (densité réglable avec -d)',
   '');
