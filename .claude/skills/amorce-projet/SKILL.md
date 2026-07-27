---
name: amorce-projet
description: Amorce un nouveau projet réutilisant le framework Gouvernail — crée le projet GitLab et le dépôt GitHub dédiés, copie l'outillage (skills, scripts, doctrine) vers un nouveau répertoire local. Usage : /amorce-projet <chemin-cible> [--nom <nom-projet>] [--description "..."]
---

# amorce-projet

## Objectif

Automatiser la section "Réutiliser ce framework pour un nouveau projet" de
`CLAUDE.md`, jusqu'ici 100% manuelle. Reste **semi-automatisé** : chaque
action mutante externe (création de projet GitLab, création de dépôt
GitHub, push) est présentée à l'utilisateur pour confirmation avant
exécution — ce skill ne remplace pas la validation humaine, il élimine la
répétition mécanique.

**Ce skill n'est jamais copié dans les nouveaux projets** (contrairement à
`/backlog-gitlab`, `/tache`, `/livre`, `/cloture`) : c'est un outil méta qui
vit uniquement dans Gouvernail, pour créer d'autres projets à partir de ce
dépôt.

Conçu à partir d'un précédent réel (`todo-cli`, premier projet amorcé
manuellement avec ce framework) : mêmes fichiers copiés, même structure de
`CLAUDE.md`, même séquence git (commit de genèse direct sur `main`, seule
exception documentée à l'interdit de commit direct).

## Prérequis

- Invoqué depuis une session Claude Code ouverte sur **ce dépôt**
  (Gouvernail) — le skill copie ses propres fichiers vers la cible.
- `GITLAB_TOKEN` déjà configuré dans le `.env` local de Gouvernail. Si
  `scripts/gitlab-api.sh` échoue avec "GITLAB_TOKEN absent", s'arrêter et
  demander à l'utilisateur de le configurer.
- `gh auth status` doit réussir. Sinon, s'arrêter et demander à
  l'utilisateur de s'authentifier (`gh auth login`) avant de continuer.
- Chemin cible fourni en argument. Si absent, demander à l'utilisateur.
- **Garde-fou anti-écrasement** : si le chemin cible existe déjà et contient
  déjà `.git/` ou `.claude/skills/`, s'arrêter immédiatement et rapporter
  pourquoi — jamais d'écrasement d'un projet déjà amorcé ou de travail en
  cours. Un répertoire absent ou vide est le seul cas accepté sans
  confirmation supplémentaire.

## Étapes

1. **Résoudre le chemin cible** et en déduire un slug par défaut (dernier
   segment du chemin, ex. `../mon-projet` → `mon-projet`). **Présenter à
   l'utilisateur pour confirmation** avant toute action mutante :
   - nom du dépôt GitHub (`<owner>/<slug>`),
   - chemin du projet GitLab (`ai-agent-projects/<slug>`),
   - visibilité (privé par défaut sur les deux plateformes).
   Attendre la validation. Ajuster slug/nom si l'utilisateur le demande.

2. **Résoudre l'id du groupe GitLab** `ai-agent-projects` (une seule fois,
   pas de cache entre invocations) :
   ```
   scripts/gitlab-api.sh graphql \
     'query($fullPath: ID!) { namespace(fullPath: $fullPath) { id } }' \
     '{"fullPath":"ai-agent-projects"}'
   ```

3. **Créer le projet GitLab** :
   ```
   scripts/gitlab-api.sh rest POST "projects" \
     '{"name":"<slug>","path":"<slug>","namespace_id":<id_groupe>,"visibility":"private"}'
   ```
   Conserver `id` et `path_with_namespace` de la réponse. Si la création
   échoue (nom déjà pris, permissions), s'arrêter et rapporter — ne jamais
   deviner un projet existant à réutiliser à sa place.

4. **Créer l'issue #1 de suivi** sur ce nouveau projet, via GraphQL (même
   mutation que `/backlog-gitlab`) :
   ```
   scripts/gitlab-api.sh graphql \
     'mutation($projectPath: ID!, $title: String!, $description: String) {
        createIssue(input: { projectPath: $projectPath, title: $title, description: $description }) {
          issue { iid webUrl }
          errors
        }
      }' \
     '{"projectPath":"ai-agent-projects/<slug>","title":"Amorçage de l'\''outillage Gouvernail","description":"Copie de l'\''outillage réutilisable depuis le framework Gouvernail, via /amorce-projet."}'
   ```
   Vérifier `errors` ; si non vide, s'arrêter et rapporter.

