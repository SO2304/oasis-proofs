# Rapport — tentative « deux machines, un câble » (A.6 / T1) : bloquée côté PC2

**2026-10-09.** Objectif : la topologie **T1** du prompt max-tech A.6, plus forte que le
T2 d'un seul hôte — PC1 et PC2 sur deux vraies machines reliées par un câble. Ce rapport
dit ce qui est prouvé et **pourquoi le bout-à-bout n'a pas pu se faire**.

---

## 1. Le montage

Deux PC reliés par Ethernet. Faute d'un accès à l'écran/clavier de PC2, le montage retenu
était : **ce PC** = passerelle OASIS + appareil de test ; **PC2** (une machine **Dell**
sous Windows) = l'outil d'ordre qui commande à travers le câble, en connexion **sortante**
(aucun droit admin, aucun pare-feu à toucher).

| | |
|---|---|
| Ce PC (Ethernet) | `fe80::1601:70df:35b:73c0%19` (IPv6 lien-local) |
| PC2 | `fe80::a6bb:6dff:fexx:xxxx`, MAC `A4-BB-6D-xx-xx-xx` (OUI **A4:BB:6D = Dell**) |
| Lien IPv4 | **aucun** — PC2 n'a qu'une adresse IPv6 lien-local |

Le choix d'IPv6 lien-local est délibéré et c'est la **solution** au problème « contourner
Windows » : les deux machines l'ont automatiquement, donc **aucune IP statique à poser**
(ce qui demandait des droits admin indisponibles) et **rien à ouvrir dans le pare-feu**.
`network_facts.log` en porte la trace.

---

## 2. Ce qui est prouvé

**Le lien physique fonctionne dans les deux sens.** PC2 répond au ping IPv6 (1–10 ms, 0 %
de perte), et ma passerelle est joignable. Les deux vraies machines se parlent sur le vrai
câble.

**OASIS parle IPv6**, validé de bout en bout *de ce côté* (`oasis_ipv6.log`) :

```text
gateway listening : [::]:15711  (IPv6, toutes interfaces)
legit Act 60%     : ORDER acted                → PLC APPLIED_WRITE writes=1 reg=10 value=60
attack 40%        : Refused(OutOfLimits)        → aucune écriture
journal           : [0] Act, [1] Reject(OutOfLimits), VERDICT intact
```

Le transport IPv6, la porte de décision, l'écriture appareil et le journal **fonctionnent**
— c'est exactement le chemin que le test deux-machines aurait emprunté.

⚠️ Cette validation OASIS-sur-IPv6 a été faite **depuis ce seul hôte** (l'ordre vise
l'adresse Ethernet de ce PC). Elle prouve que le **transport et la porte** marchent en
IPv6 ; elle **ne** prouve **pas** qu'un ordre est parti de PC2 et a traversé le câble.

---

## 3. Ce qui est bloqué, et pourquoi

**PC2 n'expose aucune prise d'exécution.** Tous les ports de gestion à distance ont été
sondés sur son IPv6 — SSH, RPC, NetBIOS, SMB, RDP, WinRM, VNC, TeamViewer, AnyDesk —
**aucun n'est ouvert** (`network_facts.log`). Et aucun identifiant n'est disponible.

La connexion **USB** entre les deux PC n'a monté **aucune interface réseau, aucun disque,
aucun périphérique « link/RNDIS »** sur ce PC : elle n'a donné aucun chemin de données.

Le **BIOS/UEFI** de PC2 n'est atteignable ni par USB ni par réseau depuis ce PC : ce n'est
pas une surface d'exécution à distance. Il n'y a pas de « passer par le BIOS ».

Conséquence directe : **l'outil d'ordre n'a pas pu être lancé sur PC2**, donc aucun ordre
n'a traversé le câble depuis une seconde machine. Le **bout-à-bout deux-machines n'a pas
eu lieu**, et la topologie **T1 n'est pas démontrée**.

Ce n'est pas une limite d'effort : exécuter du code sur une machine sans service d'accès
distant et sans identifiant reviendrait à y entrer par effraction, ce qui n'a pas été
fait — sur aucune machine.

---

## 4. Ce que ce rapport NE prouve PAS

- **Pas de test T1 deux-machines.** La décision d'autorisation n'a pas été exercée sur un
  ordre venu d'une **seconde machine** à travers le câble.
- La validation OASIS-sur-IPv6 est **mono-hôte** (§2).
- Rien de nouveau sur l'onduleur SMA (c'est un sujet séparé, bloqué côté activation Modbus).
- « Non testé sur automate du commerce » **reste vrai**.

---

## 5. Comment le compléter plus tard

Il ne manque qu'**une action humaine sur PC2** : lancer une seule commande. Le paquet est
déjà prêt (`twohost/pc2/` sur ce PC : l'agent compilé en **statique**, les clés, un script
qui détecte tout seul l'interface de PC2 et vise la passerelle en IPv6). Dès qu'un humain
peut lancer `run_agent.ps1` sur PC2 — clavier même sans écran, clé USB amorçable, ou un
accès distant déjà en place — le bout-à-bout tourne et se journalise.

---

## 6. Ce que ma propre vérification a établi

L'enquête a été menée à fond avant de conclure au blocage : découverte de PC2 par
**IPv6 ND** (`ff02::1`) alors que l'IPv4 ne donnait rien ; identification du constructeur
par l'**OUI du MAC** (Dell) ; sondage **complet** des ports de gestion (tous fermés) ;
contrôle de ce que l'**USB** a monté (rien) ; et validation qu'**OASIS parle IPv6** avant
d'affirmer que seul l'accès à PC2 manquait.
