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

# ---------------------------------------------------------------------------
# audit
# ---------------------------------------------------------------------------

# source_outillee <dossier> : Gouvernail factice avec un peu d'outillage
source_outillee() {
  mkdir -p "$1/scripts" "$1/.claude/agents" "$1/.claude/skills/livre" "$1/.claude/skills/cadre"
  git -C "$1" init -q
  echo "mesure v1" > "$1/scripts/mesure-contexte.sh"
  echo "agent v1" > "$1/.claude/agents/explorateur.md"
  echo "livre v1" > "$1/.claude/skills/livre/SKILL.md"
  echo "cadre v1" > "$1/.claude/skills/cadre/SKILL.md"
  git_quiet -C "$1" add -A && git_quiet -C "$1" commit -q -m "v1"
}

# projet_a_jour <dossier> <source> : projet aligné sur la source (profil sans /cadre)
projet_a_jour() {
  mkdir -p "$1/scripts" "$1/.claude/agents" "$1/.claude/skills/livre" "$1/docs"
  cp "$2/scripts/mesure-contexte.sh" "$1/scripts/"
  cp "$2/.claude/agents/explorateur.md" "$1/.claude/agents/"
  cp "$2/.claude/skills/livre/SKILL.md" "$1/.claude/skills/livre/"
  echo "Règle de lecture de début de session" > "$1/CLAUDE.md"
  git -C "$2" rev-parse HEAD > "$1/.claude/gouvernail-version"
  printf '# Contexte\n' > "$1/docs/CONTEXT.md"
  printf '# Journal\n\n## 2026-01-01 — Issue #1\n\ntexte\n' > "$1/docs/JOURNAL.md"
}

snapshot() { (cd "$1" && find . -type f -not -path './.git/*' | sort | xargs sha256sum | sha256sum); }

echo "== audit : projet à jour =="
source_outillee "$WORK/s2"
projet_a_jour "$WORK/a1" "$WORK/s2"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a1" audit)"
assert_status 0 $? "code 0 quand rien n'est à faire"
assert_contains "$OUT" "Rien à signaler" "annonce que tout est à jour"
assert_not_contains "$OUT" "manquant" "un skill de profil absent n'est pas imposé (cadre)"

echo "== audit : lecture seule =="
AVANT="$(snapshot "$WORK/a1")"
GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a1" audit >/dev/null
assert_eq "$AVANT" "$(snapshot "$WORK/a1")" "l'audit ne modifie aucun fichier du projet"

echo "== audit : version en retard et outillage périmé =="
V1="$(git -C "$WORK/s2" rev-parse HEAD)"
echo "mesure v2" > "$WORK/s2/scripts/mesure-contexte.sh"
git_quiet -C "$WORK/s2" commit -q -am "v2"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a1" audit)"
assert_status 1 $? "code 1 quand il y a quelque chose à faire"
assert_contains "$OUT" "version en retard" "signale la version en retard"
assert_contains "$OUT" "1 commit(s) d'avance" "compte les commits d'avance"
assert_contains "$OUT" "outillage périmé : 1" "signale le fichier périmé (copie d'origine, source évoluée)"

echo "== audit : fichier modifié localement jamais traité comme périmé =="
projet_a_jour "$WORK/a2" "$WORK/s2"
echo "livre local" > "$WORK/a2/.claude/skills/livre/SKILL.md"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a2" audit)"
assert_status 0 $? "une modification locale n'est pas un point à traiter"
assert_contains "$OUT" "modifié(s) localement" "signale la modification locale en information"

echo "== audit : outillage manquant =="
projet_a_jour "$WORK/a3" "$WORK/s2"
rm "$WORK/a3/.claude/agents/explorateur.md"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a3" audit)"
assert_contains "$OUT" "outillage manquant : 1" "signale le fichier manquant"

echo "== audit : skill de profil présent suivi, absent ignoré =="
projet_a_jour "$WORK/a4" "$WORK/s2"
mkdir -p "$WORK/a4/.claude/skills/cadre"
echo "cadre obsolète" > "$WORK/a4/.claude/skills/cadre/SKILL.md"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a4" audit)"
assert_contains "$OUT" "[i] 1 fichier(s) d'outillage modifié(s)" "suit /cadre quand le projet l'a"

echo "== audit : contrôles locaux =="
projet_a_jour "$WORK/a5" "$WORK/s2"
head -c 6500 /dev/zero | tr '\0' 'a' > "$WORK/a5/docs/CONTEXT.md"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a5" audit)"
assert_contains "$OUT" "docs/CONTEXT.md : 6500 octets" "signale CONTEXT.md trop long"

