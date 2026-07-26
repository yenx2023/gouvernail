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
