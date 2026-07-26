#!/usr/bin/env bash
# Point de passage unique pour tous les appels à l'API GitLab (REST + GraphQL).
# Voir CLAUDE.md > "Accès" pour la doctrine associée.
#
# Usage en CLI :
#   scripts/gitlab-api.sh rest <METHOD> <path> [json_body]
#   scripts/gitlab-api.sh graphql <query_or_mutation> [variables_json]
#
# Usage en tant que lib (source) :
#   source scripts/gitlab-api.sh
#   gitlab_rest GET "projects/123/issues"
#   gitlab_graphql 'query { ... }' '{"var": "val"}'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
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
  http_code="$(curl "${args[@]}" -w '%{http_code}' -o "$tmp" "$url")"
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
  http_code="$(curl -sS -X POST \
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    rest) gitlab_rest "$@" ;;
    graphql) gitlab_graphql "$@" ;;
    *)
      echo "Usage: $0 rest <METHOD> <path> [json_body]" >&2
      echo "       $0 graphql <query_or_mutation> [variables_json]" >&2
      exit 1
      ;;
  esac
fi
