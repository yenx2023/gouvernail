---
name: absorbe
description: Absorbe une nouvelle version d'un produit tiers personnalisé (profil produit-tiers de Gouvernail) sans perdre les personnalisations ni les corrections de bugs documentées dans docs/REGISTRE.md. Workflow en 6 phases validées une à une, sur le modèle de /investigue. Utilise sur /absorbe, "absorbe la version X", "mets à jour vers la version X", "monte de version", ou dès qu'un changelog/une nouvelle version du produit amont est mentionnée.
---

# absorbe

## Objectif

Exécuter une montée de version d'un produit tiers personnalisé (voir
CLAUDE.md > Produit tiers & registre de divergence) sans écraser une
personnalisation ni perdre une correction de bug documentée. Ce skill porte
la **discipline du processus** — il ne connaît rien du produit lui-même.
Le détail opérationnel (architecture, commandes de build, pièges connus)
vit dans le skill produit dédié de ce projet (ex. `<produit>-update`), à
consulter à chaque phase où il existe.

Comme `/investigue`, ce skill se déroule en phases numérotées. **Chaque
phase s'arrête et attend une validation explicite avant la suivante** —
jamais d'enchaînement automatique, une absorption de version touche
potentiellement tout le code personnalisé du projet.

## Prérequis

- `docs/REGISTRE.md` existe (créé par `/amorce-projet --profil
  produit-tiers`). S'il est vide, c'est normal pour un premier amorçage —
  continuer, mais avertir que rien ne protège encore de personnalisation
  connue.
- Le code source de la nouvelle version amont est disponible (fourni par
  l'utilisateur, un répertoire local, ou un accès à télécharger).
- Le repo suit la convention à deux branches + tags (voir CLAUDE.md >
  Stratégie Git) : `main` (ou `staging` en régime déployé), et une branche
  orpheline `upstream` portant les tags `upstream-vX.Y` (imports amont
  purs). Si cette convention n'existe pas encore sur ce projet (première
  absorption), la Phase 1 la met en place.

## PHASE 0 : Collecte d'informations

1. Version actuelle déployée (`git tag -l 'upstream-*'`, dernier tag de
   release applicatif).
2. Version cible — demander à l'utilisateur si ambigu.
3. Changelog de la nouvelle version — WebFetch/WebSearch sur la
   documentation/marketplace du produit si une URL est connue (voir skill
   produit dédié du projet, ou demander à l'utilisateur).
4. Lire `docs/REGISTRE.md` en entier — c'est la liste de tout ce qui ne
   doit pas se perdre.
5. Lire le skill produit dédié du projet s'il existe (pièges connus,
   architecture, commandes) — sinon noter l'absence, cette absorption sera
   l'occasion d'en amorcer un.

Présente un résumé (version actuelle → cible, nombre d'entrées dans le
registre à surveiller, changelog en 3-4 points). **Arrête-toi, attends
validation avant la Phase 1.**

## PHASE 1 : Analyse et classification

1. Si le code de la nouvelle version n'est pas encore importé sur la
   branche orpheline `upstream` : l'importer maintenant (remplacement des
   seuls répertoires source du produit — jamais les secrets, configuration
   d'environnement, données persistantes ; voir skill produit dédié pour
   la liste exacte des chemins concernés sur ce projet), committer, tagger
   `upstream-vX.Y`.
2. `git diff upstream-vOLD..upstream-vNEW --stat` — vue d'ensemble des
   fichiers changés côté amont.
3. `git diff --name-only upstream-vOLD..<branche-de-travail>` — fichiers
   personnalisés localement.
4. Croiser les deux : classer chaque fichier personnalisé en
   - modifié uniquement par nous → pas de conflit à l'absorption,
   - modifié par les deux côtés → conflit à trancher, chercher l'entrée
     `docs/REGISTRE.md` correspondante pour comprendre l'intention avant de
     décider,
   - fichier disparu côté amont → vérifier si la fonctionnalité a migré
     ailleurs avant de considérer la personnalisation obsolète.
