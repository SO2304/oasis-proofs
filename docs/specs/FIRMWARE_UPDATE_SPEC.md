# Phase 1.3 — Mise à jour du firmware signée (spec)

Prompt : `prompts/OASIS_VS_VERIDIFY.md`, phase 1, point 3 : deux emplacements (A/B),
image signée, compteur anti-retour persisté (même mécanisme que la réserve de
compteurs), retour automatique si la nouvelle image ne démarre pas ; sur silicium,
image valide installée, image modifiée, ancienne et d'un autre signataire refusées,
coupure pendant l'écriture sans brique.

## 1. Chargeur de démarrage : `embassy-boot`, pas un chargeur maison

- **`embassy-boot` 0.7.0 + `embassy-boot-rp` 0.10.0** (Embassy, 2026-03-20, maintenus,
  ~148 000 téléchargements pour `embassy-boot`). Lu dans les sources :
  - **permutation A/B résistante aux coupures** : un index de progression dans la
    partition d'état permet de reprendre une copie interrompue ;
  - **démarrage à l'essai** : après une permutation, si l'application n'appelle pas
    `mark_booted()` avant le prochain redémarrage, le chargeur **revient** à l'image
    précédente (`prepare_boot` : état `Swap` déjà permuté → `revert`) ;
  - **chien de garde** démarré par le chargeur (`WatchdogFlash`) ; il continue dans
    l'application, ce qui provoque le redémarrage — donc le retour — si la nouvelle
    image se bloque.
- Écrire un chargeur à la main serait le seul vrai risque de « brique ». On prend
  donc l'existant. Sa vérification de signature intégrée (Ed25519 seul, sur
  SHA-512) n'est **pas** utilisée. La porte est la nôtre, hybride (§3).
- **Compatibilité de la partition d'état** : `embassy-rp` écrit par octet
  (`WRITE_SIZE = 1`, pages de 256 o complétées par 0xFF) avec des secteurs de 4 Kio.
  L'application, restée sur `rp2040-hal`, implémente le même `NorFlash`
  (`embedded-storage`) au-dessus de `rp2040-flash`, de la même façon. Les deux côtés
  lisent donc la même structure d'état. C'est vérifié en premier sur une carte.

## 2. Carte de la flash (2 Mio)

| Décalage | Taille | Contenu |
|---|---|---|
| `0x000000` | 28 Kio | boot2 + chargeur (`oasis-bootloader`, nouvelle crate hors espace de travail ; taille réelle mesurée) |
| `0x007000` | 4 Kio | état du chargeur (2 + 4 × 128 octets nécessaires) |
| `0x008000` | 512 Kio | **ACTIVE** (le firmware actuel fait ~300 Kio) |
| `0x088000` | 516 Kio | **DFU** (ACTIVE + 1 page, exigence d'`embassy-boot`) |
| `0x1F2000` | 2 × 4 Kio | **plancher anti-retour** (nouveau) |
| `0x1F4000` | 48 Kio | état OASIS existant : registre, propriétaire, identité, politique, révocation, réserve, fenêtre v0B. **Inchangé** : les cartes gardent clés, propriétaire et pairs |

L'application est liée à `0x10008000`, sans boot2 (fonctionnalité `bootloaded` de
`oasis-silicon-test`). Les autres binaires de test restent autonomes.

## 3. Manifeste signé (`OAU1`, type 3) et porte d'installation

