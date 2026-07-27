# Journal

Journal chronologique des tâches livrées (une entrée par clôture réelle —
voir CLAUDE.md > Mémoire de session).

## 2026-07-26 — Issue #1 — `chore/1-gitlab-flow-mr`

Remplacement du gate `.claude/validated` (fichier marqueur, mauvaise
interprétation de la doctrine de validation humaine) par un vrai GitLab
Flow : branche poussée sur GitLab, Merge Request ouverte puis mergée
là-bas, déclenché par une phrase explicite de l'utilisateur ("tu peux
commiter" / "tu peux commiter et merger") plutôt qu'un fichier local.
Ajoute la doctrine "framework réutilisable" (`gitlab-facade` n'héberge
jamais de vrai projet produit) et un token GitLab unique scopé au groupe
`ai-agent-projects`, créé une seule fois pour tout projet futur.

## 2026-07-27 — Issue #2 — `chore/2-vendorise-claude-mastery`

Vendoring des skills `interroge`/`cadre`/`planifie`/`design`/`investigue`/
`illustre` depuis `naiersaidane/claude-mastery` (MIT). Ses skills `branche`
et `livre` sont exclus au profit de `/tache` et `/livre` propres à ce
framework, plus complets (liaison à une issue GitLab, Merge Request GitLab
plutôt que Pull Request GitHub). Reporté dans `todo-cli`, premier projet
amorcé avec ce framework.

## 2026-07-27 — Issue #3 — `chore/3-renomme-gouvernail`

Le framework est renommé `gitlab-facade` → **Gouvernail** (repo GitHub,
projet GitLab, doctrine). Le dossier local reste nommé `gitlab-facade` pour
ne pas perturber la session en cours — cosmétique, sans impact fonctionnel.

## 2026-07-27 — `chore/corrige-resolution-projet-gitlab` (pas d'issue formelle)

Corrige une incohérence entre skills : `/livre` résolvait déjà le projet
GitLab cible depuis `.claude/gitlab-project.env` sans jamais le redemander,
mais `/tache` et `/backlog-gitlab` redemandaient systématiquement le chemin
du projet — contredisant la doctrine "les skills ne codent jamais un projet
en dur, ils lisent toujours ce fichier". Les deux skills utilisent
désormais ce fichier comme défaut, ne redemandant que si le fichier est
absent (ou si `--projet` surcharge explicitement le défaut pour `/tache`).

## 2026-07-27 — `chore/livre-cloture-robustesse` (pas d'issue formelle)

