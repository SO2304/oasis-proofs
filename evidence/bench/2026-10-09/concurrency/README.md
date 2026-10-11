# « Un ordre à la fois » : la mesure, le défaut qu'elle a trouvé, et ce qu'il a coûté

**2026-10-09, empreinte `aae60da`.** Tout ici vient de
[`run_concurrency.sh`](run_concurrency.sh), qui **refuse de tourner sur un arbre sale** :
la règle 5 veut que l'empreinte d'une campagne soit le commit mesuré, pas un arbre qui
n'existe plus. Reproduire :

```bash
bash evidence/bench/2026-10-09/concurrency/run_concurrency.sh
```

| | |
|---|---|
| Ce qui est mesuré | débit, latence, rapport IHM la plus lente / la plus rapide, et **refus par code**, à 1, 2, 5 et 10 IHM concurrentes |
| Bandes | K=10 exécutions, médiane ± demi-écart. Aucun tir unique |
| Résultat | la voie **sature dès N=2** ; un défaut trouvé, **1,8 % des écritures légitimes refusées** ; corrigé, et le correctif coûte **~45 % du débit** |
| Contre-épreuve | le défaut réinstallé par `git apply` fait **échouer le test 3 fois sur 3** |

## 1. Le plafond, et ce qui le fixe

Arbre corrigé, appareil en boucle locale ([`bench_delay0.log`](bench_delay0.log)) :

| N IHM | débit (acq./s) | latence médiane | la plus lente / la plus rapide | refus |
|---:|---:|---:|---:|---|
| 1 | 1 843 ±30 % | 450 µs ±15 % | 1,00× | aucun |
| 2 | 2 095 ±11 % | 888 µs ±7 % | 1,01× | aucun |
| 5 | 2 150 ±9 % | 2 198 µs ±5 % | 1,04× | aucun |
| 10 | 2 169 ±8 % | 4 447 µs ±6 % | 1,07× | aucun |

Le débit est à moins de 10 % de son maximum **dès N=2**. La latence, elle, croît presque
exactement avec N : ×9,9 pour dix fois plus de clients. Dix IHM ne font pas plus de
travail, elles attendent.

Et la boucle locale **flatte** la mesure : un automate a un cycle de scrutation. Avec
2 ms de temps de réponse ([`bench_delay2ms.log`](bench_delay2ms.log)) :

| N IHM | débit (acq./s) | latence médiane |
|---:|---:|---:|
| 1 | 307 ±7 % | 3 100 µs ±9 % |
| 2 | 320 ±7 % | 6 156 µs ±6 % |
| 5 | 324 ±2 % | 15 368 µs ±3 % |
| 10 | 321 ±2 % | 30 505 µs ±3 % |

**Plat.** Le débit ne bouge pas de N=1 à N=10 et la latence est linéaire à ±3 % près.
C'est la signature d'une sérialisation complète : le temps de réponse de l'appareil
domine et rien ne se recouvre.

⚠️ **Découper le verrou n'y changerait rien**, et c'est la conclusion contre l'intuition —
celle que le prompt proposait (« décision + journal sous verrou, échange réseau hors
verrou »). La ressource sérialisée n'est pas l'état de la passerelle : c'est **la
connexion unique vers l'appareil**. Un appareil, une connexion, une transaction à la
fois. Sortir l'échange du verrou laisserait deux ordres atteindre la même socket en même
temps, ce qui est faux pour Modbus TCP sur une connexion tenue. La capacité au-delà de ce
plafond passe par des **origines distinctes** — une identité enrôlée par IHM — que la
carte par origine et la séquence par origine de A.1 rendent possibles.

## 2. Le défaut : une écriture légitime sur cinquante, refusée

Toutes les IHM passent par le même agent, donc partagent **son** identité, donc **un seul
espace de `cmd_seq`** ; et la porte exige qu'il croisse strictement par origine. L'agent
relâchait son verrou **après la signature** et faisait l'aller-retour en dehors. Deux IHM
pouvaient donc réserver 5 et 6 et faire arriver 6 en premier : 5 devenait alors
`Reject(StaleOrReplayed)` — une écriture **légitime** refusée, rendue à l'opérateur en
exception **0x0A**, qu'il lit « non autorisé ».

Mesuré sous la mutation ([`bench_mutant_delay0.log`](bench_mutant_delay0.log)) :

| N IHM | débit (acq./s) | latence | refus |
|---:|---:|---:|---|
| 1 | 1 740 ±25 % | 488 µs ±13 % | aucun |
| 2 | 3 253 ±12 % | 498 µs ±7 % | aucun |
| 5 | 3 975 ±9 % | 1 078 µs ±10 % | **0x0A × 4** |
| 10 | 3 783 ±9 % | 2 165 µs ±5 % | **0x0A × 28** |

