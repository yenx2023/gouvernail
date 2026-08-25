## Accès

- **GitLab est la seule source de vérité** : backlog, issues, décision de
  merge. C'est là que tout se décide.
- **GitHub est une façade d'exécution technique**, imposée par Claude Code
  Cloud. Il n'a aucune autorité : pas de review qui compte, pas de merge
  décisionnel, pas de protection de branche significative. Le code y
  transite, rien de plus.
- **La review et le merge réels se font via une Merge Request GitLab** —
  voir Cycle de vie d'une tâche. Le `main` GitHub est resynchronisé après
  coup depuis GitLab, jamais l'inverse : ne jamais pousser manuellement un
  `main` GitHub qui n'a pas d'abord été mergé côté GitLab.
- API GitLab : REST v4 (`https://gitlab.com/api/v4`) + GraphQL
  (`https://gitlab.com/api/graphql`), authentifiées par un token dans la
  variable d'environnement `GITLAB_TOKEN`. Toujours passer par le helper
  `scripts/gitlab-api.sh` (fonctions `gitlab_rest`, `gitlab_graphql`,
  `gitlab_git`) plutôt que des appels `curl`/`git push` ad hoc.
- GitHub : accès natif Claude Code (local et Cloud), pour clone/branch/commit/push.
- Identité du projet GitLab courant : `.claude/gitlab-project.env`
  (`GITLAB_PROJECT_PATH`/`GITLAB_PROJECT_ID`) — jamais codée en dur dans les
  scripts/skills, toujours lue depuis ce fichier.
