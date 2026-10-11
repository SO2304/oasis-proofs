# Post-quantique — feuille de route UE, tailles réelles, et ce qui tient dans une trame LoRa

**Rédigé le 2026-10-07.** Objet : décider quelles options post-quantiques sont réalistes pour un
nœud Cortex-M0+ communiquant par LoRa en Europe (`POSITIONING_GAPS.md` **A6** et **C3**).

> **Ce document ne revendique aucune fonction de sûreté.** Voir
> [`IEC_TS_63074.md`](IEC_TS_63074.md).

---

## 1. Calendrier UE — dates fermes

Acte fondateur : **recommandation (UE) 2024/1101 du 11 avril 2024** « on a Coordinated
Implementation Roadmap for the transition to Post-Quantum Cryptography »
([EUR-Lex](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=OJ%3AL_202401101)). Son §6 promeut
un déploiement « **via hybrid schemes** that may combine Post-Quantum Cryptography with existing
cryptographic approaches or with Quantum Key Distribution ».

Document opérationnel portant les dates : « *A Coordinated Implementation Roadmap for the
Transition to Post-Quantum Cryptography — **Part 1, Version 1.1, EU PQC Workstream, 11.06.2025***»
([PDF, EC newsroom](https://ec.europa.eu/newsroom/dae/redirection/document/117507)), plus la FAQ
officielle du 15/04/2026.

| Jalon | Date | Contenu (encadré « Timeline for the transition to PQC ») |
|---|---|---|
| 1 | **31/12/2026** | premières étapes implémentées par tous les États membres ; feuilles de route nationales établies ; **planification et pilotes engagés** pour les cas à risque haut et moyen |
| 2 | **31/12/2030** | **cas d'usage à haut risque migrés** ; mises à jour logicielles et de micrologiciel **quantum-safe activées par défaut** |
| 3 | **31/12/2035** | cas d'usage à risque moyen migrés |

Périmètre : **entités NIS 2 et infrastructures critiques**. `POSITIONING_GAPS.md` A6 est exact sur
l'échéance de fin 2030.

**Deux précisions qui changent la lecture :**

1. **Les jalons portent sur les déploiements, pas sur le développement produit.** Un nœud vendu en
   2028 à un exploitant d'infrastructure critique devra être migrable avant fin 2030 ; il n'a pas
   à être post-quantique en 2026.
2. **Le jalon 2 nomme explicitement les mises à jour de micrologiciel** « quantum-safe activées
   par défaut ». C'est exactement le chemin déjà implémenté en phase 1.3 (manifeste OAU1 kind 3,
   signature hybride Ed25519 + ML-DSA-44) — **la seule partie du jalon 2030 qu'OASIS satisfait
   déjà**, et elle est prouvée sur silicium.

### Hybridation : convergence ANSSI / BSI, avec une exception exploitable

Les deux agences imposent l'hybridation (classique **et** post-quantique), **sauf pour les
schémas fondés sur le hachage** — **SLH-DSA, XMSS et LMS** — qu'elles autorisent en usage seul.
C'est **le seul chemin conforme non hybride**, et il n'est pas anodin : il divise par deux le coût
en octets.

⚠️ **Tension conformité / budget radio** : le BSI (TR-02102-1, version **2026-01**, lue à la
source) **écarte ML-DSA-44 et SLH-DSA-128s**, n'acceptant que les catégories 3 et 5 — donc
**ML-DSA-65 (3 309 o)** et **SLH-DSA-192s (16 224 o)**. **Le choix conforme BSI est
systématiquement le plus coûteux en octets.** C'est le conflit central de ce document.

⚠️ **Non vérifié à la source** : le *follow-up position paper* de l'ANSSI est illisible (les deux
URL PDF de cyber.gouv.fr renvoient une page de portail). Son calendrier en trois phases et les
couples recommandés (X25519 + ML-KEM-768, ECDSA P-256 + ML-DSA-65) restent **non vérifiés** ;
seule la FAQ officielle a pu être citée.

---

## 2. Tailles exactes — lues dans les standards

**ML-DSA — FIPS 204, Table 2** ([PDF, p. 16](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.204.pdf)) :

| Jeu | Clé publique (o) | **Signature (o)** | Catégorie NIST |
|---|---:|---:|---:|
| ML-DSA-44 | 1 312 | **2 420** | 2 |
| ML-DSA-65 | 1 952 | **3 309** | 3 |
| ML-DSA-87 | 2 592 | **4 627** | 5 |