projet_a_jour "$WORK/a6" "$WORK/s2"
for i in $(seq 1 16); do printf '\n## 2026-02-%02d — Issue #%d\n\ntexte\n' "$i" "$i" >> "$WORK/a6/docs/JOURNAL.md"; done
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a6" audit)"
assert_contains "$OUT" "docs/JOURNAL.md : 17 entrées" "signale un journal trop long"

projet_a_jour "$WORK/a7" "$WORK/s2"
head -c 20000 /dev/zero | tr '\0' 'a' > "$WORK/a7/docs/DESIGN.md"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a7" audit)"
assert_contains "$OUT" "DESIGN.md monolithique" "signale un DESIGN.md monolithique"
mkdir "$WORK/a7/docs/design"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a7" audit)"
assert_not_contains "$OUT" "monolithique" "DESIGN.md avec docs/design/ n'est plus monolithique"

projet_a_jour "$WORK/a8" "$WORK/s2"
echo "rien" > "$WORK/a8/CLAUDE.md"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a8" audit)"
assert_contains "$OUT" "règle de lecture de début de session absente" "signale la règle de lecture absente"

projet_a_jour "$WORK/a9" "$WORK/s2"
rm "$WORK/a9/.claude/gouvernail-version"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/a9" audit)"
assert_contains "$OUT" "gouvernail-version absent" "signale le marqueur absent"

echo "== audit : source introuvable =="
projet_a_jour "$WORK/a10" "$WORK/s2"
head -c 6500 /dev/zero | tr '\0' 'a' > "$WORK/a10/docs/CONTEXT.md"
OUT="$(GOUVERNAIL_SOURCE="$WORK/nulle-part" "$ALIGNE" --racine "$WORK/a10" audit)"
assert_contains "$OUT" "source Gouvernail introuvable" "signale la source introuvable"
assert_contains "$OUT" "docs/CONTEXT.md" "les contrôles locaux fonctionnent sans source"

echo "== audit : dépôt invalide, source elle-même =="
mkdir -p "$WORK/vide"
"$ALIGNE" --racine "$WORK/vide" audit >/dev/null 2>&1
assert_status 1 $? "échoue sans CLAUDE.md"
echo "x" > "$WORK/s2/CLAUDE.md"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/s2" audit)"
assert_contains "$OUT" "ce dépôt est la source" "reconnaît qu'il audite la source elle-même"

echo "== audit --court =="
projet_a_jour "$WORK/c1" "$WORK/s2"
echo "mesure v1" > "$WORK/c1/scripts/mesure-contexte.sh"   # copie d'origine (v1)
echo "$V1" > "$WORK/c1/.claude/gouvernail-version"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/c1" audit --court)"
assert_status 0 $? "code 0 même avec des optimisations disponibles"
assert_eq "1" "$(printf '%s\n' "$OUT" | grep -c .)" "une seule ligne quand il y a quelque chose à faire"
assert_contains "$OUT" "lance /aligne" "oriente vers /aligne"

cp "$WORK/s2/scripts/mesure-contexte.sh" "$WORK/c1/scripts/mesure-contexte.sh"
git -C "$WORK/s2" rev-parse HEAD > "$WORK/c1/.claude/gouvernail-version"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s2" "$ALIGNE" --racine "$WORK/c1" audit --court)"
assert_eq "" "$OUT" "silence quand tout est à jour"

echo "== audit --court : jamais de réseau =="
projet_a_jour "$WORK/c2" "$WORK/s2"
rm "$WORK/c2/.claude/agents/explorateur.md"
# la source n'est joignable que par clone : l'audit complet la voit, --court non
OUT="$(GOUVERNAIL_SOURCE="$WORK/nulle-part" GOUVERNAIL_REPO_URL="$WORK/s2" "$ALIGNE" --racine "$WORK/c2" audit)"
assert_contains "$OUT" "outillage manquant" "l'audit complet clone la source si besoin"
OUT="$(GOUVERNAIL_SOURCE="$WORK/nulle-part" GOUVERNAIL_REPO_URL="$WORK/s2" "$ALIGNE" --racine "$WORK/c2" audit --court)"
assert_eq "" "$OUT" "--court ne clone jamais la source"

echo
echo "$TESTS_RUN tests, $TESTS_FAILED échec(s)"
[ "$TESTS_FAILED" -eq 0 ]
