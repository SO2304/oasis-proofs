# Rapport — deux machines, un câble (A.6 / T1) : un passage démontré

**2026-10-10.** Complète la tentative du 2026-10-09 (`../../2026-10-09/twohost/REPORT.md`),
bloquée faute d'accès à PC2. Le blocage est levé par le propriétaire de PC2, qui y a
autorisé une clé SSH. Rien n'a été contourné.

Ce rapport établit qu'un ordre signé **sur une seconde machine** a traversé un **vrai câble**
jusqu'à la passerelle, que seule la décision `Act` a écrit sur l'appareil, et que le journal
de la passerelle le dit, refus compris. Il dit aussi ce que ce passage **ne** prouve **pas** (§5).

---

## 1. Le montage

| | PC1 — côté machine | PC2 — côté opérateur |
|---|---|---|
| Matériel | PC Windows 11 Pro | Dell OptiPlex 7080, Ubuntu |
| Rôle | passerelle `oasis_mbtcp_gateway` + appareil `oasis_test_plc` | outil d'ordre `oasis_mbtcp_order` |
| Adresse | `fe80::1601:70df:35b:73c0` | `fe80::abea:xxxx:xxxx:xxxx` (masquée) |
| Lien | un câble Ethernet direct, 100 Mbit/s, IPv6 lien-local seulement, aucune IPv4 | |

L'appareil écoute sur `127.0.0.1` de PC1 : PC2 n'a **aucune route** vers lui, sauf la
passerelle. La configuration de la passerelle ne nomme que des **clés publiques**
(`peer_pk`) : `aa00` avec `ACTUATE`, `7800` sans permission, et pas `f000…f0`.

L'outil d'ordre de PC2 est un binaire Linux **statique** (musl), construit depuis l'arbre
propre de `19e9d83`. Son SHA-256 `957180ef…304f1d` a été affiché **par PC2** juste avant le
passage, et c'est le même que celui de la construction (`binaries.log`).

## 2. Ce qui s'est passé

Cinq ordres partis de PC2. La vérité est le journal **de la passerelle** (`gateway.log`,
`journal_verify.log`), pas ce que l'outil d'ordre affiche (§4) :

| # | Ordre | Décision de la passerelle | Écriture appareil |
|---|---|---|---|
| 1 | `aa00`, registre 10 ← 60 | **`Act`** | **oui**, `writes=1 reg=10 value=60` |
| 2 | `aa00`, registre 10 ← 40 (plancher 50) | `Reject(OutOfLimits)` `ValueOutOfRange(10, 40)` | non |
| 3 | `aa00`, registre 99 (hors carte) | `Reject(OutOfLimits)` `RegisterNotAllowed(99)` | non |
| 4 | clé inconnue `f000…f0` | `MESH_DROP "unknown sender"`, journalisé `origin=0000 Reject(NotVerified)` | non |
| 5 | `7800`, connue mais sans `ACTUATE` | `Reject(NotAuthorized)`, attribué à `7800` | non |

- **Chaque connexion vient de l'adresse de PC2** (`gateway.log`, 20 lignes). Dans
  l'auto-test du 2026-10-09, elles venaient de l'adresse de PC1 elle-même : c'est la
  différence que ce passage établit.
- **1 décision `Act` = 1 écriture**. L'appareil termine à `frames=1 writes=1 rejected=0`
  (`device.log`).
- **Journal : `VERDICT intact entries=5`, exit 0.** La clé inconnue y figure en
  `origin=0000`, exprès, parce qu'une origine non vérifiée écrite comme un fait serait pire
  que rien.
- **Contrôle de falsification** : l'octet de décision de la dernière entrée
  (`0x11`, `NotAuthorized`) est réécrit en `0x00` (`Act`), une seule ligne change, et le
  vérificateur répond **`VERDICT broken at=4`, exit 1** (`journal_tampered_verify.log`).
- Les `cmd_seq` 1, 65 et 129 ne sont pas un saut anormal : chaque lancement de l'outil
  réserve un bail de 64 numéros. Un redémarrage perd au plus 64 numéros et n'en réutilise
  jamais.
- L'échéance de l'ordre vient de l'horloge **de la passerelle** (échange `OTQ1`/`OTM1`
  avant chaque ordre), pas de celle de PC2.

## 3. Défaut trouvé : l'outil d'ordre affichait une raison inventée