5. **Préparer le répertoire cible** : `mkdir -p <chemin>` si absent, puis
   `git init` si ce n'est pas déjà un dépôt git (déjà vérifié absent de
   travail existant au prérequis).

6. **Copier l'outillage** vers la cible :
   - `.claude/skills/` en entier — **tous** les sous-dossiers de skills sauf
     `amorce-projet/` lui-même — plus `LICENSE-claude-mastery`.
   - `scripts/gitlab-api.sh`
   - `tests/gitlab-api.test.sh` (filet de sécurité pour `scripts/gitlab-api.sh`,
     cohérent avec la section "Tests" du gabarit `CLAUDE.md` généré à l'étape
     suivante)
   - `.env.example`
   - `.gitignore`

7. **Générer `CLAUDE.md`** dans la cible à partir de
   `.claude/skills/amorce-projet/references/CLAUDE.md.template`, en
   substituant `{{PROJET_NOM}}` (le slug ou nom donné par l'utilisateur) et
   `{{PROJET_DESCRIPTION}}` (fournie via `--description`, sinon un
   placeholder explicite du type "À compléter — voir /cadre").

8. **Créer `docs/JOURNAL.md`** dans la cible avec l'en-tête standard :
   ```
   # Journal

   Journal chronologique des tâches livrées (une entrée par clôture réelle —
   voir CLAUDE.md > Mémoire de session).
   ```

9. **Créer `.claude/gitlab-project.env`** dans la cible :
   ```
   # Identité du projet GitLab associé à CE dépôt.
   # Pas de secret ici, ce fichier est committé.
   GITLAB_PROJECT_PATH=ai-agent-projects/<slug>
   GITLAB_PROJECT_ID=<id du projet créé à l'étape 3>
   ```
   (chemin exact = `path_with_namespace` renvoyé à l'étape 3).

10. **Copier le token** : lire la valeur de `GITLAB_TOKEN` depuis le `.env`
    local de Gouvernail (lecture fichier, jamais via une commande qui
    l'afficherait comme `cat`/`echo` dans un log visible), et écrire un
    `.env` dans la cible avec cette même valeur plus les mêmes
    `GITLAB_API_URL`/`GITLAB_GRAPHQL_URL`. Ne jamais afficher le token dans
    la conversation.

11. **Commit de genèse, directement sur `main`** de la cible — **seule
    exception documentée** à "jamais de commit direct sur `main`" (voir
    CLAUDE.md > Ce que Claude ne doit jamais faire seul) : c'est la genèse
    du dépôt, rien à review contre (précédent `todo-cli`, commit
    `b559a8f`). Message de commit référençant l'issue #1, ex. "Amorçage de
    l'outillage Gouvernail (issue #1)".

12. **Créer le dépôt GitHub** — **demander confirmation explicite avant
    cette étape** (action visible/externe) :
    ```
    gh repo create <owner>/<slug> --private --source=<chemin_cible> --remote=origin
    ```

13. **Pousser `main`** vers GitHub (`git push origin main`) et vers GitLab
    (depuis la cible, avec son propre `scripts/gitlab-api.sh` et son propre
    `.claude/gitlab-project.env`/`.env` copiés aux étapes 6/9/10) :
    ```
    git push origin main
    ./scripts/gitlab-api.sh push main main
    ```

14. **Récapituler** à l'utilisateur : chemin local, URL du dépôt GitHub, URL
    du projet GitLab, issue #1 ouverte (`web_url`). Rappeler que toutes les
    tâches suivantes (y compris la clôture de l'issue #1 elle-même, via
    `/cloture`) suivent désormais le cycle de vie standard — plus de commit
    direct sur `main`. Suggérer l'étape suivante : ouvrir une session
    Claude Code dans ce nouveau répertoire et lancer `/cadre` pour cadrer le
    projet.

## Ce que ce skill ne doit jamais faire seul

- Écraser un répertoire cible déjà initialisé (déjà un `.git/` ou déjà
  amorcé) — s'arrêter dès le prérequis correspondant.
- Créer le dépôt GitHub ou le projet GitLab sans confirmation explicite de
  l'utilisateur sur le nom/slug et la visibilité.
- Committer directement sur `main` en dehors de ce commit de genèse unique
  — toute tâche suivante dans le nouveau projet passe par `/tache` + `/livre`.
- Afficher le token GitLab en clair dans la conversation ou un log.
- Créer le PRD/PLAN ou peupler le backlog du nouveau projet — hors
  périmètre, voir les skills `/cadre`, `/planifie`, `/backlog-gitlab` (déjà
  copiés dans la cible, prêts à être utilisés depuis une session ouverte
  là-bas).
