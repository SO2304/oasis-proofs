# Installer la passerelle OASIS Modbus TCP — guide d'intégrateur

Ce document est écrit pour la personne qui installe, pas pour celle qui développe. Il
suppose que vous savez câbler un réseau industriel et lire une trame Modbus, et il ne
suppose rien d'OASIS.

> **À lire avant tout le reste.** OASIS n'est **jamais** dans la chaîne d'arrêt
> d'urgence. Ce n'est pas une fonction de sûreté, ni certifiée SIL, ni certifiée PL. Les
> arrêts d'urgence, les barrières immatérielles, les interverrouillages et tout ce qui
> relève d'ISO 13849 ou d'IEC 62061 restent **entièrement** dans le système de commande
> de sûreté existant de la machine, sur leur propre câblage, et doivent fonctionner
> identiquement si la passerelle est éteinte, débranchée ou en panne. OASIS décide
> seulement si une **écriture de commande** venue du réseau est autorisée, et garde la
> trace de cette décision. Si vous êtes en train d'imaginer un chemin où un arrêt passe
> par ce logiciel, arrêtez-vous et revoyez l'architecture.

---

## 1. Ce que ça fait, en une phrase et un schéma

Une IHM ou un SCADA écrit dans un automate. Entre les deux, OASIS exige que l'écriture
soit **signée par une clé connue**, **autorisée pour ce registre et cette plage**,
**fraîche**, et **non rejouée** ; et il écrit chaque décision — acceptée **ou refusée** —
dans un journal chaîné.

```text
   côté opérateur                                   côté machine
 ┌───────────────┐   Modbus TCP    ┌───────────┐  ordre signé  ┌────────────┐  Modbus TCP   ┌──────────┐
 │ IHM / SCADA   │ ──en clair────▶ │  agent    │ ──(v0B)─────▶ │ passerelle │ ──────────▶   │ automate │
 │ (non modifié) │ ◀──ack ou ──── │  OASIS    │ ◀──réponse─── │   OASIS    │ ◀─────────    │(non mod.)│
 └───────────────┘   exception     └───────────┘               └────────────┘               └──────────┘
```

**Un seul chemin.** Toute la valeur de ce montage tient à une chose : l'automate ne doit
être joignable que par la passerelle. Si l'IHM, un PC de maintenance, un variateur ou un
ordinateur portable de passage peut écrire directement dans l'automate, OASIS ne protège
rien — il ajoute seulement de la latence sur un chemin parmi d'autres. C'est une
contrainte de **réseau**, pas de logiciel, et c'est la première chose à vérifier et la
première à se dégrader avec le temps.

En pratique : l'automate sur un segment dédié (VLAN ou commutateur séparé), une seule
route vers lui, celle de la passerelle, et le port Modbus fermé à tout le reste par la
configuration du commutateur ou un filtrage sur l'hôte de la passerelle.

---

## 2. Matériel et système

| | Minimum | Remarque |
|---|---|---|
| Hôtes | 2 (côté opérateur, côté machine) | Un seul hôte fonctionne et **annule l'intérêt** : les deux moitiés tombent ensemble |
| CPU / RAM | tout x86-64 ou ARM64 sous Linux, 256 Mo | Le coût est de l'ordre de 0,5 ms par écriture autorisée ; ce n'est pas un problème de puissance |
| Réseau | 100 Mbit/s suffit | Une écriture fait quelques centaines d'octets |
| Système | Linux avec systemd | Les unités fournies sont dans [`deploy/`](../deploy/) |

⚠️ **Non testé sur automate du commerce.** Tous les chiffres de ce dépôt viennent d'un
simulateur bâti sur `rmodbus` qui ne dépend pas d'OASIS, sur un seul hôte en boucle
locale. Le protocole et le chemin d'autorisation sont réels ; la machine ne l'est pas, et
les latences sont un **plancher**. Votre première mise en service est donc aussi le
premier essai sur un automate réel : prévoyez-la en atelier, pas en production.

---

## 3. Installer

