# Cyber Resilience Act — règlement (UE) 2024/2847 — correspondance OASIS

**Rédigé le 2026-10-07.** Texte de référence : règlement (UE) 2024/2847, JO du 20.11.2024,
lu **intégralement en FR et en EN** et cité depuis le fichier téléchargé, non résumé
([FR](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=OJ:L_202402847),
[EN](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202402847)).

> **Ce document ne revendique aucune fonction de sûreté.** Voir
> [`IEC_TS_63074.md`](IEC_TS_63074.md).

---

## 1. Dates — vérifiées à la source

| Disposition | Application | Statut au 2026-10-07 |
|---|---|---|
| Entrée en vigueur | 10/12/2024 | en vigueur |
| **Chapitre IV (art. 35 à 51)** — organismes d'évaluation | **11/06/2026** | **applicable** |
| **Article 14 — signalement** | **11/09/2026** | **applicable depuis 26 jours** |
| Annexe I, art. 13, marquage CE, art. 24 (intendants), reste du règlement | **11/12/2027** | pas encore |

Au 2026-10-07, **seuls l'article 14 et le chapitre IV sont en vigueur.** L'annexe I, l'article 13
et l'article 24 ne le sont pas encore. `POSITIONING_GAPS.md` A2 est donc exact sur les deux dates.

Deux réserves relevées à la lecture, à manier avec prudence dans un dossier :

- **Divergence linguistique au JO sur l'article 69 §3** : la version FR dit « mis sur le marché
  **le** 11 décembre 2027 », la version EN dit « placed on the market **before** 11 December
  2027 ». Seule la lecture EN donne un sens à la dérogation du §2 et correspond à la pratique
  administrative. ⚠️ À faire trancher par un juriste avant tout usage opposable.
- **L'article 15 (signalement volontaire) n'apparaît pas** parmi les dispositions anticipées de
  l'article 71 §2 : il ne serait donc applicable qu'au 11/12/2027, contrairement à l'article 14.
  ⚠️ **Non vérifié à la source.**

---

## 2. OASIS est-il dans le champ ? La réponse dépend d'une seule chose : la monétisation

Trois textes à enchaîner.

> **Article 3, point 1** — « “produit comportant des éléments numériques”: un produit logiciel ou
> matériel et ses solutions de traitement de données à distance, y compris **les composants
> logiciels ou matériels mis sur le marché séparément**; »

Donc **une bibliothèque est bien un « produit comportant des éléments numériques »**. Mais :

> **Considérant 18** — « […] **seuls les logiciels libres et ouverts mis à disposition sur le
> marché, donc fournis pour être distribués ou utilisés dans le cadre d'une activité commerciale,
> devraient relever du champ d'application du présent règlement.** […] la fourniture de produits
> comportant des éléments numériques qui répondent aux critères de logiciels libres et ouverts
> **qui ne sont pas monétisés par leur fabricant** ne devrait pas être considérée comme une
> activité commerciale. En outre, la fourniture de produits […] destinés à être intégrés par
> d'autres fabricants à leurs propres produits […] ne devrait être considérée comme une mise à
> disposition sur le marché **que si le composant est monétisé par son fabricant d'origine**. »

> **Considérant 20** — « Le seul fait d'héberger des produits comportant des éléments numériques
> sur des dépôts ouverts […] ne constitue pas en soi la mise à disposition sur le marché […]. »

**Conclusion pour OASIS aujourd'hui — licence libre (AGPL-3.0-or-later depuis le 11 octobre 2026), une personne, aucune monétisation :
hors du champ.** Publier sur un dépôt ouvert n'est pas une mise sur le marché.

**Le statut d'« intendant de logiciels ouverts » est juridiquement fermé**, et c'est une
correction de `POSITIONING_GAPS.md` D4, qui supposait qu'OASIS y serait soumis :

> **Article 3, point 14** — « une **personne morale**, autre que le fabricant, qui a pour objectif
> ou finalité de fournir un soutien systématique et continu au développement de produits
> spécifiques comportant des éléments numériques […] destinés à des activités commerciales […]. »

