#!/usr/bin/env bash
# Aligne un projet outillé Gouvernail sur l'évolution du framework. Un projet
# amorcé est une COPIE de l'outillage : ce script (et le skill /aligne) lui
# permet de savoir ce qui a changé côté Gouvernail et de s'y mettre à jour,
# sans jamais committer ni pousser — la livraison reste soumise à la
# validation de /livre (voir CLAUDE.md > Cycle de vie d'une tâche).
#
# Usage : scripts/aligne-gouvernail.sh [--racine <dossier>] <commande> [args]
#
#   marqueur lire      affiche la version de Gouvernail dont l'outillage a été
#                      copié (.claude/gouvernail-version)
#   marqueur ecrire    enregistre la version courante de la source Gouvernail
#
# Source de Gouvernail : variable GOUVERNAIL_SOURCE (défaut : dépôt voisin
# ../gouvernail) ; à défaut, clone temporaire de GOUVERNAIL_REPO_URL (par
# exemple en session Cloud, où le dépôt voisin n'existe pas).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARQUEUR_REL=".claude/gouvernail-version"
GOUVERNAIL_REPO_URL="${GOUVERNAIL_REPO_URL:-https://github.com/yenx2023/gouvernail}"

SOURCE=""      # chemin de la source Gouvernail, posé par resolve_source
TMP_SOURCE=""  # clone temporaire éventuel, supprimé en sortie

cleanup() { [ -z "$TMP_SOURCE" ] || rm -rf "$TMP_SOURCE"; }
trap cleanup EXIT

die() { echo "Erreur : $*" >&2; exit 1; }

usage() {
  sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
}

# resolve_source [reseau] : pose SOURCE. Sans l'argument "reseau", seule la
# source locale est admise (aucun accès réseau).
resolve_source() {
  local allow_network="${1:-non}" candidate
  candidate="${GOUVERNAIL_SOURCE:-$ROOT/../gouvernail}"
  if [ -e "$candidate/.git" ]; then
    SOURCE="$(cd "$candidate" && pwd)"
    return 0
  fi
  [ "$allow_network" = "reseau" ] || return 1
  TMP_SOURCE="$(mktemp -d)"
  if ! git clone --quiet "$GOUVERNAIL_REPO_URL" "$TMP_SOURCE" 2>/dev/null; then
    rm -rf "$TMP_SOURCE"; TMP_SOURCE=""
    return 1
  fi
  SOURCE="$TMP_SOURCE"
}

# lire_marqueur : affiche le hash enregistré ; échoue s'il est absent/invalide.
lire_marqueur() {
  local file="$ROOT/$MARQUEUR_REL" hash
  [ -f "$file" ] || die "marqueur absent ($MARQUEUR_REL) — lancer : scripts/aligne-gouvernail.sh marqueur ecrire"
  hash="$(head -n 1 "$file" | tr -d '[:space:]')"
  case "$hash" in
    ''|*[!0-9a-f]*) die "marqueur invalide dans $MARQUEUR_REL : '$hash'" ;;
  esac
  [ "${#hash}" -ge 7 ] && [ "${#hash}" -le 40 ] || die "marqueur invalide dans $MARQUEUR_REL : '$hash'"
  echo "$hash"
}

ecrire_marqueur() {
  resolve_source reseau || die "source Gouvernail introuvable (GOUVERNAIL_SOURCE='${GOUVERNAIL_SOURCE:-$ROOT/../gouvernail}', clone de $GOUVERNAIL_REPO_URL impossible)"
  if [ "$SOURCE" = "$ROOT" ]; then
    echo "Ce dépôt est la source Gouvernail : pas de marqueur à écrire."
    return 0
  fi
  local hash
  hash="$(git -C "$SOURCE" rev-parse HEAD)"
  mkdir -p "$ROOT/.claude"
  echo "$hash" > "$ROOT/$MARQUEUR_REL"
  echo "Marqueur écrit : $hash"
}

cmd_marqueur() {
  case "${1:-}" in
    lire)   lire_marqueur ;;
    ecrire) ecrire_marqueur ;;
    *)      usage; die "marqueur : 'lire' ou 'ecrire' attendu" ;;
  esac
}

if [ "${1:-}" = "--racine" ]; then
  [ $# -ge 2 ] && [ -d "$2" ] || die "--racine attend un dossier existant"
  ROOT="$(cd "$2" && pwd)"
  shift 2
fi

case "${1:-}" in
  marqueur) shift; cmd_marqueur "$@" ;;
  -h|--help|'') usage ;;
  *) usage; die "commande inconnue : $1" ;;
esac