```bash
# Sur chaque hôte, en tant que root.
useradd --system --home-dir /var/lib/oasis --create-home --shell /usr/sbin/nologin oasis
install -d -o oasis -g oasis -m 0750 /etc/oasis /var/lib/oasis
install -m 0755 oasis_mbtcp_agent oasis_mbtcp_gateway oasis_mbtcp_order \
                oasis_mbtcp_revoke oasis_journal_verify /usr/local/bin/
```

Construction depuis les sources :

```bash
cargo build --release -p oasis-rt --bins   # binaires dans target/release/
```

---

## 4. Les clés, et la seule erreur à ne pas faire

Chaque nœud a une graine Ed25519 de 32 octets, en hexadécimal dans un fichier, et une
empreinte de 8 octets qui l'identifie sur le réseau.

```bash
# Une graine par nœud, sur l'hôte de ce nœud, jamais ailleurs.
umask 077
head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > /etc/oasis/this_node.seed
chown oasis:oasis /etc/oasis/this_node.seed
chmod 0400 /etc/oasis/this_node.seed

# La clé publique à donner à l'autre hôte :
oasis_mbtcp_revoke --print-pub /etc/oasis/this_node.seed
```

> **La graine est une clé privée. Elle ne quitte jamais son hôte.**
>
> La configuration accepte deux façons de déclarer un pair :
>
> ```ini
> peer_pk = aa00000000000000,<64 caractères hex de clé publique>,ACTUATE   # ✅ à déployer
> peer    = aa00000000000000,/etc/oasis/other.seed,ACTUATE                 # ❌ essais seulement
> ```
>
> La forme `peer` dérive la clé publique du pair à partir de sa **graine**, donc son
> fichier de configuration contient la **clé privée** de chaque nœud qu'il accepte —
> celle de l'opérateur comprise. Sur l'hôte côté machine, qui est le moins protégé des
> deux, cela veut dire que prendre cet hôte donne la capacité de **forger** les ordres
> que la passerelle est là pour vérifier. Sur un seul hôte de laboratoire les deux
> moitiés partagent un répertoire et ça ne se voyait pas. Utilisez `peer_pk`.

Notez l'empreinte de chaque nœud et **vérifiez-la de vive voix ou sur papier** avec la
personne qui a généré la graine, avant de l'écrire dans une configuration. Une empreinte
reçue par le même canal que la clé ne vérifie rien.

---

## 5. Les fichiers de configuration

Côté machine, `/etc/oasis/gateway.conf` :

```ini
# --- identité et réseau -------------------------------------------------------
listen      = 0.0.0.0:15041          # où l'agent se connecte
peer_addr   = 192.0.2.50:502         # l'automate. Modbus TCP, port 502
unit        = 0x11                   # l'identifiant d'unité de l'automate
timeout_ms  = 2000                   # délai réseau, dans les deux sens
network_id  = 4f415349536e6574       # 8 octets, identiques sur les deux hôtes
our_fp      = cc00000000000000       # l'empreinte de CET hôte
our_seed_file = /etc/oasis/this_node.seed
gateway_id  = 1                      # l'actionneur logique, pas l'unité Modbus

# --- qui a le droit d'écrire ---------------------------------------------------
# Troisième champ = permissions. ABSENT = AUCUN DROIT (fermeture par défaut).
# Une ligne sans permission reste utile : la clé est connue, donc ses messages sont
# vérifiés plutôt que rejetés comme inconnus — mais elle ne peut pas commander.
peer_pk = aa00000000000000,<clé publique de l'agent>,ACTUATE
peer_pk = bb00000000000000,<clé publique du poste opérateur>          # publie les révocations, ne commande pas

# --- ce qui est écrivable ------------------------------------------------------
# register = adresse,min,max     → la carte partagée, pour toute origine sans carte propre
register  = 10,0,1000
register  = 12,0,1000

# origin_register = empreinte,adresse,min,max  → la carte de CETTE origine.
# Dès qu'une origine a au moins une ligne, elle n'a QUE ses lignes : la carte partagée
# ne s'applique plus à elle. C'est ce qui permet « cette IHM déplace l'axe 1 entre 0 et
# 100, celle-là remet seulement le compteur à zéro ».
origin_register = aa00000000000000,10,0,1000
origin_register = ee00000000000000,12,0,5

# --- révocation ----------------------------------------------------------------
operator = <clé publique d'opérateur>    # répétable ; signe les listes de révocation
quorum   = 2                             # k parmi n. Absent = toutes les clés requises
revoked  = dd00000000000000              # révocation statique, en plus des listes signées
```

