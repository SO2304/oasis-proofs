# Correspondance réglementaire et normative

**Phase 0 de `prompts/POSITIONING_ALIGNMENT.md`, 2026-10-07.** Un fichier par texte. Chacun
contient le texte officiel (verbatim et lien), les dates d'application, le périmètre, et un
tableau **exigence → ce qu'OASIS couvre → preuve → ce qui manque**.

> **Règle appliquée partout.** Chaque exigence porte son statut de vérification : **« vérifié à
> la source »** (texte officiel lu) ou **« non vérifié à la source »** (norme payante ou document
> inaccessible), avec l'origine de l'information. Aucun chiffre n'est inventé ; toute estimation
> est marquée **[calcul]** ou « estimation ».

> **OASIS n'est pas une fonction de sûreté certifiée** : ni PL (ISO 13849-1), ni SIL (IEC 62061).
> Aucun document de ce dossier ne l'affirme, même indirectement. Le cadrage est dans
> [`IEC_TS_63074.md`](IEC_TS_63074.md), à lire en premier.

| Fichier | Texte | Échéance | Ce qu'il décide |
|---|---|---|---|
| [`MACHINERY_REGULATION_2023_1230.md`](MACHINERY_REGULATION_2023_1230.md) | Règlement Machines (UE) 2023/1230 | **20/01/2027** | **Le déclencheur d'achat.** Annexe III 1.1.9 et 1.2.1 verbatim ; périmètre (drones, AMR, composants de sécurité) ; pourquoi OASIS se vend comme fournisseur de preuve, pas comme composant certifié |
| [`CRA.md`](CRA.md) | Cyber Resilience Act (UE) 2024/2847 | art. 14 **depuis le 11/09/2026** ; reste **11/12/2027** | OASIS est **hors champ tant qu'il n'est pas monétisé** ; le statut d'intendant lui est juridiquement fermé ; le CRA crée la **demande** pour son dossier de preuves |
| [`EN_18031.md`](EN_18031.md) | RED 2014/53/UE + règlement délégué (UE) 2022/30 + EN 18031 | **depuis le 01/08/2025**, **abrogé au 11/12/2027** | Un nœud LoRa est dans le champ, mais la fenêtre se referme : **le travail utile est le CRA**. Grille de lecture technique des 11 mécanismes |
| [`IEC_62443_4_2.md`](IEC_62443_4_2.md) | IEC 62443-4-2 et -4-1 | volontaire | SL 2 en capacité visé, **non certifié** ; la grappe « journal » (6 exigences) est le plus gros bloc manquant ; 3 absences tiennent au matériel |
| [`IEC_TS_63074.md`](IEC_TS_63074.md) | IEC TS 63074:2023 | volontaire | **La frontière sûreté / sécurité.** La règle de bascule d'ISO 13849-1 qui rend C2 bloquant ; le vocabulaire à employer devant un ingénieur sûreté |
| [`MAVLINK_SIGNING_GAP.md`](MAVLINK_SIGNING_GAP.md) | Signature MAVLink 2 (spec, PX4, ArduPilot) | — | **9 limites documentées, 9 réponses prouvées** — et la 10ᵉ démonstration, l'intégration PX4, qui manque et sans laquelle rien ne se vend côté drones |
| [`PQC.md`](PQC.md) | Feuille de route PQC de l'UE, FIPS 204/205, RFC 8554/8391, LoRa EU868 | **31/12/2030** | Les tailles réelles contre 36 s d'émission par heure : une signature ML-DSA-65 à SF12 coûte **5 h** de budget légal. Options réalistes classées |
| [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md) | Règlement Machines, annexe III 1.1.9 **alinéa 3** | **20/01/2027** | La moitié « **identifiés comme tels** » : les logiciels et données d'OASIS dont dépend la conformité, **et ce qui est hors périmètre**. Chaque chemin vérifié par `tools/check_claims.sh`. Ce n'est **pas** un SBOM : celui-là liste les dépendances, celui-ci les parties d'OASIS lui-même |

## Ce qui ressort de l'ensemble

**Un seul chantier est exigé par quatre textes** : la trace des ordres acceptés et refusés
(`POSITIONING_GAPS.md` **C5**).

| Texte | Où |
|---|---|
| Règlement Machines | annexe III 1.1.9 al. 5 (« recueillent la preuve d'une intervention légitime ou illégitime ») |
| Règlement Machines | annexe III 1.2.1 al. 2 f) (« journal de suivi […] activé pendant cinq ans ») |
| CRA | annexe I-I-2 l) (« enregistrant et en surveillant les activités internes pertinentes ») |
| IEC 62443-4-2 | CR 2.8, 2.9, 2.10, 2.11, 2.12 et 3.9 |

Seule **EN 18031-1** ne l'exige pas — son mécanisme de journalisation (LGM) est dans les parties
2 et 3 (⚠️ non vérifié à la source).

**Et un chantier est exigé par le texte lui-même, pas par un ingénieur** : l'arrêt et la perte de
liaison (**C2**). Le Règlement Machines, annexe III 1.2.1, dit « l'arrêt automatique ou manuel des
éléments mobiles, quels qu'ils soient, **n'est pas empêché** » et « pour la commande sans fil, une
défaillance de la communication […] **n'entraîne pas de situation dangereuse** ». Tant que la
porte appliquait ses 7 conditions à un ordre d'arrêt, OASIS était contraire à cette clause.

> **Fermé le 2026-10-08.** `stop_decision` ne garde que **3** des 9 conditions de la porte
> (v0B valide, droit `STOP`, origine non révoquée) et l'arrêt **se verrouille**. Voir
> [`IEC_TS_63074.md`](IEC_TS_63074.md) et la section G de
> [`../../partners/POSITIONING_GAPS.md`](../../partners/POSITIONING_GAPS.md).

## Notes de recherche brutes

`research_notes/Conformité réglementaire OASIS phase 0/` — 8 fichiers, ~560 Ko, structurés en
Takeaway / Cited Findings / Inferences / Gaps par question. Ils contiennent les verbatim
intégraux (FR et EN), les considérants, et la liste des points **non vérifiés à la source**. Les
documents de ce dossier sont la couche **autoritative** ; les notes sont la matière première, et
contiennent des éléments explicitement marqués « à ne pas citer ».
