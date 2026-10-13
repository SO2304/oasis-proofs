# « Dossier de preuve 1.1.9 » — spécification du livrable

**Rédigé le 11 octobre 2026** à partir de `research_notes/Monétisation OASIS sans crédit/format_preuve_auditeurs.md`.
Les attentes d'auditeurs y sont des inférences à partir des textes (règlement, FprEN 50742, CyFun 2025, IEC 62443-4-2,
protocole DGUV GS-IFA-M25 de juillet 2026) : aucune checklist officielle d'organisme notifié n'a pu être lue en entier.
Tout chemin cité ci-dessous existe dans l'arbre de la branche `claude/eloquent-ptolemy-oojjn0` au commit qui porte ce
fichier (fusion de `max-tech-2026-10-09` à `f00aff7`).

## 1. Ce qu'on vend, en une phrase

Pour un type de machine ou un site : OASIS est posé devant l'automate ou l'onduleur, une campagne d'ordres légitimes
et d'attaques est jouée, et le client reçoit un dossier organisé **clause par clause** du règlement (UE) 2023/1230,
annexe III 1.1.9 et 1.2.1, qui montre que seule une commande signée et autorisée atteint l'actionneur et que chaque
intervention, légitime ou illégitime, est consignée dans un journal infalsifiable à distance. Prix de lancement
2 900 € HT, acompte 50 %, livraison en dix jours ouvrés après la journée d'inventaire.

Ce que le dossier **n'est pas** : un certificat, une évaluation indépendante, une fonction de sûreté (ni PL ni SIL ;
OASIS n'est jamais dans la chaîne d'arrêt d'urgence), ni une preuve sur un automate du commerce tant qu'un client ne
l'a pas fourni.

## 2. Table des matières type (15 sections)

1. **Résumé de preuve** (une page, format §4).
2. **Objet, périmètre, frontière sûreté/sécurité** : hypothèse « OASIS est le seul chemin de commande », accès
   physique hors périmètre.
3. **Référentiel et dates** : texte verbatim 1.1.9 et 1.2.1 (consolidé `02023R1230-20260727`), application au
   20 janvier 2027, absence de norme harmonisée, état de FprEN 50742 (vote formel, publication annoncée novembre 2026
   ou avril 2027 selon les sources).
4. **Évaluation des risques numériques et analyse de menaces** : 23 menaces, 19 couvertes, les 4 restantes nommées ;
   détermination du niveau SRSL par interface (document à produire par client).
5. **Inventaire des logiciels et données essentiels** (al. 3) : `docs/compliance/SOFTWARE_INVENTORY.md`, vérifié par
   `tools/check_claims.sh`.
6. **Spécification des exigences de sécurité** : authenticité (v0B/v0C), autorisation (porte à 9 conditions, classes
   Act/Stop), fraîcheur (`boot_id`, compteur persisté), révocation, enrôlement, mise à jour signée, confidentialité,
   quorum.
7. **Preuves formelles et tests** : 735 tests, 196 harnais Kani (175/182 vérifiés en balayage séquentiel, 7 lourds
   réservés à la CI), fuzzing ; contrôles négatifs systématiques.
8. **Essais sur silicium et campagnes réelles** : RP2040 ×3, pilote `oasis_test_plc` 72/72, deux machines 98/98 répété,
   SMA (partiel, aucune écriture), PX4 SITL 5/5 ; pour chaque campagne : empreinte git, SHA256SUMS, défauts trouvés.
9. **Journal de preuve** (al. 5 et 1.2.1 f) : format, chaîne de hachage, verdicts, vérificateur indépendant, échantillons
   avec acceptations, refus et changements, falsification → exit 1, survie à la coupure et au redémarrage, témoin
   externe, lieu de stockage (réponse au protocole DGUV), politique de rétention cinq ans (**à écrire avec le client**),
   procédure d'export pour l'autorité.