Côté opérateur, `/etc/oasis/agent.conf` : même forme, avec `listen` sur le port que
l'IHM utilise, `peer_addr` pointant sur la **passerelle**, et `peer_pk` déclarant la clé
publique de la passerelle.

Toute erreur de configuration est refusée **au démarrage**, jamais découverte au premier
ordre. Une ligne mal formée (`register`, `origin_register`, `peer`, `peer_pk`) est nommée
avec son numéro de ligne ; une clé obligatoire absente ou une valeur invalide est nommée
par son nom et le fichier, sans numéro de ligne.

`oasis_mbtcp_order` et `oasis_mbtcp_revoke` lisent une configuration de la **même forme**
que celle de l'agent — leur propre identité, et la passerelle comme `peer_addr`. Appelons
la `operator.conf` : c'est elle qu'utilise la mise en service ci-dessous, pour commander
sans passer par l'IHM.

---

## 6. Mise en service : la liste à cocher

Faites-la dans cet ordre, en atelier, automate **débranché de la machine**.

| | Essai | Attendu |
|---|---|---|
| 1 | `systemctl start oasis-mbtcp-gateway` puis `status` | actif ; toute erreur de configuration est dans le journal avec son numéro de ligne |
| 2 | `oasis_mbtcp_order --config /etc/oasis/operator.conf --reg 10 --value 700` | **sortie 0**, et l'automate porte 700 |
| 3 | Le même ordre, `--value 5000`, hors plage | **sortie 1**, exception **0x03**, automate **inchangé** |
| 4 | Le même ordre sur un registre absent de la carte | **sortie 1**, exception **0x02**, automate **inchangé** |
| 5 | Depuis l'IHM, une écriture normale | acquittée, automate à jour |
| 6 | Arrêtez la passerelle, écrivez depuis l'IHM | exception **0x0B** en moins de `timeout_ms`, **jamais** un silence, automate inchangé |
| 7 | Redémarrez l'agent, puis écrivez | acquittée. Un redémarrage ne doit pas verrouiller l'agent hors de sa passerelle |
| 8 | Depuis l'hôte de l'IHM, `telnet <automate> 502` | **doit échouer**. S'il réussit, le chemin unique n'existe pas et rien de ce qui précède ne protège la machine |
| 9 | Relisez le journal (§7) | `VERDICT intact`, **sortie 0**, et vos refus des essais 3, 4 et 6 y figurent nommément |

L'essai 8 est celui qu'on oublie et c'est le seul qui conditionne tous les autres.

---

## 7. Lire le journal

La passerelle écrit deux fichiers, l'entrée **avant** la tête, de sorte qu'une coupure
entre les deux laisse au plus une entrée que la tête ne couvre pas — signalée, pas
cachée.

```bash
cat /var/lib/oasis/jrn.head /var/lib/oasis/jrn.entries > /tmp/dump.txt
oasis_journal_verify /tmp/dump.txt ; echo "verdict: $?"
```

**Après un redémarrage**, la chaîne du démarrage précédent n'est pas écrasée. Elle est
renommée `jrn.<boot_id>.head` / `jrn.<boot_id>.entries`, et la passerelle l'annonce au
démarrage par une ligne `GATEWAY previous journal kept as …`. Chaque chaîne se vérifie
seule, contre **sa propre** tête, donc vérifiez-les toutes :

```bash
for h in /var/lib/oasis/jrn.*.head /var/lib/oasis/jrn.head; do
  cat "$h" "${h%.head}.entries" > /tmp/dump.txt
  oasis_journal_verify /tmp/dump.txt > /dev/null ; echo "$h -> verdict: $?"
done
```

⚠️ Jusqu'au 2026-10-10, un redémarrage **tronquait** le journal : toutes les décisions du
démarrage précédent étaient perdues. Une installation antérieure à cette date n'a donc
gardé que la chaîne de son dernier démarrage. Les chaînes archivées s'accumulent, une
paire par redémarrage, et l'unité systemd redémarre la passerelle après chaque crash :
leur durée de conservation est **votre** décision. `--keep-journals N` l'applique au
démarrage, en ne gardant que les N archives les plus récentes ; sans ce drapeau, tout est
gardé. Choisissez N pour que les archives couvrent au moins votre période d'audit, et
exportez-les avant qu'elles ne tombent.

