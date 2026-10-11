# Logiciels et données essentiels à la conformité — annexe III 1.1.9, alinéa 3

> **1.1.9, alinéa 3** (texte vérifié à la source, [EUR-Lex CELEX 32023R1230](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32023R1230),
> 1.1.9 compte 5 alinéas) : « Software and data that are critical for the compliance of the
> machinery or related product with the relevant essential health and safety requirements
> shall be **identified as such** and shall be adequately protected against accidental or
> intentional corruption. »

Ce fichier est la moitié « **identifiés comme tels** ». La moitié « protégés » est couverte
ailleurs et chaque ligne pointe vers sa preuve.

**Chaque chemin de ce document est vérifié par `tools/check_claims.sh`** : un module renommé
ou supprimé fait échouer le contrôle, donc cet inventaire ne peut pas dériver en silence.
C'est le seul mécanisme qui distingue un inventaire d'une liste écrite une fois.

⚠️ **Ce document n'est pas un SBOM.** Le SBOM CycloneDX
(`evidence/supply-chain/2026-10-07/sbom/`) liste les **dépendances** de chaque crate ;
celui-ci liste les parties **d'OASIS lui-même** dont dépend la conformité. Les deux sont
demandés par des textes différents et ne se remplacent pas.

⚠️ « Essentiel à la conformité » est un **jugement**, pas une propriété dérivable de
l'arbre. Le critère retenu ici : *ce dont une modification peut faire exécuter une action
physique qui aurait dû être refusée, ou faire refuser une action qui aurait dû être
exécutée*. Un fabricant qui intègre OASIS doit refaire ce jugement pour sa machine ; la
colonne « pourquoi » existe pour qu'il puisse le contester ligne à ligne.

---

## 1. La décision d'agir

| Chemin | Rôle | Pourquoi essentiel | Protection et preuve |
|---|---|---|---|
| `oasis-rt/src/actuation.rs` | Le portail : **9 conditions ordonnées** pour `Act`, **3** pour `Stop` | C'est la fonction qui dit oui ou non à une action physique. Une condition retirée est une action non autorisée exécutée | 15 tests `act_*`, 15 harnais Kani, silicium (`evidence/silicon/2026-10-07/modbus/`) : 12 refus couvrant ses six raisons, **0 octet** sur le bus |
| `oasis-rt/src/actuation/timeview.rs` | Vue du commandant sur l'horloge de l'actionneur | Une erreur d'estimation ne doit **jamais** produire une exécution non voulue, seulement un refus | 4 harnais Kani, silicium partie K 6/6 |
| `oasis-rt/src/hyper_state.rs` | R14 : verrou d'état des capteurs / entropie | Alimente la 5ᵉ condition du portail ; un seuil faussé laisse agir une machine dont l'état est inconnu | 9 tests + 3 harnais Kani, 1000/1000 fautes bloquées |
| `oasis-rt/src/hal.rs` | `KillSwitch` et contraintes physiques | Dernière borne avant la sortie ; un `clamp` faussé envoie une consigne hors domaine | tests `hal` ; ⚠️ `clamp_command` **fail-open sur NaN** historiquement — garde NaN ajoutée dans le portail |
| `oasis-rt/src/quorum.rs` | Ordres à deux signatures (k parmi n) | Pour un ordre critique, une seule signature ne doit pas suffire | 9 tests `q_*`, 5 harnais Kani ; ⚠️ **PC seulement**, aucune carte ne détient un jeu de clés opérateur |

## 2. L'authenticité de ce qui arrive

