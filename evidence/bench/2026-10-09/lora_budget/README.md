# Budget radio : le script Python était une seconde implémentation, et un chiffre était faux

**2026-10-09.** `docs/lora_budget.py` est supprimé et porté en Rust :
`oasis-lora-transport::budget`, plus le binaire `lora_budget` dont la sortie est
[`lora_budget.txt`](lora_budget.txt). Reproduire :

```bash
cd oasis-lora-transport && cargo run --release --bin lora_budget
```

## 1. Pourquoi ce n'était pas qu'une traduction

Le script calculait le temps d'antenne avec **sa propre copie** de la formule, alors que
`oasis-lora-transport::airtime::airtime_us` — celle que le transport applique réellement
pour facturer le duty cycle — en a une autre. **Rien ne comparait les deux**, et six
documents citaient les chiffres du script pendant que le code appliquait les siens. Les
deux s'accordent, et c'est maintenant asserté plutôt que supposé :

| Vérification | Valeur |
|---|---|
| SF7 / 16 o | **51,456 ms** (publiée 51,456) |
| SF12 / 64 o | **2 793,472 ms** (publiée 2 793,5 — l'auto-contrôle du script) |
| Frontière LDRO | la règle `sf >= 11` du script et la règle « temps de symbole ≥ 16 ms » du Rust **coïncident** à 125 kHz, pour les six SF |

Les quatre chiffres de `docs/CRYPTO_MIGRATION.md` sont reproduits à l'identique :
ML-DSA-44 **48 trames / 3,72 h**, ML-KEM-768 **22 / 1,70 h**, OAQ1 k=2 clés portées
**148 / 11,48 h**, indices d'un octet **96 / 7,44 h**.

## 2. Le chiffre faux

`CLAUDE.md` et la section G annonçaient, pour l'enveloppe SF12 en LoRa brut : « **6
ordres, 3 révocations, 7 balises** par heure et par bande ». Les ordres et les balises
sont justes. La révocation ne l'est pas :

| Message | Octets | Temps d'antenne SF12 | Par heure |
|---|---:|---:|---:|
| ordre `OAC1` | 153 | 5 742,592 ms | **6** ✅ |
| balise `OSB1` | 131 | 5 087,232 ms | **7** ✅ |
| arrêt compact `OAS1` | 110 | 4 268,032 ms | **8** ✅ |
| révocation `ORV1`, 1 nœud | 234 | 8 364,032 ms | **4**, pas 3 ❌ |

3 par heure demanderait un message de **251 octets**, ce qu'aucun des nôtres n'est.

**Pourquoi ça a survécu** : le script n'a **jamais calculé** ces chiffres. Sa table
appliquait le plafond applicatif LoRaWAN — 51 octets à SF10–SF12 — donc chaque message
OASIS y sortait `**over cap**` et aucune valeur horaire SF12 n'en est jamais sortie.
L'enveloppe LoRa brut était attribuée à un script qui ne pouvait pas l'avoir produite. Ses
assertions, elles, ne portaient que sur la fragmentation post-quantique — qui, elle, était
juste.

## 3. Ce que le port change en plus

- **Les assertions deviennent des tests.** Un script ne tourne que si quelqu'un y pense ;
  `budget::tests` tourne à chaque `cargo test` de la crate. 10 tests, dont la
  monotonie en charge utile **et** en SF, que nul chiffre isolé n'aurait attrapée.
- **`tools/check_claims.sh --full` exécute désormais les tests de cette crate.** Elle est
  délibérément **hors** de l'espace de travail — elle active sans condition
  `oasis-rt/mesh_bloom_mcu`, ce qui, dans l'espace de travail, rétrécirait le filtre de
  Bloom de l'hôte pour tout le monde (la fuite d'unification de features du
  2026-05-11) — et la conséquence était passée inaperçue : **ses 31 tests ne tournaient
  nulle part**, ni ici, ni en CI, ni dans `--workspace`.
- **Règle 7 contrôlée.** `check_claims.sh` refuse tout nouveau `.py` hors des deux
  exceptions déclarées (`tools/hmi_client.py` et les scripts de contre-épreuve sous
  `evidence/`). Contre-épreuve : un fichier Python ajouté dans `docs/` → `NOUVEAU`,
  sortie 1.

## 4. Ce que ça ne montre pas

- **La formule n'est toujours pas vérifiée à la source** : la datasheet Semtech est
  derrière un portail commercial. Ce qui est vérifié, c'est que ce code reproduit les
  valeurs publiées dans les documents qui le citent. L'exactitude est vis-à-vis de cette
  formule, pas d'une radio mesurée.
- **Aucune radio n'a jamais émis.** Phase C.1 reste ouverte.
- **Les 13 octets d'en-tête LoRaWAN** par fragment sont la convention de `PQC.md` §4,
  **non vérifiée à la source** (TS001 non relu). Tous les chiffres de fragmentation sont
  donc des **[calculs]**.
