# CLAUDE.md — Conventions du projet

## Ce que ce dépôt est (et n'est pas)

**Gouvernail** est un **framework réutilisable** — la méthodologie et
l'outillage (doctrine, skills, scripts) pour développer *n'importe quel*
projet avec Claude Code en suivant de vraies pratiques d'ingénierie : cadrage
(claude-mastery : `/cadre`, `/planifie`...), gestion de backlog façon Scrum
sur GitLab, versioning GitLab Flow (branches + Merge Request), et exécution
autonome par Claude Code Cloud sur ce backlog — y compris en l'absence de
l'utilisateur, comme le ferait une équipe de développement qui pioche des
tickets.

**Ce dépôt lui-même n'héberge jamais de "vrai" projet produit.** Son propre
développement (le framework qui s'améliore) suit néanmoins ce même GitLab
Flow, sur son propre projet GitLab méta `ai-agent-projects/gouvernail` —
c'est un cas normal d'auto-hébergement, pas une exception à la règle
ci-dessus.

### Réutiliser ce framework pour un nouveau projet

Chaque nouveau projet (cahier des charges → application livrée) a sa **propre
paire** dépôt GitHub + projet GitLab, distincte de celles de `Gouvernail`.
GitHub n'existe que parce que Claude Code Cloud l'impose (voir Doctrine
ci-dessous) — GitLab reste la seule source de vérité, y compris pour ce
nouveau projet.

Amorçage semi-automatisé via le skill `/amorce-projet <chemin-cible>`,
lancé depuis une session Claude Code ouverte sur **ce dépôt** (Gouvernail) :
crée le projet GitLab et le dépôt GitHub dédiés, copie l'outillage vers le
nouveau répertoire — chaque action mutante externe (création de projet,
création de dépôt, push) reste **validée par l'utilisateur à chaque
étape**, ce skill élimine la répétition mécanique, pas la validation
humaine. `/amorce-projet` lui-même n'est **jamais** copié dans les nouveaux
projets — c'est un outil méta propre à Gouvernail.

Ce qui change d'un projet à l'autre, concrètement, c'est le contenu de
`.claude/gitlab-project.env` (`GITLAB_PROJECT_PATH`/`GITLAB_PROJECT_ID`) —
`scripts/gitlab-api.sh` et les skills (`/backlog-gitlab`, `/tache`, `/livre`,
`/cloture`) ne codent jamais un projet en dur, ils lisent toujours ce
fichier. Le token GitLab, lui, n'a pas besoin de changer d'un projet à
l'autre : scopé au groupe, il fonctionne tel quel pour tout nouveau projet
créé dans ce groupe (voir Sécurité du token GitLab).

### Skills de cadrage (claude-mastery)

Les skills `interroge`, `cadre`, `planifie`, `design`, `investigue`,
`illustre` sont vendorisés depuis
[`naiersaidane/claude-mastery`](https://github.com/naiersaidane/claude-mastery)
(MIT, licence copiée dans `.claude/skills/LICENSE-claude-mastery`) —
copiés tels quels dans `.claude/skills/`, à reporter dans chaque nouveau
projet au même titre que `/backlog-gitlab`/`/tache`/`/livre`/`/cloture`.

**Ses skills `branche` et `livre` sont volontairement exclus** : ils font
respectivement une branche générique `feat/`/`fix/` sans lien avec une issue
GitLab, et une Pull Request GitHub sans passer par GitLab — moins complets
que `/tache` (branche liée à une issue GitLab) et `/livre` (Merge Request
GitLab, pas juste une PR GitHub) déjà présents dans ce framework. Règle de
principe si claude-mastery publie un nouveau skill qui recoupe l'existant :
**garder claude-mastery si équivalent, garder le custom de ce framework s'il
est strictement plus complet** — décision de l'utilisateur, voir mémoire
`feedback` associée.

## Doctrine (à ne jamais enfreindre)

- **GitLab est la seule source de vérité projet** : backlog, epics, issues, jalons,
  décision de merge. C'est là que tout se décide.
- **GitHub est une façade d'exécution technique**, imposée par Claude Code Cloud.
  Il n'a aucune autorité : pas de review qui compte, pas de merge décisionnel,
  pas de protection de branche significative. Le code y transite, rien de plus.
- **La review et le merge réels se font via une Merge Request GitLab**
  (GitLab Flow) — voir Cycle de vie d'une tâche. Le `main` GitHub est
  resynchronisé après coup depuis GitLab, jamais l'inverse : ne jamais
  pousser manuellement un `main` GitHub qui n'a pas d'abord été mergé côté
  GitLab.

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

Un **seul token**, `GITLAB_TOKEN`, couvre à la fois l'API backlog (work
items/milestones) et le push de code + Merge Requests (voir Cycle de vie
d'une tâche). Choix délibéré : minimiser le nombre de créations manuelles de
token (Claude ne peut pas en créer lui-même), au prix d'un rayon d'action
plus large en cas de compromission — accepté par l'utilisateur, voir mémoire
`feedback` associée.

- Type de token : **Personal Access Token fine-grained** (GA depuis GitLab
  19.2, disponible sur tous les tiers dont Free — contrairement au Group
  Access Token, qui nécessite Premium/Ultimate sur GitLab.com et n'est donc
  pas utilisable ici). Créé depuis les réglages du compte personnel
  (`https://gitlab.com/-/user_settings/personal_access_tokens`).
- **Scopé au groupe `ai-agent-projects`, jamais à un projet précis** — c'est
  ce qui permet de le créer **une seule fois** et de le réutiliser tel quel
  pour tout nouveau projet créé dans ce groupe (voir Réutiliser ce framework
  pour un nouveau projet) : jamais besoin d'en recréer un par projet.
- Permissions nécessaires (testées en conditions réelles le 2026-07-26,
  y compris `git push` et création/merge de Merge Request via le skill
  `/livre` — le token en place couvre déjà tout ce qui suit) :
  - **Group and project permissions → Groups → `Group: Read`**
  - **Group and project permissions → Project Planning → `Work Item: Create,
    Read, Update, Delete`** — autorise la création d'issues via la mutation
    GraphQL `createIssue` (les Issues sont des work items sous le capot).
  - **User permissions → `Project: Create`** — nécessaire pour créer un
    projet dans le groupe (catégorie distincte de "Group and project
    permissions", facile à manquer).
  - Une permission de type **Repository: Write** (push de branches) — le
    libellé exact retenu par l'utilisateur à la création n'a pas été
    ré-inspecté via l'API (nécessiterait la permission additionnelle
    `Personal Access Token: Read` rien que pour lire les scopes du token
    lui-même) ; fonctionnellement confirmé : `git push` vers GitLab a
    réussi sans 403.
  - Une permission couvrant la **création et le merge de Merge Requests** —
    même remarque, fonctionnellement confirmé (MR créée sans erreur).
  - La création de Milestones et les liens `relates_to` ont fonctionné sans
    permission "Milestone"/"Issue Link" dédiée trouvée dans le formulaire —
    probablement couverts implicitement par l'accès projet de base.
- Expiration à définir à la création du token (recommandé : courte, ex. 90
  jours) et à suivre manuellement (pas de rotation automatique).
- Stockage : uniquement dans `.env` local (gitignoré, jamais committé) et,
  pour les sessions Cloud, dans une variable d'environnement Cloud
  **personnelle** (jamais un environnement partagé en équipe/org — Claude Code
  Cloud n'a pas de coffre-fort à secrets, ces valeurs sont visibles en clair
  par quiconque peut éditer l'environnement). Jamais de secret GitHub
  Actions : le token est utilisé directement par Claude Code (local ou
  Cloud), pas par une CI GitHub.
- Ne jamais afficher le token en clair dans une commande, un log ou une
  réponse (pas d'`echo`, pas de `curl -v`), jamais de remote git persistant
  configuré avec ce token (ne doit jamais atterrir dans `.git/config`).

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
2. Créer la branche locale selon la convention ci-dessus (skill `/tache`).
3. Développer, committer localement au fil de l'eau si besoin — mais tout
   push (GitHub ou GitLab) et toute Merge Request restent conditionnés à une
   validation humaine explicite, voir ci-dessous.
4. **Le gate n'est pas un fichier, c'est une phrase explicite de
   l'utilisateur dans la conversation** (skill `/livre`) :
   - **"tu peux commiter"** → commit (si nécessaire) + push de la branche sur
     GitHub *et* GitLab + ouverture d'une Merge Request GitLab (branche →
     `main`). Pas de merge.
   - **"tu peux commiter et merger"** → tout ce qui précède, **plus** le
     merge de la Merge Request, la resynchronisation de `main` GitHub depuis
     GitLab, un commentaire sur l'issue liée, **la fermeture de cette issue**
     et **du milestone associé si c'était sa dernière issue ouverte**. Le
     merge explicite *est* la confirmation de livraison — pas besoin de la
     redemander séparément pour la fermeture.
5. **La review réelle a lieu sur la Merge Request GitLab** — lecture du
   diff, approbation, merge : c'est le vrai point de décision humaine, pas un
   artefact local.
6. Fermer une issue **en dehors** de ce flux (décidée comme non pertinente,
   doublon, ou rattrapage d'une clôture manquée) reste une action distincte
   et délibérée, via le skill `/cloture <numero-issue>` invoqué
   explicitement — jamais en réaction à une simple mention en conversation.
   Pas d'Epics à fermer sur ce tier (voir Limitation vérifiée ci-dessous).

## Mémoire de session

- `docs/JOURNAL.md` : journal chronologique des tâches livrées, une entrée par
  clôture (date, numéro d'issue GitLab, branche, résumé). Toujours le lire en
  début de session pour retrouver le contexte des sessions précédentes.
- `docs/BACKLOG.md` : optionnel, miroir lisible du backlog GitLab si besoin
  d'une vue hors-ligne — le backlog GitLab reste la référence en cas d'écart.

## Ce que Claude ne doit jamais faire seul

- Committer directement sur `main` (toujours via une branche + Merge Request).
- Pousser une branche (GitHub ou GitLab) ou ouvrir une Merge Request sans la
  phrase de validation explicite ("tu peux commiter" / "tu peux commiter et
  merger").
- Merger une Merge Request sans le "... et merger" explicite.
- Fermer une issue/milestone en dehors du merge d'une Merge Request qui la
  referme (`/livre` mode "merge") ou de `/cloture` explicitement invoqué —
  jamais en réaction à une simple mention en conversation.
- Modifier les règles de protection de branche ou les permissions GitLab/GitHub.