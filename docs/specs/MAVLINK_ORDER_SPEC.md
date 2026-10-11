# Un ordre OASIS signé transporté dans MAVLink

**Écrit le 2026-10-08.** Ferme **B1** de [`partners/POSITIONING_GAPS.md`](../../partners/POSITIONING_GAPS.md).
Module : [`oasis-rt/src/mavlink_order.rs`](../../oasis-rt/src/mavlink_order.rs).

> **Ce document ne revendique aucune fonction de sûreté.** OASIS n'est pas une fonction de
> sûreté certifiée (ni PL au sens de l'ISO 13849-1, ni SIL au sens de l'IEC 62061).
> Voir [`../compliance/IEC_TS_63074.md`](../compliance/IEC_TS_63074.md).

> ⚠️ **B1 sert le segment S3 (drones), pas le segment S1 retenu**
> ([`partners/SEGMENT_COMPARISON.md`](../../partners/SEGMENT_COMPARISON.md) : machines
> mobiles autonomes). Il est traité parce que la phase 3 du prompt le demande et parce
> que le travail est en grande partie commun — la porte, le compteur, la révocation sont
> les mêmes. Il ne faut pas le lire comme un investissement dans S3.

---

## 1. Le problème, tel que les sources le posent

La signature MAVLink 2 est un **HMAC-SHA-256 tronqué à 48 bits** sur une clé **partagée**
par le lien. Les neuf limites sont établies à la source dans
[`../compliance/MAVLINK_SIGNING_GAP.md`](../compliance/MAVLINK_SIGNING_GAP.md) (L1 à L9).
Les deux qui comptent ici :

- elle atteste qu'une trame vient de **quelqu'un qui détient la clé du lien**, pas d'un
  opérateur nommé : tout nœud du lien peut signer au nom de n'importe qui ;
- l'horodatage n'est pas lié à un compteur que le véhicule **persiste**, donc la
  résistance au rejeu dépend de ce que l'implémentation garde en RAM.

**Ce module ne remplace pas la signature MAVLink.** Il transporte une enveloppe OASIS v0B
**à l'intérieur** d'un message MAVLink, de sorte que la décision d'armement dépend de la
signature OASIS, du compteur OASIS et de la liste de révocation OASIS — quoi que fasse le
lien. Les deux couches peuvent coexister : la signature de lien reste utile contre le
bruit et les injections triviales.

---

## 2. Le porteur : `V2_EXTENSION`, et pourquoi pas `TUNNEL`

Lu dans `mavlink/message_definitions/v1.0/common.xml` (branche `master`, téléchargé le
2026-10-08) :

| Message | id | Charge opaque | `CRC_EXTRA` | Verdict |
|---|---:|---:|---:|---|
| `TUNNEL` | 385 | **128 o** | 147 | ❌ une enveloppe v0B + `OAC1` fait 153 o |
| `V2_EXTENSION` | 248 | **249 o** | 8 | ✅ retenu, 94 o de marge |

**[calcul]** `MESH_V0B_HEADER_LEN + OAC1_LEN` = 99 + 54 = **153 o**, asserté par
`mo_v2_extension_roundtrip_and_sizes`. Une enveloppe v0C (pré-filtre de lien) ferait
177 o, ce qui tient aussi.

Disposition de la charge utile de `V2_EXTENSION`, dans l'ordre de câble (tri MAVLink par
taille de type décroissante) :

```
0..2    uint16   message_type
2..3    uint8    target_network
3..4    uint8    target_system
4..5    uint8    target_component
5..254  uint8[249]  payload        ← opaque
```

**`message_type = 0xFA0B`**, au-dessus de 32767. C'est la classe que `common.xml` décrit
lui-même : « *Message_types greater than 32767 are considered local experiments and should
not be checked in to any widely distributed codebase* ». Aucun `message_type` n'a été
enregistré auprès du projet MAVLink, donc c'est la seule valeur honnête. `0x0B` rappelle
v0B.

### Les `CRC_EXTRA`, et comment ils ont été obtenus

`CRC_EXTRA` n'est pas écrit dans `common.xml` : il se **calcule** à partir du nom du
message et de la signature de ses champs. Un chiffre faux donne une trame que PX4 rejette
silencieusement, donc il a été calculé par un script dont **le contrôle est les dix
valeurs déjà présentes** dans [`../../oasis-rt/src/mavlink_min.rs`](../../oasis-rt/src/mavlink_min.rs)
(issues de pymavlink). Le script a reproduit **10/10** — mais seulement après deux
corrections qu'il a lui-même mises en évidence :

1. les champs placés **après** le marqueur `<extensions/>` sont exclus du calcul
   (`COMMAND_ACK` sortait à 205 au lieu de 143) ;
2. le type `uint8_t_mavlink_version` s'écrit `uint8_t` dans la chaîne hachée
   (`HEARTBEAT` sortait à 239 au lieu de 50).

Au passage, le contrôle a aussi corrigé **une erreur de ma part** : j'avais inscrit 22
comme `CRC_EXTRA` de `PARAM_VALUE`, alors que 22 est son **identifiant de message** ; la
valeur est 220, ce que le dépôt disait déjà et ce que le script a calculé.

