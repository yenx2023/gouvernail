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
#   audit              rapport en LECTURE SEULE : outillage manquant/périmé,
#                      CONTEXT.md trop long, journal trop long, DESIGN.md
#                      monolithique, règles de lecture absentes, version en
#                      retard. Code retour 1 s'il y a quelque chose à faire.
#   audit --court      une seule ligne s'il y a quelque chose à faire, rien
#                      sinon, jamais d'accès réseau (pour un hook de démarrage)
#   outillage [--simule]  copie l'outillage mécanique manquant ou périmé. Une
#                      copie MODIFIÉE localement (ou sans base de comparaison)
#                      n'est jamais écrasée : son diff est affiché.
#   donnees [--simule]    archive les entrées anciennes du journal
#                      (scripts/archive-journal.sh)
#
# Ces commandes ne modifient que l'arbre de travail : jamais de commit, jamais
# de push (la livraison passe par /livre). --simule n'écrit rien.
#
# Source de Gouvernail : variable GOUVERNAIL_SOURCE (défaut : dépôt voisin
# ../gouvernail) ; à défaut, clone temporaire de GOUVERNAIL_REPO_URL (par
# exemple en session Cloud, où le dépôt voisin n'existe pas).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARQUEUR_REL=".claude/gouvernail-version"
GOUVERNAIL_REPO_URL="${GOUVERNAIL_REPO_URL:-https://github.com/yenx2023/gouvernail}"

# Seuils d'optimisation (voir CLAUDE.md > Mémoire de session)
CONTEXT_MAX_OCTETS=6000
JOURNAL_MAX_ENTREES=15
DESIGN_INDEX_MAX_OCTETS=18000

# Skills du socle commun, copiés quel que soit le profil. Les skills propres à
# un profil (cadre, planifie, absorbe, registre, piege) ne sont suivis que
# s'ils sont déjà présents dans le projet : l'alignement n'impose jamais un
# profil.
SKILLS_SOCLE="backlog-gitlab tache livre cloture interroge investigue illustre design eprouve aligne"
SKILLS_PROFIL="cadre planifie absorbe registre piege"

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

# liste_outillage : chemins relatifs (fichiers mécaniques) à suivre, d'après la
# SOURCE. Ne liste que ce qui existe dans la source.
liste_outillage() {
  local rel name
  for rel in scripts/gitlab-api.sh scripts/mesure-contexte.sh scripts/archive-journal.sh \
             scripts/aligne-gouvernail.sh tests/gitlab-api.test.sh tests/mesure-contexte.test.sh \
             tests/archive-journal.test.sh tests/modeles.test.sh tests/aligne-gouvernail.test.sh \
             .claude/skills/LICENSE-claude-mastery; do
    [ -f "$SOURCE/$rel" ] && echo "$rel"
  done
  [ -d "$SOURCE/.claude/agents" ] && (cd "$SOURCE" && find .claude/agents -type f | sort)
  for name in $SKILLS_SOCLE; do
    [ -d "$SOURCE/.claude/skills/$name" ] && (cd "$SOURCE" && find ".claude/skills/$name" -type f | sort)
  done
  for name in $SKILLS_PROFIL; do
    if [ -d "$SOURCE/.claude/skills/$name" ] && [ -d "$ROOT/.claude/skills/$name" ]; then
      (cd "$SOURCE" && find ".claude/skills/$name" -type f | sort)
    fi
  done
  return 0
}

# statut_fichier <rel> : manquant | ok | perime | modifie | different
#   perime    le projet a la copie d'origine (celle du marqueur), la source a changé
#   modifie   le projet a modifié sa copie localement
#   different diverge de la source, sans base de comparaison (pas de marqueur)
statut_fichier() {
  local rel="$1" base=""
  [ -f "$ROOT/$rel" ] || { echo manquant; return; }
  cmp -s "$SOURCE/$rel" "$ROOT/$rel" && { echo ok; return; }
  base="$(lire_marqueur 2>/dev/null)" || base=""
  if [ -n "$base" ] && git -C "$SOURCE" cat-file -e "$base^{commit}" 2>/dev/null \
     && git -C "$SOURCE" cat-file -e "$base:$rel" 2>/dev/null; then
    if git -C "$SOURCE" show "$base:$rel" | cmp -s - "$ROOT/$rel"; then echo perime; else echo modifie; fi
  else
    echo different
  fi
}

