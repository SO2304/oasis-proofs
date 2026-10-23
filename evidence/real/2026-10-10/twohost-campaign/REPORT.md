# Rapport — deux machines, câble et LAN : la campagne (A.6 / T1)

> *Expurgé pour publication le 2026-10-23 / redacted for publication on 2026-10-23 : chemins de sources, identifiants internes et noms de harnais retirés ; résultats inchangés.*

**2026-10-10, au soir.** Suite du passage 1 (`../twohost-t1/`). [withheld: test harness]
pilote depuis PC1, [withheld: test harness] s'exécute sur PC2. Le script a été versionné
**avant** de mesurer (`08630a1`, règle 5). Le premier lancement a trouvé un défaut (§3).
Le correctif est `b098449`, et ce dossier est le second lancement, sur ce code :
**61 contrôles sur 61**.

L'empreinte du journal de campagne porte `b098449+dirty`. Les deux fichiers modifiés à ce
moment-là n'étaient que de la documentation (`docs/PILOT_INSTALL.md` et l'erratum de
`../twohost-t1/REPORT.md`), aucun code.

---

## 1. Le montage

| | PC1 — côté machine | PC2 — côté opérateur |
|---|---|---|
| Matériel | PC Windows 11 Pro | Dell OptiPlex 7080, Ubuntu |
| Programmes | `oasis_mbtcp_gateway`, `oasis_test_plc` sur `127.0.0.1` seulement | `oasis_mbtcp_order`, `oasis_mbtcp_agent`, [withheld: test harness] (Python sans dépendance) |
| Câble | `fe80::1601:70df:35b:73c0` | `fe80::abea:xxxx:xxxx:xxxx` (masquée), interface `eno2` |
| LAN | `192.168.129.236` (Wi-Fi) | `192.168.129.116` (Wi-Fi), via le routeur domestique |

Deux chemins de données entre les mêmes machines :
- **le câble direct** : IPv6 lien-local, 100 Mbit/s, sans IPv4 ;
- **le LAN** : IPv4 privée, à travers un routeur, deux sauts Wi-Fi.

L'administration (SSH) passe par le LAN. Elle utilise la clé que le propriétaire a
autorisée, et l'empreinte d'hôte épinglée lors du passage 1 (`HostKeyAlias`). C'est
cette empreinte qui établit que `192.168.129.116` est bien le PC2 du câble.

**Les clés naissent sur PC2** : celles de l'outil d'ordre (`aa00`), de l'agent (`ab00`), de
la clé inscrite sans permission (`7800`) et de l'attaquant (`f0…f0`, inscrite nulle part).
Seules leurs moitiés publiques reviennent, et la passerelle les inscrit en `peer_pk`. La clé
de la passerelle naît sur PC1. C'est ce qui manquait au passage 1, où les graines avaient
été préparées sur PC1 puis copiées.

Aucune règle de décision n'a été touchée.

## 2. Résultats

| Phase | Chemin | Ce qui est vérifié | Résultat |
|---|---|---|---|
| A | câble, outil d'ordre | 3 passages × 5 ordres | dans chaque passage, **1 `Act` = 1 écriture**, et les 4 attaques sont refusées avec le bon code. La clé sans `ACTUATE` affiche `exception=0x0a` et plus jamais `OutOfLimits` : c'est le correctif du passage 1, vu **à travers le câble** |
| A2 | câble, **chemin livré** (IHM → agent sur PC2 → passerelle sur PC1) | écriture, registre hors carte, valeur hors plage, lecture, latence | `OK`, `0x02`, `0x03`, lecture `61` ; 205 écritures acquittées, **205 atterries** |
| B | LAN, chemin livré | les cas C1 à C7 et C10 du pilote, entre deux machines | tous passent, voir le détail plus bas |
| C | journaux | chaque chaîne vérifiée ; `Act` = écritures appareil ; falsification | voir le détail plus bas |

**Phase B, détail :**
- L'écriture légitime atteint l'appareil, qui la tient. Le registre hors carte (`0x02`), la valeur hors plage (`0x03`) et la lecture hors carte (`0x02`) sont refusés.
- Du Modbus brut envoyé par PC2 sur le port de la passerelle ne reçoit **aucune réponse**, et l'appareil n'est pas touché.
- **Non-contournement** : depuis PC2, le port de l'appareil (15720) et le port 502 de PC1 sont refusés.
- Après un redémarrage de l'agent sur PC2, son numéro de séquence monte (64 → 128) et l'écriture passe.
- Après un redémarrage de la passerelle sur PC1, le `boot_id` change et l'écriture passe.
- Latence : voir §4.

**Phase C, détail :**
- Trois chaînes sont sur le disque : `jrnA`, `jrnB.1791655439803` (le premier démarrage de B, archivé) et `jrnB`. Chacune donne `VERDICT intact`, exit 0.
- **`Act` = écritures de l'appareil**, phase par phase : A, 209 = 209 ; B, 208 = 208 en additionnant les deux démarrages.
- Un refus réécrit en `Act` dans la chaîne **archivée** donne `broken`, exit 1.