10. **Identification des logiciels installés** (al. 4) : version, `FirmwareInstalled` avec SHA-256, limites.
11. **Mise à jour sécurisée et intégrité du démarrage** : A/B, rollback, coupures ; absence de secure boot sur RP2040.
12. **Chaîne d'approvisionnement** : SBOM CycloneDX ×9, `cargo audit` et `cargo deny`, licences, `SECURITY.md`.
13. **Correspondances normatives** : IEC 62443-4-2 CR par CR, CyFun 2025 (pièces fournies à l'exploitant), CRA ; chaque
    ligne marquée vérifié ou non vérifié à la source.
14. **Limites, écarts et éléments non fournis** : formulations exactes du §5.
15. **Annexes** : SHA256SUMS, commandes de reproduction, liste chronologique des erratums.

## 3. Correspondance clause → preuve existante

| Clause | Preuve attendue | Fichiers OASIS à joindre | Statut honnête |
|---|---|---|---|
| 1.1.9 al. 1 (raccordement sans situation dangereuse) | essais d'attaque par interface, hypothèse seul chemin écrite | `evidence/silicon/2026-10-07/modbus/REPORT.md`, `evidence/pilot/2026-10-09/`, `evidence/real/2026-10-10/twohost-campaign-3/` | 🟡 vaut si OASIS est le seul chemin ; BOOTSEL/SWD hors périmètre |
| 1.1.9 al. 2, matériel de transmission | format de trame authentifié, essais de corruption | `evidence/silicon/2026-10-06/REPORT_MESH_V0B.md` (0/150 bit-flips), `docs/MESH_V0B_SPEC.md` | 🟡 logiciel seulement |
| 1.1.9 al. 2, preuve d'intervention matérielle | détecteur physique | aucun (emplacement `TamperSignal` seulement) | ❌ à déclarer |
| 1.1.9 al. 3, inventaire | inventaire versionné et vérifié | `docs/compliance/SOFTWARE_INVENTORY.md`, SBOM `evidence/supply-chain/2026-10-07/sbom/` | ✅ documentaire, à refaire par machine |
| 1.1.9 al. 4, identification des logiciels installés | procédure et condensé réel | `evidence/silicon/2026-10-09/c4-reflash/` | 🟡 USB seulement |
| 1.1.9 al. 5, intervention légitime ou illégitime | journaux avec acceptations et refus, vérificateur indépendant, falsification détectée | `evidence/real/2026-10-10/twohost-campaign-3/jrn*.verify`, `jrn_tampered.verify`, `witness.pc2`, `evidence/pilot/2026-10-09/journal_run3.txt`, `evidence/silicon/2026-10-08/hardening/` | ✅ sur hôte et RP2040 ; attaquant distant seulement, lectures non journalisées, Modbus brut sans entrée |
| 1.2.1 a), tentatives malveillantes prévisibles | modèle de menace relié aux essais | `docs/SECURITY_COMPARISON.md`, matrice CLAUDE.md, `evidence/silicon/2026-10-08/b1-sitl/` | ✅ |
| 1.2.1 f), journal cinq ans après chaque téléchargement | survie au redémarrage, export, rétention | archivage `<prefix>.<boot_id>.*`, `jrnB.<boot_id>.*`, `--keep-journals`, `tools/journal_witness.sh` | 🟡 mécanisme prouvé ; **rétention = procédure d'exploitation à écrire** |
| 1.2.1 d)/f), l'arrêt n'est pas empêché | preuve formelle et silicium | `proof_stop_never_blocked`, `evidence/silicon/2026-10-08/{hardening,jk}/` | ✅ |
| FprEN 50742, authentification et mise à jour signée | spec d'identité, essais « unknown sender », A/B | `docs/specs/ENROLLMENT_OWNERSHIP_SPEC.md`, `evidence/silicon/2026-10-06/{enroll,fwupdate}/` | 🟡 pas de secure boot |
| CyFun PR.AA / PR.MA-2 / PR.PS-04 | ordres approuvés et journalisés, logs protégés | journal passerelle, `peer_pk … ,ACTUATE` ou `,STOP`, `deploy/oasis-mbtcp-*.service` | ✅ comme pièce fournie, jamais « certifié CyFun » |
| IEC 62443-4-2 CR 2.8, 2.12, 3.9 | événements auditables, non-répudiation, protection | journal partie I, origine attribuée, chaîne de hachage | 🟡 capacité, non certifié ; CR 2.9 RE(1), 2.10, 2.11 non couverts |
| Questionnaire acheteur, SBOM et CVE | SBOM, audit de dépendances, divulgation | `evidence/supply-chain/2026-10-07/` | ✅ ; `SECURITY.md` à écrire |

