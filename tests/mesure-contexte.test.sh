#!/usr/bin/env bash
# Tests hors-ligne de scripts/mesure-contexte.sh sur un dépôt factice.
# Usage : bash tests/mesure-contexte.test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MESURE="$SCRIPT_DIR/scripts/mesure-contexte.sh"

TESTS_RUN=0
TESTS_FAILED=0

pass() { TESTS_RUN=$((TESTS_RUN + 1)); echo "  ok - $1"; }
fail() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1)); echo "  FAIL - $1"; }

assert_status() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" -eq "$actual" ]; then pass "$label"; else
    fail "$label (code retour attendu: $expected, obtenu: $actual)"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then pass "$label"; else
    fail "$label (introuvable: '$needle')"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    fail "$label (présent: '$needle')"
  else pass "$label"; fi
}

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/docs" "$FIXTURE/.claude/skills/demo"
head -c 3700 /dev/zero | tr '\0' 'a' > "$FIXTURE/CLAUDE.md"           # 3700 octets → 1000 tokens
head -c 370 /dev/zero | tr '\0' 'a' > "$FIXTURE/docs/CONTEXT.md"      # 370 octets → 100 tokens
head -c 740 /dev/zero | tr '\0' 'a' > "$FIXTURE/docs/JOURNAL.md"      # 740 octets → 200 tokens
head -c 37 /dev/zero | tr '\0' 'a' > "$FIXTURE/docs/AUTRE.md"         # hors liste de début de session
head -c 1850 /dev/zero | tr '\0' 'a' > "$FIXTURE/.claude/skills/demo/SKILL.md"

echo "== dépôt valide =="
OUT="$("$MESURE" "$FIXTURE")"
assert_status 0 $? "réussit sur un dépôt avec CLAUDE.md"
assert_contains "$OUT" "toujours chargé" "affiche la catégorie CLAUDE.md"
assert_contains "$OUT" "3700" "compte les octets de CLAUDE.md"
assert_contains "$OUT" "1000" "estime 3700 octets à 1000 tokens"
assert_contains "$OUT" "docs/CONTEXT.md" "classe CONTEXT.md en début de session"
assert_contains "$OUT" "début de session" "affiche la catégorie début de session"
assert_contains "$OUT" "300" "totalise le début de session (CONTEXT+JOURNAL = 1110 octets → 300 tokens)"
assert_contains "$OUT" "autres docs" "classe un doc hors liste dans autres docs"
assert_contains "$OUT" "docs/AUTRE.md" "liste le doc hors liste"
assert_contains "$OUT" ".claude/skills/demo/SKILL.md" "liste les SKILL.md"
assert_contains "$OUT" "500" "estime 1850 octets de skill à 500 tokens"

echo "== design system en index + fichiers par thème =="
mkdir -p "$FIXTURE/docs/design"
head -c 740 /dev/zero | tr '\0' 'a' > "$FIXTURE/docs/DESIGN.md"          # index → début de session
head -c 1110 /dev/zero | tr '\0' 'a' > "$FIXTURE/docs/design/tokens.md"  # détail → autres docs
OUT="$("$MESURE" "$FIXTURE")"
assert_contains "$OUT" "docs/DESIGN.md" "liste l'index DESIGN.md"
assert_contains "$OUT" "docs/design/tokens.md" "liste le détail docs/design/*.md"
DESIGN_LINE="$(printf '%s\n' "$OUT" | grep -F 'docs/DESIGN.md')"
assert_contains "$DESIGN_LINE" "début de session" "classe l'index DESIGN.md en début de session"
TOKENS_LINE="$(printf '%s\n' "$OUT" | grep -F 'docs/design/tokens.md')"
assert_contains "$TOKENS_LINE" "autres docs" "classe docs/design/*.md en autres docs (lu à la demande)"
rm -rf "$FIXTURE/docs/design" "$FIXTURE/docs/DESIGN.md"

echo "== catégories vides omises =="
mkdir -p "$FIXTURE/minimal"
echo "x" > "$FIXTURE/minimal/CLAUDE.md"
OUT="$("$MESURE" "$FIXTURE/minimal")"
assert_status 0 $? "réussit avec CLAUDE.md seul"
assert_not_contains "$OUT" "autres docs" "n'affiche pas une catégorie vide"
assert_not_contains "$OUT" "début de session" "n'affiche pas début de session sans docs"

echo "== dépôt invalide =="
mkdir -p "$FIXTURE/vide"
"$MESURE" "$FIXTURE/vide" >/dev/null 2>&1
assert_status 1 $? "échoue si CLAUDE.md est absent"
ERR="$("$MESURE" "$FIXTURE/vide" 2>&1 >/dev/null)"
assert_contains "$ERR" "CLAUDE.md introuvable" "explique l'erreur sur stderr"

echo
echo "$TESTS_RUN tests, $TESTS_FAILED échec(s)"
[ "$TESTS_FAILED" -eq 0 ]