**Origine des connexions.** Chaque connexion reçue par la passerelle venait de PC2 : de son
adresse câble en phase A, de son adresse LAN en phase B (`gateway_a.log`, `gateway_b.log`).

Les journaux comptent 209 `Act` et 14 refus en A, 208 `Act` et 2 refus en B. Le Modbus brut
de B6 n'y laisse aucune entrée : il est refusé par le cadrage, avant de devenir une décision.
C'est la limite déjà documentée du chemin pilote.

## 3. Défaut trouvé : un redémarrage effaçait le journal du démarrage précédent

**Constat.** Au premier lancement (`08630a1`), la phase B a donné **53 contrôles réussis et
4 échecs**. L'appareil avait compté **208** écritures, mais le journal de B ne contenait que
**206** `Act` et **0** refus, et il commençait à `cmd_seq=66`.

Les 4 décisions prises avant le redémarrage de la passerelle avaient disparu : 2 `Act` qui
avaient atteint l'appareil, et 2 refus. Le journal de la passerelle les montre pourtant
(`seq=1 Act`, `seq=2` et `seq=3 Reject`, `seq=65 Act`). Les 3 autres échecs en
découlaient. Sans refus restant, le contrôle de falsification n'avait rien à réécrire, et
son propre garde l'a signalé (`changes exactly one entry: expected 1, got 0`) au lieu de
passer pour rien.

**Cause.** [withheld: code identifier] **tronquait** les deux fichiers à chaque lancement, et c'était
voulu : « mélanger deux démarrages dans un fichier ferait sauter la séquence ». Ce
raisonnement était juste sur le mélange et faux sur la destruction. Le cas C10 de
[withheld: test harness] est resté vert tout ce temps, parce qu'il ne vérifiait que la **nouvelle**
chaîne.

Pour l'annexe III 1.1.9 §5, qui demande de *recueillir* des preuves, un enregistrement
qu'un redémarrage efface ne recueille rien. Et l'unité systemd redémarre la passerelle
après chaque plantage.

**Correctif** (`b098449`).
- Au démarrage, la paire précédente est **renommée** en `<préfixe>.<son boot_id>.head/.entries`, jamais écrasée : un nom déjà pris donne `.2`, `.3`, …
- Chaque chaîne se vérifie seule, contre sa propre tête.
- Le `boot_id` lu dans l'ancienne tête n'est accepté qu'en chiffres, pour qu'une valeur comme `../x` ne choisisse pas où atterrit le renommage.
- La passerelle écrit où elle a rangé la chaîne précédente.
- Le format du journal, [withheld: source file] (vérifié par Kani) et la porte de décision ne sont pas touchés.

[withheld: code identifier] vit désormais dans [withheld: code identifier], ce qui ramène [withheld: source file]
de 532 à 445 lignes (règle R10).

**Tests.** 4 tests : redémarrage conservé octet pour octet, archive jamais écrasée, tête qui ne
peut pas orienter le renommage, premier démarrage. **Contrôle négatif** : avec la troncature
remise, **3 tests sur 4 échouent**. Le premier démarrage, qui n'a rien à déplacer, reste
vert. Le C10 du pilote vérifie maintenant que la chaîne du premier démarrage est gardée,
qu'elle se vérifie, et qu'elle contient autant d'entrées qu'avant l'arrêt.

⚠️ **À ne pas confondre** avec l'hypothèse, encore non vérifiée, que `CLAUDE.md` formule pour
le firmware RP2040 : un nœud dont la flash contient déjà une chaîne ne la reprendrait pas.
C'est un autre code (`jstore` sur le MCU), et ce correctif ne la tranche pas.

## 4. Latence de bout en bout

La mesure est prise **côté IHM, sur PC2** : une seule connexion tenue ouverte, K = 10 séries de
20 écritures, la médiane de chaque série, puis la médiane des séries et sa demi-dispersion.

| Chemin | Lancement 1 (`08630a1`) | Lancement 2 (`b098449`) |
|---|---:|---:|
| Câble direct, 100 Mbit/s | **1 972 µs ± 22 %** | **1 961 µs ± 20 %** |
| LAN, deux sauts Wi-Fi via le routeur | 3 899 µs ± 30 % | 5 150 µs ± 27 % |

Chaque écriture comprend :
- la signature de l'agent sur PC2 ;
- le réseau, à l'aller et au retour ;
- sur PC1, la vérification, la porte, l'écriture sur l'appareil et le journal, avec deux vidages sur disque.

