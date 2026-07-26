# CLAUDE.md — Conventions du projet

## Doctrine (à ne jamais enfreindre)

- **GitLab est la seule source de vérité projet** : backlog, epics, issues, jalons,
  décision de merge. C'est là que tout se décide.
- **GitHub est une façade d'exécution technique**, imposée par Claude Code Cloud.
  Il n'a aucune autorité : pas de review qui compte, pas de merge décisionnel,
  pas de protection de branche significative. Le code y transite, rien de plus.
- Le code sur GitHub est répliqué vers GitLab en sens unique (miroir), jamais
  l'inverse. Ne jamais pousser manuellement sur la copie miroir côté GitLab.

### Vocabulaire : work items

Depuis ses versions récentes, GitLab unifie Epics, Issues, Tasks, Incidents,
etc. sous un modèle de données commun appelé **work item** — c'est ce que
manipule l'API GraphQL Work Items utilisée par `scripts/gitlab-api.sh` et le
skill `/backlog-gitlab` (`workItemCreate`, `workItemTypes`, `hierarchyWidget`
pour les relations parent/enfant). Un Epic est un work item de type "Epic",
une Issue un work item de type "Issue", etc. Les **Milestones** restent en
dehors de ce modèle — c'est un concept GitLab séparé, toujours géré en REST
classique (`/milestones`).

