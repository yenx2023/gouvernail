---
name: eprouve
description: "Écrit et exécute des parcours end-to-end Maestro sur l'application réelle (émulateur, simulateur ou appareil connecté à une session Claude Code locale) pour valider un parcours utilisateur de façon factuelle — au fil du développement d'une fonctionnalité à impact visuel/interactif, pas seulement en diagnostic a posteriori d'un bug déjà signalé. Usage : /eprouve <parcours ou story à valider> [--flow <chemin>] [--suite]. L'exécution réelle (jouer le flow) nécessite Maestro CLI et un device/émulateur connecté en session locale — voir CLAUDE.md > Vérification visuelle ; en session Cloud, le flow est seulement écrit/mis à jour, jamais exécuté. Utilise sur /eprouve, \"éprouve l'application\", \"teste ce parcours\", \"vérifie ce flow\", \"lance les tests Maestro\", \"fais rejouer le parcours\", ou dès qu'une fonctionnalité à impact visuel/interactif doit être validée avant d'être considérée terminée."
---

# eprouve

## Objectif

Faire jouer réellement un parcours utilisateur sur l'application (Maestro,
E2E déclaratif en YAML) pour en obtenir une preuve factuelle de bon
fonctionnement — au même titre qu'un test Jest/PHPUnit vert, pas comme un
outil de diagnostic réservé à l'après-coup d'un bug déjà signalé. Trois
usages distincts, tous couverts par ce même skill :

1. **Validation continue** (usage principal) — pendant le développement
   d'une fonctionnalité à impact visuel/interactif, écrire ou étendre le
   flow Maestro du parcours concerné et l'exécuter jusqu'à ce qu'il passe,
   avant de considérer la story terminée. C'est l'extension E2E de la
   doctrine Tests (voir `CLAUDE.md` > Tests) : un comportement qui se joue
   à l'écran n'est vraiment validé que rejoué sur l'application réelle, pas
   seulement déduit d'un test unitaire qui mocke le rendu.
2. **Diagnostic** — sur un bug rapporté à composante visuelle/interactive,
   écrire ou rejouer un flow ciblé pour reproduire factuellement le
   symptôme avant d'investiguer (voir le skill `/investigue` pour la
   suite : hypothèses sur la cause racine, fix minimal).
