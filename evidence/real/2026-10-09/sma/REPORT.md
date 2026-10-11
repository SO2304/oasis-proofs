# Rapport — la passerelle OASIS devant un vrai onduleur SMA (partiel)

**2026-10-09, empreinte `2eb7e3d`.** Rejouable : `bash tools/sma_campaign.sh`. Journaux :
[`run/campaign.log`](run/campaign.log), [`run/journal_dump.txt`](run/journal_dump.txt).

⚠️ **Ce rapport est partiel, et il faut le lire comme tel.** Le serveur Modbus de l'onduleur
est **désactivé** et n'a pas pu être activé (il faut le mot de passe installateur de
l'interface web, qui n'était pas disponible — voir [`PLAN.md`](PLAN.md) §4 et §8). Donc
**aucune écriture n'a atteint l'onduleur** et la moitié « une écriture légitime accepte,
l'onduleur obéit » **n'est pas démontrée**. Ce qui suit est la seule chose prouvable en
l'état, et elle est réelle : **la passerelle, pointée sur l'onduleur réel, refuse chaque
attaque et ne le touche jamais ; seule une décision `Act` tente de l'atteindre.**

---

## 1. L'appareil

| | |
|---|---|
| Modèle | **SMA Sunny Boy SB4.0-1AV-40**, onduleur monophasé 4000 W (plaque, 2018) |
| Adresse | `169.254.12.3` (lien-local), OUI `00:40:AD` = SMA Solar Technology |
| Firmware | **non relevé** — nécessite la connexion web ou le Modbus actif |
| Modbus TCP | **port 502 fermé** (désactivé par défaut, comme SMA le documente) |

---

## 2. Ce qui a été fait, et le résultat

La passerelle a été configurée avec `peer_addr = 169.254.12.3:502` — **l'onduleur réel** —
une carte des registres à une seule entrée (plage 50–100 %), l'agent enrôlé avec `ACTUATE`,
un pair enrôlé **sans** `ACTUATE`, et une clé non enrôlée. Six cas, le journal de la
passerelle comme preuve autoritaire :

