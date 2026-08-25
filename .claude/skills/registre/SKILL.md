---
name: registre
description: Consigne ou met à jour une divergence par rapport au produit tiers amont (personnalisation, correctif préservé, contournement) dans docs/REGISTRE.md, référencée par numéro d'issue GitLab plutôt que dupliquée. Profil produit-tiers de Gouvernail. Usage : /registre <numero-issue>
---

# registre

## Objectif

Tenir `docs/REGISTRE.md` à jour — le document pivot du profil
`produit-tiers` (voir CLAUDE.md > Produit tiers & registre de divergence).
Symétrique de `/cloture` : appelé en fin de tâche quand celle-ci a introduit
ou modifié une divergence par rapport à l'amont, jamais automatique.

Ce skill ne touche jamais à git, à GitLab (hors lecture), ni au code — il
ne fait que lire l'issue liée et écrire dans `docs/REGISTRE.md`.

## Prérequis

- L'issue GitLab existe déjà et décrit la tâche qui vient d'introduire la
  divergence.
- `GITLAB_TOKEN` configuré. Si `scripts/gitlab-api.sh` échoue avec
  "GITLAB_TOKEN absent", s'arrêter et demander à l'utilisateur de le
  configurer.

## Format d'une entrée `docs/REGISTRE.md`

```markdown
### #<numero-issue> — <titre court>

**Type** : personnalisation | correctif préservé | contournement
**Fichiers** : <liste des fichiers/répertoires concernés>
**Intention** : <pourquoi cette divergence existe, en une ou deux phrases>
**Statut face à l'amont** : présente depuis <upstream-vX.Y> · toujours
nécessaire (vérifié le <date>) | absorbée nativement en <upstream-vX.Y>,
divergence obsolète
```

## Étapes

1. **Lire l'issue** liée : `gitlab_rest GET
   "projects/${GITLAB_PROJECT_ID}/issues/<numero>"`. Si l'appel échoue,
   s'arrêter et rapporter l'erreur.
2. **Déterminer le type** de divergence à partir des labels de l'issue
   (`personnalisation`, `bug` → correctif préservé) et de sa description.
   Si ambigu, demander à l'utilisateur plutôt que deviner.
3. **Chercher une entrée existante** pour ce numéro d'issue dans
   `docs/REGISTRE.md`. Si trouvée (une tâche ultérieure sur la même
   divergence, ex. une absorption qui la reconfirme), mettre à jour son
   « Statut face à l'amont » plutôt que d'en créer une seconde. Sinon,
   créer une nouvelle entrée selon le format ci-dessus.
4. **Rédiger l'intention** en s'appuyant sur la description de l'issue et
   le contexte de la conversation — pas une reformulation du titre, la
   vraie raison métier/technique de la divergence.
5. **Récapituler** à l'utilisateur : entrée créée ou mise à jour, chemin
   `docs/REGISTRE.md`.

## Ce que ce skill ne doit jamais faire seul

- Committer, pousser, ou toucher au code — hors périmètre, voir `/livre`.
- Fermer ou modifier l'issue GitLab — hors périmètre, voir `/cloture`.
- Inventer une intention non déductible de l'issue ou de la conversation :
  demander plutôt que de deviner.
- Créer une deuxième entrée pour un numéro d'issue déjà présent dans le
  registre — toujours chercher l'entrée existante d'abord.
