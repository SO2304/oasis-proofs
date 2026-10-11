# Fuzz — la porte d'entrée du chemin TCP n'avait jamais été fuzzée (pilote A.8)

**2026-10-09, empreinte `d8a3164`.** `cargo-fuzz 0.13.2`, `+nightly-2025-11-21`, ASan,
Windows — la même chaîne que les campagnes du 2026-10-07 et du 2026-10-08, pour que les
chiffres se comparent. Reproduire :

```bash
bash evidence/fuzz/2026-10-09/run_fuzz_a8.sh 240
```

| Cible | Exécutions | Débit | Couverture | Plantages |
|---|---:|---:|---|---:|
| [`modbus_tcp`](modbus_tcp.log) | **22 480 724** en 240 s | 93 281/s | 155 arêtes, 158 traits, corpus 23 u. / 301 o, 28 nouvelles | **0** |
| [`link_frames`](link_frames.log) | **755 798** en 240 s | 3 136/s | 466 arêtes, 1 634 traits, corpus 543 u. / 110 Ko, **2 070 nouvelles** | **0** |

RSS maximal 593 et 658 Mo. Unité la plus lente : 0 s dans les deux cas.

## 1. Ce que la phase demandait, et le trou trouvé en le vérifiant

La phase A.8 demande de fuzzer « les parseurs ajoutés depuis la dernière campagne
(`ORV1` sur TCP, trames de lien, configuration) ». En allant voir ce qui était déjà
couvert :

| Demandé | État réel |
|---|---|
| `ORV1` sur TCP | `parse_orv1`, `parse_revocation_body` et `parse_oep1` sont fuzzés **depuis le 2026-10-07** par la cible `revocation`. Le parseur était couvert ; ce qui ne l'était pas, c'est le **cadrage** qui l'apporte. Le revendiquer comme nouveau ici serait malhonnête |
| Trames de lien | **Pas fuzzées.** `read_frame` et `modbus_read_request` prenaient un `TcpStream` concret, donc aucune cible ne pouvait les atteindre. Ils sont génériques sur `Read` depuis aujourd'hui — un `TcpStream` satisfait toujours la contrainte, donc aucun appelant ne change |
| Configuration | **Pas fuzzée.** `Config::load` lit un fichier ; `Config::from_text` a été extraite pour que le parseur tourne sans disque |

Et, en cherchant, un trou que la phase ne demandait pas :

> **`parse_tcp_write` et `check_tcp_response` n'avaient jamais été fuzzés.**

`parse_tcp_write` est la **première** chose que l'agent exécute sur des octets venus
d'une IHM, et `check_tcp_response` la première que la passerelle exécute sur des octets
venus de l'automate. La cible `modbus` existante couvre `parse_omb1` et
`modbus_gateway::check_response` — qui est le vérificateur **RTU**, sur une trame RTU,
une fonction différente. L'affirmation du dépôt sur les parseurs fuzzés (`SECURITY.md`,
C10) avait donc un trou exactement là où le chemin TCP commence.

## 2. Ce que les cibles vérifient, au-delà de « ça ne plante pas »

Un harnais qui n'appelle qu'une fonction ne teste que l'absence de panique. Ceux-ci
affirment des propriétés :

**`modbus_tcp`**

1. une écriture acceptée a `count` dans `1..=MAX_REGS` et une fonction qui est FC06 ou
   FC16 — les bornes dont dépend `to_order` ensuite ;
2. l'écho que recevrait l'IHM est une trame Modbus bien formée : **la longueur MBAP
   décrit la trame où elle se trouve**, le bit d'exception est à zéro, et le `tid` est
   celui de la requête ;
3. `check_tcp_response` ne rend `Ack` que pour une réponse dont le `tid` **et** l'unité
   correspondent — un appareil qui répond pour la transaction d'un autre est la façon
   dont une connexion tenue se désynchronise.

**`link_frames`**

1. une trame de lien rendue est non vide, sous le plafond `MAX_LINK_FRAME`, **de la
   longueur exactement annoncée** par son préfixe, et composée des octets qui suivaient
   ce préfixe — un lecteur qui rend plus ou moins que ce qu'il a promis est l'autre façon
   de désynchroniser un flux ;