Corrige un bug découvert en mergeant réellement la MR de la correction
précédente : le `PUT .../merge_requests/<iid>/merge` de GitLab exige un
champ `sha`, non documenté dans `/livre`. Ajoute un retry avec backoff
exponentiel sur les erreurs transitoires (429/5xx) dans
`scripts/gitlab-api.sh`, utile en exécution autonome sans supervision. Ajoute
le skill `/cloture` pour fermer une issue proprement après confirmation de
livraison (comblait un vide entre la doctrine et l'outillage).

## 2026-07-27 — Issue #4 — `fix/4-tache-label-type`

`/backlog-gitlab` pose désormais un label `feature`/`fix`/`chore` sur
chaque issue à sa création (contexte complet du PRD/PLAN disponible à ce
moment). `/tache` utilise ce label directement sans redemander à
l'utilisateur — ne retombe sur une déduction + confirmation que si le
label est absent. Corrige un défaut repéré en conditions réelles sur
`todo-cli` (issue #5).

## 2026-07-27 — `chore/skill-amorce-projet` (pas d'issue formelle)

Ajoute le skill `/amorce-projet <chemin-cible>` pour automatiser la section
"Réutiliser ce framework pour un nouveau projet" de `CLAUDE.md`, jusqu'ici
100% manuelle. Crée le projet GitLab et le dépôt GitHub dédiés (via `gh`),
copie l'outillage (`.claude/skills/`, `scripts/gitlab-api.sh`) et génère un
`CLAUDE.md` adapté depuis un gabarit, en gardant une validation utilisateur
explicite à chaque action mutante externe. Conçu à partir de l'inspection
du précédent réel `todo-cli` (fichiers copiés, structure de `CLAUDE.md`,
séquence git avec commit de genèse direct sur `main`). N'est jamais copié
dans les nouveaux projets — outil méta propre à Gouvernail.

## 2026-07-27 — `chore/solid-template-amorce-projet` (pas d'issue formelle)

Ajoute une section "Principes de conception (SOLID)" au gabarit `CLAUDE.md`
utilisé par `/amorce-projet` pour chaque nouveau projet, avec un garde-fou
explicite contre l'abstraction prématurée (cohérence avec le reste de la
doctrine anti-over-engineering). Ne s'applique qu'aux futurs projets amorcés
— pas de rétro-application sur `todo-cli`.

## 2026-07-27 — `chore/dry-tests-erreurs-dependances-template` (pas d'issue formelle)

Complète le gabarit `CLAUDE.md` de `/amorce-projet` dans le même esprit que
SOLID : section renommée "SOLID + DRY", et trois nouvelles sections Tests
(filet de sécurité pour tout comportement changé par une session autonome),
Gestion des erreurs (fail fast, pas de fallback silencieux) et Dépendances
(réutiliser l'existant avant d'ajouter une librairie). Axes proposés en
réponse à une demande explicite d'amélioration "dans le même sens que
SOLID", sélectionnés par l'utilisateur parmi plusieurs candidats.

## 2026-07-27 — Issue #5 — `feature/5-livre-ferme-issue-milestone`

`/livre` (mode "merge") ferme désormais automatiquement l'issue liée et,
si c'était sa dernière issue ouverte, le milestone associé — le merge
explicite est déjà la confirmation de livraison, plus besoin de la
redemander séparément. `/cloture` devient l'outil des exceptions (hors
flux de merge), sur invocation explicite. Issue #5 elle-même fermée en
appliquant cette nouvelle doctrine dans la foulée.

## 2026-07-27 — `chore/fonctions-testables-gitlab-api` (pas d'issue formelle)

Extrait la logique mécanique de `scripts/gitlab-api.sh` (parsing du numéro
d'issue depuis le nom de branche, vérification qu'un milestone n'a plus
d'issue ouverte, récupération du `sha` d'une Merge Request) en fonctions
bash dédiées (`parse_issue_from_branch`, `milestone_is_empty`,
`merge_request_sha`), plutôt que de laisser `/livre` redériver ce
raisonnement en langage naturel à chaque exécution. Ajoute
`tests/gitlab-api.test.sh` (16 tests hors-ligne, curl et sleep mockés) pour
couvrir ce script au cœur de tous les skills — jusqu'ici seul le script
applicatif des autres projets amorcés avait une doctrine de tests, pas
Gouvernail lui-même. `/livre` et `/amorce-projet` mis à jour en
conséquence (ce dernier reporte désormais `tests/` dans chaque nouveau
projet).

## 2026-07-27 — `chore/push-continuite-local-cloud` (pas d'issue formelle)

Formalise dans `CLAUDE.md` le "push de continuité" local ↔ Cloud : Claude
Code local et Claude Code Cloud sont deux environnements séparés qui ne
partagent que le code (via GitHub), pas l'historique de conversation ni la
mémoire auto — poursuivre une même tâche en changeant d'environnement exige
donc de pousser la branche WIP sur GitHub avant la livraison finale. Ce push
est distinct de celui de `/livre` : déclenché par une instruction ponctuelle
explicite (pas les phrases "tu peux commiter"/"... et merger"), limité à
GitHub, jamais de Merge Request ni de GitLab. Sans cette exception, la règle
absolue "aucun push sans phrase de `/livre`" bloquait ce cas d'usage.

## 2026-07-27 — `chore/readme-utilisation` (pas d'issue formelle)

Ajoute un `README.md` à la racine du dépôt : point d'entrée pratique et
humain pour utiliser Gouvernail (prérequis, démarrage d'un nouveau projet
via `/amorce-projet`, cycle de vie d'une tâche, table des 11 skills
disponibles), complémentaire à `CLAUDE.md` qui reste la doctrine détaillée.
Répond à un besoin identifié en conversation : jusqu'ici, comprendre comment
utiliser le framework nécessitait de lire `CLAUDE.md` en entier (écrit comme
instructions pour Claude, pas comme guide de démarrage).
