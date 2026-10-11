# Plan — premier test devant un onduleur SMA réel

**2026-10-09.** Phase 0 de `prompts/OASIS_SMA_REAL_TEST.md`. **Aucune écriture n'a été
faite**, et aucune ne le sera avant ton accord sur ce plan (phase 0, point 5).

---

## 1. Ce qui est établi, et comment

| | |
|---|---|
| **Onduleur trouvé** | `169.254.12.3`, MAC `00:40:AD:xx:xx:xx` |
| **Comment** | diffusion lien-local sur le segment du câble (`ping 169.254.255.255`) → une seule réponse, TTL 64, 2 ms ; l'OUI `00:40:AD` est **SMA Solar Technology** |
| **Interface web** | port **80 ouvert**, HTTP 200, page servant `images/layout/smalogo.gif` et le mot `Speedwire` — c'est bien l'interface SMA |
| **Modbus** | port **502 FERMÉ**. Le serveur Modbus est donc **désactivé par défaut**, exactement ce que SMA documente |
| **443** | fermé |

Le PC est en `169.254.224.117/16` sur son Ethernet, l'onduleur en `169.254.12.3/16` : même
`/16`, ils se parlent **sans qu'aucune adresse ait été changée**.

## 2. Topologie retenue : T2, et ce que ça coûte

Un seul PC, deux interfaces : **Wi-Fi** `192.168.129.236/23` pour le réseau domestique et
Internet, **Ethernet** lien-local dédié à l'onduleur. Agent et passerelle seront deux
processus sur cette machine.

⚠️ **T2 est la topologie faible du prompt, et il faut le dire** : l'IHM, l'agent et la
passerelle partagent une machine.

⚠️ **La règle 3 n'est pas vérifiable telle qu'elle est écrite.** Elle demande de prouver,
*depuis l'hôte agent*, que le port 502 de l'onduleur est injoignable. En T2 l'hôte agent
**est** l'hôte passerelle, donc le port 502 y est joignable par construction. Ce qui est
vrai et vérifiable à la place, et qui a du sens :

> **Aucune machine du réseau domestique ne peut joindre l'onduleur.** Il est en
> `169.254.12.3`, une adresse **lien-local** (RFC 3927), non routable par définition, sur
> un câble qui ne va qu'au PC. Et un balayage ICMP des 508 adresses de `192.168.128.0/23`
> suivi d'une lecture de la table ARP n'a trouvé **aucun OUI SMA** parmi les 12 hôtes
> vivants : l'onduleur n'est pas sur le Wi-Fi.

### Le point 0 de la phase 0 est satisfait, et sans adresse statique

Le prompt demande une adresse **statique** sans passerelle sur l'interface onduleur. Une
adresse **lien-local** fait mieux : elle ne porte **jamais** de route par défaut, par
définition du protocole (RFC 3927). Les métriques d'interface ont été inversées par
l'utilisateur, en administrateur :

```powershell
Set-NetIPInterface -InterfaceAlias 'Wi-Fi'    -AutomaticMetric Disabled -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias 'Ethernet' -AutomaticMetric Disabled -InterfaceMetric 100
```

⚠️ Au départ l'Ethernet avait la métrique **35** contre **40** au Wi-Fi : il était donc
*prioritaire*. Brancher le câble sur un segment pourvu d'un DHCP aurait fait basculer la
route par défaut et coupé Internet. Ici le segment n'a pas de DHCP, donc le risque ne s'est
pas matérialisé — mais la correction reste nécessaire pour le prochain test, et c'est
pourquoi elle est notée ici.

## 3. Le registre d'écriture, avec sa référence SMA

**Source primaire** : SMA Solar Technology AG, *Technical Information — SunSpec Modbus*,
document **`SunSpecModbus-TI-en-11`**, sections **2** (Safety), **3** (Activating the
SunSpec Modbus), **4** (SunSpec Profile), **5** (Supported Information Models).

