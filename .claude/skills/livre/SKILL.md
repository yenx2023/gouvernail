---
name: livre
description: Déclenche le vrai gate de validation GitLab Flow — commit, push (GitHub + GitLab), ouverture puis (sur demande explicite) merge d'une Merge Request GitLab. Usage explicite `/livre` (mode `revue` ou `merge`), ou déclenché automatiquement dès que l'utilisateur dit "tu peux commiter" / "tu peux commiter et merger" dans la conversation.
---

# livre

## Objectif

Remplacer l'ancien gate `.claude/validated` (fichier marqueur, abandonné —
mauvaise interprétation de la doctrine de validation humaine) par le vrai
mécanisme voulu : une Merge Request GitLab, ouverte puis mergée sur GitLab
lui-même. Le déclencheur n'est jamais implicite : toujours une phrase
explicite de l'utilisateur dans la conversation, ou l'invocation `/livre`.

**Deux modes**, correspondant à deux phrases distinctes :

- **Mode "revue"** — déclenché par *"tu peux commiter"* (ou `/livre revue`) :
  commit + push (GitHub et GitLab) + ouverture de la Merge Request. Pas de
  merge.
- **Mode "merge"** — déclenché par *"tu peux commiter et merger"* (ou
  `/livre merge`) : tout ce qui précède, **plus** le merge de la Merge
  Request, la resynchronisation de `main` GitHub, et un commentaire sur
  l'issue GitLab liée.

Si la phrase de l'utilisateur est ambiguë sur le mode, demander avant d'agir
— ne jamais merger sans le "... et merger" explicite.

## Prérequis

- `GITLAB_TOKEN` configuré (`.env` local ou variable d'environnement Cloud —
  même token que celui utilisé par `/backlog-gitlab` et `/tache`, scopé au
  groupe GitLab, voir CLAUDE.md > Sécurité du token GitLab). Si
  `scripts/gitlab-api.sh` échoue avec "GITLAB_TOKEN absent", s'arrêter et
  demander à l'utilisateur de le configurer.
- Être sur une branche de travail nommée selon la convention
  `<type>/<numero-issue>-<slug>` (créée par le skill `/tache`) — **jamais sur
  `main`**. Si la branche courante est `main`, s'arrêter : rien à livrer.
- Le numéro d'issue est extrait du nom de branche. Ce skill suppose que
  l'issue vit sur le même projet GitLab que le code — l'identité du projet
  (chemin + id) est décrite dans `.claude/gitlab-project.env`
  (`GITLAB_PROJECT_PATH`/`GITLAB_PROJECT_ID`), jamais codée en dur ici. Ce
  fichier est ce qui change quand ce framework est réutilisé dans un nouveau
  dépôt pour un nouveau projet (voir CLAUDE.md > Réutiliser ce framework pour
  un nouveau projet).

## Étapes — Mode "revue"

1. Vérifier qu'on n'est pas sur `main` (`git branch --show-current`). Sinon,
   s'arrêter et expliquer pourquoi.
2. S'il y a des changements en attente (`git status --short`), `git add` +
   `git commit` avec un message clair décrivant le changement. S'il n'y a
   rien à committer mais des commits locaux non poussés, continuer sans
   recommitter.
3. `git push origin <branche>` (GitHub, pour la continuité Cloud).
4. `scripts/gitlab-api.sh push <branche> <branche>` (pousse la même branche
   sur GitLab).
5. Extraire le numéro d'issue du nom de branche. Charger l'identité du projet
   (`source .claude/gitlab-project.env`) puis ouvrir la Merge Request :
   ```
   scripts/gitlab-api.sh rest POST "projects/${GITLAB_PROJECT_ID}/merge_requests" \
     '{"source_branch":"<branche>","target_branch":"main","title":"<titre>","description":"Closes #<numero>"}'
   ```
   Si une MR existe déjà pour cette branche (erreur "already exists"), la
   retrouver (`GET .../merge_requests?source_branch=<branche>`) plutôt que
   d'échouer.
