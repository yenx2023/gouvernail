# Gouvernail

Framework réutilisable pour développer un projet avec Claude Code en
suivant de vraies pratiques d'ingénierie : cadrage structuré, backlog GitLab,
versioning GitLab Flow, et livraison contrôlée par une phrase de validation
explicite plutôt qu'un fichier marqueur.

Ce dépôt lui-même n'héberge jamais de projet produit — c'est l'outillage
(skills, scripts, doctrine) à copier vers chaque nouveau projet via
`/amorce-projet`. La doctrine complète (règles à ne jamais enfreindre,
limitations connues, sécurité du token) vit dans [`CLAUDE.md`](CLAUDE.md) ;
ce README est le point d'entrée pratique pour démarrer.

## Prérequis

- Un groupe GitLab (ex. `ai-agent-projects`) et un compte GitHub.
- [`gh`](https://cli.github.com/) authentifié (`gh auth login`) — nécessaire
  pour `/amorce-projet`, qui crée les dépôts GitHub des nouveaux projets.
- Un **Personal Access Token GitLab fine-grained**, scopé au groupe (pas à un
  projet précis) — un seul token pour tout le groupe, réutilisable pour
  chaque nouveau projet. Permissions exactes et procédure de création :
  voir `CLAUDE.md` > *Sécurité du token GitLab*.
- `git`, `curl`, `jq` installés.
- Le token placé dans un fichier `.env` local (copier `.env.example`) :
  ```
  GITLAB_TOKEN=<ton_token>
  ```
  Jamais committé (`.env` est gitignoré) ; en session Cloud, passer par une
  variable d'environnement personnelle plutôt qu'un secret partagé.

## Démarrer un nouveau projet

Depuis une session Claude Code ouverte **sur ce dépôt** (Gouvernail) :

```
/amorce-projet ../mon-projet --nom mon-projet --description "..."
```

Ce skill crée le projet GitLab et le dépôt GitHub dédiés, copie l'outillage
(skills, `scripts/gitlab-api.sh`, `tests/`) vers le nouveau répertoire, et
génère un `CLAUDE.md` adapté — chaque action externe (création de
projet/dépôt, push) reste soumise à ta confirmation. `/amorce-projet`
lui-même n'est jamais copié : il ne vit que dans Gouvernail.

Ensuite, dans une session ouverte sur ce nouveau répertoire :

1. `/cadre` — questionnement structuré, produit `docs/PRD.md`.
2. `/planifie` — découpe le PRD en phases livrables, produit `docs/PLAN.md`.
3. `/backlog-gitlab docs/PLAN.md` — transforme le plan en Milestones +
   Issues GitLab (avec ton accord sur le découpage avant toute écriture).

## Cycle de vie d'une tâche

Une fois le backlog peuplé :

1. `/tache <numero-issue>` — lit l'issue GitLab, crée la branche locale
   correspondante (`<feature|fix|chore>/<numero>-<slug>`).
2. Développer, committer localement au fil de l'eau si besoin.
3. Une phrase explicite déclenche la suite (jamais automatique) :
   - **"tu peux commiter"** → commit + push (GitHub et GitLab) + ouverture
     d'une Merge Request GitLab. Pas de merge.
   - **"tu peux commiter et merger"** → tout ce qui précède, **plus** le
     merge de la MR, la resynchronisation de `main` GitHub, la fermeture de
     l'issue (et du milestone si c'était sa dernière issue ouverte), et une
     entrée dans `docs/JOURNAL.md`.
4. La review réelle a lieu sur la Merge Request GitLab — c'est le seul vrai
   point de décision humaine.

Fermer une issue **en dehors** de ce flux (doublon, décision de ne pas la
faire, rattrapage) : `/cloture <numero-issue>`, toujours invoqué
explicitement.

## Skills disponibles

| Skill | Rôle |
|---|---|
| `/amorce-projet` | Amorce un nouveau projet (GitLab + GitHub + outillage). Outil méta, reste dans Gouvernail. |
| `/interroge` | Questionnement structuré pour cadrer une idée de feature/app. |
| `/cadre` | Produit ou étend `docs/PRD.md` (8 sections fixes). |
| `/planifie` | Découpe le PRD en phases verticales, produit `docs/PLAN.md`. |
| `/design` | Produit `docs/DESIGN.md` + preview HTML du système de design. |
| `/investigue` | Investigation méthodique d'un bug en 4 phases validées. |
| `/illustre` | Diagrammes et visuels Excalidraw. |
| `/backlog-gitlab` | Convertit un PRD/PLAN en Milestones + Issues GitLab. |
| `/tache` | Crée la branche locale liée à une issue GitLab existante. |
| `/livre` | Le vrai gate : commit, push, ouverture puis merge d'une MR GitLab. |
| `/cloture` | Ferme une issue hors du flux normal de merge. |

Les six premiers (`interroge` à `illustre`) sont vendorisés depuis
[`claude-mastery`](https://github.com/naiersaidane/claude-mastery) (MIT) ;
les cinq suivants sont propres à Gouvernail.

## Limitation connue

Le groupe GitLab est en tier **Free** : pas d'Epics (Premium/Ultimate requis)
— les **Milestones** jouent ce rôle de regroupement à la place. Seul le lien
`relates_to` fonctionne entre issues (`blocks`/`is_blocked_by` échouent sur
ce tier). Détail et impact sur les skills : voir `CLAUDE.md` > *Limitation
vérifiée*.

## Tests

`scripts/gitlab-api.sh` (le point de passage unique vers l'API GitLab) est
couvert par `tests/gitlab-api.test.sh` — suite hors-ligne (curl et sleep
mockés, aucun appel réseau) :

```
bash tests/gitlab-api.test.sh
```

## Aller plus loin

- `CLAUDE.md` — doctrine complète : ce que Claude ne doit jamais faire seul,
  convention de nommage des branches, sécurité du token, répartition
  REST/GraphQL vérifiée en conditions réelles.
- `docs/JOURNAL.md` — journal chronologique des tâches livrées sur ce
  dépôt, à lire en début de session pour retrouver le contexte.