| | |
|---|---|
| **Registre** | `WMaxLimPct` — limitation de puissance active, en % de `WMax` |
| **Modèle** | SunSpec **123** *Inverter Immediate Controls*, **supporté** (§5). ⚠️ En profil 2.0 SMA **recommande le 704** et marque le 123 comme dépassé ; lequel s'applique dépend du jeu de données pays de cet onduleur. **À trancher sur l'appareil**, pas ici |
| **Adresse** | **à découvrir sur l'appareil** en parcourant la chaîne des modèles SunSpec. §4 : « All information models start with an ID register and a length register … information models can be found and used ». C'est la méthode que SMA prescrit ; une adresse recopiée d'un forum est refusée par la règle 1 |
| **Unit ID** | **126** en profil SunSpec (§3 : *Unit ID SunSpec = Unit ID SMA + 123*, préréglé à 126) |
| **Plage de la carte** | **50 à 100 %**. Jamais 0 % |
| **Écritures cycliques** | §2 : « Cyclical changing of these parameters leads to **destruction of the flash memory** … The following parameters are **excluded** … Information model 123: Conn, **WMaxLimPct**, OutPFSet, VArWMaxPct, VArMaxPct ». Ce registre est donc **explicitement exempté**. Le plafond du prompt — une écriture légitime par minute, dix au total — reste appliqué malgré tout |

⚠️ Un fait de sécurité à retenir pour le rapport, §2 du même document : « After activating
the Modbus interface, the read and write access to all data points is possible **without
further input of a password** via Modbus. » C'est précisément le trou que la passerelle
vient combler.

## 4. Ce qui manque pour aller plus loin

| Manque | Pourquoi je ne peux pas le lever seul |
|---|---|
| **Mot de passe installateur** | Toutes les lectures JSON de l'interface répondent `{"err":401}` : `getValues.json` exige une session. Sans elle, pas de modèle, pas de firmware, pas de numéro de série, et pas d'activation du Modbus |
| **Modèle exact et firmware** | Lisibles seulement après connexion, ou sur la plaque |
| **Activation du Modbus** | Par l'interface web : assistant d'installation → **Configuration réseau > Modbus** → type de communication = Modbus, port TCP **502**, version de profil « Standard (recommandé) ». Relever l'Unit ID affiché |
| **Heure avec du soleil** | Pour que la limitation à 60 % se voie sur la puissance AC |

⚠️ Je ne devinerai aucun mot de passe. Et conformément à la règle 10, le mot de passe ne
sera **jamais** écrit dans le dépôt : il sert en session et nulle part ailleurs.

## 5. Les cas de la phase 2, dans l'ordre prévu

1. écriture légitime **60 %** → puissance AC en baisse dans la minute ;
2. retour à **100 %** → la puissance remonte ;
3. **rejeu** octet pour octet du cas 1 → refusé, aucune trame vers l'onduleur ;
4. **origine forgée** (clé non enrôlée) → refusée ;
5. **valeur modifiée** dans une enveloppe authentique → refusée ;
6. **hors plage** 40 % → refusé, registre inchangé ;
7. **registre hors carte**, adresse en **lecture seule** → refusé ;
8. **ordre expiré**, puis ordre d'un **démarrage précédent** de la passerelle → refusés ;
9. **Modbus brut** 60 % envoyé au port de la passerelle par un tiers → refusé ;
10. **révocation `ORV1`** de l'agent, puis une écriture légitime de cet agent → refusée,
    journal `Change(Revocation)` ;
11. **lecture** à travers la passerelle (`OMQ1`) → puissance AC relue sans contact direct ;
12. **témoin** : limitation 60 % puis 100 % en direct depuis l'hôte passerelle, avec un
    binaire Rust, pour prouver que l'onduleur obéit bien à ce registre.

Écritures légitimes atteignant l'onduleur : cas 1, 2 et 12 → **4 au total**, sous le
plafond de 10. Les écritures K=10 de la phase 3 utiliseront **100 % → 100 %**, légitimes
et sans effet sur la valeur.

## 6. Ce que cette campagne ne prouvera pas

- **Ce n'est pas une machine** au sens du Règlement (UE) 2023/1230 : c'est un équipement
  d'énergie. Cette campagne **ne démontre pas** l'annexe III 1.1.9.
- **Une seule commande, sans danger**, sur **un seul registre**. Aucune E/S, aucun cycle
  de scrutation, aucune fonction de sûreté.
- Le **profil Modbus de l'onduleur n'est pas audité par nous**.
- T2 : agent et passerelle sur la même machine (§2).
- La phrase « non testé sur automate du commerce » **reste vraie** : un onduleur n'est pas
  un automate, et elle doit rester écrite dans `CLAUDE.md`.

