# Rapport — la campagne répétée : quatre limites traitées (A.6 / T1, second dossier)

> *Expurgé pour publication le 2026-10-23 / redacted for publication on 2026-10-23 : chemins de sources, identifiants internes et noms de harnais retirés ; résultats inchangés.*

**2026-10-10, fin de soirée.** [withheld: test harness] à `4fea1b5`, versionné avec ses
quatre contournements **avant** de mesurer (règle 5). `RUNS_CABLE=1`, `RUNS_SHIPPED=3`.
**84 contrôles sur 84.** Le dossier précédent (`../twohost-campaign/`, 61/61) listait en §6
quatre limites ; ce dossier dit ce que chacune est devenue, et ce qu'elle reste.

`RUNS_CABLE=1` parce que la phase câble de l'outil d'ordre avait déjà tourné 3 × 3 fois dans
les deux campagnes précédentes : les répétitions visent A2 et B, qui n'avaient tourné
qu'une fois après le correctif du journal.

---

## 1. Les quatre limites

| Limite du dossier précédent | Contournement | Preuve ici | Ce qui reste |
|---|---|---|---|
| A2 et B n'avaient tourné qu'une fois | `RUNS_SHIPPED=3` : A2 entier répété 3 fois (agent relancé à chaque fois), les cas d'écriture de B et les deux latences répétés 3 fois | A2 : 3 × (écriture, 0x02, 0x03, lecture, latence), **619** écritures appareil, aucune perdue ; B : 3 × (écriture, 0x02, 0x03), 3 latences ; **622** écritures | les répétitions sont **dans un seul lancement** ; les redémarrages de l'agent et de la passerelle ne tournent qu'une fois |
| Pas de rejeu entre les deux machines | **B7b**, sans autre outil que celui livré : l'état persistant de l'outil d'ordre (compteur et séquence) est sauvegardé, un ordre est envoyé, l'état est **remis en place**, le même ordre repart | `FIRST` exécuté, `SECOND` exécuté, `REUSE` **non confirmé** ; la passerelle le rejette **avant la porte** (`MESH_DROP "stale counter"`) ; l'appareil ne bouge que pour les deux vrais ordres | le **renvoi octet pour octet** d'une trame capturée et l'**ordre périmé** restent couverts sur un seul hôte et par Kani, pas entre deux machines |
| Chaînes archivées sans rétention | `oasis_mbtcp_gateway --keep-journals N` : au démarrage, seules les N archives les plus récentes survivent ; sans drapeau, tout est gardé | 2 tests unitaires ; **contrôle négatif** : rétention désactivée, 2 tests sur 6 échouent. [withheld: code identifier] ne touche que `<base>.<tag>.head/.entries` du préfixe, jamais la paire vive, jamais un autre préfixe | **pas exercé dans la campagne** : la phase B n'a que deux démarrages, donc une archive, et rien à élaguer. Prouvé par les tests, pas sur le terrain |
| Un administrateur de PC1 peut réécrire entrées et tête ensemble | **Témoin hors de l'hôte**, [withheld: off-host witness tool] : la tête et l'empreinte SHA-256 des entrées de la chaîne archivée sont ajoutées à un fichier **sur PC2** ; `check` compare la chaîne à cette copie | l'ancrage relu **depuis PC2** est identique octet pour octet ; la chaîne archivée → `WITNESS ok` ; la copie où un refus est réécrit en `Act` (la même que le contrôle de falsification) → `WITNESS DIVERGENCE` | voir §4 : dans ce montage, **PC1 détenait la clé SSH de PC2**, donc l'hôte surveillé pouvait aussi écrire le fichier témoin. La mécanique est démontrée ; l'indépendance de l'hôte témoin ne l'est pas |

Aucune règle de décision n'a été touchée. Le format du journal et [withheld: source file] (vérifié par
Kani) non plus.

## 2. Latence, toutes campagnes confondues

Mesure côté IHM, sur PC2, une connexion tenue, K = 10 séries de 20 écritures, médiane des
médianes et demi-dispersion. Chaque écriture comprend la signature sur PC2, l'aller-retour
réseau, et sur PC1 la vérification, la porte, l'écriture sur l'appareil et le journal avec
deux vidages sur disque.

