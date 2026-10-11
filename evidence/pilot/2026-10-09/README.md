# Ce PC comme automate de test — HMI → agent → passerelle → appareil, en vrais processus

**2026-10-09.** Trois exécutions, **69 cas sur 69** chacune. Reproduire :

```bash
cargo build --release -p oasis-rt -p oasis-test-plc
bash tools/pilot_campaign.sh /tmp/camp
```

| | |
|---|---|
| Résultat | **69/69**, trois fois ([`run1.log`](run1.log), [`run2.log`](run2.log), [`run3.log`](run3.log)) |
| Écritures appliquées par l'appareil | 208 par exécution, comptées **par l'appareil** |
| Latence bout en bout | **849 / 609 / 725 µs** médiane, ±**18 / 31 / 23 %** (K=10 × 20, une socket tenue) — lus dans [`run1.log`](run1.log), [`run2.log`](run2.log), [`run3.log`](run3.log) |
| Journal | **intact, exit 0**, et un refus réécrit en acceptation → **exit 1** |

## 1. Pourquoi ce n'est pas le test d'intégration qui existait déjà

`oasis-rt/tests/mbtcp_pilot_sockets.rs` passe par de vraies sockets, mais tout vit dans un
seul processus de test : il prouve la **bibliothèque**. Cette campagne lance les
**binaires livrés**, donc elle exerce ce qu'aucun test en processus ne touche — fichiers de
configuration, graines lues sur disque, écouteur, fil par connexion, **fichier de séquence
persisté**, **compteur d'émission persisté**, **journal sur disque**, et un **redémarrage**
de chaque processus.

```text
hmi_client.py  --Modbus TCP-->  oasis_mbtcp_agent  --v0B-->  oasis_mbtcp_gateway
                                                                    |
                                                          Modbus TCP v
                                                            oasis_test_plc  (rmodbus)
```

**Aucune des deux extrémités n'est du code OASIS, et c'est vérifiable** :
`oasis-test-plc/Cargo.toml` dépend de `rmodbus` et **pas** de `oasis-rt` ; le client est du
Python sans aucun import. Quand l'appareil applique une trame, OASIS ne se donne pas raison
à lui-même — la même propriété que la carte A sous `rmodbus` en phase 1.4.

## 2. Les 69 cas