Sur PC2, l'ordre n° 5 s'est affiché `Refused(OutOfLimits, Ok)`, alors que la passerelle
avait décidé et journalisé `NotAuthorized`. Les ordres 2 et 3 se sont affichés
`ValueOutOfRange(0, 0)` et `RegisterNotAllowed(0)`, avec des zéros que la passerelle n'a
jamais envoyés.

**Cause.** La réponse `OMR1` ne transporte qu'un **code d'exception Modbus**, pas la
raison de la décision. `decode_reply` reconstruit un `Outcome` de remplacement dont la
raison est **toujours** `OutOfLimits`, pour que l'agent rende à l'IHM le même code. Ce
choix est correct pour l'IHM. Mais `oasis_mbtcp_order` imprimait ce remplacement avec
`{:?}`, donc une reconstruction présentée comme le constat de la passerelle. C'est la même
famille de défaut que l'origine `0000` évite dans le journal.

Le mot « refused » était faux aussi pour `NoAnswer`, que la passerelle envoie à la fois
pour une trame rejetée avant la porte **et** pour un `Act` dont l'échange avec l'appareil a
échoué. Dans ce second cas, l'écriture a pu atteindre l'appareil. Il l'était encore pour
`PlcException`, où c'est l'appareil, et non la passerelle, qui refuse.

**Correctif** (`oasis-rt/src/bin/oasis_mbtcp_order.rs`, `reply_line`). L'outil n'affiche
que ce qui a traversé le fil : `exception=0x02` (registre hors carte), `0x03` (valeur hors
plage), `0x0a` (« refusé pour une raison que la réponse ne porte pas ; le journal de la
passerelle la nomme »), `ORDER unconfirmed` pour `NoAnswer`, `ORDER device-exception`
pour `PlcException`. Les codes de sortie ne changent pas : les scripts de campagne ne
lisent que `rc == 0`.

**Ni la porte, ni le protocole, ni `modbus_tcp` n'ont été touchés** (règle 2).

**Tests.** 5 tests dans le binaire. Ils passent par `encode_reply` → `decode_reply`, donc
par ce que l'outil reçoit vraiment, et non par un `Outcome` construit à la main. **Contrôle
négatif** : avec l'ancien affichage remis en place, **4 tests sur 5 échouent**. Le 5ᵉ,
`Act`, était déjà correct. Le fichier restauré est identique octet pour octet à la version
corrigée.

⚠️ Le binaire corrigé (`460f25a8…`) n'a **pas** été exécuté sur PC2 : PC2 avait cessé de
répondre (§5 — **pas une veille** : NetworkManager retirait l'adresse du câble, voir l'erratum du §8).

## 4. Pourquoi ce n'est pas un détail

Lancé devant une vraie machine, l'outil aurait dit à l'opérateur « hors limites » pour un
ordre refusé faute d'autorisation. Cet opérateur aurait corrigé une valeur au lieu d'une
permission. Aucune écriture n'en résultait, et le journal disait vrai. Mais l'écran disait
faux, et cela ne se voyait pas sur un hôte unique : il fallait lire le journal **d'une
autre machine** à côté de l'écran de PC2.

## 5. Ce que ce rapport NE prouve PAS

- **Un seul passage.** Les passages 2 et 3, prévus contre le même démarrage de la
  passerelle, n'ont pas pu se faire : quelques minutes après le premier, PC2 a cessé de
  répondre à tout (veille probable, lien physique toujours monté). ⚠️ **Faux : ce
  n'était pas une veille, mais NetworkManager qui retire l'adresse du câble entre deux
  essais DHCP. Voir l'erratum du §8.** Le comportement est
  établi **une fois**, sans répétition. Aucun chiffre de latence n'est publié.
- **Pas un automate du commerce** : l'appareil est `oasis_test_plc` (`rmodbus`, aucun code
  OASIS), sur l'hôte de la passerelle. « Non testé sur automate du commerce » **reste
  vrai**.
- **Le pare-feu de PC1 était désactivé** sur le profil Public, celui du câble. La
  connexion entrante n'a donc demandé aucune règle. Un hôte au pare-feu actif en demande
  une pour le port de la passerelle (`network.log`).
- **Les graines des clés d'ordre ont été préparées sur PC1** puis copiées vers PC2. La
  passerelle, elle, ne lit que des clés publiques. En déploiement, la clé de l'opérateur
  naît sur sa machine et ne passe jamais par l'hôte côté machine. Ce passage ne le
  démontre pas.
- **Lien-local, un câble, sans commutateur, VLAN ni IPv4.** Rien sur un réseau d'usine
  réel.
