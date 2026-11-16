#!/usr/bin/env bash
# Tests hors-ligne de scripts/aligne-gouvernail.sh sur des dépôts factices.
# Usage : bash tests/aligne-gouvernail.test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALIGNE="$SCRIPT_DIR/scripts/aligne-gouvernail.sh"

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
assert_not_contains() {
  if printf '%s' "$1" | grep -qF -- "$2"; then fail "$3 (présent: '$2')"; else pass "$3"; fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Les tests ne doivent jamais toucher au réseau ni à un vrai dépôt voisin.
export GOUVERNAIL_REPO_URL="$WORK/inexistant.git"

git_quiet() { git -c user.name=test -c user.email=test@test -c commit.gpgsign=false "$@"; }

# nouvelle_source <dossier> : dépôt git factice jouant Gouvernail (1 commit)
nouvelle_source() {
  mkdir -p "$1" && git -C "$1" init -q
  echo "v1" > "$1/fichier"
  git_quiet -C "$1" add -A && git_quiet -C "$1" commit -q -m "v1"
}

nouveau_projet() { mkdir -p "$1/.claude" "$1/docs"; echo "x" > "$1/CLAUDE.md"; }

echo "== marqueur : écrire / lire =="
nouvelle_source "$WORK/src"
nouveau_projet "$WORK/p1"
HASH="$(git -C "$WORK/src" rev-parse HEAD)"
GOUVERNAIL_SOURCE="$WORK/src" "$ALIGNE" --racine "$WORK/p1" marqueur ecrire >/dev/null
assert_status 0 $? "écrit le marqueur depuis une source locale"
assert_eq "$HASH" "$(cat "$WORK/p1/.claude/gouvernail-version")" "le marqueur contient le hash HEAD de la source"
assert_eq "$HASH" "$("$ALIGNE" --racine "$WORK/p1" marqueur lire)" "lit le marqueur écrit"

echo "== marqueur : erreurs =="
nouveau_projet "$WORK/p2"
"$ALIGNE" --racine "$WORK/p2" marqueur lire >/dev/null 2>&1
assert_status 1 $? "lire échoue si le marqueur est absent"
ERR="$("$ALIGNE" --racine "$WORK/p2" marqueur lire 2>&1)"
assert_contains "$ERR" "marqueur absent" "explique que le marqueur est absent"

echo "zzz-pas-un-hash" > "$WORK/p2/.claude/gouvernail-version"
"$ALIGNE" --racine "$WORK/p2" marqueur lire >/dev/null 2>&1
assert_status 1 $? "lire échoue si le marqueur est invalide"

nouveau_projet "$WORK/p3"
GOUVERNAIL_SOURCE="$WORK/nulle-part" "$ALIGNE" --racine "$WORK/p3" marqueur ecrire >/dev/null 2>&1
assert_status 1 $? "écrire échoue si la source est introuvable"
[ ! -f "$WORK/p3/.claude/gouvernail-version" ] && pass "n'écrit aucun marqueur en cas d'échec" || fail "marqueur écrit malgré l'échec"

"$ALIGNE" --racine "$WORK/p3" marqueur inconnu >/dev/null 2>&1
assert_status 1 $? "sous-commande de marqueur inconnue refusée"
"$ALIGNE" --racine "$WORK/p3" nimporte >/dev/null 2>&1
assert_status 1 $? "commande inconnue refusée"
"$ALIGNE" --racine "$WORK/inexistant" marqueur lire >/dev/null 2>&1
assert_status 1 $? "--racine vers un dossier inexistant refusée"

echo "== la source n'écrit pas dans elle-même =="
OUT="$(GOUVERNAIL_SOURCE="$WORK/src" "$ALIGNE" --racine "$WORK/src" marqueur ecrire)"
assert_contains "$OUT" "est la source" "signale que le dépôt est la source"
[ ! -f "$WORK/src/.claude/gouvernail-version" ] && pass "n'écrit pas de marqueur dans la source" || fail "marqueur écrit dans la source"

echo
echo "$TESTS_RUN tests, $TESTS_FAILED échec(s)"
[ "$TESTS_FAILED" -eq 0 ]