6. Rapporter l'URL de la MR à l'utilisateur (`web_url` de la réponse). Fin —
   ne jamais merger à ce stade.

## Étapes — Mode "merge"

Exécuter les étapes 1 à 5 du mode "revue" ci-dessus (ou vérifier qu'une MR
ouverte existe déjà pour la branche), puis :

7. Merger la Merge Request. L'API GitLab **exige le champ `sha`** (le
   `sha` de la réponse d'ouverture de la MR à l'étape 5, ou récupéré via
   `GET .../merge_requests/<iid>`) — un `PUT .../merge` sans ce champ échoue
   avec `400 "SHA must be provided when merging"` (vérifié en conditions
   réelles le 2026-07-27) :
   ```
   scripts/gitlab-api.sh rest PUT "projects/${GITLAB_PROJECT_ID}/merge_requests/<iid>/merge" \
     '{"sha":"<sha_de_la_mr>"}'
   ```
   Si le merge échoue (conflits, pipeline requis, etc.), s'arrêter et
   rapporter l'erreur — ne jamais forcer.
8. Resynchroniser `main` GitHub **sans toucher à la branche locale
   courante** :
   ```
   scripts/gitlab-api.sh fetch main
   git push origin FETCH_HEAD:main
   ```
9. Commenter puis **fermer** l'issue GitLab liée — le merge explicite
   ("tu peux commiter et merger") **est** la confirmation de livraison, la
   fermeture n'a plus besoin d'être redemandée séparément :
   ```
   scripts/gitlab-api.sh rest POST "projects/${GITLAB_PROJECT_ID}/issues/<numero>/notes" \
     '{"body":"Livré via Merge Request <web_url>."}'
   scripts/gitlab-api.sh rest PUT "projects/${GITLAB_PROJECT_ID}/issues/<numero>" \
     '{"state_event":"close"}'
   ```
10. **Fermer le milestone associé si c'était sa dernière issue ouverte.**
    Lire le `milestone.id` de l'issue (déjà dans la réponse de l'étape
    précédente), puis vérifier s'il reste des issues ouvertes dedans :
    ```
    scripts/gitlab-api.sh rest GET "projects/${GITLAB_PROJECT_ID}/issues?milestone_id=<milestone_id>&state=opened"
    ```
    Si la liste est vide, fermer le milestone :
    ```
    scripts/gitlab-api.sh rest PUT "projects/${GITLAB_PROJECT_ID}/milestones/<milestone_id>" \
      '{"state_event":"close"}'
    ```
    Si l'issue n'a pas de milestone, sauter cette étape.
11. Ajouter une entrée dans `docs/JOURNAL.md` (créer le fichier avec un
    titre "# Journal" s'il n'existe pas) : date du jour, numéro d'issue,
    nom de branche, résumé en une phrase du travail livré.
12. Récapituler à l'utilisateur : MR mergée (URL), `main` GitHub
    synchronisé, issue fermée (+ milestone fermé si c'était le cas),
    `docs/JOURNAL.md` mis à jour.

Pour fermer une issue **en dehors** de ce flux (décidée comme non
pertinente, doublon, ou rattrapage d'une clôture manquée) : skill
`/cloture <numero-issue>`, invoqué explicitement — jamais ce skill `/livre`
ne doit fermer une issue qui n'est pas celle de la branche en cours de
merge.

## Ce que ce skill ne doit jamais faire seul

- Committer, pousser une branche, ou ouvrir une Merge Request sans la phrase
  de validation explicite de l'utilisateur.
- Merger une Merge Request sans le "... et merger" explicite — même si le
  mode "revue" vient d'être exécuté avec succès, ne pas enchaîner sur le
  merge sans nouvelle confirmation.
- Committer directement sur `main`.
- Fermer une issue autre que celle de la branche en cours de merge, ou un
  milestone qui a encore des issues ouvertes.
- Forcer un merge en cas de conflit ou d'échec (`--force`, résolution
  automatique de conflit) : s'arrêter et rapporter à l'utilisateur.