| Cas | Résultat | Où il est refusé |
|---|---|---|
| **Act légitime 60 %** | la passerelle **décide `Act`**, tente de joindre l'onduleur → `TimedOut` (Modbus éteint) | nulle part — il **atteint** l'onduleur, mais ne peut pas atterrir |
| valeur hors plage 40 % | `Reject(OutOfLimits)` | **par la porte** (plage) |
| registre hors carte | `Reject(OutOfLimits)` / `RegisterNotAllowed` | **par la porte** (carte) |
| origine forgée (clé inconnue) | `Reject(NotVerified)`, origine `0000` | **avant la porte** (couche de vérification v0B) |
| clé enrôlée sans `ACTUATE` | `Reject(NotAuthorized)`, origine `7800` | **par la porte** (permission) |
| Modbus brut vers le port passerelle | connexion avortée, **aucune entrée de journal** | **avant la porte** (cadrage : ce n'est pas une enveloppe v0B) |

Journal de la passerelle, relu par `oasis_journal_verify` :

```text
  [0] seq=0 origin=aa00 cmd_seq=1   decision=Act
  [1] seq=1 origin=aa00 cmd_seq=65  decision=Reject(OutOfLimits)
  [2] seq=2 origin=aa00 cmd_seq=129 decision=Reject(OutOfLimits)
  [3] seq=3 origin=0000 cmd_seq=0   decision=Reject(NotVerified)
  [4] seq=4 origin=7800 cmd_seq=1   decision=Reject(NotAuthorized)
VERDICT intact entries=5
```

**Port 502 de l'onduleur : fermé avant, fermé après.** Rien n'a été écrit sur l'appareil.

---

## 3. Les quatre questions du prompt, répondues honnêtement

**Combien d'écritures ont atteint l'onduleur, et combien de décisions `Act` ?**
**0 écriture atteinte, 1 décision `Act`.** Ces deux nombres **ne sont pas égaux**, et c'est
le constat central : normalement une décision `Act` produit une écriture qui atterrit ;
ici, la seule `Act` a bien fait **tenter** la connexion à l'onduleur, mais l'écriture n'a
pas pu atterrir parce que le serveur Modbus est éteint. L'égalité que le prompt attend
exige un onduleur avec Modbus actif.

**Quelles attaques ont été refusées, et où ?**
Les cinq attaques ont été refusées, et le journal dit **où** : deux **avant la porte**
(l'origine forgée, à la couche de vérification v0B, journalisée `NotVerified` avec origine
`0000` parce que la prétention n'est pas vérifiée ; le Modbus brut, au cadrage, sans même
une entrée) et trois **par la porte** (hors plage, hors carte, sans permission `ACTUATE`).

**Ce que le journal relu prouve, et contre qui ?**
Il prouve, contre un attaquant **à distance**, que chaque décision — acceptée **ou
refusée** — est enregistrée, chaînée, et **infalsifiable à distance** : `VERDICT intact`
sur les 5 entrées, et quand on **réécrit le dernier refus en acceptation**, la vérification
le détecte (**exit 1**, chaîne rompue). Il ne prouve rien contre quelqu'un ayant un accès
physique à l'hôte, qui peut réécrire entrées et tête ensemble.

**Ce que cette campagne NE prouve PAS** (liste lisible telle quelle à un client) :
- qu'une écriture légitime atteint l'onduleur et qu'il obéit — le Modbus était éteint ;
- que l'adresse du registre `WMaxLimPct` est la bonne — elle n'a pas pu être découverte
  sur l'appareil (registre **placeholder** utilisé pour la démonstration) ;
- quoi que ce soit sur la puissance AC réelle, ni de lecture par la passerelle (`OMQ1`) ;
- la latence de bout en bout contre un vrai appareil ;
- que l'onduleur est une **machine** au sens du Règlement (UE) 2023/1230 — c'est un
  **équipement d'énergie**, et cette campagne **ne démontre pas** l'annexe III 1.1.9.

---

## 4. Limites

- **Équipement d'énergie, pas machine.** Une seule commande sans danger (limitation de
  puissance), un seul registre, aucune E/S, aucun cycle de scrutation.
- **Topologie T2** : agent et passerelle sur la même machine (un seul PC). Plus faible que
  deux hôtes.
- **Registre placeholder** (`40236`), non confirmé sur l'appareil. Le script **refuse**
  d'envoyer l'`Act` légitime si le port 502 est ouvert, pour ne pas écrire un mauvais
  registre sur un onduleur vif.
- **Profil Modbus de l'onduleur non audité par nous.**
- La phrase « **non testé sur automate du commerce** » reste vraie : un onduleur n'est pas
  un automate, et cette campagne ne la lève pas.
- **La porte de décision n'a pas été touchée** (règle 2) : `modbus_gateway`, `modbus_tcp`,
  `actuation` et les binaires `oasis_mbtcp_*` sont ceux déjà prouvés par la campagne à 69
  cas contre `oasis_test_plc` et par Kani. Ce qui est nouveau ici est seulement que la
  cible configurée est un **vrai onduleur SMA du commerce**.

---

## 5. Ce que ma propre vérification a trouvé

- **Mon premier scan réseau a rendu « aucun appareil »** sur 508 hôtes alors qu'un port
  était ouvert que je venais de confirmer : 508 connexions simultanées pour une seule
  attente. Refait par balayage ICMP puis lecture ARP — c'est là que l'OUI SMA est apparu.
- **La photo de la plaque ne permet pas de se connecter** : la WPA2-PSK est la clé du Wi-Fi
  de l'onduleur, le RID/PIC sont des codes Sunny Portal ; aucun n'est le mot de passe du
  groupe Installateur de l'interface web. Je n'ai tenté aucun contournement de cette
  authentification.
- **Ma première falsification du journal retournait l'octet de séquence** → `exit 2`
  (trou de séquence) au lieu de l'`exit 1` attendu. Corrigée pour réécrire le refus en
  acceptation, ce que le prompt demande.
- **Un trou dans mon propre contrôle** : la complétude des manifestes ignorait un
  répertoire de preuves sans aucun `SHA256SUMS`. Le contrôle signale désormais tout
  fichier orphelin.
