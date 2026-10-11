# B et C reflashées sur HEAD, et le journal des changements démontré sur silicium

**2026-10-09, empreinte `758ed59`.** Phase C.4 du prompt : « trois cartes RP2040
reflashées avec le firmware courant ». Fait sur **deux** cartes, **B** et **C**, avec
l'accord explicite de l'utilisateur pour la montée **irréversible** du plancher
anti-retour. **A n'a pas été touchée** : elle reste l'appareil Modbus sous `rmodbus`, sans
code OASIS, ce qui est la propriété qui rend vérifiable « aucun code OASIS dans
l'appareil ».

Tout est passé par le **chemin de mise à jour signée** de la phase 1.3 (`@U` téléversement,
`@Q` manifeste, `@M` installation), entièrement par USB, sans toucher aux cartes et sans
BOOTSEL — donc le plancher a joué son rôle au lieu d'être contourné.

| Carte | Avant | Après | Plancher | Identité |
|---|---|---|---|---|
| **B** `/dev/ttyS9` | v25, plancher 25, `6d3429f` | **v28, `758ed59`**, `ConfirmedAfterSwap` | 25 → **28** | `fp=f6bd34440030a136` **inchangée** |
| **C** `/dev/ttyS10` | v26, plancher 26, `ad8f24a` | **v28, `758ed59`**, `ConfirmedAfterSwap` | 26 → **28** | `fp=a7089677a10b7fb0` **inchangée** |
| **A** `/dev/ttyS8` | appareil Modbus | *non touchée* | — | — |

Les deux clés privées ont survécu au swap : elles vivent en flash hors des partitions
d'image, et c'est exactement ce que la phase 1.3 avait conçu. Propriétaire `o2`
(`owner_ed=5b8649c0cfcdbe78`), 3 pairs, epoch 2, des deux côtés.

## 1. Ce que le journal de B montre, et c'est le résultat qui compte

Annexe III 1.1.9 ¶5 demande la preuve d'une intervention « légitime **ou illégitime** »
dans le logiciel, **ou d'une modification du logiciel installé**. Le journal de B
(`11_B_journal.log`, décodé dans `12_journaux_decodes.txt`) porte les deux, dans l'ordre :

```text
slot=0 seq=0 boot=33445 fp=0000000000000000 valeur=27  Change(FirmwareInstalled) applique=False
slot=1 seq=1 boot=33445 fp=785fdbfb257ee0f6 valeur=28  Change(FirmwareInstalled) applique=True
```

- **slot 0 est une tentative refusée**, et elle est enregistrée. C'est l'installation que
  j'ai ratée (§3) : `NotAuthorized`, refusée en 4 475 µs. La valeur 27 est la version qui
  *tournait* alors, et l'empreinte est nulle parce qu'un refus n'a pas d'image à nommer.
- **slot 1 est l'installation acceptée**, version 28, et son champ de 8 octets porte le
  **début du SHA-256 de l'image installée** : `785fdbfb257ee0f6`. Le manifeste signé par
  o2 annonçait `sha256=785fdbfb257ee0f687851650fc05f1b5…`. **Identique octet pour octet.**
  Le digest est la seule information irrécupérable autrement, et c'est elle que le champ
  dépense.

Une modification du logiciel installé est donc tracée sur silicium, avec l'empreinte de
ce qui a été installé, et une tentative refusée l'est aussi.

## 2. ⚠️ L'installation de C est absente du journal de C

C a bien reçu, accepté et confirmé v28 (`08_C_v28_upload.log`, `09_C_final.log`), mais son
journal (`10_C_journal.log`) ne contient **aucune** entrée `FirmwareInstalled` : ses 13
entrées viennent des boots **49629** et **50908**, c'est-à-dire des campagnes J/K et de la
non-régression du 2026-10-08, et son boot courant est **53466**.

Ce n'est pas écrit ici comme un détail : **la même opération a été tracée sur B et pas sur
C**, et je ne sais pas encore pourquoi.

