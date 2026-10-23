# Huit heures devant un automate Siemens LOGO! réel

**Nuit du 2026-10-21 au 2026-10-22, 22 h 58 → 06 h 58.** La revue de fiabilité du 2026-10-11
reprochait ceci, et c'était son grief le plus lourd : « aucune exécution n'a dépassé quelques
minutes ». Les campagnes durent 30 s, le banc de concurrence pousse 300 écritures. Rien ne disait
ce qui se passe au bout de plusieurs heures.

> ⚠️ **Le script est sorti avec le code 1**, parce qu'il compte **2 anomalies**. Les deux sont
> attribuées à un essai S7 que l'opérateur menait sur le même automate en pleine nuit (§ 4), et
> aucune n'est imputable à OASIS. Le code de sortie est archivé tel quel plutôt que corrigé.

## 1. Le montage

| | |
|---|---|
| Appareil | **Siemens LOGO! 230RCE**, de série, aucun code OASIS dedans |
| Chemin | passerelle OASIS → Modbus TCP → automate, registre 100, plage 0..1000 |
| Vérité terrain | la valeur **relue dans l'automate** à chaque cycle par un client Modbus indépendant, en lecture seule, plus l'état des 4 bobines de relais |
| Cadence | un ordre toutes les ~5 s ; **un cycle sur cinq** envoie une valeur hors plage, qui doit être refusée sans toucher l'automate |
| Durée demandée | 480 min, atteinte |

Aucune écriture directe : ce banc n'écrit **que** par OASIS, sinon il ne mesurerait plus OASIS. Le
lecteur de contrôle ne sait pas écrire.

## 2. Résultat

| | |
|---|---:|
| Cycles | **5 652** |
| Écritures conformes — valeur commandée = valeur relue dans l'automate | **4 521** |
| Écritures non conformes | **1** (§ 4) |
| Refus respectés — automate inchangé | **1 130** |
| Refus violés | **0** |
| Bobines déplacées | **1** (§ 4) |
| Ordres en échec (code de retour) | **0 sur 5 652** |
| Journal, relu par le vérificateur indépendant | **`VERDICT intact entries=5652`**, code 0 |

**La passerelle n'a pas dérivé.** Relevé toutes les 50 itérations pendant huit heures :

| | début (cycle 50) | cycle 2000 | cycle 4000 | fin (cycle 5650) |
|---|---:|---:|---:|---:|
| fils d'exécution | 1 | 1 | 1 | 1 |
| descripteurs | 107 | 107 | 107 | 107 |
| mémoire (Ko) | 2 836 | 1 460 | 1 276 | **1 448** |
| temps processeur cumulé (s) | 0,19 | 2,39 | 3,20 | **3,81** |

Fils et descripteurs **constants**, mémoire qui **baisse** sur la durée, 3,81 s de processeur pour
8 heures. Aucune fuite observable sur cette fenêtre.

**Latence d'une écriture autorisée**, mesurée côté outil d'ordre, n = 4 522 :
min 145 ms, **médiane 164 ms**, p95 375 ms, max 5 626 ms. ⚠️ Ces chiffres incluent le démarrage d'un
processus par ordre — l'outil est relancé à chaque cycle — et ne sont donc **pas** comparables aux
459–468 µs mesurés en appel direct dans `evidence/bench/2026-10-08/mbtcp/`. Ce que la médiane établit
ici, c'est la **stabilité** sur huit heures, pas le coût du chemin.

## 3. Ce que le blocage de la veille devient

Un premier bain, le 2026-10-21 à 21 h 24, avait tenu **240 cycles parfaits** puis cessé d'être
servi : les ordres n'atteignaient plus la passerelle, qui restait vivante, et la boucle s'est figée.
Aucune écriture erronée — l'automate est resté à la dernière valeur autorisée et le journal était
intact sur 240 entrées.

