---
name: cloture
description: Ferme une issue GitLab suite à confirmation explicite que le travail est réellement livré — action distincte et délibérée, jamais automatique même après un merge (voir CLAUDE.md > Cycle de vie d'une tâche). Usage : /cloture <numero-issue>
---

# cloture

## Objectif

Fournir un mécanisme cohérent pour l'étape 6 du "Cycle de vie d'une tâche"
(voir CLAUDE.md) : fermer une issue GitLab après confirmation que le travail
est réellement livré. Avant ce skill, cette étape se faisait via des appels
`gitlab-api.sh` ad hoc, avec un risque d'entrées `docs/JOURNAL.md`
incohérentes d'une clôture à l'autre.

Ce skill ne touche jamais au code, à git, ni aux Merge Requests — il ferme
une issue déjà livrée et met à jour la trace correspondante dans
`docs/JOURNAL.md`.

## Prérequis

- `GITLAB_TOKEN` configuré. Si `scripts/gitlab-api.sh` échoue avec
  "GITLAB_TOKEN absent", s'arrêter et demander à l'utilisateur de le
  configurer.
- Le projet GitLab cible se résout depuis `.claude/gitlab-project.env`
  (`GITLAB_PROJECT_PATH`/`GITLAB_PROJECT_ID`), comme les autres skills — voir
  CLAUDE.md > Réutiliser ce framework pour un nouveau projet. Si ce fichier
  est absent, demander le projet à l'utilisateur.
- Pas d'Epics sur ce tier (Free) — ce skill ne gère que des Issues, jamais
  des Epics (voir CLAUDE.md > Limitation vérifiée : pas d'Epics).

## Étapes

1. **Lire l'issue** : `gitlab_rest GET "projects/${GITLAB_PROJECT_ID}/issues/<numero>"`.
   Si l'appel échoue (issue inexistante), s'arrêter et rapporter l'erreur.
2. **Vérifier l'état actuel.** Si `state` est déjà `"closed"`, informer
   l'utilisateur qu'il n'y a rien à faire et s'arrêter — ne pas rouvrir ni
   re-fermer.
3. **Vérifier qu'une Merge Request associée a bien été mergée**, par
   cohérence de branche (`gitlab_rest GET
   "projects/${GITLAB_PROJECT_ID}/merge_requests?state=merged"`, chercher une
   `source_branch` contenant `-<numero>-` ou commençant par `<type>/<numero>-`).
   Si aucune MR mergée correspondante n'est trouvée, avertir explicitement
   l'utilisateur ("aucune MR mergée détectée pour l'issue #<numero> — bien
   confirmer que le travail est livré avant de fermer") et attendre sa
   confirmation avant de continuer. Ne jamais fermer silencieusement une
   issue sans travail livré détectable.
4. **Fermer l'issue** :
   ```
   scripts/gitlab-api.sh rest PUT "projects/${GITLAB_PROJECT_ID}/issues/<numero>" \
     '{"state_event":"close"}'
   ```
5. **Ajouter un commentaire de clôture** résumant la livraison (ou
   référençant la MR déjà commentée par `/livre` si le mode "merge" a été
   utilisé) :
   ```
   scripts/gitlab-api.sh rest POST "projects/${GITLAB_PROJECT_ID}/issues/<numero>/notes" \
     '{"body":"Issue clôturée — travail livré et confirmé."}'
   ```
6. **Mettre à jour `docs/JOURNAL.md`** : chercher l'entrée existante qui
   mentionne cette issue (créée par `/livre` au moment du merge). Si trouvée,
   lui ajouter une ligne `Clôturée le <date du jour>.` à la fin. Si aucune
   entrée ne mentionne cette issue (clôture sans passage préalable par
   `/livre`, cas rare), créer une entrée minimale avec la date, le numéro
   d'issue et une mention "clôturée directement, sans entrée de livraison
   préexistante".
7. **Récapituler** à l'utilisateur : issue fermée (numéro + titre), entrée
   `docs/JOURNAL.md` mise à jour.

## Ce que ce skill ne doit jamais faire seul

- Fermer une issue sans que l'utilisateur ait explicitement invoqué ce skill
  avec le numéro d'issue (jamais de clôture en masse ou implicite).
- Fermer une issue déjà fermée, ou la rouvrir.
- Fermer une issue sans MR mergée détectée, sans avoir d'abord obtenu une
  confirmation explicite de l'utilisateur que le travail est bien livré.
- Créer ou gérer des Epics (indisponibles sur ce tier).
- Toucher à git, au code, ou aux Merge Requests — hors périmètre (voir
  skill `/livre`).