Une **personne physique ne peut pas être intendant**. Le considérant 19 confirme la cible
(fondations, entités publiant du logiciel libre dans un cadre commercial) et précise que les
intendants « ne devraient pas être autorisés à apposer le marquage CE ». L'article 64 §10 b) les
exonère d'amendes administratives. Terminologie officielle FR : « **intendant de logiciels
ouverts** », pas « steward ».

### Le basculement à anticiper

| Scénario | Statut CRA | Obligations |
|---|---|---|
| Aujourd’hui : AGPL-3.0-or-later, non monétisé, dépôt public | **hors champ** (cons. 18 et 20) | aucune |
| Support payant, licence commerciale, module vendu | **fabricant** (art. 3, point 13 : « à titre onéreux, monétisé ou gratuit ») d'un produit comportant des éléments numériques | **annexe I entière**, art. 13, art. 14, marquage CE, documentation annexe VII, à partir du 11/12/2027 |
| Constitution d'une personne morale qui soutient le développement d'un OASIS intégré à des produits monétisés par d'autres | **intendant** (art. 3, point 14) | régime allégé : art. 24 + art. 14 §1, §3, §8 ; pas de marquage CE ; pas d'amendes |

**La première ligne du modèle économique déclenche le régime complet.** C'est à savoir avant de
facturer le premier euro, pas après.

### Mais les intégrateurs vont demander la preuve dès maintenant

Même hors champ, OASIS subit la pression du texte par ses clients :

> **Article 13 §5** — « […] les fabricants font preuve de **diligence raisonnable** lorsqu'ils
> intègrent dans des produits comportant des éléments numériques des composants obtenus auprès de
> tiers, de sorte que ces composants ne compromettent pas la cybersécurité du produit […],
> **y compris lors de l'intégration de composants de logiciels libres et ouverts qui n'ont pas
> été mis à disposition sur le marché dans le cadre d'une activité commerciale**. »

> **Article 13 §6** — « Lorsqu'ils identifient une vulnérabilité dans un composant […] les
> fabricants signalent la vulnérabilité à la personne ou à l'entité qui assure la maintenance du
> composant […] ils partagent le code ou la documentation correspondants […]. »

Et si OASIS devient monétisé, l'**annexe II, point 8 f)** impose de fournir « les informations
nécessaires pour que l'intégrateur se conforme aux exigences essentielles […] de l'annexe I et
aux exigences en matière de documentation […] de l'annexe VII ».

**Lecture stratégique : le CRA crée la demande pour exactement ce que ce dépôt produit déjà** —
SBOM, campagnes de tests reproductibles, politique de divulgation, preuves horodatées. Un
intégrateur soumis à l'article 13 §5 a besoin d'un dossier sur chaque composant tiers ; OASIS
peut le lui livrer tout en restant hors champ.

---

## 3. Article 14 — signalement, applicable depuis le 11 septembre 2026

> **Article 14 §1** — « Un fabricant notifie toute vulnérabilité activement exploitée […]
> **simultanément au CSIRT désigné comme coordinateur** […] **et à l'ENISA**. Le fabricant notifie
> cette vulnérabilité […] par l'intermédiaire de la **plateforme unique de signalement** établie
> en vertu de l'article 16. »

Deux canaux, trois échéances chacun :

| Canal | Alerte précoce | Notification | Rapport final |
|---|---|---|---|
| **Vulnérabilité activement exploitée** (art. 14 §2) | **24 h** | **72 h** | **14 jours après la mise à disposition d'un correctif** |
| **Incident grave** ayant des répercussions sur la sécurité (art. 14 §4) | **24 h** | **72 h** | **1 mois après la notification à 72 h** |

L'**article 14 §8** ajoute une obligation **autonome** d'informer les utilisateurs du produit, sans
délai chiffré. L'**article 64 §10 a)** exonère les micro et petites entreprises d'amende sur le
seul manquement au délai de 24 heures — pas sur le reste.