5. Identifier les nouveautés amont nécessitant une action (nouvelle
   permission/migration/traduction/config) même hors fichiers déjà
   personnalisés.

Présente le plan de classification (liste des conflits identifiés, avec la
divergence `docs/REGISTRE.md` associée à chacun). **Arrête-toi, attends
validation avant la Phase 2.**

## PHASE 2 : Import et merge

1. Tag de sauvegarde avant toute modification : `git tag pre-update-vX.Y`
   sur la branche de travail actuelle.
2. Créer une branche de tâche dédiée à cette absorption (`chore/<issue>-
   absorbe-vX.Y`, voir `/tache`) — **jamais de merge direct sur `main`**,
   même en régime distribué sans `staging` : une absorption de version
   touche potentiellement tout le projet, elle suit le cycle de vie normal
   d'une tâche comme n'importe quel autre changement.
3. Merger `upstream` (ou la branche portant l'import de la nouvelle
   version) dans cette branche de tâche.
4. Résoudre chaque conflit identifié en Phase 1, un par un, en s'appuyant
   sur l'entrée `docs/REGISTRE.md` correspondante pour décider : garder
   notre version, prendre l'amont, ou fusionner les deux.

**Arrête-toi, attends validation avant la Phase 3** — présente le résumé
des conflits résolus et comment.

## PHASE 3 : Réapplication

**`docs/REGISTRE.md` n'est pas une garantie d'exhaustivité.** Il ne
documente que les divergences explicitement consignées au fil des tâches
précédentes. Si la Phase 2 a résolu des conflits en prenant largement
`--theirs` (ou toute résolution qui privilégie systématiquement l'amont),
des personnalisations qui vivaient dans des fichiers **non conflictuels**
peuvent avoir été silencieusement écrasées par le merge automatique — Git
ne signale rien puisqu'il n'y a pas eu de conflit à trancher. Sur une
absorption réelle, l'écart entre le nombre de fichiers réellement
personnalisés et le nombre d'entrées du registre peut être d'un ordre de
grandeur (dizaines de fichiers vs plusieurs centaines) : piloter la
réapplication par le seul registre laisse alors un angle mort large.

1. **Audit différentiel complet, en plus du passage par le registre** :
   `git diff --name-only upstream-vOLD..pre-update-vNEW -- <chemins source
   du produit>` donne la liste exhaustive des fichiers avec une
   divergence réelle par rapport à l'amont précédent. Comparer cette liste
   au nombre d'entrées du registre — si l'écart est important, prévenir
   l'utilisateur avant de continuer et proposer un audit par lots
   thématiques (par domaine fonctionnel) plutôt qu'une réapplication
   pilotée uniquement par les entrées connues.
2. **Méthode de vérification recommandée ("diff vérité-terrain")**, plus
   fiable que `git apply --3way` (qui construit sa propre résolution
   ours/theirs sans le contexte des vrais commits) : pour chaque fichier,
   comparer trois références —
   - `git diff -w upstream-vOLD..pre-update-vNEW -- <fichier>` : notre
     delta réel avant l'absorption (le `-w`, ignore whitespace, est
     important — une bonne partie des "deltas" apparents ne sont que du
     bruit de fin de ligne ou de reformatage) ;
   - `git diff -w upstream-vOLD..upstream-vNEW -- <fichier>` : delta amont
     — l'amont a pu corriger nativement le même problème, à comparer avant
     de réappliquer aveuglément par-dessus ;
   - `git diff -w upstream-vNEW..HEAD -- <fichier>` (ou `pre-update-vNEW`)
     : ce qui manque réellement dans l'état actuel.
   Ne réappliquer que la logique fonctionnelle réellement perdue, jamais
   écraser une refonte native de l'amont sans l'avoir comparée.
3. Pour chaque entrée de `docs/REGISTRE.md` : vérifier qu'elle est
   toujours présente et fonctionnelle dans le code après merge, avec la
   méthode ci-dessus. Pour une correction de bug documentée, si l'amont
   l'a corrigée nativement, comparer les deux corrections pour
   compatibilité avant de choisir laquelle garder.
