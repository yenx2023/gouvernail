---
name: piege
description: Capitalise un piège rencontré pendant l'absorption d'une version du produit tiers amont (symptôme, cause, solution) dans la base de pièges du skill produit dédié de ce projet. Profil produit-tiers de Gouvernail. Usage : /piege, ou dès qu'un piège vient d'être résolu pendant une session (contournement non évident, erreur inattendue après montée de version).
---

# piege

## Objectif

Éviter de refaire deux fois la même investigation. Chaque piège
opérationnel rencontré en absorbant une version amont — un comportement non
documenté, un ordre d'opérations non évident, une régression connue — est
capitalisé dans la base de pièges du skill produit dédié de ce projet
(ex. `<produit>-update/references/pieges.md`), pas seulement résolu et
oublié.

Différence avec `/registre` : le registre documente **en quoi notre code
diverge** de l'amont (état). Ce skill documente **comment ne pas se
refaire avoir** en absorbant une future version (procédural) — un piège
n'est pas forcément lié à une divergence (ex. « toujours relancer les
migrations après cette étape » n'est pas une personnalisation).

## Prérequis

- Un skill produit dédié existe pour ce projet (ex. `<produit>-update`,
  structuré `SKILL.md` + `references/`). S'il n'existe pas encore
  (première absorption de ce produit), proposer de l'amorcer maintenant
  avec une structure minimale (`SKILL.md` + `references/pieges.md`) plutôt
  que d'improviser un autre emplacement.

## Étapes

1. **Identifier le piège** : symptôme observé, cause réelle (pas juste le
   symptôme), solution appliquée. Si l'un des trois manque encore
   (résolution en cours), attendre que le fix soit confirmé avant de
   capitaliser — un piège mal compris documenté à moitié est pire que rien.
2. **Chercher une entrée existante** dans `references/pieges.md` pour ce
   même symptôme ou cette même cause — éviter les doublons, enrichir
   l'entrée existante si elle couvre déjà le cas (ex. nouvelle version où
   le même piège réapparaît différemment).
3. **Rédiger l'entrée**, format cohérent avec les entrées existantes du
   fichier (généralement : titre court, Symptôme, Cause, Solution, contexte
   de version si pertinent).
4. **Récapituler** à l'utilisateur : entrée ajoutée, fichier concerné.

## Ce que ce skill ne doit jamais faire seul

- Documenter un piège encore non résolu ou dont la cause réelle n'est pas
  confirmée — spéculer n'aide pas la prochaine absorption.
- Dupliquer une entrée déjà présente — toujours chercher d'abord.
- Committer ou pousser — reste soumis au cycle de vie normal de la tâche
  (`/livre`), ce skill ne fait qu'écrire le fichier.
