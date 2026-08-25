## Stratégie Git — régime déployé

Ce composant tourne en continu sur une infrastructure contrôlée (VPS,
cloud...) — la disponibilité pendant et après chaque changement est
primordiale. La gestion des environnements et la stratégie de déploiement
ne sont pas optionnelles.

```
main (production)       ← ce qui tourne réellement, déployé après validation
  ↑ merge (via MR)
staging                 ← intégration, tests, validation avant mise en prod
  ↑ merge (par tâche)
<type>/<issue>-<slug>    ← branches de tâche courtes (voir Convention de nommage des branches)
```

- **`staging` est un sas d'intégration permanent**, pas une branche de
  tâche : les branches de tâche s'y mergent au fil de l'eau, `staging` se
  teste comme un tout avant tout merge vers `main`.
- **`main` ne reçoit que du code déjà validé sur `staging`** — jamais de
  merge direct d'une branche de tâche vers `main`.
- **Stratégie de déploiement** (adapter selon l'infra réelle du projet —
  Blue/Green, rolling, canary...) : documentée explicitement dans le
  `CLAUDE.md` du projet, avec la procédure de rollback. Ne jamais déployer
  directement depuis une branche de tâche ou `staging` — toujours depuis
  `main`, après merge.
- **Tag de release sur `main`, après le merge, avant le déploiement** —
  permet de revenir à un état exact (`git checkout <tag>`) sans dépendre
  d'un backup séparé.
