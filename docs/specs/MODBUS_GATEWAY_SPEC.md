# Phase 1.4 — Passerelle Modbus RTU pour équipements existants (spec)

Prompt : `prompts/OASIS_VS_VERIDIFY.md`, phase 1, point 4 : un nœud OASIS placé
devant un équipement Modbus RTU, qui ne laisse passer que les écritures acceptées par
la porte d'actionnement. Sur une carte jouant l'équipement : une écriture de registre
forgée, rejouée ou non habilitée n'atteint jamais l'équipement.

## 0. Ce que dit la veille (rappel, sources publiques)

- C'est du **rattrapage** : DOME Sentry protège déjà Modbus TCP et RTU
  (`docs/competition/VERIDIFY.md` §1). Le seul écart possible est l'autorisation
  **par écriture** : qui écrit, sur quel registre, quelle valeur, dans quel état. Chez
  Veridify, c'est non documenté, ce qui ne veut pas dire absent.
- FrostyGoop : des « Modbus commands to ENCO controllers designed to control district
  heating substation modules or boiler plant processes » ([The Record](https://therecord.media/frostygoop-malware-ukraine-heat),
  2024-07-23). Plus de 600 immeubles ont été privés de chauffage pendant deux jours
  ([CyberScoop](https://cyberscoop.com/frostygoop-ics-malware-dragos-ukraine/),
  2024-07-23). Ces deux sources **ne disent pas** si le transport était TCP ou RTU.
  Cette spec traite RTU, comme le demande le prompt. La porte serait la même en TCP,
  seul le transport change (non fait).

## 1. Rôles et câblage

| Carte | Rôle | Firmware |
|---|---|---|
| **A** | **équipement Modbus existant** : esclave RTU, unité `0x11`, **aucun code OASIS**, aucune clé, aucune authentification | nouveau binaire autonome `modbus_device`, flashé en UF2 (A quitte le chargeur de 1.3) |
| **B** | **donneur d'ordres** : origine v0B des ordres d'écriture (PC → B par USB, puis B → C par le maillage) | `uart_mesh` v4, installé par la mise à jour signée de 1.3 |
| **C** | **passerelle** : vérifie, décide, puis seule à parler Modbus à A | `uart_mesh` v4, installé par la mise à jour signée de 1.3 |

- Bus Modbus : **UART1 à 19 200 bauds, 8E1** (réglage par défaut de la spec Modbus
  série), en **TTL 3,3 V directement**, sans transceiver RS-485.
- **Deux fils à ajouter :**
  - C.GP4 (UART1 TX) → A.GP5 (UART1 RX) : les requêtes ;
  - A.GP4 → C.GP5 : les réponses.
  - Masse commune requise. Elle l'est déjà si les liaisons A→B et B→C actuelles ont
    un fil GND (à confirmer).
- Le maillage reste sur UART0. Le bus de l'équipement est **physiquement séparé** :
  rien de ce qui arrive par le maillage n'est recopié sur UART1.
- Le fil A.GP0→B.GP1 reste en place. Le firmware de A maintient GP0 au niveau haut
  (repos UART), pour ne pas injecter de bruit chez B.
- Le donneur d'ordres devient B. A, devenu l'équipement, ne fait plus partie du
  maillage pendant cette phase. Le trajet est donc **B → C, un saut**. La
  vérification à chaque relais est déjà prouvée ailleurs (v0B).

## 2. L'équipement (A) : une bibliothèque Modbus existante, pas la nôtre

- **`rmodbus` 0.12.2** (alttch, Apache-2.0, 2025-09-29, ~225 000 téléchargements) :
  serveur (esclave) Modbus RTU/TCP. Je l'ai vérifié : il compile en `no_std` pour
  `thumbv6m-none-eabi` avec sa fonctionnalité `heapless`, et sa banque de registres
  est générique (64 registres de maintien ici).
- **Pourquoi elle :** l'équipement interprète les trames avec du code indépendant du
  nôtre. Une trame mal formée par la passerelle serait refusée par lui, ce qui prouve
  l'interopérabilité. `modbus-core` 0.2.0 (~18 000 téléchargements) était l'autre
  candidat ; il est moins diffusé.
- Comportement d'un équipement existant : il **exécute toute trame bien formée**
  (FC06, FC16, et le reste de ce que `rmodbus` sait faire), sans rien vérifier.
- **Vérité terrain :** A compte **chaque octet reçu sur UART1** et journalise chaque
  trame (hex, CRC bon ou mauvais, résultat `rmodbus`, registre et valeur écrits).
  « N'atteint jamais l'équipement » signifie **zéro octet reçu** par A.
- Commandes USB :
  - `@D` : compteurs et registres `0x10`–`0x12` ;
  - `@Z<hex>` : contrôle, voir G8 ;
  - `b` : BOOTSEL, pour reflasher.

## 3. L'ordre `OMB1` et la porte (C)

Contenu v0B, petit-boutiste comme `OAC1` :

```
"OMB1" | gateway_id u16 | cmd_seq u32 | boot_id u64 | deadline_ms u64
       | unit u8 | fc u8 | start u16 | count u8 | values[count] u16     (33 à 47 o)
```

- **Seuls FC06** (`count = 1`) **et FC16** (`1 ≤ count ≤ 8`) sont analysés. Tout
  autre code (bobines, diagnostic, lecture) est refusé dès l'analyse.
- **Aucun chemin de lecture** : la passerelle n'émet que des écritures décidées.

**La porte est celle de la partie F, sans modification.**
`actuation::actuation_decision` vérifie, dans l'ordre :
1. v0B vérifié ;
2. émetteur enrôlé avec `ACTUATE` ;
3. non révoqué ;
4. non expiré dans l'horloge de C (`boot_id`) ;
5. R14 ;
6. dans les limites ;
7. `cmd_seq` strictement plus récent.

Un `Actuator` distinct de celui de la LED tient le dernier `cmd_seq` exécuté pour le
bus Modbus. Pour un `OMB1`, **« dans les limites »** veut dire :
- `unit` est l'unité configurée (`0x11`) ;
- chaque registre écrit est dans la **carte de registres** de la passerelle ;
- chaque valeur est dans le `[min, max]` de son registre.

Carte compilée pour la démonstration :

| Registre | Sens | Plage |
|---|---|---|
| `0x0010` | consigne de chauffage, 0,1 °C | 50–300 |
| `0x0011` | pompe arrêt/marche | 0–1 |
| `0x0012` | ouverture de vanne, % | 0–100 |

Tout autre registre est refusé, et le journal indique la cause exacte
(`RegisterNotAllowed`, `ValueOutOfRange`, `WrongUnit`).

**Construction de la trame :**
- `oasis-rt/src/modbus_gateway.rs`, fonction pure. Elle rend
  `(Decision, Option<trame>)`, et la trame n'est construite **que** dans la branche
  `Act`, à partir de l'ordre décidé : unité, FC, registres, valeurs en gros-boutiste,
  CRC-16/MODBUS.
- Le firmware écrit cette trame telle quelle sur UART1. C'est **le seul appel
  d'écriture sur UART1** du firmware.

**Réponse :**
- attendue 100 ms au plus, puis journalisée : `ACK` (écho FC06, ou en-tête FC16),
  `EXCEPTION code`, ou `TIMEOUT` ;
- elle ne change pas la porte : le `cmd_seq` reste consommé, et un nouvel essai exige
  un nouvel ordre.

**CRC :** **`crc` 3.4.0** (mrhooray, MIT/Apache-2.0, ~300 M téléchargements, `no_std`),
algorithme `CRC_16_MODBUS` du catalogue. Ce n'est pas de la cryptographie : le CRC
détecte les erreurs de ligne, la sécurité vient de v0B et de la porte.

## 4. Commandes de test ajoutées à `uart_mesh` (v4)

- `@J<hex>` : envoie ces octets tels quels sur UART0, avec le tramage du maillage.
  Sert à injecter des trames forgées ou brutes chez C.
- `@K<pos>` : renvoie la dernière enveloppe v0B originée, avec l'octet `pos` modifié.
- C : `OMB1` traité si `BOARD_ID == "C"` ; statut `@G` (compteurs de la passerelle,
  dernières décisions).

L'outil PC `oasis_enroll` gagne :
- `mb-order` : construit un `OMB1` avec `boot_id` et `deadline` lus sur C, comme
  pour `OAC1` en partie F ;
- `forge-v0b` : une enveloppe qui prétend venir de B, signée par une autre clé.

## 5. Preuves prévues

**PC** (`modbus_gateway.rs` < 400 lignes) :
- analyse de `OMB1` : longueurs, FC, `count` ;
- règles de registres, refus un par un ;
- trame : CRC égal au contrôle catalogue (`0x4B37` sur `"123456789"`) ;
- chaque trame produite est relue par **`rmodbus`** (dépendance de dev), qui doit
  appliquer exactement les registres et valeurs de l'ordre ;
- bout en bout avec la porte : signatures, enrôlement, révocation, rejeu.

**Kani** (ce que la phase 2.2 demande pour la passerelle) :
- `proof_mb_no_frame_without_act` : une trame produite implique `Act`, donc les 7
  conditions ;
- `proof_mb_frame_matches_rules` : une trame produite ne porte que des registres de la
  carte, des valeurs dans leurs plages et l'unité configurée, et elle encode
  exactement l'ordre ;
- `proof_mb_parsers_total` : l'analyse de `OMB1` et des réponses ne panique jamais
  et n'accepte que des longueurs exactes.

**Silicium.** Pour chaque essai : journaux de A, B et C, et compteur d'octets de A
avant et après.

| # | Essai | Attendu chez C | Chez A |
|---|---|---|---|
| G0 | État initial | — | 0 octet |
| G1 | Ordre valide de B (consigne 215) | `Act`, `ACK` | 1 trame, registre `0x10` = 215 |
| G2a | Enveloppe forgée (empreinte de B, autre clé) | `DROP` signature | 0 octet |
| G2b | Enveloppe authentique, un octet de la charge modifié | `DROP` signature | 0 octet |
| G3a | Rejeu à l'octet près de G1 | `DROP` rejeu (fenêtre v0B) | 0 octet |
| G3b | Même `OMB1`, enveloppe neuve | `StaleOrReplayed` | 0 octet |
| G3c | Après redémarrage logiciel de C, l'ordre de G1 renvoyé | `Expired` (`boot_id`) | 0 octet |
| G4a | Registre `0x0020` hors carte | `OutOfLimits` / `RegisterNotAllowed` | 0 octet |
| G4b | Consigne 900 (90 °C) | `OutOfLimits` / `ValueOutOfRange` | 0 octet |
| G4c | FC05 (bobine) | refus à l'analyse | 0 octet |
| G4d | `ACTUATE` retiré à B (attestation o2, `enroll_seq` plus haut) | `NotAuthorized` | 0 octet |
| G5a | Trame Modbus brute bien formée, injectée sur la ligne B→C (façon FrostyGoop) | rejet du tramage | 0 octet |
| G5b | Même trame brute, en charge d'une enveloppe v0B **valide** de B | ignorée (pas un `OMB1`) | 0 octet |
| G6 | R14 dangereux (perte capteur simulée sur C) | `R14Unsafe` | 0 octet |
| G7 | Ordre expiré (échéance dépassée) | `Expired` | 0 octet |
| G8 | **Contrôle :** la trame de G5 donnée à A directement (`@Z`) | — | **exécutée** : l'équipement seul ne se défend pas |

- Après chaque refus, un ordre valide passe encore. Cela prouve que le refus ne vient
  pas d'un chemin cassé.
- **Bilan final :**
  - trames reçues par A = décisions `Act` de C = trames envoyées par C ;
  - octets reçus par A = somme des longueurs de ces trames.

**Pas de coupure de courant prévue.** G3c se fait par redémarrage logiciel. La
persistance de la fenêtre v0B à travers une coupure est déjà prouvée (phase v0B, T8).

## 6. Ce que je te demande

1. Les deux fils C.GP4→A.GP5 et A.GP4→C.GP5, et la confirmation que les cartes
   partagent la masse.
2. Rien d'autre :
   - A passe en BOOTSEL par sa commande `b` ;
   - B et C sont mis à jour par le chemin signé (v4, manifestes o2) ;
   - B reçoit `ACTUATE` par une attestation o2 chargée sur C, retirée en G4d.
   État final des permissions : celui d'aujourd'hui.

## 7. Limites dites

- **La passerelle ne protège que si elle est le seul chemin vers l'équipement.**
  Quiconque se branche sur le bus RTU de A écrit ce qu'il veut (G8 le montre).
  C'est la condition de déploiement, pas une propriété prouvée.
- **TTL 3,3 V, pas de RS-485**, un seul équipement, 19 200 bauds. Pas de Modbus TCP.
- **Seulement FC06 et FC16**, aucune lecture. La carte de registres est compilée, pas
  signée (une carte signée par le propriétaire serait l'étape suivante).
- « Seul appel d'écriture sur UART1 » est vérifié **à la relecture du code**, pas
  prouvé. Kani couvre la fonction pure qui décide et construit la trame.
- Une écriture envoyée sans réponse (`TIMEOUT`) reste consommée. Il n'y a pas de
  confirmation de bout en bout vers le donneur d'ordres.
- A n'est plus un nœud OASIS pendant la phase. Pour la suite, il sera reflashé avec
  le chargeur et `uart_mesh` (UF2 rembourré).