Contenu signé par le propriétaire **courant** (o2 sur les cartes aujourd'hui) :

```
version u32 | image_len u32 | sha256(image)[32] | hw_id[8] (= "RP2040U1")
```

- **`AuthPolicy::default()` exige l'hybride pour le type 3**, comme pour la
  politique et la propriété : une image de firmware peut tout faire.
- L'image porte sa version à une adresse fixe : section `.oasis_fwinfo` juste
  après la table des vecteurs (`"OFWI" | version u32`), couverte par le hash.
- **Installation acceptée si et seulement si** :
  1. `verify_authority` réussit (clés du propriétaire courant, politique, réseau) ;
  2. `hw_id` correspond ;
  3. `image_len ≤ 512 Kio` ;
  4. le SHA-256 de la partition DFU sur `image_len` égale le hash du manifeste ;
  5. la version lue dans l'image égale celle du manifeste ;
  6. `version ≥ plancher` **et** `version > version en cours`.

  Alors `mark_updated()` puis redémarrage. La règle (6) est une fonction pure
  prouvée par Kani.

## 4. Plancher anti-retour : le même mécanisme que la réserve de compteurs

Le plancher est un `u64` monotone stocké avec **`tx_lease::DualSlotStore`**
(`CeilingStore`), sans modification : deux emplacements avec somme de contrôle, le
plus grand gagne, et une écriture déchirée ne perd que la valeur en cours
d'écriture.

Au premier démarrage d'une nouvelle image (état `Swap`), **à l'entrée de la boucle
principale** (toute l'initialisation a abouti), dans l'ordre :
1. auto-test : clés et état OASIS lisibles, vérification hybride d'un vecteur connu ;
2. `plancher = max(plancher, ma version)`, rendu durable ;
3. `mark_booted()` ;
4. arrêt du chien de garde.

- Une coupure entre 2 et 3 provoque un retour vers l'ancienne image avec un
  plancher déjà relevé. Réinstaller la nouvelle reste possible, puisque
  `version ≥ plancher` et `> version en cours`. L'ancienne image, elle, ne peut plus
  revenir **par la mise à jour**.
- Si l'auto-test échoue, l'image ne s'est pas confirmée : le chien de garde (≤ 8 s)
  ou le gestionnaire de panique redémarre la carte, et le chargeur revient en
  arrière.
- **Changement (2026-10-07)** : la confirmation se faisait d'abord juste après le
  chargement des clés, puis le chien de garde était arrêté. Un blocage dans la suite
  de l'initialisation (routeur, fenêtre v0B, réserve de compteurs, liste de
  révocation) n'aurait alors été rattrapé ni par le chien de garde ni par le retour.
  Elle est déplacée à l'entrée de la boucle principale.
- **Changement** : dans le firmware chargé par le chargeur, la panique fait
  `sys_reset` au lieu d'entrer en BOOTSEL, sinon le retour automatique n'aurait pas
  lieu.

## 5. Transport (USB, pas le maillage)

- `@U<offset 8 hex><≤ 256 o hex>` écrit dans la DFU avec le `BlockingFirmwareUpdater`
  d'embassy-boot.
- `@Q`, puis `@M`, chargent et vérifient le manifeste, puis installent.
- `@V` donne la version, le plancher et l'état du chargeur.
- Environ 1 200 lignes pour 300 Kio.
- Diffuser 300 Kio par le maillage UART (~1 660 fragments de 185 o utiles, ~8,4 min par saut) est hors
  périmètre.

## 6. Preuves prévues

**PC** (`oasis-rt/src/firmware.rs`, < 400 lignes) : analyse du manifeste et de
`.oasis_fwinfo`, règle d'installation (tous les refus un par un), politique type 3
hybride, bout en bout avec signatures o1/o2/o3.

**Kani** :
- une installation acceptée implique signature, hash, version d'image, et
  `version ≥ plancher` et `> en cours` ;
- l'analyseur du manifeste ne panique jamais ;
- le plancher ne baisse jamais (les preuves `tx_lease` existantes couvrent
  `DualSlotStore`).

**Silicium**, sur une carte (C), puis l'installation valide sur les trois cartes :
1. chargeur + v1 flashés en UF2 ; `@V` : v1, plancher 1, état `Boot` ;
2. **v2 valide** (manifeste o2) → permutation → v2 démarre, se confirme, plancher
   2 ; le maillage fonctionne toujours ;
3. **image modifiée** (1 octet après signature) → refusée (hash) ;
4. **ancienne image v1** correctement signée → refusée (`version ≤ en cours`) ;
5. **autre signataire** (o3) → refusée (`BadSignature`), tout comme o1, l'ancien
   propriétaire ;
6. **image qui ne démarre pas** (v3, auto-test qui bloque) → chien de garde →
   **retour à v2**, plancher inchangé ;
7. **coupure pendant l'écriture DFU** → v2 redémarre normalement ;
8. **coupure pendant la permutation** (chargeur ; durée mesurée d'abord) → la
   permutation reprend → la nouvelle image démarre.

Avant chaque coupure, je demande.

## 7. Limites dites

- **Pas de démarrage sécurisé.** Le chargeur ne vérifie pas de signature au
  démarrage, et le RP2040 n'a pas de *secure boot* (le RP2350 en a). La porte est
  l'application en cours d'exécution. Qui peut écrire la flash (BOOTSEL, SWD,
  commande `b` du firmware de test) contourne tout, plancher compris.
- Le chargeur n'est pas mis à jour par ce mécanisme et n'est pas signé.
- Les mises à jour passent par l'USB, pas par le maillage.
- `embassy-boot` n'a pas d'audit externe connu ; on s'appuie sur ses tests, sa
  diffusion et nos essais de coupure.
