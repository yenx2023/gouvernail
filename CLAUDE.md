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

Chaque nouveau projet a son **propre** projet GitLab, distinct de celui de
`Gouvernail` — GitLab reste la seule source de vérité, y compris pour ce
nouveau projet. Un dépôt GitHub dédié s'y ajoute **si le projet utilise
Claude Code Cloud** (voir Doctrine ci-dessous — obligatoire pour le profil
`conception`, optionnel pour `produit-tiers`, voir Profils ci-dessous).

Amorçage semi-automatisé via le skill `/amorce-projet <chemin-cible>
--profil <conception|produit-tiers> [...]`, lancé depuis une session Claude
Code ouverte sur **ce dépôt** (Gouvernail) : crée le projet GitLab (et le
dépôt GitHub le cas échéant), copie l'outillage adapté au profil choisi
vers le nouveau répertoire — chaque action mutante externe (création de
projet, création de dépôt, push) reste **validée par l'utilisateur à
chaque étape**, ce skill élimine la répétition mécanique, pas la validation
humaine. `/amorce-projet` lui-même n'est **jamais** copié dans les nouveaux
projets — c'est un outil méta propre à Gouvernail.

Ce qui change d'un projet à l'autre, concrètement, c'est le contenu de
`.claude/gitlab-project.env` (`GITLAB_PROJECT_PATH`/`GITLAB_PROJECT_ID`) —
`scripts/gitlab-api.sh` et les skills du socle commun (`/backlog-gitlab`,
`/tache`, `/livre`, `/cloture`, et les autres skills partagés quel que soit
le profil) ne codent jamais un projet en dur, ils lisent toujours ce
fichier. Le token GitLab, lui, n'a pas besoin de changer d'un projet à
l'autre : scopé au groupe, il fonctionne tel quel pour tout nouveau projet
créé dans ce groupe (voir Sécurité du token GitLab).

### Profils

Deux profils déterminent quel outillage `/amorce-projet` copie et quel
`CLAUDE.md` il génère — le détail mécanique complet (skills copiés par
profil, templates, substitutions) vit dans
`.claude/skills/amorce-projet/SKILL.md`, cette section n'en donne que le
principe :

- **`conception`** (défaut historique de ce framework, cas TAGA/todo-cli) —
  le produit est conçu ici : cahier des charges → application livrée. Le
  cadrage passe par `/cadre` → `docs/PRD.md`, puis `/planifie` →
  `docs/PLAN.md`. GitHub est systématique (façade Claude Code Cloud).
