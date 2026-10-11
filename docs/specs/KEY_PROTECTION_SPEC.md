# Protéger la clé d'un nœud : décision écrite (phase 0)

**2026-10-09.** Phase 0 de `prompts/OASIS_KEY_PROTECTION_RP2350.md` : la décision est
écrite **avant** tout code et **avant** toute écriture d'OTP, parce que l'OTP est
irréversible et qu'une erreur détruit la carte.

⚠️ **Rien n'a été exécuté sur un RP2350 à cette date.** Aucune carte RP2350 n'a été
détectée sur cette machine. Tout ce document est de la **lecture de sources primaires** :
les phases 1 à 4 restent entières, et la seule chose que ce §0 autorise est de commencer
le portage *sans* sécurité activée.

---

## 0.1 Les deux trous que ça doit fermer

Déjà écrits comme limites dans `CLAUDE.md`, sur RP2040 :

| # | Trou | Conséquence |
|---|---|---|
| 1 | **La clé privée du nœud est lisible.** Elle est en flash ; BOOTSEL ou SWD suffisent à la copier | Avec elle on fabrique des ordres `v0B` **authentiques** depuis n'importe où. C'est la seule chose qui tient tout l'édifice : la porte d'actionnement, la révocation, l'enrôlement |
| 2 | **Aucune vérification de l'image au démarrage.** BOOTSEL, SWD ou la commande de test `b` flashent n'importe quel firmware, plancher anti-retour compris | La mise à jour signée de la phase 1.3 ne protège que le chemin prévu, pas la carte |

Ce que OASIS protège est une **clé Ed25519 d'identité de nœud**, celle qui signe les
enveloppes v0B. À ne pas confondre avec la clé du **démarrage sécurisé** du RP2350, qui
est une autre clé, d'un autre algorithme, et qui ne signe que l'image.

---

## 0.2 Ce que le RP2350 offre vraiment — sources primaires

Toutes les sections citées renvoient à la *RP2350 Datasheet* et au white paper
*Understanding RP2350's security features* (RP-009377-WP-1, **version 1, 20 novembre
2025**).

| Mécanisme | Ce que la source dit | Référence |
|---|---|---|
| **Démarrage sécurisé** | « Signatures use the SHA-256 hash algorithm and **secp256k1 ECDSA** elliptic curve cipher to authenticate binaries. » Activé par des réglages OTP ; seules les images signées par la bonne clé s'exécutent | Datasheet **§10.1.1** |
| **Anti-retour** | « RP2350 can also disallow downgrading to older software versions through version numbering » | Datasheet §10.1.1 |
| **OTP** | **8 ko**, protégeable par **granularité de 128 octets**, en verrouillage **dur** ou **doux**. Le dur « permanently revokes … read or write access for secure or non-secure code » ; le doux jusqu'au prochain *reset* du bloc OTP — et ce reset **réinitialise aussi les processeurs**, « which ensures that soft locks cannot be bypassed » | Datasheet **§10.8** |
| **Démarrage chiffré** | Clés de déchiffrement en OTP, **verrouillées en doux** après usage ; binaire chiffré chargé en **SRAM** et déchiffré sur place, « avoids attacks based on physical access to the flash ». L'AES est « hardened against SCA and glitching attacks » | Datasheet **§10.1.2** |
| **TrustZone** | Armv8-M Security Extension, **8 régions SAU**, 8 MPU sécurisées, 8 non sécurisées ; `ACCESSCTRL` lisible par tout code mais écriture verrouillable par `LOCK` | Datasheet **§10.2**, §10.6.2 |
| **Cœurs RISC-V** | « The RISC-V cores are **not secured**, so securing a RP2350 **disables those cores** to prevent them from being used as attack vectors » | White paper, *Processor level security* |
| **Détecteurs de glitch** | **Quatre** circuits ; déclenchement ⇒ *reset* du système. **Désactivés par défaut** ; recommandé de les activer **en OTP** plutôt qu'en code, « as this safeguards the chip from intrusion before the processor has had a chance to enable the detectors » | Datasheet **§10.9** |
| **RCP** | Canaris de pile, compteurs de séquence, validation de booléens et d'entiers, arrêt de tous les cœurs sur panique. Utilisé massivement par le boot ROM, **à insérer soi-même** dans le code applicatif | Datasheet §3.6.3 |
| **Désactivation du débogage** | Les permissions OTP spécifient « what can be accessed by the boot ROM when the device is in BOOTSEL mode » | Datasheet §10.8 |

