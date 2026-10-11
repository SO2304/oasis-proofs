# Non-régression silicium après C9 et B1 — B→C, 2026-10-08

**HEAD du dépôt : `c29700b`.** Trois RP2040, liaison filaire. Cinq cas, **5/5**.

> **OASIS n'est pas une fonction de sûreté certifiée** (ni PL ISO 13849-1, ni SIL
> IEC 62061). Voir [`docs/compliance/IEC_TS_63074.md`](../../../../docs/compliance/IEC_TS_63074.md).

## 1. Pourquoi le firmware n'a **pas** été relevé

Le fil `B.GP1` est revenu sur `A.GP0` (il était sur `C.GP0` depuis la partie K), et la
décision prise était de reflasher B et C au HEAD. **Elle a été abandonnée après lecture de
l'état réel des cartes**, qui n'était pas connu au moment du choix :

| | version | plancher | empreinte | fp |
|---|---:|---:|---|---|
| **B** `/dev/ttyS9` | 25 | **25** | `6d3429f` | `f6bd34440030a136` |
| **C** `/dev/ttyS10` | 26 | **26** | `ad8f24a` | `a7089677a10b7fb0` |
| **A** `/dev/ttyS8` | — | — | `a39d5fe` | équipement Modbus (`rmodbus`) |

B et C tournent **sous le chargeur A/B** (phase 1.3), `bootloader_state=Boot`, **plancher
égal à la version courante**. Y poser HEAD demanderait :

- soit la **voie signée** — une image 26 (B) et 27 (C), un manifeste `OAU1` kind 3 signé
  par le propriétaire o2, et **le plancher monte définitivement** après l'auto-test. Une
  action à sens unique sur le banc ;
- soit un **écrasement BOOTSEL**, qui remplace aussi le chargeur et contourne le plancher.

Or **la seule différence de comportement entre le firmware flashé et HEAD est le 10ᵉ
compteur de refus** dans la ligne de statut (ajouté par C9, `Reason::QuorumMissing`) : un
format de log. Les parties G, H, I et J sont entièrement présentes dans `6d3429f`/`ad8f24a`.
Dépenser un plancher de version irréversible pour un champ de log serait un mauvais
échange, donc **les cinq cas tournent sur le firmware en place**, et ce rapport ne prétend
pas valider HEAD sur silicium.

**A est restée l'équipement Modbus**, ce qui était l'intérêt de la décision : son compteur
`writes` est la seule mesure extérieure à OASIS du banc. Son firmware **maintient `GP0`
haut et ne s'en sert jamais** (commentaire dans `modbus_device.rs` : « the A→B mesh wire
stays quiet »), donc le fil rétabli est électriquement correct et **ne transporte rien** :
la chaîne à trois sauts est recâblée, pas fonctionnelle.

## 2. Les cinq cas

État initial de C : `boot_id=50908`, `executed=2`, `jseq=Some(2)`, `stopped=false`,
`pin25=1`. A : `writes=7`, `rx_bytes=57`.

| # | Cas | Attendu | Observé | Log |
|---|---|---|---|---|
| **R1** | ordre `OAC1` valide, `seq=2001`, échéance = horloge de C + 6 s | `Act` | `ARRIVED sig=verified` puis **`ACT decision=Act,seq=2001,pin25=1,jseq=Some(3)`** | `10_r1_*` |
| **R2** | même ordre, `boot_id=50907` (démarrage précédent), `seq=2002` | refus, **et journalisé** | **`Reject(Expired)`**, `jseq=Some(4)` | `20_r2_*` |
| **R3** | arrêt compact `OAS1`, `actuator_id=1` (LED seule), `seq=3001` | verrou sur la LED, **pas** sur la passerelle | **`STOP fmt=OAS1,decision=Stop,stopped_led=true,stopped_gw=false,pin25=0`**, `stopped=true,stops=1`, `jseq=Some(5)` | `30_r3_*` |
| **R3b** | ordre **valide** pendant le verrou, `seq=2003` | refus `Stopped`, **et A ne reçoit rien** | **`Reject(Stopped)`**, `pin25=0`, `jseq=Some(6)` ; A : `writes=7`, `rx_bytes=57` **inchangés** | `31_r3b_*` |
| **R4** | journal relu de la flash (`@Zd`) et vérifié sur PC | intact, sortie 0 | **`VERDICT intact entries=7`, exit 0** | `40_r4_*`, `41_r4_*` |
| **R5** | un chiffre hexadécimal inversé dans une entrée | cassé, sortie 1 | **`VERDICT broken at=6`, exit 1** (`cmd_seq` 2003 → 1795) | `50_r5_*`, `51_r5_*` |