## 4. Résumé de preuve, une page (gabarit)

```
DOSSIER DE PREUVE 1.1.9 — RÉSUMÉ            Réf. OASIS-DP-<AAAA-MM-JJ>-<client>   Rév. n
Produit : passerelle OASIS Modbus TCP/RTU            Version : <tag git>   Empreinte : <sha>
Fabricant du logiciel : <société>                    Licence : <commerciale ; code accessible sous NDA, séquestre possible>
Référentiel : Règlement (UE) 2023/1230, annexe III 1.1.9 et 1.2.1 (consolidé 02023R1230-20260727)
État de l'art consulté : FprEN 50742:2026 (non harmonisée), IEC 62443-4-2 (SL2 visé, non certifié)
Nature : autorité de commande logicielle. NI fonction de sûreté (pas de PL/SIL), NI composant de sécurité art. 3(3).
Hypothèse d'emploi : OASIS est le SEUL chemin de commande vers l'actionneur ; accès physique hors périmètre.

| Exigence             | Preuve principale                              | Méthode        | Résultat            | Statut |
| 1.1.9 al. 1          | campagne site <client> ; twohost-campaign-3     | essai attaque  | 0 écriture illégit. | 🟡     |
| 1.1.9 al. 2 matériel | —                                              | —              | —                   | ❌     |
| 1.1.9 al. 3          | SOFTWARE_INVENTORY.md (machine <client>)       | revue + script | n chemins           | ✅     |
| 1.1.9 al. 4          | c4-reflash ; version lue sur site              | essai          | SHA-256 préfixe     | 🟡     |
| 1.1.9 al. 5          | jrn*.verify ; jrn_tampered ; witness           | essai + vérif. | intact / exit 1     | ✅*    |
| 1.2.1 a)             | SECURITY_COMPARISON ; 19/23 menaces            | analyse+essais | —                   | ✅     |
| 1.2.1 f) 5 ans       | archivage <prefix>.<boot_id> ; rétention client| essai + proc.  | chaîne conservée    | 🟡**   |
* attaquant distant seulement ; lectures non journalisées   ** rétention = procédure d'exploitation
Vérification formelle : 196 harnais Kani (175/182 balayage, 7 en CI) ; 735 tests ; CI verte au commit <sha>
Chaîne d'approvisionnement : SBOM CycloneDX ×9 ; cargo audit 0 vulnérabilité ; 3 avis informatifs documentés
Non fourni : évaluation externe, certification IEC 62443, pentest tiers (voir §14)
Intégrité du dossier : SHA256SUMS <hash racine> ; reproduction : tools/check_claims.sh --full
Signataire : <nom, date>. Ce résumé n'est pas un certificat et n'emporte aucune présomption de conformité.
```

## 5. Formulations à employer pour ce qui n'est pas fourni