### Un témoin hors de l'hôte

Le journal est inviolable **à distance**. Il ne l'est pas contre quelqu'un qui administre
l'hôte : entrées et tête sont sur le même disque et peuvent être réécrites ensemble. Ce
qu'un tel administrateur ne peut pas réécrire, c'est ce qui a **déjà quitté l'hôte**.

`tools/journal_witness.sh anchor <préfixe> <fichier>` ajoute une ligne, la tête et
l'empreinte des entrées à cet instant, à un fichier qui doit vivre **ailleurs** : une autre
machine, un support non réinscriptible, une impression. `check` compare la chaîne
d'aujourd'hui avec le dernier ancrage et répond `ok`, `DIVERGENCE` (une entrée ancrée ou la
tête a changé), `TRUNCATED` (la chaîne a raccourci) ou `MISSING` (le démarrage ancré n'est
plus ni vif ni archivé), avec les codes de sortie 0 à 3. Une chaîne qui a seulement grandi
reste `ok`. Ancrez à chaque période d'audit, depuis l'hôte de la passerelle vers une machine
d'exploitation :

```bash
tools/journal_witness.sh anchor /var/lib/oasis/jrn /tmp/w \
  && tail -n 1 /tmp/w | ssh <exploitation> 'cat >> ~/oasis-witness.log'
```

et, plus tard, depuis la machine d'exploitation, rapatriez la paire et comparez-la à **votre**
copie de l'ancrage :

```bash
scp <passerelle>:/var/lib/oasis/jrn.{head,entries} ./ \
  && tools/journal_witness.sh check ./jrn ~/oasis-witness.log
```

