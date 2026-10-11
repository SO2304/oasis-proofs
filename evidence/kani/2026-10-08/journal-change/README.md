# Kani — le journal des changements de logiciel et de configuration : 6/6 vérifiées

**2026-10-08, empreinte `f187527`.** Kani 0.68.0, WSL2, clone propre de la révision
committée (`git clean -qfd`). Reproduire : `run_journal.sh main` (copié ici tel qu'exécuté).

| | |
|---|---|
| Résultat | **6 vérifiées, 0 réfutée, 0 indéterminée** |
| Contrôles négatifs | **2 mutations, 2 échecs comme voulu, sur une propriété nommée** |
| Stub déclaré | **oui, 3 des 6** (voir §3) |
| Durée | ~1 min 50 pour les huit exécutions |

Provenance : [`console.txt`](console.txt), transcription complète portant l'empreinte en
tête et en pied. Les `.log` individuels ne portent pas l'empreinte — le runner l'imprime sur
stdout — donc ils ne s'auto-attestent pas.

## 1. Ce qui est prouvé

Le règlement (UE) 2023/1230, annexe III 1.1.9, alinéa 5, **vérifié à la source**
([EUR-Lex, CELEX 32023R1230](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32023R1230),
1.1.9 compte **5 alinéas**) : « The machinery or related product shall collect evidence of a
legitimate or illegitimate intervention in the software or a modification of the software
installed on the machinery or related product or its configuration. »

Le journal portait les **décisions**. Il ne portait rien quand le logiciel ou la
configuration d'autorité changeait — les déclencheurs 2 et 3 de cette phrase.

| Harnais | Énoncé | Stub |
|---|---|---|
| `proof_entry_roundtrip_is_lossless` | rien d'une entrée n'est perdu ni altéré en passant par les octets, **y compris un changement** | non |
| `proof_journal_parse_total` | le parseur est **total** sur toute chaîne d'au plus 33 octets, les octets réservés restent nuls, et un changement n'a **qu'un seul** octet de classe valide | non |
| `proof_decision_byte_is_injective` | les **trois** régions de l'espace d'octets sont disjointes et injectives, et `DEC_REJECT_BASE + REASON_COUNT ≤ DEC_CHANGE_BASE` — donc ajouter un `Reason` échoue ici plutôt que de transformer silencieusement un refus en changement de configuration | non |
| `proof_journal_seq_monotone` | `seq` avance d'exactement un | oui |
| `proof_every_decision_is_logged` | `append` n'a aucun chemin qui rende sans produire d'entrée ni avancer la tête | oui |
| `proof_change_record_preserves_what_an_auditor_reads` | **nouveau** : un enregistrement de changement conserve quel changement, son numéro, **qui l'a autorisé**, et s'il a été **appliqué ou refusé** | oui |

## 2. Les contrôles négatifs

| Mutation | Harnais | Vérifié nommé en échec |
|---|---|---|
| A — `DEC_CHANGE_BASE` 64 → 20, donc un refus lirait comme un changement | `proof_decision_byte_is_injective` | `assertion failed: DEC_REJECT_BASE as usize + REASON_COUNT <= DEC_CHANGE_BASE as usize` (`kani_proofs.rs:187`) |
| B — le drapeau appliqué/refusé est perdu (tout changement enregistré comme appliqué) | `proof_change_record_preserves_what_an_auditor_reads` | `assertion failed: (e.flags & FLAG_CHANGE_APPLIED != 0) == applied` (`kani_proofs.rs:115`) |

**Zéro ligne `unwinding assertion` dans les deux** : ce sont des réfutations, pas des
indéterminations. La distinction décide si un `FAILED` veut dire quelque chose.

Le contrôle A est le plus utile : il tombe sur la garde ajoutée exprès pour que les régions
ne puissent pas se chevaucher. Le contrôle B montre que la propriété qui compte pour le
règlement — « légitime **ou illégitime** » — est bien celle qui est testée : perdre le bit
« refusé » laisse la chaîne de hachage parfaitement valide tout en rendant la preuve fausse.

## 3. Ce qui n'est pas prouvé ici

- **Trois des six harnais tournent sous un stub déclaré** (`chain` et `genesis`), parce
  qu'un programme GOTO contenant sha2 est tué par l'OOM killer sur cette machine. Ils
  prouvent donc le **séquencement et la conservation du contenu, pas la résistance aux
  collisions**. La propriété cryptographique est couverte par un test, pas par une preuve :
  `jrn_every_byte_of_an_entry_is_chained` inverse **chaque bit de chaque octet** d'une
  entrée et exige que chacun casse la vérification.
- **Rien sur silicium.** Les sites d'application réels (installation de firmware,
  enrôlement, révocation, élévation de politique, transfert de propriété) sont dans le
  firmware RP2040 ; le mécanisme est ici, le câblage et sa démonstration sur carte ne le
  sont pas.
- **Rien sur l'alinéa 2, 2ᵈᵉ phrase.** `ChangeKind::TamperSignal` est une *place* pour un
  signal matériel, tamper-evident comme le reste de la chaîne. OASIS ne détecte pas une
  intervention physique — aucun logiciel ne le fait — et ce type ne satisfait **pas** cette
  phrase à lui seul.