Ce projet continue d'utiliser "epic"/"issue"/"jalon" dans son vocabulaire
courant (plus lisible pour l'humain), mais toute implémentation technique
doit garder à l'esprit qu'il s'agit de work items sous le capot — utile si le
périmètre s'élargit un jour à d'autres types (Task, Incident, Objective,
Key Result, Ticket) sans tout redécouvrir.

### Limitation vérifiée : pas d'Epics sur ce projet (tier Free)

Les **Epics nécessitent un abonnement GitLab Premium ou Ultimate** — vérifié
en conditions réelles le 2026-07-26 (`workItemTypes` renvoie une liste vide
pour le groupe "ai-agent-projects", en tier Free). Tant que ce tier n'a pas
changé, **le backlog utilise les Milestones comme mécanisme de regroupement**
à la place des Epics (thème/phase → Issues rattachées via `milestone_id`).
Si le groupe passe un jour en Premium/Ultimate, reconsidérer l'usage
d'Epics et mettre à jour cette section + le skill `/backlog-gitlab` en
conséquence.

Autre limitation liée au tier, vérifiée le même jour : les liens de
dépendance entre issues de type `blocks`/`is_blocked_by` renvoient une
erreur ("Blocked issues not available for current license"). Seul le type
`relates_to` fonctionne sur ce tier.

## Accès

- GitLab : via appels directs à l'API GitLab (REST v4
  `https://gitlab.com/api/v4` + GraphQL `https://gitlab.com/api/graphql`),
  authentifiés par un token dans la variable d'environnement `GITLAB_TOKEN`.
  Toujours passer par le helper `scripts/gitlab-api.sh` (fonctions
  `gitlab_rest` et `gitlab_graphql`) plutôt que des appels `curl` ad hoc
  dispersés dans les skills. Ce choix remplace l'ancien MCP GitLab, abandonné
  car incomplet (ne pouvait pas créer d'Epics/Milestones) et indisponible en
  session Claude Code Cloud.
- Répartition REST / GraphQL, vérifiée en conditions réelles le 2026-07-26:
  la création de projet, de milestone, le rattachement d'une issue à un
  milestone et les liens `relates_to` passent par REST classique ; la
  **création d'issue passe par la mutation GraphQL `createIssue`** (le POST
  REST `/projects/:id/issues` n'est pas couvert par les permissions du token
  fine-grained utilisé ici — seul `Work Item` l'autorise, via GraphQL).
- GitHub : accès natif Claude Code (local et Cloud), pour clone/branch/commit/push.

### Sécurité du token GitLab

- Type de token : **Personal Access Token fine-grained** (GA depuis GitLab
  19.2, disponible sur tous les tiers dont Free — contrairement au Group
  Access Token, qui nécessite Premium/Ultimate sur GitLab.com et n'est donc
  pas utilisable ici). Créé depuis les réglages du compte personnel
  (`https://gitlab.com/-/user_settings/personal_access_tokens`), mais
  **scopé aux groupes/projets cibles** (ex. "ai agent projects") au moment
  de la création — ce qui évite l'écueil d'un PAT classique qui hériterait
  de tous les droits du compte sur GitLab.com.
- Permissions confirmées nécessaires (testées en conditions réelles le
  2026-07-26 sur le groupe "ai-agent-projects", tier Free) :
  - **Group and project permissions → Groups → `Group: Read`**
  - **Group and project permissions → Project Planning → `Work Item: Create,
    Read, Update, Delete`** — autorise la création d'issues via la mutation
    GraphQL `createIssue` (les Issues sont des work items sous le capot).
  - **User permissions → `Project: Create`** — nécessaire pour créer un
    projet dans le groupe (catégorie distincte de "Group and project
    permissions", facile à manquer).
  - La création de Milestones et les liens `relates_to` ont fonctionné sans
    permission "Milestone"/"Issue Link" dédiée trouvée dans le formulaire —
    probablement couverts implicitement par l'accès projet de base.
  - Si un appel échoue malgré tout avec une erreur 403
    (`insufficient_granular_scope`), le message d'erreur indique la
    permission exacte manquante : régénérer le token en l'ajoutant.
- Expiration à définir à la création du token (recommandé : courte, ex. 90
  jours) et à suivre manuellement (pas de rotation automatique).
- Stockage : uniquement dans `.env` local (gitignoré, jamais committé) et,
  pour les sessions Cloud, dans une variable d'environnement Cloud
  **personnelle** (jamais un environnement partagé en équipe/org — Claude Code
  Cloud n'a pas de coffre-fort à secrets, ces valeurs sont visibles en clair
  par quiconque peut éditer l'environnement).
- Ne jamais afficher le token en clair dans une commande, un log ou une
  réponse (pas d'`echo`, pas de `curl -v`).

## Convention de nommage des branches

- Format : `<type>/<numero-issue-gitlab>-<slug-court>`
- Types : `feature`, `fix`, `chore`
- Exemple : `feature/142-export-pdf-facture`
- Le numéro d'issue GitLab est **obligatoire** dans le nom de branche : c'est
  le seul lien traçable entre le travail GitHub et le work item GitLab
  (aucun mot-clé automatique type `Closes #` ne fonctionne entre les deux
  plateformes — la liaison est manuelle, via ce nommage, et doit être
  entretenue explicitement à chaque étape).

## Cycle de vie d'une tâche

1. L'issue existe sur GitLab (créée via `/backlog-gitlab` ou manuellement).
2. Créer la branche GitHub selon la convention ci-dessus.
3. Développer, committer normalement.
4. **Ne jamais committer ni pousser sans validation humaine explicite.**
   Le fichier marqueur `.claude/validated` doit exister avant tout `git commit`
   ou `git push`. Il est créé uniquement par l'utilisateur après ses propres
   tests manuels (commande `/valide`). Le supprimer après usage.
5. À la clôture : mettre à jour l'issue/epic GitLab correspondante via l'API
   (commentaire + fermeture si le travail est terminé), et ajouter une entrée
   dans `docs/JOURNAL.md`.

## Mémoire de session

- `docs/JOURNAL.md` : journal chronologique des tâches livrées, une entrée par
  clôture (date, numéro d'issue GitLab, branche, résumé). Toujours le lire en
  début de session pour retrouver le contexte des sessions précédentes.
- `docs/BACKLOG.md` : optionnel, miroir lisible du backlog GitLab si besoin
  d'une vue hors-ligne — le backlog GitLab reste la référence en cas d'écart.

## Ce que Claude ne doit jamais faire seul

- Merger une branche sans validation humaine explicite.
- Fermer une issue ou un epic sans confirmation que le travail est réellement livré.
- Modifier les règles de protection de branche ou les permissions GitLab/GitHub.
- Committer si `.claude/validated` est absent.