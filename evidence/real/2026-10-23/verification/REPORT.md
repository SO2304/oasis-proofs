# Vérification du 2026-10-23 : chaque essai trois fois sur l'automate, au commit attribuable

**Demande :** vérifier chaque essai, l'automate branché. Le lien Ethernet était coupé à l'arrivée —
carte du PC déconnectée, pas de ping, port 510 fermé pendant une heure — et ne s'est rétabli qu'à
08 h 23. Tout ce qui ne dépendait pas de l'automate a été vérifié pendant ce temps, et c'est là que
les trois défauts de la journée ont été trouvés.

## 1. Les quatre campagnes, sur le LOGO! réel

| Campagne | Passage 1 | Passage 2 | Passage 3 | Ce qui a changé ce matin |
|---|---|---|---|---|
| base | **15/15** | **15/15** | **15/15** | le **contrôle négatif** y est intégré (C10–C12) |
| relais, partie A | **18/18** | **18/18** | **18/18** | témoin déplacé de **Q1 à Q2** ; code d'exception éprouvé ; décisions comptées |
| relais, partie B | **8/8** | **8/8** | **8/8** | inchangée |
| GS-IFA-M25 | **33 J / 0 N** | **33 J / 0 N** | **33 J / 0 N** | nouveau critère **T03**, la provenance |

**Trois passages par essai**, le premier à part ce matin (`<essai>/`), les deux suivants en tours
alternés — base, relais A, relais B, M25, puis de nouveau — pour que deux passages d'un même essai ne
se suivent pas (`<essai>_r2/`, `<essai>_r3/`, journal `passages_2_3.log`). Tous avec les binaires
gravés **`d1674874e0df`**, compilés sur des
entrées propres ; la tête était `632b906`, un commit de documentation qui ne touche aucune entrée de
la compilation. **Ces passages sont donc attribuables à une source précise — ce que ceux d'hier
n'étaient pas.**

**762 tests**, 43 suites, 0 échec, au même commit.

## 2. Ce que chaque campagne a révélé

**Base — le contrôle négatif n'était pas automatisé.** Le rapport du 2026-10-21 l'appelle « celui qui
compte » : l'automate, seul, accepte ce qu'OASIS refuse, donc les refus sont l'œuvre d'OASIS. Il
avait été mené **à la main** et ne faisait pas partie de la campagne, si bien que ses 12/12
revérifiaient les refus sans revérifier que l'automate les aurait acceptés. Si son programme venait
à brider ces registres, la campagne passerait pour une raison étrangère à OASIS. Il tourne
désormais dans la campagne, après les contrôles d'OASIS, et restaure ce qu'il a écrit :

| | Résultat |
|---|---|
| C10 — 5000 au registre 100, sans OASIS (refusé en C2) | **accepté**, le registre porte 5000 |
| C11 — 42 au registre 200, sans OASIS (refusé en C3) | **accepté**, le registre porte 42 |
| C12 — valeurs restaurées | 727 / 0 |

**Relais A — le témoin a refusé de conclure, et il avait raison.** Un FC05 brut sur Q1 n'a pas fermé
le relais. Cette partie avait été menée le 2026-10-21 **avant** que le programme à seuil soit chargé ;
Q1 est depuis **pilotée par le programme**. Mesuré : l'automate **accuse réception** du FC05 sur Q1 —
réponse de succès — mais la sortie reste à 0, réécrite à chaque cycle. **Une réponse de succès ne dit
pas que la sortie a bougé.** Q2, que le programme ne pilote pas, se ferme et s'ouvre sur FC05 brut :
le témoin y est passé, et la propriété éprouvée est inchangée — OASIS ne donne aucun chemin vers
**aucune** bobine. Rien n'est câblé sur Q1–Q4.

Deux contrôles ajoutés. Le code d'exception que l'agent renvoie à un FC05 et à un FC15 est éprouvé
pour la première fois sur le chemin livré devant l'automate réel : **`85/01` et `8f/01`**, la
« fonction illégale » introduite le 2026-10-22 (la partie ne vérifiait que le code de fonction). Et
le compte du journal, qui attendait **1** entrée et en trouvait **2**, compte maintenant les
**décisions** : une seule, un `Act`, et la chaîne commence par l'identité logicielle. Le compte total
se trompait sur le sens, pas sur le fait — vérifié sur le journal avant de changer quoi que ce soit.

**M25 — T03.** Le binaire annonce `d1674874e0df` ; aucune entrée de la compilation ne diffère entre ce
commit et la tête. **T03 = J.**

## 3. T03 sait échouer

Un contrôle né ce matin n'est pas un contrôle tant qu'on ne l'a pas vu échouer. Un binaire compilé à
partir d'un arbre de travail **modifié** — aucune modification du code exécuté — s'annonce
**`632b906f84dc-dirty`**. Avec lui, l'essai complet donne **T03 = N** (« n'est attribuable à aucun
commit ») et **les 32 autres critères restent J** : le contrôle discrimine sur la provenance et sur
rien d'autre. Dossier `m25_negctl_t03/`. Les binaires de contrôle ont été retirés ensuite.

## 4. Ce que cette vérification ne montre pas

- Les trois passages ont été **vérifiés comme ayant agi**, pas seulement comme verts : la base a
  écrit trois valeurs différentes (727, 921, 170) et son contrôle négatif a vu 5000 et 42 acceptés
  aux trois passages ; le témoin de la partie A a fermé Q2 trois fois ; la partie B a fermé puis
  rouvert Q1 trois fois ; l'essai M25 rend la **même empreinte de verdicts aux trois passages**
  (`9b20f06ae4577947`), 320 mutations et aucune acceptée chaque fois, T03 = J chaque fois.
- Le contrôle négatif de T03 n'a tourné **qu'une fois** : c'est un contrôle du contrôle, pas un essai.
- Le contrôle négatif de la campagne de base écrit en direct dans l'automate — c'est sa raison
  d'être — puis restaure ; il touche deux mots mémoire, aucun relais.
- Toutes les limites des campagnes elles-mêmes restent : un module logique et non un S7-1200/1500,
  topologie T2, relais à vide, port 102 ouvert.

## 5. Fichiers

`campagne/`, `relais_a/`, `relais_b/`, `m25/`, `m25_negctl_t03/` : la console de chaque passage, ses
journaux et ses verdicts. Les harnais d'essai ne sont **pas publiés** : ce corpus porte les
résultats, pas la méthode. `suite.txt` :
le résumé de la suite de tests. Ni graines ni configurations. `SHA256SUMS` couvre tous les fichiers
présents — et il est calculé **en dernier**, après ce rapport.
