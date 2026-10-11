# Phase 1.1 — Post-quantique et agilité cryptographique (spec)

Prompt : `prompts/OASIS_VS_VERIDIFY.md`, phase 1, point 1. Branche `oasis-vs-veridify`.
**Spec à valider avant tout code.**

## 1. Périmètre : où mettre du post-quantique, et où pas

| Trafic | Signature | Pourquoi |
|---|---|---|
| **Messages d'autorité** : révocation, attestation d'enrôlement, manifeste de mise à jour, transfert de propriété | **Hybride Ed25519 + ML-DSA-44**, les deux obligatoires | Rares, et valides **longtemps** : une révocation ou un firmware signé aujourd'hui doit tenir face à un calculateur quantique de demain (« harvest now, forge later ») |
| Ordres d'actionnement (`OAC1`), balises, trafic v0B saut par saut | **Ed25519 seul**, inchangé | (a) 64 octets contre 2 484 : sur une trame LoRa de ≤ 255 octets, un ordre hybride ferait ~15 fragments et ~4 s d'antenne par saut ; (b) un ordre expire en ≤ 10 s (`MAX_VALIDITY_MS`) dans l'horloge de l'actionneur : le falsifier plus tard ne sert à rien |

**Limite assumée, écrite telle quelle :** le transport v0B reste classique. Face à un
calculateur quantique capable de casser Ed25519, un attaquant pourrait se faire passer
pour un nœud enregistré et émettre des ordres. Seuls les messages d'autorité deviennent
post-quantiques. Un v0B hybride attendra des trames plus grandes.

## 2. Conteneur d'autorité `OAU1` (contenu v0B, v0B inchangé)

```
"OAU1" | kind u8 | suite u8 | network_id[8] | content_len u16 | content | sigblock
```

- `kind` : 1 révocation, 2 enrôlement, 3 manifeste de firmware, 4 transfert de propriété.
- `suite` (agilité) : `0x01` Ed25519 ; `0x02` ML-DSA-44 (réservé, refusé par défaut) ;
  **`0x03` hybride Ed25519 + ML-DSA-44**. Les valeurs inconnues sont refusées.
- `sigblock` (`0x03`) : `ed25519_sig[64] | mldsa44_sig[2420]`. Les **clés publiques
  ne voyagent pas** : celle d'Ed25519 et celle de ML-DSA-44 (1 312 octets) sont
  provisionnées dans la flash de l'équipement.
- **Données signées**, identiques pour les deux algorithmes :
  `"OASIS-AUTH-v1" ‖ kind ‖ suite ‖ network_id ‖ content_len ‖ content`.
  `suite` est signé : impossible de réétiqueter un message hybride en Ed25519 seul.
- **Hybride = ET** : accepté seulement si **les deux** signatures sont valides.

**Politique anti-déclassement.** Chaque équipement garde, par `kind`, une suite
minimale `min_suite[kind]`, persistée en flash et **qui ne baisse jamais**. Un message
plus faible que le minimum est refusé (`Downgrade`), avant toute vérification coûteuse.
La politique ne monte que par un message d'autorité hybride. Une fois
`min_suite[révocation] = 0x03`, les anciennes listes `ORV1` (Ed25519 seul) sont refusées.

**Compatibilité.** `ORV1` reste lisible tant que la politique l'autorise. Une
révocation hybride est un `OAU1` (`kind = 1`) dont le contenu est le corps d'`ORV1`
sans ses signatures : `network_id, epoch, issued_at, count, fps`. Les règles de
révocation déjà prouvées (époque croissante, liste qui ne rétrécit pas, persistance
avant application) s'appliquent sans changement. **k-sur-n hybride : reporté** (k × 2,5 Ko).

## 3. Fragmentation signée

Un message hybride fait ~2,6 Ko ; une trame fait ≤ 300 octets sur notre banc UART et
≤ 255 octets en LoRa. Chaque fragment voyage dans **son propre envelope v0B** : il est
donc authentifié, frais (compteur), lié au réseau et vérifié à chaque saut.

```
"OFR1" | msg_id[8] | total_len u16 | idx u8 | count u8 | chunk
```

- `msg_id` = les 8 premiers octets de SHA-256 du message `OAU1` complet.
- **Réassemblage borné** : 2 emplacements, 4 096 octets maximum par message,
  expiration après 30 s, un seul message en cours par origine. Doublon ignoré ; un
  fragment incohérent (taille, index, `count`) annule l'emplacement.
- Une fois complet : SHA-256 doit correspondre à `msg_id`, puis politique, puis
  Ed25519, puis ML-DSA-44.