4. **Avant de réappliquer un delta décrit comme manquant** (que ce soit
   par une entrée du registre ou par une tâche déléguée), vérifier
   `git log --oneline --all -- <fichier>` et lire les messages de commit —
   un correctif ultérieur a pu retirer délibérément une partie d'un
   correctif antérieur (parce qu'il causait un autre problème), ou la
   documentation elle-même peut être en décalage avec le code réel
   historique. Ne jamais faire confiance à une description sans vérifier
   contre l'historique git.
5. Consulter le skill produit dédié du projet pour les pièges connus liés à
   cette version ou ce type de changement (voir sa base de pièges).

**Arrête-toi, attends validation avant la Phase 4.**

## PHASE 4 : Tests

Exécuter la checklist de vérification du projet (build, tests automatisés,
smoke test manuel — voir CLAUDE.md > Tests et le skill produit dédié pour
le détail exact adapté à ce projet). Rapporter explicitement ce qui a été
vérifié et ce qui ne l'a pas été (voir CLAUDE.md.template de Gouvernail >
Tests > limite de vérification visuelle en session Cloud, si applicable).

**Arrête-toi, attends validation avant la Phase 5.**

## PHASE 5 : Documentation et livraison

1. Pour chaque divergence touchée pendant cette absorption (réappliquée,
   modifiée, ou confirmée obsolète parce qu'absorbée nativement) : mettre à
   jour `docs/REGISTRE.md` via le skill `/registre`. Si l'audit de la Phase
   3 a fait remonter beaucoup de divergences jamais documentées jusque-là,
   ne pas ouvrir mécaniquement une issue par divergence trouvée — regrouper
   par famille sous une entrée unique (ex. rattachée à l'issue de
   l'absorption elle-même) est plus lisible qu'une dizaine d'entrées
   quasi-identiques ; demander à l'utilisateur en cas de doute sur le bon
   grain.
2. Pour chaque piège rencontré pendant cette absorption : le capitaliser
   via le skill `/piege`.
3. **Vérifier que le numéro de version du projet (fichier de manifeste :
   `pubspec.yaml`, `package.json`, `build.gradle`, etc., selon
   l'écosystème) reflète bien la nouvelle base amont**, selon la convention
   du projet (voir CLAUDE.md du projet — généralement `X.Y` dérivé de la
   version amont). Un import qui remplace le fichier de manifeste en Phase
   1/2 peut faire régresser ce numéro vers la valeur par défaut de l'amont,
   ou simplement l'oublier — cette régression ne casse ni le build ni les
   tests, donc rien d'autre ne la détecte.
4. Suivre le cycle de vie normal de la tâche (CLAUDE.md > Cycle de vie
   d'une tâche) : `/livre` sur la phrase de validation explicite de
   l'utilisateur.

## Ce que ce skill ne doit jamais faire seul

- Enchaîner une phase sur la suivante sans validation explicite de
  l'utilisateur.
- Merger la branche d'absorption vers `main` (ou `staging` en régime
  déployé) — reste soumis au cycle de vie normal de la tâche, `/livre`.
- Remplacer un fichier hors du périmètre déclaré de l'absorption (secrets,
  signature, configuration d'environnement, données persistantes) — voir
  CLAUDE.md > Ce que Claude ne doit jamais faire seul.
- Considérer une divergence comme obsolète/absorbée sans une vérification
  explicite (diff amont) confirmant qu'elle est effectivement couverte
  nativement.
- Considérer la Phase 3 terminée sur la seule base des entrées de
  `docs/REGISTRE.md` quand la Phase 2 a résolu des conflits en `--theirs`
  à grande échelle, sans un audit différentiel complet (voir Phase 3.1) —
  le registre n'est pas une garantie d'exhaustivité.
- Sauter la Phase 4 (tests) même sous pression de temps.
