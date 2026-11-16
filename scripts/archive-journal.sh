#!/usr/bin/env bash
# Archive les entrées les plus anciennes de docs/JOURNAL.md pour que le journal
# reste court (il est consulté en début de session — voir CLAUDE.md > Mémoire
# de session). Les entrées archivées vont dans docs/archive/JOURNAL-<année>.md
# (une entrée = un titre "## AAAA-MM-JJ — ..." et son contenu), jamais perdues.
#
# Les entrées gardées sont les N plus récentes selon la DATE de leur titre (à
# date égale, la position dans le fichier départage) — pas la position seule :
# le fichier n'est pas toujours parfaitement chronologique.
#
# Usage : scripts/archive-journal.sh [--garder N] [chemin-du-journal]
#   --garder N   nombre d'entrées conservées dans le journal (défaut : 15)
#   chemin       défaut : docs/JOURNAL.md à la racine de ce dépôt
# Idempotent : rien à faire si le journal a N entrées ou moins.

set -euo pipefail

KEEP=15
JOURNAL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --garder)
      [ $# -ge 2 ] || { echo "Erreur : --garder attend un nombre." >&2; exit 1; }
      KEEP="$2"; shift 2 ;;
    *) JOURNAL="$1"; shift ;;
  esac
done

case "$KEEP" in
  ''|*[!0-9]*) echo "Erreur : --garder attend un entier positif (reçu : '$KEEP')." >&2; exit 1 ;;
esac
[ "$KEEP" -ge 1 ] || { echo "Erreur : --garder doit valoir au moins 1." >&2; exit 1; }

if [ -z "$JOURNAL" ]; then
  JOURNAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs/JOURNAL.md"
fi
[ -f "$JOURNAL" ] || { echo "Erreur : journal introuvable : $JOURNAL" >&2; exit 1; }

ARCHIVE_DIR="$(dirname "$JOURNAL")/archive"
HEADING='^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'

TOTAL=$(grep -c "$HEADING" "$JOURNAL" || true)
if [ "$TOTAL" -le "$KEEP" ]; then
  echo "Rien à archiver : $TOTAL entrée(s), seuil $KEEP."
  exit 0
fi

# Numéros de ligne des titres à archiver : les plus anciens par date (tri
# stable : à date égale, l'ordre du fichier est conservé).
TO_ARCHIVE=$(grep -n "$HEADING" "$JOURNAL" \
  | awk -F: '{ split($2, t, " "); print t[2], $1 }' \
  | sort -s -k1,1 \
  | head -n $((TOTAL - KEEP)) \
  | awk '{ print $2 }' \
  | tr '\n' ' ')

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$ARCHIVE_DIR"

# Un seul passage : chaque entrée part vers le journal allégé ou vers un
# fichier temporaire d'archive par année.
awk -v list="$TO_ARCHIVE" -v tmp="$TMP_DIR" '
  BEGIN { n = split(list, a, " "); for (i = 1; i <= n; i++) archive[a[i]] = 1 }
  /^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ {
    if (NR in archive) { out = tmp "/archive-" substr($2, 1, 4) }
    else { out = tmp "/kept" }
  }
  { if (out == "") out = tmp "/kept"; print > out }
' "$JOURNAL"

for part in "$TMP_DIR"/archive-*; do
  year="${part##*-}"
  target="$ARCHIVE_DIR/JOURNAL-$year.md"
  if [ ! -f "$target" ]; then
    printf '# Journal — archives %s\n\nEntrées anciennes déplacées depuis docs/JOURNAL.md par\nscripts/archive-journal.sh — historique complet, jamais réécrit.\n\n' "$year" > "$target"
  fi
  cat "$part" >> "$target"
done

mv "$TMP_DIR/kept" "$JOURNAL"
echo "Archivé $((TOTAL - KEEP)) entrée(s) dans $ARCHIVE_DIR ; $KEEP conservée(s) dans $JOURNAL."
