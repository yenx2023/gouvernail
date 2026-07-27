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