| # | Ce qui est vérifié | Vérité de terrain |
|---|---|---|
| C1 | une écriture légitime atteint l'appareil, qui **garde la valeur** | compteur et registre imprimés **par l'appareil** |
| C2 | registre hors carte → 0x02, **l'appareil n'est pas interrogé** | compteur inchangé |
| C3 | valeur hors plage → 0x03, idem | compteur inchangé |
| C4 | une **lecture** traverse la passerelle et rend ce que l'appareil détient | `values=500` |
| C5 | lecture hors carte → 0x02 sans interroger l'appareil | compteur inchangé |
| C6 | du Modbus brut **sur le port de la passerelle** n'atteint pas l'appareil | `NOANSWER`, compteur inchangé |
| C7 | la séquence de l'agent **survit à un redémarrage** et ne se réutilise pas | fichier 64 → 128, écriture acceptée après |
| C8 | le journal est **sur disque** et vérifie avec le vérificateur indépendant | `exit 0`, acceptations **et** refus nommés |
| C9 | un **refus réécrit en acceptation** est détecté | `exit 1` |
| C10 | un redémarrage de passerelle change le `boot_id` et ouvre une chaîne neuve, intacte | deux `JRN_BOOT` différents, deux `exit 0` |
| C11 | la latence à travers les **vrais binaires** | 711–951 µs, ±15–23 % |
| C23 | l'agent écrit **son** registre | accepté, l'appareil compte une écriture |
| C24 | l'agent **ne peut pas** écrire le registre de l'autre, bien qu'il soit dans la carte de la passerelle | `RegisterNotAllowed(12)`, appareil intact |
| C25 | la **plage** est par origine : 500 refusé à hmi2 (plafond 9), autorisé à l'agent (plafond 1000) sur le **même** registre | `ValueOutOfRange(10, 500)` |
| C26 | chaque refus est **attribué** à son origine | `origin=aa00` et `origin=ee00` |
| C27 | compter par origine **n'affaiblit pas** l'anti-rejeu de cette origine | `Reject(StaleOrReplayed)`, `origin=ee00` |
| C19 | un `ORV1` signé par **deux opérateurs distincts** satisfait k=2 de n=3 | `REVOCATION Applied`, `Change(Revocation) flags=0x10` |
| C20 | **une** signature ne satisfait pas k=2 | `Reject(BadOperatorSig)`, journalisé non appliqué |
| C21 | **le même opérateur deux fois** ne fait pas deux voix | `Reject(BadOperatorSig)` |
| C22 | le coût du quorum, K=10 | 110 µs (une clé), 234 µs (k=2), 318 µs (k=3) |
| C15 | un `ORV1` **signé** arrive sur le lien, est appliqué, et **le changement est journalisé** | `Change(Revocation)`, `flags=0x10`, `origin=bb00` |
| C16 | une époque non supérieure est refusée, **et le refus est journalisé aussi** | `Change(Revocation)`, `flags=0x00` |
| C17 | une liste signée par un opérateur non approuvé est refusée et journalisée | `Reject(BadOperatorSig)`, `flags=0x00` |
| C18 | un pair **sans la permission `ACTUATE`** ne peut pas commander, **bien que sa clé soit connue** | `Reject(NotAuthorized)`, `origin=bb00`, compteur inchangé |
| C12 | un ordre adressé à **un autre `gateway_id`** est refusé | 0x0A, journal `Reject(NotAuthorized)`, compteur inchangé |
| C13 | une origine **révoquée** est refusée — **au niveau mesh, au-dessus du portail** | `MESH_DROP why="origin revoked"`, journal `Reject(NotVerified)` |
| C14 | le journal **attribue** la décision à une origine | `origin=aa00` sur une décision vérifiée |

## 3. Trois défauts trouvés en faisant tourner les vrais programmes

Aucun n'était visible depuis un test en processus. C'est la raison d'exister de cette
campagne.

### 3.1 Le journal de la passerelle n'était pas écrit du tout

`handle_frame` appelait `Journal::append`, **jetait les octets rendus**, et gardait la
chaîne en RAM : le journal mourait avec le processus, pendant que `CLAUDE.md` écrivait
« appends **every** decision to the journal, refusals included ». C'était vrai et sans
valeur — l'annexe III 1.1.9 alinéa 5 demande de **recueillir** la preuve, et un
enregistrement qui disparaît à la sortie ne recueille rien. Le firmware RP2040 persistait
via `jstore` depuis le début ; la passerelle hôte, jamais.

Corrigé : `JournalSink`, deux fichiers, **entrée d'abord puis tête** comme `jstore` sur le
MCU, au format que `oasis_journal_verify` lit déjà. Et toutes les écritures passent par
**une** fonction, pour qu'une branche future ne puisse pas enregistrer en RAM seule en
oubliant une ligne — ce à quoi ressemblait exactement le défaut d'origine.

### 3.2 L'agent se verrouillait lui-même hors de sa passerelle après un redémarrage

C7 a échoué d'abord : toute écriture après un redémarrage de l'agent revenait en exception
0x0B. La séquence d'ordre était persistée (`SeqStore`), mais le **compteur d'émission v0B**
ne l'était pas : un agent redémarré repartait à 1 et la fenêtre anti-rejeu de la passerelle
refusait ses enveloppes comme périmées — **correctement**. `tx_lease` résout exactement ce
problème sur le MCU et a été prouvé sur silicium à travers une coupure réelle ; l'agent hôte
ne l'avait simplement jamais eu, et aucun test en processus ne redémarre un processus.