- **Aucun redémarrage** de la passerelle ni de PC2 pendant le passage : la persistance n'est
  pas exercée ici. Elle l'est dans la campagne `pilot_campaign.sh`, sur un seul hôte.
- **« L'appareil n'a pas d'autre chemin que la passerelle » est vrai par construction**
  (écoute sur `127.0.0.1`), pas testé comme une propriété sous attaque.

## 6. Reproduire

```text
PC1 :  oasis_test_plc --listen 127.0.0.1:15720 --unit 0x7e --log plc.log
       oasis_mbtcp_gateway --config gateway.conf --journal t1jrn
PC2 :  bash run_agent.sh        # détecte son interface filaire, vise PC1 en lien-local
PC1 :  cat t1jrn.head t1jrn.entries > jrn.txt && oasis_journal_verify jrn.txt
```

Accès à PC2 : une clé publique ajoutée à `~/.ssh/authorized_keys` **par son propriétaire**,
connexion par clé seulement (`BatchMode`), empreinte d'hôte épinglée. Aucun mot de passe
n'a été utilisé.

## 7. Fichiers

| Fichier | Contenu |
|---|---|
| `gateway.log` | sortie de la passerelle, adresse de PC2 masquée |
| `device.log` | sortie de l'appareil `oasis_test_plc` |
| `pc2_run1.log` | ce que PC2 a affiché (avec l'ancien affichage fautif du §3), nom d'hôte masqué |
| `journal.head`, `journal.entries` | le journal tel qu'écrit par la passerelle |
| `journal_run1.txt`, `journal_verify.log` | leur concaténation et le verdict `intact`, exit 0 |
| `journal_tampered.txt`, `journal_tampered_verify.log` | un refus réécrit en `Act`, verdict `broken at=4`, exit 1 |
| `binaries.log` | SHA-256 et provenance de chaque binaire |
| `network.log` | faits réseau, identifiants de PC2 masqués |
| `SHA256SUMS` | empreintes de tout ce qui précède |

## 8. Erratum, 2026-10-10 au soir : PC2 ne s'est **pas** mis en veille

Ce rapport (§5), `network.log` (ligne `sleep`) et la ligne de la matrice de `CLAUDE.md`
disaient que PC2 s'était mis en veille quelques minutes après le passage 1. **C'est faux**,
et c'est le propriétaire de PC2 qui l'a signalé. Le journal système de PC2 ne contient
**aucune** mise en veille entre 18:20 et 19:05 : il tourne depuis 17:52 sans interruption.

La vraie cause est **NetworkManager**. Sur un câble direct, il n'y a pas de serveur DHCP.
Le profil « Wired connection 1 » échoue donc au bout de 45 s (`ip-config-unavailable`),
retire l'adresse et recommence. Le cycle est de 4 essais, soit environ 3 minutes avec
adresse, puis 5 minutes sans. Les horodatages de PC2 concordent à la seconde :

| Événement | Heure (CEST) | Phase de NetworkManager |
|---|---|---|
| échec SSH | 18:41:10 | pause, 18:36:33 → 18:41:33 |
| **passage 1** | **18:43:03** | salve, 18:41:33 → 18:44:33 |
| tentatives des passages 2 et 3 | ≈ 18:45 → 18:47 | pause, 18:44:33 → 18:49:33 |

Le même cycle explique les connexions intermittentes que `network.log` attribuait à une
entrée de voisinage « qui vieillit au repos ». `network.log` est laissé tel qu'il a été
écrit, puisque c'est ce que je croyais alors, et ce paragraphe le corrige. Les passages
répétés ont été faits ensuite par `tools/twohost_campaign.sh`, qui attend une fenêtre de
NetworkManager : voir `../twohost-campaign/`.

## 9. Exposition pendant ce passage

Pendant ce passage, la passerelle écoutait sur `[::]:15711`, c'est-à-dire toutes les
interfaces IPv6 de PC1, avec le pare-feu désactivé. Or l'interface Wi-Fi de PC1 porte deux
adresses IPv6 **globales**, sur le préfixe du fournisseur d'accès. Pendant environ 30
minutes, la passerelle était donc joignable au-delà du câble, sauf si le routeur domestique
bloque l'IPv6 entrant non sollicité, ce qui n'a pas été vérifié.

Seul un ordre signé par une clé inscrite pouvait agir, et l'« appareil » était un simulateur
sur la boucle locale : l'exposition réelle était faible. Mais c'est un défaut d'hygiène de
test, et il est corrigé dans la campagne qui suit : la phase câble se lie à la seule adresse
lien-local, et la phase LAN à la seule adresse IPv4 privée.
