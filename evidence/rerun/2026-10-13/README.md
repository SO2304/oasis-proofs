# Ce qu'OASIS prouve : refait le 2026-10-13, sur ce PC

**Arbre `53a64d7`** (branche `max-tech-2026-10-09`), aucune modification locale. Le code n'a pas été
touché pour ce passage : on refait les tests, on n'y change rien.

Deux plateformes, deux toolchains :

| | Windows 11 (`windows/`) | WSL2 Ubuntu 26.04 (`wsl/`) |
|---|---|---|
| Rust | 1.95.0 | 1.99.0 |
| Machine | même portable, AMD Ryzen 3 PRO 2300U, 4 fils | idem, 3,3 Go alloués à WSL |
| Ce qui a tourné | suite du workspace, audit des dépendances | suite du workspace, suite LoRa complète, binaires livrés, campagne pilote, balayage Kani |

Les cartes RP2040, le second PC et l'onduleur ne sont **pas branchés** : les campagnes qui en
dépendent ne sont pas refaites. Leurs preuves archivées sont **vérifiées octet pour octet** (§4).

## 1. Les essentiels, preuve par preuve

| Ce qu'OASIS affirme | Refait aujourd'hui (tests, Linux et Windows) | Preuve formelle (Kani, refaite aujourd'hui) | Sur silicium (archivé, RP2040) |
|---|---|---|---|
| **La porte de décision** n'agit que si les neuf conditions sont réunies ; un arrêt n'en demande que trois | `actuation` : **40 / 40** | **15 / 15**, plus 4 / 4 sur la vue d'horloge `TimeView` | `silicon/2026-10-06/ef` : la LED ne bouge que sur `Act` ; ordres non autorisés, expirés, rejoués, R14 instable, hors limites et NaN refusés. `silicon/2026-10-08/hardening` et `jk` : trois arrêts acceptés là où un ordre aurait été refusé |
| **L'enveloppe signée v0B** lie l'origine, le compteur, le réseau et la charge utile | `mesh` v0B : **13 / 13**, dont `v0b_bitflip_each_signed_byte_rejected` | **7 / 7** : parseurs totaux ; préimage liée au condensé, au compteur et au réseau ; séparation de domaine | `silicon/2026-10-06/REPORT_MESH_V0B.md` : **0 sur 147** inversions de bit acceptées (v0A : 12 sur 50) ; `followup` : 150 / 150 tracées, rejeu octet pour octet refusé après une coupure de courant |
| **La cryptographie** est conforme aux vecteurs officiels | voir §2 | — | `silicon/2026-10-06/REPORT.md` : ChaCha20-Poly1305 (RFC 8439) et X25519 (RFC 7748) octet pour octet, Ed25519 sur vecteur fixe, **9 / 9** sur trois cartes |
| **Le journal** est chaîné et garde chaque décision, refus compris | `journal` : **18 / 18** ; campagne pilote C8, C9 | **6 / 6**, dont 3 avec bouchon déclaré (§3) | `silicon/2026-10-08/hardening` : intact sur 10 entrées dont 4 refus ; un bit inversé → sortie 1 ; une vraie coupure de courant (S8) |
| **La révocation** signée est appliquée au premier saut | `mesh_revocation` : **14 / 14** | **3 / 3**, plus 3 / 3 sur le bail d'émission `tx_lease` | `silicon/2026-10-06/ef` : propagée A→B→C, origine révoquée rejetée avant sa signature, liste restaurée après coupure |
| **Les messages d'autorité hybrides** (Ed25519 + ML-DSA-44) refusent tout déclassement | `authority` : **16 / 16** ; `fragment` : **11 / 11** | **4 / 4** et **3 / 3**, dont 1 avec bouchon déclaré | `silicon/2026-10-06/pq` : révocation de 14 fragments appliquée à chaque saut ; altération refusée ; déclassement refusé ; politique restaurée après coupure |
| **L'enrôlement et le transfert de propriété** | `enrollment` 6, `ownership` 5, `identity` 5 : **16 / 16** | **4 / 4** et **3 / 3** | `silicon/2026-10-06/enroll` : nœuds non enrôlés refusés (14 / 14) ; transfert entre propriétaires ; coupure |
| **La mise à jour signée** | `firmware` : **3 / 3** | **3 / 3** | `silicon/2026-10-06/fwupdate` : image altérée, retour arrière et signataires non autorisés refusés ; retour automatique par le chien de garde ; deux coupures, pendant l'envoi et pendant l'échange |
| **La passerelle Modbus** n'écrit que sur `Act` | `modbus_gateway` 17, `modbus_tcp` 7, `modbus_read` 9, `mbtcp` 22 : **55 / 55** ; **campagne pilote 72 / 72** sur les binaires livrés, compilés pour Linux | **4 / 4**, **2 / 2** et **5 / 5** (RTU, TCP, lectures) | `silicon/2026-10-07/modbus` : **4 décisions `Act` = 4 trames = 4 écritures** sur l'appareil (`rmodbus`, sans code OASIS) ; aucune des attaques listées n'a produit d'écriture |
| **Le pré-filtre v0C** protège le processeur d'un relais | `mesh::prefilter` : **16 / 16** | **3 / 3** | `silicon/2026-10-07/prefilter` : une trame forgée coûte **0,70 ms au lieu de 179,4 ms** ; sous inondation, 60 / 60 messages légitimes livrés contre 39 / 60 en v0B |
| **Les ordres à deux signatures** (k sur n) | `quorum` : **9 / 9** | **5 / 5** | — (rien sur silicium) |
| **La confidentialité de bout en bout** `OSE1` | `sealed` : **8 / 8** | **5 / 5** | — (rien sur silicium) |

**Dans tout le workspace : 738 tests passent, 0 échec, 2 ignorés, sous Linux comme sous Windows**
(`wsl/workspace_tests.txt`, `windows/workspace_tests.txt`, 42 suites chacun).

## 2. La cryptographie, vecteur par vecteur

Tests refaits aujourd'hui sous Linux (`wsl/workspace_tests.txt`), tous `ok` :

| Test | Ce qu'il vérifie |
|---|---|
| `spore_crypto::tests::rfc_8439_test_vector_sanity` | ChaCha20-Poly1305 contre RFC 8439 §2.8.2 : les 16 premiers octets du chiffré **et** le tag |
| `mesh::prefilter::tests::hmac_sha256_rfc4231_case2` | HMAC-SHA256 contre RFC 4231, cas 2 |
| `authority::tests::pq_acvp_mldsa44_sigver_official_vectors` | ML-DSA-44 (FIPS 204) : 15 vecteurs **officiels** NIST ACVP (3 valides, 12 altérés), sur **deux** implémentations indépendantes (libcrux, embarquée, et RustCrypto `ml-dsa`, oracle) |
| `authority::tests::pq_mldsa44_matches_libcrux_byte_for_byte` | génération de clé et signature identiques octet pour octet entre les deux implémentations |
| `authority::tests::pq_every_single_bit_flip_refused` | 20 072 inversions d'un seul bit, **0 acceptée** |
| `mesh::tests::v0b_bitflip_each_signed_byte_rejected` | chaque octet signé de l'enveloppe v0B, altéré, est refusé |
| `mesh_revocation::tests::rev_tampered_byte_rejected`, `sealed::tests::tamper_and_junk_are_refused`, `spore_crypto::tests::tampered_*` | altération de la révocation, du chiffré scellé, de l'AAD, du chiffré et du tag : refusée |
| `mavlink_min::tests::crc_known_vector` | CRC MAVLink contre un vecteur connu |

**Dépendances** (`windows/cargo_audit.txt`, base d'avis de sécurité du 2026-10-13) :
- **0 vulnérabilité** dans les 150 dépendances du workspace et les 108 de la crate LoRa ;
- un seul avertissement « non maintenu », déjà autorisé : `proc-macro-error2`, RUSTSEC-2026-0173,
  utilisé à la compilation seulement.

**Limite :** sur ce PC, X25519 et Ed25519 ne sont pas testés contre des vecteurs RFC numérotés. Ils
reposent sur les suites de tests de leurs bibliothèques (`x25519-dalek`, `ed25519-compact`). Sur
silicium, X25519 l'est (RFC 7748 §6.1) ; Ed25519 l'est contre un vecteur fixe et une altération,
**pas** contre un vecteur numéroté de la RFC 8032, comme le firmware le dit lui-même.

## 3. Preuves formelles (Kani) — refaites aujourd'hui

Le balayage est archivé dans `../../kani/2026-10-13/sweep/` :
- **Méthode :** **tous les harnais non lourds de l'arbre, un par un**, sous WSL, avec Kani 0.68.0, de
  18:38 à 19:21 UTC.
- **Résultat :** **189 vérifiés sur 189, 0 réfuté, 0 indéterminé.** Le balayage du 2026-10-08 avait
  de même vérifié les 175 harnais non lourds de l'arbre d'alors (182 au total). Les 14 ajoutés depuis passent
  aujourd'hui dans le même balayage : 2 de Modbus TCP, 5 des lectures Modbus, 5 d'`OSE1`, 1 de la
  carte d'origine Modbus et 1 du journal des changements.
- **Les 7 harnais lourds** ne sont pas tentés, faute de mémoire (3,3 Go). Aucun n'est sur le chemin
  de sécurité : deux mécanismes bio-inspirés, quatre blocs arithmétiques du mesh et un hachage de
  topic. « 196 sur 196 » reste donc **faux**.

**83 harnais portent sur le chemin de sécurité :**

| Brique | Harnais vérifiés aujourd'hui |
|---|---:|
| Porte de décision (`actuation`) | 15 |
| Vue d'horloge du commandant (`TimeView`) | 4 |
| Enveloppe v0B | 7 |
| Pré-filtre v0C | 3 |
| Journal | 6 |
| Révocation, bail d'émission | 3 + 3 |
| Autorité hybride, fragmentation | 4 + 3 |
| Enrôlement, propriété | 4 + 3 |
| Mise à jour signée | 3 |
| Passerelle Modbus : RTU, TCP, lectures | 4 + 2 + 5 |
| Quorum | 5 |
| Confidentialité `OSE1` | 5 |
| Ordre transporté dans MAVLink | 4 |

**Les 106 autres** portent sur les mécanismes bio-inspirés, les primitives de type ROS 2 et des
propriétés du mesh hors chemin de sécurité (TTL, filtre de Bloom). Parmi eux, **28 harnais du mesh
(blocs AC à AJ) font de l'arithmétique sur des entiers symboliques sans appeler le code du mesh**.
Ils sont vérifiés, mais ne prouvent rien sur le protocole, et ce rapport ne les compte pas comme
tels.

**Ce que ces preuves ne disent pas :**
- **Le sens de la porte.** Les 15 harnais prouvent qu'un `Act` implique les neuf conditions et qu'un
  arrêt n'est jamais bloqué. Que les neuf conditions réunies donnent bien `Act` est montré par les
  tests, pas par Kani.
- **Les entrées de la porte.** Elles sont des booléens dans les harnais. Leur calcul à partir du
  registre, du routeur et des capteurs n'est pas prouvé formellement ; c'est la campagne pilote
  (§1) qui l'exerce.
- **Quatre harnais tournent avec un bouchon déclaré.** Dans les trois harnais du journal, `chain` et
  `genesis` sont remplacés, car un programme contenant SHA-256 ne tient pas en mémoire sous CBMC. Le
  quatrième est un harnais de la fragmentation.
- **Les contre-épreuves**, qui montrent qu'un harnais sait échouer, ne sont pas refaites ici. Celles
  qui existent sont archivées avec les campagnes Kani antérieures (par exemple
  `kani/2026-10-07/hardening/`, `kani/2026-10-08/jk/`).

## 4. Silicium : archivé, vérifié, pas refait

Les trois RP2040 ne sont pas branchées. Les 14 campagnes silicium du 4 au 9 octobre ont été
vérifiées aujourd'hui : **970 fichiers, chacun conforme à son manifeste**, contrôlé sur le contenu
committé (`git cat-file`).

| Dossier | Fichiers | État |
|---|---:|---|
| `silicon/2026-10-04` | 24 | conforme |
| `silicon/2026-10-06` | 31 | conforme |
| `silicon/2026-10-06/ef` | 82 | conforme |
| `silicon/2026-10-06/enroll` | 127 | conforme |
| `silicon/2026-10-06/followup` | 34 | conforme |
| `silicon/2026-10-06/fwupdate` | 51 | conforme |
| `silicon/2026-10-06/pq` | 85 | conforme |
| `silicon/2026-10-07/modbus` | 130 | conforme |
| `silicon/2026-10-07/prefilter` | 113 | conforme |
| `silicon/2026-10-08/b1-sitl` | 27 | conforme |
| `silicon/2026-10-08/hardening` | 129 | conforme |
| `silicon/2026-10-08/jk` | 99 | conforme |
| `silicon/2026-10-08/regress` | 23 | conforme |
| `silicon/2026-10-09/c4-reflash` | 15 | conforme |

Ce qui limite leur portée :
- **Pas rejouables sur ces cartes.** Deux cartes ont été reflashées le 2026-10-09 par la voie de mise
  à jour signée, avec un plancher de version relevé **irréversiblement**. Les campagnes plus
  anciennes restent valables, mais ne peuvent plus être rejouées à l'identique sur ces cartes.
- **Simulation, pas silicium.** `b1-sitl` est une simulation PX4, sans drone réel ; elle est
  rangée sous `silicon/` pour des raisons historiques.

## 5. Ce que ces preuves ne couvrent pas

- **Le matériel réel :** aucun automate du commerce. L'onduleur SMA n'a reçu aucune écriture. Aucune
  radio n'a émis.
- **La durée :** aucune exécution de plus de quelques minutes, ni pour la passerelle ni pour l'agent.
- **L'exploitation :** les redémarrages, les pannes et un réseau hostile ne sont couverts qu'à
  travers les cas listés.
- **Le matériel physique :** la preuve d'intervention sur le matériel (règlement 2023/1230, annexe
  III 1.1.9 ¶2, phrase 2) n'est pas faisable en logiciel. L'accès physique à un RP2040 (BOOTSEL,
  SWD) contourne tout.
- **La forme des preuves de la porte :** Kani prouve qu'un `Act` implique les neuf conditions. Le
  sens inverse, un ordre valide est bien accepté, est montré par les tests, pas prouvé
  formellement.
- **Le transport LoRa :** voir `../../bench/2026-10-13/lora_sim/`. Il passe **40 tests sur 41**, et
  le test en échec est enregistré tel quel.
- **Les débits et latences :** la latence C11 de la campagne pilote, **1 270 µs ± 24 %** (K=10 × 20,
  sous WSL), est mesurée sur la boucle locale contre un simulateur d'automate. C'est un plancher,
  pas une performance en usine.

## 6. Reproduire

```bash
cargo test --workspace --release                                    # 738 passent
(cd oasis-lora-transport && cargo test --release --features std)    # 40 sur 41
cargo build --release --workspace --bins && bash tools/pilot_campaign.sh <dossier>   # 72 / 72
cargo audit                                                         # 0 vulnérabilité
```

Sous WSL, `rerun_essentials.sh` (dans `wsl/`) fait tout cela depuis un clone dédié, avec deux
garde-fous :
- il **refuse de tourner** si le commit obtenu n'est pas celui demandé ;
- il **s'arrête** si la récupération du commit échoue.

Ces garde-fous ont été ajoutés après un premier passage qui avait testé, sans le dire, un commit plus
ancien (`f391ed7`). Ce passage a été jeté.

Les graines de test que la campagne pilote écrit sur disque (`*.seed`) et ses fichiers de bail
(`*.seq`, `*.txc`) ne sont **pas** archivés ici.