---

## 7. Outil de découverte prêt — `oasis_sma_probe` (lecture seule)

Ajouté le 2026-10-09 pour satisfaire la règle 1 **sans forum et sans contournement** :
`oasis-rt/src/bin/oasis_sma_probe.rs`, un client Modbus TCP qui **n'émet que du FC03**
(lecture de registres) — il ne peut pas écrire. Il parcourt la chaîne des modèles SunSpec
(`"SunS"` → en-tête id+longueur par modèle, §4 de SMA), liste les modèles présents, lit
l'identité du modèle commun 1 (numéro de série masqué, 4 derniers caractères, règle 10) et
**affiche** le bloc du modèle 123 ou 704 pour que l'offset de `WMaxLimPct` et de son facteur
d'échelle soit confirmé contre la définition SunSpec avant qu'aucune écriture ne soit
planifiée.

Le cœur (parcours de chaîne, parse FC03, masquage) est **testé sans matériel** : 8 tests
unitaires verts. Lancé contre l'onduleur avec le Modbus encore éteint, il échoue proprement
(`TimedOut` sur le port 502, exit 1) et nomme la cause.

```text
oasis_sma_probe --addr 169.254.12.3:502 --unit 126
```

⚠️ **Il ne tournera pour de vrai qu'une fois le serveur Modbus activé.** Cette activation
est la seule chose qui reste bloquée, et elle n'a pas de contournement acceptable : elle se
fait par l'interface web de l'onduleur, avec le mot de passe installateur, sur ton appareil.
Deux façons de la débloquer, au choix :

1. **Tu actives le Modbus toi-même** (c'est l'exception prévue par le prompt à « l'utilisateur
   ne fait que le câblage ») : interface web → assistant d'installation → **Configuration
   réseau > Modbus** → type de communication = Modbus, port TCP **502**, version de profil
   « Standard (recommandé) ». Dis-moi ensuite l'Unit ID affiché.
2. **Tu me donnes le mot de passe installateur pour la session** (oralement/ici, jamais
   écrit dans le dépôt, règle 10) et je fais les mêmes clics par l'interface web — en
   l'utilisant comme prévu, pas en la contournant.

Je ne tenterai ni mot de passe par défaut, ni endpoint non authentifié, ni aucune autre
forme de contournement de l'authentification de l'onduleur : ce serait de l'accès non
autorisé, et c'est hors de ce que je fais même sur ton propre matériel.

---

## 8. Appareil identifié (plaque signalétique)

L'utilisateur a fourni une photo de la plaque. Relevé, conformément à la phase 0 point 1
(« relève modèle, firmware, numéro de série masqué ») :

| | |
|---|---|
| **Fabricant** | SMA Solar Technology AG, Niestetal, Allemagne |
| **Modèle** | **SB4.0-1AV-40** — Sunny Boy 4.0, onduleur **monophasé** |
| **Puissance** | P_AC 4000 W, S_max 4000 VA, 220/230/240 V, 50/60 Hz |
| **Numéro de série** | `199212xxxx` (4 derniers masqués, règle 10) |
| **Date de fabrication** | 2018-08-08 |
| **Firmware** | **non relevé** — lisible seulement après connexion au web ou activation du Modbus |

Conséquences pour la campagne :

- **Monophasé** → pour la puissance AC de la ligne de base, le modèle SunSpec attendu est
  le **101** (*single phase AC monitoring*), pas le 103.
- Série **1AV-40** « Smart Connected », fabriquée en 2018 : le profil SunSpec effectif
  (1.1 ou 2.0) dépend du jeu de données pays, à confirmer par `oasis_sma_probe` une fois le
  Modbus actif. Le modèle de contrôle sera donc **123** ou **704**, l'outil le dira.

⚠️ **Codes de la plaque délibérément NON consignés** (règle 10) : la clé WPA2-PSK (point
d'accès Wi-Fi de l'onduleur), le RID et le PIC (enregistrement Sunny Portal). Aucun n'est
le mot de passe du **groupe Installateur** de l'interface web locale, lequel est défini à
la mise en service et ne figure pas sur la plaque. Il reste donc le seul élément nécessaire
pour activer le Modbus, et il n'a pas de contournement acceptable.