# audit [--court]
cmd_audit() {
  local court="non" findings=0 lines=() info=() size n rel st
  [ "${1:-}" = "--court" ] && court="oui"
  [ -f "$ROOT/CLAUDE.md" ] || die "$ROOT/CLAUDE.md introuvable — ce n'est pas un dépôt outillé Gouvernail."

  # --- Contrôles locaux (aucune source nécessaire) -------------------------
  if [ -f "$ROOT/docs/CONTEXT.md" ]; then
    size=$(wc -c < "$ROOT/docs/CONTEXT.md" | tr -d ' ')
    if [ "$size" -gt "$CONTEXT_MAX_OCTETS" ]; then
      findings=$((findings + 1))
      lines+=("docs/CONTEXT.md : $size octets (cible ≈ $CONTEXT_MAX_OCTETS) — à condenser")
    fi
  fi
  if [ -f "$ROOT/docs/JOURNAL.md" ]; then
    n=$(grep -c '^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' "$ROOT/docs/JOURNAL.md" || true)
    if [ "$n" -gt "$JOURNAL_MAX_ENTREES" ]; then
      findings=$((findings + 1))
      lines+=("docs/JOURNAL.md : $n entrées (seuil $JOURNAL_MAX_ENTREES) — à archiver (scripts/archive-journal.sh)")
    fi
  fi
  if [ -f "$ROOT/docs/DESIGN.md" ] && [ ! -d "$ROOT/docs/design" ]; then
    size=$(wc -c < "$ROOT/docs/DESIGN.md" | tr -d ' ')
    if [ "$size" -gt "$DESIGN_INDEX_MAX_OCTETS" ]; then
      findings=$((findings + 1))
      lines+=("docs/DESIGN.md monolithique : $size octets, pas de docs/design/ — à migrer vers index + fichiers par thème (/design, option migrer)")
    fi
  fi
  if ! grep -q "Règle de lecture de début de session" "$ROOT/CLAUDE.md"; then
    findings=$((findings + 1))
    lines+=("CLAUDE.md : règle de lecture de début de session absente — à reporter (CLAUDE.md > Mémoire de session de Gouvernail)")
  fi
  if ! [ -f "$ROOT/$MARQUEUR_REL" ]; then
    findings=$((findings + 1))
    lines+=("$MARQUEUR_REL absent — version de Gouvernail inconnue (scripts/aligne-gouvernail.sh marqueur ecrire)")
  fi

  # --- Contrôles qui demandent la source Gouvernail ------------------------
  local source_ok="non" mode_reseau="non"
  [ "$court" = "oui" ] || mode_reseau="reseau"
  if resolve_source "$mode_reseau"; then source_ok="oui"; fi

  if [ "$source_ok" = "oui" ] && [ "$SOURCE" = "$ROOT" ]; then
    info+=("ce dépôt est la source Gouvernail : comparaison d'outillage sans objet")
  elif [ "$source_ok" = "oui" ]; then
    local mine head behind manquants=0 perimes=0 modifies=0 differents=0
    head="$(git -C "$SOURCE" rev-parse HEAD)"
    if mine="$(lire_marqueur 2>/dev/null)"; then
      if [ "$mine" != "$head" ] && [ "${head#"$mine"}" = "$head" ]; then
        if git -C "$SOURCE" cat-file -e "$mine^{commit}" 2>/dev/null; then
          behind="$(git -C "$SOURCE" rev-list --count "$mine..$head")"
          findings=$((findings + 1))
          lines+=("version en retard : marqueur ${mine:0:7}, Gouvernail ${head:0:7} ($behind commit(s) d'avance)")
        else
          findings=$((findings + 1))
          lines+=("marqueur ${mine:0:7} inconnu de la source (${head:0:7}) — à réenregistrer après alignement")
        fi
      fi
    fi
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      st="$(statut_fichier "$rel")"
      case "$st" in
        manquant)  manquants=$((manquants + 1)) ;;
        perime)    perimes=$((perimes + 1)) ;;
        modifie)   modifies=$((modifies + 1)) ;;
        different) differents=$((differents + 1)) ;;
      esac
    done < <(liste_outillage)
    if [ "$manquants" -gt 0 ]; then
      findings=$((findings + 1)); lines+=("outillage manquant : $manquants fichier(s)")
    fi
    if [ "$perimes" -gt 0 ]; then
      findings=$((findings + 1)); lines+=("outillage périmé : $perimes fichier(s) (copie d'origine, la source a évolué)")
    fi
    [ "$differents" -gt 0 ] && info+=("$differents fichier(s) d'outillage diffèrent de la source, sans marqueur pour trancher — à comparer")
    [ "$modifies" -gt 0 ] && info+=("$modifies fichier(s) d'outillage modifié(s) localement : jamais écrasés automatiquement")
  else
    info+=("source Gouvernail introuvable : outillage et version non comparés (GOUVERNAIL_SOURCE)")
  fi

  # --- Sortie --------------------------------------------------------------
  if [ "$court" = "oui" ]; then
    [ "$findings" -eq 0 ] || echo "Gouvernail : $findings optimisation(s) disponible(s) — lance /aligne (détail : scripts/aligne-gouvernail.sh audit)"
    return 0
  fi
  echo "Audit Gouvernail — $ROOT"
  local l
  for l in "${lines[@]+"${lines[@]}"}"; do echo "  [!] $l"; done
  for l in "${info[@]+"${info[@]}"}"; do echo "  [i] $l"; done
  if [ "$findings" -eq 0 ]; then echo "Rien à signaler."; return 0; fi
  echo "$findings point(s) à traiter."
  return 1
}