Corrigé : `TxCounterStore`, même bail que la séquence (256 compteurs par écriture), même
garantie — un plantage en perd jusqu'à 256 et n'en **réutilise** jamais un.

### 3.3 Une écriture coûtait 13,2 ms, dont 12 de réouverture de fichiers

La première version de `JournalSink` rouvrait les deux fichiers à chaque décision :
13 203 µs par écriture autorisée contre ~460 µs en processus. En gardant les deux
descripteurs ouverts et en réécrivant la tête sur place : **1 230 µs**, soit **11× moins**,
et l'ordre de durabilité est identique. `TCP_NODELAY` a aussi été posé sur la socket face à
l'HMI — la passerelle et le lien vers l'appareil l'avaient, celle-là non — mais ce n'était
**pas** la cause : la mesure n'a pas bougé, et c'est dit ici plutôt que présenté comme un
gain.

Reste donc ~140 à 390 µs au-dessus du chiffre en processus : les deux `flush` du journal et
les frontières de processus. **La preuve coûte de la latence**, et le chiffre honnête est
**609–849 µs** par écriture autorisée (médianes des trois exécutions), journal persisté
compris.

⚠️ Ce paragraphe a porté « 1,2 ms » jusqu'au 2026-10-09 alors que le tableau d'en-tête du
même document donnait déjà 711–951 µs : le 1,2 ms datait de l'exécution où le défaut des
13,2 ms venait d'être corrigé, et la phrase n'avait pas suivi les mesures suivantes. Une
incohérence **interne au document de preuve**, trouvée en recomptant, et corrigée ici plutôt
que laissée au lecteur.

## 3ter. Le journal des changements (1.1.9 al. 5) est enfin **démontré**

Il était implémenté, **vérifié 6/6 par Kani**, et démontré **nulle part** : son câblage
firmware compile et aucune carte n'a été reflashée. Un `ORV1` signé appliqué sur ce lien
est un changement de configuration — qui peut commander — donc C15–C17 l'exercent bout en
bout, par les binaires livrés, **sans carte** :

```text
[206] seq=206 origin=bb00 cmd_seq=1 decision=Change(Revocation) flags=0x10   <- appliqué
[207] seq=207 origin=bb00 cmd_seq=1 decision=Change(Revocation) flags=0x00   <- refusé (époque)
[208] seq=208 origin=bb00 cmd_seq=1 decision=Change(Revocation) flags=0x00   <- refusé (opérateur)
```

C'est exactement ce que l'alinéa demande : « légitime **ou illégitime** ». Les trois sont sur
la **même** chaîne que les décisions, attribués à l'opérateur (`bb00`), et la chaîne reste
`VERDICT intact`. La passerelle nomme chaque verdict distinctement : `Applied`,
`Duplicate`, `Reject(BadOperatorSig)`.

L'ordre des opérations est celui que la spécification fixe et que le silicium a prouvé :
vérifier, **persister avant d'appliquer**, puis appliquer. ⚠️ **Un seul opérateur** :
`oasis-operator-key` est une dépendance de **développement** de `oasis-rt`, donc le k parmi n
n'est pas atteignable ici et une liste portant plusieurs signatures est **refusée par son
nom** plutôt qu'acceptée sur la force de l'une d'elles.

## 3bis. Le portail tournait sur trois entrées constantes

Trouvé en relisant ce que la campagne exerçait réellement. Le portail est bien celui de la
partie F, **inchangé** — mais il ne vaut que ce qu'on lui donne, et la voie TCP lui donnait :

```rust
OrderContext { v0b_ok: true, authorized: true, revoked: false, ..., r14_safe: true }
```

là où le firmware lui donne `registry.allows(origin, ACTUATE)`, `router.is_revoked(origin)`
et `efs.r14_safe_now()`. Conséquences, et ce qui en a été fait :