Les deux valeurs nouvelles — `V2_EXTENSION` = **8**, `TUNNEL` = **147** — viennent du même
script une fois les dix contrôles verts.

### Le préfixe de longueur n'est pas décoratif

Disposition du bloc opaque : `len u16 LE | enveloppe[len] | remplissage à zéro`.

C'est ce que la description du champ demande dans `common.xml` : « *The length must be
encoded in the payload as part of the message_type protocol […] This is required in order
to reconstruct zero-terminated payloads that are (or otherwise would be) trimmed by
MAVLink 2 empty-byte truncation* ». Un émetteur MAVLink 2 conforme **tronque les zéros de
fin**. `truncate_trailing_zeros` modélise un tel émetteur (il recalcule `len` et le CRC,
donc sa sortie est une trame valide) et `mo_survives_mavlink2_zero_truncation` réassemble
après lui, y compris quand l'enveloppe se termine elle-même par des zéros.

Le réassemblage par extension de zéros est sûr **par construction** : la signature v0B
couvre `SHA-256(charge utile)`, donc une enveloppe mal réassemblée échoue à la
vérification au lieu d'être exécutée. L'erreur est détectée, pas devinée.

---

## 3. La règle côté véhicule

Identique en forme à la passerelle Modbus (phase 1.4), pour la même raison : **la trame
n'est construite que dans la branche `Act`**.

```rust
pub fn arm_decision_ctx(...) -> (Decision, Option<ArmAction>, Option<Vec<u8>>)
```

1. `OrderClass::Stop` → refus immédiat (`OutOfLimits`). Voir §5.
2. Sinon, `actuation_decision_ctx` — les **neuf** conditions de la partie F, inchangées.
3. `Act` → `encode_command_long(..., 400, 0, param1, 0,…)`, c'est-à-dire
   `MAV_CMD_COMPONENT_ARM_DISARM` avec `param1 = 1` pour armer, `0` pour désarmer.
4. `Reject(_)` → `(decision, None, None)`. Rien n'est construit.

« Dans les limites », pour un ordre d'armement, se réduit à deux conditions
**configurées** : l'ordre nomme **ce** véhicule, et `force` vaut exactement `0.0` ou
`1.0`. Un `force` à `NaN` est refusé — `NaN` est faux face à tout — ce qui est
l'**inverse** de `clamp_command`, qui échoue en ouverture sur `NaN`
([`../AUTHORITY_HARDENING_SPEC.md`](../AUTHORITY_HARDENING_SPEC.md)).

Conséquence de `MAX_VALIDITY_MS = 10_000` : une échéance de plus de **10 s** est refusée.
Un ordre d'armement signé ne peut donc pas être préparé à l'avance et conservé.

---

## 4. Ce qui est prouvé, et par quoi

**7 tests** (`mo_*`), dont les quatre cas que B1 demande, chacun sur une **vraie**
enveloppe v0B et un **vrai** `MeshRouter` :

| Cas B1 | Ce qui l'arrête | Observé |
|---|---|---|
| **ordre valide** | — | `Act`, **une** trame `COMMAND_LONG`, commande 400, `param1 = 1.0`, relue par `parse_frame` |
| **forgé** (clé absente du registre) | la couche mesh, **avant la porte** | `Drop("unknown sender")`, aucune trame |
| **forgé** (ordre remplacé après signature) | la couche mesh | `Drop("bad mesh signature")`, aucune trame |
| **rejoué** (trame identique octet pour octet) | la couche mesh | `Drop("stale counter")` — la **fenêtre de compteur persistée**, pas le filtre de Bloom en RAM |
| **rejoué** (enveloppe neuve, `cmd_seq` déjà exécuté) | **la porte** | `Reject(StaleOrReplayed)`, aucune trame |
| **révoqué** | **la porte** (v0B vérifie) | `Reject(Revoked)`, aucune trame |

Deux barrières distinctes, et les tests **nomment laquelle a joué**. C'est volontaire :
dire « l'ordre forgé n'arme pas » sans dire où il s'arrête rend la preuve invérifiable.

Plus : les autres conditions de la porte une par une (non vérifié, non autorisé,
démarrage précédent, expiré, capteurs verrouillés, autre véhicule, `force` 0,5, `force`
NaN, classe `Stop`) — **aucune ne produit de trame** ; le désarmement par le même chemin ;
et l'octet de classe, qui est dans la zone signée, ne peut pas être promu de `Stop` à
`Act` sur le câble sans casser la signature.

**4 harnais Kani — 4 vérifiés, 0 réfuté, 0 indéterminé** (empreinte `e2e2045`,
`evidence/kani/2026-10-08/b1/`, Kani 0.68.0 / CBMC 6.11.0, sans stub) :