**Applicabilité à OASIS :** aucune, aujourd'hui, puisque l'article 14 pèse sur les *fabricants* et
que l'intendance est exclue (personne physique). Mais `SECURITY.md` s'aligne déjà sur ces délais,
ce qui est le bon réflexe : le jour de la monétisation, le processus existe. ⚠️ **Un délai écrit
dans un `SECURITY.md` est une promesse unilatérale** : il est tenable par une personne seule pour
un rapport, pas pour une campagne.

---

## 4. Annexe I partie I — exigences de produit, et correspondance OASIS

Portée : l'article 13 §1 rend l'annexe I partie I obligatoire. Mais le **point 2 s'applique « le
cas échéant »**, sur la base de l'évaluation de risque de l'article 13 §2, et l'**article 13 §4**
impose, pour toute exigence écartée, « une justification claire dans [la] documentation
technique ». Le **point 1 n'est pas conditionné** :

> « Les produits comportant des éléments numériques sont conçus, développés et fabriqués de
> manière à garantir un niveau de cybersécurité approprié en fonction des risques. »

Légende : ✅ prouvé · 🟡 partiel · ❌ absent · ➖ sans objet

| Annexe I-I-2 | Exigence (abrégée ; texte intégral dans les notes) | OASIS | Preuve / manque |
|---|---|---|---|
| a) | mis à disposition **sans vulnérabilité exploitable connue** | ✅ | `cargo-audit` et `cargo-deny` sur 6 cibles, **0 vulnérabilité connue** (`evidence/supply-chain/2026-10-07/`) |
| b) | **configuration de sécurité par défaut**, réinitialisation possible | 🟡 | Les routeurs v0B sont **stricts par défaut** (v8/v9/v0A refusés, ce qui ferme un déclassement) ; un nœud non enrôlé est « unknown sender » au premier saut. ❌ Aucune réinitialisation d'usine documentée |
| c) | vulnérabilités **corrigeables par mise à jour de sécurité**, le cas échéant automatique | ✅ chemin / ❌ automatisme | Mise à jour A/B signée, sûre en cas de coupure, avec essai et retour automatique (`evidence/silicon/2026-10-06/fwupdate/REPORT.md`). ❌ USB uniquement, pas par le mesh ; aucune mise à jour automatique |
| d) | protection contre les **accès non autorisés** … **et signaler tout accès non autorisé** | 🟡 | Authentification prouvée à chaque saut et à l'actionneur (`evidence/silicon/2026-10-06/`, `2026-10-07/modbus/`). ❌ **« signaler »** : voir C5 |
| e) | protéger la **confidentialité** des données | 🟡 | ChaCha20-Poly1305 et X25519 existent à la couche spore (v3→v7). ⚠️ **v0B et v0C sont authentifiés, pas chiffrés** : la charge utile d'un ordre mesh circule en clair. À dire explicitement à tout acheteur |
| f) | protéger l'**intégrité** des données, **des commandes**, des programmes et de la configuration contre toute manipulation non autorisée **et signaler les corruptions** | ✅ intégrité / ❌ signalement | **C'est le cœur d'OASIS**, et le texte nomme explicitement « les commandes ». 0/150 inversions de bit acceptées ; contenu remplacé rejeté ; image altérée d'un octet → `HashMismatch`. ❌ « signaler les corruptions » : compteurs en RAM uniquement |
| g) | **minimisation des données** | ➖ | OASIS ne traite pas de données à caractère personnel |
| h) | protéger la **disponibilité des fonctions essentielles**, y compris **atténuation du déni de service** | 🟡 **mesuré** | Pré-filtre à clé de lien : 179,4 ms → **0,70 ms** par trame forgée ; sous 8 trames forgées/s, **60/60** messages légitimes livrés à 19 % de charge contre **39/60** à 110 % sans lui (`evidence/silicon/2026-10-07/prefilter/REPORT.md`). ⚠️ Contre un **initié**, le seau à jetons borne le calcul (143 jetons sur 144) mais **affame le trafic légitime (4/60)** : plafond de calcul, pas équité |
| i) | ne pas dégrader la disponibilité des **autres** dispositifs ou réseaux | 🟡 | L'inondation mesh n'a ni routage ni contrôle d'émission (`POSITIONING_GAPS.md` C11) ; le budget de duty-cycle n'est pas appliqué par le code |
| j) | **limiter les surfaces d'attaque**, interfaces externes incluses | 🟡 | `no_std`, pas d'allocation dans le chemin critique, parseurs totaux prouvés. ❌ Le firmware de test expose des commandes de diagnostic, dont un contournement `b` — documenté comme tel dans `SECURITY.md` §Scope |
| k) | réduire les **répercussions d'un incident**, techniques de limitation d'exploitation | 🟡 | Rust, sûreté mémoire, 1,5 × 10⁹ exécutions de fuzzing (`evidence/fuzz/2026-10-07/`). ❌ Aucun durcissement d'exécution sur Cortex-M0+ (pas d'ASLR, pas de MPU utilisée) |
| l) | **fournir des informations de sécurité en enregistrant et surveillant les activités internes pertinentes**, y compris l'accès ou la modification de données, services ou fonctions, avec possibilité de désactivation par l'utilisateur | ❌ | **Troisième texte à exiger un journal**, après l'annexe III 1.1.9 al. 5 et 1.2.1 al. 2 f) du Règlement Machines. `POSITIONING_GAPS.md` **C5** |
| m) | **suppression sûre et permanente** de toutes les données et paramètres | ❌ | Aucune procédure d'effacement documentée ; les clés privées restent lisibles en flash par BOOTSEL ou SWD |

