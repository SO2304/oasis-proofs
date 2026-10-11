# Modbus TCP pour la passerelle (spec, première étape)

Origine : l'audit commercial du 2026-10-07. La plupart des machines récentes parlent
Ethernet (Modbus TCP, Profinet, EtherNet/IP), alors que la passerelle de la phase 1.4
ne parle que Modbus RTU. Sans TCP, aucun pilote n'est possible devant une machine
réelle. Cette étape ajoute le **transport TCP**. La **porte reste celle de la
phase 1.4** (`modbus_gateway::gateway_decision`, elle-même la porte de la partie F),
sans modification.

## 1. Architecture visée pour un pilote

```
IHM / SCADA ──Modbus TCP en clair──▶ agent OASIS ──ordre OMB1 signé (v0B)──▶ passerelle OASIS ──Modbus TCP──▶ automate
 (inchangée)                         (côté opérateur)                        (côté machine)                    (inchangé)
```

- **L'IHM n'est pas modifiée.** Elle écrit en Modbus TCP vers l'agent comme elle le
  ferait vers l'automate.
- L'**agent** lit l'écriture (`parse_tcp_write`). Il en fait un ordre `OMB1`
  (`TcpWrite::to_order`) avec son numéro de séquence, l'identifiant de démarrage
  (`boot_id`) de la passerelle et une échéance, puis le signe en v0B. Une fois la
  décision connue, il répond à l'IHM (`hmi_response`).
- La **passerelle** vérifie l'enveloppe v0B, décide (`decide_tcp`), et seule une
  décision `Act` produit une requête vers l'automate. Elle vérifie ensuite la
  réponse de l'automate (`check_tcp_response`).

## 2. Ce qui est fait (module `oasis-rt/src/modbus_tcp.rs`, pur, `no_std`)

| Élément | Règle |
|---|---|
| Requête vers l'automate | Construite à partir de la trame RTU d'une décision `Act` : même unité, même PDU, en-tête MBAP au lieu du CRC. **Aucune requête TCP sans `Act`.** |
| En-tête MBAP | `tid u16 \| protocole 0 \| longueur = 1 + PDU \| unité`, big-endian |
| Fonctions | FC06 (1 registre) et FC16 (1 à 8 registres), comme en RTU |
| Écriture reçue de l'IHM | Longueur exacte, protocole 0, longueur MBAP cohérente, nombre d'octets FC16 = 2 × quantité, quantité 1..=8. Tout le reste est refusé (`None`), lectures comprises |
| Réponse de l'automate | `Ack` seulement si `tid`, protocole et unité correspondent, la longueur MBAP est cohérente, et l'écho FC06/FC16 est exact. Sinon `Exception(code)`, `Mismatch` ou `Short` |
| Réponse à l'IHM | Écho de l'écriture si elle a été exécutée et acquittée. Sinon une exception Modbus : 0x02 (registre hors carte), 0x03 (valeur hors plage), 0x0A (autre refus de la porte), l'exception de l'automate telle quelle, 0x0B (pas de réponse exploitable) |

Le code 0x0A pour un refus de politique est un choix : le protocole Modbus n'a pas de
code « non autorisé ». L'IHM voit un refus, pas une coupure silencieuse.

## 3. Preuves

- **7 tests `mbtcp_*`.**
  - Chaque requête construite est analysée et appliquée par **`rmodbus` 0.12.2 en
    mode TCP**, un serveur indépendant de notre code. La requête est identique,
    octet pour octet, à celle qu'une IHM enverrait.
  - Chaque condition de la porte bloque la requête.
  - L'analyseur refuse les trames mal formées.
  - La vérification des réponses et les réponses à l'IHM sont couvertes.
  - Un test de bout en bout chaîne IHM → agent → v0B → passerelle → automate
    `rmodbus`. L'automate n'est jamais touché par : une valeur hors plage, un
    registre hors carte, un rejeu octet pour octet, une origine forgée, une valeur
    modifiée dans une enveloppe authentique, ou une écriture Modbus brute emballée
    dans une enveloppe valide. Deux écritures valides = deux écritures sur
    l'automate.
