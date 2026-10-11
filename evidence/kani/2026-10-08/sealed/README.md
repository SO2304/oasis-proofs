# Kani — `OSE1`, confidentialité bout en bout (C13) : 5/5 vérifiées

**2026-10-08, empreinte `24497d1`.** Kani 0.68.0, CBMC 6.11.0, WSL2 Ubuntu 26.04,
3 381 Mo. Clone propre de la révision committée, **sans stub**.

| | |
|---|---|
| Résultat | **5 vérifiées, 0 réfutée, 0 indéterminée** |
| Contrôle négatif | **2 mutations, 2 échecs comme voulu** |
| Passage 1 (`dd993b5`) | **2 réfutées et 1 passant à vide** — voir [`run1/`](run1/) |

## 1. Les cinq harnais

| Harnais | Énoncé |
|---|---|
| `proof_sealed_dest_total` | `sealed_dest` est **totale** : toute chaîne d'octets rend une empreinte ou `None`, et une empreinte seulement si la longueur atteint `ose1_len(0)` et que le magic est bon. Un relais l'appelle sur des octets fournis par l'attaquant |
| `proof_sealed_dest_accepts_a_wellformed_blob` | la branche `Some` est **atteignable** : un blob assez long au bon magic rend bien une empreinte, égale octet pour octet à l'en-tête. Ce harnais n'existe que pour épingler cette atteignabilité (§3) |
| `proof_ose1_len_is_sane` | `ose1_len` est monotone et ne déborde pas, donc un contrôle de longueur ne peut pas être franchi par débordement |
| `proof_nonce_is_injective_in_the_counter` | deux compteurs distincts ne partagent **jamais** un nonce, et les octets hauts sont nuls. C'est la propriété qui rend un compteur persisté utilisable comme source de nonce pour ChaCha20-Poly1305, où une répétition est fatale |
| `proof_open_refuses_another_destination_without_crypto` | `open` refuse sur l'empreinte de destination **avant** de toucher l'AEAD : un nœud ne fait aucun travail cryptographique pour du trafic qui ne lui est pas adressé |

## 2. Ce qui est prouvé et ce qui est testé

ChaCha20-Poly1305 et X25519 ne terminent pas sous CBMC sur cette machine. Ce qui est
prouvé ici est donc **le cadrage et l'adressage** — ce qui décide si un blob est même
remis à l'AEAD. La cryptographie est **testée** dans `sealed/tests.rs` : accord de clé des
deux côtés sans échange, clé de scellement différente de la clé de lien du même couple,
aller-retour rendant des octets que le parseur de la partie F accepte inchangés, un relais
détenant les deux clés publiques qui **ne peut pas** ouvrir, cinq AAD erronés refusés, et
un balayage **exhaustif** d'inversion d'un octet. Le partage est le même que pour `quorum`
et `actuation`, et il est dit plutôt que sous-entendu.

## 3. Deux errata du premier passage, et le pire des deux

**`run1/console_run1.txt`** conserve la trace du passage sur `dd993b5` : **deux harnais
réfutés**. Les deux avaient tort **dans le harnais, pas dans le code** — ils affirmaient
encore `OSE1_HEADER_LEN + n + OSE1_TAG_LEN`, formule d'avant la correction de structure
qui a porté l'overhead à `OSE1_OVERHEAD = 50`. Le module et les tests avaient été mis à
jour, les preuves non.

**Corriger cela a révélé un défaut plus grave.** Les tampons étaient `[u8; 32]`, **sous le
minimum de 50 octets** d'un blob scellé : `sealed_dest` ne pouvait donc que renvoyer
`None`, les branches `Some` étaient **inatteignables**, et
`proof_open_refuses_another_destination_without_crypto` passait **à vide**. Un harnais qui
ne peut pas atteindre le comportement qu'il nomme ne vaut rien. Le contrôle négatif A
héritait du défaut : il échouait **avant et après** la mutation, donc il ne prouvait rien.

Correctifs : `BUF = 64`, chaque harnais **affirme** l'atteignabilité de sa branche au lieu
de la supposer, et un cinquième harnais ne sert qu'à cela. Depuis, le contrôle négatif A
mord vraiment : la preuve passe sur l'arbre non muté et échoue sur le muté.

## 4. Contrôle négatif — `neg/`

| Mutation | Preuve qui doit échouer | Résultat |
|---|---|---|
| la borne de longueur de `sealed_dest` tombe à 4 | `proof_sealed_dest_total` | **FAILED**, comme voulu |
| le nonce n'emporte que 4 octets du compteur, donc deux compteurs peuvent le partager | `proof_nonce_is_injective_in_the_counter` | **FAILED**, comme voulu |

## 5. Ce que ces preuves ne disent pas

- **`OSE1` ne cache pas l'adressage.** L'en-tête de l'enveloppe reste en clair par
  construction — origine, compteur, longueur, réseau — et `sealed_dest` est lisible par un
  relais, puisque c'est ainsi qu'un nœud sait qu'un contenu ne lui est pas destiné. Un
  observateur voit toujours **qui parle à qui, à quelle fréquence, et sur quelle
  longueur**. L'analyse de trafic est une ligne distincte du modèle de menace et **n'est
  pas fermée**.
- **Rien sur silicium.** Le firmware n'émet ni n'accepte `OSE1` ; c'est du logiciel hôte.
- **La porte n'est pas touchée** et ce n'est pas un hasard : `open` rend les octets
  `OAC1` d'origine et la règle de la partie F tourne dessus sans modification. Une couche
  de confidentialité ne doit pas devenir un second chemin d'autorisation.
- **v0B n'est pas touché** non plus : un blob scellé est une charge utile comme une autre.

## 6. Reproduire

```bash
run_sealed.sh <git-ref>
```