**32 refus sur 1 800 — 1,8 %** — et le registre de décisions de la passerelle elle-même
dit lesquels :

```text
  The gateway's own record of every non-Act decision, 32 in all:
      32  Reject(StaleOrReplayed)
  Acts: 1768
```

Ce point compte : la cause est **lue** et non déduite. Un 0x0A ne dit que « la porte a
refusé » ; laquelle des neuf conditions a tiré, seule la passerelle le sait, et c'est
exactement là qu'une explication plausible et fausse s'écrit. `spawn_gateway_counting`
collecte le `Served::Decided` que la passerelle rapporte déjà.

## 3. Ce que le correctif coûte, dit franchement

L'agent signe et émet maintenant dans la **même** section critique, donc les ordres
partent et sont répondus dans l'ordre où leurs numéros ont été distribués.

| | mutant | corrigé | |
|---|---:|---:|---|
| débit à N=5 | 3 975 | 2 150 | **−46 %** |
| débit à N=10 | 3 783 | 2 169 | **−43 %** |
| latence à N=5 | 1 078 µs | 2 198 µs | ×2,0 |
| refus légitimes | **32 / 1 800** | **0** | |

Le correctif coûte donc près de la moitié du débit. C'est payé volontiers : une
passerelle industrielle qui refuse 1,8 % des écritures légitimes en affichant « non
autorisé » n'est pas utilisable, et le débit perdu se récupère par des origines
distinctes, pas en faisant la course avec le compteur d'une seule identité.

⚠️ **La règle de décision n'est pas touchée** (règle 1 du prompt). Le défaut était dans
l'agent ; la porte faisait son travail. « Strictement plus récent que le dernier exécuté
pour cette origine » reste la condition, mot pour mot.

## 4. La contre-épreuve, et le test qui ne valait rien

[`mutant_lock_released.patch`](mutant_lock_released.patch) réinstalle le défaut par
`git apply` — pas un script qui édite les sources, pour rester en bash et en Rust
(règle 7). Le script **abandonne** si la mutation ne change rien.

| | résultat |
|---|---|
| arbre tel quel ([`test_clean.log`](test_clean.log)) | **3 verts sur 3** |
| mutation appliquée ([`test_mutant.log`](test_mutant.log)) | **3 rouges sur 3** — **5, 15 et 18** refus sur 300 |

⚠️ **La première version de ce test ne valait rien, et c'est dit ici parce qu'elle était
verte.** Écrite à 6 IHM × 5 écritures, elle a vu la contre-épreuve **passer 3 fois sur
3** : à 1,8 % de refus, 30 écritures en attendent 0,54, et une seule exécution n'en voit
souvent aucun. Elle aurait été livrée comme test de non-régression en ne détectant rien.
À 10 × 30, l'attente est de 5,4 et la contre-épreuve échoue de façon fiable.
L'arithmétique avant la confiance — c'est le troisième harnais vert-pour-rien de la
journée.

Deux autres défauts à moi, du même tonneau :

1. le test lisait **8 octets** de la réponse et laissait les **4 derniers** de l'écho FC06
   dans la socket. Sur une connexion **tenue** le flux se désynchronise, et l'octet
   d'adresse de la réponse suivante est lu comme un code de fonction : le test a ainsi
   « trouvé » 5 écritures manquantes qui étaient son propre bogue. L'autre helper du
   fichier ouvre une connexion par écriture et s'en sortait ;
2. il exigeait que la **dernière** valeur écrite soit la plus haute, ce qui est faux quand
   six IHM s'entrelacent : l'ordre global est celui des `cmd_seq`, pas celui des valeurs.

Et une erreur de méthode : j'ai lu `rc=$?` après un tuyau, donc le code de `head` et non
celui de `cargo`. Le banc n'avait pas compilé, et les premiers chiffres venaient du
binaire d'avant.

## 5. Ce que cette campagne ne montre pas

- **Aucun automate du commerce.** L'appareil est un répondeur local ; les 2 ms sont une
  valeur **injectée**, pas celle d'une machine mesurée. Les chiffres absolus sont un
  plancher.
- **Un seul hôte, en boucle locale.** Pas de réseau, pas de commutateur, pas de latence
  de lien. A.6 (deux machines, un câble) reste à faire.
- **Les lectures ne sont pas dans la mesure**, alors qu'une IHM en fait en permanence :
  elles passent par la même passerelle et prendront le même verrou.
- **Le défaut n'est pas prouvé absent**, seulement non observé à 0 refus sur 1 800 à ces
  N. C'est une propriété de l'ordonnancement, pas un théorème ; le harnais Kani ne couvre
  pas l'agent.
