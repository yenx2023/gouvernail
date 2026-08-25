## Accès

- **GitLab est la seule plateforme** — code et suivi. Pas de GitHub sur ce
  projet : Claude Code Cloud n'est pas utilisé ici, donc pas de façade
  d'exécution à maintenir. Toute Merge Request, tout push, se fait
  directement vers GitLab.
- API GitLab : REST v4 (`https://gitlab.com/api/v4`) + GraphQL
  (`https://gitlab.com/api/graphql`), authentifiées par un token dans la
  variable d'environnement `GITLAB_TOKEN`. Toujours passer par le helper
  `scripts/gitlab-api.sh` (fonctions `gitlab_rest`, `gitlab_graphql`,
  `gitlab_git`) plutôt que des appels `curl`/`git push` ad hoc.
- Identité du projet GitLab courant : `.claude/gitlab-project.env`
  (`GITLAB_PROJECT_PATH`/`GITLAB_PROJECT_ID`) — jamais codée en dur dans les
  scripts/skills, toujours lue depuis ce fichier.
- **Si Claude Code Cloud devient utile un jour sur ce projet** (exécution
  autonome sans supervision continue), GitHub redevient nécessaire comme
  façade d'exécution — voir le `CLAUDE.md` de Gouvernail > Doctrine, et
  répéter la partie « créer le dépôt GitHub » de `/amorce-projet` a
  posteriori. Jusque-là, ne pas ajouter de remote GitHub par anticipation.