**Lecture :** sur 13 sous-exigences, 1 est prouvée, 1 sans objet, 8 partielles, 3 absentes. Les
trois absences (d/f « signaler », l « enregistrer », m « effacer ») tiennent à **deux** chantiers :
le journal (C5) et l'effacement des secrets.

## 5. Annexe I partie II — gestion des vulnérabilités (obligations de processus)

| Annexe I-II | Exigence (abrégée) | OASIS | Preuve / manque |
|---|---|---|---|
| 1) | **nomenclature des logiciels (SBOM)** dans un format couramment utilisé et lisible par machine, couvrant au moins les dépendances de niveau supérieur | ✅ | 9 SBOM CycloneDX, un par paquet (`evidence/supply-chain/2026-10-07/sbom/*.cdx.json`) |
| 2) | gérer et corriger **sans retard**, mises à jour de sécurité séparées des fonctionnalités | 🟡 | Aucune version publiée, donc aucun canal de correctif ; la séparation sécurité/fonctionnalité n'existe pas |
| 3) | **tests et examens de sécurité efficaces et réguliers** | ✅ | 608 tests, 152 harnais Kani dont **130 vérifiés, 0 contre-exemple** (`evidence/kani/2026-10-07/full/`), 1,5 × 10⁹ exécutions de fuzzing, campagnes silicium datées |
| 4) | **publier** une description des vulnérabilités corrigées | ❌ | Aucun avis publié à ce jour. ⚠️ Des défauts de mes propres mesures sont publiés dans les rapports, ce qui est différent |
| 5) | **politique de divulgation coordonnée** | ✅ | `SECURITY.md` (contact, délais, divulgation coordonnée) |
| 6) | faciliter le partage d'informations, **adresse de contact** | ✅ | `SECURITY.md` §Reporting a vulnerability |
| 7) | **mécanismes de distribution sécurisée** des mises à jour | 🟡 | Le chemin sur l'appareil est prouvé (manifeste OAU1 kind 3, hybride, plancher anti-retour). ❌ Aucune infrastructure de distribution |
| 8) | correctifs diffusés **sans retard et gratuitement**, avec message consultatif | ❌ | Aucun processus |

### Durée de support — ce que le texte impose vraiment

- **Article 13 §8, al. 3** : période d'assistance d'au moins **5 ans** (ou la durée d'utilisation
  prévue si elle est inférieure).
- **Article 13 §9** : les mises à jour déjà publiées restent disponibles **au moins 10 ans**.
- **Article 13 §19** : la date de fin de support (mois et année) est affichée **à l'achat**.