C'est une vérification de préfixe, pas une re-vérification de la chaîne de hachage : lancez
aussi `oasis_journal_verify`. Les deux répondent à des questions différentes (« a-t-on
réécrit depuis mon dernier passage ? » et « la chaîne est-elle cohérente aujourd'hui ? »).
Le témoin ne protège que ce qui a été ancré : une entrée réécrite **entre** deux ancrages,
puis ré-ancrée, n'est pas détectée. Ancrez donc assez souvent, et ne laissez jamais le
fichier d'ancrage accessible en écriture depuis l'hôte de la passerelle.

| Sortie | Sens |
|---:|---|
| 0 | chaîne **intacte** |
| 1 | chaîne **rompue** — une entrée a été modifiée ou retirée |
| 2 | **trou** dans la séquence |
| 3 | se termine sur une entrée **non confirmée** (une coupure au mauvais moment) |
| 4 | entrée illisible ou erreur d'usage |

Chaque décision y est, **acceptée ou refusée**, avec l'origine qui l'a causée. Gardez une
copie de la tête hors de l'hôte : c'est elle qui permet plus tard de dire qu'un journal
n'a pas été réécrit. Le journal est inviolable **à distance** ; il ne l'est pas contre
quelqu'un ayant un accès administrateur à l'hôte, qui peut réécrire entrées et tête
ensemble.

---

## 8. Panne, mode dégradé, et état sûr

| Ce qui tombe | Ce qui se passe | Ce que voit l'opérateur |
|---|---|---|
| La passerelle s'arrête ou plante | **Aucune** écriture réseau n'atteint l'automate | exception **0x0B** sous `timeout_ms` |
| La passerelle se bloque sans mourir | idem : rien n'est écrit | exception **0x0B** (c'est le délai de l'agent qui le dit, pas la passerelle) |
| L'agent s'arrête | l'IHM ne reçoit plus de réponse | la connexion de l'IHM cesse d'être servie — un **silence**, plus faible que l'exception ci-dessus |
| Le lien entre les deux hôtes est coupé | rien n'est écrit | exception **0x0B** |
| L'automate ne répond pas | rien n'est écrit ; la décision est quand même journalisée | exception **0x0B** ou l'exception de l'automate telle quelle |

**L'état sûr est donc : aucune écriture.** La défaillance est fermée, pas ouverte, et
c'est le seul comportement acceptable ici — mais relisez l'encadré du début : cela veut
dire qu'une machine dont la commande passe par ce chemin **n'est plus commandable** quand
la passerelle est en panne. Si cet état est dangereux pour votre machine, ce n'est pas à
OASIS de le rendre sûr : c'est au système de commande de sûreté.

Les unités systemd fournies redémarrent les deux services (`Restart=always`,
`RestartSec=1`), sans plafond de tentatives : une passerelle qui refuse de revenir
laisserait la machine sans chemin autorisé, ce qui pousse à recâbler l'IHM en direct —
exactement ce qu'on veut empêcher.

⚠️ **Il n'y a pas de chien de garde.** `WatchdogSec` de systemd exige que le processus
envoie des battements `sd_notify`, ce que ces binaires ne font pas ; en déclarer un ferait
tuer un processus sain. systemd redémarre donc un processus **planté** et ne détecte pas
un processus **bloqué**. Ce qui couvre le blocage est l'autre bout : le délai de l'agent
transforme le silence en 0x0B. C'est dit ici plutôt que présenté comme une surveillance.

---

## 9. Ce que ce montage ne couvre pas

Lisez cette section avant de signer quoi que ce soit.

1. **L'accès physique.** Quiconque ouvre l'armoire, branche un portable sur le segment de
   l'automate ou accède à l'hôte de la passerelle contourne tout. Le chemin unique est une
   propriété du câblage, et le câblage se modifie.
2. **La clé sur disque.** La graine est un fichier en `0400` sur un hôte Linux ordinaire.
   Pas d'élément sécurisé, pas de TPM. Un accès administrateur à l'hôte côté machine donne
   sa clé ; un accès à l'hôte côté opérateur donne celle qui **signe** les ordres.
3. **Le journal face à l'administrateur de l'hôte.** Voir §7 : inviolable à distance,
   réécrivable localement.
4. **Les autres protocoles.** Modbus TCP (FC06, FC16 jusqu'à 8 registres) et la lecture
   FC03 passent par la passerelle. Profinet, EtherNet/IP, OPC UA, EtherCAT : **rien**. Une
   machine qui parle aussi l'un de ces protocoles garde un chemin non couvert.
5. **La carte des registres n'est pas signée.** Qui édite `/etc/oasis/gateway.conf` édite
   les droits. Une attestation signée par le propriétaire sur ce lien reste à faire.
6. **Le débit.** Les ordres sont servis **un à la fois** : avec un automate à 2 ms de temps
   de réponse, environ **320 écritures par seconde au total**, et la latence croît
   linéairement avec le nombre d'IHM simultanées (10 IHM ≈ 30 ms par écriture). Pour une
   IHM qui écrit quelques fois par seconde c'est sans objet ; pour un parc, il faut une
   identité enrôlée par IHM.
7. **Les lectures révèlent les valeurs.** L'enveloppe donne l'authenticité, pas la
   confidentialité : qui écoute le lien voit les registres lus et écrits.
8. **Ce n'est pas un produit certifié.** Pas d'audit externe, pas de certification, pré-1.0.

---

## 10. Pour aller voir

| | |
|---|---|
| La spécification du transport et ses limites | [`specs/MODBUS_TCP_SPEC.md`](specs/MODBUS_TCP_SPEC.md) |
| La passerelle RTU, prouvée sur trois RP2040 | [`specs/MODBUS_GATEWAY_SPEC.md`](specs/MODBUS_GATEWAY_SPEC.md) |
| Le journal des décisions | [`AUTHORITY_HARDENING_SPEC.md`](AUTHORITY_HARDENING_SPEC.md) §I |
| Le cycle de vie des clés, et ses trous | [`KEY_LIFECYCLE.md`](KEY_LIFECYCLE.md) |
| La campagne bout en bout | [`../evidence/pilot/2026-10-09/README.md`](../evidence/pilot/2026-10-09/README.md) |
| Le débit et la concurrence | [`../evidence/bench/2026-10-09/concurrency/README.md`](../evidence/bench/2026-10-09/concurrency/README.md) |
