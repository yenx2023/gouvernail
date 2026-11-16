# Doctrine technique — détail

Détail des principes techniques de ce projet, lu **à la demande** (pas en
début de session). `CLAUDE.md` en garde la règle courte, ceci en est le
développement complet — les deux font foi, sans contradiction.

## Principes de conception (SOLID + DRY)

Le code applicatif de ce projet suit les principes **SOLID** dès qu'une
modélisation orientée objet ou modulaire est en jeu :

- **S**ingle Responsibility — une classe/module a une seule raison de changer.
- **O**pen/Closed — étendre par composition/abstraction plutôt que modifier
  du code existant qui fonctionne.
- **L**iskov Substitution — une sous-classe doit pouvoir remplacer sa classe
  mère sans surprendre l'appelant.
- **I**nterface Segregation — plusieurs interfaces ciblées plutôt qu'une
  interface générale que personne n'utilise en entier.
- **D**ependency Inversion — dépendre d'abstractions, pas d'implémentations
  concrètes, pour les dépendances qui varient.
- **DRY** — éviter la duplication de logique, dans les mêmes limites que
  ci-dessous : factoriser dès qu'une duplication réelle apparaît, pas par
  anticipation.

Ça ne justifie pas l'abstraction prématurée : appliquer ces principes au
moment où la complexité le justifie réellement (deuxième implémentation,
point d'extension concret, duplication réellement constatée) — pas en
préparant hypothétiquement l'avenir. Trois lignes similaires valent mieux
qu'une abstraction anticipée.

## Tests

Toute fonctionnalité ou tout comportement modifié par une session autonome
(notamment Claude Code Cloud, sans supervision continue) est couvert par au
moins un test avant tout push — c'est le filet de sécurité qui permet à une
tâche prise en autonomie totale d'être fiable sans qu'un humain relise
chaque ligne avant la Merge Request. Pas d'objectif de couverture globale
arbitraire : du code existant non touché sans test n'est pas un blocage, un
comportement changé sans test l'est.

**Limite de vérification visuelle en session Cloud** — Claude Code Cloud
(sandbox web sans écran ni émulateur/simulateur, restrictions réseau qui
bloquent en général les tunnels de dev interactif type Expo/Metro) peut
écrire du code, exécuter des tests automatisés (unitaires/composants, sans
rendu réel) et ouvrir des Merge Requests, mais ne peut ni afficher un
rendu visuel ni piloter une session de développement interactive (hot
reload navigateur/appareil, émulateur Android, simulateur iOS). Pour tout
projet à surface visuelle significative (frontend web, application
mobile), documenter explicitement dans le `CLAUDE.md` du projet ce qui
reste vérifiable en session Cloud (tests automatisés) et ce qui nécessite
une session Claude Code locale ou une reprise manuelle par l'utilisateur
(rendu visuel, tests end-to-end pilotés par un simulateur/émulateur/
navigateur réel). Ne jamais prétendre à une vérification visuelle qui n'a
pas eu lieu — l'annoncer explicitement comme non faite plutôt que de
l'omettre.

**Preuve factuelle via Maestro (`/eprouve`)** — sur un projet à surface
visuelle/interactive réelle, un test unitaire/composant ne suffit pas à
couvrir la doctrine Tests ci-dessus pour un comportement qui se joue à
l'écran (navigation, formulaire, retour visuel) : seul un parcours
end-to-end rejoué sur l'application réelle (Maestro) en apporte la preuve
factuelle. Le skill `/eprouve` formalise cet usage : un parcours
utilisateur nouveau ou modifié doit avoir son flow Maestro correspondant
écrit **et exécuté avec succès** avant d'être considéré terminé — au même
titre qu'un test automatisé vert, pas seulement en réaction à un bug déjà
signalé. Cette exécution réelle ne peut avoir lieu qu'en session Claude
Code locale (voir paragraphe ci-dessus) : en session Cloud, `/eprouve`
écrit ou met à jour le flow mais le marque explicitement non exécuté, à
valider lors d'une reprise locale.

## Documentation vivante

Toute modification qui change un état déjà documenté — périmètre
fonctionnel (PRD), décisions/découpage d'architecture (PLAN), dépendance
cross-repo signalée dans un autre projet du même produit, instructions de
mise en route (README ou équivalent), surface d'API exposée (voir
Documentation API le cas échéant) — met à jour le document concerné dans la
même livraison, pas dans une tâche séparée "à faire plus tard". Même
logique que Tests (section ci-dessus) : un état changé sans que sa documentation
suive n'est pas considéré comme livré.