La chaîne relue contient **exactement** les quatre décisions de cette campagne, dans
l'ordre, après les trois de la campagne J/K — et le vérificateur a **filtré 6 entrées d'un
démarrage antérieur** (`prev_boot=Some(49629)`) avant de conclure :

```
[3] seq=3 cmd_seq=2001 class=Act  decision=Act                 ← R1
[4] seq=4 cmd_seq=2002 class=Act  decision=Reject(Expired)     ← R2
[5] seq=5 cmd_seq=3001 class=Stop decision=Stop                ← R3
[6] seq=6 cmd_seq=2003 class=Act  decision=Reject(Stopped)     ← R3b
```

Deux refus sur quatre entrées : c'est la propriété que l'annexe III 1.1.9 du Règlement
Machines demande nommément (« légitime **ou** illégitime »), observée et non déduite.

## 3. Ce que R5 a coûté, et pourquoi c'est écrit ici

**R5 est passé « intact » deux fois avant d'être un vrai test**, et les deux fois l'erreur
était la mienne :

1. j'ai inversé un chiffre dans l'entrée d'indice 0 **du fichier** — qui appartient au
   démarrage 49629 et que le vérificateur **filtre**. Falsifier une entrée écartée ne
   casse rien, et le verdict « intact » était correct ;
2. j'ai corrigé en visant « la dernière ligne `JRN_E` » — sauf que **`JRN_END` commence
   aussi par `JRN_E`**, donc j'ai falsifié le terminateur, pas une entrée.

Le prédicat juste est `startswith('JRN_E ')`, espace compris, et le script affiche
désormais le nombre d'entrées trouvées, la ligne visée, et l'empreinte avant/après — pour
qu'un « intact » ne puisse plus passer pour une preuve. C'est la même classe de défaut que
K6 dans la campagne J/K (une seconde balise rafraîchissait la vue au lieu de la rejouer) :
**un test qui ne teste pas ce qu'il annonce rend un verdict vert et ne vaut rien.**

## 4. État du banc à la fin

Le verrou a été **effacé localement** (`@Zc` → `STOP_CLEAR was_stopped_led=true,
now_led=false`), donc `stopped=false`, `stops=1`, `jseq=Some(6)`, `pin25=0`. La LED reste
éteinte : effacer le verrou ne réexécute pas un ordre, ce qui est le comportement voulu.
A est intacte à `writes=7`. Rien n'a été reflashé, aucun plancher de version n'a bougé,
aucune coupure de courant.

## 5. Limites

- **Ce rapport ne valide pas HEAD sur silicium** : il valide `6d3429f` (B) et `ad8f24a`
  (C). Le 10ᵉ compteur de refus de C9 n'a jamais tourné sur une carte.
- **Deux nœuds, une liaison filaire, aucune radio.** La chaîne à trois sauts est recâblée
  mais A est un équipement Modbus et se tait.
- **Passages uniques**, non bandés. Cinq cas ne sont pas une campagne : ils disent que les
  parties G, H, I et J n'ont pas régressé, pas qu'elles sont prouvées à nouveau — la
  campagne qui les prouve est `evidence/silicon/2026-10-08/hardening/` (19/20) et
  `.../jk/` (6/6 et 6/6).
- **Le journal reste tamper-évident contre un attaquant distant seulement** : R5 falsifie
  un fichier sur le PC, pas la flash. Qui tient la flash réécrit entrées et tête ensemble.
- **C9 n'a toujours rien sur silicium** : aucune carte ne détient un *jeu* de clés
  opérateur.
