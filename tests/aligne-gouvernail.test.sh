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
  cp "$SCRIPT_DIR/.claude/settings.json" "$1/.claude/settings.json"
  git_quiet -C "$1" add -A && git_quiet -C "$1" commit -q -m "v1"
}

# projet_a_jour <dossier> <source> : projet aligné sur la source (profil sans /cadre)
projet_a_jour() {
  mkdir -p "$1/scripts" "$1/.claude/agents" "$1/.claude/skills/livre" "$1/docs"
  cp "$2/scripts/mesure-contexte.sh" "$1/scripts/"
  cp "$2/.claude/agents/explorateur.md" "$1/.claude/agents/"
  cp "$2/.claude/skills/livre/SKILL.md" "$1/.claude/skills/livre/"
  echo "Règle de lecture de début de session" > "$1/CLAUDE.md"
  cp "$2/.claude/settings.json" "$1/.claude/settings.json"
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

# ---------------------------------------------------------------------------
# outillage
# ---------------------------------------------------------------------------

echo "== outillage : ajoute le manquant, met à jour le périmé =="
source_outillee "$WORK/s3"
chmod +x "$WORK/s3/scripts/mesure-contexte.sh"
git_quiet -C "$WORK/s3" add -A && git_quiet -C "$WORK/s3" commit -q -m "exec"
projet_a_jour "$WORK/o1" "$WORK/s3"
git -C "$WORK/o1" init -q && git_quiet -C "$WORK/o1" add -A && git_quiet -C "$WORK/o1" commit -q -m "base"
rm "$WORK/o1/.claude/agents/explorateur.md"
O1V1="$(git -C "$WORK/s3" rev-parse HEAD)"
echo "mesure v3" > "$WORK/s3/scripts/mesure-contexte.sh"
git_quiet -C "$WORK/s3" commit -q -am "v3"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s3" "$ALIGNE" --racine "$WORK/o1" outillage)"
assert_status 0 $? "réussit"
assert_contains "$OUT" "ajouté : .claude/agents/explorateur.md" "ajoute le fichier manquant"
assert_eq "agent v1" "$(cat "$WORK/o1/.claude/agents/explorateur.md")" "le fichier manquant est copié"
assert_contains "$OUT" "mis à jour : scripts/mesure-contexte.sh" "met à jour le fichier périmé"
assert_eq "mesure v3" "$(cat "$WORK/o1/scripts/mesure-contexte.sh")" "le fichier périmé prend la version de la source"
assert_contains "$OUT" "1 ajouté(s), 1 mis à jour, 0 conservé(s)" "résume l'opération"

echo "== outillage : ne committe jamais =="
assert_eq "1" "$(git -C "$WORK/o1" log --oneline | wc -l | tr -d ' ')" "aucun commit créé dans le projet"
[ -n "$(git -C "$WORK/o1" status --porcelain)" ] && pass "les changements restent dans l'arbre de travail" || fail "aucun changement dans l'arbre de travail"

echo "== outillage : idempotent =="
OUT="$(GOUVERNAIL_SOURCE="$WORK/s3" "$ALIGNE" --racine "$WORK/o1" outillage)"
assert_contains "$OUT" "0 ajouté(s), 0 mis à jour, 0 conservé(s)" "un second passage ne change rien"

echo "== outillage : préserve le bit exécutable =="
rm "$WORK/o1/scripts/mesure-contexte.sh"
GOUVERNAIL_SOURCE="$WORK/s3" "$ALIGNE" --racine "$WORK/o1" outillage >/dev/null
[ -x "$WORK/o1/scripts/mesure-contexte.sh" ] && pass "le script copié reste exécutable" || fail "bit exécutable perdu"

echo "== outillage : n'écrase jamais une copie modifiée localement =="
projet_a_jour "$WORK/o2" "$WORK/s3"
echo "$O1V1" > "$WORK/o2/.claude/gouvernail-version"
echo "mesure v1" > "$WORK/o2/scripts/mesure-contexte.sh"   # copie d'origine (v1) : périmée
echo "livre modifié par le projet" > "$WORK/o2/.claude/skills/livre/SKILL.md"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s3" "$ALIGNE" --racine "$WORK/o2" outillage)"
assert_contains "$OUT" "CONSERVÉ (modifié localement) : .claude/skills/livre/SKILL.md" "signale la copie modifiée localement"
assert_eq "livre modifié par le projet" "$(cat "$WORK/o2/.claude/skills/livre/SKILL.md")" "la copie modifiée n'est pas écrasée"
assert_contains "$OUT" "-livre modifié par le projet" "affiche le diff projet/gouvernail"
assert_eq "mesure v3" "$(cat "$WORK/o2/scripts/mesure-contexte.sh")" "la copie d'origine, elle, est mise à jour"

echo "== outillage : sans marqueur, une différence n'est pas écrasée =="
projet_a_jour "$WORK/o3" "$WORK/s3"
rm "$WORK/o3/.claude/gouvernail-version"
echo "divergent" > "$WORK/o3/scripts/mesure-contexte.sh"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s3" "$ALIGNE" --racine "$WORK/o3" outillage)"
assert_contains "$OUT" "CONSERVÉ (diffère de la source" "signale la différence sans base de comparaison"
assert_eq "divergent" "$(cat "$WORK/o3/scripts/mesure-contexte.sh")" "n'écrase pas sans base de comparaison"

echo "== outillage --simule =="
projet_a_jour "$WORK/o4" "$WORK/s3"
rm "$WORK/o4/.claude/agents/explorateur.md"
AVANT="$(snapshot "$WORK/o4")"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s3" "$ALIGNE" --racine "$WORK/o4" outillage --simule)"
assert_contains "$OUT" "simulation" "annonce la simulation"
assert_contains "$OUT" "ajouté : .claude/agents/explorateur.md" "décrit ce qui serait fait"
assert_eq "$AVANT" "$(snapshot "$WORK/o4")" "n'écrit rien en simulation"

echo "== outillage : erreurs =="
GOUVERNAIL_SOURCE="$WORK/nulle-part" "$ALIGNE" --racine "$WORK/o4" outillage >/dev/null 2>&1
assert_status 1 $? "échoue si la source est introuvable"
GOUVERNAIL_SOURCE="$WORK/s3" "$ALIGNE" --racine "$WORK/s3" outillage >/dev/null 2>&1
assert_status 1 $? "refuse d'aligner la source sur elle-même"
GOUVERNAIL_SOURCE="$WORK/s3" "$ALIGNE" --racine "$WORK/o4" outillage --bidon >/dev/null 2>&1
assert_status 1 $? "refuse une option inconnue"

# ---------------------------------------------------------------------------
# donnees
# ---------------------------------------------------------------------------

echo "== donnees : archive le journal =="
mkdir -p "$WORK/d1/scripts" "$WORK/d1/docs" "$WORK/d1/.claude"
echo "x" > "$WORK/d1/CLAUDE.md"
cp "$SCRIPT_DIR/scripts/archive-journal.sh" "$WORK/d1/scripts/"
printf '# Journal\n' > "$WORK/d1/docs/JOURNAL.md"
for i in $(seq 1 20); do printf '\n## 2026-03-%02d — Issue #%d\n\ntexte\n' "$i" "$i" >> "$WORK/d1/docs/JOURNAL.md"; done
AVANT="$(snapshot "$WORK/d1")"
OUT="$("$ALIGNE" --racine "$WORK/d1" donnees --simule)"
assert_contains "$OUT" "20 entrée(s)" "la simulation compte les entrées"
assert_eq "$AVANT" "$(snapshot "$WORK/d1")" "la simulation n'écrit rien"
"$ALIGNE" --racine "$WORK/d1" donnees >/dev/null
assert_status 0 $? "archive le journal"
assert_eq "15" "$(grep -c '^## 2026' "$WORK/d1/docs/JOURNAL.md")" "garde 15 entrées dans le journal"
assert_eq "5" "$(grep -c '^## 2026' "$WORK/d1/docs/archive/JOURNAL-2026.md")" "archive les 5 plus anciennes"

echo "== donnees : cas limites =="
mkdir -p "$WORK/d2/docs"; echo "x" > "$WORK/d2/CLAUDE.md"
OUT="$("$ALIGNE" --racine "$WORK/d2" donnees)"
assert_contains "$OUT" "Pas de docs/JOURNAL.md" "journal absent : rien à faire, sans erreur"
printf '# Journal\n\n## 2026-01-01 — Issue #1\n' > "$WORK/d2/docs/JOURNAL.md"
"$ALIGNE" --racine "$WORK/d2" donnees >/dev/null 2>&1
assert_status 1 $? "échoue si scripts/archive-journal.sh est absent du projet"
"$ALIGNE" --racine "$WORK/d2" donnees --bidon >/dev/null 2>&1
assert_status 1 $? "refuse une option inconnue"

# ---------------------------------------------------------------------------
# hook SessionStart
# ---------------------------------------------------------------------------

echo "== hook : settings.json de Gouvernail =="
SETTINGS="$SCRIPT_DIR/.claude/settings.json"
if command -v python3 >/dev/null 2>&1; then
  python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$SETTINGS"
  assert_status 0 $? "settings.json est un JSON valide"
  HOOK_CMD="$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["hooks"]["SessionStart"][0]["hooks"][0]["command"])' "$SETTINGS")"
  HOOK_MATCHER="$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["hooks"]["SessionStart"][0]["matcher"])' "$SETTINGS")"
  assert_eq "startup" "$HOOK_MATCHER" "le hook ne se déclenche qu'au démarrage (pas à chaque compactage)"
  assert_contains "$HOOK_CMD" "audit --court" "le hook lance l'audit court"
  assert_contains "$HOOK_CMD" "|| true" "le hook ne bloque jamais le démarrage de session"

  # exécute la commande exacte du hook dans un projet factice
  lancer_hook() { CLAUDE_PROJECT_DIR="$1" bash -c "$HOOK_CMD"; }

  echo "== hook : une ligne ou rien =="
  source_outillee "$WORK/s4"
  projet_a_jour "$WORK/h1" "$WORK/s4"
  mkdir -p "$WORK/h1/scripts" && cp "$ALIGNE" "$WORK/h1/scripts/"
  OUT="$(GOUVERNAIL_SOURCE="$WORK/s4" lancer_hook "$WORK/h1")"
  assert_eq "" "$OUT" "silence quand le projet est à jour"
  head -c 6500 /dev/zero | tr '\0' 'a' > "$WORK/h1/docs/CONTEXT.md"
  OUT="$(GOUVERNAIL_SOURCE="$WORK/s4" lancer_hook "$WORK/h1")"
  assert_eq "1" "$(printf '%s\n' "$OUT" | grep -c .)" "une seule ligne quand il y a quelque chose à faire"
  assert_contains "$OUT" "lance /aligne" "la ligne oriente vers /aligne"

  echo "== hook : jamais bloquant =="
  mkdir -p "$WORK/h2"
  OUT="$(lancer_hook "$WORK/h2" 2>&1)"
  assert_status 0 $? "code 0 si le script est absent du projet"
  assert_eq "" "$OUT" "aucune erreur affichée si le script est absent"
  mkdir -p "$WORK/h3/scripts"; cp "$ALIGNE" "$WORK/h3/scripts/"
  OUT="$(lancer_hook "$WORK/h3" 2>&1)"
  assert_status 0 $? "code 0 si le projet n'est pas un dépôt Gouvernail valide"
else
  echo "  (python3 absent : tests du hook ignorés)"
fi

echo "== audit : hook absent =="
projet_a_jour "$WORK/h4" "$WORK/s4"
rm "$WORK/h4/.claude/settings.json"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s4" "$ALIGNE" --racine "$WORK/h4" audit)"
assert_contains "$OUT" "hook SessionStart d'audit absent" "signale l'absence du hook"
echo '{"model": "sonnet"}' > "$WORK/h4/.claude/settings.json"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s4" "$ALIGNE" --racine "$WORK/h4" audit)"
assert_contains "$OUT" "hook SessionStart d'audit absent" "des réglages sans le hook sont signalés aussi"

echo "== audit : la source n'a pas de marqueur à porter =="
projet_a_jour "$WORK/h7" "$WORK/s4"
rm "$WORK/h7/.claude/gouvernail-version"
mkdir -p "$WORK/h7/.claude/skills/amorce-projet"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s4" "$ALIGNE" --racine "$WORK/h7" audit)"
assert_not_contains "$OUT" "gouvernail-version absent" "pas de marqueur exigé de Gouvernail lui-même"

echo "== outillage : settings.json =="
projet_a_jour "$WORK/h5" "$WORK/s4"
rm "$WORK/h5/.claude/settings.json"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s4" "$ALIGNE" --racine "$WORK/h5" outillage)"
assert_contains "$OUT" "ajouté : .claude/settings.json" "ajoute settings.json s'il est absent"
assert_contains "$(cat "$WORK/h5/.claude/settings.json")" "audit --court" "settings.json copié avec le hook"

projet_a_jour "$WORK/h6" "$WORK/s4"
echo '{"model": "sonnet"}' > "$WORK/h6/.claude/settings.json"
OUT="$(GOUVERNAIL_SOURCE="$WORK/s4" "$ALIGNE" --racine "$WORK/h6" outillage)"
assert_eq '{"model": "sonnet"}' "$(cat "$WORK/h6/.claude/settings.json")" "ne touche pas aux réglages existants du projet"
assert_contains "$OUT" "À AJOUTER À LA MAIN" "demande d'ajouter le hook à la main"
assert_contains "$OUT" "audit --court" "affiche le hook à ajouter"

echo
echo "$TESTS_RUN tests, $TESTS_FAILED échec(s)"
[ "$TESTS_FAILED" -eq 0 ]