- **`gateway_id` n'était jamais comparé.** Le firmware plie cette comparaison dans
  `authorized` ; la voie TCP la codait à `true`, donc la passerelle 1 exécutait un ordre
  adressé à la passerelle 7. C'est le défaut réel des trois, et **C12** le montre : mêmes
  clés, `gateway_id = 7`, refus 0x0A, `Reject(NotAuthorized)` au journal, appareil intact.
- **La révocation ne faisait rien** sur cette voie. Elle en fait maintenant — mais **C13**
  montre que le vrai garde-fou est **une couche au-dessus** : v0B jette une origine révoquée
  au premier saut, avant même de vérifier sa signature, donc l'entrée `revoked` du portail
  est de la **défense en profondeur** et ne se déclenche pas ici. C'est dit comme ça plutôt
  que de laisser croire que le portail a arrêté quelque chose. ⚠️ La liste est de
  **configuration** : un `ORV1` signé sur ce lien n'est pas traité, et c'est le manque.
- **Le journal écrivait `origin=0000`** à chaque entrée : il disait qu'une décision avait eu
  lieu, pas **qui** l'avait causée, alors que l'alinéa 5 parle d'une intervention
  légitime *ou illégitime* — une affirmation d'attribution. **C14** : `origin=aa00` sur une
  décision vérifiée. Et `0000` est **conservé** sur une enveloppe rejetée, délibérément :
  son champ d'origine est contrôlé par l'attaquant jusqu'à vérification de la signature, et
  inscrire une prétention non vérifiée dans la preuve est pire que de n'en inscrire aucune.

