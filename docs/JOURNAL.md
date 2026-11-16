# Journal

Journal chronologique des tâches livrées (une entrée par clôture réelle —
voir CLAUDE.md > Mémoire de session).

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

## 2026-11-16 — Issue #24 — `chore/24-alias-modele-sans-skip-permissions`

Documente dans le README (section « Choisir le modèle selon la tâche ») trois
alias shell `ccs`/`cco`/`cch` (`claude --model sonnet|opus|haiku`) **sans**
`--dangerously-skip-permissions`. Signale que l'installateur du dépôt tiers
`videvjs/claude-aliases` ajoute ce flag, incompatible avec la doctrine de
gates humains : outil externe non vendorisé, jamais installé par
`/amorce-projet`. Les alias ne fixent le modèle qu'au lancement ; le routage
par tâche reste assuré par les skills et subagents. Documentation seule, aucun
test ajouté. Livré via Merge Request GitLab, mergée dans `main`.

## 2026-11-16 — Issue #25 — `chore/25-procedure-portage-depot-existant`

Ajoute dans `CLAUDE.md` (« Adopter Gouvernail sur un dépôt existant ») une
checklist de portage d'une évolution du framework vers un dépôt déjà outillé :
mesurer avant, comparer avant de copier, reporter `CLAUDE.md` section par
section sans écraser le propre au projet (zéro perte vers `docs/DOCTRINE.md`),
appliquer les règles aux données du projet (`CONTEXT`, `JOURNAL`, `DESIGN`),
tests, mesurer après. Une issue et une MR par dépôt. Documentation seule, aucun
test ajouté. Dernière issue du milestone « Optimisation de la consommation de
tokens » ; le portage effectif dans `taga-mobile-app` et `taga-backend` reste à
faire, dans leurs propres backlogs. Livré via Merge Request GitLab, mergée dans
`main`.

## 2026-11-16 — Issue #26 — `feature/26-marqueur-version-gouvernail`

Un projet amorcé étant une copie de l'outillage, rien ne le reliait à
Gouvernail. Ajoute `scripts/aligne-gouvernail.sh marqueur lire|ecrire` :
`.claude/gouvernail-version` retient le commit de Gouvernail dont l'outillage a
été copié ; la source se résout par `GOUVERNAIL_SOURCE` (défaut
`../gouvernail`) avec repli sur un clone de `GOUVERNAIL_REPO_URL`.
`/amorce-projet` copie le script et écrit le marqueur. Livré via Merge Request
GitLab, mergée dans `main`.

## 2026-11-16 — Issue #27 — `feature/27-aligne-audit`

Ajoute `aligne-gouvernail.sh audit`, rapport en lecture seule : outillage
manquant ou périmé (une copie modifiée localement n'est jamais comptée comme
périmée), `CONTEXT.md` > ≈ 6 Ko, journal > 15 entrées, `DESIGN.md`
monolithique, règle de lecture absente, marqueur absent ou en retard.
`audit --court` : une ligne ou rien, jamais de réseau. Testé sur
`taga-mobile-app` en lecture seule (6 points relevés). Livré via Merge Request
GitLab, mergée dans `main`.

## 2026-11-16 — Issue #28 — `feature/28-aligne-outillage-donnees`

Ajoute `outillage` (copie le manquant, met à jour la copie restée identique à
l'origine, n'écrase jamais une copie modifiée localement ou sans base de
comparaison — diff affiché) et `donnees` (archive le journal), tous deux avec
`--simule`, sans jamais committer. Livré via Merge Request GitLab, mergée dans
`main`.

## 2026-11-16 — Issue #29 — `feature/29-hook-session-start-audit`

Ajoute `.claude/settings.json` : hook `SessionStart` (démarrage seulement) qui
lance `audit --court` — une ligne ou rien, jamais bloquant. L'audit signale son
absence ; `outillage` le copie ou affiche le hook à ajouter à la main si le
projet a déjà ses réglages. Défaut corrigé en cours de route : Gouvernail,
source du framework, se signalait « marqueur absent ». Livré via Merge Request
GitLab, mergée dans `main`.

## 2026-11-16 — Issue #30 — `feature/30-skill-aligne`

Ajoute le skill `/aligne` : alignement d'un projet en 5 phases validées (audit
et mesure de départ, outillage, fusion de `CLAUDE.md` sans écraser le
spécifique du projet, données, vérification avant/après). Ne committe jamais :
livraison par `/livre`. Non testé de bout en bout (dialogue) ; frontmatter
validé par `tests/modeles.test.sh`. Livré via Merge Request GitLab, mergée dans
`main`.

## 2026-11-16 — Issue #31 — `chore/31-documenter-auto-alignement`

Documente le mécanisme dans `CLAUDE.md` (section dédiée, garde-fous : analyse
automatique, application toujours validée), les gabarits (une puce sur
`/aligne`) et le README ; la checklist de portage de #25 renvoie à `/aligne`.
Clôt le milestone « Auto-alignement des projets sur Gouvernail » ; l'alignement
effectif de `taga-mobile-app` et `taga-backend` reste à faire avec `/aligne`,
dans leurs backlogs. Les entrées #26 à #31 sont regroupées ici pour éviter des
conflits entre branches empilées. Livré via Merge Request GitLab, mergée dans
`main`.
