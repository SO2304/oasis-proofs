# Kani — balayage séquentiel des 175 harnais non lourds : 175/175 vérifiés

**2026-10-08, empreinte `fb1db2c`.** Kani 0.68.0, CBMC 6.11.0, WSL2 Ubuntu 26.04,
**3 381 Mo de RAM, 4 cœurs**. Clone propre de la révision committée, un harnais à la fois,
`--harness-timeout 300s`.

| | |
|---|---|
| Résultat | **175 vérifiés, 0 réfuté, 0 indéterminé** |
| Périmètre | les **175** harnais que `oasis-rt/kani_shards.sh` ne déclare pas lourds |
| Non tentés | les **7 lourds**, auxquels le script de shards donne 60 min **chacun, seul**, dans `kani-heavy.yml` (hebdomadaire sur CI) |
| Durée | ~1 h 10 (16:05 UTC à la fin) |

## 1. Ce que ce passage corrige

Le seul passage intégral précédent (2026-10-07, `…/2026-10-07/full/`) avait rendu
**130 vérifiés, 10 indéterminés par manque de mémoire, 12 jamais atteints** avant que le
tueur d'OOM n'arrête la série. La conclusion qu'on en tirait — « la suite complète n'est
pas exécutable sur cette machine » — était **fausse dans sa cause** : ce n'étaient pas les
harnais, c'était le **parallélisme**. Un harnais à la fois, les 175 passent sur les mêmes
3 381 Mo.

Ce qui reste vrai : les **7 harnais lourds** ne sont pas tentés ici. Le script de shards
les isole parce qu'ils dépassent le budget de 600 s, et l'un d'eux
(`topics::…::proof_topic_hash_deterministic_1byte`) fait tuer `goto-instrument` avant même
CBMC — un SHA-256 sur un octet symbolique. **« 182/182 » reste donc faux** ; le chiffre
exact est **175 sur 182, et 0 contre-exemple sur ces 175**.

## 2. Répartition par shard

Le découpage vient de `oasis-rt/kani_shards.sh --all`, dont `--check` garantit que chaque
harnais est dans exactement un shard. Le détail par harnais est dans
[`results.tsv`](results.tsv) (`VERDICT`, code de retour, nom complet) et
[`assignment.txt`](assignment.txt).

| Shard | Harnais | Résultat |
|---|---:|---|
| `other-modules` | 63 | 63 vérifiés |
| `authority` | 34 | 34 vérifiés |
| `mesh-core-v0b` | 21 | 21 vérifiés |
| `authority-phase1` | 20 | 20 vérifiés |
| `mesh-ag-aj` | 14 | 14 vérifiés |
| `mesh-ac-af` | 14 | 14 vérifiés |
| `spinal-synapse` | 9 | 9 vérifiés |
| **total balayé** | **175** | **175 vérifiés** |
| `heavy-*` (7, isolés) | 7 | **non tentés** |

## 3. Ce que ça ne dit pas

- **Les 7 lourds restent inconnus en local.** Ils sont à la CI, et leur shard doit être
  vert pour être comptés — ce que `kani_shards.sh` écrit lui-même en commentaire.
- **Deux harnais de la campagne G/H/I tournent sous un stub déclaré** (`sha2` fait sortir
  le programme GOTO en OOM ici) ; c'est écrit dans `…/2026-10-07/hardening/README.md` et
  ce balayage ne change rien à ce point.
- **Un harnais vérifié prouve son énoncé, pas la sûreté du système.** Les énoncés sont
  dans les fichiers `kani_proofs.rs`, et plusieurs prennent la cryptographie comme un
  `bool` (`v0b_ok`, `quorum_ok`) parce qu'Ed25519 sous CBMC ne termine pas ici : la règle
  est prouvée, la cryptographie est testée. Chaque README de campagne le dit pour son
  périmètre.
- **Aucun contrôle négatif ici.** Les mutations qui doivent faire échouer les preuves sont
  dans les campagnes ciblées (`…/hardening/neg/`, `…/jk/neg/`, `…/c9/neg/`, `…/b1/neg/`).
  Un balayage vert sans contrôle négatif ne prouve pas que les preuves mordent ; ce sont
  ces campagnes-là qui l'établissent.

## 4. Reproduire

```bash
kani_sweep.sh <git-ref> [timeout_par_harnais=300]
```

Le script refuse de travailler hors de `$HOME`, part d'un clone propre de la révision
demandée, et écrit un log par harnais plus `results.tsv`.