Et la phrase qui gouverne la règle 1 du prompt :

> « Security on RP2350 is entirely optional … It should also be noted that **once the
> security features are turned on, they cannot be turned off.** »

⚠️ **Non documenté / non vérifié à la source** à ce stade :

- la **réversibilité exacte** de chaque bit de désactivation du débogage, bit par bit :
  le white paper dit que l'OTP gouverne l'accès en BOOTSEL, mais la table de permissions
  détaillée est dans la datasheet §10.8, **non relue ligne à ligne ici** ;
- l'existence d'un **magasin de clés du monde sécurisé** fourni par le boot ROM pour
  l'option B : le white paper décrit l'isolation, pas un service de signature. À vérifier
  dans la datasheet avant de retenir B ;
- il n'y a **pas d'API de contrôle d'accès** dans le SDK : « any access control will need
  to be done at the register level » (white paper, note). C'est un coût d'effort réel
  pour l'option B.

---

## 0.3 Les attaques publiées, et ce que la révision du silicium change

Le concours *RP2350 Hacking Challenge* a tourné **4,5 mois, d'août à décembre 2024**, avec
une seule tâche : récupérer un secret stocké en OTP. **Les quatre soumissions valides ont
réussi**, et toutes ont exigé un **accès physique**.

| Attaque | Méthode | Statut |
|---|---|---|
| **Aedan Cullen**, « Hazardous Threes » | Isole physiquement la broche 53 (piste coupée), puis **injection de tension** pour rallumer les cœurs **RISC-V « permanently disabled »** et leur port de débogage, et lire le secret | Boot ROM corrigé en **A4** (errata 20/21/24) |
| **Marius Muench** | Reboot normal vers le bootloader USB, puis **glitch d'alimentation** pour sauter une instruction, avec du code malveillant préchargé en RAM | Boot ROM corrigé en **A4** |
| **Kévin Courdesses** | **Injection laser** sur la vérification de signature, faute d'une seule instruction | Boot ROM corrigé en **A4** |
| **IOActive** | **Passive Voltage Contrast** au **FIB** sur les antifusibles : lit le **OU bit-à-bit de paires de bits adjacents** | ⚠️ **Non corrigé en matériel**, y compris en A4 |
| Hors concours — Thomas Roth / Hextree | Évaluation des détecteurs de glitch, et **faute de double instruction** sur la lecture OTP par injection électromagnétique | — |

**La révision A4** (annoncée environ un an après l'A2 d'août 2024) corrige, d'après
Raspberry Pi : les **errata 20, 21 et 24** — « boot ROM security vulnerabilities
discovered in the course of the RP2350 Hacking Challenge … fixed in the A4 boot ROM » —
l'**erratum 16**, « which relates to the behaviour of the OTP when power is removed during
a read operation », et l'**erratum 9** (fuite de courant des pads GPIO). Le boot ROM A4
« implements a variety of new defensive strategies ».

Ce qui **reste ouvert sur toute révision** :

> « a vulnerability in the OTP bit array itself. Using a technique called Passive Voltage
> Contrast, they were able … read out the bitwise OR of pairs of adjacent bits stored in
> the OTP. »

Et deux limites écrites noir sur blanc par le fabricant :

- « **Glitch detectors cannot catch all possible glitch attacks.** At slower clock speeds,
  they become less effective, making attacks during reduced-speed stages like **boot ROM
  execution** more likely to succeed » — c'est-à-dire précisément la fenêtre où trois des
  quatre attaques ont réussi ;
- le délai pseudo-aléatoire du RCP (0–127 cycles) « can, in practice, actually make
  [timing injection] easier, so it is advisable that you **do not use** this delay »
  (**RP2350-E3**).

### La parade documentée contre la PVC, et elle est précise

Datasheet **§13.8 *Imaging Vulnerability***, reprise par le white paper : dans chaque page
OTP de 64 rangées, **les rangées `i` et `32 + i` partagent la même cellule**. La PVC a du
mal à dire laquelle des deux est à 1 — **sauf si l'une est connue nulle**, « for example,
a key stored at the bottom of an otherwise blank page », et alors « the data can be
trivially read from the PVC image ».

