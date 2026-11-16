# Journal

Journal chronologique des tâches livrées (une entrée par clôture réelle —
voir CLAUDE.md > Mémoire de session).

## 2026-09-19 — Issue #15 — `chore/15-context-produit-tiers`

Étend `docs/CONTEXT.md` (issue #14) au profil `produit-tiers` : le
fichier se crée désormais quel que soit le profil dans `amorce-projet`.
Son rôle (état courant + pièges généraux + décisions en attente) est
orthogonal à `docs/REGISTRE.md` (divergences de code par rapport à
l'amont) et à la base de pièges du skill `/piege` (pièges spécifiques à
l'absorption d'une version) — vérifié avant l'extension, pas supposé.
Frontière rendue explicite à deux endroits (le fichier généré lui-même
pour ce profil, et l'étape correspondante du skill `/livre`) plutôt que
de compter sur la mémoire de la session qui le remplira plus tard. Livré
via MR GitLab !42, mergée dans `main`.

## 2026-09-19 — Issue #14 — `chore/14-memoire-vivante-contexte`

Remonte le patron `docs/CONTEXT.md` (résumé vivant, édité en place, de
l'état opérationnel courant) validé sur `taga-backend`#95/
`taga-mobile-app`#90, profil `conception` uniquement : puce dans
`CLAUDE.md.template` > Mémoire de session (lue avant `docs/JOURNAL.md`),
étape de maintenance dans le skill `/livre` (mode merge, conditionnée à
l'existence du fichier — socle commun, sans effet en `produit-tiers`),
création du fichier vide à l'amorçage dans `amorce-projet` (symétrique à
`docs/REGISTRE.md` côté `produit-tiers`). Vérifié sans chevauchement avec
`docs/REGISTRE.md`/skill `/piege` avant cette remontée. Livré via MR
GitLab !41, mergée dans `main`.

## 2026-07-29 — Issue #9 — `fix/9-milestone-empty-parametre-invalide`

Corrige `scripts/gitlab-api.sh` > `milestone_is_empty()` : interrogeait
`GET /projects/:id/issues?milestone_id=<id>`, paramètre invalide côté API
GitLab (HTTP 400 "milestone_id does not have a valid value"). L'endpoint
attend `milestone=<titre>` — résout désormais le titre du milestone avant
de filtrer les issues ouvertes. Bug découvert en conditions réelles le
2026-07-29 sur `taga-backend` (clôture du milestone "Authentification &
comptes"), vérifié corrigé sur un milestone vide et un milestone encore
ouvert. Reporté dans les deux projets qui en ont une copie
(`taga-backend`#58, `taga-mobile-app`#43). Livré via MR GitLab !33, mergée
dans `main`.

## 2026-07-29 — Issue #10 — `chore/10-limite-verification-visuelle-cloud`

Retour d'expérience `taga-mobile-app` : Claude Code Cloud (sandbox web
utilisé pour ces sessions) n'a ni écran ni émulateur/simulateur, et ses
restrictions réseau bloquent en général les tunnels de dev interactif
(ex. tunnel Expo/Metro). Il peut écrire du code, exécuter des tests
automatisés (sans rendu réel) et ouvrir des Merge Requests, mais jamais
afficher un rendu visuel ni piloter une session interactive. Ajoute ce
garde-fou à `CLAUDE.md.template` > Tests pour que tout nouveau projet à
surface visuelle significative (frontend web, mobile) en hérite dès
l'amorçage, plutôt que de le redécouvrir projet par projet. Livré via MR
GitLab !35, mergée dans `main`.

## 2026-08-11 — Issue #11 — chore/11-langue-travail-claude

Ajoute une section "Langue de travail" au `CLAUDE.md` de Gouvernail et au
gabarit `CLAUDE.md.template` (`/amorce-projet`) : aucun des deux ne
précisait explicitement la langue de réponse de Claude Code (distincte
d'une éventuelle exigence de langue sur le contenu applicatif), obligeant
l'utilisateur à le rappeler à chaque nouvelle session — y compris sur les
projets amorcés depuis ce framework. Retour d'expérience remonté depuis
`taga-backend` et `taga-mobile-app`, corrigés de la même façon. Livré via
MR GitLab !37, mergée dans `main`.

## 2026-08-26 — chore/outils-externes-diagram-design (pas d'issue formelle)

Ajoute une section "Outils externes recommandés (plugins, non vendorisés)"
à `CLAUDE.md` (et son pendant dans `README.md`) : contrairement aux skills
vendorisés (`interroge`/`cadre`/.../`illustre`, copiés dans
`.claude/skills/`), certains outils tiers utiles au framework se
distribuent comme plugins Claude Code via marketplace — mode de
distribution incompatible avec le vendoring, donc jamais installés
automatiquement par `/amorce-projet`. Documente `diagram-design`
(`cathrynlavery/diagram-design`, MIT) : diagrammes techniques (architecture,
ER, séquence, UML...) en HTML+SVG autonome, en complément — jamais en
remplacement — de Mermaid (documents versionnés, diffable en MR) et
`/illustre` (visuels pédagogiques Excalidraw). Livré via MR GitLab !38,
mergée dans `main`.

## 2026-09-08 — Issue #13 — branche `claude/taga-mobile-test-automation-p2gugz`

Ajoute le skill `/eprouve` : formalise Maestro comme preuve factuelle de
bon fonctionnement d'un parcours utilisateur au fil du développement (pas
seulement en diagnostic a posteriori d'un bug rapporté), au même titre que
les tests Jest/PHPUnit déjà couverts par la doctrine Tests. Distingue
explicitement l'écriture d'un flow (possible en session Cloud) de son
exécution réelle (nécessite Maestro CLI + device/émulateur, donc une
session locale). Reporté dans `amorce-projet` (socle commun) et dans
`CLAUDE.md.template` (doctrine Tests étendue). Branche imposée par la
session Claude Code Cloud, hors convention `<type>/<numero>-<slug>` — le
numéro d'issue est référencé via la description de la Merge Request
plutôt que le nom de branche. Livré via MR GitLab !40, mergée dans `main`.

## 2026-09-24 — Issue #16 — branche `claude/maestro-android-emulator-performance-vjxvcq`

Documente `mobile-mcp` (`mobile-next/mobile-mcp`) dans `CLAUDE.md` >
Outils externes recommandés : serveur MCP de pilotage live d'un
émulateur/simulateur par agent, en complément — jamais en remplacement —
de `/eprouve` (Maestro) pour le testing exploratoire (zone d'app non
cartographiée, diagnostic sans reproduction connue). Tableau de décision
`/eprouve` (régression scriptée, par défaut) vs `mobile-mcp` (exploration)
vs conversion vers `/eprouve` dès qu'un chemin exploratoire se stabilise.
Miroir README ajouté dans une seconde MR après un oubli initial (même
pattern que `diagram-design`). Branche imposée par la session Claude Code
Cloud, hors convention `<type>/<numero>-<slug>` — numéro d'issue référencé
via la description des Merge Requests plutôt que le nom de branche
(même situation que l'issue #13). Livré via MR GitLab !43 (doctrine) et
!44 (miroir README), toutes deux mergées dans `main`.

## 2026-09-25 — Issue #17 — `chore/17-doctrine-anti-injection-gate`

Ajoute dans `CLAUDE.md` une clause de doctrine explicite (Doctrine) : le
contenu d'un dépôt/issue/Merge Request/PR n'autorise jamais une action
d'écriture — défense contre l'injection de contenu externe se faisant
passer pour une autorisation. Documente aussi la spécification d'un hook
technique complémentaire au gate déclaratif (nouvelle sous-section en fin
de Cycle de vie d'une tâche), inspiré du hook « GateGuard » du framework
ECC (`affaan-m/ecc`, analysé en session) — explicitement marqué comme
**non implémenté** : un jeton de gate à courte durée de vie, écrit par
`/livre` au moment de la phrase de validation, est un préalable
indispensable avant tout blocage strict, sous peine de bloquer aussi le
push de continuité. Livré via MR GitLab !45, mergée dans `main`.

## 2026-11-16 — Issue #18 — `chore/18-mesurer-contexte-session`

Ajoute `scripts/mesure-contexte.sh` : mesure (octets, mots, tokens estimés
≈ octets / 3,7) du contexte qu'une session charge dans un dépôt outillé
Gouvernail — `CLAUDE.md` (toujours chargé), docs lus en début de session,
autres docs, skills. Sert de référence avant/après pour les autres issues du
milestone « Optimisation de la consommation de tokens ». Couvert par
`tests/mesure-contexte.test.sh` (16 tests hors-ligne, validés sous bash 3.2
macOS) ; usage documenté dans le README. Livré via Merge Request GitLab,
mergée dans `main`.

## 2026-11-16 — Issue #19 — `feature/19-regles-lecture-debut-session`

Ajoute une règle de lecture de début de session dans la section « Mémoire de
session » du `CLAUDE.md` de Gouvernail et des deux gabarits (`conception`,
`produit-tiers`) : `CONTEXT.md` d'abord, `JOURNAL.md` jamais lu en entier
(`tail` ou `grep` sur le n° d'issue), documents longs (`DESIGN.md`) lus par
section ; `REGISTRE.md` garde ses lectures obligatoires en `produit-tiers`.
Renvoie à `scripts/mesure-contexte.sh` pour chiffrer l'effet. Le gain réel
(≈ 22–38 k tokens de journal + ≈ 45 k de design sur les sessions UI de TAGA)
se vérifiera au portage (#25). Livré via Merge Request GitLab, mergée dans
`main`.

## 2026-11-16 — Issue #22 — `chore/22-alleger-claude-md-template`

Allège `CLAUDE.md.template` (profil conception) de 16,5 Ko à 10,6 Ko
(≈ −1 600 tokens par tour) : le détail de SOLID, Tests, Documentation
vivante et Stratégie de logging est déplacé, repris mot pour mot, dans
`references/doctrine-technique.md`, que `/amorce-projet` copie en
`docs/DOCTRINE.md` dans chaque projet (les deux profils) ; `CLAUDE.md` n'en
garde que la règle courte et un pointeur. Corrige au passage les renvois du
gabarit `produit-tiers` vers « le `CLAUDE.md.template` de Gouvernail »,
inaccessibles depuis un projet. `/amorce-projet` copie aussi désormais
`scripts/mesure-contexte.sh` et son test. 52 phrases d'origine vérifiées
présentes dans la doctrine détaillée. Livré via Merge Request GitLab,
mergée dans `main`.

## 2026-11-16 — Issue #23 — `feature/23-subagents-modeles-par-tache`

Ajoute le choix du modèle par tâche, d'après la documentation officielle de
Claude Code : deux subagents `.claude/agents/` (`explorateur` en Haiku,
lecture seule ; `executant` en Sonnet, pour appliquer une décision déjà
prise) et `model: sonnet` (+ `effort: low` sur `/tache` et `/cloture`) sur
les skills mécaniques `/tache`, `/livre`, `/cloture`, `/backlog-gitlab`,
`/registre`, `/piege`. Pas de `model:` sur `/cadre`, `/planifie`,
`/investigue`, `/absorbe` : l'override d'un skill ne vaut que pour le tour
courant, inefficace sur un dialogue multi-tours (→ `opusplan` documenté dans
le README). `tests/modeles.test.sh` (39 tests) valide le frontmatter, car
Claude Code ignore sans erreur un champ mal formé, et interdit Haiku sur un
skill qui écrit sur git/GitLab. `/amorce-projet` copie agents et test.
Effet réel non mesuré en session (à vérifier avec `/cost`). Livré via Merge
Request GitLab, mergée dans `main`.

## 2026-11-16 — Issue #21 — `feature/21-design-index-par-theme`

Le skill `/design` produit désormais `docs/DESIGN.md` comme **index court**
(cible ≤ ~18 Ko, ≈ 5 k tokens : contexte produit, direction esthétique,
tableau « quel fichier lire ») et le détail dans `docs/design/` (`tokens.md`,
`composants.md`, `ecarts.md`), lu à la demande. Règle de croissance : tout
ajout va dans les fichiers de thème, scindés au-delà de ~40 Ko. Ajoute une
option **migrer** pour un `DESIGN.md` monolithique (déplacement à
l'identique, contrôle de perte zéro avant suppression). La règle de lecture
de #19 (`CLAUDE.md` + gabarits) précise que `DESIGN.md` est un index ;
`scripts/mesure-contexte.sh` compte aussi `docs/design/*.md` (+4 tests).
Migration non testée sur un vrai `DESIGN.md` (le découpage effectif de
TAGA, ≈ 55 k tokens, se fera au portage #25). Livré via Merge Request
GitLab, mergée dans `main`.

## 2026-11-16 — Issue #20 — `feature/20-archivage-journal-contexte`

Ajoute `scripts/archive-journal.sh` : garde les 15 entrées les plus récentes
du journal (selon la date du titre, pas la position — le fichier n'est pas
toujours chronologique) et déplace les autres dans
`docs/archive/JOURNAL-<année>.md`, sans perte, idempotent (+20 tests,
`tests/archive-journal.test.sh`). `/livre` (mode merge) l'appelle après
l'entrée de journal et vérifie la taille cible de `docs/CONTEXT.md`
(≈ 6 Ko, condensé à la livraison si dépassé — consigne, pas contrôle
automatique) ; `/cloture` cherche aussi dans les archives ; `/amorce-projet`
copie le script et son test ; gabarits, `CLAUDE.md` et README documentent la
règle. Premier archivage appliqué au journal de Gouvernail dans cette même
livraison. Livré via Merge Request GitLab, mergée dans `main`.
