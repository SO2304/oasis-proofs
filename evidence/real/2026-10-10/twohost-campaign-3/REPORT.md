# Rapport — la campagne complète sur HEAD, réglages par défaut (A.6 / T1, troisième dossier)

> *Expurgé pour publication le 2026-10-23 / redacted for publication on 2026-10-23 : chemins de sources, identifiants internes et noms de harnais retirés ; résultats inchangés.*

**2026-10-10, 22 h 50.** [withheld: test harness] à `2876fa7`, arbre propre, **tous les
réglages par défaut** (`RUNS_CABLE=3`, `RUNS_SHIPPED=3`). **98 contrôles sur 98.**

Pourquoi un troisième dossier : le premier (`../twohost-campaign/`, 61/61) a tourné sur le
script d'avant les quatre contournements ; le deuxième (`../twohost-campaign-2/`, 84/84) les a
mesurés avec `RUNS_CABLE=1` pour gagner du temps. Celui-ci est **le passage de référence** :
le code committé, le script complet, rien d'abrégé. Le montage, les clés nées sur PC2, les
cinq ordres, le rejeu B7b, le témoin sur PC2 et les limites sont ceux décrits dans
`../twohost-campaign-2/REPORT.md`, inchangés.

## 1. Résultats

| Phase | Ce qui tourne | Résultat |
|---|---|---|
| A, câble, outil d'ordre | 3 passages × 5 ordres | 1 `Act` = 1 écriture par passage (1, 2, 3) ; 4 refus avec le bon code, dont `0x0a` pour la clé sans `ACTUATE` |
| A2, câble, chemin livré | 3 répétitions, agent relancé à chaque fois | écriture, `0x02`, `0x03`, lecture ; latences 1 963 ± 3 %, 2 014 ± 24 %, 1 939 ± 18 % µs ; **621** écritures appareil, aucune perdue |
| B, LAN, chemin livré | C1–C7 et C10 × 3, B7b, latences × 3 | tout passe ; rejeu **refusé avant la porte** (`stale counter`) ; latences 6 320 ± 40 %, 4 936 ± 40 %, 5 137 ± 21 % µs ; **622** écritures |
| C, journaux | 3 chaînes, `Act` = écritures, falsification, témoin | `jrnA` 621 `Act` et 18 refus ; `jrnB` + archive 622 `Act` et 7 refus ; les trois `intact` ; refus réécrit → `broken`, exit 1 ; ancrage relu depuis PC2 octet pour octet, `ok` sur la chaîne, `DIVERGENCE` sur la copie réécrite |

Les 18 refus de A sont 3 × 4 attaques de l'outil d'ordre et 3 × 2 refus du chemin livré ;
les 7 de B sont 3 × 2 refus et le rejeu.

## 2. Latence, huit mesures par chemin, quatre campagnes

| Chemin | Mesures (µs, médiane ± demi-dispersion, K=10 × 20) | Plage |
|---|---|---:|
| Câble direct 100 Mbit/s | 1 972 ± 22, 1 961 ± 20, 1 946 ± 17, 1 886 ± 18, 1 914 ± 11, 1 963 ± 3, 2 014 ± 24, 1 939 ± 18 | **1,89 – 2,01 ms** |
| LAN, deux sauts Wi-Fi | 3 899 ± 30, 5 150 ± 27, 5 128 ± 63, 5 452 ± 29, 7 189 ± 83, 6 320 ± 40, 4 936 ± 40, 5 137 ± 21 | **3,9 – 7,2 ms** |

Le câble tient dans 6 % sur huit mesures : c'est un chiffre. Le Wi-Fi va du simple au double :
c'est un ordre de grandeur. L'appareil est un simulateur sans cycle d'automate, donc sa part
est un plancher (le plan `prompts/OASIS_FIELD_CONSTRAINTS.md` §1.2 dit comment lui en donner un).

## 3. Ce que ce dossier ajoute, et ce qu'il n'ajoute pas

Il ajoute la **répétition** : quatre campagnes, trois scripts successifs, le même verdict sur
chaque propriété (`Act` = écritures, refus nommés, rejeu refusé, chaînes intactes, falsification
détectée, témoin cohérent). Il n'ajoute aucune propriété nouvelle, et les réserves de
`../twohost-campaign-2/REPORT.md` §4 tiennent mot pour mot : témoin démontré en mécanique
seulement, rétention en tests unitaires seulement, pas de renvoi octet pour octet ni d'ordre
périmé entre machines, pas d'automate du commerce, Wi-Fi domestique, pare-feu de PC1 coupé.

## 4. Fichiers

Les mêmes que `../twohost-campaign-2/` : `campaign.log` (les 98 contrôles), les journaux de la
passerelle et de l'appareil, les trois chaînes et leurs verdicts, la copie réécrite, l'ancrage
local et sa relecture depuis PC2, `pc2/` (configurations sans graine, journaux des agents,
`witness.log` tel que PC2 le tient), `SHA256SUMS`. Adresse câble et compte de PC2 masqués.
