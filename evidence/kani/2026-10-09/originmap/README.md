# Kani — une carte de registres par origine (pilote A.1) : 3/3 vérifiées

**2026-10-09, empreinte `f391ed7`.** Kani 0.68.0, WSL2, clone propre de la révision
committée, **sans stub**. Reproduire : `run_originmap.sh max-tech-2026-10-09` (copié ici tel
qu'exécuté). Provenance : [`console.txt`](console.txt), portant l'empreinte en tête et en
pied.

| | |
|---|---|
| Résultat | **3 vérifiées, 0 réfutée, 0 indéterminée** |
| Contrôle négatif | **1 mutation, échec sur une propriété nommée, 0 `unwinding assertion`** |
| Durée | ~11 min |

## 1. Le manque que ça ferme

La carte de registres était **partagée** : toute clé que la configuration autorisait pouvait
écrire **tous** les registres de la carte. Le firmware exige
`registry.allows(origin, ACTUATE)` *et* sa propre carte ; la voie TCP avait la permission
depuis C18 et la carte seulement maintenant. La demande réelle d'un pilote est « cette IHM
peut déplacer l'axe 1 entre 0 et 100, celle-là ne peut que remettre le compteur à zéro » —
une question d'autorisation, pas un contrôle de plage.

## 2. Les trois harnais

| Harnais | Énoncé |
|---|---|
| `proof_mb_no_frame_outside_the_origin_map` | **nouveau.** Si un ordre est « dans les limites » pour une origine, alors l'unité correspond **et** chaque registre écrit figure dans les entrées **de cette origine** avec sa valeur dans la plage de cette entrée. Et, dans l'autre sens, une origine absente de la table obtient **exactement** le verdict de `check_rules` sur la carte partagée — c'est ce qui rend l'ajout sûr : une règle pour une origine ne peut pas élargir ce qu'une autre peut écrire |
| `proof_mb_no_frame_without_act` | inchangé, re-vérifié : une trame n'existe que pour une décision `Act` |
| `proof_mb_frame_matches_rules` | inchangé, re-vérifié : la trame correspond à l'ordre dans les règles |

Les deux derniers sont rejoués parce que `gateway_decision_ctx` a été **réusiné** :
`gateway_decision_with_rules` a été extrait pour que la carte partagée et une carte par
origine partagent **un seul** site qui construit une trame. Un réusinage qui laisse les
preuves existantes sans les rejouer n'est pas un réusinage, c'est un pari.

## 3. Le contrôle négatif

| Mutation | Harnais | Vérifié nommé en échec |
|---|---|---|
| le filtre par origine est retiré du parcours de la carte (`if e.rule.addr == addr` au lieu de `if &e.origin == origin && …`) | `proof_mb_no_frame_outside_the_origin_map` | `"a register was allowed that is not in this origin's own map"` (`kani_proofs.rs:173`) |

**Zéro ligne `unwinding assertion`** : c'est une réfutation, pas une indétermination. La
mutation est la plus proche possible du défaut qu'on craint — une origine lisant la carte
d'une autre — et le harnais la voit.

## 4. Ce que la campagne a trouvé que les preuves ne pouvaient pas

Les harnais portent sur la règle pure. La campagne a montré que la fonctionnalité était
**inutilisable** telle quelle, pour une raison hors de la règle : `last_executed_seq` était
**une seule valeur pour toute la passerelle**, donc la première origine à exécuter
`cmd_seq=1` transformait le `cmd_seq=1` de toutes les autres en rejeu. Journal, cas C25 :

```text
[0] origin=aa00 cmd_seq=1  Act
[2] origin=ee00 cmd_seq=1  Reject(StaleOrReplayed)
```

Deux émetteurs autorisés ne pouvaient pas commander la même passerelle — ce qui vide la
carte par origine de son sens. Le compte est désormais **par origine**.

⚠️ **La règle 1 du prompt est respectée.** Les neuf conditions ne changent pas, et
« strictement plus récent que le dernier exécuté » ne change pas non plus : seul **ce par
rapport à quoi** c'est plus récent change — le dernier ordre de cette origine au lieu de
celui de la passerelle. La règle pure prenait déjà `last_executed_seq` en paramètre, donc
elle est intacte ; c'est l'appelant qui choisit une meilleure valeur. L'anti-rejeu d'une
origine est préservé (**C27** : rejeu de son propre numéro → `Reject(StaleOrReplayed)`), et
une origine ne peut plus consommer des numéros qui en bloquent une autre.

## 5. Ce qui n'est pas prouvé ici

- **Rien sur silicium.** Le portail RTU du firmware garde la carte partagée ; seule la voie
  TCP a la carte par origine.
- **Le compte par origine est en RAM** (`GatewayState::last_seq`) : un redémarrage de
  passerelle l'oublie, et un ordre d'avant le redémarrage est alors refusé sur son
  `boot_id`, que le portail contrôle de toute façon. La séquence n'a donc pas besoin de
  survivre au redémarrage — c'est l'identifiant de démarrage qui rend refusable l'ordre
  d'une exécution précédente.
- **La carte reste compilée dans la configuration**, non signée : qui édite le fichier
  édite les droits. Une attestation `OAU1` signée par le propriétaire sur ce lien reste à
  faire, comme pour la révocation avant C15 et pour les permissions depuis C18.
