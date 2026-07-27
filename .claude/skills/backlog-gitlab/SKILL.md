---
name: backlog-gitlab
description: Convertit un PRD/PLAN (issu de /cadre, /planifie ou équivalent) en Milestones et Issues GitLab via l'API GitLab (REST + GraphQL). Usage : /backlog-gitlab <chemin-vers-PRD-ou-PLAN>
---

# backlog-gitlab

## Objectif

Transformer un document de cadrage produit (PRD.md, PLAN.md) en backlog
structuré sur GitLab (Milestones + Issues), en respectant la doctrine du
projet : **GitLab est la seule source de vérité** (voir CLAUDE.md). Ce skill
ne touche jamais à git ni à GitHub — il ne fait que peupler GitLab.

## Pas d'Epics sur ce projet (tier Free)

Les Epics nécessitent un abonnement GitLab Premium/Ultimate — indisponibles
sur le tier Free utilisé ici (vérifié en conditions réelles, voir CLAUDE.md >
Vocabulaire : work items). **Les Milestones jouent le rôle de regroupement**
à la place des Epics : un Milestone par thème/phase, des Issues rattachées.
Si le groupe passe un jour en Premium/Ultimate, ce skill devra être révisé
pour utiliser de vrais Epics.

## Comment cet accès GitLab fonctionne

Tous les appels passent par `scripts/gitlab-api.sh` (voir CLAUDE.md > Accès).
Répartition **vérifiée en conditions réelles**, pas théorique :

- **REST** (`gitlab_rest`) : création de projet, création de Milestone,
  rattachement d'une Issue à un Milestone, liens `relates_to` entre Issues.
- **GraphQL** (`gitlab_graphql`) : **création d'Issue**, via la mutation
  `createIssue` — le POST REST `/projects/:id/issues` échoue avec ce token
  (permission `Work Item`, pas de permission REST `Issue: Create` distincte).

Le script échoue bruyamment (exit non nul, message sur stderr) en cas
d'erreur HTTP ou d'erreur GraphQL logique — ne jamais ignorer un échec pour
continuer sur les étapes suivantes.

**Liens de dépendance** : seul `link_type: "relates_to"` fonctionne sur ce
tier. `blocks`/`is_blocked_by` renvoient une erreur ("Blocked issues not
available for current license") — ne jamais les utiliser tant que le tier
n'a pas changé.

## Prérequis avant de lancer les étapes

- Le projet GitLab cible se résout par défaut depuis
  `.claude/gitlab-project.env` (`GITLAB_PROJECT_PATH`/`GITLAB_PROJECT_ID`) —
  jamais redemandé à l'utilisateur si ce fichier existe et que son projet est
  déjà créé sur GitLab (voir CLAUDE.md > Réutiliser ce framework pour un
  nouveau projet). Deux cas où on sort de ce défaut :
  - **Fichier absent** (premier amorçage d'un nouveau projet, avant que
    `.claude/gitlab-project.env` ait été créé/adapté) : demander le chemin à
    l'utilisateur — jamais deviner ou réutiliser un projet d'une session
    précédente sans confirmation.
  - **Projet référencé mais pas encore créé sur GitLab** (`gitlab_rest GET
    "projects/<groupe>%2F<projet>"` échoue en 404) : le créer via
    `gitlab_rest POST "projects" '{"name":"...","path":"...","namespace_id":<id_groupe>,"visibility":"private"}'`
    (nécessite la permission `Project: Create`, catégorie "User permissions"
    du token — voir CLAUDE.md > Sécurité du token), puis continuer avec ce
    projet.
- `GITLAB_TOKEN` doit être configuré (`.env` local ou variable d'environnement
  Cloud). Si `scripts/gitlab-api.sh` échoue avec "GITLAB_TOKEN absent",
  s'arrêter et demander à l'utilisateur de le configurer.
- Le fichier PRD/PLAN à convertir doit être fourni en argument (chemin) ou
  collé par l'utilisateur.

## Étapes

1. **Identifier le projet GitLab cible.** Par défaut, `source
   .claude/gitlab-project.env` et utiliser `GITLAB_PROJECT_PATH`/
   `GITLAB_PROJECT_ID`. Si ce fichier est absent, demander le chemin à
   l'utilisateur puis vérifier que le projet existe (le créer sinon, voir
   Prérequis) — et rappeler à l'utilisateur de créer/adapter
   `.claude/gitlab-project.env` à l'issue de cette étape pour que les skills
   suivants (`/tache`, `/livre`) n'aient pas à redemander le projet.

2. **Lire le PRD/PLAN**, extraire une structure Milestone → Issues (thèmes
   ou phases de haut niveau = Milestones candidats, tâches concrètes et
   actionnables = Issues). **Présenter ce découpage à l'utilisateur et
   attendre sa validation avant toute écriture sur GitLab** — jamais de
   création silencieuse en masse.

3. **Créer chaque Milestone validé** via REST :
   ```
   scripts/gitlab-api.sh rest POST "projects/<project_id>/milestones" \
     '{"title":"<titre>","description":"<description>","due_date":"<YYYY-MM-DD ou omis>"}'
   ```
   Conserver l'`id` renvoyé pour l'étape 4.

4. **Créer chaque Issue** via GraphQL, puis la rattacher à son Milestone :
   ```
   scripts/gitlab-api.sh graphql \
     'mutation($projectPath: ID!, $title: String!, $description: String) {
        createIssue(input: { projectPath: $projectPath, title: $title, description: $description }) {
          issue { id iid title webUrl }
          errors
        }
      }' \
     '{"projectPath":"<groupe>/<projet>","title":"<titre>","description":"<description>"}'
   ```
   Vérifier `errors` dans la réponse ; si non vide, s'arrêter et rapporter à
   l'utilisateur plutôt que de continuer. Puis rattacher au Milestone (et
   poser les labels si prévus) via REST, avec l'`iid` renvoyé :
   ```
   scripts/gitlab-api.sh rest PUT "projects/<project_id>/issues/<iid>" \
     '{"milestone_id":<id milestone>,"labels":"<label1,label2>"}'
   ```

5. **Lier les dépendances explicites entre tâches**, si le PRD/PLAN en
   indique (uniquement des relations simples, pas de blocage — voir
   limitation ci-dessus) :
   ```
   scripts/gitlab-api.sh rest POST "projects/<project_id>/issues/<iid source>/links" \
     '{"target_project_id":<project_id>,"target_issue_iid":<iid cible>,"link_type":"relates_to"}'
   ```
   Ne pas inventer de dépendances non mentionnées dans le document source.

6. **Récapituler** à l'utilisateur : liens `webUrl`/`web_url` des Milestones
   et Issues créés. Rappeler que la convention de branche
   `<type>/<numero-issue-gitlab>-<slug-court>` (voir CLAUDE.md) s'applique dès
   qu'une de ces issues est prise en charge — c'est l'objet du skill
   `/tache <issue_gitlab>` (Phase 2, à construire).

## Ce que ce skill ne doit jamais faire seul

- Créer des Epics (impossible sur ce tier, voir plus haut) ou tenter des
  liens `blocks`/`is_blocked_by` (échouent sur ce tier).
- Fermer, modifier ou supprimer une Issue/Milestone existante : ce skill ne
  fait que créer et lier.
- Committer, pousser ou créer une branche : hors périmètre (voir skill `/tache`).
- Créer des dizaines d'Issues sans validation préalable du découpage proposé
  à l'étape 2.
- Continuer les étapes suivantes si un appel `scripts/gitlab-api.sh` échoue
  (exit non nul) — s'arrêter et rapporter l'erreur à l'utilisateur.