3. **Régression** (`--suite`) — rejouer l'ensemble des flows existants,
   comme le ferait une équipe de testeurs qui repasserait sur toute
   l'application avant une livraison ou après un changement à risque
   (refactor transverse, montée de version d'une dépendance UI...).

## Qui écrit les flows

Par défaut, **ce skill** — pas l'utilisateur. Un flow Maestro s'écrit en
même temps que le code de l'écran/la feature qu'il valide, exactement
comme un test Jest s'écrit avec le composant qu'il couvre : ce n'est
jamais une tâche séparée "à faire plus tard". L'utilisateur peut bien sûr
écrire ou corriger un flow lui-même (parcours métier particulièrement
sensible, connaissance fine d'un cas limite), mais ce n'est jamais un
prérequis à l'usage de ce skill.

Un flow **écrit mais jamais exécuté n'a aucune valeur de preuve** — au
même titre qu'un test qui ne tourne jamais (voir Étape 1 : détection de
l'environnement).

## Convention des flows

- Emplacement : `maestro/flows/<slug-parcours>.yaml` — un flow par
  parcours utilisateur ou user story, jamais un flow monolithique qui
  couvre toute l'app, jamais un flow par écran isolé sans scénario.
- Chaque flow commence par un commentaire de traçabilité :
  `# Parcours : <description courte> (issue GitLab #<numero> si connue)`.
- Config partagée (`appId`, etc.) dans `maestro/config.yaml` si
  l'outillage Maestro du projet en a besoin — jamais dupliquée dans
  chaque flow.
- Sélecteurs stables : s'appuyer sur les `testID`/labels d'accessibilité
  déjà posés sur les composants plutôt que sur du texte affiché ou une
  position à l'écran — un flow qui casse à chaque changement de copy
  n'apporte rien.
- Les flows sont **versionnés et committés** comme n'importe quel test —
  jamais un artefact jetable généré puis supprimé après usage.

## Prérequis

- **Maestro CLI installé** dans l'environnement d'exécution
  (`maestro --version`). S'il est absent en session locale, s'arrêter et
  demander à l'utilisateur de l'installer plutôt que d'improviser une
  alternative.
- **Un device/émulateur/simulateur réellement disponible** pour toute
  exécution : émulateur Android démarré (`adb devices` liste un appareil
  à l'état `device`), simulateur iOS démarré (`xcrun simctl list devices
  | grep Booted`), ou appareil physique connecté avec débogage activé. Ne
  jamais supposer qu'un device est prêt sans l'avoir vérifié.
- **Détection de l'environnement d'exécution** avant toute chose (voir
  Étape 1) : ce skill se comporte différemment en session Cloud (écriture
  seule) et en session locale (écriture + exécution réelle) — voir la
  section dédiée du `CLAUDE.md` du projet (ex. "Vérification visuelle —
  limite de l'environnement Cloud").

## Étapes

1. **Détecter le contexte d'exécution.** Tenter `maestro --version` puis
   une détection de device (`adb devices` / `xcrun simctl list devices`).
   Deux cas :
   - **Aucun Maestro CLI et/ou aucun device détecté** (typiquement une
     session Claude Code Cloud, sandbox sans écran ni émulateur) :
     continuer uniquement jusqu'à l'Étape 3 (écriture du flow), puis
     s'arrêter — ne jamais tenter `maestro test`, ne jamais prétendre
     qu'un parcours a été vérifié. Le rapporter explicitement dans le
     récapitulatif (Étape 6) : "flow écrit, non exécuté — nécessite une
     session locale".
   - **Maestro CLI et device disponibles** (session locale) : procéder
     jusqu'à l'exécution réelle (Étape 4).

2. **Localiser ou créer le flow correspondant** au parcours demandé
   (argument de `/eprouve`, ou déduit de la fonctionnalité en cours de
   développement). Chercher dans `maestro/flows/` un flow existant qui
   couvre déjà ce parcours avant d'en créer un nouveau — étendre plutôt
   que dupliquer si le parcours existant se prolonge (ex. un flow
   "inscription" qu'on étend avec une étape ajoutée).

3. **Écrire ou mettre à jour le flow** en YAML Maestro, en suivant la
   Convention des flows ci-dessus. À cette étape, le flow reflète le
   comportement attendu de l'écran/la feature — pas encore vérifié.

4. **Exécuter réellement** (session locale uniquement) :
   ```
   maestro test maestro/flows/<flow>.yaml
   ```
   Ou, en mode régression (`--suite`) :
   ```
   maestro test maestro/flows/
   ```
   Capturer la sortie complète (pas/fail par étape, captures d'écran en
   cas d'échec si Maestro les produit).

5. **En cas d'échec** : ne jamais corriger à l'aveugle. Utiliser la sortie
   Maestro (étape qui échoue, capture d'écran, message) comme symptôme
   factuel. Si la cause est évidente et locale au flow (sélecteur obsolète
   après un renommage, timing d'attente insuffisant), corriger directement
   et relancer le même flow jusqu'au vert. Si la cause n'est pas évidente
   ou touche la logique applicative (pas juste le flow lui-même), basculer
   sur le skill `/investigue` pour la discipline hypothèses/cause
   racine/fix minimal plutôt que d'itérer au hasard dans ce skill.

6. **Récapituler** : parcours/flow concerné, résultat (vert/rouge/non
   exécuté et pourquoi), chemin du fichier flow. C'est cette preuve
   factuelle — pas une déduction — qui compte comme "test" au sens de la
   doctrine Tests pour tout comportement visuel/interactif modifié.

## Ce que ce skill ne doit jamais faire seul

- Déclarer un parcours vérifié visuellement sans l'avoir réellement fait
  rejouer par Maestro en session locale — jamais de faux positif "ça
  devrait fonctionner".
- Considérer une fonctionnalité à impact visuel terminée avec un flow
  rouge, ou sans flow du tout si le parcours est nouveau — même exigence
  que pour un test Jest/PHPUnit rouge ou absent (voir `CLAUDE.md` >
  Tests).
- Supprimer, commenter ou désactiver un flow existant pour faire
  disparaître un échec plutôt que d'en traiter la cause.
- Exécuter un flow contre un environnement de production ou avec des
  identifiants/données réelles d'un utilisateur — toujours un build de
  développement/test avec des comptes dédiés.
- Committer une capture d'écran ou un artefact de run contenant une
  donnée personnelle réelle.