| Chemin | Rôle | Pourquoi essentiel | Protection et preuve |
|---|---|---|---|
| `oasis-rt/src/mesh.rs` | v0B : Ed25519 liant charge utile, compteur, réseau ; fenêtre anti-rejeu persistée | Si une trame forgée passe, toutes les conditions du portail sont évaluées sur un ordre inventé | 11 tests `v0b_*`, 53 harnais Kani, silicium **0/150** inversions de bit acceptées |
| `oasis-rt/src/mesh/prefilter.rs` | v0C : MAC de lien + budget, **avant** Ed25519 | Sans lui, une trame forgée coûte 179 ms de CPU au relais | 16 tests, 3 harnais Kani, silicium **256×** moins coûteux |
| `oasis-rt/src/spore_crypto.rs` | ChaCha20-Poly1305, X25519, suivi de compteur | Primitives sous tout le reste | vecteur RFC 8439 octet pour octet |
| `oasis-rt/src/sealed.rs` | `OSE1` : confidentialité origine → actionneur | Une charge utile lisible en clair n'est pas une faille de sûreté en soi, mais elle l'est pour C13 | 8 tests, 5 harnais Kani |
| `oasis-rt/src/mavlink_order.rs` | Enveloppe v0B portée dans `V2_EXTENSION` | Chemin d'armement d'un véhicule PX4 | 7 tests `mo_*`, 4 harnais Kani, PX4 SITL 5/5 |

## 3. Qui a le droit (la configuration d'autorité)

| Chemin | Rôle | Pourquoi essentiel | Protection et preuve |
|---|---|---|---|
| `oasis-rt/src/enrollment.rs` | Attestations `OAU1` : qui peut commander, avec quelles permissions | Une entrée ajoutée, c'est un commandant de plus | 6 tests, 4 harnais Kani, silicium (`enroll/`) |
| `oasis-rt/src/mesh_revocation.rs` | `ORV1` : qui ne peut plus, époque strictement croissante, permanent | Un retour en arrière réadmet un nœud compromis | 13 tests `rev_*`, 6 harnais Kani, silicium avec coupure de courant |
| `oasis-rt/src/ownership.rs` | Transfert de propriété signé des deux côtés | Qui a le droit de changer tout ce qui précède | 5 tests `own_*`, 3 harnais Kani, silicium o1→o2 sur 3 cartes |
| `oasis-rt/src/authority.rs` | Octet de suite signé, minimum par type, jamais abaissé | Un abaissement de suite rouvre la cryptographie classique | 7 tests, 4 harnais Kani, silicium (`pq/`) |
| `oasis-rt/src/fragment.rs` | `OFR1` : réassemblage borné, store-and-forward | Un message d'autorité fragmenté doit arriver entier ou pas du tout | 11 tests `frag_*`, 3 harnais Kani |
| `oasis-rt/src/identity.rs` | Génération de clé embarquée, tests de santé SP 800-90B | Une clé prévisible, c'est une identité usurpable | 5 tests `id_*`, silicium : ROSC 43–47 % de uns |
| `oasis-operator-key/` | Vérification de l'autorité opérateur, k parmi n, `no_std` | Ce qui valide une signature d'opérateur | 7 tests + 3 d'intégration |

## 4. Ce qui atteint un équipement

| Chemin | Rôle | Pourquoi essentiel | Protection et preuve |
|---|---|---|---|
| `oasis-rt/src/modbus_gateway.rs` | `OMB1` → trame RTU, **seulement** dans la branche `Act` | La trame qui écrit dans un automate | 10 tests `mb_*` contre `rmodbus`, 3 harnais Kani, silicium 4 `Act` = 4 écritures |
| `oasis-rt/src/modbus_tcp.rs` | Le même portail, transport TCP | idem, sur Ethernet | 7 tests `mbtcp_*`, 2 harnais Kani |
| `oasis-rt/src/modbus_read/` | Lectures authentifiées, bornées par la carte de registres | Une lecture non bornée est un scanner d'équipement | 9 tests `rd_*`, 5 harnais Kani vérifiés 5/5 |
| `oasis-rt/src/mbtcp_pilot/` | Passerelle et agent : la boucle qui tourne vraiment | Ce qu'un opérateur exécute ; une copie divergente du portail serait une seconde porte | 4 tests + 4 sur sockets réelles contre `rmodbus` |

## 5. La preuve (alinéa 5)

