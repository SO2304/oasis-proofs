# OASIS jusqu'au relais d'un automate Siemens LOGO! réel

**2026-10-21, soir.** Suite de `../logo/REPORT.md` (l'après-midi), qui s'arrêtait à la mémoire :
la chaîne *décision → actionneur physique* n'y était pas démontrée. Elle l'est ici, dans les deux
sens, sur le relais **Q1** du même automate. Ce rapport consigne aussi un **défaut de la campagne
de l'après-midi** : son contrôle C8 ne pouvait pas échouer (§ 6).

## 1. L'appareil

| | |
|---|---|
| Modèle | **Siemens LOGO! 230RCE**, réf. `6ED1052-1FB08-0BA2`, 4 sorties relais 10 A |
| Serveur Modbus | **port 510** |
| Charge sur Q1 | **aucune** — l'opérateur a confirmé que rien n'est câblé sur Q1 à Q4 |
| Code OASIS embarqué | **aucun** |
| Version d'OASIS | une seule, inchangée pendant toutes les mesures de ce dossier |

## 2. Pourquoi il faut un programme dans l'automate

OASIS n'écrit **jamais de bobine** : la passerelle n'émet que des écritures de **registres** (FC06
et FC16), et l'agent côté opérateur ne transmet que FC06, FC16 et FC03. C'est voulu : OASIS
autorise une **consigne**, la machine garde sa logique. Un relais ne bouge donc que si le
**programme** de l'automate le décide.

L'aide livrée par Siemens avec LOGO!Soft Comfort V8.4 (*Fichier → Propriétés → espace d'adresses
Modbus*) donne la correspondance :

| Ressource LOGO! | Adresse Modbus | Sens |
|---|---|---|
| Q 1–20 (sorties relais) | bobines 8193–8212 | **lecture/écriture** |
| VW 0–850 (mots mémoire) | registres de maintien 1–425 | lecture/écriture |

D'où les deux parties : sans programme, Q1 n'obéit qu'à une écriture de bobine, qu'OASIS ne fait
pas (partie A) ; avec un programme *consigne > seuil → Q1*, une consigne signée commande le relais
(partie B).

## 3. Partie A — sans changer le programme : aucun chemin OASIS vers une bobine

**Un passage**, programme de l'après-midi (`NI1 → M1`, rien sur Q1). Q1 relu à chaque étape par un
client Modbus indépendant, en lecture seule.

| | Envoyé | Réponse | Q1 relu |
|---|---|---|---|
| A0 | — | — | 0 |
| **A1 témoin** | FC05 brut, 12 octets `00010000000601052000ff00`, **directement à l'automate** | écho : exécuté | **1** (puis FC05 « off » → 0) |
| A2 | le même paquet, au port de la **passerelle** | aucune | 0 |
| A3 | le même paquet, envoyé par une IHM à l'**agent** | exception `85 0a` | 0 |
| A4 | FC15 (bobines multiples) à l'agent | exception `8f 0a` | 0 |
| A5 | écriture de registre légitime (FC06, registre 100 ← 860) par l'agent | écho : exécuté, l'automate porte 860 | 0 |
| A6 | journal de la passerelle | `VERDICT intact entries=1` | — |

**14 contrôles sur 14**, avec une réserve : le contrôle du **code de sortie** de A6 était vide tel
qu'exécuté (même défaut qu'au § 6). Le fait qu'il visait est revérifié après coup avec le vrai
code : `partA/run1/journal.txt` est intact.

**Ce que A1 établit.** Un paquet de 12 octets, sans aucune authentification, ferme un relais de
l'automate. Le LOGO! n'a aucune protection propre sur ses sorties : c'est le témoin sans lequel
A2–A4 ne prouveraient rien.

La partie A **n'a pas été répétée** : une fois le programme de la partie B chargé, c'est lui qui
pilote Q1 et il écrase une écriture de bobine à chaque cycle. Ce passage unique reste la référence.

## 4. Partie B — avec programme : une consigne signée commande le relais

Programme chargé par l'opérateur avec LOGO!Soft Comfort **sous licence** : `NI1 → M1` conservé,
plus **entrée réseau analogique NAI1** (source VM, **VW 202**) → **seuil analogique** (500) →
**Q1**. VW 202 est réservé au relais, pour que les écritures des autres campagnes (VW 200) ne le
fassent pas claquer. OASIS n'a pas participé au chargement ; le programme est connu par son
**comportement mesuré**.

**Trois passages.**

| | Envoyé | Q1 relu, ×3 |
|---|---|---|
| **Témoin** | écriture **brute, non signée**, directe à l'automate : 600 puis 300 à l'adresse 101 | **1** puis 0 |
| R1 | ordre **signé**, identité avec `ACTUATE`, consigne 600 | **1** — `Act`, `plc_written=true` |
| R2 | ordre signé, consigne 300 | 0 — `Act` |
| R3 | ordre signé, consigne 5000, hors de la plage 0..1000 | 0 — `Reject(OutOfLimits)` |
| R4 | identité enrôlée **sans** `ACTUATE`, consigne 600 | 0 — `Reject(NotAuthorized)` |
| R5 | trame Modbus brute FC06 600 au port de la passerelle | 0 — connexion coupée |
| R6 | journal | `VERDICT intact entries=4`, code 0 |
| R7 | le premier refus réécrit en acceptation | `VERDICT broken at=3`, code 1 |

**8 contrôles sur 8, trois fois.** R3 et R4 ont un sens précisément parce que le témoin et R1
montrent qu'une consigne au-dessus de 500 **ferme** le relais : acceptées, elles l'auraient fermé.

