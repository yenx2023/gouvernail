#!/usr/bin/env bash
# Point de passage unique pour tous les appels à l'API GitLab (REST + GraphQL)
# ainsi que le push/fetch git vers le projet GitLab du dépôt courant. Un seul
# token (GITLAB_TOKEN, scopé groupe) pour tous ces usages — voir CLAUDE.md >
# Sécurité du token GitLab.
#
# Usage en CLI :
#   scripts/gitlab-api.sh rest <METHOD> <path> [json_body]
#   scripts/gitlab-api.sh graphql <query_or_mutation> [variables_json]
#   scripts/gitlab-api.sh push <local_ref> <remote_branch>
#   scripts/gitlab-api.sh fetch <remote_branch>
#
# Usage en tant que lib (source) :
#   source scripts/gitlab-api.sh
#   gitlab_rest GET "projects/123/issues"
#   gitlab_graphql 'query { ... }' '{"var": "val"}'
#   gitlab_git push main main
#   gitlab_git fetch main

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
  set +a
fi

if [ -f "$SCRIPT_DIR/.claude/gitlab-project.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.claude/gitlab-project.env"
  set +a
fi

: "${GITLAB_API_URL:=https://gitlab.com/api/v4}"
: "${GITLAB_GRAPHQL_URL:=https://gitlab.com/api/graphql}"

require_token() {
  if [ -z "${GITLAB_TOKEN:-}" ]; then
    echo "Erreur: GITLAB_TOKEN absent. Renseigne-le dans .env (voir .env.example)." >&2
    exit 1
  fi
}

require_project() {
  if [ -z "${GITLAB_PROJECT_PATH:-}" ]; then
    echo "Erreur: GITLAB_PROJECT_PATH absent. Renseigne-le dans .claude/gitlab-project.env." >&2
    exit 1
  fi
}

# curl_with_retry <curl_args...> -w '%{http_code}' -o <tmp_file> <url>
# Réessaie jusqu'à 3 fois (backoff 1s/2s/4s) sur 429 ou 5xx — erreurs
# transitoires typiques d'une exécution autonome (Claude Code Cloud) sans
# supervision humaine pour relancer manuellement. N'affecte jamais les
# erreurs 4xx logiques (400/401/403/404), qui remontent immédiatement.
curl_with_retry() {
  local attempt=1 max_attempts=3 delay=1 http_code
  while true; do
    http_code="$(curl "$@")"
    if [ "$http_code" -lt 429 ] || { [ "$http_code" -gt 429 ] && [ "$http_code" -lt 500 ]; }; then
      echo "$http_code"
      return 0
    fi
    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "$http_code"
      return 0
    fi
    echo "Avertissement: HTTP $http_code (tentative $attempt/$max_attempts), nouvel essai dans ${delay}s..." >&2
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

# gitlab_git push <local_ref> <remote_branch>
# gitlab_git fetch <remote_branch>
gitlab_git() {
  require_token
  require_project
  local action="$1"
  local url="https://oauth2:${GITLAB_TOKEN}@gitlab.com/${GITLAB_PROJECT_PATH}.git"
  case "$action" in
    push)
      local local_ref="$2" remote_branch="$3"
      git push "$url" "${local_ref}:refs/heads/${remote_branch}"
      ;;
    fetch)
      local remote_branch="$2"
      git fetch "$url" "$remote_branch"
      ;;
    *)
      echo "Usage: gitlab_git push <local_ref> <remote_branch> | fetch <remote_branch>" >&2
      exit 1
      ;;
  esac
}