| Chemin | Campagne 1 | Campagne 2 | Ce dossier (3 répétitions) | Plage |
|---|---:|---:|---:|---:|
| Câble direct 100 Mbit/s | 1 972 µs ± 22 % | 1 961 µs ± 20 % | 1 946 ± 17 %, 1 886 ± 18 %, 1 914 ± 11 % | **1,89 – 1,97 ms** |
| LAN, deux sauts Wi-Fi | 3 899 µs ± 30 % | 5 150 µs ± 27 % | 5 128 ± 63 %, 5 452 ± 29 %, 7 189 ± 83 % | **3,9 – 7,2 ms** |

Cinq mesures par chemin. Sur le câble, elles tiennent dans 5 % : c'est un chiffre. Sur le
Wi-Fi, du simple au double, avec des dispersions jusqu'à ± 83 % : c'est un ordre de grandeur,
et c'est pour cela que la répétition valait la peine. ⚠️ L'appareil est un simulateur sans
cycle d'automate : sa part est un plancher.

## 3. Journaux

Trois chaînes sur le disque, chacune `VERDICT intact`, exit 0 : `jrnA` (619 `Act`, 10 refus),
`jrnB.1791660239432` (le premier démarrage de B, archivé) et `jrnB`, 622 `Act` et 7 refus à
elles deux. Les refus de B sont les six hors-limites et le rejeu de B7b, rejeté au maillage.
**`Act` = écritures de l'appareil** : 619 = 619, 622 = 622. Un refus réécrit en `Act` dans la
chaîne archivée → `broken`, exit 1.

## 4. Ce que ce dossier NE prouve PAS

- **Le témoin n'est démontré qu'en mécanique.** L'ancrage a été poussé sur PC2 depuis PC1,
  avec la clé SSH que PC1 détient : un administrateur de PC1 aurait pu, par la même voie,
  réécrire `witness.log` sur PC2. Un déploiement doit donner à l'hôte de la passerelle le
  droit d'**ajouter** et rien d'autre (commande SSH restreinte, support non réinscriptible,
  impression), et ancrer assez souvent : une entrée réécrite **entre** deux ancrages puis
  ré-ancrée n'est pas détectée. Le témoin dit « rien de ce que j'ai vu n'a changé », pas
  « rien n'a changé ».
- **La rétention n'a pas tourné sur le terrain**, seulement en tests unitaires.
- **Le rejeu démontré est celui d'un compteur et d'une séquence réutilisés** par l'outil
  livré, pas le renvoi octet pour octet d'une trame capturée ; l'ordre périmé entre deux
  machines n'est pas fait non plus.
- **Un seul lancement** ; les répétitions sont internes à ce lancement.
- Toujours **pas un automate du commerce**, toujours un Wi-Fi domestique et non un réseau
  industriel ; pare-feu de PC1 désactivé sur les profils du câble et du LAN.

## 5. Reproduire

```text
RUNS_CABLE=1 RUNS_SHIPPED=3 PC2_SSH=… PC2_KEY=… PC2_KNOWN_HOSTS=… PC2_HOSTKEY_ALIAS=… PC1_LL=… PC1_LAN=…
bash [withheld: test harness] <dossier de sortie>
```

## 6. Fichiers

| Fichier | Contenu |
|---|---|
| `campaign.log` | les 84 contrôles, dans l'ordre |
| `gateway_a.log`, `gateway_b.log` | la passerelle, câble puis LAN (B : deux démarrages ; le `MESH_DROP` du rejeu y est) |
| `gw_a.conf`, `gw_b.conf` | clés **publiques** seulement |
| `plc.log` | l'appareil : chaque trame, chaque écriture appliquée |
| `jrnA.*`, `jrnB.*`, `jrnB.1791660239432.*` | les trois chaînes, concaténations et verdicts |
| `jrn_tampered.txt`, `jrn_tampered.verify` | la chaîne archivée avec un refus réécrit : `broken`, exit 1 |
| `witness.local`, `witness.pc2` | l'ancrage tel qu'écrit sur PC1, et tel que relu depuis PC2 |
| `wbad/` | la paire réécrite soumise au témoin : `DIVERGENCE` |
| `pc2/` | sur PC2 : configurations (chemins de graines seulement, **aucune graine n'a quitté PC2**), journaux des agents, et `witness.log` tel que PC2 le tient |
| `SHA256SUMS` | empreintes de tout ce qui précède |

Adresse câble et nom de compte de PC2 masqués ; les adresses LAN sont privées (RFC 1918).
