# Phase 1.2 — Enrôlement et transfert de propriété (spec)

Prompt : `prompts/OASIS_VS_VERIDIFY.md`, phase 1, point 2. S'appuie sur la phase 1.1
(`docs/specs/PQ_AUTHORITY_SPEC.md`) : tout message d'autorité est un `OAU1` (suite
signée, politique par type, fragmentation `OFR1`, stocker-puis-relayer).

## 1. Modèle

- **Propriétaire = autorité d'un réseau** (`network_id`) : une paire de clés hybride
  (Ed25519 + ML-DSA-44). Il signe les révocations, les politiques et désormais les
  **attestations d'enrôlement**. Tous les nœuds d'un réseau doivent pouvoir vérifier
  ces messages, donc ils partagent le même propriétaire. Le propriétaire n°1 est
  celui des phases E/F et 1.1 (compilé dans le firmware de test). Une procédure de
  revendication en usine ou par présence physique est hors périmètre.
- **Transfert** = passation d'un réseau entier (intégrateur → client, rachat). Il
  exige la signature de l'ancien **et** du nouveau propriétaire (§4). Déplacer *un*
  nœud vers un autre réseau = révocation dans l'ancien + enrôlement dans le nouveau :
  c'est un autre modèle que la « chaîne de propriété par équipement » annoncée par
  DOME, et la phase 3 le dira.
- **Nœud non enrôlé = muet.** Le registre des clés publiques de v0B ne contient plus
  de clés compilées. Il se remplit uniquement d'attestations vérifiées. Une enveloppe
  dont l'origine n'est pas enrôlée est refusée au premier saut (`unknown sender`, déjà
  le comportement de v0B).

## 2. Identité du nœud : générée sur la carte, jamais exportée

- **Premier démarrage** (aucune identité valide en flash) : la graine Ed25519 vaut
  `SHA-256("OASIS-KEYGEN-v1" ‖ 4 096 bits bruts du ROSC ‖ timer ‖ ID unique de la flash)`.
  SHA-256 est un conditionneur reconnu (NIST SP 800-90B §3.1.5.1.1).
- **Tests de santé** sur les bits bruts (SP 800-90B §4.4, entropie supposée 0,5 bit
  par échantillon) : *repetition count* (coupure 41) et *adaptive proportion*
  (fenêtre 1 024, coupure 793). En cas d'échec, nouvel essai ; après 3 échecs, pas de
  clé et le nœud reste muet (`ENTROPY_FAIL`). Les 4 096 échantillons font 8 fois les
  512 nécessaires à 256 bits sous cette hypothèse.
