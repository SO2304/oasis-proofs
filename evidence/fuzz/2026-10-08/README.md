# Fuzz — les quatre parseurs du chemin de lecture (pilote A.6)

**2026-10-08.** `cargo +nightly-2025-11-21 fuzz run modbus_read -O`, ASan, Windows,
même chaîne que la campagne du 2026-10-07.

| | |
|---|---|
| Exécutions | **22 295 401** en 241 s (92 512/s) |
| Plantages | **0** |
| Couverture | 293 arêtes, 322 traits, corpus 42 unités / 412 o, **68 nouvelles unités** |
| RSS max | 585 Mo |

Reproduire (le runtime ASan doit être sur le `PATH`, voir
[`../2026-10-07/harness/fuzz_campaign.sh`](../2026-10-07/harness/fuzz_campaign.sh) — sans
lui le binaire sort en `STATUS_DLL_NOT_FOUND`) :

```bash
cd oasis-rt && cargo +nightly-2025-11-21 fuzz run modbus_read -O -- -max_total_time=240 -print_final_stats=1
```

## Pourquoi cette cible existe

Le chemin de lecture a introduit **quatre parseurs** que le réseau atteint —
`parse_omq1`, `parse_omv1`, `parse_tcp_read`, `check_read_response` — et l'affirmation du
dépôt (`SECURITY.md`, C10) porte sur les parseurs **effectivement fuzzés**. Un parseur que
seul Kani a vu est couvert pour les propriétés que le harnais énonce ; le fuzzing est ce qui
trouve celles que personne n'a pensé à énoncer. Ne pas ajouter la cible aurait laissé
l'affirmation vraie sur neuf parseurs et muette sur quatre nouveaux, ce qui est la forme
que prend une dette d'assurance.

## Ce que la cible vérifie

1. **`parse_omq1`** — une requête acceptée doit se ré-encoder **octet pour octet** sur les
   octets qui l'ont produite, sinon deux chaînes distinctes désignent une même requête.
2. **`parse_omv1`** — même identité, plus `1 ≤ count ≤ 8` : une réponse qui annonce plus de
   registres qu'elle n'en porte est refusée, jamais complétée par des zéros.
3. **`parse_tcp_read`** — ne rapporte **jamais** une écriture comme une lecture, ce qui
   ferait passer une écriture à côté du portail d'actionnement.
4. **`check_read_response`** — totale sur la réponse d'un équipement, y compris avec un
   `count` pour lequel la trame n'a pas été construite (1, celui demandé, et le maximum).
5. **La règle sur des spans choisis par l'attaquant** (`start`, `count`, `fc` tirés des
   octets d'entrée) : une trame existe **exactement** quand la règle a dit `Ok`, elle adresse
   exactement la requête, et **chaque** registre du span est dans la carte — la carte de
   test est volontairement non contiguë (10, 11, 20) pour qu'un span traversant le trou soit
   réellement refusé.

## Résultat

**Aucune anomalie.** C'est un résultat négatif et il se dit comme tel : 22,3 millions
d'exécutions ne prouvent pas l'absence de défaut, elles bornent ce qu'une recherche guidée
par la couverture a atteint en quatre minutes. À comparer avec la campagne du 2026-10-07,
où la cible la plus rapide a fait 3 × 10⁸ exécutions ; cette cible-ci est courte.

⚠️ Le total du dépôt reste donc **1,50 × 10⁹ pour les neuf parseurs du 2026-10-07** plus
**2,23 × 10⁷ pour ces quatre-ci**. Les deux chiffres ne se fondent pas en un seul : le
second n'a pas contribué au premier, et une moyenne cacherait que ce chemin est le moins
longuement fuzzé du dépôt.
