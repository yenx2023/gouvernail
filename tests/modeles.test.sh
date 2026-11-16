#!/usr/bin/env bash
# Valide le frontmatter des subagents (.claude/agents/*.md) et des skills
# (.claude/skills/*/SKILL.md) : Claude Code ignore SILENCIEUSEMENT un
# frontmatter mal formé (agent sans name/description, valeur de model
# inconnue…), ce qui désactiverait l'économie de tokens sans aucune erreur.
# Usage : bash tests/modeles.test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${1:-$SCRIPT_DIR}"

TESTS_RUN=0
TESTS_FAILED=0
pass() { TESTS_RUN=$((TESTS_RUN + 1)); echo "  ok - $1"; }
fail() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1)); echo "  FAIL - $1"; }

# frontmatter <fichier> : imprime les lignes entre le premier --- (ligne 1
# obligatoire) et le --- suivant ; code 1 si le fichier n'ouvre pas par ---.
frontmatter() {
  [ "$(head -n 1 "$1")" = "---" ] || return 1
  awk 'NR==1{next} /^---$/{exit} {print}' "$1"
}

# field <frontmatter> <clé> : valeur de la clé (première occurrence)
field() { printf '%s\n' "$1" | sed -n "s/^$2: *//p" | head -n 1; }

MODELS_OK="sonnet opus haiku fable inherit"
EFFORTS_OK="low medium high xhigh max"

in_list() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

echo "== subagents =="
AGENTS=0
for f in "$ROOT"/.claude/agents/*.md; do
  [ -f "$f" ] || continue
  AGENTS=$((AGENTS + 1))
  n="$(basename "$f")"
  fm="$(frontmatter "$f")" || { fail "$n : le frontmatter doit s'ouvrir à la ligne 1"; continue; }
  name="$(field "$fm" name)"
  [ -n "$name" ] && pass "$n : name présent" || fail "$n : name manquant (agent ignoré)"
  [ "$name.md" = "$n" ] && pass "$n : name = nom de fichier" || fail "$n : name '$name' ≠ nom de fichier"
  case "$name" in *:*|-*) fail "$n : name ne doit ni contenir ':' ni commencer par '-'" ;; *) pass "$n : name valide" ;; esac
  [ -n "$(field "$fm" description)" ] && pass "$n : description présente" || fail "$n : description manquante (agent ignoré)"
  model="$(field "$fm" model)"
  if [ -z "$model" ]; then fail "$n : model absent (hérite du modèle de session, aucune économie)"
  elif in_list "$model" "$MODELS_OK"; then pass "$n : model '$model' reconnu"
  else fail "$n : model '$model' inconnu (attendu : $MODELS_OK)"; fi
done
[ "$AGENTS" -gt 0 ] && pass "au moins un subagent défini ($AGENTS)" || fail "aucun subagent dans .claude/agents/"

echo "== skills =="
for f in "$ROOT"/.claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  n="$(basename "$(dirname "$f")")"
  fm="$(frontmatter "$f")" || { fail "skill $n : le frontmatter doit s'ouvrir à la ligne 1"; continue; }
  [ "$(field "$fm" name)" = "$n" ] && pass "skill $n : name cohérent" || fail "skill $n : name ≠ nom du dossier"
  model="$(field "$fm" model)"
  if [ -n "$model" ]; then
    in_list "$model" "$MODELS_OK" && pass "skill $n : model '$model' reconnu" || fail "skill $n : model '$model' inconnu"
  fi
  effort="$(field "$fm" effort)"
  if [ -n "$effort" ]; then
    in_list "$effort" "$EFFORTS_OK" && pass "skill $n : effort '$effort' reconnu" || fail "skill $n : effort '$effort' inconnu"
  fi
done

echo "== garde-fous =="
# Un skill qui committe/pousse/merge ne doit jamais tourner sur Haiku.
for n in livre tache cloture backlog-gitlab; do
  f="$ROOT/.claude/skills/$n/SKILL.md"
  [ -f "$f" ] || continue
  [ "$(field "$(frontmatter "$f")" model)" != "haiku" ] && pass "skill $n : pas sur haiku" || fail "skill $n : ne doit pas utiliser haiku (écritures GitLab/git)"
done
# Les subagents qui écrivent ne doivent pas être sur haiku ; l'explorateur reste en lecture seule.
EXP="$ROOT/.claude/agents/explorateur.md"
if [ -f "$EXP" ]; then
  tools="$(field "$(frontmatter "$EXP")" tools)"
  case "$tools" in *Write*|*Edit*) fail "explorateur : ne doit pas avoir Write/Edit (lecture seule)" ;; *) pass "explorateur : lecture seule (pas de Write/Edit)" ;; esac
fi

echo
echo "$TESTS_RUN tests, $TESTS_FAILED échec(s)"
[ "$TESTS_FAILED" -eq 0 ]