Deux des quatre constantes restent, en commentaires et non en code : `v0b_ok` est vraie par
construction (la couche mesh a vérifié l'enveloppe au-dessus) et `r14_safe` n'a **aucun
capteur à lire** sur un hôte — une passerelle colocée avec de la mesure devra l'alimenter.

**Les permissions sont arrivées le 2026-10-09**, avec le modèle du firmware et non un
schéma parallèle : `enrollment::Registry`, `Entry` et `allows` sont publics, donc la voie
TCP consulte **le même type et la même règle**. Un troisième champ sur la ligne `peer`
les porte (`peer = <fp>,<seed>,ACTUATE|STOP`), et c'est **fail closed** : une ligne sans
troisième champ n'accorde rien et ses ordres sont refusés. C'est une rupture pour toute
config écrite avant, délibérément — le défaut inverse accorderait l'actionnement à chaque
clé du fichier. La passerelle imprime la table au démarrage pour qu'un opérateur lise
`permissions=none` tout de suite au lieu de le déduire d'un refus.

**C18** est le test honnête de la permission et non de la clé : la clé du nœud opérateur
**est** dans le registre de la passerelle — elle doit l'être, sinon ses listes de
révocation seraient jetées comme venant d'un inconnu — et elle n'a pas `ACTUATE`. Son
ordre est refusé `Reject(NotAuthorized)`, attribué à `bb00`, l'appareil intact.

⚠️ Toujours **config-time** : une attestation `OAU1` signée par le propriétaire sur ce
lien reste à faire, comme pour la révocation avant C15. Un opérateur édite le fichier et
redémarre.

## 4. Sept défauts de la campagne elle-même

Écrits ici parce qu'un harnais qui mentait une fois mentira encore.

1. **Cinq cas « PASS » alors que rien ne tournait.** La première exécution lançait les
   trois processus, qui mouraient tous (chemins MSYS dans les configs, illisibles pour des
   binaires Windows natifs), et les onze cas tournaient contre du vide. Trois sont passés
   en comparant `"0\n0"` à `"0\n0"` — `grep -c` rend 1 quand il ne trouve rien, donc le
   repli `|| echo 0` s'ajoutait à son propre `0`. Corrigé par un compteur `awk` qui rend
   toujours un entier, **et** par une barrière de disponibilité qui **abandonne** si l'un
   des trois ports n'accepte pas de connexion. Une connexion refusée ressemble à un ordre
   refusé pour qui ne vérifie que « est-ce que ça a échoué ».
2. **Un contrôle négatif qui ne mutait rien.** C9 cassait un octet de décision à l'entrée 0,
   qui était un `Act` dont l'octet valait déjà `00` : il écrivait `00` sur `00`, ne changeait
   rien, et concluait « falsification NON détectée » à propos d'une mutation inexistante. Il
   cherche maintenant une entrée dont l'octet n'est pas `00`, et **abandonne** s'il n'en
   trouve aucune.
3. **Une latence de 151 ms.** C11 lançait un processus Python par écriture et appelait le
   résultat une latence. Mesuré dans un seul processus sur une socket tenue : 609–849 µs.
4. **C12 passait sur le mauvais refus.** Le second agent avait ses propres fichiers de
   séquence et de compteur — ils sont nommés d'après le **fichier de config**, alors qu'ils
   appartiennent à l'**identité** — donc son compteur v0B repartait à 1, la fenêtre de la
   passerelle refusait l'enveloppe comme périmée, et le cas était vert sur un 0x0B sans que
   l'ordre ait jamais atteint le portail. Corrigé en partageant les deux fichiers ; la note
   de conception est que ces chemins devraient dériver de l'empreinte, pas du nom de
   fichier.
5. **Un `sed` coupé en deux.** Un patch avait écrit un vrai retour à la ligne dans
   l'expression `sed` qui ajoutait la ligne `revoked`, ce qui cassait la commande en deux et
   produisait une config que la passerelle refusait (`missing network_id`). Remplaçé par un
   `cat` + `echo`.
6. **C14 passait sur une chaîne vide.** Il ne testait que l'égalité à `origin=0000`, donc la
   valeur vide laissée par un C13 en échec passait. Un cas qui passe quand son entrée manque
   est pire que pas de cas.
7. **C15–C17 tournaient sous l'identité de l'agent**, placés après C13 qui venait de la
   révoquer : la couche mesh jetait l'enveloppe de l'outil et **C16 et C17 étaient verts
   pour la mauvaise raison** — l'outil échouait par révocation, pas par époque ni par
   signature. Corrigé en donnant à l'outil **sa propre identité mesh** (`bb00`, ce qu'un
   opérateur est de toute façon) et en plaçant les trois cas avant C12. Et l'outil
   persiste désormais son compteur d'émission : trois invocations d'un outil à usage unique
   repartaient toutes à 1, donc la deuxième était refusée comme un rejeu. Le compteur
   appartient à l'identité, pas au processus — pour la deuxième fois dans cette campagne.

## 4bis. Deux défauts de preuve corrigés le 2026-10-09

Trouvés par un audit externe, vérifiés ici contre l'arbre, et tous deux de mon fait.

1. **La latence annoncée ne venait pas des journaux.** Ce README disait
   « 1 017 / 1 159 / 1 248 µs, ±8–15 % » pendant que les journaux posés à côté disaient
   autre chose. Les chiffres ci-dessus sont désormais **lus dans les trois journaux
   archivés**, et `tools/check_claims.sh` compare désormais les deux à chaque passage.
   ⚠️ L'écart entre exécutions est large : le même code a mesuré 697–771 µs dans une
   série antérieure et 1 165–1 274 µs dans celle-ci. Un seul tir ne veut rien dire ici, et
   la fourchette honnête est **0,7 à 1,3 ms** selon la charge de la machine.
2. **L'empreinte des journaux ne désignait pas le code testé.** Les trois journaux
   portaient `tree=6865f43` alors qu'ils exerçaient les cas C18 (permissions), dont le code
   n'était **pas encore commité** au moment de la mesure : le script imprime
   `git rev-parse HEAD`, qui pointait sur le commit précédent. Une preuve qui nomme un
   commit ne contenant pas ce qu'elle a mesuré n'est pas une preuve. La règle en est
   simple : **commiter d'abord, mesurer ensuite**. Les journaux portent maintenant
   `tree=97a4441`, qui contient bien les 47 cas.

