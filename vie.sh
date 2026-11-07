#!/usr/bin/env bash
# vie.sh — lance vie.sql dans sqlite3 et anime le résultat dans le terminal.
# Tout le calcul est fait par SQLite ; ce script ne fait que passer les
# paramètres et afficher les images une par une.
set -euo pipefail
ici="$(cd "$(dirname "$0")" && pwd)"

motif=planeur regle="" gens=150 w=40 h=24 tore=1 densite=0.35 vitesse=0.06 fichier="" anim=1

aide() {
  cat <<'FIN'
vie.sh — le Jeu de la vie, calculé par SQLite

  ./vie.sh [motif] [options]

  motif               nom d'un motif (voir --liste), défaut : planeur
  -f, --fichier F     lire un motif dans un fichier .rle (LifeWiki, Golly...)
  -r, --regle R       règle B/S, ex. B36/S23 (HighLife), B2/S (Seeds), B3678/S34678 (Day & Night)
  -g, --generations N nombre de générations (défaut 150)
  -l, --largeur N     largeur de la grille (défaut 40)
  -H, --hauteur N     hauteur de la grille (défaut 24)
  -b, --bords-morts   pas de tore : ce qui sort de la grille meurt
  -d, --densite X     densité de la soupe aléatoire (défaut 0.35)
  -v, --vitesse S     secondes entre deux images (défaut 0.06)
  -n, --bilan         pas d'animation, seulement le bilan
      --liste         lister les motifs
FIN
}

entier() { [[ "$2" =~ ^[0-9]+$ ]] || { echo "$1 attend un entier positif" >&2; exit 1; }; }
sql_texte() { printf "'%s'" "${1//\'/\'\'}"; }

while (($#)); do
  case "$1" in
    -h|--aide) aide; exit 0 ;;
    -f|--fichier) fichier="$2"; shift ;;
    -r|--regle) regle="$2"; shift ;;
    -g|--generations) entier "$1" "$2"; gens="$2"; shift ;;
    -l|--largeur) entier "$1" "$2"; w="$2"; shift ;;
    -H|--hauteur) entier "$1" "$2"; h="$2"; shift ;;
    -b|--bords-morts) tore=0 ;;
    -d|--densite) [[ "$2" =~ ^(0|1)?(\.[0-9]+)?$ ]] || { echo "densité entre 0 et 1" >&2; exit 1; }; densite="$2"; shift ;;
    -v|--vitesse) vitesse="$2"; shift ;;
    -n|--bilan) anim=0 ;;
    --liste)
      sqlite3 -batch :memory: ".read '$ici/motifs.sql'" \
        "SELECT printf('  %-15s %-9s %s', nom, regle, description) FROM motifs;"
      exit 0 ;;
    -*) echo "option inconnue : $1 (voir --aide)" >&2; exit 1 ;;
    *) motif="$1" ;;
  esac
  shift
done
((w >= 3 && h >= 3)) || { echo "grille trop petite" >&2; exit 1; }

if [[ -n "$fichier" ]]; then
  [[ -r "$fichier" ]] || { echo "impossible de lire $fichier" >&2; exit 1; }
  source_motif=$(sql_texte "$(cat -- "$fichier")")
  source_regle="''"
else
  source_motif="(SELECT rle FROM motifs WHERE nom = $(sql_texte "$motif"))"
  source_regle="(SELECT regle FROM motifs WHERE nom = $(sql_texte "$motif"))"
fi

script=$(cat <<FIN
.read '$ici/motifs.sql'
CREATE TEMP TABLE param AS SELECT
  coalesce(nullif($(sql_texte "$regle"), ''), $source_regle, '') AS regle,
  $gens AS gens, $w AS w, $h AS h, $tore AS tore, $densite AS densite, $anim AS anim,
  $source_motif AS motif;
.read '$ici/vie.sql'
FIN
)

if [[ -z "$fichier" ]] && [[ -z "$(sqlite3 -batch :memory: ".read '$ici/motifs.sql'" "SELECT 1 FROM motifs WHERE nom = $(sql_texte "$motif");")" ]]; then
  echo "motif inconnu : $motif (voir ./vie.sh --liste)" >&2; exit 1
fi

# sqlite3 sépare les lignes du résultat par \x1e : une « ligne » = une image entière.
if ((anim)); then
  trap 'printf "\e[?25h"' EXIT
  printf '\e[2J\e[?25l'
fi
# Les sqlite3 récents remplacent ESC par « ^[ » à l'affichage : -escape off
# l'empêche, et pour les versions sans cette option on remet ESC à la main.
echappement=()
sqlite3 -escape off :memory: 'SELECT 1' >/dev/null 2>&1 && echappement=(-escape off)
sqlite3 -batch -noheader -list "${echappement[@]}" -newline $'\x1e' :memory: <<<"$script" |
while IFS= read -r -d $'\x1e' image; do
  image=${image//'^['/$'\e'}
  printf '%s' "$image"
  if [[ "$image" == $'\e['* ]]; then sleep "$vitesse"; fi
done
