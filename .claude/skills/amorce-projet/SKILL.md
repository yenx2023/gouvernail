---
name: amorce-projet
description: Amorce un nouveau projet réutilisant le framework Gouvernail — crée le projet GitLab (et le dépôt GitHub si nécessaire) dédiés, copie l'outillage (skills, scripts, doctrine) vers un nouveau répertoire local, adapté au profil choisi. Usage : /amorce-projet <chemin-cible> [--profil conception|produit-tiers] [--regime deploye|distribue] [--nom <nom-projet>] [--description "..."] [--sous-groupe <produit>] [--github]
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
`/backlog-gitlab`, `/tache`, `/livre`, `/cloture`, et selon le profil
`/cadre`/`/planifie` ou `/absorbe`/`/registre`/`/piege`) : c'est un outil
méta qui vit uniquement dans Gouvernail, pour créer d'autres projets à
partir de ce dépôt.

Conçu à partir d'un précédent réel (`todo-cli`, premier projet amorcé
manuellement avec ce framework) : mêmes fichiers copiés, même structure de
`CLAUDE.md`, même séquence git (commit de genèse direct sur `main`, seule
exception documentée à l'interdit de commit direct).

## Profils

Deux profils déterminent quel outillage est copié et quel `CLAUDE.md` est
généré — voir CLAUDE.md > Réutiliser ce framework pour un nouveau projet
pour la logique complète des profils :

| | `conception` (défaut) | `produit-tiers` |
|---|---|---|
| Cas d'usage | Le produit est conçu ici, cahier des charges → application livrée | Le produit existe déjà chez un fournisseur tiers, ce projet le personnalise et absorbe ses mises à jour |
| Document pivot | `docs/PRD.md` puis `docs/PLAN.md`, écrits par `/cadre`/`/planifie` | `docs/REGISTRE.md`, créé vide à l'amorçage |
| Skills spécifiques copiés | `cadre`, `planifie` | `absorbe`, `registre`, `piege` |
| `CLAUDE.md` généré depuis | `references/CLAUDE.md.template` | `references/CLAUDE.md.produit-tiers.template` |
| GitHub | Toujours créé (façade Claude Code Cloud, voir Doctrine) | Optionnel — GitLab seul par défaut, `--github` pour l'ajouter (voir Étape 12bis) |
| `--regime` | Non applicable | `deploye` (environnements + stratégie de déploiement contrôlée) ou `distribue` (versions, stores/packages) — voir Étape 1 |

Si `--profil` est absent, demander explicitement à l'utilisateur plutôt que
de supposer `conception` par défaut sans confirmation — les deux profils
divergent trop pour deviner.

## Prérequis

- Invoqué depuis une session Claude Code ouverte sur **ce dépôt**
  (Gouvernail) — le skill copie ses propres fichiers vers la cible.
- `GITLAB_TOKEN` déjà configuré dans le `.env` local de Gouvernail. Si
  `scripts/gitlab-api.sh` échoue avec "GITLAB_TOKEN absent", s'arrêter et
  demander à l'utilisateur de le configurer.
- `gh auth status` doit réussir **si le profil implique GitHub**
  (`conception`, ou `produit-tiers --github`). Pour `produit-tiers` sans
  `--github`, cette vérification est sautée entièrement. Sinon, s'arrêter
  et demander à l'utilisateur de s'authentifier (`gh auth login`) avant de
  continuer.
- Chemin cible fourni en argument. Si absent, demander à l'utilisateur.
- **Garde-fou anti-écrasement** : si le chemin cible existe déjà et contient
  déjà `.git/` ou `.claude/skills/`, s'arrêter immédiatement et rapporter
  pourquoi — jamais d'écrasement d'un projet déjà amorcé ou de travail en
  cours. Un répertoire absent ou vide est le seul cas accepté sans
  confirmation supplémentaire.

## Étapes

1. **Résoudre le profil et le chemin cible**, et en déduire un slug par
   défaut (dernier segment du chemin, ex. `../mon-projet` → `mon-projet`).
   **Présenter à l'utilisateur pour confirmation** avant toute action
   mutante :
   - profil (`conception` ou `produit-tiers`) — demander si absent de
     l'invocation,
   - **si `produit-tiers`** : régime (`deploye`/`distribue` — demander si
     absent, voir tableau Profils), nom du produit tiers personnalisé
     ({{PRODUIT_NOM}}) et son URL de référence ({{PRODUIT_URL}}, ex. page
     marketplace/documentation officielle) — nécessaires pour générer
     `CLAUDE.md`,
   - **si plusieurs dépôts pour un même produit tiers** (ex. backend +
     mobile d'un même produit) : chaque dépôt s'amorce séparément, avec son
     propre régime le cas échéant (voir CLAUDE.md > Produit multi-dépôts) —
     `--sous-groupe <produit>` reste la bonne façon de les regrouper côté
     GitLab,
   - nom du dépôt GitHub (`<owner>/<slug>`, toujours à plat) **si GitHub
     fait partie du profil résolu**,
   - chemin du projet GitLab (`ai-agent-projects/<slug>`, ou
     `ai-agent-projects/<sous-groupe>/<slug>` si `--sous-groupe <produit>`
     est fourni),
   - visibilité (privé par défaut sur les deux plateformes).
   Attendre la validation. Ajuster slug/nom si l'utilisateur le demande.

2. **Résoudre l'id du groupe/sous-groupe GitLab** cible (une seule fois,
   pas de cache entre invocations) :
   - **Sans `--sous-groupe`** : résoudre l'id du groupe `ai-agent-projects` :
     ```
     scripts/gitlab-api.sh graphql \
       'query($fullPath: ID!) { namespace(fullPath: $fullPath) { id } }' \
       '{"fullPath":"ai-agent-projects"}'
     ```
   - **Avec `--sous-groupe <produit>`** : résoudre d'abord l'id de
     `ai-agent-projects/<produit>` avec la même requête (`fullPath`
     substitué). S'il existe déjà (produit dont un premier dépôt a déjà été
     amorcé), réutiliser directement cet id. S'il n'existe pas (`namespace`
     renvoyé `null`), résoudre l'id du groupe parent `ai-agent-projects`
     (requête ci-dessus), **présenter la création du sous-groupe à
     l'utilisateur pour confirmation** (action mutante externe, comme la
     création de projet/dépôt), puis :
     ```
     scripts/gitlab-api.sh rest POST "groups" \
       '{"name":"<produit>","path":"<produit>","parent_id":<id_groupe_parent>,"visibility":"private"}'
     ```
     Utiliser l'`id` renvoyé comme groupe cible pour l'étape suivante. Si la
     création échoue (permissions insuffisantes, nom déjà pris), s'arrêter
     et rapporter — ne jamais retomber silencieusement sur le chemin plat.