`POSITIONING_GAPS.md` A6 citait **2 420 octets** pour ML-DSA-44 : **exact, vérifié à la source**.

**SLH-DSA — FIPS 205, Table 2** ([PDF](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.205.pdf)) :

| Jeu | pk (o) | **Signature (o)** | Catégorie |
|---|---:|---:|---:|
| SLH-DSA-128s | **32** | **7 856** | 1 |
| SLH-DSA-192s | 48 | **16 224** | 3 |
| SLH-DSA-256s | 64 | **29 792** | 5 |

Le plus petit jeu SLH-DSA est **3,2× plus gros** que ML-DSA-44. Sa clé publique, en revanche, est
minuscule (32 o).

**LMS — RFC 8554** ([RFC](https://www.rfc-editor.org/rfc/rfc8554.html)) : signature =
`4 + n·(p+1) + m·h` octets ; clé publique = `24 + m` octets, soit **56 o** pour SHA-256.
Signatures OTS à la source (Table 1) : W1 = 8 516 o, W2 = 4 292 o, W4 = 2 180 o, **W8 = 1 124 o**.

**[calcul]** Signature LMS complète = signature OTS + `m·h` :

| Combinaison | Taille | Nombre max de signatures |
|---|---:|---:|
| H10 + LMOTS W8 | **1 444 o** | 2¹⁰ = 1 024 |
| H20 + LMOTS W8 | **1 764 o** | 2²⁰ ≈ 1,05 M |
| H25 + LMOTS W8 | **1 924 o** | 2²⁵ ≈ 33,5 M |

**XMSS — RFC 8391** : clé publique `2n + 4` = **68 o** (n=32). XMSS-SHA2_10_256 = **2 500 o**,
_16_256 = 2 692 o, _20_256 = 2 884 o.

**Falcon** — spécification officielle : Falcon-512 pk **897 o**, signature **666 o**.
⚠️ **Deux réserves** : (1) la taille dépend de l'encodage — 666 o est la valeur de la
spécification, les implémentations exposent 690, 752, 809 ou 1 077 o ; **une taille Falcon doit
toujours être qualifiée par son encodage** ; (2) **Falcon n'apparaît ni dans FIPS 204/205 ni dans
les tables BSI lues** : le statut de FIPS 206 (FN-DSA) est **non vérifié**, à traiter comme **non
standardisé**.

Repère d'échelle : Ed25519 = signature 64 o, clé publique 32 o. *Non revérifié à la source dans
cette session.*

⚠️ Une note de bas de page de FIPS 205 mentionne une publication NIST (chaîne extraite
« SP 800-230 ») spécifiant des jeux de paramètres additionnels à nombre de signatures plus limité.
**Non vérifié, extraction possiblement erronée** (confusion probable avec SP 800-208). **À
vérifier en priorité**, car elle pourrait contenir des jeux SLH-DSA à signatures plus courtes.

---

## 3. Le budget LoRa EU868 — et il est impitoyable

**Charge utile applicative maximale** — LoRaWAN **RP002-1.0.3**, Tables 8, 12 et 13, EU863-870
([PDF](https://lora-alliance.org/wp-content/uploads/2021/05/RP002-1.0.3-FINAL-1.pdf)) :

| DR | SF | **Charge utile applicative max (o)** |
|---:|---|---:|
| 0–2 | SF12, SF11, SF10 | **51** |
| 3 | SF9 | 115 |
| 4+ | SF8, SF7 | 242 |

**Duty-cycle : la chaîne juridique, établie à la source.** ETSI **EN 300 220-2 V3.2.2**, clause
4.4.3.2 : duty cycle = `Ton_cum / Tobs`, avec « Tobs is 1 hour », appliqué **par bande**. La
bande M (868,0–868,6 MHz), où se trouvent les trois canaux LoRaWAN par défaut, est limitée à
**1 %**. EN 300 220-2 est une norme harmonisée sous la RED ; son annexe B renvoie à la **décision
2019/1345/UE** modifiant la décision 2006/771/CE.

> **Point crucial, souvent mal compris :** `Fobs` est la **bande**, pas le canal. Étaler les
> émissions sur 868,1 / 868,3 / 868,5 MHz **ne multiplie pas le budget** — les trois canaux sont
> dans la même bande M.

**[calcul]**

```
Ton_cum_max = 0,01 × 3 600 s = 36 s par heure et par bande
N_msg/h     = floor( 36 / ToA(SF, PL) )
```

Hypothèses radio : BW 125 kHz, CR 4/5, 8 symboles de préambule, en-tête explicite, CRC actif,
LDRO actif pour SF11 et SF12.

| SF | ToA (PL = 64 o) | **msg/h** | ToA (PL = 255 o) | **msg/h** |
|---|---:|---:|---:|---:|
| SF7 | 118,0 ms | **305** | 399,6 ms | 90 |
| SF8 | 215,6 ms | 167 | 707,1 ms | 50 |
| SF9 | 390,1 ms | 92 | 1 250,3 ms | 28 |
| SF10 | 698,4 ms | 51 | 2 295,8 ms | 15 |
| SF11 | 1 560,6 ms | 23 | 5 001,2 ms | 7 |
| SF12 | 2 793,5 ms | **12** | 9 019,4 ms | **3** |

Exemple détaillé, SF12 / 64 o : `36 / 2,7935 = 12,89` ⇒ **12 messages/heure** (le treizième
dépasserait 36 s).

**Correction de `POSITIONING_GAPS.md` C3**, qui estimait « une trame de 255 octets en SF12 dure
≈ 9 s, soit environ une trame toutes les 15 min » : la durée **9,019 s est confirmée**, et le
débit permis est de **3 trames/heure**, soit une toutes les 20 minutes. L'estimation était juste
à 25 % près.

⚠️ **« Non vérifié à la source »** : la datasheet Semtech SX1276 est inaccessible (portail
commercial, toutes les URL testées renvoient du HTML). **La formule de time on air n'a pas été
vérifiée à la source** et doit l'être avant tout usage en dossier de conformité. Toutes les
valeurs de ToA ci-dessus sont marquées **[calcul]**.

---

## 4. Le verdict : ce qui tient, ce qui ne tient pas

**[calcul]** Coût d'**une seule** signature post-quantique fragmentée à SF12 (51 o applicatifs par
trame, donc 48 trames pour 2 420 o) :

| Schéma | Signature | Trames à SF12 | **Budget légal consommé** |
|---|---:|---:|---|
| **Ed25519** (actuel) | 64 o | 2 | **≈ 10 min** |
| **LMS** H20 + W8 | 1 764 o | 35 | ≈ 2,9 h |
| **Falcon-512** | 666 o | 14 | ≈ 1,2 h |
| **ML-DSA-44** | 2 420 o | 48 | **3,72 h** |
| **ML-DSA-65** (conforme BSI) | 3 309 o | 65 | **5,04 h** |
| **SLH-DSA-192s** (conforme BSI) | 16 224 o | 319 | **24,75 h** |

**Une signature ML-DSA-65 à SF12 consomme plus de cinq heures du budget légal d'un nœud.** Ce
n'est pas une difficulté d'ingénierie, c'est une impossibilité à ce facteur d'étalement.

**MTU de SCHC over LoRaWAN : 2 520 octets** (valeur calculée dans la RFC 9011 elle-même). Elle
couvre Falcon-512, LMS, ML-DSA-44 et XMSS-SHA2_10_256, **mais ni ML-DSA-65, ni aucun SLH-DSA**.

⚠️ **Aucune spécification normalisée d'agrégation de signatures post-quantiques n'a été trouvée**
(RFC, FIPS, LoRa Alliance) : seuls des travaux académiques, écartés faute de source primaire.

### Options réalistes, classées

| # | Option | Pour | Contre |
|---|---|---|---|
| **1** | **Cantonner le post-quantique aux messages rares** : mises à jour de micrologiciel, révocation, politique. Garder Ed25519 par saut | **C'est déjà fait** (phase 1.1 et 1.3, hybride Ed25519 + ML-DSA-44, prouvé sur silicium et après coupure de courant). Aligné sur le jalon UE 2030, qui nomme les mises à jour de micrologiciel | Ne protège pas les ordres eux-mêmes contre un attaquant quantique futur |
| **2** | **LMS, LMOTS w=8, non hybridé** (1,4 à 1,9 kio ; clé publique **56 o**) | **L'option la plus défendable au vu des sources** : ANSSI et BSI autorisent les schémas à hachage **sans** hybridation, ce qui divise par deux le coût. Clé publique 23× plus petite que ML-DSA-44 — décisif pour un nœud qui stocke les clés de ses pairs. Le BSI désigne nommément la **signature de mises à jour de micrologiciel** comme usage approprié aux schémas à état | **À état** : « the LMS signing algorithm is **stateful** » ; réutiliser un état détruit toute garantie. Inacceptable sur un nœud qui peut perdre son alimentation — **mais acceptable sur le PC opérateur**, qui signe les révocations et les manifestes |
| **3** | Fragmentation signée de ML-DSA-65 à SF7 uniquement | Conforme BSI | 3 309 o = 14 trames à SF7, soit ≈ 5 % du budget horaire : jouable. Mais SF7 est la portée **la plus courte** — on perd l'intérêt du LoRa |
| **4** | SLH-DSA sur LoRa | Sans état, conforme BSI en 192s | **Exclu** : 24,75 h de budget pour une signature |

**Recommandation technique :** garder l'architecture actuelle (option 1), et instruire l'option 2
**pour la clé opérateur sur PC** — là où l'état est gérable et où la clé publique de 56 octets est
un avantage net pour les nœuds. Ne pas tenter d'ordre par saut post-quantique sur LoRa.

### Ce qu'OASIS a déjà, et ce qui manque

| Élément | État | Preuve / manque |
|---|---|---|
| **Agilité cryptographique dans l'enveloppe** | ✅ | Octet de suite **signé** dans `OAU1` ; suite minimale par type de message, **jamais abaissée**, persistée en deux emplacements flash ; déclassement refusé **avant toute vérification de signature**. Correction de `POSITIONING_GAPS.md` A6, qui disait « pas d'agilité cryptographique » : c'est vrai de `SPORE\x0B`, faux des messages d'autorité |
| **Signature hybride Ed25519 + ML-DSA-44** | ✅ | `libcrux-ml-dsa` 0.0.10 sur l'appareil ; oracle indépendant RustCrypto `ml-dsa` 0.1.1 ; ACVP NIST sigVer **15/15** sur les deux ; concordance octet pour octet sur 8 graines ; **20 072 inversions d'un bit, 0 acceptée**. Sur RP2040 : porte hybride complète **377 ms**, pile **48,7 Ko**, flash **+125 Ko**. Silicium A→B→C avec coupure de courant réelle (`evidence/silicon/2026-10-06/pq/REPORT.md`) |
| **Plan de migration écrit** | 🟡 | `docs/specs/PQ_AUTHORITY_SPEC.md` couvre les messages d'autorité. ❌ Rien pour `SPORE\x0B` : le magic fige l'algorithme par saut |
| **Aucun KEM post-quantique** | ❌ | L'échange de clés reste X25519 ; aucun ML-KEM. C'est l'écart réel avec Veridify (`partners/OASIS_VS_VERIDIFY.md`) |
| **Conformité BSI** | ❌ | ML-DSA-44 est de catégorie 2 ; le BSI exige la catégorie 3. Passer à ML-DSA-65 coûte +889 o par signature et n'a pas été mesuré sur RP2040 |

---

## 5. Limites de ce document

- **Vérifié à la source** : FIPS 204 et 205 (PDF téléchargés, Table 2 de chacun) ; recommandation
  (UE) 2024/1101 ; feuille de route NIS CG Part 1 v1.1 (PDF officiel) et sa FAQ du 15/04/2026 ;
  BSI TR-02102-1 version 2026-01 (tables 5.3, 5.6, 5.7, 5.8 et §5.3.4) ; FAQ PQC de l'ANSSI ;
  LoRaWAN RP002-1.0.3 (Tables 6, 8, 12, 13) ; ETSI EN 300 220-2 V3.2.2 (clause 4.4.3.2, table des
  bandes, annexe B) ; RFC 8554, RFC 8391, RFC 9011 ; spécification Falcon.
- **Non vérifié à la source** : datasheet SX1276 → **la formule de time on air**, donc toutes les
  valeurs de ToA et de messages/heure (marquées **[calcul]**) ; le *position paper* de suivi de
  l'ANSSI ; le statut de Falcon / FIPS 206 ; la référence « SP 800-230 » citée en note de FIPS 205.
- **Versions lues** : ETSI EN 300 220-2 **V3.2.2 (2024-03) en projet** — la version référencée au
  JOUE peut être la V3.2.1 (2018-04) ; RP002-**1.0.3** alors que 1.0.4 existe ; SP 800-208 non lu
  (peut restreindre les jeux LMS/XMSS par rapport aux RFC) ; structure de trame LoRaWAN (surcoût
  de 13 o) non revérifiée dans TS001.
- Notes de recherche brutes, avec les calculs détaillés :
  `research_notes/Conformité réglementaire OASIS phase 0/pqc_lora.md`.