**Il ne s'est pas reproduit en 5 652 cycles**, soit 23 fois plus long, ni en 558 cycles contre un
simulateur la même soirée. L'opérateur confirme n'avoir rien fait à 21 h 41. **La cause reste
inconnue**, et ce rapport ne prétend pas l'avoir trouvée : il établit que le défaut n'est pas
systématique et que la défaillance observée allait dans le sens fermé.

⚠️ L'hôte n'était pas au repos cette nuit-là : `charge_hote.txt` archive les deux fenêtres de
compilation que j'ai ouvertes (23 h 16–23 h 18 et 23 h 39–23 h 40, un cœur, priorité basse). Aucune
anomalie ne tombe dans ces fenêtres.

## 4. Les deux anomalies, et à quoi elles se rapportent

| Cycle | Heure | Ce qui est enregistré |
|---|---|---|
| 1 218 | 01:06:28 | attendu 369, le lecteur de contrôle a répondu `ERR` — mais l'ordre a réussi (`ORDER acted reg=100 value=369`) |
| 1 225 | 01:07:11 | bobines `0` → `1` : **Q1 s'est fermé** |

Les deux se rapportent à un **essai S7** que l'opérateur menait sur le même automate, et le
rapprochement est arithmétique, pas une impression : son compte rendu note que le registre de la
campagne « a continué d'évoluer seul, 375 → 383 » pendant l'essai, et la suite de valeurs de ce banc
place **375 au cycle 1 224 et 383 au cycle 1 232**. L'essai couvre donc exactement la fenêtre des
deux anomalies.

- **Cycle 1 225** : l'écriture S7 de l'opérateur a fermé Q1, ce que son compte rendu décrit. Le banc
  l'a enregistré indépendamment — deux relevés du même événement.
- **Cycle 1 218** : c'est le **lecteur de contrôle** qui a échoué à joindre l'automate, pas OASIS.
  L'ordre, lui, a abouti. Une défaillance de mesure, pas d'exécution.

⚠️ **Ce banc constate qu'une bobine a bougé, il ne prouve pas qui l'a bougée.** L'attribution vient
du compte rendu de l'opérateur, plus le fait qu'OASIS n'émet aucune écriture de bobine. Que le port
102 atteigne le relais est établi ailleurs (`evidence/real/2026-10-21/logo/REPORT.md`, erratum).

## 5. Ce que ce rapport ne montre pas

- **Un registre, une plage, un code de fonction.** Pas de FC16 — il coupe la liaison de cet automate.
- **Cadence de laboratoire** : un ordre toutes les 5 s, pas un automate en production.
- **Huit heures, pas huit jours.** Ni usure de la mémoire flash, ni rotation du journal : l'anneau
  n'a pas bouclé.
- **Un seul passage.** Pas de bande statistique sur plusieurs nuits.
- **L'hôte n'a pas été coupé** : aucune épreuve de panne de courant ici.
- **Le chemin Modbus n'était pas le seul** : le port 102 est resté ouvert toute la nuit, et l'essai
  S7 du § 4 en est la démonstration.
- **Ce n'est pas une fonction de sûreté** : ni SIL ni PL, et OASIS n'est jamais dans la chaîne
  d'arrêt d'urgence.

## 6. Fichiers

| Fichier | Contenu |
|---|---|
| `soak.log` | la trace du banc, points d'étape toutes les 50 itérations, les 2 anomalies |
| `orders.log` | les 5 652 ordres : horodatage, valeur, code de retour, durée, sortie de l'outil |
| `trend.log` | fils, descripteurs, mémoire et processeur de la passerelle, toutes les 50 itérations |
| `diag.log` | l'instantané pris à l'anomalie du cycle 1 218 |
| `gateway.log` | les décisions de la passerelle, acceptées et refusées |
| `journal.txt`, `jrn.head`, `jrn.entries` | le journal chaîné, 5 652 entrées |
| `charge_hote.txt` | les fenêtres de compilation ouvertes sur l'hôte pendant le bain |
| `exit_code.txt` | le code de sortie du script, archivé tel quel |

Ni graines, ni baux, ni configurations. `SHA256SUMS` couvre tous les fichiers présents.