La parade est donc un **remplissage par paires** :

- écrire la donnée réelle en rangées `i`, de 0 à 31 ;
- écrire le **complément bit-à-bit sur 24 bits** de ces valeurs en rangées `32 + i`, « on
  the entire 24-bit raw row contents, **including the ECC bit pattern** ».

Variante : une valeur **aléatoire** en `32 + i` et le **XOR** de cette valeur avec la
donnée en `i` — « advantageous from a power side-channel perspective because it avoids
reading the secret value directly from OTP » ; le bootloader chiffré d'exemple du RP2350
utilise un XOR à 4 voies. Le complément est la recommandation pour le remplissage par
paires, et c'est le même procédé avec un motif fixe `0xffffff`.

Plus deux bonnes pratiques du même paragraphe : **une clé unique par carte** — « if one
device is compromised, not all are compromised » — et du **chaff**.

⚠️ La PVC « involves decapsulating the die. Therefore, **physical access** to the device
is a strict requirement, and there is a **moderate chance of destroying the die** without
being able to recover its OTP contents. » C'est une attaque de laboratoire, coûteuse, pas
un vol de clé à distance. Elle ne doit **ni** être ignorée **ni** servir à dire que l'OTP
ne vaut rien.

---

## 0.4 Les trois options

### Option A — RP2350 seul