- **Stocker puis relayer** : un relais ne réémet les fragments qu'**après** une
  vérification complète réussie, en les réoriginant sous ses propres compteurs (comme
  le rattrapage `OEP1`). Un message d'autorité invalide s'arrête donc au premier saut,
  comme `ORV1` aujourd'hui.
- **Coût**, à mesurer : avec ~200 octets utiles par fragment, ~13 fragments, soit
  ~13 × 180 ms de vérification v0B par saut (≈ 2,3 s), plus une vérification d'autorité.
  Acceptable pour une révocation ; inacceptable pour un ordre, d'où le §1.

## 4. Choix de l'implémentation ML-DSA (règle 4)

| Crate | Version | État | `no_std` thumbv6m sans allocateur |
|---|---|---|---|
| `ml-dsa` (RustCrypto) | 0.1.1 (2026-06-05) | FIPS 204 final, maintenu, 3,4 M de téléchargements ; README : « **never been independently audited** » | ✅ compile (2026-10-06) |
| `libcrux-ml-dsa` (Cryspen) | 0.0.11-pre.1 (2026-10-06) | Arithmétique, NTT et sérialisation **vérifiées formellement** (hax/F*) ; préversion | ✅ compile |
| `fips204` | 0.4.6 (2024-12-22) | Pas de version depuis près de deux ans | ✅ compile |
| `pqcrypto-mldsa` | — | Liaison C (PQClean) : pas du Rust pur, compilateur C croisé requis | ❌ exclu |

**Proposition.** Sur la carte, `ml-dsa` (RustCrypto) : maintenu, API stable, même
écosystème que nos autres primitives. **Contre-vérification sur PC** : chaque
signature des tests est aussi vérifiée par `libcrux-ml-dsa`, et les deux doivent
donner le même verdict (deux implémentations indépendantes, dont une vérifiée
formellement), en plus des vecteurs officiels du NIST (ACVP). Le choix définitif se
fait après une **mesure comparée sur RP2040** des deux candidats principaux : on
retient le plus sûr qui tient dans la mémoire, et on documente pourquoi.

**Décision (2026-10-06, après mesure) : `libcrux-ml-dsa` sur la carte**, version
stable **0.0.10** (2026-07-15) et non la préversion 0.0.11-pre.1 d'abord épinglée.
Mesuré sur 3 cartes × 3 passes × K = 5 (`evidence/silicon/2026-10-06/pq/REPORT.md`) :
vérification 198 ms et **44,8 Ko** de pile, contre 178 ms et **84,0 Ko** pour `ml-dsa`
(102 Ko selon le site d'appel). Les deux tiennent ; la règle « le plus sûr qui tient »
retient libcrux (vérifié formellement en partie, deux fois moins de pile), au prix
de +11 % de temps et +101 Ko de flash. `ml-dsa` reste l'oracle des tests et le
signataire côté PC. Les deux crates Rust sont 4 à 4,5 fois plus lents que PQClean en C.

## 5. Mesures sur RP2040

Taille du firmware (avant, après), pic de pile (pile peinte d'un motif connu, puis
relue), temps de vérification ML-DSA-44 sur K = 5. Référence publique : PQClean en C
à 125 MHz, **44,0 ms et 9,4 Ko de pile** pour la vérification
([arXiv 2603.19340](https://arxiv.org/abs/2603.19340)). **Arrêt et question** si la
vérification ne tient pas dans la RAM du RP2040. Aucune carte RP2350 n'est
disponible ici.

## 6. Preuves prévues

**Tests PC :**
- hybride : Ed25519 seul valide → refus ; ML-DSA seul valide → refus ; les deux → accepté ;
- suite inconnue ; déclassement ; politique monotone ; `suite` modifiée en transit ;
- fragments dans le désordre, en double, manquants, mélangés, trop grands, emplacements saturés ;
- vecteurs officiels ACVP ; vérification croisée `ml-dsa` / `libcrux-ml-dsa`.

**Kani :**
- le réassembleur ne panique jamais et ne dépasse jamais son tampon ;
- `min_suite` ne baisse jamais ;
- « accepté » avec la suite `0x03` implique que les deux vérifications ont réussi.

**Silicium**, 3 cartes, mode strict :
- une révocation hybride signée sur le PC est fragmentée par A, réassemblée et vérifiée
  par B, puis réoriginée vers C ;
- un fragment modifié fait refuser tout le message ;
- une `ORV1` Ed25519 seule envoyée après la montée de politique est refusée ;
- temps, pile et taille mesurés sur la carte.

## 7. Hors périmètre

ML-KEM (accord de clé hybride X25519 + ML-KEM pour la couche `spore`), Falcon, k-sur-n
hybride, v0B hybride.