| Harnais | Énoncé |
|---|---|
| `proof_no_arm_frame_without_act` | **l'invariant de B1** : pour tout ordre, tout état d'actionneur et toute classe, une trame existe **si et seulement si** la décision est `Act` |
| `proof_arm_implies_every_condition` | `Act` implique les **neuf** conditions **et** que l'ordre nomme ce véhicule avec un `force` binaire : le porteur n'affaiblit pas la porte |
| `proof_stop_class_never_arms` | une classe `Stop` n'arme jamais, quoi que vaille le reste, et donne la même raison qu'un hors-limites — elle n'apprend rien à un attaquant |
| `proof_action_is_total_and_binary` | `action_of` est totale et binaire ; `NaN` tombe dans le refus |

Les harnais testent **l'existence** de la trame, pas ses octets : `encode_command_long`
alloue, et ce qui est pertinent pour la sûreté d'exécution est *s'il y a* une trame. Les
octets sont couverts par les tests, qui les relisent.

⚠️ **Erratum du premier passage.** Les deux harnais qui atteignent `encode_command_long`
sont d'abord revenus `VERIFICATION:- FAILED`. Les logs de ce passage **n'existent plus**
— le script d'exécution commence par `rm -rf` sur son dossier de sortie, donc le second
passage les a écrasés ; seule la **transcription console** est conservée
(`evidence/kani/2026-10-08/b1/run1/`). Ce n'était **pas un contre-exemple** : la vérification en
échec était une *unwinding assertion* dans la boucle de `crc_over` sur une trame de
43 octets, c'est-à-dire CBMC disant « je n'ai pas pu regarder assez loin ». Mon
`unwind(2)` était l'erreur ; `unwind(64)` la corrige (`e2e2045`). La distinction est
écrite ici parce qu'une trace disant FAILED reste au dépôt et qu'il ne faut pas qu'elle soit
lue comme une réfutation. Le script d'exécution, lui, **étiquette à tort** toute sortie
`FAILED` comme « counterexample » : c'est un défaut du script, noté dans
`run1/README.md`, et il est commun aux campagnes Kani précédentes du dépôt.

**Contrôle négatif** — trois mutations, trois preuves nommées, les trois doivent échouer :

| Mutation | Preuve qui doit échouer |
|---|---|
| le refus de la classe `Stop` est retiré | `proof_stop_class_never_arms` |
| une décision de refus construit quand même la trame d'armement | `proof_no_arm_frame_without_act` |
| `force >= 1.0` compte comme un armement, donc l'action n'est plus binaire | `proof_action_is_total_and_binary` |

---

## 5. Ce que ce module ne fait pas

- ✅ **Exécuté sur PX4 SITL le 2026-10-08**, 5 cas sur 5
  (`evidence/silicon/2026-10-08/b1-sitl/`). L'ordre valide arme
  (`Armed by external command`) ; forgé, altéré, rejoué et révoqué
  n'arment pas. ⚠️ Mais c'est de la **simulation** : SIH est un modèle de vol
  dans PX4, il n'y a ni Pixhawk, ni cellule, ni radio, et le dépôt n'a jamais
  volé. ⚠️ Et le véhicule **ne voit pas lui-même** l'état armé : il
  ne reçoit jamais le flux de PX4, cause **inconnue**, donc l'armement est établi
  par le journal de l'autopilote (§3 du rapport de campagne).
- ⚠️ **`OrderClass::Stop` est refusé par ce porteur.** Pour un véhicule en vol, la
  « direction sûre » n'est pas un désarmement — un désarmement en vol le fait tomber — et
  OASIS ne définit pas ce qu'elle est. Refuser est honnête ; inventer ici un atterrissage
  serait une revendication de sûreté que ce projet ne fait pas.
- **Aucun vol, aucun Pixhawk.** Le dépôt n'a jamais volé sur matériel réel
  (`CLAUDE.md`, ligne « Real hardware test (Pixhawk + quad) : none »).
- La trame `COMMAND_LONG` produite n'est **pas signée MAVLink**. Si le lien exige la
  signature de lien, l'appelant la pose avec `mavlink_min::sign_frame` ; les deux couches
  sont indépendantes.
- `split_frame` refuse les trames MAVLink **signées** en entrée (bit `incompat_flags`
  0x01) : les treize octets de signature ne sont pas traités ici.
- Le `message_type` 0xFA0B est une **expérience locale**, pas un identifiant enregistré.
  Deux déploiements OASIS indépendants sur le même lien se marcheraient dessus.

## 6. Sources

- `mavlink/message_definitions/v1.0/common.xml` et `minimal.xml`, branche `master`,
  téléchargés le 2026-10-08 — définitions de `V2_EXTENSION` (id 248), `TUNNEL` (id 385),
  `COMMAND_LONG` (id 76) et les dix messages de contrôle.
- Limites de la signature MAVLink 2 : [`../compliance/MAVLINK_SIGNING_GAP.md`](../compliance/MAVLINK_SIGNING_GAP.md),
  qui porte ses propres citations à la source.
- `CRC_EXTRA` : calculés, avec dix valeurs de contrôle reproduites. **Non lus dans une
  source normative** — l'algorithme est celui de pymavlink, et c'est la concordance avec
  les dix valeurs du dépôt qui tient lieu de vérification.