| Chemin | Rôle | Pourquoi essentiel | Protection et preuve |
|---|---|---|---|
| `oasis-rt/src/journal.rs` | Chaîne de hachages : **toute** décision, acceptée et refusée, **et** tout changement de logiciel ou de configuration | C'est l'exigence elle-même. Un journal falsifiable ne prouve rien | 18 tests, 6 harnais Kani 6/6, silicium **intact exit 0** sur 10 entrées dont 4 refus, coupure de courant réelle (S8) |
| `oasis-rt/src/firmware.rs` | Règle d'installation pure : plancher anti-retour, hachage, matériel | Une image non autorisée installée remplace tout ce qui précède | 3 tests `fw_*`, 3 harnais Kani, silicium T1–T7 avec 2 coupures |
| `oasis-bootloader/` | Échange A/B tolérant à la coupure, démarrage d'essai, retour arrière | Si l'échange est interrompu, la machine doit redémarrer sur une image valide | silicium : coupure **pendant** l'échange, reprise, `v3` confirmée |
| `oasis-rt/src/tx_lease.rs` | `DualSlotStore` : fenêtre de compteur, bail d'émission, plancher firmware, politique | Les données persistées dont dépendent l'anti-rejeu et l'anti-retour | 6 harnais Kani, silicium T8 à travers une coupure réelle |

## 6. Données persistées essentielles

Ce ne sont pas des fichiers du dépôt mais des **secteurs de flash**, et l'alinéa 3 dit
« logiciels **et données** ». Toutes passent par `tx_lease::DualSlotStore` ou `jstore`
(deux emplacements alternés, écriture avant application) :

| Donnée | Ce qu'une corruption permettrait | Où |
|---|---|---|
| Fenêtre de compteur v0B (128 bits) | rejouer un ordre après un redémarrage | `tx_lease` |
| Bail d'émission (`tx_lease`) | une origine redémarrée se verrouille ou se rejoue | `tx_lease` |
| Liste de révocation + époque | réadmettre un nœud compromis | `tx_lease` |
| Registre d'enrôlement | ajouter un commandant | `enroll::persist_registry` |
| Politique de suites (2 emplacements) | abaisser la cryptographie exigée | `tx_lease` |
| Plancher de version firmware | réinstaller une image ancienne | `tx_lease` |
| Tête + anneau du journal | effacer la preuve | `jstore` |
| **Clé privée Ed25519 du nœud** | **usurper l'identité du nœud** | flash, ⚠️ **lisible par BOOTSEL/SWD** — voir C14 |

## 7. Ce qui n'est **pas** essentiel à la conformité

Dire ce qui est dehors borne la revendication, et c'est aussi utile qu'une liste de ce qui
est dedans. Les **onze mécanismes bio-inspirés** (`tension`, `synapse`, `emotion`,
`morpho`, `efference`, `dreams`, `branching`, `world_model`, `reflex`, `federation`,
`audio`, `nerve`, `spinal`, `vitality`) ne décident aucune action physique : le portail ne
lit aucune de leurs sorties, à **une exception** — `hyper_state` alimente la condition R14
et figure donc au §1. Les primitives type ROS 2 (`topics`, `services`, `actions`,
`transforms`, `timers`, `parameters`, `nav`), les bancs (`bench_*`), les simulations
(`sim_*`) et le démon Android (`main.rs`) sont hors périmètre.

⚠️ **Cette exclusion vaut pour OASIS, pas pour une machine.** Un intégrateur qui câblerait
une sortie d'un mécanisme expérimental sur une commande d'actionneur le ferait entrer dans
le périmètre, et c'est son jugement à refaire, pas le nôtre.

---

## Ce que cet inventaire ne fait pas

- Il **n'exécute pas** l'alinéa 4 : la machine doit pouvoir fournir l'identité des logiciels
  installés « à tout moment sous une forme aisément accessible ». Sur silicium, `@V` renvoie
  une `version` qui est une **constante de compilation**, pas un condensé mesuré de l'image
  en cours, et seulement par USB. Ce manque reste ouvert.
- Il ne dit rien du **matériel** (alinéa 2). Voir `MACHINERY_REGULATION_2023_1230.md` §3.
- Il n'est **pas** une évaluation de conformité : c'est la liste qu'un fabricant doit
  pouvoir produire, pas la démonstration qu'elle est suffisante pour sa machine.