3. **Créer le projet GitLab**, sous le groupe ou sous-groupe résolu à
   l'étape précédente :
   ```
   scripts/gitlab-api.sh rest POST "projects" \
     '{"name":"<slug>","path":"<slug>","namespace_id":<id_groupe_ou_sous_groupe>,"visibility":"private"}'
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
     '{"projectPath":"<path_with_namespace de l'\''étape 3>","title":"Amorçage de l'\''outillage Gouvernail","description":"Copie de l'\''outillage réutilisable depuis le framework Gouvernail (profil <profil résolu>), via /amorce-projet."}'
   ```
   `projectPath` = `path_with_namespace` renvoyé à l'étape 3 — jamais
   recomposé à la main. Vérifier `errors` ; si non vide, s'arrêter et
   rapporter.

5. **Préparer le répertoire cible** : `mkdir -p <chemin>` si absent, puis
   `git init` si ce n'est pas déjà un dépôt git (déjà vérifié absent de
   travail existant au prérequis).

6. **Copier l'outillage** vers la cible :
   - **Socle commun aux deux profils** : `.claude/skills/backlog-gitlab/`,
     `.claude/skills/tache/`, `.claude/skills/livre/`,
     `.claude/skills/cloture/`, `.claude/skills/interroge/`,
     `.claude/skills/investigue/`, `.claude/skills/illustre/`,
     `.claude/skills/design/`, `.claude/skills/eprouve/`,
     `.claude/skills/LICENSE-claude-mastery`. `/eprouve` (validation E2E
     Maestro, voir `CLAUDE.md.template` > Tests) n'a d'usage réel que sur
     un projet à surface visuelle/interactive (mobile, frontend web) mais
     reste copié sans condition, comme `/design`/`/illustre` — il ne sera
     simplement jamais invoqué sur un projet qui n'en a pas l'usage.
   - **Si profil `conception`** : ajouter `.claude/skills/cadre/`,
     `.claude/skills/planifie/`.
   - **Si profil `produit-tiers`** : ajouter `.claude/skills/absorbe/`,
     `.claude/skills/registre/`, `.claude/skills/piege/`.
   - `scripts/gitlab-api.sh`
   - `tests/gitlab-api.test.sh`
   - `.env.example`
   - `.gitignore`
   - **Jamais** `amorce-projet/` lui-même, quel que soit le profil.