| Élément demandé | Phrase à écrire telle quelle |
|---|---|
| Évaluation externe | « Aucune évaluation indépendante n'a été réalisée. Toutes les preuves sont auto-produites, horodatées par commit et sommées ; `tools/check_claims.sh --full` permet à un tiers de les re-dériver. » |
| Certification IEC 62443 | « OASIS n'est pas certifié IEC 62443. Le dossier présente une correspondance exigence par exigence, en capacité SL2 visée, avec les exigences non applicables justifiées et les exigences non couvertes nommées. » |
| Automate du commerce | « Non testé sur automate du commerce avant ce dossier. Le dispositif de référence est `oasis_test_plc`, un simulateur sans cycle de scan ; le premier équipement commercial visé (onduleur SMA) n'a reçu aucune écriture, son serveur Modbus étant désactivé. » |
| Test d'intrusion tiers | « Aucun test d'intrusion par un tiers. Les essais d'attaque sont ceux du fabricant du logiciel, avec contrôles négatifs, plus une campagne de fuzzing. » |
| Détection matérielle | « Aucun détecteur d'intrusion matérielle. OASIS fournit l'emplacement de journal, pas la détection ; BOOTSEL et SWD contournent clé et journal. » |
| Secure boot | « Le RP2040 n'offre ni secure boot ni stockage de clé protégé ; la clé est lisible en flash ; le bootloader n'est ni signé ni mis à jour. » |
| Rétention cinq ans | « Le mécanisme de conservation entre redémarrages est prouvé ; la rétention de cinq ans après chaque téléversement relève d'une procédure d'exploitation définie avec le fabricant de la machine. » |
| Horodatage absolu | « Les entrées sont ordonnées par identifiant de démarrage et compteur monotone ; l'horodatage absolu, s'il est exigé, est celui de l'hôte passerelle. » |
| Support et fin de vie | « Fournisseur unipersonnel : aucun engagement 24/7 ni durée de maintenance contractuelle ; le code source est accessible au client sous NDA et peut être mis sous séquestre indépendamment du fournisseur. » |

## 6. Paquet à envoyer à un prospect (avant tout devis)

Un dossier zippé, ou le dépôt public `oasis-proofs` (<https://github.com/SO2304/oasis-proofs>, publié le 11 octobre 2026), contenant uniquement :

- `evidence/real/2026-10-10/twohost-campaign-3/REPORT.md` et son `SHA256SUMS` (la campagne de référence, 98/98) ;
- `evidence/real/2026-10-09/sma/REPORT.md` (le seul équipement commercial, avec ses limites) ;
- `evidence/silicon/2026-10-07/modbus/REPORT.md` (brownfield RTU, 0 octet sur le bus) ;
- `evidence/pilot/2026-10-09/README.md` (72 cas, trois fois) ;
- `evidence/supply-chain/2026-10-07/REPORT.md` et les neuf SBOM ;
- `docs/specs/MODBUS_GATEWAY_SPEC.md`, `docs/specs/MODBUS_TCP_SPEC.md`, `docs/PILOT_INSTALL.md` ;
- `docs/compliance/MACHINERY_REGULATION_2023_1230.md` ;
- ce fichier, en guise de table des matières du futur dossier ;
- une page de garde avec le hash racine et la commande de reproduction.

Ne jamais y mettre : clés, graines, adresses réseau réelles, numéros de série, photos d'installation.

## 7. Trois corrections à faire dans le dépôt avant de montrer le dossier

1. `docs/compliance/IEC_62443_4_2.md` dit encore « aucun module de journal » pour CR 2.8/2.9/2.10/3.9 : à réaligner
   sur le journal partie I et le journal des changements.
2. `docs/compliance/MACHINERY_REGULATION_2023_1230.md` §4 cite 1.2.1 f) avec des ellipses : recopier le texte intégral
   FR et EN depuis EUR-Lex (page inaccessible depuis la session, à faire depuis un poste non filtré).
3. Écrire `SECURITY.md` (divulgation, délais de réponse) : demandé par les questionnaires acheteurs et par GitHub
   Secure Open Source Fund.

## 8. Déroulé d'un dossier chez un client (dix jours ouvrés)

| Jour | Étape | Livrable |
|---|---|---|
| 0 | Journée d'inventaire, par écrit et sur site : protocole réel, carte des registres, chemins vers l'actionneur, politique de rétention souhaitée | `PLAN.md` approuvé par le client avant toute écriture |
| 1–2 | Installation de la passerelle en coupure, clés nées sur le poste opérateur, enrôlement | configs (clés publiques seulement) |
| 3–5 | Campagne : ordres légitimes, douze attaques, redémarrages, rejeu, témoin externe | `campaign.log`, journaux, `SHA256SUMS` |
| 6–8 | Rédaction clause par clause, résumé une page, limites | dossier v1 |
| 9 | Relecture écrite avec le client, corrections | dossier v2 |
| 10 | Remise, hash racine, facture du solde | dossier signé |
