# Phase 2.1 — Pré-filtre des relais contre la vérification forcée (spec)

Prompt : `prompts/OASIS_VS_VERIDIFY.md`, phase 2, point 1 : ajouter le pré-filtre peu
coûteux contre la saturation par vérification forcée (`partners/POSITIONING_GAPS.md`
C1), mesurer la résistance de nos propres relais avant et après, documenter le chiffre.

**Décision d'architecture (2026-10-07, validée)** : MAC à **clé par lien** dérivée des
identités, pas de clé de réseau partagée. La diffusion radio N-voisins est hors
périmètre (TRL 6/7) ; sur notre banc filaire A→B→C point à point, chaque nœud a un
seul voisin aval, donc une seule étiquette. Ce choix supprime toute distribution de
clé et réduit le rayon de compromission à un nœud.

## 0. Le problème, avec nos chiffres

Un relais v0B fait, dans l'ordre (`mesh.rs`, `process_v0b`) : magie et longueur,
réseau, écho, origine révoquée, origine connue, ttl/hops, longueur annoncée, compteur
déjà vu, puis **Ed25519 (184,3 à 184,8 ms sur RP2040**, preuves de la phase 1.2), puis
fenêtre de compteurs.

Toutes les vérifications avant la signature portent sur des données **publiques** :
l'identifiant de réseau et les empreintes d'origine circulent en clair, et un compteur
« frais » se choisit librement. Un échec de signature n'enregistre pas le compteur ;
c'est voulu (une copie forgée ne doit pas supprimer le vrai message — silicium 1.4,
G2b). Quelqu'un qui écoute la liaison peut donc fabriquer, sans aucune clé, des
enveloppes qui coûtent chacune une vérification Ed25519 complète. Au-delà d'environ
**5,4 par seconde** (1 / 0,185 s), un relais RP2040 ne fait plus que ça.

## 1. Deux couches, deux métiers

Le MAC et le budget ne se remplacent pas :

- **MAC** = tri avant toute dépense. Un extérieur sans clé de lien échoue en ~µs (un
  HMAC-SHA256), sans atteindre Ed25519 **ni consommer de jeton**. Le trafic légitime
  (bon MAC) passe. C'est le MAC qui préserve la **disponibilité** face à l'extérieur.

- **Budget** = plafond CPU par lien, filet contre l'**initié** (qui a les clés). Il
  garantit qu'aucune liaison ne force plus de N vérifications Ed25519/s.

### A. Enveloppe `SPORE\x0C` (v0C) : v0B + empreinte de relais + étiquette

Disposition (le bloc v0B reste identique octet pour octet, donc le préimage Ed25519 ne
change pas) :

```text
[ en-tête v0B, 99 o ] [ forwarder_fp 8 o ] [ tag 16 o ] [ payload ]
```

- **`forwarder_fp`** : empreinte du **dernier relais** (pas l'origine). Dit au
  récepteur quelle clé de lien essayer. Champ **mutable par saut**, comme `ttl`/`hops`.

- **`tag`** : HMAC-SHA256 tronqué à 16 o de
  `"OASIS-LINK-v0C" ‖ origin_fp ‖ counter ‖ payload_len ‖ payload`, **sous la clé du
  lien** `forwarder → récepteur`. Le préimage est **invariant par saut** (il ne
  dépend que du cœur signé par l'origine) : un relais ne recalcule que le HMAC avec la
  clé du lien aval, sans resigner.

- `ttl`, `hops`, `forwarder_fp` **ne sont pas dans le préimage du tag** (ils mutent) ;
  `forwarder_fp` est de toute façon protégé par conséquence (un mauvais `forwarder_fp`
  fait choisir la mauvaise clé → MAC échoue).

- **Ordre sur le relais** : réseau, écho, `forwarder_fp` connu, **MAC** (un
  HMAC-SHA256 sur ~150 o, à mesurer sur M0+), budget (§C), puis les vérifs v0B
  existantes dont **Ed25519**. Sans la bonne clé de lien, une enveloppe n'atteint
  jamais Ed25519 ni le budget.

- **Pas de rétrogradation** : un routeur v0C refuse v0B/v9/v0A (mode strict déjà
  existant). Sinon l'attaquant enverrait du v0B pour retrouver le coût Ed25519.

- Relais : vérifie avec `K(forwarder→moi)`, puis pour relayer met `forwarder_fp = moi`
  et recalcule `tag` avec `K(moi→aval)`, décrémente `ttl`. L'origine (`origin_wrap_v0c`)
  calcule la signature Ed25519 **et** le premier tag.

### B. Clé de lien — dérivée, jamais distribuée

- `K(X↔Y) = HKDF-SHA256( X25519(x_sk_self, x_pk_peer), "OASIS-LINK-v0C" ‖ fp_min ‖ fp_max )`
  où `fp_min`/`fp_max` sont les deux empreintes triées (clé **symétrique** : `K(X↔Y) =
  K(Y↔X)`).

- Les clés X25519 sont **dérivées des clés d'identité Ed25519** déjà présentes
  (`ed25519_compact::x25519::*::from_ed25519`) : la nôtre depuis notre graine, celle du
  voisin depuis sa clé publique du **registre d'enrôlement**. Aucune nouvelle clé,
  aucun message, aucun slot flash, aucune `key_epoch`, aucune rotation.

- **Révocation gratuite** : un nœud révoqué sort du registre → plus aucune clé de lien
  n'est dérivée avec lui → son trafic échoue le MAC au premier saut (en plus du rejet
  v0B existant pour origine révoquée).

### C. Budget de vérification par liaison (token bucket)

- Plafond **par liaison d'entrée physique** (UART ici), pas par origine annoncée
  (falsifiable, et un quota par origine permettrait de faire taire un nœud précis).

- **Seau à jetons** : débit `N = 2`/s, **capacité de rafale `B = 24`**. La rafale
  couvre un message d'autorité fragmenté complet (révocation ≈ 14 fragments, offre de
  propriété ≈ 21, espacés de 100 ms) : **correction du défaut de la v1 de cette spec**,
  où `N = 2`/s avec rejet sec aurait jeté la plupart des fragments légitimes.

