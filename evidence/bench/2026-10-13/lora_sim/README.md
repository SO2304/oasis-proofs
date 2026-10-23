# Transport LoRa : tests virtuels, sans radio — travail en cours

> *Expurgé pour publication le 2026-10-23 / redacted for publication on 2026-10-23 : chemins de sources, identifiants internes et noms de harnais retirés ; résultats inchangés.*

**2026-10-13, arbre `eeda4dd`** (aucune modification locale sous `oasis-lora-transport/`), Rust 1.95.0,
Windows 11. Tout ce qui suit tourne **en logiciel**. **Aucune radio n'a jamais émis.**

## 1. Ce qui est testé

La crate `oasis-lora-transport` porte la pile OASIS au-dessus d'une radio LoRa :
- **trame de transport** autour d'une enveloppe signée v0B ;
- **temps d'antenne** calculé par la formule Semtech ([withheld: source file]) ;
- **rapport cyclique EU868 de 1 %**, appliqué par le transport lui-même : `send_envelope` refuse avec
  `DutyCycleExceeded` **avant** de toucher la radio ;
- **saut de fréquence** (FHSS, [withheld: source file]) ;
- **pilote SX1262** ([withheld: source file]) testé contre un bus SPI simulé ;
- **radio simulée** ([withheld: source file]) : deux nœuds reliés par des canaux en mémoire, avec perte de paquets
  injectée.

Le simulateur travaille **au niveau des octets**. Il suppose que les octets envoyés sont reçus, hors
pertes injectées. Ce n'est **pas** une simulation de la couche physique : pas de propagation, pas de
bruit, pas de collision radio réelle.

## 2. Reproduire

```bash
cd oasis-lora-transport
cargo test --release                          # 31 tests : ce que lance [withheld: claims checker]
cargo test --release --features std           # 41 tests : la suite complète
cargo run -q --release --features std --example mesh_poc
cargo run -q --release --features std --example duty_cycle
cargo run -q --release --features std --example fhss_measurement
cargo run -q --release --features std --example fhss_advanced_jammers
```

Sorties brutes : `tests_default.txt`, `tests_std.txt` et un fichier par simulation (sortie standard
seule ; la sortie d'erreur ne contient que des avertissements de compilation). Chaque simulation a
tourné **deux fois** : les deux sorties sont **identiques octet pour octet** (graines fixes ; les
empreintes des deux passages sont dans `env.txt`).

## 3. Résultats

### Tests : 40 sur 41, un échec qui n'était visible nulle part

| Commande | Tests | Résultat |
|---|---:|---|
| `cargo test --release` | 31 | **31 passent** |
| `cargo test --release --features std` | 41 | **40 passent, 1 échoue** |

Le test qui échoue est `signed_envelope_survives_partial_loss` :

```
called `Result::unwrap()` on an `Err` value: DutyCycleExceeded { needed_us: 174336, available_us: 128320, retry_in_ms: 4602 }
```

Depuis le 2026-10-08, le transport **applique** le rapport cyclique de 1 % par défaut. Ce test envoie
ses enveloppes plus vite que ce que la règle autorise, et il n'a jamais été mis à jour. Le transport
fait ce qu'il doit, et c'est le test qui n'a pas suivi. Personne ne l'a vu, pour deux raisons :
- [withheld: claims checker] lance la crate **sans** `--features std` ;
- **dix** tests ne sont compilés qu'avec cette option : les trois de la radio simulée, les cinq du
  saut de fréquence et les deux du pilote SX1262.

Le README de la crate disait « Tests (all green) », et le rapport `../../2026-10-09/lora_budget/`
annonçait 41 tests. Les deux sont corrigés en place, avec la date. **Rien n'a été corrigé dans le
code** : l'échec est enregistré tel quel.

### Simulation de bout en bout : `mesh_poc`

Deux nœuds Ed25519 sur un lien LoRa simulé (SF7) :
- A signe et émet 28 octets de charge, soit une enveloppe de 117 octets et 210,2 ms d'antenne ;
- B vérifie la signature : `ARRIVED` ;
- une enveloppe **forgée** est rejetée (`bad mesh signature`) ;
- à un envoi par seconde, le rapport cyclique n'autorise que **7 envois sur 50**.

La dernière ligne du programme (« écrire le driver SX1262 réel ») est **périmée** : le pilote existe
depuis le 2026-06-12. Il n'a cependant **jamais tourné contre une radio**.

### Rapport cyclique : `duty_cycle`

Temps d'antenne d'une charge de 24 octets (BW 125 kHz, CR 4/5) : **61,70 ms à SF7**, jusqu'à
**1 482,75 ms à SF12**. Avec une tentative SF7 toutes les 200 ms pendant 30 s, **21 envois sont
légaux et 129 refusés**.

### Saut de fréquence contre brouilleurs : `fhss_measurement`, `fhss_advanced_jammers`

K=10 essais par scénario, 80 paquets par essai. Les valeurs sont des **taux de livraison**, médiane et
demi-écart.

| Scénario | Médiane | ± |
|---|---:|---:|
| Sans brouilleur, 1 canal | 1,000 | 0,000 |
| 1 canal brouillé sur 1 (pas de saut possible) | 0,000 | 0,000 |
| 1 canal brouillé sur 8, saut | 0,900 | 0,031 |
| 2 canaux brouillés sur 8, saut | 0,762 | 0,094 |
| 4 canaux brouillés sur 8, saut | 0,450 | 0,069 |
| 1 canal brouillé sur 32, saut | 0,963 | 0,050 |
| Brouilleur à balayage, période 800 ms, 8 canaux | 0,900 | 0,075 |
| Brouilleur **suiveur**, latence 10 ms ou 50 ms | **0,000** | 0,000 |
| Brouilleur suiveur, latence 85 ms ou 120 ms | 1,000 | 0,000 |
| Paquets de 10 ms contre un suiveur à 20 ms | 1,000 | 0,000 |

**À lire :** un brouilleur suiveur plus rapide que la durée d'un paquet bat le saut de fréquence, et
seuls des paquets plus courts que sa latence lui échappent. Le modèle de brouilleur est simplifié.

## 4. Ce que ça ne montre pas

- **Aucune émission radio, aucune réception réelle.** La phase C.1 (deux SX1262 sur RP2040) reste
  ouverte.
- **Pas de couche physique** : pas de portée, d'obstacles, d'interférences ni de collisions réelles.
- **La formule de temps d'antenne n'est pas vérifiée à la source** (fiche technique Semtech derrière
  un portail commercial). Elle reproduit les valeurs publiées, pas une radio mesurée.
- **Le pilote SX1262** n'est vérifié que contre un bus SPI simulé et la fiche technique.
- **Les taux de livraison FHSS** viennent d'un modèle. Ils ne valent pas mesure en environnement
  réel.

## 5. Statut : en cours

| Brique | État |
|---|---|
| Pile logicielle au-dessus de la radio (trame, signature, rapport cyclique) | testée en simulation |
| Budget d'antenne par message | calculé (`../../2026-10-09/lora_budget/`) |
| Saut de fréquence | simulé contre trois modèles de brouilleur |
| Pilote SX1262 | écrit, testé contre un SPI simulé |
| Émission réelle | **pas commencée** |
