# B1 sur PX4 SITL — un ordre OASIS signé, transporté par MAVLink, et l'armement

**2026-10-08, PX4 `v1.18.0-beta1-985-gdf387bdec2`, OASIS `b442b46` (branche `b1-px4-sitl`).**
Cinq cas, **5/5 conformes**. Détail de l'environnement : [`00_environnement.log`](00_environnement.log).

> **OASIS n'est pas une fonction de sûreté certifiée** (ni PL ISO 13849-1, ni SIL IEC 62061).
> Voir [`docs/compliance/IEC_TS_63074.md`](../../../../docs/compliance/IEC_TS_63074.md).

> ⚠️ **B1 sert le segment S3 (drones), pas le S1 retenu.** Traité parce que la phase 3 du
> prompt le demande et que la porte, le compteur et la révocation sont le travail commun.

## 1. Le montage

```
PX4 SITL (SIH quadx — la physique tourne DANS PX4)
     ▲ COMMAND_LONG(400)                      ▲ HEARTBEAT
     │                                         │
px4_order_arm vehicle  ◀──V2_EXTENSION/UDP── px4_order_arm commander
```

Le `V2_EXTENSION` **traverse une vraie socket UDP entre deux processus** : ce n'est pas un
appel en mémoire déguisé en test. Le rôle *vehicle* extrait l'enveloppe, la vérifie par un
vrai `MeshRouter` v0B, passe la **porte de la partie F**, et n'émet
`MAV_CMD_COMPONENT_ARM_DISARM` que dans la branche `Act`.

**Aucun `sudo`, aucun `apt`.** La chaîne de compilation a été montée dans `$HOME` : venv +
`get-pip.py` → pip 26.2.1, puis `cmake` 4.4.4 et `ninja` 1.13.2 en roues pip, et les 14
dépendances Python en roues **pour Python 3.14** (`lxml` 6.1.3, `numpy` 2.5.3,
`pymavlink` 2.4.50 comprises). `java` et `ant` sont absents de la machine et **ne sont pas
nécessaires** : l'airframe `10040_sihsim_quadx` fait tourner la physique dans PX4 (SIH) avec
`SENS_EN_GPSSIM/BAROSIM/MAGSIM`, donc ni jmavsim ni Gazebo.

## 2. Les cinq cas

| # | Cas | Où il est arrêté | Observé | PX4 |
|---|---|---|---|---|
| **1** | ordre valide | — | `GATE Act seq=1 action=Some(Arm)` → **1 trame** `COMMAND_LONG(400)`, 45 o | **`INFO [commander] Armed by external command`** |
| **2** | **forgé** — signé par une clé absente du registre du véhicule | couche mesh, **avant la porte** | `MESH_DROP why="unknown sender"` → **0 trame** | rien |
| **3** | **altéré** — un bit de l'ordre inversé **après** signature | couche mesh | `MESH_DROP why="bad mesh signature"` → **0 trame** | rien |
| **4** | **rejoué** — la même trame, deux fois | 1ʳᵉ exécutée, 2ᵉ par la **fenêtre de compteur persistée** | `GATE Act` puis `MESH_DROP why="stale counter"` → **1 trame, pas 2** | armé **une fois** |
| **5** | **révoqué** — ordre authentique d'une origine révoquée | **la porte** (v0B vérifie) | `GATE Reject(Revoked)` → **0 trame**, compteur `rejects[2]=1` | rien |

C'est exactement ce que B1 demandait : **un ordre forgé, rejoué ou révoqué n'arme pas le
drone, et l'ordre valide l'arme.** Et les logs nomment **quelle barrière a joué** : deux cas
meurent dans la couche mesh avant que la porte soit atteinte, un cas meurt à la porte, et le
rejeu montre les deux à la suite.

Le cas 4 est le plus parlant : la première copie **a** armé — c'est un ordre valide — et la
seconde est tombée sur la fenêtre de compteur persistée. **Un ordre, un armement, jamais
deux.**