- **README (ou équivalent) tenu à jour** — point d'entrée de mise en route :
  reflète le setup réel (dépendances, commandes de démarrage, pointeurs
  vers PRD/PLAN/CLAUDE.md), pas un template générique laissé tel quel après
  le bootstrap initial.
- **Notes de dépendance cross-repo résolues** — quand un PRD/PLAN signale
  explicitement une dépendance non couverte par un autre dépôt du même
  produit (voir Produit multi-dépôts dans le CLAUDE.md de Gouvernail), et
  que cette dépendance devient couverte côté dépôt référencé, la note doit
  être mise à jour ou retirée dans la foulée — jamais laissée affirmer un
  état qui n'est plus vrai.
- **Un état, un endroit** — éviter de dupliquer une même information dans
  plusieurs documents (ex. une décision d'architecture décrite à la fois
  dans PLAN.md et CLAUDE.md) : référencer plutôt que recopier, pour n'avoir
  qu'un seul endroit à corriger en cas de changement.

## Stratégie de logging

Les logs suivent le même esprit que la Gestion des erreurs (`CLAUDE.md` > Gestion des erreurs) — fail
fast, pas de bruit :

- **Niveaux de log fidèles à la sévérité réelle** — `error`/`warning` pour ce
  qui casse ou dégrade un flux, `info` pour les événements métier
  significatifs, `debug` pour le détail d'investigation. Ne pas logger en
  `error` un comportement attendu (ex. validation utilisateur rejetée), ne
  pas masquer une vraie erreur en `debug`.
- **Catégorisation par canal/finalité** — séparer au minimum le technique
  (debug applicatif, erreurs d'exécution) de l'audit (traçabilité d'une
  action métier sensible : KYC, transaction, moyen de paiement) dès que
  l'écosystème propose un mécanisme natif de canaux/channels. Deux finalités
  différentes (diagnostic dev vs preuve de conformité), deux publics, donc
  potentiellement deux durées de rétention — pas un flux unique
  indifférencié.
- **Volumétrie maîtrisée** — la verbosité `debug` reste désactivée par
  défaut en production ; une rotation/rétention explicite (durée adaptée à
  la finalité du canal, cf. Catégorisation) évite une croissance illimitée
  du volume de logs. Un événement à haute fréquence (boucle, retry,
  polling) se sample ou s'agrège plutôt que de produire une entrée par
  occurrence.
- **Structuré plutôt que texte libre** dès que l'écosystème le permet
  nativement (champs clé/valeur, pas de concaténation de string) — condition
  pour qu'un log reste exploitable en recherche/alerting, pas juste lu à
  l'œil dans un fichier.
- **Jamais de secret, token, mot de passe ou donnée personnelle identifiante
  en clair dans un log** — règle absolue, pas une recommandation.
  Particulièrement sensible sur tout projet manipulant KYC, moyens de
  paiement ou identité. Masquer/tronquer plutôt que ne pas logger, quand le
  contexte reste utile sans la donnée sensible.
- **Un événement, un log** — logger au point où l'erreur est effectivement
  gérée (la frontière, cf. Gestion des erreurs), pas à chaque niveau de la
  pile d'appel qui la laisse remonter : un même incident ne doit pas
  produire N entrées redondantes.
- **Contexte exploitable, pas un identifiant de plus** — inclure ce qui
  permet de recouper un incident (identifiant de requête/corrélation,
  utilisateur ou entité concernée) en réutilisant une convention déjà
  existante dans le framework utilisé plutôt qu'en en inventant une.
- **Réutiliser le mécanisme de logging natif du framework/langage** avant
  d'introduire une dépendance dédiée (cohérent avec `CLAUDE.md` > Dépendances)
  — une lib de logging externe se justifie par un besoin réel (agrégation
  centralisée, format imposé par l'infra), pas par défaut.