- **2 harnais Kani** (`modbus_tcp/kani_proofs.rs`), vérifiés le 2026-10-07 avec
  cargo-kani 0.68.0 (CBMC 6.11.0), chacun avec une contre-épreuve qui échoue comme attendu :
  - `proof_mbtcp_frame_iff_act_and_matches_order` : une requête existe si et
    seulement si la décision est `Act`. Elle porte exactement l'ordre (MBAP,
    fonction, adresse de départ, valeurs).
    Contre-épreuve : `tid` altéré → FAILED.
  - `proof_mbtcp_parse_total` : l'analyseur ne panique sur aucune entrée jusqu'à
    37 octets, et ne rend que des écritures bornées.
    Première contre-épreuve sans effet : le harnais n'allait que jusqu'à 30 octets,
    donc n'explorait pas une FC16 à 9 registres. Harnais élargi, puis contre-épreuve
    (quantité 9 acceptée) → FAILED.

## 4. Ce que cette section listait comme manquant, et où ça en est

Cette section a porté « ce qui n'est pas fait » jusqu'au 2026-10-09 alors que quatre de
ses cinq points étaient faits. Le constat est gardé plutôt qu'effacé, parce qu'une spec
qui réclame ce qu'elle a déjà est une spec que personne ne relit.

| Point d'alors | Où ça en est |
|---|---|
| 1. Les binaires réseau | **Fait.** `oasis_mbtcp_agent` et `oasis_mbtcp_gateway` (`src/mbtcp_pilot/`), délais d'attente partout, une seule connexion automate, carte des registres en configuration. Un audit avait relevé qu'il n'y avait **aucune socket dans `oasis-rt`** : `mbtcp_net` est le transport |
| 2. Le temps de la passerelle | **Fait.** L'agent demande `OTQ1` et reçoit `OTM1`, extrapolé par le `TimeView` de la partie K ; il ne lit plus le `boot_id` par un canal latéral |
| 3. Le journal des interventions | **Fait.** `JournalSink` tient les deux fichiers ouverts, écrit **chaque** décision, refus compris, et `oasis_journal_verify` les relit (`intact`, sortie 0 ; `broken`, sortie 1 sur un refus réécrit en acceptation) |
| 4. Les lectures (FC03/FC04) | **Fait, par la passerelle** (`modbus_read`, `OMQ1`/`OMV1`) : même enveloppe v0B, même carte des registres, une plage dont un registre sort est refusée **entière** et l'automate n'est pas interrogé. FC04 refusé par son nom. Le relais direct par l'agent a été écarté : il recrée le canal latéral que la passerelle existe pour empêcher |
| 5. Un essai sur du matériel réel | **Ouvert.** Voir §5 |

## 5. Limites, nommées

- **Aucun automate du commerce.** Tout ce qui est mesuré ici l'a été contre
  `oasis_test_plc`, un simulateur bâti sur `rmodbus` qui **ne dépend pas d'`oasis-rt`**
  (vérifiable dans son manifeste), sur un seul hôte en boucle locale. Il répond
  instantanément là où un automate a un cycle de scrutation, des E/S et des contraintes
  temps réel. Le protocole et le chemin d'autorisation sont réels ; la machine ne l'est
  pas, et la latence mesurée est un **plancher**. Partout où ce document écrit
  « automate », lire **non testé sur automate du commerce**.
