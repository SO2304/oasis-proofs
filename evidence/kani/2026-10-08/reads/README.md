# Kani — lectures authentifiées à travers la passerelle (pilote A.6) : 5/5 vérifiées

**2026-10-08, empreinte `92b2f84`.** Kani 0.68.0, CBMC via `cargo kani`, WSL2 Ubuntu,
clone propre de la révision committée (`git clean -qfd`), **sans stub**.

| | |
|---|---|
| Résultat | **5 vérifiées, 0 réfutée, 0 indéterminée** |
| Contrôles négatifs | **2 mutations, 2 échecs comme voulu, sur une propriété nommée** |
| Durée | ~60 s pour les sept exécutions |

Reproduire : `run_reads.sh main` (copié ici tel qu'exécuté).

⚠️ Un premier appel, `run_reads.sh 92b2f84`, a échoué : un SHA court n'est pas une
référence que `git fetch` accepte, le clone est resté sur `24497d1` et les cinq harnais ont
été rapportés **UNDETERMINED**. Le script a donc dit « je ne sais pas » au lieu de dire
« vérifié » sur le mauvais arbre, ce qui est le comportement voulu.

⚠️ **L'empreinte n'est pas dans les journaux.** Le runner imprime `stamp=92b2f84` sur sa
sortie standard, pas dans chaque `.log` — j'avais d'abord écrit ici le contraire, c'était
faux. La provenance est donc dans [`console.txt`](console.txt), la transcription complète
d'une exécution rejouée sur le même `main`, qui porte l'empreinte en tête et en pied et les
sept verdicts entre les deux. Les `.log` individuels ne contiennent que la sortie de `cargo
kani` et ne s'auto-attestent pas.

## 1. Les cinq harnais

| Harnais | Énoncé |
|---|---|
| `proof_omq1_parse_is_total` | `parse_omq1` est **totale** : toute chaîne d'octets rend une requête ou `None`, jamais une panique, et seule une longueur exacte avec le bon magic parse. Une passerelle l'appelle sur des octets fournis par le réseau |
| `proof_omv1_parse_is_total_and_count_matches_length` | `parse_omv1` est totale, et le `count` déclaré **correspond toujours** aux octets portés. Une réponse qui annonce 4 registres en portant 2 est refusée, pas complétée par des zéros : un zéro que l'opérateur lit comme une mesure est pire que pas de mesure |
| `proof_no_read_frame_without_ok` | **aucune trame n'atteint l'appareil si la règle n'a pas dit `Ok`**, et `Ok` exige que *chaque* registre de `start .. start+count` soit dans la carte — énoncé sur tout le span, pas seulement sur sa première adresse. C'est la propriété qui empêche FC03 d'être un scanner |
| `proof_read_frame_is_exactly_the_query` | quand une trame existe, elle adresse **exactement** la requête : même unité, même fonction, même premier registre, même nombre. La branche `Some` est contrainte atteignable, sinon le harnais passerait à vide |
| `proof_parse_tcp_read_never_accepts_a_write` | `parse_tcp_read` ne rapporte **jamais** une écriture comme une lecture — ce qui ferait passer une écriture à côté du portail d'actionnement |

## 2. Les contrôles négatifs

Un harnais vert ne prouve rien tant qu'on ne l'a pas vu échouer. Les deux mutations
portent sur les deux propriétés qui comptent, et toutes deux échouent **sur une propriété
nommée, avec zéro `unwinding assertion`** — la distinction est essentielle ici : un
`FAILED` sur `unwinding assertion loop N` est *indéterminé*, pas une réfutation.

| Mutation | Harnais | Vérifié nommé en échec |
|---|---|---|
| A — `span_allowed` ne contrôle plus que le premier registre (`while i < 1`) | `proof_no_read_frame_without_ok` | `"register {addr} was framed but is not in the map"` |
| B — `parse_omv1` ne lie plus la longueur déclarée aux octets portés | `proof_omv1_parse_is_total_and_count_matches_length` | `"a count that lies is refused"` |

La mutation B donne le résultat le plus instructif : elle ne fait pas que laisser passer un
`count` faux, elle fait **lire `parse_omv1` hors des bornes** —
`index out of bounds: the length is less than or equal to the given index`, deux fois, à
`mod.rs:230`. Le contrôle de longueur n'est donc pas cosmétique, et c'est Kani qui le
montre, pas une relecture.

La mutation A déclenche en plus un `attempt to add with overflow` à la ligne 71 du harnais :
l'arithmétique `q.start + i as u16` du harnais lui-même n'est plus protégée dès que
`span_allowed` cesse de valider le span avec `checked_add`. Sur l'arbre propre cette
addition ne peut pas déborder *parce que* la règle l'a déjà prouvé, ce qui est exactement la
dépendance que le harnais est censé exprimer.

## 3. Ce qui n'est pas prouvé ici

- **Rien sur les sockets.** Ces harnais portent sur la couche pure (`modbus_read`). Le
  chemin réseau est couvert par `oasis-rt/tests/mbtcp_pilot_sockets.rs` — cinq cas sur de
  vraies sockets contre un serveur **`rmodbus`**, dont « une lecture non listée est refusée
  **sans que l'appareil soit interrogé** », mesuré par un compteur dans l'appareil.
- **Rien sur la confidentialité.** Une lecture révèle des valeurs de registres à qui
  détient la clé de l'agent. L'enveloppe donne l'authenticité, pas le secret ; `sealed`
  (`OSE1`) est le module pour ça et ce chemin ne l'utilise pas.
- **Rien sur silicium.** Pas de RP2040, pas de vrai automate, pas de radio. Le chemin RTU
  est celui qui a été prouvé sur trois cartes en phase 1.4.
- Ces 5 harnais portent le total du dépôt à **194**, dont **aucun passage complet** sur
  l'ensemble n'existe : voir `CLAUDE.md` pour l'état exact des campagnes.
