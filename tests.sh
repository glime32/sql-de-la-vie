#!/usr/bin/env bash
# Vérifie le moteur SQL sur des résultats connus du Jeu de la vie.
cd "$(dirname "$0")"
ok=0 total=0
verifie() { # description, attendu (morceau du bilan), arguments de vie.sh...
  local desc="$1" attendu="$2"; shift 2
  total=$((total + 1))
  if ./vie.sh "$@" -n | grep -qF "$attendu"; then ok=$((ok + 1)); echo "  ok    $desc"
  else echo "  ÉCHEC $desc (attendu : $attendu)"; fi
}
verifie "diehard meurt à la génération 130"      "tout est mort à la génération 130" diehard -l 40 -H 30 -b -g 140
verifie "clignotant : période 2"                 "cycle de période 2"  clignotant -g 6
verifie "pulsar : période 3"                     "cycle de période 3"  pulsar -g 8
verifie "pentadécathlon : période 15"            "cycle de période 15" pentadecathlon -g 32
verifie "planeur : revient en 4×20 sur un tore 20×20" "cycle de période 80" planeur -l 20 -H 20 -g 90
verifie "vaisseau : revient en 2×20 sur un tore 20×8" "cycle de période 40" vaisseau -l 20 -H 8 -g 50
verifie "un bloc (B3/S23) est une nature morte"  "figé (nature morte) depuis la génération 0" -f <(echo '2o$2o!') -g 3
verifie "Seeds (B2/S) : une cellule seule meurt"  "tout est mort à la génération 1" -f <(echo 'o!') -r B2/S -g 3
echo "$ok / $total"
[ "$ok" = "$total" ]