- **`produit-tiers`** — le produit existe déjà chez un fournisseur externe
  (ex. un produit CodeCanyon), ce projet le personnalise et absorbe ses
  mises à jour au fil du temps sans perdre les personnalisations ni les
  corrections de bugs déjà appliquées. Pas de cadrage produit (`/cadre`/
  `/planifie` n'ont pas de sens ici — la conception n'est pas la nôtre) :
  le document pivot est `docs/REGISTRE.md`, alimenté par les skills
  `/absorbe` (montée de version, en phases validées comme `/investigue`),
  `/registre` (consigner une divergence) et `/piege` (capitaliser un piège
  d'absorption). GitHub est **optionnel** — GitLab seul par défaut
  (`--github` pour l'ajouter si Claude Code Cloud devient utile plus tard).
  Un axe supplémentaire, `--regime deploye|distribue`, distingue un
  composant déployé en continu sur une infra contrôlée (environnements +
  stratégie de déploiement, ex. un backend) d'un composant distribué en
  versions (stores/packages, pas d'environnement à gérer, ex. une app
  mobile) — voir Produit multi-dépôts ci-dessous, c'est typiquement le même
  produit qui a besoin des deux régimes selon le dépôt.

Ce qui est spécifique au produit tiers personnalisé (architecture, pièges,
procédures de build) n'est **jamais** copié depuis Gouvernail ni reporté
dedans — ça vit dans un skill produit dédié propre à chaque projet
`produit-tiers` (ex. `<produit>-update`), en dehors du framework. Seule la
discipline du processus (`/absorbe`, `/registre`, `/piege`) est partagée.

### Produit multi-dépôts

Un même produit peut nécessiter plusieurs dépôts GitHub / projets GitLab
distincts (ex. un backend et une app mobile qui partagent un même domaine
fonctionnel). Dans ce cas :

- Regrouper les projets GitLab sous un **sous-groupe dédié au produit**
  (`ai-agent-projects/<produit>/<depot>`), via `/amorce-projet
  --sous-groupe <produit>` — plutôt que le chemin plat
  `ai-agent-projects/<depot>` utilisé pour un projet isolé. Le sous-groupe
  est créé une seule fois, au premier dépôt amorcé pour ce produit ; les
  suivants le réutilisent (le skill détecte s'il existe déjà).
- **Chaque dépôt du produit choisit son propre régime** en profil
  `produit-tiers` (voir Profils ci-dessus) : le cas fréquent est un backend
  en `--regime deploye` et une ou plusieurs apps mobiles du même produit en
  `--regime distribue` — même produit, même sous-groupe, workflows Git
  différents parce que les contraintes opérationnelles diffèrent
  réellement (haute disponibilité côté serveur vs releases versionnées
  côté store).
- Chaque dépôt garde son propre backlog GitLab, son propre `docs/PRD.md`/
  `docs/PLAN.md`, sans mécanisme automatique de liaison entre eux : les
  liens d'issue `relates_to` de GitLab sont scopés au même projet — pas de
  dépendance croisée outillable entre projets sur ce tier.
- Une dépendance fonctionnelle vers un autre dépôt du même produit (ex. une
  user story mobile qui suppose un support backend) se documente
  explicitement dans la section **Notes complémentaires** du PRD concerné,
  par référence au chemin du dépôt frère (ex. « suppose un endpoint côté
  `taga-backend`, voir `taga-backend/docs/PRD.md` ») — cette section est
  déjà un catch-all pour les dépendances externes, pas besoin d'une
  nouvelle section ni d'un nouvel outil.
- **Cette note doit être révisée dès que la dépendance est couverte côté
  dépôt référencé** — sinon elle continue d'affirmer un état qui n'est plus
  vrai (voir Documentation vivante dans le `CLAUDE.md.template`, gabarit
  copié dans chaque nouveau projet). Rien ne déclenche cette révision
  automatiquement : sans check explicite, la note survit telle quelle même
  après que le dépôt référencé a rattrapé son retard.

Retour d'expérience à l'origine de cette section : `taga-backend` et
`taga-mobile-app`, deux dépôts d'un même produit (TAGA) regroupés sous
`ai-agent-projects/taga/`. Retour d'expérience à l'origine de la règle de
révision ci-dessus : la section Notes complémentaires de
`taga-mobile-app/docs/PRD.md`, puis la section Bloquée par de la Phase 7 de
son `docs/PLAN.md`, ont continué à affirmer que le portefeuille
conducteur/suivi temps réel n'étaient "pas encore couverts" côté
`taga-backend` — alors que `taga-backend/docs/PRD.md` (user stories 44-52)
et `taga-backend/docs/PLAN.md` (Phases 5 et 8) les couvraient déjà depuis
l'extension du PRD backend. Détecté a posteriori, sans qu'aucune étape du
cycle de vie d'une tâche ne l'ait signalé.

### Adopter Gouvernail sur un dépôt existant

`/amorce-projet` refuse délibérément de tourner sur un chemin cible qui a
déjà un `.git/` (voir son garde-fou anti-écrasement) — il n'est prévu que
pour un nouveau dépôt vide. Adopter l'outillage Gouvernail sur un projet
**déjà existant** (cas fréquent en profil `produit-tiers` : le code tourne
déjà en production depuis longtemps quand la décision d'outiller avec
Gouvernail est prise) n'est donc **pas couvert par un skill dédié** — ça se
fait à la main, en copiant l'outillage adapté au profil depuis
`.claude/skills/amorce-projet/SKILL.md` (la logique de copie y est
documentée même si le skill lui-même refuse de s'exécuter sur ce cas) ou
depuis un dépôt frère du même produit déjà outillé.

**Ce que cette copie manuelle rate le plus souvent : les décisions que
`/amorce-projet` force explicitement pour un projet neuf ne sont plus
posées.** Une session qui adopte Gouvernail sur un dépôt existant en
copiant un `CLAUDE.md` frère hérite silencieusement de SES choix — y
compris ceux qui ne s'appliquent pas au nouveau contexte. Avant de
considérer une adoption manuelle terminée, reposer explicitement les mêmes
questions qu'`/amorce-projet` poserait pour un projet neuf (voir Étape 1 de
`.claude/skills/amorce-projet/SKILL.md`) :

- profil (`conception`/`produit-tiers`),
- **si `produit-tiers` : régime (`deploye`/`distribue`) — ne jamais le
  copier tel quel d'un dépôt frère.** Reposer la question pour CE dépôt
  précis à partir de sa nature réelle (composant à environnements gérés vs
  composant distribué en versions, voir Profils ci-dessus), pas de ce que
  le dépôt frère utilise,
- sous-groupe produit s'il y a plusieurs dépôts pour le même produit tiers
  (voir Produit multi-dépôts ci-dessus).

Retour d'expérience à l'origine de cette section : sur un produit à trois
dépôts (un backend + deux apps mobiles), le backend a adopté Gouvernail en
régime `déployé` — correct, il a de vrais environnements test/production.
Les deux apps mobiles ont ensuite adopté Gouvernail en copiant le
`CLAUDE.md` du backend, régime `déployé` inclus — alors que la doc Profils
cite explicitement une app mobile comme cas canonique du régime
`distribué`. L'écart a été noté dans le `CLAUDE.md` de chacune ("pas encore
basculé sur distribue... tâche dédiée") mais rien n'a jamais déclenché cette
tâche — la note a survécu telle quelle sur les deux dépôts jusqu'à ce que
l'utilisateur la relève, plusieurs semaines et une absorption de version
majeure plus tard.

### Skills de cadrage (claude-mastery)

Concerne uniquement le socle commun et le profil `conception` — les skills
`absorbe`/`registre`/`piege` du profil `produit-tiers` sont natifs à
Gouvernail, pas vendorisés (voir Profils ci-dessus).

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

## Langue de travail

Toute réponse de Claude Code dans une session sur ce dépôt — messages de
conversation, commentaires, titres/descriptions de commits, Merge Requests,
issues — est rédigée en français : l'utilisateur de ce framework communique
exclusivement en français.

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
   validation humaine explicite, voir ci-dessous. Seule exception : le
   **push de continuité** local ↔ Cloud (voir sous-section dédiée), qui n'a
   pas besoin des phrases de `/livre`.
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

### Push de continuité (switch local ↔ Cloud)

Claude Code local et Claude Code Cloud sont deux environnements d'exécution
séparés qui ne partagent ni historique de conversation ni mémoire auto —
seul le code passe entre les deux, via GitHub (Cloud clone le dépôt GitHub à
chaque nouvelle session ; le local ne voit ce qu'a fait Cloud qu'après un
`git pull`). Continuer une même tâche en changeant d'environnement en cours
de route nécessite donc de pousser la branche de travail sur GitHub **avant
la fin de la tâche**, c'est-à-dire avant la phrase de validation habituelle
("tu peux commiter" / "tu peux commiter et merger") qui, elle, reste
réservée à la livraison finale.

Ce **push de continuité** est distinct du push de livraison de `/livre` :

- **Déclencheur** : une instruction ponctuelle et explicite de l'utilisateur
  dans la conversation (ex. "pousse cette branche sur GitHub pour que je
  continue en Cloud"), **pas** les phrases "tu peux commiter" / "tu peux
  commiter et merger" — celles-ci restent le déclencheur du seul push de
  livraison via `/livre`.
- **Portée strictement limitée** : uniquement `git push` de la branche
  courante vers **GitHub**. Jamais vers GitLab, jamais d'ouverture de Merge
  Request, jamais de merge — ce push ne fait que rendre le code visible à
  l'autre environnement, il n'est pas une étape du Cycle de vie d'une tâche.
- **Retour côté local** : après une session Cloud, `git fetch`/`git pull` la
  branche avant de continuer en local — pas d'action automatique attendue de
  Claude ici, c'est une étape manuelle de reprise de session.
- Le token GitLab et les skills (`/tache`, `/livre`, `/backlog-gitlab`,
  `/cloture`) fonctionnent à l'identique en Cloud, à condition que
  `GITLAB_TOKEN` soit configuré dans une variable d'environnement Cloud
  personnelle (voir Sécurité du token GitLab) — rien de spécifique à ajouter
  ici.

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
  merger") — **sauf le push de continuité local ↔ Cloud** (voir sous-section
  dédiée), qui répond à une instruction ponctuelle explicite distincte, reste
  limité à un `git push` GitHub de la branche courante, et n'ouvre jamais de
  Merge Request ni ne touche GitLab.
- Merger une Merge Request sans le "... et merger" explicite.
- Fermer une issue/milestone en dehors du merge d'une Merge Request qui la
  referme (`/livre` mode "merge") ou de `/cloture` explicitement invoqué —
  jamais en réaction à une simple mention en conversation.
- Modifier les règles de protection de branche ou les permissions GitLab/GitHub.