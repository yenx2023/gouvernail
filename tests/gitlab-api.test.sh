#!/usr/bin/env bash
# Suite de tests hors-ligne pour scripts/gitlab-api.sh — aucun appel réseau
# réel, curl et sleep sont mockés. Usage : bash tests/gitlab-api.test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GITLAB_TOKEN="fake-token-for-tests"
source "$SCRIPT_DIR/scripts/gitlab-api.sh"
# Le sourcing ci-dessus active set -euo pipefail et peut charger le vrai
# GITLAB_TOKEN depuis .env : on désactive le mode strict (le harnais doit
# continuer après un test en échec) et on reforce un token factice.
set +euo pipefail
GITLAB_TOKEN="fake-token-for-tests"

TESTS_RUN=0
TESTS_FAILED=0

pass() { TESTS_RUN=$((TESTS_RUN + 1)); echo "  ok - $1"; }
fail() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1)); echo "  FAIL - $1"; }

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then pass "$label"; else
    fail "$label (attendu: '$expected', obtenu: '$actual')"
  fi
}

assert_status() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" -eq "$actual" ]; then pass "$label"; else
    fail "$label (code retour attendu: $expected, obtenu: $actual)"
  fi
}

# curl_with_retry attend 1s puis 2s entre tentatives : inutile de ralentir
# la suite de tests pour ça.
sleep() { :; }

# curl mocké : consomme une file de couples (code_http, corps_json) posée par
# mock_curl_queue. Le compteur d'appels est un fichier (pas une variable) car
# certains appels testés se font dans une sous-coquille (isolation des `exit`
# internes à gitlab_rest/gitlab_graphql) où les variables ne remontent pas.
MOCK_CURL_LOG="$(mktemp)"
MOCK_CURL_CODES=()
MOCK_CURL_BODIES=()

mock_curl_queue() {
  : > "$MOCK_CURL_LOG"
  MOCK_CURL_CODES=()
  MOCK_CURL_BODIES=()
  local entry
  for entry in "$@"; do
    MOCK_CURL_CODES+=("${entry%%:*}")
    MOCK_CURL_BODIES+=("${entry#*:}")
  done
}

mock_curl_call_count() {
  wc -l < "$MOCK_CURL_LOG" | tr -d ' '
}

curl() {
  local args=("$@") out_file="" i n
  n=${#args[@]}
  for ((i = 0; i < n; i++)); do
    if [ "${args[$i]}" = "-o" ]; then out_file="${args[$((i + 1))]}"; fi
  done
  echo x >> "$MOCK_CURL_LOG"
  local call_count total idx
  call_count="$(mock_curl_call_count)"
  total=${#MOCK_CURL_CODES[@]}
  idx=$((call_count - 1))
  if [ "$idx" -ge "$total" ]; then idx=$((total - 1)); fi
  if [ -n "$out_file" ]; then printf '%s' "${MOCK_CURL_BODIES[$idx]}" > "$out_file"; fi
  printf '%s' "${MOCK_CURL_CODES[$idx]}"
}

echo "== parse_issue_from_branch =="
assert_eq "45" "$(parse_issue_from_branch "chore/45-migrer-node-20")" "extrait le numéro, pas le nombre du slug"
assert_eq "142" "$(parse_issue_from_branch "feature/142-export-pdf-facture")" "cas nominal feature"
assert_eq "7" "$(parse_issue_from_branch "fix/7-x")" "cas nominal fix, slug court"
parse_issue_from_branch "main" >/dev/null 2>&1
assert_status 1 $? "échoue sur une branche sans convention"

echo "== milestone_is_empty =="
mock_curl_queue "200:[]"
milestone_is_empty 1 10
assert_status 0 $? "vrai quand la liste des issues ouvertes est vide"

mock_curl_queue '200:[{"iid":1}]'
milestone_is_empty 1 10
assert_status 1 $? "faux quand il reste une issue ouverte"

echo "== merge_request_sha =="
mock_curl_queue '200:{"iid":3,"sha":"abc123"}'
assert_eq "abc123" "$(merge_request_sha 1 3)" "extrait le champ sha de la réponse"

echo "== curl_with_retry / gitlab_rest =="

mock_curl_queue "500:{}" "500:{}" "200:{\"ok\":true}"
out="$(gitlab_rest GET "projects/1/issues" 2>/dev/null)"
assert_status 0 $? "réussit après deux 500 puis un 200"
assert_eq "3" "$(mock_curl_call_count)" "réessaie sur 500 jusqu'au succès (3 tentatives)"
assert_eq "true" "$(printf '%s' "$out" | jq -r '.ok')" "renvoie le corps de la réponse finale"

mock_curl_queue "404:{\"message\":\"introuvable\"}"
(gitlab_rest GET "projects/1/issues/999" >/dev/null 2>&1)
assert_status 1 $? "échoue immédiatement sur un 404"
assert_eq "1" "$(mock_curl_call_count)" "ne réessaie jamais sur une erreur 4xx"

mock_curl_queue "429:{}" "429:{}" "429:{}"
(gitlab_rest GET "projects/1/issues" >/dev/null 2>&1)
assert_status 1 $? "abandonne après épuisement des tentatives sur 429 persistant"
assert_eq "3" "$(mock_curl_call_count)" "s'arrête à 3 tentatives maximum"

echo "== require_token / require_project =="
(unset GITLAB_TOKEN; require_token >/dev/null 2>&1)
assert_status 1 $? "require_token échoue si GITLAB_TOKEN absent"

(unset GITLAB_PROJECT_PATH; require_project >/dev/null 2>&1)
assert_status 1 $? "require_project échoue si GITLAB_PROJECT_PATH absent"

rm -f "$MOCK_CURL_LOG"

echo
echo "$TESTS_RUN tests, $TESTS_FAILED échec(s)"
[ "$TESTS_FAILED" -eq 0 ]