2. une trame Modbus rendue porte sa propre longueur (`len == 6 + rest`), avec `rest` dans
   `1..=260`, et l'en-tête ressort inchangé ;
3. une configuration acceptée est cohérente là où la porte s'y fie : `timeout_ms > 0`, et
   `min <= max` pour **chaque** règle de registre, carte partagée et carte par origine
   comprises. Un refus doit porter une raison : un `Err("")` n'est pas un refus.

## 3. Résultat

**0 plantage** sur 23 236 522 exécutions au total, et aucun artefact produit. Zéro n'est
pas la valeur par défaut de ce harnais : la campagne du 2026-10-07 avait trouvé un défaut
de **canonicalisation** dans `OAC1` — les octets réservés n'étaient pas tenus d'être nuls,
donc deux encodages différents du même ordre étaient acceptés — corrigé dans `f26195b`
avec le test `act_oac1_reserved_bytes_must_be_zero`, et le reproducteur est gardé
([`oac1_noncanonical_reproducer.bin`](../2026-10-07/oac1_noncanonical_reproducer.bin),
54 octets, trouvé par la cible `actuation`).

⚠️ Et deux tailles différentes : le 2026-10-07 tournait **3 600 s par cible**, ici
**240 s**. Ces chiffres disent « rien trouvé en 240 s », pas « rien à trouver ».

La couverture dit où le temps est passé. `modbus_tcp` est une petite surface entièrement
explorée : 155 arêtes, un corpus qui plafonne à 23 unités, 93 000 exécutions par seconde.
`link_frames` est l'inverse — 466 arêtes, 1 634 traits, **2 070 nouvelles unités** — et
c'est ce qui coûte le débit : 3 136/s contre 93 281. Le parseur de configuration alloue,
et tente d'ouvrir les fichiers de graine que le texte nomme, donc chaque exécution touche
le disque. Un débit trente fois plus faible pour une couverture trois fois plus large est
le bon côté de l'échange.

## 4. Ce que cette campagne ne montre pas

- **240 s par cible**, pas une nuit. La campagne du 2026-10-07 tournait plus longtemps ;
  ces chiffres disent « aucun défaut trouvé en 240 s », pas « aucun défaut ».
- **Pas de corpus de départ** : les deux cibles partent du corpus accumulé par leurs
  propres exécutions, sans dictionnaire ni graines écrites à la main. Un dictionnaire des
  mots-clés de configuration (`register`, `peer_pk`, `origin_register`) irait plus loin
  plus vite.
- **`read_frame` et `modbus_read_request` sont fuzzés sur un `&[u8]`**, pas sur une
  socket : le flux est donc complet et immédiat. Une lecture partielle, un pair qui
  s'arrête au milieu d'un corps, un délai expiré — ce sont les cas que la socket apporte
  et que ceci ne couvre pas. Les tests de `mbtcp_net` en couvrent une partie
  (`a_silent_peer_times_out`, une longueur de 4 Gio annoncée pour quatre octets envoyés).
- **La configuration n'est pas une surface réseau.** Elle est atteinte par qui peut
  écrire dans `/etc/oasis`, donc ce n'est pas une défense contre un attaquant : c'est la
  garantie qu'un intégrateur qui édite un fichier à la main obtient une erreur et jamais
  une panique.
- **Rien ici ne concerne le silicium** ni la couche mesh, déjà couvertes par les cibles
  du 2026-10-07.

## 5. Un défaut de mon propre script, dit parce qu'il était vert

La première exécution a annoncé « **0 plantage** » pour deux campagnes qui **n'avaient
pas tourné** : la redirection `> "../$HERE/$t.log"` est évaluée dans le répertoire du
parent, donc hors du dépôt, et le journal n'existait pas ; `grep -q` sur un fichier
absent rend non-zéro, ce qui prenait la branche « pas de plantage ». Un verdict ne doit
jamais être atteignable sans la preuve dont il est le verdict. Le script **abandonne**
maintenant si le journal est vide, ou s'il n'y trouve pas la fin d'une campagne
(`Done N runs`).

C'est le cinquième harnais vert-pour-rien de la journée, tous du même genre : un contrôle
qui passe parce que son sujet est absent, sa mutation inopérante, ou son processus déjà
mort.