- Au-delà de la rafale : rejet **avant Ed25519**, compté et journalisé. Le surplus
  légitime est réémis par la couche store-and-forward.

## 2. Preuves prévues

**PC** :

- MAC : vecteurs RFC 4231 (HMAC-SHA256), étiquette changée d'un bit refusée ;
- dérivation : `K(X↔Y) == K(Y↔X)`, clé différente pour un autre voisin ;
- enveloppe v0C : tous les octets du préimage modifiés un par un → refus ; `ttl`/`hops`
  modifiés → acceptés (plage) ; `forwarder_fp` inconnu → refus avant MAC ;

- relais : le tag est bien réécrit avec la clé aval (A→B→C, trois clés distinctes) ;
- budget : jetons, recharge, rafale de 21 absorbée, 100/s plafonné à N après la rafale ;
- un **compteur d'appels Ed25519** montre zéro vérification pour une enveloppe sans bon
  MAC, et zéro au-delà du budget.

**Kani** :

- avec les clés de lien disponibles, Ed25519 n'est jamais atteint sans MAC valide, et
  v0B est refusé (rétrogradation) ;

- le budget ne délivre jamais plus de `B` jetons sur une fenêtre, ni plus de `N`/s en
  régime ;

- l'analyse de l'enveloppe v0C (parse de `forwarder_fp`/`tag`) est totale.

**Silicium**, B → C, B injectant par `@J` des enveloppes au mauvais MAC (outil adapté)
à débit fixe, en plus d'un message légitime par seconde :

| Débit forgé | Mesures sur C |
|---|---|
| 0, 1, 2, 4, 8 /s, 60 s chacun | vérifications Ed25519 lancées, temps occupé, messages légitimes acceptés/relayés, octets perdus (FIFO) |

- **Avant** (v0B, firmware actuel) puis **après** (v0C + budget), même scénario.
- **Initié** : enveloppes au **bon** MAC mais mauvaise signature, pour chiffrer ce que
  le budget laisse passer (c'est là que le budget, pas le MAC, fait le travail).

- Pas de coupure de courant. A reste l'équipement Modbus ; B et C suffisent.

## 3. Limites dites

- **L'initié** (nœud enrôlé, ou graine volée en lisant la flash — le RP2040 ne la
  protège pas) peut forger un MAC valide sur **ses propres liens** et forcer jusqu'à
  `N`/s de vérifications sur ces liens. Rayon limité à un nœud ; une protection totale
  demanderait un matériel sécurisé, hors périmètre.

- **ECDH statique-statique** : pas de confidentialité persistante, même clé réutilisée
  sur un lien. Acceptable — le MAC ne chiffre rien, l'authenticité vient d'Ed25519.

- **Double usage de la graine** (signer + échange de clés) : courant (libsodium le
  permet), mais noté.

- **Diffusion radio N-voisins hors périmètre** (TRL 6/7) : en diffusion il faudrait une
  étiquette par voisin, ou un `forwarder_fp`/tag par voisin. Non traité ici.

- La clé de lien n'apporte **aucune confidentialité** aux messages : v0C reste en clair.
- En-tête v0C = 123 o (v0B 99 + 24). Sans objet sur UART ; à revoir pour LoRa (C3).
