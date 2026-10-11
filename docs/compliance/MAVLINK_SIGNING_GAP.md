# Limites de la signature MAVLink 2 — point par point, avec la réponse OASIS

**Rédigé le 2026-10-07.** Ce document est la base du coin d'entrée côté drones
(`POSITIONING_GAPS.md` **B1**). Chaque limite porte son origine :

- **[SPEC]** — spécification officielle MAVLink
- **[CODE]** — implémentation de référence `mavlink/c_library_v2`, branche `master`
- **[PX4]** / **[ARDU]** — **choix d'implémentation** de PX4 ou d'ArduPilot

⚠️ Projets vivants : pages et code consultés le **2026-10-07**, branches `master`/`main`.
Aucun SHA de commit n'a pu être capturé (`gh` absent de l'environnement).

> **Ce document ne revendique aucune fonction de sûreté.** Voir
> [`IEC_TS_63074.md`](IEC_TS_63074.md).
>
> **Défensif uniquement.** Aucun test n'a été conduit contre un véhicule, un autopilote ou un
> réseau tiers. Les limites décrites sont **documentées par les projets eux-mêmes**.

---

## 1. Ce que fait la signature MAVLink 2 — [SPEC] + [CODE]

| Élément | Valeur |
|---|---|
| Bloc de signature | **13 octets**, aux positions `(n+12)` à `(n+24)` de la trame v2 |
| Trame v2 signée maximale | **280 octets** |
| Drapeau | `MAVLINK_IFLAG_SIGNED = 0x01` |
| Identifiant de lien | **8 bits** |
| Horodatage | **48 bits**, en unités de **10 µs** depuis le **1er janvier 2015 GMT** (décalage Unix 1 420 070 400) |
| **Signature** | **48 bits (6 octets)** |
| Clé secrète | **32 octets**, « must not be exposed via any publicly accessible communication protocol » |

Construction [SPEC] :

```
signature = sha256_48(secret_key + header + payload + CRC + link-ID + timestamp)
```