## 4ter. Un cycle de dépendances coûtait une capacité entière

La passerelle refusait **toute** liste multi-signée, par son nom, et la raison n'était pas
cryptographique : `OperatorAuthority` vit dans `oasis-operator-key`, qui déclarait une
dépendance vers `oasis-rt`. Comme `oasis-rt` a besoin de ce crate pour les tests de quorum,
cela formait un **cycle** — toléré dans un espace de travail — et un cycle oblige l'une des
deux arêtes à être une dépendance de développement. Or **un `[[bin]]` ne peut pas utiliser
une dépendance de développement**. D'où le refus.

Le cycle était un artefact : `grep -rn oasis_rt oasis-operator-key/src/` ne rend **rien** —
seuls ses tests et ses exemples s'en servent. Déplacé dans *ses* dépendances de
développement, le cycle disparaît, `oasis-rt` prend ce crate normalement (optionnel, derrière
`std`, car un quorum ne se vérifie que sur un hôte) et la règle de quorum revient à celui qui
la possède.

Ce que cela apporte en plus du simple fait de fonctionner : `verify_authorization` exige **k
clés distinctes**. Le contrôle à une clé écrit à la main que cette fonction remplace n'avait
pas cette propriété, et **C21** la montre — le même opérateur signant deux fois est une voix,
pas deux. Un quorum de clés identiques n'en est pas un, et la configuration refuse aussi un
doublon dans ses propres lignes `operator`.

⚠️ **Un quorum n'est pas un limiteur de débit**, et la mesure le dit dans le sens inverse de
l'intuition : un refus coûte environ **une** vérification (le vérificateur s'arrête dès que
l'issue est jouée), mais un attaquant qui présente n signatures bien formées fait quand même
faire n vérifications à la passerelle avant qu'elle puisse juger le compte. C'est borné par
le n de la configuration, pas par l'attaquant.

⚠️ **Rien sur silicium** : aucune carte ne détient un *jeu* de clés opérateur, donc le k
parmi n sur un nœud reste non démontré.

## 5. Ce que cette campagne ne prouve pas

- **Ce n'est pas un automate.** `oasis_test_plc` est un simulateur d'appareil : pas de cycle
  de scrutation, pas de logique à relais, pas d'E/S, pas de temps réel, et il répond
  instantanément là où un automate prend des millisecondes. Il rend **le protocole et le
  chemin d'autorisation** réels ; il ne rend pas la machine réelle. La latence mesurée à
  travers lui est un **plancher**.
- **Une seule machine, en loopback.** Pas de réseau, pas de commutateur, pas de radio, pas
  de RS-485. Les trois processus partagent un ordonnanceur et un cache.
- **L'injection Modbus brute ne laisse aucune entrée de journal.** Ses quatre premiers
  octets ne sont pas un préfixe de longueur valide, donc `read_frame` la refuse avant
  qu'elle devienne une décision. Rien n'atteint l'appareil — c'est la propriété de sûreté —
  mais il n'y a **pas de trace de la tentative**. Ne pas la journaliser est délibéré (une
  inondation au niveau du cadrage évincerait l'historique des commandes de l'anneau, la même
  raison que pour les lectures), donc c'est une **limite connue de la piste d'audit**, pas
  un oubli. C'est écrit dans le log de chaque exécution.
- **Les ordres sont servis un à la fois** : le verrou d'état couvre l'aller-retour vers
  l'appareil. Correct pour un appareil, plafond de débit pour un parc.
- **Aucun ordre d'autorité** ne passe par ce chemin, donc le journal des **changements**
  (1.1.9 al. 5, 2ᵈ et 3ᵉ déclencheurs) n'est pas exercé ici : il l'est par ses tests et ses
  6 harnais Kani, et son câblage firmware n'a pas été flashé.