# outillage [--simule]
cmd_outillage() {
  local simule="non" rel st copies=0 maj=0 gardes=0 verbe
  case "${1:-}" in
    --simule) simule="oui" ;;
    '') ;;
    *) usage; die "outillage : option inconnue '$1'" ;;
  esac
  resolve_source reseau || die "source Gouvernail introuvable (GOUVERNAIL_SOURCE='${GOUVERNAIL_SOURCE:-$ROOT/../gouvernail}', clone de $GOUVERNAIL_REPO_URL impossible)"
  [ "$SOURCE" != "$ROOT" ] || die "ce dépôt est la source Gouvernail : rien à aligner"
  [ "$simule" = "non" ] || echo "(simulation : aucun fichier écrit)"

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    st="$(statut_fichier "$rel")"
    case "$st" in
      manquant|perime)
        [ "$st" = "manquant" ] && { verbe="ajouté"; copies=$((copies + 1)); } || { verbe="mis à jour"; maj=$((maj + 1)); }
        echo "  $verbe : $rel"
        if [ "$simule" = "non" ]; then
          mkdir -p "$(dirname "$ROOT/$rel")"
          cp -p "$SOURCE/$rel" "$ROOT/$rel"
        fi ;;
      modifie|different)
        gardes=$((gardes + 1))
        if [ "$st" = "modifie" ]; then
          echo "  CONSERVÉ (modifié localement) : $rel"
        else
          echo "  CONSERVÉ (diffère de la source, pas de marqueur pour trancher) : $rel"
        fi
        diff -u --label "projet:$rel" --label "gouvernail:$rel" "$ROOT/$rel" "$SOURCE/$rel" | head -40 || true ;;
    esac
  done < <(liste_outillage)

  echo "Outillage : $copies ajouté(s), $maj mis à jour, $gardes conservé(s)."
  [ "$gardes" -eq 0 ] || echo "Les fichiers conservés se comparent et se fusionnent à la main (skill /aligne)."
  return 0
}

# donnees [--simule]
cmd_donnees() {
  local simule="non" journal="$ROOT/docs/JOURNAL.md" archiveur="$ROOT/scripts/archive-journal.sh" n
  case "${1:-}" in
    --simule) simule="oui" ;;
    '') ;;
    *) usage; die "donnees : option inconnue '$1'" ;;
  esac
  [ -f "$journal" ] || { echo "Pas de docs/JOURNAL.md : rien à archiver."; return 0; }
  [ -f "$archiveur" ] || die "scripts/archive-journal.sh absent — lancer d'abord : scripts/aligne-gouvernail.sh outillage"
  if [ "$simule" = "oui" ]; then
    n=$(grep -c '^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' "$journal" || true)
    echo "(simulation) journal : $n entrée(s), seuil $JOURNAL_MAX_ENTREES — rien n'est écrit."
    return 0
  fi
  bash "$archiveur" "$journal"
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
  audit) shift; cmd_audit "$@" ;;
  outillage) shift; cmd_outillage "$@" ;;
  donnees) shift; cmd_donnees "$@" ;;
  -h|--help|'') usage ;;
  *) usage; die "commande inconnue : $1" ;;
esac