C'est exactement la question de `POSITIONING_GAPS.md` **D5** (« qui assure le support pendant 5 à
10 ans ? »), et le CRA la transforme en obligation chiffrée dès que le produit est monétisé. Une
personne seule ne peut pas s'engager sur 5 ans de correctifs et 10 ans de disponibilité. **Ce
point conditionne le modèle économique plus que n'importe quelle exigence technique.**

### SBOM : trois idées fausses corrigées

1. **Aucun format n'est imposé.** « CycloneDX » et « SPDX » apparaissent **0 fois** dans le texte,
   FR et EN (recherche plein texte). L'exigence est « un format couramment utilisé et lisible par
   machine ». Un acte d'exécution peut le préciser (art. 13 §24) ; aucun n'a été identifié.
2. **La SBOM n'est pas publique.** Le considérant 77 le dit explicitement. Elle vit dans le
   dossier technique (annexe VII, point 2 b)) et n'est transmise à l'autorité que **sur demande
   motivée** (annexe VII, point 8) ; la fournir à l'utilisateur est **facultatif** (annexe II,
   point 9).
3. **Seules les dépendances de niveau supérieur** sont exigées (« au moins »).

Publier 9 SBOM complètes est donc **au-delà** de l'exigence. C'est un choix de transparence, pas
une obligation — à présenter comme tel.

---

## 6. Normes harmonisées : aucune référence vérifiée

La Commission a émis la demande de normalisation **M/606 = C(2025)618**, portant sur « a set of
41 standards », horizontales et verticales, avec priorité aux annexes III et IV
([Commission européenne — CRA standardisation](https://digital-strategy.ec.europa.eu/en/policies/cyber-resilience-act)).

⚠️ **Aucune référence de norme harmonisée citée au JO n'a pu être vérifiée à la source**, et la
page officielle n'en liste aucune. L'état d'avancement normatif qui circule (EN 40000-1-1 et
-1-2 votées, ratification annoncée, report de deux mois des échéances 2026) provient
**exclusivement de sources secondaires non officielles** : **non vérifié à la source**, à ne pas
citer dans un document d'acheteur.

## 7. Ce que ce texte change pour le positionnement

1. **OASIS est hors champ tant qu'il n'est pas monétisé** (cons. 18 et 20), et le statut
   d'intendant lui est **juridiquement fermé** (art. 3, point 14 : personne morale). Correction
   de `POSITIONING_GAPS.md` D4.
2. **La monétisation déclenche l'annexe I entière**, plus 5 ans de support et 10 ans de
   disponibilité des mises à jour. À décider avant de facturer.
3. **Le CRA est un générateur de demande, pas une contrainte** : l'article 13 §5 oblige chaque
   intégrateur à instruire ses composants tiers. Le dossier de preuves de ce dépôt est
   précisément ce qu'il doit produire.
4. **Le journal (C5) est exigé une troisième fois** ici, à l'annexe I-I-2 l), après les deux
   occurrences du Règlement Machines. Quatre textes, un seul chantier.
5. **À dire sans détour : v0B et v0C ne chiffrent pas.** L'annexe I-I-2 e) demande la
   confidentialité « le cas échéant » ; si un acheteur en a besoin sur le mesh, c'est un
   développement, pas une option de configuration.

## 8. Limites de ce document

- Le texte a été téléchargé depuis EUR-Lex et cité depuis le fichier local, en FR et en EN.
- **Non vérifié à la source** : l'acte d'exécution sur le format de SBOM (art. 13 §24) ; l'acte
  d'exécution sur le format des notifications (art. 14 §10) ; la référence EUR-Lex de l'acte
  délégué de l'article 14 §9 que la Commission indique avoir adopté le 11/12/2025 ; le contenu
  des orientations de la Commission du 27/07/2026 ; le document M/606 lui-même ; toute référence
  de norme harmonisée au JO. ENISA n'a pas été consulté.
- Le terme « **monétisé** », pivot de tout le raisonnement de périmètre, **n'est pas défini dans
  le règlement**. C'est la plus grande incertitude de ce document.
- Notes de recherche brutes, avec l'annexe I intégrale et les considérants 17 à 20 :
  `research_notes/Conformité réglementaire OASIS phase 0/cra.md`.