## 3. Deux défauts de ma part, dont un non résolu

**a. Le premier passage ne disait rien d'OASIS.** Mon motif d'attente acceptait n'importe
quelle ligne `INFO [commander]`, qui apparaît au bout de 2 s, donc l'ordre arrivait pendant
le transitoire de démarrage : PX4 répondait `Preflight Fail: no heading reference` puis
`Arming denied: Resolve system health failures first`. Le refus venait de PX4 et de son EKF,
pas de la porte. Corrigé en attendant **`Ready for takeoff`**, qui arrive à **5 s** (mesuré,
`px4_ready_probe.sh`). Sans cette correction le test aurait pu être présenté comme un
succès de la porte alors qu'il ne testait rien.

**b. Le véhicule ne voit pas lui-même l'état armé — et je n'en connais pas la cause.**
`px4_heartbeats=0` et `armed=false` dans tous les cas : la socket du véhicule ne reçoit
jamais le flux de PX4. **L'armement est donc établi par le log de PX4**, pas par
l'observation interne du test. J'ai d'abord attribué cela au drapeau `-f` de
`mavlink start`, en le croyant « diffusion » ; vérification faite dans
`src/modules/mavlink/mavlink_main.cpp`, **`-f` met `_forwarding_on = true`**, c'est-à-dire le
transfert entre instances mavlink, et **mon explication était fausse**. Lier la socket à
14550 (commit `b442b46`) n'a rien changé. La cause reste **inconnue**, et je préfère le dire
que proposer une seconde hypothèse non vérifiée.

Conséquence pour la lecture des résultats : la colonne « PX4 » du tableau §2 vient de
`*_px4.log`, le journal de l'autopilote lui-même, qui est la source la plus forte
disponible ; la colonne `vu_par_le_vehicule` du résumé vaut **0 partout** et ne prouve rien.

## 4. Limites

- **Clés de test.** Les deux rôles dérivent leurs identités Ed25519 des graines
  déterministes des tests unitaires. C'est un banc de démonstration, pas un déploiement.
- **Horloge partagée.** L'horloge de l'actionneur est l'horloge murale, lue
  indépendamment par les deux processus, et `boot_id` est un drapeau donné aux deux.
  Honnête pour deux processus sur une machine, et **ce n'est pas** ainsi qu'un commandant
  apprend l'horloge d'un actionneur : la réponse est la **partie K** (`TimeView` sur une
  balise `OTM1` signée), volontairement non réutilisée ici.
- **Simulation, pas de vol.** SIH est un modèle de vol dans PX4 ; il n'y a **aucun
  matériel** — ni Pixhawk, ni quadricoptère, ni radio. Le dépôt n'a jamais volé.
- **Passages uniques**, non bandés. Cinq cas, une fois chacun.
- **Pas de signature MAVLink.** Les trames `COMMAND_LONG` produites ne sont pas signées au
  niveau du lien ; les deux couches sont indépendantes et
  [`docs/compliance/MAVLINK_SIGNING_GAP.md`](../../../../docs/compliance/MAVLINK_SIGNING_GAP.md)
  explique pourquoi la signature de lien ne remplace pas l'autorité par nœud.
- **Désarmement automatique.** PX4 écrit `Disarmed by auto preflight disarming` une dizaine
  de secondes après l'armement, faute de décollage. Attendu, sans rapport avec OASIS.

## 5. Reproduire

```bash
bash harness/px4_bootstrap.sh    # venv, puis constat de ce qui manque
bash harness/px4_bootstrap2.sh   # get-pip, cmake, ninja, les 14 deps
bash harness/px4_build.sh        # px4_sitl_default (6 min 31 ici, rc=0)
bash harness/build_linux_bin.sh b1-px4-sitl
bash harness/b1_sitl_all.sh      # les cinq cas + le resume
```