**Hypothèse, non vérifiée.** Les deux cartes rapportent `restored=false`, donc le journal
n'est pas rechargé depuis la flash au démarrage et `log_change` ouvre une chaîne neuve à
`seq=0`. Le journal de B en flash était vide — B est l'**origine** des ordres, pas
l'actionneur, donc elle n'avait aucune entrée de décision — et la chaîne neuve a écrit les
slots 0 et 1 sans rien heurter. Celui de C contenait déjà 13 entrées, et C affiche
`overwritten=0` : l'ajout n'a donc pas atterri. Si c'est la bonne explication, le défaut
est que **le journal d'un nœud dont la flash contient déjà une chaîne ne reprend pas cette
chaîne**, ce qui toucherait aussi les décisions ordinaires et pas seulement les
changements. À instrumenter avant d'affirmer quoi que ce soit.

En attendant, ce qui est démontré est : **le journal des changements fonctionne sur
silicium** (B, deux entrées dont un refus), et **il ne l'a pas fait sur C dans cette
exécution**.

## 3. Deux défauts de moi, dits parce qu'ils ont coûté un cran de plancher

1. **J'ai construit l'image sans `OASIS_BOARD_ID`.** La valeur par défaut est `X`, et B est
   revenue du swap en annonçant `OASIS|X|…` sur un nouveau port COM. Ce n'est pas cosmétique :
   `BOARD_ID == "C"` **gouverne** si une carte consomme les `OAC1`, `OAS1`, `OSB1` et
   `OMB1`, donc l'identifiant est fonctionnel. Pour B, relais et non actionneur, le
   comportement des chemins utiles était inchangé, mais les journaux auraient dit `X`.
   Corrigé en reconstruisant en v28 avec `OASIS_BOARD_ID=B`, ce qui a coûté **un cran de
   plancher de plus** (27 puis 28). L'identité cryptographique, elle, n'a jamais bougé.
2. **J'ai redirigé `2>&1` dans le fichier de manifeste.** `oasis_enroll fw-manifest` écrit
   le manifeste sur la sortie standard et un diagnostic lisible sur l'erreur standard ;
   en les fusionnant, la ligne `manifest: version=28 image_len=…` s'est retrouvée **dans**
   le hex. Le fichier faisait 5 207 caractères au lieu de 5 096 — exactement la longueur de
   cette ligne — et la carte a répondu `NotAuthorized` en 4 475 µs. C'est l'entrée slot 0
   du journal de B.

   Et le refus était **muet sur sa cause** : `update::install` replie les six raisons de
   `verify_authority` (`Malformed`, `UnknownKind`, `UnsupportedSuite`, `WrongNetwork`,
   `Downgrade`, `BadSignature`) sur un seul `NotAuthorized` par un `_ =>`. Ce qui m'a mis
   sur la piste n'est pas le message mais le **temps** : 4 475 µs contre 982 471 µs pour
   une acceptation, donc refusé **avant** toute signature.

## 4. Ce que ça ne montre pas

- **A n'est pas reflashée**, donc **aucun relais A→B→C sur HEAD** n'est démontré ici. La
  chaîne utile aujourd'hui est B (origine) → C (passerelle) → A (appareil Modbus), qui est
  la configuration de la non-régression du 2026-10-08 ; elle n'a **pas** été rejouée dans
  cette session.
- **Aucune mesure K=10.** Les deux durées citées (4 475 µs, 982 471 µs) sont des **tirs
  uniques** lus dans les journaux de la carte, données pour expliquer un diagnostic et non
  comme des performances.
- **Le plancher est monté irréversiblement** : B et C ne pourront plus jamais exécuter les
  firmwares `6d3429f` et `ad8f24a` sur lesquels les campagnes prouvées ont tourné. Les
  preuves déjà archivées restent valables ; c'est la possibilité de les **rejouer sur ces
  cartes** qui est perdue. C'était le prix accepté.
- **Une seule coupure de courant n'a pas été refaite** : les deux swaps se sont déroulés
  sans incident, donc le chemin de retour arrière du bootloader n'a pas été exercé ici.
- L'empreinte firmware rapportée par les cartes est `758ed59`, le commit de construction.
  Le commit `87e23c6` apparaît dans les journaux intermédiaires : c'est la même image à
  l'octet près côté firmware, seul `oasis-silicon-test/Cargo.lock` séparant les deux
  commits.