**Correction d'une formulation répandue** — et de `POSITIONING_GAPS.md` B1, qui écrivait
« HMAC-SHA-256 tronqué à 48 bits » : ce **n'est pas un HMAC**. C'est un SHA-256 sur
`secret_key ‖ données`, tronqué à 48 bits : une construction **à clé en préfixe**. Le code de
référence le confirme sans ambiguïté — `sha256_update` absorbe successivement `secret_key` (32 o),
`header`, `packet`, `crc` (2 o), puis les 7 premiers octets de la signature (link ID +
horodatage), avant `mavlink_sha256_final_48()`
([`mavlink_helpers.h`](https://raw.githubusercontent.com/mavlink/c_library_v2/master/mavlink_helpers.h)).

⚠️ **Ce que je n'affirme pas :** je n'ai trouvé **aucun audit cryptographique externe public** de
cette construction, et je n'en revendique aucune attaque. Une construction à clé en préfixe est
*connue pour être moins robuste qu'un HMAC* en général ; dans ce cadre précis (trame de longueur
bornée, troncature à 48 bits), je n'ai pas d'attaque à citer. **Le point à retenir devant un
acheteur est factuel : 48 bits de signature, et ce n'est pas un HMAC.** Rien de plus.

---

## 2. Les neuf limites, et la réponse OASIS

État de la réponse OASIS : **prouvé** (silicium ou test) · **conçu** (spécifié, non implémenté) ·
**absent**.

### L1 — Clé **partagée par lien**, aucune identité de nœud — [SPEC]

La spécification est explicite : secret symétrique, « **only one key per link** ». Aucune identité
par nœud, **aucune non-répudiation**, aucun appairage cryptographique. Un nœud compromis détient
la clé de tous ses interlocuteurs sur ce lien et peut usurper n'importe quel émetteur.

> ⚠️ L'arithmétique de flotte (1 clé partagée contre N clés par nœud) est une **inférence** :
> aucune source officielle ne la traite.

**Réponse OASIS — prouvé.** Clé Ed25519 **par nœud**, générée sur la carte, jamais distribuée.
Chaque relais vérifie la signature de l'**origine** avec la clé propre de celle-ci. Un nœud
capturé ne peut pas forger un autre émetteur : `v10_spoofed_origin_fp_rejected`, et sur silicium
0/150 inversions de bit acceptées (`evidence/silicon/2026-10-06/REPORT_MESH_V0B.md`). La
non-répudiation cryptographique existe par construction — mais **rien n'est conservé**, donc elle
n'est pas démontrable après coup (`POSITIONING_GAPS.md` **C5**).

### L2 — **Désactivée par défaut** — [PX4], [ARDU]

PX4 l'écrit noir sur blanc : « **Signing is disabled by default** » et « **By default, all MAVLink
messages are unauthenticated and unencrypted** »
([docs.px4.io](https://docs.px4.io/main/en/mavlink/message_signing)). Chez ArduPilot,
l'activation se fait par **présence d'une clé** — déduit du code
([`GCS_Signing.cpp`](https://github.com/ArduPilot/ardupilot/blob/master/libraries/GCS_MAVLink/GCS_Signing.cpp)) ;
⚠️ le wiki ne le dit pas explicitement : **gap**.

**Réponse OASIS — prouvé.** Il n'existe pas de mode non signé : v0B rejette v8, v9 et v0A, et les
routeurs sont **stricts par défaut**. 150/150 trames tracées, **0 acceptée** en mode strict
(`evidence/silicon/2026-10-06/followup/`).

### L3 — **Déclassement vers MAVLink 1** possible, sans protection protocolaire — [SPEC], [ARDU]

La spécification admet elle-même la limite : « a system cannot use a single channel to connect to
signed MAVLink 2 systems, unsigned MAVLink 2 systems, and/or MAVLink 1 components ». Il n'existe
**aucune protection protocolaire** : seule une politique locale (`accept_unsigned_callback`)
protège, et **la spécification suggère elle-même** la politique « accepter jusqu'au premier paquet
signé » — exploitable au démarrage. Chez ArduPilot, l'USB (`MAVLINK_COMM_0`) est accepté non signé
**inconditionnellement**, et laisser un port en MAVLink 1 neutralise la protection.

**Réponse OASIS — prouvé.** Le refus du déclassement est **dans le protocole**, pas dans une
politique : un routeur v0B refuse les versions antérieures par défaut. C'était d'ailleurs un
défaut d'OASIS lui-même, corrigé : v0A ne signait que 22 octets d'en-tête, si bien qu'un échange
de charge utile conservait une signature valide — **12/50 acceptées sur silicium**. v0B signe
`SHA-256(charge)` et passe à 0/150.

### L4 — Fenêtre de rejeu : **pas de tolérance au réordonnancement** — [SPEC]

**Correction importante de `POSITIONING_GAPS.md` B1**, qui parlait d'une « fenêtre de rejeu d'une
minute ». La règle réelle est la **monotonie stricte par flux `(SystemID, ComponentID, LinkID)`**.
Les « 6 millions d'unités » (une minute) ne s'appliquent **qu'à l'admission d'un flux inconnu**.
Il n'y a **aucune fenêtre glissante tolérant le réordonnancement** — contrairement à ce que
l'expression « fenêtre de rejeu » suggère. Sur un lien radio qui réordonne, un paquet en retard
est donc **définitivement perdu**.

⚠️ Un nom de constante lu dans le rendu de `mavlink_helpers.h`
(`MAVLINK_SIGNING_TIMESTAMP_LIMIT`) **n'a pas pu être confirmé** et ne doit pas être cité. La
valeur de 60 s est, elle, confirmée par la spécification.

**Réponse OASIS — prouvé, et c'est un avantage net.** Compteur monotone **plus** fenêtre
glissante de **128 bits** tolérant **127 positions** de réordonnancement : un paquet en retard
est accepté une fois et une seule. Testé : `v0b` réordonnancement accepté une seule fois, rejeu
immédiat refusé.

### L5 — Horodatage dérivable du GPS : rejeu après usurpation — [ARDU], ticket #13860

Vecteur **confirmé et documenté**. ArduPilot `update_signing_timestamp()` dérive l'horodatage de
l'UTC GPS et le persiste toutes les 30 s « unless forced by a GPS update ». Réponse de tridge
dans le ticket : « We force the 64 bit timestamp to only ever go forward » — l'attaque exige donc
un **effacement préalable du stockage** (FRAM `hal.storage`, pas la carte microSD), ce que le
rapporteur a concédé.

**Fermé en 4 jours (22 → 26 mars 2020) sans correctif protocolaire** : la seule issue a été
documentaire ([ArduPilot #13860](https://github.com/ArduPilot/ardupilot/issues/13860)).

Contraste utile : **PX4 ne couple pas l'horodatage au GPS** (écriture sur `SETUP_SIGNING` et
arrêt propre seulement), donc il est immunisé **à ce vecteur** — mais sa documentation reconnaît
que l'horodatage sur disque « will typically remain at the value from the last key provisioning on
reboot ».

**Réponse OASIS — prouvé, et c'est la différence la plus vendable.** OASIS **n'a pas d'horloge**
et ne dépend d'**aucune source de temps externe** : la fraîcheur repose sur le `boot_id` de
l'actionneur et un compteur persisté en flash. Un ordre d'un démarrage antérieur est refusé après
redémarrage ; un rejeu **octet pour octet** est refusé **après une vraie coupure de courant**
(`evidence/silicon/2026-10-06/followup/`). Il n'y a pas de GPS à leurrer.
⚠️ Le revers est `POSITIONING_GAPS.md` **C4** : le commandant doit connaître le `boot_id` et le
compteur de l'actionneur. **Non spécifié** — c'est le prix de l'absence d'horloge.

### L6 — Messages **exemptés** de signature, et pas les mêmes selon l'autopilote — [SPEC], [PX4], [ARDU]

| Implémentation | Messages acceptés non signés |
|---|---|
| **Spécification** | **1** suggéré : `RADIO_STATUS` |
| **PX4** | **4** : `HEARTBEAT` (0), `RADIO_STATUS` (109), `ADSB_VEHICLE` (246), `COLLISION` (247) — avec un avertissement explicite sur l'usurpation possible |
| **ArduPilot** | **2** (`RADIO`, `RADIO_STATUS`) **+ tout le canal 0** (USB) |

**Il n'y a donc pas d'interopérabilité du modèle de menace entre deux autopilotes « conformes ».**
`COLLISION` et `ADSB_VEHICLE` non signés sont particulièrement notables : ce sont des entrées qui
influencent l'évitement.

**Réponse OASIS — prouvé.** Aucune exemption : toute trame v0B est signée, sans exception. ⚠️ Deux
champs sont **volontairement non signés** parce qu'ils changent à chaque saut — `ttl` et `hops` —
et ils sont **contrôlés en plage** seulement. C'est documenté comme tel dans `docs/MESH_V0B_SPEC.md`.

### L7 — **Aucune rotation ni révocation** — [PX4], [ARDU]

PX4 : « **There is no automatic key rotation** » ; la récupération est « **only physical** ».
ArduPilot active une nouvelle clé « **immediately on all links** » : aucune période de
recouvrement. Les deux **refusent un changement de clé véhicule armé** — donc **aucune révocation
en vol**.

**Réponse OASIS — prouvé.** Révocation signée par l'opérateur (ORV1), époque strictement
croissante, permanente (sur-ensemble), **persistée avant application**, **appliquée par chaque
relais** et propagée une fois par époque. Sur silicium : propagée A→B→C, origine révoquée
abandonnée **au premier saut avant toute vérification de signature**, ancienne liste refusée
(`Rollback`), liste restaurée depuis la flash après une vraie coupure de courant
(`evidence/silicon/2026-10-06/ef/REPORT.md`). Possibilité k-sur-n via `oasis-operator-key`.
**Révoquer un nœud ne renouvelle aucune autre clé.**
⚠️ Un nœud révoqué peut encore **relayer** le trafic des autres ; le rattrapage et le k-sur-n sont
**PC uniquement**. Pas de rotation de clé de nœud (`POSITIONING_GAPS.md` **C6**).

### L8 — Ce que la signature **ne couvre pas** : l'autorisation par commande — [PX4]

La source officielle la plus explicite est PX4 *MAVLink Security Hardening* : la signature
**authentifie** l'émetteur mais **ne restreint pas quelles commandes** un émetteur authentifié
peut envoyer. Un opérateur légitime et un opérateur légitime compromis sont indiscernables.

**Réponse OASIS — prouvé.** C'est le cœur du positionnement. Porte d'actionnement pure à
**9 conditions ordonnées** (7 à la rédaction de ce fichier ; les parties G et H ont ajouté le verrou d'arrêt et la vivacité de la supervision) : trame v0B valide, origine **habilitée pour cet actionneur**, non
révoquée, non expirée dans l'horloge de l'actionneur (`boot_id`), verrou d'état des capteurs,
**dans les limites physiques** (avec garde NaN), `cmd_seq` strictement plus récent. 15 tests
`act_*`, 3 harnais Kani vérifiés, et sur silicium un ordre non habilité, expiré, rejoué, à
capteur perdu, à 1 000 N et à NaN sont tous refusés (`evidence/silicon/2026-10-06/ef/REPORT.md`).
Sur un équipement Modbus réel : **4 décisions « agir » = 4 trames émises = 4 écritures sur le
bus**, octet pour octet, tandis que **12 refus de la porte** (ses six raisons), 1 ordre malformé
et 3 injections brutes **n'ont mis aucun octet** sur le bus
(`evidence/silicon/2026-10-07/modbus/REPORT.md`).

### L9 — **La spécification ne contient aucun modèle de menace** — [SPEC]

Asymétrie à signaler : la spécification MAVLink **n'a ni section « modèle de menace » ni section
« limites »**. Tout l'énoncé des limites vient de **PX4** et, brièvement, du wiki ArduPilot. Un
intégrateur qui ne lit que la spécification ne voit aucune de ces neuf limites.

---

## 3. Tableau de synthèse

| # | Limite MAVLink 2 | Origine | Réponse OASIS | État |
|---|---|---|---|---|
| L1 | Clé partagée par lien, pas d'identité de nœud, pas de non-répudiation | SPEC | Ed25519 par nœud, vérifié à chaque saut | **prouvé** |
| L2 | Désactivée par défaut | PX4, ARDU | Pas de mode non signé ; strict par défaut | **prouvé** |
| L3 | Déclassement vers MAVLink 1, sans protection protocolaire | SPEC, ARDU | Refus dans le protocole | **prouvé** |
| L4 | Monotonie stricte, **aucune** tolérance au réordonnancement | SPEC | Fenêtre glissante 128 bits, 127 positions | **prouvé** |
| L5 | Horodatage dérivable du GPS → rejeu (#13860) | ARDU | Pas d'horloge : `boot_id` + compteur persisté | **prouvé** |
| L6 | 1 à 4 messages exemptés, variables selon l'autopilote | SPEC, PX4, ARDU | Aucune exemption (`ttl`/`hops` en plage) | **prouvé** |
| L7 | Aucune rotation, aucune révocation, rien en vol | PX4, ARDU | ORV1 signée, époque, appliquée par relais, persistée | **prouvé** |
| L8 | N'autorise pas **par commande** | PX4 | Porte à 9 conditions, atteinte depuis un `V2_EXTENSION` (B1) | **prouvé en logiciel**, rien sur PX4 SITL |
| L9 | Pas de modèle de menace dans la spécification | SPEC | `docs/specs/` : modèle de menace par spécification | **prouvé** |

**Et le manque qui annule la démonstration commerciale :**

| B1 | **Aucune intégration MAVLink n'est testée** | — | PX4 SITL est déjà utilisé dans le dépôt (mission 4 points, tenue d'altitude à ±6 cm) ; transporter un ordre OASIS signé dans un message MAVLink et le faire vérifier par la porte avant exécution reste à faire | **absent** |

C'est la seule ligne de ce tableau qui compte pour une vente côté drones : **neuf réponses
prouvées sur un banc filaire ne valent rien sans la dixième démonstration, sur PX4.** Le travail
est cadré en phase 3 du prompt.

## 4. Ce que ce document ne permet pas de dire

- **« MAVLink est cassé » : non.** Les neuf limites sont des **choix de conception documentés**,
  pour un protocole conçu en 2009 pour des liaisons de télémétrie. Le dire autrement ferait perdre
  la crédibilité devant un intégrateur PX4, qui connaît ces limites mieux que nous.
- **« OASIS remplace la signature MAVLink » : non.** OASIS est une couche **au-dessus**, et PX4
  reste responsable du vol. La formule juste est : PX4 garantit le firmware (secure boot) et le
  vol, OASIS garantit l'**autorité de l'ordre**.
- **L'avantage réglementaire est faible côté drone civil européen.** L'EASA a **retiré** les
  exigences de cybersécurité de SORA 2.5 (voir `POSITIONING_GAPS.md` A7 et
  `research_notes/.../drones_nis2_export.md`) : ici, la conformité ne fera pas vendre. L'argument
  est technique, pas réglementaire.

## 5. Limites de ce document

- **Vérifié à la source** : 11 sources primaires, toutes consultées le 2026-10-07 — pages
  mavlink.io *Message Signing*, *Packet Serialization*, *MAVLink Versions*, *C Message Signing* ;
  `mavlink_helpers.h` (`mavlink_sign_packet()` récupéré verbatim) ; PX4 *MAVLink Message Signing*
  et *MAVLink Security Hardening*, plus la source markdown du dépôt en contre-lecture ; wiki
  ArduPilot et `GCS_Signing.cpp` ; **ArduPilot #13860** (corps + les 14 commentaires via l'API
  GitHub).
- ⚠️ **Contradiction non résolue dans la documentation PX4** : le rendu HTML affirme que
  `SETUP_SIGNING` n'est accepté **que sur USB** ; la source markdown du même document dit « PX4
  accepts this on any link, but once signing is active, key changes must arrive as signed
  messages ». À départager par lecture de `mavlink_receiver.cpp`.
- **Non vérifié / à ne pas citer** : `MAVLINK_SIGNING_TIMESTAMP_LIMIT` (orthographe non
  confirmée) ; **CVE-2026-1579** (absence d'authentification par défaut PX4 + shell via
  `SERIAL_CONTROL`), vue seulement en bribe de recherche, fiche non récupérée ; l'activation par
  présence de clé chez ArduPilot (déduite du code, non documentée) ; aucun ticket PX4 équivalent à
  #13860 n'a été trouvé (seulement des fils de forum, écartés comme non primaires).
- Notes de recherche brutes, avec les 15 lignes de synthèse classées par origine :
  `research_notes/Conformité réglementaire OASIS phase 0/mavlink_signing.md`.
