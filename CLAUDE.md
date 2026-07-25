# CLAUDE.md — Conventions du projet

## Doctrine (à ne jamais enfreindre)

- **GitLab est la seule source de vérité projet** : backlog, epics, issues, jalons,
  décision de merge. C'est là que tout se décide.
- **GitHub est une façade d'exécution technique**, imposée par Claude Code Cloud.
  Il n'a aucune autorité : pas de review qui compte, pas de merge décisionnel,
  pas de protection de branche significative. Le code y transite, rien de plus.
- Le code sur GitHub est répliqué vers GitLab en sens unique (miroir), jamais
  l'inverse. Ne jamais pousser manuellement sur la copie miroir côté GitLab.

## Accès

- GitLab : via le serveur MCP (`/mcp` pour vérifier la connexion). Toujours
  passer par les tools MCP pour lire/écrire les issues, epics, milestones —
  jamais d'appel API GitLab manuel en dehors du MCP.
- GitHub : accès natif Claude Code (local et Cloud), pour clone/branch/commit/push.

### Limitation actuelle : MCP GitLab indisponible en session cloud

Les sessions Claude Code Cloud (web/app) ne chargent pas les MCP servers
configurés (limitation Anthropic connue, pas une erreur de config de ce repo).
En session cloud, **ne pas tenter d'appeler les tools GitLab** — ils ne seront
pas disponibles.

Règle de contournement : en session cloud, l'utilisateur colle le contexte de
l'issue GitLab directement dans le prompt (numéro, titre, description). Claude
travaille sur cette base sans accès GitLab autonome. La mise à jour de l'issue
(commentaire, fermeture, avancement de l'epic) se fait ensuite en session
locale, une fois le MCP GitLab de nouveau disponible.

À revérifier périodiquement : si Anthropic corrige cette limitation, retirer
cette section et repasser au flux normal (issue lue et mise à jour directement
en session cloud via MCP).

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
5. À la clôture : mettre à jour l'issue/epic GitLab correspondante via MCP
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