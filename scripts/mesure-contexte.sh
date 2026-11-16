#!/usr/bin/env bash
# Mesure le volume de contexte qu'un dépôt outillé Gouvernail fait charger à
# une session Claude Code, pour chiffrer l'effet d'une optimisation (avant /
# après). Estimation : tokens ≈ octets / 3,7 (français) — un ordre de
# grandeur, pas un décompte exact du tokenizer.
#
# Catégories :
#   toujours chargé   CLAUDE.md (relu à chaque tour)
#   début de session  docs que CLAUDE.md demande de lire : CONTEXT, JOURNAL,
#                     PRD, PLAN, DESIGN
#   autres docs       le reste de docs/*.md (lu à la demande)
#   skills            SKILL.md, chargé seulement à l'invocation du skill
#
# Usage : scripts/mesure-contexte.sh [racine-du-depot]   (défaut : racine de ce dépôt)

set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [ ! -f "$ROOT/CLAUDE.md" ]; then
  echo "Erreur : $ROOT/CLAUDE.md introuvable — ce n'est pas un dépôt outillé Gouvernail." >&2
  exit 1
fi

# tokens estimés à partir d'un nombre d'octets (entier, arrondi inférieur)
estimate_tokens() { echo $(( $1 * 10 / 37 )); }

TOTAL_BYTES=0

# print_line <catégorie> <fichier relatif>
print_line() {
  local category="$1" file="$2" bytes words
  bytes=$(wc -c < "$ROOT/$file" | tr -d ' ')
  words=$(wc -w < "$ROOT/$file" | tr -d ' ')
  printf '%-17s %-45s %9s %8s %9s\n' "$category" "$file" "$bytes" "$words" "$(estimate_tokens "$bytes")"
  TOTAL_BYTES=$((TOTAL_BYTES + bytes))
}

# print_total <libellé> : affiche et remet à zéro le cumul de la catégorie
print_total() {
  [ "$TOTAL_BYTES" -eq 0 ] && return 0
  printf '%-17s %-45s %9s %8s %9s\n' "" "→ $1" "$TOTAL_BYTES" "" "$(estimate_tokens "$TOTAL_BYTES")"
  echo
  TOTAL_BYTES=0
}

printf '%-17s %-45s %9s %8s %9s\n' "CATÉGORIE" "FICHIER" "OCTETS" "MOTS" "~TOKENS"

print_line "toujours chargé" "CLAUDE.md"
print_total "toujours chargé"

for name in CONTEXT JOURNAL PRD PLAN DESIGN; do
  [ -f "$ROOT/docs/$name.md" ] && print_line "début de session" "docs/$name.md"
done
print_total "début de session"

for file in "$ROOT"/docs/*.md; do
  [ -f "$file" ] || continue
  case "$(basename "$file")" in CONTEXT.md|JOURNAL.md|PRD.md|PLAN.md|DESIGN.md) continue ;; esac
  print_line "autres docs" "docs/$(basename "$file")"
done
print_total "autres docs"

for file in "$ROOT"/.claude/skills/*/SKILL.md; do
  [ -f "$file" ] || continue
  print_line "skills" "${file#"$ROOT"/}"
done
print_total "skills (à l'invocation)"
