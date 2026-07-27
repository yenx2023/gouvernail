---
name: tache
description: Démarre le cycle de vie d'une tâche à partir d'une issue GitLab existante — lit l'issue via l'API et crée la branche GitHub correspondante selon la convention du projet. Usage : /tache <numero-issue> [--projet <groupe>/<projet>]
---

# tache

## Objectif

Faire le pont entre une issue GitLab déjà créée (par `/backlog-gitlab` ou
manuellement) et le travail de code sur GitHub : lire l'issue, en déduire un
nom de branche conforme à la convention du projet, et créer cette branche
localement. Correspond à l'étape 2 du "Cycle de vie d'une tâche" (voir
CLAUDE.md).

Ce skill ne committe jamais, ne pousse jamais, et ne modifie jamais l'issue
GitLab — il ne fait que lire l'issue et créer une branche locale.

## Convention de branche (rappel, voir CLAUDE.md)

Format : `<type>/<numero-issue-gitlab>-<slug-court>`, avec `type` parmi
`feature`, `fix`, `chore`. Le numéro d'issue est obligatoire : c'est le seul
lien traçable entre le travail GitHub et le work item GitLab.

## Prérequis

- `GITLAB_TOKEN` configuré (`.env` local ou variable d'environnement Cloud).
  Si `scripts/gitlab-api.sh` échoue avec "GITLAB_TOKEN absent", s'arrêter et
  demander à l'utilisateur de le configurer.
- Le projet GitLab cible se résout par défaut depuis
  `.claude/gitlab-project.env` (`GITLAB_PROJECT_PATH`/`GITLAB_PROJECT_ID`) —
  jamais redemandé à l'utilisateur si ce fichier existe (voir CLAUDE.md >
  Réutiliser ce framework pour un nouveau projet). L'option `--projet
  <groupe>/<projet>` reste disponible pour **surcharger** explicitement ce
  défaut (ex. issue exceptionnellement portée par un autre projet) ; dans ce
  cas, présenter la substitution à l'utilisateur pour confirmation avant de
  continuer. Si `.claude/gitlab-project.env` est absent et qu'aucun
  `--projet` n'est fourni, demander le chemin à l'utilisateur — jamais
  deviner ou réutiliser un projet d'une session précédente sans confirmation.
- L'arbre de travail git local doit être propre (`git status` sans
  modification en cours). S'il ne l'est pas, s'arrêter et demander à
  l'utilisateur de committer ou stasher avant de continuer — ne jamais
  stash/commit à sa place.

## Étapes

1. **Identifier l'issue et le projet.** Par défaut, `source
   .claude/gitlab-project.env` et utiliser `GITLAB_PROJECT_PATH`/
   `GITLAB_PROJECT_ID` directement (pas d'appel API nécessaire pour résoudre
   l'`id`, il est déjà dans le fichier). Si `--projet <groupe>/<projet>` a
   été fourni explicitement (surcharge du défaut) ou si le fichier est
   absent, résoudre l'`id` numérique via
   `gitlab_rest GET "projects/<groupe>%2F<projet>"` (champ `id`).

2. **Lire l'issue** via REST :
   ```
   scripts/gitlab-api.sh rest GET "projects/<project_id>/issues/<numero>"
   ```
   Si l'appel échoue (issue inexistante, etc.), s'arrêter et rapporter
   l'erreur — ne pas continuer sur une hypothèse.

3. **Déterminer le type de branche** (`feature`/`fix`/`chore`) à partir des
   labels et du titre de l'issue (ex. label `bug` → `fix`). En l'absence
   d'indice clair, proposer `feature` par défaut. Dans tous les cas,
   présenter le type déduit à l'utilisateur pour confirmation avant de
   continuer — ne jamais trancher silencieusement une ambiguïté.

4. **Générer un slug court** à partir du titre de l'issue : minuscules,
   sans accents, mots séparés par des tirets, limité à 4-5 mots
   significatifs (ex. "Générer le PDF côté serveur" → `generer-pdf-serveur`).

5. **Composer le nom de branche** `<type>/<numero>-<slug>` et le présenter à
   l'utilisateur. Attendre sa validation avant de créer quoi que ce soit
   (l'utilisateur peut ajuster le slug ou le type proposés).

6. **Vérifier l'état du dépôt local** : `git status` doit être propre.
   S'assurer d'être sur la branche principale (`main`) et à jour avec
   `origin/main` (`git fetch origin && git status`) ; si la branche locale
   est en retard, proposer un `git pull` avant de continuer plutôt que de
   créer la branche sur une base obsolète.

7. **Créer la branche localement** : `git checkout -b <type>/<numero>-<slug>`.
   Ne pas pousser (`git push`) — la branche reste locale tant que
   l'utilisateur n'a pas donné la phrase de validation explicite (voir skill
   `/livre` et CLAUDE.md > Cycle de vie d'une tâche).

8. **Récapituler** à l'utilisateur : branche créée, issue liée (numéro +
   `web_url`), et rappeler que le développement peut commencer — commit,
   push et Merge Request GitLab n'auront lieu qu'après une phrase de
   validation explicite ("tu peux commiter" / "tu peux commiter et merger",
   voir le skill `/livre` et CLAUDE.md > Cycle de vie d'une tâche).

## Ce que ce skill ne doit jamais faire seul

- Committer ou pousser (`git commit`, `git push`) — hors périmètre, géré par
  le skill `/livre` sur validation explicite de l'utilisateur.
- Modifier, commenter ou fermer l'issue GitLab — ce skill ne fait que la lire.
- Stash ou committer des modifications en cours à la place de l'utilisateur
  si l'arbre de travail n'est pas propre.
- Deviner le projet GitLab cible ou le type de branche sans confirmation
  explicite de l'utilisateur.
- Créer la branche si l'appel de lecture de l'issue a échoué.
