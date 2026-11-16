#!/usr/bin/env bash
# Tests hors-ligne de scripts/archive-journal.sh sur des journaux factices.
# Usage : bash tests/archive-journal.test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="$SCRIPT_DIR/scripts/archive-journal.sh"

TESTS_RUN=0
TESTS_FAILED=0

pass() { TESTS_RUN=$((TESTS_RUN + 1)); echo "  ok - $1"; }
fail() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1)); echo "  FAIL - $1"; }

assert_eq() {
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (attendu: '$1', obtenu: '$2')"; fi
}
assert_status() {
  if [ "$1" -eq "$2" ]; then pass "$3"; else fail "$3 (code attendu: $1, obtenu: $2)"; fi
}
assert_contains() {
  if printf '%s' "$1" | grep -qF -- "$2"; then pass "$3"; else fail "$3 (introuvable: '$2')"; fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# nouveau_journal <dossier> : en-tête + 5 entrées. Les entrées #4 et #5 sont
# volontairement placées en tête du fichier (non chronologique) : l'archivage
# doit suivre la date du titre, pas la position.
nouveau_journal() {
  mkdir -p "$1/docs"
  cat > "$1/docs/JOURNAL.md" <<'JOURNAL'
# Journal

En-tête du journal.

## 2026-09-10 — Issue #4 — `chore/4-a`

Texte de l'entrée 4.

## 2026-09-11 — Issue #5 — `chore/5-b`

Texte de l'entrée 5.

## 2025-12-01 — Issue #1 — `chore/1-c`

Texte de l'entrée 1.

## 2026-01-15 — Issue #2 — `chore/2-d`

Texte de l'entrée 2.

## 2026-03-20 — Issue #3 — `chore/3-e`

Texte de l'entrée 3.
JOURNAL
}

compte_entrees() { grep -c '^## ' "$1" || true; }

echo "== archive les plus anciennes par date =="
nouveau_journal "$WORK/a"
OUT="$("$ARCHIVE" --garder 3 "$WORK/a/docs/JOURNAL.md")"
assert_status 0 $? "réussit quand le journal dépasse le seuil"
assert_contains "$OUT" "Archivé 2 entrée(s)" "annonce le nombre d'entrées archivées"
assert_eq "3" "$(compte_entrees "$WORK/a/docs/JOURNAL.md")" "garde 3 entrées dans le journal"
assert_contains "$(cat "$WORK/a/docs/JOURNAL.md")" "Issue #4" "garde #4 (date récente malgré sa position en tête)"
assert_contains "$(cat "$WORK/a/docs/JOURNAL.md")" "Issue #5" "garde #5 (date la plus récente)"
assert_contains "$(cat "$WORK/a/docs/JOURNAL.md")" "Issue #3" "garde #3"
assert_contains "$(cat "$WORK/a/docs/JOURNAL.md")" "En-tête du journal." "conserve l'en-tête du journal"
assert_contains "$(cat "$WORK/a/docs/archive/JOURNAL-2025.md")" "Issue #1" "archive #1 dans l'archive 2025"
assert_contains "$(cat "$WORK/a/docs/archive/JOURNAL-2026.md")" "Issue #2" "archive #2 dans l'archive 2026"
assert_contains "$(cat "$WORK/a/docs/archive/JOURNAL-2026.md")" "Texte de l'entrée 2." "archive le contenu de l'entrée, pas seulement son titre"

echo "== aucune entrée perdue =="
TOTAL=$(cat "$WORK/a/docs/JOURNAL.md" "$WORK/a/docs/archive/"*.md | grep -c '^## [0-9]')
assert_eq "5" "$TOTAL" "journal + archives contiennent les 5 entrées d'origine"

echo "== idempotent =="
"$ARCHIVE" --garder 3 "$WORK/a/docs/JOURNAL.md" >/dev/null
assert_eq "3" "$(compte_entrees "$WORK/a/docs/JOURNAL.md")" "un second passage ne change rien"

echo "== ajoute à une archive existante =="
nouveau_journal "$WORK/b"
"$ARCHIVE" --garder 4 "$WORK/b/docs/JOURNAL.md" >/dev/null   # archive #1 (2025)
"$ARCHIVE" --garder 3 "$WORK/b/docs/JOURNAL.md" >/dev/null   # archive #2 (2026)
"$ARCHIVE" --garder 2 "$WORK/b/docs/JOURNAL.md" >/dev/null   # archive #3 (2026), à la suite de #2
assert_contains "$(cat "$WORK/b/docs/archive/JOURNAL-2026.md")" "Issue #2" "conserve l'entrée déjà archivée"
assert_eq "2" "$(grep -c '^## 2026' "$WORK/b/docs/archive/JOURNAL-2026.md")" "ajoute la nouvelle entrée sans écraser l'archive"

echo "== rien à archiver =="
nouveau_journal "$WORK/c"
OUT="$("$ARCHIVE" --garder 5 "$WORK/c/docs/JOURNAL.md")"
assert_status 0 $? "réussit au seuil exact"
assert_contains "$OUT" "Rien à archiver" "annonce qu'il n'y a rien à faire"
[ ! -d "$WORK/c/docs/archive" ] && pass "ne crée pas de dossier d'archive inutile" || fail "crée un dossier d'archive inutile"

echo "== erreurs =="
"$ARCHIVE" "$WORK/inexistant.md" >/dev/null 2>&1
assert_status 1 $? "échoue si le journal est introuvable"
"$ARCHIVE" --garder abc "$WORK/c/docs/JOURNAL.md" >/dev/null 2>&1
assert_status 1 $? "échoue si --garder n'est pas un entier"
"$ARCHIVE" --garder 0 "$WORK/c/docs/JOURNAL.md" >/dev/null 2>&1
assert_status 1 $? "échoue si --garder vaut 0"

echo
echo "$TESTS_RUN tests, $TESTS_FAILED échec(s)"
[ "$TESTS_FAILED" -eq 0 ]