7. **Générer `CLAUDE.md`** dans la cible :
   - **Profil `conception`** : depuis
     `.claude/skills/amorce-projet/references/CLAUDE.md.template`, en
     substituant `{{PROJET_NOM}}` et `{{PROJET_DESCRIPTION}}` (fournie via
     `--description`, sinon un placeholder explicite type "À compléter —
     voir /cadre").
   - **Profil `produit-tiers`** : depuis
     `.claude/skills/amorce-projet/references/CLAUDE.md.produit-tiers.template`,
     en substituant `{{PROJET_NOM}}`, `{{PROJET_DESCRIPTION}}`,
     `{{PRODUIT_NOM}}`, `{{PRODUIT_URL}}` (résolus à l'Étape 1), puis :
     - `{{ACCES_SECTION}}` : contenu intégral de
       `references/acces-gitlab-github.md` si `--github`, sinon
       `references/acces-gitlab-seul.md` (défaut),
     - `{{REGIME_GIT_SECTION}}` : contenu intégral de
       `references/regime-deploye.md` ou `references/regime-distribue.md`
       selon `--regime` résolu à l'Étape 1.

8. **Créer `docs/JOURNAL.md`** dans la cible avec l'en-tête standard, quel
   que soit le profil :
   ```
   # Journal

   Journal chronologique des tâches livrées (une entrée par clôture réelle —
   voir CLAUDE.md > Mémoire de session).
   ```
   **Si profil `produit-tiers`**, créer en plus `docs/REGISTRE.md` :
   ```
   # Registre de divergence

   Chaque divergence de ce projet par rapport à {{PRODUIT_NOM}} (personnalisation,
   correctif préservé, contournement) — une entrée par divergence, référencée
   par numéro d'issue GitLab. Alimenté par le skill /registre. Voir CLAUDE.md
   > Produit tiers & registre de divergence.
   ```

9. **Créer `.claude/gitlab-project.env`** dans la cible :
   ```
   # Identité du projet GitLab associé à CE dépôt.
   # Pas de secret ici, ce fichier est committé.
   GITLAB_PROJECT_PATH=ai-agent-projects/<slug>
   GITLAB_PROJECT_ID=<id du projet créé à l'étape 3>
   ```
   (chemin exact = `path_with_namespace` renvoyé à l'étape 3 — inclut le
   sous-groupe, ex. `ai-agent-projects/<produit>/<slug>`, si `--sous-groupe`
   a été utilisé).

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

12. **Créer le dépôt GitHub** — **uniquement si le profil résolu implique
    GitHub** (`conception`, ou `produit-tiers --github`) — **demander
    confirmation explicite avant cette étape** (action visible/externe) :
    ```
    gh repo create <owner>/<slug> --private --source=<chemin_cible> --remote=origin
    ```
    **Si `produit-tiers` sans `--github`** : sauter entièrement cette
    étape — pas de remote `origin` GitHub, `origin` pointera directement
    vers GitLab à l'étape suivante.

13. **Pousser `main`** :
    - **Si GitHub fait partie du profil résolu** : vers GitHub
      (`git push origin main`) et vers GitLab (depuis la cible, avec son
      propre `scripts/gitlab-api.sh` et son propre
      `.claude/gitlab-project.env`/`.env` copiés aux étapes 6/9/10) :
      ```
      git push origin main
      ./scripts/gitlab-api.sh push main main
      ```
    - **Si GitLab seul** (`produit-tiers` sans `--github`) : configurer
      `origin` directement vers GitLab (SSH, cohérent avec les autres
      projets GitLab du même groupe) puis pousser normalement :
      ```
      git remote add origin git@gitlab.com:<path_with_namespace>.git
      git push -u origin main
      ```

14. **Récapituler** à l'utilisateur : chemin local, URL du dépôt GitHub
    (si créé), URL du projet GitLab, issue #1 ouverte (`web_url`). Rappeler
    que toutes les tâches suivantes (y compris la clôture de l'issue #1
    elle-même, via `/cloture`) suivent désormais le cycle de vie standard —
    plus de commit direct sur `main`. Suggérer l'étape suivante :
    - **Profil `conception`** : ouvrir une session Claude Code dans ce
      nouveau répertoire et lancer `/cadre` pour cadrer le projet.
    - **Profil `produit-tiers`** : ouvrir une session Claude Code dans ce
      nouveau répertoire, amorcer un skill produit dédié (architecture,
      guides, `references/pieges.md` — non fourni par Gouvernail,
      spécifique au produit tiers personnalisé), puis lancer `/absorbe`
      dès la première montée de version à traiter.

## Ce que ce skill ne doit jamais faire seul

- Écraser un répertoire cible déjà initialisé (déjà un `.git/` ou déjà
  amorcé) — s'arrêter dès le prérequis correspondant.
- Créer le dépôt GitHub, le projet GitLab ou le sous-groupe GitLab
  (`--sous-groupe`) sans confirmation explicite de l'utilisateur sur le
  nom/slug et la visibilité.
- Créer un dépôt GitHub pour un profil `produit-tiers` sans `--github`
  explicite — GitLab seul est le défaut de ce profil.
- Committer directement sur `main` en dehors de ce commit de genèse unique
  — toute tâche suivante dans le nouveau projet passe par `/tache` + `/livre`.
- Afficher le token GitLab en clair dans la conversation ou un log.
- Créer le PRD/PLAN, peupler le backlog, ou pré-remplir `docs/REGISTRE.md`
  du nouveau projet — hors périmètre, voir les skills dédiés (déjà copiés
  dans la cible selon le profil, prêts à être utilisés depuis une session
  ouverte là-bas).
- Résoudre `--profil` ou `--regime` par défaut sans confirmation explicite
  de l'utilisateur quand ils sont absents de l'invocation.