Sur le câble, les deux lancements concordent à 0,6 % près. Sur le Wi-Fi, les bandes se
recouvrent mais les médianes diffèrent d'un tiers : le chiffre Wi-Fi est un **ordre de
grandeur**, pas une constante. Pour situer, la campagne pilote mesure 609 à 849 µs sur un
seul hôte, en boucle locale.

⚠️ L'appareil est un simulateur sans cycle d'automate : sa part est un **plancher**.

## 5. Les contournements que la campagne a demandés

- **NetworkManager sur le câble.** Sans DHCP, le profil filaire de PC2 échoue toutes les
  45 s, retire l'adresse et recommence : 4 essais, puis 5 minutes de pause. Mes droits SSH
  ne permettent pas de le reconfigurer sans mot de passe. Chaque étape câble attend donc
  une fenêtre **fraîche** ([withheld: test harness]) et part aussitôt. C'est cette
  même cause que le passage 1 avait prise pour une mise en veille (erratum dans
  `../twohost-t1/REPORT.md`).
- **Exposition.** Au passage 1, la passerelle écoutait sur `[::]`, qui inclut les adresses
  IPv6 **globales** du Wi-Fi de PC1. Ici, la phase A se lie à la seule adresse lien-local du
  câble, et la phase B à la seule adresse IPv4 privée.
- **Identité de PC2 sur le LAN** : vérifiée par l'empreinte d'hôte épinglée sur le câble, et
  non par une nouvelle empreinte acceptée à l'aveugle.
- **Windows verrouille un `.exe` en cours d'exécution** : aucune reconstruction pendant la
  campagne, et les tests sont recomptés dans un `CARGO_TARGET_DIR` séparé.

## 6. Ce que ce rapport NE prouve PAS

- **Pas un automate du commerce.** L'appareil est `oasis_test_plc` (`rmodbus`, aucun code
  OASIS), sur PC1. « Non testé sur automate du commerce » **reste vrai**.
- **Pas un réseau industriel.** Le LAN est un Wi-Fi domestique derrière un routeur grand
  public : ni VLAN, ni zone IEC 62443. Et pendant la phase B, la passerelle était joignable
  depuis ce LAN. Seuls les ordres signés par une clé inscrite pouvaient agir.
- **Un seul lancement après le correctif.** Le passage câble de l'outil d'ordre est répété
  3 fois par lancement. Les phases A2 et B ne tournent qu'une fois par lancement, soit deux
  fois au total, dont une avant le correctif.
- **Pas de rejeu octet pour octet, ni d'ordre périmé, d'une machine à l'autre.** Ces cas sont
  couverts sur un seul hôte, par les tests et Kani.
- **Le câble n'a de bout en bout que les fenêtres de NetworkManager.** Un déploiement
  configurerait le lien en statique, ce qui demandait des droits d'administration sur PC2.
- **Les chaînes archivées s'accumulent**, une par redémarrage, sans politique de
  conservation. Le journal détecte une réécriture faite **à distance**. Quelqu'un qui a les
  droits d'administration sur PC1 peut réécrire entrées et têtes ensemble.
- **Le pare-feu de PC1 était désactivé** sur les profils Public et Privé.

**Suite, le soir même.** Les quatre premières limites ci-dessus ont chacune reçu un
contournement, versionné puis mesuré : `../twohost-campaign-2/REPORT.md` (84 contrôles sur
84) dit ce que chacune est devenue, et ce qu'elle reste.

## 7. Reproduire

```text
PC2_SSH=<compte>@<PC2 sur le LAN>  PC2_KEY=<clé privée autorisée>  PC2_KNOWN_HOSTS=<known_hosts>
PC2_HOSTKEY_ALIAS=<nom épinglé>    PC1_LL=<lien-local câble de PC1>%<index>  PC1_LAN=<IPv4 de PC1>
bash [withheld: test harness] <dossier de sortie>
```

## 8. Fichiers

| Fichier | Contenu |
|---|---|
| `campaign.log` | les 61 contrôles, dans l'ordre |
| `gateway_a.log`, `gateway_b.log` | la passerelle en phase câble et en phase LAN (B : deux démarrages) |
| `gw_a.conf`, `gw_b.conf` | leurs configurations : clés **publiques** seulement |
| `plc.log` | l'appareil : chaque trame reçue et chaque écriture appliquée |
| `jrnA.*`, `jrnB.*`, `jrnB.1791655439803.*` | les trois chaînes (`.head`, `.entries`, `.txt` concaténé, `.verify`) |
| `jrn_tampered.txt`, `jrn_tampered.verify` | la chaîne archivée avec un refus réécrit en `Act` : `broken`, exit 1 |
| `pc2/` | sur PC2 : les configurations de l'outil d'ordre et des agents, et les journaux des agents. Chemins de graines seulement : **aucune graine n'a quitté PC2** |
| `SHA256SUMS` | empreintes de tout ce qui précède |

Adresse câble et nom de compte de PC2 masqués. Les adresses LAN sont privées (RFC 1918).