- ⚠️ **Le RP2040 n'a pas de générateur aléatoire matériel.** Sa fiche technique
  (§2.17.5, p. 224) dit du bit aléatoire du ROSC : *« This does not meet the
  requirements of randomness for security systems because it can be compromised »*.
  Nous le disons tel quel. Deux mesures en réduisent le risque :
  1. les tests de santé ci-dessus, plus une commande `@N` qui publie des
     statistiques sur 100 000 bits bruts (proportion de 1, plus longue série,
     estimation *most common value* de SP 800-90B §6.3.1), mesurées sur les 3 cartes ;
     jamais la graine ;
  2. **une seule fois, avant d'être enrôlé**, le nœud mélange une contribution de
     l'outil : `graine' = SHA-256("OASIS-REKEY-v1" ‖ graine ‖ nonce_outil ‖ bits ROSC frais)`.
     Si le ROSC a fourni de l'entropie, l'outil n'apprend rien de la clé. S'il n'en a
     pas fourni, un tiers ne peut plus la prédire, mais l'outil le pourrait.
  En production : RP2350 (TRNG matériel) ou élément sécurisé (contrat
  `oasis-secure-element`).
- **Stockage** : secteur 0x1F8000, `OID1 | graine[32] | mixed u8 | check4`. Le firmware
  n'émet jamais la graine. ⚠️ Ce n'est **pas** une garantie matérielle : la flash du
  RP2040 se lit en BOOTSEL (picotool) ou par SWD, et le firmware de test accepte `b`
  (redémarrage en BOOTSEL) par USB. Quiconque a un accès physique ou USB peut donc
  lire la clé. Écrit tel quel dans le rapport.
- **Empreinte** = `SHA-256(pk)[0..8]` (fonction existante `sender_fingerprint`). Elle
  est dérivée, jamais transmise séparément : un nœud ne peut pas revendiquer
  l'empreinte d'un autre.
- **Preuve de possession** : `@E<défi 32 o><nonce 32 o>` renvoie `pk` et une signature
  Ed25519 de `"OASIS-POP-v1" ‖ network_id ‖ défi`. L'outil la vérifie avant de signer
  l'attestation. La même clé signe les enveloppes v0B ; les préfixes de domaine
  séparent les usages.

## 3. Attestation d'enrôlement (`OAU1`, type 2)

Contenu, sous la signature du propriétaire (réseau = en-tête `OAU1`, déjà signé) :

```
version u8 (=1) | node_pk[32] | role u8 | permissions u32 LE | enroll_seq u32 LE
```

- `role` : 1 capteur, 2 relais, 3 passerelle, 4 actionneur. **Seulement journalisé**,
  aucune règle n'en dépend dans cette phase.
- `permissions` : bit 0 `ACTUATE` (peut commander un actionneur), **appliqué** : la
  condition « autorisé » de la porte d'actionnement devient « origine enrôlée avec
  `ACTUATE` », au lieu de l'empreinte de A codée en dur. Les autres bits sont
  réservés, et une attestation qui les met à 1 est refusée.
- Règles : empreinte dérivée de `node_pk` ; refus si cette empreinte est révoquée
  (la révocation est définitive) ; `enroll_seq` strictement supérieur à celui déjà
  enregistré pour cette empreinte. On peut donc changer des droits ; rejouer une
  vieille attestation plus généreuse est refusé.
- Effet : l'entrée est enregistrée, la clé insérée dans le registre v0B, puis la
  persistance est faite **avant** l'application. Le message est réoriginé s'il a
  changé l'état (même règle qu'en 1.1).
- **Persistance du registre** : 2 secteurs (0x1F4000/0x1F5000),
  `ORG1 | gen u32 | n u16 | n × (fp, pk, role, perms, seq) | check4`, le plus grand
  `gen` valide gagnant. **Contrôle d'intégrité, pas de signature, au démarrage** :
  sur un RP2040, qui peut écrire la flash peut aussi remplacer le firmware, donc
  revérifier N signatures (N × 377 ms) à chaque démarrage ne relèverait pas la barre.
  La liste de révocation garde, elle, sa revérification héritée de E/F.

## 4. Transfert de propriété (`OAU1`, type 4) : deux messages, deux signatures

Un seul message ne tiendrait pas : avec la clé ML-DSA du nouveau propriétaire, sa
signature de consentement et celle de l'ancien, il ferait ~6,3 Ko. Le transfert se
fait donc en deux temps, chacun ≤ 4 Ko (≤ 22 fragments) :

1. **Offre**, signée (hybride) par le propriétaire **actuel** :
   `sub u8 (=1) | transfer_seq u32 | new_ed_pk[32] | new_mldsa_pk[1312]` (1 349 o).
   Le nœud la vérifie avec ses clés actuelles, exige `transfer_seq` > courant, la
   garde **en attente** (RAM) et la relaie.
2. **Acceptation**, signée (hybride) par le **nouveau** propriétaire, avec les clés
   de l'offre en attente :
   `sub u8 (=2) | transfer_seq u32 | SHA-256(offre complète)` (37 o).
   Elle n'est valable qu'avec la même séquence et l'empreinte exacte de l'offre (donc
   du même réseau et des signatures de l'ancien propriétaire). Le nœud enregistre
   alors le nouveau propriétaire **avant** de l'appliquer, puis relaie.

Le sous-type, lu avant vérification, ne sert qu'à choisir les clés de vérification :
s'il est falsifié, la vérification échoue. Changements :
`AuthPolicy::default()` exige l'hybride pour le type 4, comme pour la politique ;
`MAX_AUTH_CONTENT` passe de 1 024 à 1 536 (16 + 1 536 + 2 484 ≤ 4 096).

**Enregistrement du propriétaire** : 2 secteurs (0x1F6000/0x1F7000),
`OWN1 | transfer_seq | propriétaire courant (ed, mldsa) | précédent (ed, mldsa) | check4`.
Le propriétaire n°1 compilé vaut quand rien n'est enregistré. Après un transfert,
les messages de l'ancien propriétaire sont refusés (`BadSignature`).

**Révocations signées par l'ancien propriétaire.** Au démarrage, la liste persistée
est revérifiée avec le propriétaire courant, sinon avec le précédent (un seul
niveau). Pour que ce niveau suffise toujours, **un nœud refuse une nouvelle offre
tant que sa liste persistée n'est pas signée par le propriétaire courant**
(`NeedsResign`) : avant de céder à son tour, le nouveau propriétaire re-signe la
liste. Sinon, après deux transferts, un redémarrage effacerait des révocations
(défaillance ouverte).

Une offre en attente est perdue au redémarrage : il suffit de la renvoyer, elle est
idempotente.

## 5. Outil PC minimal

`oasis-operator-key/examples/oasis_enroll.rs` (les clés des propriétaires restent
sur le PC ; graines de test o1 = le propriétaire n°1, o2 = nouveau propriétaire,
o3 = attaquant) :

- `challenge` → défi + nonce aléatoires ;
- `verify-pop <pk> <défi> <sig>` → vérifie la preuve de possession ;
- `attest <owner> <pk> <role> <perms> <seq>` → attestation hybride ;
- `offer <old> <new> <seq>` et `accept <new> <offre>` → les deux messages du transfert.

Plus un script `enroll_board.sh <carte> <rôle> <perms>` : `@E` → vérification de la
preuve → signature de l'attestation → chargement. Côté firmware, `@L` fait passer le
message préparé par **la même porte** que s'il venait du maillage : l'USB n'est pas
un canal privilégié, les signatures sont vérifiées.

## 6. Preuves prévues

**PC** (`oasis-rt`, nouveaux modules `identity`, `enrollment`, `ownership`, chacun
< 400 lignes) :
- tests de santé : un flux bloqué ou biaisé est rejeté, un flux équilibré passe ;
  conditionnement déterministe ;
- preuve de possession : valide acceptée ; mauvais réseau, mauvais défi ou autre clé
  refusés ;
- attestation : bits réservés, empreinte révoquée, `enroll_seq` non croissant et
  mauvais réseau refusés ; un changement de droits est accepté ;
- transfert : offre seule (pas de changement), acceptation sans offre, acceptation
  signée par o3, offre signée par o2, séquence rejouée, empreinte d'offre différente
  → tous refusés ; offre + acceptation → transfert ; ensuite o1 est refusé et o2
  accepté ; `NeedsResign` ;
- enregistrements : aller-retour, écriture déchirée, le plus récent gagne.

**Kani** :
- le propriétaire ne change que si l'offre a été vérifiée avec les clés courantes
  **et** l'acceptation avec les clés offertes, avec la même séquence et la même
  empreinte ;
- `transfer_seq` et `enroll_seq` ne baissent jamais ;
- une empreinte révoquée n'est jamais enrôlée ;
- les analyseurs d'attestation et de transfert ne paniquent jamais.

**Silicium** (3 cartes, mode strict, après remise à zéro) :
1. génération de clé au premier démarrage : 3 empreintes distinctes, statistiques
   d'entropie `@N` par carte ;
2. **refus d'un nœud non enrôlé** : avant enrôlement, les envois de A sont refusés
   par B (`unknown sender`) ; après l'enrôlement de A chez B, acceptés ;
3. enrôlement par l'outil (preuve de possession vérifiée), puis enrôlement de C
   propagé par le maillage (A→B→C) ;
4. droits : un ordre de A (`ACTUATE`) est exécuté par C ; un ordre de B, enrôlé
   sans `ACTUATE`, est refusé (`NotAuthorized`) ;
5. transfert o1 → o2 sur les 3 cartes ; refus : acceptation par o3, acceptation sans
   offre, offre rejouée ; ensuite une attestation ou révocation o1 est refusée, une
   o2 acceptée ;
6. **coupure de courant** (je demanderai avant) : même empreinte, o2 toujours
   propriétaire, pairs toujours enrôlés, liste de révocation restaurée.

## 7. Hors périmètre et limites dites

- Clé non protégée matériellement (voir §2) ; ROSC non conforme selon sa fiche
  technique ; pas d'élément sécurisé.
- Pas de revendication initiale ni de chaîne de propriété par équipement ; pas de
  multi-signature hybride (k-sur-n) du propriétaire.
- Le rôle n'est pas appliqué ; une seule permission (`ACTUATE`) est appliquée.
- Le registre est limité à environ 80 entrées par secteur (démonstrateur, pas
  une flotte).