Démarrage sécurisé, clé du nœud (ou clé d'enveloppement) en OTP avec **remplissage par
paires** de §0.3, page verrouillée en doux après lecture au démarrage, débogage désactivé,
détecteurs de glitch activés en OTP.

| | |
|---|---|
| **BOOTSEL** | **Fermé.** Les permissions OTP disent ce que le boot ROM peut atteindre en mode BOOTSEL (§10.8) |
| **SWD** | **Fermé** par la désactivation du débogage |
| **Firmware malveillant flashé** | **Fermé** par le démarrage sécurisé : seule une image signée secp256k1 démarre, avec anti-retour par numéro de version |
| **Attaque physique** | ⚠️ **Non fermé.** PVC/FIB reste possible ; le remplissage par paires la rend difficile, pas impossible. Les glitchs restent possibles pendant le boot ROM, par aveu du fabricant |
| **Coût par carte** | **0 €** de matériel en plus |
| **Effort** | Moyen : signature des images (`picotool`), écriture OTP, séquence de provisionnement, et le portage Cortex-M33 de la phase 1 |
| **Impact v0B / ML-DSA / mise à jour A/B** | **Aucun sur les algorithmes** : secp256k1 ne signe que l'*image*. L'identité du nœud reste Ed25519, la couche autorité reste hybride Ed25519 + ML-DSA-44. ⚠️ La mise à jour A/B de la phase 1.3 doit être **re-prouvée** sous démarrage sécurisé : les images deviennent signées par `picotool`, et le plancher anti-retour d'OASIS coexiste avec celui du bootrom — deux planchers, à ne pas confondre |
| **Reste ouvert** | PVC/FIB ; glitch pendant le boot ROM ; et le fait qu'une clé unique par carte **impose une étape de provisionnement** que la phase 1.2 fait aujourd'hui *sur la carte* (`identity`, ROSC + SP 800-90B). Garder la génération embarquée est compatible : la clé naît sur la carte et n'en sort jamais, ce qui est **mieux** qu'une clé injectée |

### Option B — RP2350 + TrustZone

La clé n'est lisible que du monde sécurisé ; l'application signe par un appel au monde
sécurisé.

| | |
|---|---|
| **Ce qu'elle ajoute à A** | Une **application compromise** ne peut pas lire la clé : elle ne peut que *demander* une signature. C'est le seul gain réel sur A |
| **BOOTSEL / SWD / flash malveillant** | Identiques à A — c'est A qui les ferme, pas TrustZone |
| **Attaque physique** | ⚠️ **Non fermé**, identique à A |
| **Coût par carte** | 0 € |
| **Effort** | **Élevé.** Deux images, une frontière sécurisée, `SAU` et `ACCESSCTRL` à écrire **au niveau registre** : « there is no API for helping configure access control in the … SDK ». Et l'existence d'un service de signature du monde sécurisé côté boot ROM est **non vérifiée** (§0.2) |
| **Impact** | v0B inchangé, mais le chemin de signature devient un appel inter-mondes : il faut re-mesurer les 178 ms de la signature v0B et le budget de la porte hybride |
| **Reste ouvert** | Tout ce que A laisse ouvert, plus la surface de la frontière elle-même |

### Option C — élément sécurisé externe

| | NXP **SE050** | Microchip **ATECC608B** |
|---|---|---|
| **Ed25519** | **Oui** — le portage wolfSSL expose ED25519/Curve25519 ; signature mesurée ~**261 ms**, vérification ~**144 ms** (⚠️ chiffres d'un banc wolfSSL, **pas re-mesurés ici**, et pas sur RP2350) | **Non : P-256 seulement.** Retenir cette puce voudrait dire **changer l'algorithme d'identité** de tout OASIS, ou faire cohabiter deux algorithmes |
| **Certification** | Common Criteria **EAL 6+** jusqu'au niveau OS, revendiquée par NXP | — |
| **Ce qu'elle ferme** | La clé ne quitte **jamais** l'élément : BOOTSEL, SWD, firmware malveillant **et** une bonne part de l'attaque physique sur le RP2350, puisque la clé n'y est plus | Idem, mais pour une autre courbe |
| **Coût par carte** | Un composant en plus, un bus I²C, de la place sur la carte | idem |
| **Effort** | **Élevé** : pilote `no_std`, sessions sécurisées, provisionnement, et une **nouvelle dépendance** à justifier (mainteneur, téléchargements, licence vs `deny.toml`) | **Très élevé** : changement d'algorithme, donc v0B, l'enrôlement, la révocation et toutes les preuves |
| **Impact v0B** | ⚠️ **261 ms par signature est plus lent que les 178 ms de la signature logicielle v0B mesurée sur RP2040.** Un élément sécurisé coûterait ici de la latence au lieu d'en gagner — à re-mesurer avant toute conclusion | Rupture d'algorithme |
| **Reste ouvert** | Le bus I²C entre le MCU et l'élément : il ne transporte pas la clé, mais il transporte **les demandes de signature**, donc un firmware compromis peut faire signer ce qu'il veut. L'élément protège la clé, **pas la politique** | idem |

---

## 0.5 Recommandation

**Commencer par l'option A**, et ne juger B et C qu'après.

Pourquoi, dans l'ordre du prompt (« la plus simple qui ferme BOOTSEL et SWD ») :

1. **Elle ferme les deux trous nommés**, qui sont exactement BOOTSEL et SWD, pour **0 €**
   de matériel et sans toucher à un seul algorithme d'OASIS.
2. **Elle ne demande aucune rupture** : secp256k1 signe l'image, l'identité reste Ed25519,
   la couche autorité reste hybride. Rien de ce qui est prouvé sur silicium n'est retiré.
3. **B n'ajoute qu'une chose** — résister à une *application* compromise — pour un effort
   élevé au niveau registre, et avec un prérequis non vérifié. C'est le bon second pas,
   pas le premier.
4. **C est le seul qui attaque la PVC**, en sortant la clé de la puce, mais il ajoute un
   composant, une dépendance, et **~261 ms par signature contre 178 ms en logiciel** : il
   faut une raison plus forte que « c'est plus sûr » pour payer ça, et cette raison est un
   modèle de menace qui inclut le laboratoire. Elle n'est pas écrite aujourd'hui.

**Conditions à respecter dans l'option A**, toutes tirées de §0.2 et §0.3 :

- la clé du nœud en OTP est écrite avec le **remplissage par paires** (donnée en `i`,
  complément 24 bits en `32 + i`, bits ECC compris) — sans quoi la PVC la lit
  « trivially » ;
- **une clé unique par carte**, ce que la génération embarquée de la phase 1.2 fait déjà :
  la clé naît sur la carte, donc elle n'a jamais existé ailleurs ;
- **détecteurs de glitch activés en OTP**, pas en code ;
- **ne pas** utiliser le délai pseudo-aléatoire du RCP (**RP2350-E3**) ;
- viser une carte de révision **A4** pour les errata 16/20/21/24, et **écrire la révision
  de silicium de chaque carte utilisée** dans le rapport (phase 1, étape 0) ;
- **jamais** verrouiller le débogage ou BOOTSEL avant d'avoir prouvé, sur la carte
  d'essai, qu'une image signée démarre **et** qu'une mise à jour signée fonctionne.

---

## 0.6 Rôles des cartes, et la règle irréversible

Le prompt fixe la discipline, et elle n'est pas négociable : l'OTP est irréversible, une
erreur détruit la carte, et **le démarrage sécurisé actif rend tout nouveau firmware
impossible si la clé de signature est perdue**.

| Carte | Rôle | Écriture OTP |
|---|---|---|
| **E** | carte d'essai, la seule des phases 2 et 3 | autorisée, **après accord explicite, carte par carte** |
| **F**, **G** | relais A→B→C sur RP2350, et réserve si E est perdue | **vierges** jusqu'à ce que tout soit prouvé de bout en bout sur E |

Avant toute écriture d'OTP, dans cet ordre : **la séquence exacte écrite** (adresses et
valeurs) → **simulée ou passée en lecture seule** → **montrée à l'utilisateur** →
**accord explicite**. Rien de tout cela n'a été fait à ce jour, et rien ne sera écrit sans.

Et une exigence qui précède même l'accord : **une copie de sauvegarde de la clé de
signature, hors de cette machine**, avant d'écrire son hachage en OTP.

⚠️ **Combien de cartes ?** Le prompt a été écrit pour trois RP2350. Avec **deux**, E est la
carte d'essai et la seconde tient les deux rôles de F et G — ce qui veut dire qu'un
A→B→C **à trois RP2350 n'est pas possible**, et qu'un relais à deux cartes RP2350 plus un
RP2040 est le maximum. Avec **une seule**, le prompt interdit les écritures d'OTP en
phases 0 et 1 et demande de rappeler que c'est la seule carte avant la phase 2.

---

## 0.7 Ce qui n'est pas fait

- **Phases 1 à 4 : entières.** Aucun portage Cortex-M33, aucune mesure, aucune écriture
  d'OTP, aucun harnais Kani de cette phase.
- **Aucun RP2350 détecté** sur cette machine au 2026-10-09 : ni port série, ni volume
  `RP2350`/`RPI-RP2`, ni périphérique en erreur.
- **La datasheet n'est pas relue ligne à ligne** : §10.1.1, §10.1.2, §10.2, §10.6.2,
  §10.8, §10.9, §3.6.3, §13.8 et l'annexe E (errata) sont citées d'après le white paper
  officiel qui les référence, et deux points sont explicitement marqués **non vérifiés à
  la source** en §0.2.
- **Les chiffres du SE050 ne sont pas re-mesurés** et ne viennent pas d'un RP2350.
- **Le RP2040 reste supporté et garde ses limites**, écrites telles quelles dans
  `CLAUDE.md` : clé lisible en flash, pas de démarrage sécurisé.

## Sources

- *Understanding RP2350's security features*, white paper RP-009377-WP-1, **version 1 du
  20 novembre 2025**, Raspberry Pi Ltd —
  <https://pip-assets.raspberrypi.com/categories/1260-security/documents/RP-009377-WP-1-Understanding%20RP2350_s%20security%20features.pdf>
- *RP2350 Datasheet*, Raspberry Pi Ltd — <https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf>
  (sections citées via le white paper ; **non relue ligne à ligne**)
- *RP2350 A4, RP2354, and a new Hacking Challenge*, Raspberry Pi —
  <https://www.raspberrypi.com/news/rp2350-a4-rp2354-and-a-new-hacking-challenge/>
- *Security through transparency: RP2350 Hacking Challenge results are in*, Raspberry Pi —
  <https://www.raspberrypi.com/news/security-through-transparency-rp2350-hacking-challenge-results-are-in/>
- *IOActive — RP2350 Hacking Challenge* (PVC/FIB sur les antifusibles) —
  <https://www.ioactive.com/wp-content/uploads/2025/01/IOActive-RP2350HackingChallenge.pdf>
- *Tales from the RP2350 Hacking Challenge*, M. Muench et al., USENIX WOOT 2025 —
  <https://www.usenix.org/system/files/woot25-muench.pdf>
- *SE050 datasheet*, NXP — <https://www.nxp.com/docs/en/data-sheet/SE050-DATASHEET.pdf> ;
  support Ed25519 confirmé par le portage wolfSSL —
  <https://github.com/wolfSSL/wolfssl/blob/master/wolfcrypt/src/port/nxp/README_SE050.md>
