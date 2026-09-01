## Stratégie Git — régime distribué

Ce composant est distribué en versions (stores d'applications, package
manager, exécutable téléchargeable...), pas déployé en continu sur une
infrastructure qu'on contrôle. Pas d'environnement à gérer, pas de bascule
Blue/Green — chaque version est un artefact figé, testée avant publication,
publiée par lots.

```
main (trunk)             ← branches de tâche mergées via MR au fil de l'eau
  ↑ merge (par tâche)
<type>/<issue>-<slug>     ← branches de tâche courtes (voir Convention de nommage des branches)
```

- **Pas de branche `staging`** : chaque MR mergée dans `main` est
  potentiellement livrable, mais ce n'est un `main` figé et tagué qui
  déclenche une publication — pas chaque merge.
- **Versionner par tag**, pas par merge : `main` avance en continu, mais
  seul un tag de release engage une publication (build, soumission store,
  publication package). Convention : `vX.Y.Z` (semver) ou la convention de
  version native de l'écosystème (ex. `pubspec.yaml` pour Flutter :
  `X.Y.Z+buildNumber`, `buildNumber` jamais décroissant).
- **Le sas de test avant publication n'est pas une branche longue** : c'est
  un canal de distribution interne au store/écosystème (TestFlight, Google
  Play Internal/Closed Testing, canal `beta` npm...), alimenté depuis un
  tag ou une branche de release éphémère — jamais depuis une branche
  d'intégration permanente qui diverge silencieusement de `main`.