- **R14 est non applicable sur hôte.** R14 refuse une action physique quand l'entropie
  des capteurs dépasse un seuil. Un hôte Linux n'a pas de capteur à lire : il n'y a pas
  de signal, donc rien que la condition puisse juger. La passerelle passe
  `R14_NOT_APPLICABLE_ON_HOST` — une constante **nommée**, pas un `true` anonyme dans
  une structure — et c'est *non applicable*, pas *vérifié sûr* : la nuance compte pour
  qui relit une entrée de journal dont `FLAG_R14_SAFE` est levé. L'état de supervision
  de la partie H n'en est pas un substitut : aucun balisage `OSB1` n'arrive sur ce lien.
  Une passerelle co-implantée avec des capteurs doit alimenter le vrai signal ; les neuf
  conditions de la porte sont inchangées dans les deux cas.
- **Les clés sont dans des fichiers de configuration** — plus de graine compilée, mais un
  fichier aussi lisible qu'un autre sur l'hôte.
- **Les ordres sont servis un à la fois**, et c'est désormais **mesuré** et non seulement
  affirmé (`bench_mbtcp_concurrency`, K=10, 2026-10-09). Avec 1, 2, 5 puis 10 IHM
  concurrentes sur une boucle locale : débit **1 843 → 2 169 acquittements/s** mais à
  moins de 10 % de son maximum dès **N=2**, et latence **450 → 4 447 µs**, soit **×9,9**
  pour dix fois plus de clients. En donnant à l'appareil un temps de réponse de **2 ms** —
  un automate réel a un cycle de scrutation, la boucle locale n'en a pas — le débit est
  **plat à 307–324/s de N=1 à N=10** et la latence croît linéairement **à ±3 % près** :
  3 100 / 6 156 / 15 368 / 30 505 µs. C'est de l'attente, pas du travail.

  ⚠️ **Découper le verrou n'y changerait rien**, et c'est la conclusion honnête contre
  l'intuition : la ressource sérialisée n'est pas l'état de la passerelle mais **la
  connexion unique vers l'appareil**. Un appareil, une connexion, une transaction à la
  fois. Sortir l'échange réseau du verrou laisserait deux ordres atteindre la même socket
  en même temps, ce qui est faux pour Modbus TCP sur une connexion tenue. La capacité
  au-delà de ce plafond passe par des **origines distinctes** — une identité enrôlée par
  IHM — que la carte par origine et la séquence par origine (A.1) rendent possibles.

- **Un défaut trouvé par cette mesure, et corrigé** : toutes les IHM partagent l'identité
  de l'agent, donc **un seul espace de `cmd_seq`**, et la porte exige qu'il croisse
  strictement par origine. L'agent relâchait son verrou après la signature et faisait
  l'aller-retour en dehors : deux IHM pouvaient réserver 5 et 6 et faire arriver 6 en
  premier, après quoi 5 devenait `Reject(StaleOrReplayed)` — **une écriture légitime
  refusée**, montrée à l'opérateur en 0x0A, ce qu'un opérateur lit « non autorisé ». Le
  banc en a compté **32 sur 1 800** (1,8 % ; 4 à N=5, 28 à N=10), **toutes** en
  `Reject(StaleOrReplayed)` contre 1 768 `Act`, lues dans le registre de décisions de la
  passerelle elle-même et **non déduites** du code d'exception — un 0x0A ne dit que « la
  porte a refusé », et laquelle des neuf conditions a tiré est exactement là qu'une
  explication plausible et fausse s'écrit. L'agent signe et émet maintenant dans la même
  section critique : **0 refus** aux mêmes N, au prix de **46 % du débit à N=5**
  (3 975 → 2 150/s) et d'une latence doublée (1 078 → 2 198 µs). C'est près de la moitié,
  et c'est dit plutôt qu'arrondi : une passerelle qui refuse 1,8 % des écritures légitimes
  en affichant « non autorisé » n'est pas utilisable, et le débit perdu se récupère par des
  origines distinctes. Empreinte `aae60da`,
  `evidence/bench/2026-10-09/concurrency/`.
- **Une injection Modbus brute ne laisse aucune entrée de journal** : elle est refusée par
  le cadrage avant de devenir une décision. C'est une limite connue de la piste d'audit,
  pas un oubli.