# gitlab_rest <METHOD> <path> [json_body]
gitlab_rest() {
  require_token
  local method="$1" path="$2" body="${3:-}"
  local url="${GITLAB_API_URL}/${path#/}"
  local args=(-sS -X "$method" -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" -H "Content-Type: application/json")
  if [ -n "$body" ]; then
    args+=(--data "$body")
  fi
  local tmp http_code
  tmp="$(mktemp)"
  http_code="$(curl_with_retry "${args[@]}" -w '%{http_code}' -o "$tmp" "$url")"
  if [ "$http_code" -ge 400 ]; then
    echo "Erreur HTTP $http_code sur $method $url" >&2
    jq . "$tmp" >&2 2>/dev/null || cat "$tmp" >&2
    rm -f "$tmp"
    exit 1
  fi
  jq . "$tmp" 2>/dev/null || cat "$tmp"
  rm -f "$tmp"
}

# gitlab_graphql <query_or_mutation> [variables_json]
gitlab_graphql() {
  require_token
  local query="$1" variables="${2:-}"
  if [ -z "$variables" ]; then variables='{}'; fi
  local payload tmp http_code
  payload="$(jq -n --arg q "$query" --argjson vars "$variables" '{query: $q, variables: $vars}')"
  tmp="$(mktemp)"
  http_code="$(curl_with_retry -sS -X POST \
    -H "Authorization: Bearer ${GITLAB_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$payload" \
    -w '%{http_code}' -o "$tmp" \
    "$GITLAB_GRAPHQL_URL")"
  if [ "$http_code" -ge 400 ]; then
    echo "Erreur HTTP $http_code sur GraphQL" >&2
    jq . "$tmp" >&2 2>/dev/null || cat "$tmp" >&2
    rm -f "$tmp"
    exit 1
  fi
  # GraphQL peut renvoyer 200 avec un champ "errors" même en cas d'échec logique.
  if jq -e '.errors' "$tmp" >/dev/null 2>&1; then
    echo "Erreur GraphQL:" >&2
    jq '.errors' "$tmp" >&2
    rm -f "$tmp"
    exit 1
  fi
  jq . "$tmp"
  rm -f "$tmp"
}

# parse_issue_from_branch <nom_branche>
# Extrait le numéro d'issue GitLab d'un nom de branche <feature|fix|chore>/<numero>-<slug>.
# N'extrait jamais un nombre trouvé ailleurs dans le slug (ex.
# "chore/45-migrer-node-20" → 45, pas 20) : seul le nombre juste après le
# type et avant le premier tiret compte.
parse_issue_from_branch() {
  local branch="$1"
  if [[ "$branch" =~ ^(feature|fix|chore)/([0-9]+)- ]]; then
    echo "${BASH_REMATCH[2]}"
  else
    echo "Erreur: impossible d'extraire un numéro d'issue de la branche '$branch' (attendu <feature|fix|chore>/<numero>-<slug>)" >&2
    return 1
  fi
}

# milestone_is_empty <project_id> <milestone_id>
# Vrai (exit 0) si le milestone n'a plus aucune issue ouverte, faux (exit 1) sinon.
# L'endpoint GET /projects/:id/issues n'accepte pas de filtre milestone_id :
# il attend milestone=<titre> (le titre du milestone, pas son id numérique) —
# on résout donc d'abord le titre avant de filtrer les issues ouvertes.
milestone_is_empty() {
  local project_id="$1" milestone_id="$2"
  local milestone_title encoded_title open_count
  milestone_title="$(gitlab_rest GET "projects/${project_id}/milestones/${milestone_id}" | jq -r '.title')"
  encoded_title="$(jq -rn --arg v "$milestone_title" '$v|@uri')"
  open_count="$(gitlab_rest GET "projects/${project_id}/issues?milestone=${encoded_title}&state=opened" | jq 'length')"
  [ "$open_count" -eq 0 ]
}

# merge_request_sha <project_id> <mr_iid>
# Récupère le sha courant d'une Merge Request, requis par l'API de merge
# GitLab (PUT .../merge exige ce champ). Utile quand le mode "merge" de
# /livre est invoqué séparément du mode "revue" qui avait ouvert la MR
# (ex. reprise dans une session ultérieure sans le sha déjà en main).
merge_request_sha() {
  local project_id="$1" mr_iid="$2"
  gitlab_rest GET "projects/${project_id}/merge_requests/${mr_iid}" | jq -r '.sha'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    rest) gitlab_rest "$@" ;;
    graphql) gitlab_graphql "$@" ;;
    push) gitlab_git push "$@" ;;
    fetch) gitlab_git fetch "$@" ;;
    parse-issue) parse_issue_from_branch "$@" ;;
    milestone-empty)
      if milestone_is_empty "$@"; then echo true; else echo false; fi
      ;;
    mr-sha) merge_request_sha "$@" ;;
    *)
      echo "Usage: $0 rest <METHOD> <path> [json_body]" >&2
      echo "       $0 graphql <query_or_mutation> [variables_json]" >&2
      echo "       $0 push <local_ref> <remote_branch>" >&2
      echo "       $0 fetch <remote_branch>" >&2
      echo "       $0 parse-issue <nom_branche>" >&2
      echo "       $0 milestone-empty <project_id> <milestone_id>" >&2
      echo "       $0 mr-sha <project_id> <mr_iid>" >&2
      exit 1
      ;;
  esac
fi