**L'adresse est mesurée, pas supposée.** Les trois passages ont trouvé l'adresse **101** sur le
fil, ce que donne la table du § 2 en numérotation à partir de 1 (VW 202 = registre 102 = adresse
101) : la table est confirmée par la mesure.

**Le relais a réellement claqué.** L'état ci-dessus est celui que l'automate rapporte par Modbus ;
l'opérateur, présent à côté de l'automate, confirme avoir **entendu Q1 claquer**. C'est un
témoignage, pas une mesure : aucun capteur n'a enregistré le contact.

## 5. Ce que les refus laissent comme trace — une lacune

Les tentatives de commander directement le relais sont **refusées**, mais rien ne les distinguait,
à la date de ces essais, d'une déconnexion ordinaire : l'agent n'en garde que la ligne d'une
connexion qui se ferme, et la passerelle n'en sait rien, l'agent n'ayant rien transmis. La
tentative d'intervention la plus grave qui soit — actionner directement une sortie — était donc
refusée **sans laisser de preuve qu'elle a eu lieu**. L'annexe III 1.1.9 ¶5 demande de recueillir
les preuves d'une intervention « légitime **ou illégitime** » : c'est un manque, pas un détail.

Décidé le même soir : l'agent consignera chaque requête refusée avec son code de fonction, et
répondra `0x01` (« fonction illégale ») au lieu de `0x0A` (« chemin de passerelle
indisponible »), qui se lisait comme une panne. **Non encore éprouvé à la date de ce rapport.**

## 6. Défaut : le contrôle C8 de la campagne de l'après-midi ne pouvait pas échouer

Le contrôle C8 (« journal intact ») lisait le code de sortie d'une commande de mise en forme placée
après le vérificateur, et non celui du vérificateur : il valait toujours 0. C8 aurait validé un
journal falsifié. Trouvé en relisant le même contrôle, recopié dans les essais de ce soir.

| Preuve | Résultat |
|---|---|
| Le contrôle d'origine, sur un journal falsifié (`../logo/run1/journal_tampered.txt`) | code 0 — **passe** |
| Le contrôle corrigé, sur le journal intact | code 0 |
| Le contrôle corrigé, sur le journal falsifié | code 1 — **échoue**, comme il se doit |
| Les trois journaux de `../logo/`, revérifiés avec le vrai code | intacts, falsifications détectées |
| La campagne **relancée** avec C8 corrigé (`campagne-c8/`) | **12 sur 12, trois fois** |

Le **fait** publié l'après-midi tenait donc — les journaux étaient intacts —, mais le **contrôle**
qui l'affirmait n'en était pas un. Le même défaut se trouvait dans les autres essais écrits ce
soir, corrigé partout ; les campagnes antérieures publiées n'étaient pas touchées.

La campagne relancée part d'un registre à **0** : le transfert du programme de la partie B a remis
la mémoire VM à zéro.

## 7. Ce que ce rapport ne montre pas

- **Relais à vide.** Rien n'est câblé sur Q1 : aucun actionneur, aucune machine.
- **Le chemin Modbus n'était pas le seul.** Le port 102 (S7) de l'automate est resté ouvert, et un
  essai du 2026-10-22 a montré qu'une écriture S7 commande Q1 aussi sûrement qu'une écriture
  Modbus. OASIS ne garde que Modbus : le témoin de la partie A — l'automate obéit à n'importe qui —
  vaut donc pour **deux** protocoles, et la protection n'est effective que si tous les autres
  chemins sont fermés. ⚠️ L'état de la bobine, lui, **n'est pas exposé en S7** : la vérité terrain
  du relais se lit par Modbus ou sur le relais physique, jamais par S7.
- **FC16 coupe la liaison sur cet automate.** Mesuré le 2026-10-22 : une écriture multiple de
  registres fait tomber la connexion TCP du LOGO!, là où une écriture d'un seul registre passe sans
  problème. OASIS transmet le code de fonction de l'IHM **sans le changer**, donc un tel ordre
  atteindrait l'automate sous cette forme. L'issue est fermée — depuis le 2026-10-21 la passerelle
  ne réessaie pas en aveugle une requête déjà partie, et l'IHM reçoit une exception — mais **on ne
  sait pas si l'écriture avait atterri** avant la coupure, et rien ne permet aujourd'hui de déclarer
  à la passerelle qu'un appareil ne tolère que les écritures d'un seul registre.
- **Un module logique, pas un S7-1200/1500**, et une logique de seuil réduite à un bloc.
- **Un relais, un registre, FC06.** Topologie T2 : outil d'ordre, agent et passerelle sur le même hôte.
- **Pas une fonction de sûreté.** Q1 commandé par une consigne autorisée n'est en aucun cas un
  chemin d'arrêt d'urgence ; OASIS n'est jamais dans cette chaîne.
- **« broken at » n'est pas une localisation** : c'est l'endroit où la vérification s'arrête (la
  dernière entrée), pas l'entrée falsifiée — une seule empreinte de tête détecte, elle ne localise pas.
- **Exécutions courtes.** Un bain d'endurance lancé le même soir devant ce LOGO! a tenu 240 cycles
  parfaits puis cessé d'être servi, sans aucune écriture erronée ; il fait l'objet d'une enquête
  séparée et n'est pas couvert ici.

## 8. Ce que ce dossier publie

Les résultats : journaux d'exécution, journaux de décisions, verdicts du vérificateur, sorties des
ordres, et pour la trame brute injectée, la trame et la réponse (vide). Les scripts d'essai, les
configurations et les identités de test ne sont pas publiés. `SHA256SUMS` couvre tous les fichiers
publiés.
