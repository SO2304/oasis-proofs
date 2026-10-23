# OASIS devant un automate Siemens LOGO! réel

**2026-10-21.** Première campagne d'OASIS avec un **automate du commerce** comme cible. Jusqu'ici,
partout où les documents écrivaient « automate », il fallait lire « simulateur ». Ce n'est plus le
cas pour cette campagne.

## 1. L'appareil

| | |
|---|---|
| Modèle | **Siemens LOGO! 230RCE**, réf. `6ED1052-1FB08-0BA2` |
| Nature | module logique industriel Siemens, 4 sorties relais 10 A, alimentation 230 V |
| Adresse | `192.168.0.3` |
| Serveur Modbus | **port 510**, et non le 502 standard |
| Programme | un bloc `Network Input` relié à un flag mémoire `M1` ; aucune sortie relais câblée |
| Code OASIS embarqué | **aucun** — c'est un appareil Siemens de série, non modifié |

Le PC porte la passerelle OASIS et l'outil d'ordre ; l'automate est relié par un câble Ethernet
direct.

⚠️ **Erratum du 2026-10-22 : « l'automate n'a aucun autre chemin que la passerelle » est faux**, et
cette phrase se trouvait ici. Le **port 102 (S7) de l'automate est ouvert**, et un essai du
2026-10-22 a montré qu'une **écriture S7 commande réellement le relais** : la consigne écrite en S7
ferme puis ouvre Q1, et se relit identique par Modbus. OASIS ne garde que le chemin Modbus. Ce banc
ne respectait donc **pas** le principe « un seul chemin », qui est la condition de toute la valeur
du montage : sur une machine réelle il faut fermer le port 102, ou le placer derrière la même
autorisation. Cela ne retire rien aux résultats ci-dessous — les refus mesurés restent des refus, et
le contrôle négatif du § 4 n'en est que plus net — mais la phrase promettait une exclusivité que le
banc n'avait pas.

⚠️ **Le port est 510, pas 502.** Trois sondages successifs sur 502 l'ont donné fermé, ce qui a
fait croire pendant plusieurs heures que Modbus était désactivé. Un balayage de 500 à 520 puis une
requête FC03 réelle ont tranché.

## 2. Ce qui a été fait

Trois passages complets. La vérité terrain n'est **jamais** ce qu'OASIS annonce : c'est la valeur
relue dans l'automate par un client Modbus indépendant, sans aucune dépendance à OASIS, plus l'état
des quatre bobines de relais.

| Cas | Ce qui est envoyé | Attendu |
|---|---|---|
| C1 | ordre signé légitime, registre 100, valeur **différente à chaque passage** | exécuté, l'automate porte la valeur |
| C2 | même origine, valeur 5000, hors de la plage 0..1000 | refusé, automate inchangé |
| C3 | registre 200, absent de la carte des registres | refusé, automate inchangé |
| C4 | identité connue de la passerelle, **sans** permission `ACTUATE` | refusé, automate inchangé |
| C5 | identité inconnue de la passerelle | refusé, automate inchangé |
| C6 | trame **Modbus brute non signée**, droit sur le port de la passerelle | refusée, automate inchangé |
| C7 | état des 4 relais, début contre fin | identique |
| C8 | journal des décisions, vérificateur indépendant | intact |
| C9 | un refus réécrit en acceptation dans le journal | détecté |

## 3. Résultat

**12 contrôles sur 12, trois fois** (`run1/`, `run2/`, `run3/`).

⚠️ **Le contrôle C8, tel qu'il a tourné ici, ne pouvait pas échouer** : le code de sortie qu'il
lisait était celui d'une commande de mise en forme placée après le vérificateur, toujours 0. Trouvé
le soir même. Les trois journaux de ce dossier, revérifiés avec le vrai code de sortie, sont
intacts, et leurs falsifications détectées ; la campagne relancée avec C8 corrigé donne 12 sur 12,
trois fois. Le détail est dans `../logo-relais/REPORT.md`, § 6.

Les valeurs commandées en C1 diffèrent à chaque passage — **321**, puis **860**, puis **881** — et
l'automate les porte à chaque fois. C'est ce qui rend C1 probant : une première version écrivait
toujours `321`, si bien qu'au deuxième passage le registre valait déjà la valeur attendue et le
contrôle serait passé **sans rien prouver**. Corrigé avant les passages archivés.

**Les relais n'ont pas bougé** : bobines `8192..8199` à `0` avant et après chaque passage. Seuls
des mots mémoire ont été touchés.

Le journal, relu par le vérificateur :

```
boot_id=1792591130129 entries=5 head_seq=Some(4) overwritten=0
  [0] seq=0 origin=aa00 cmd_seq=1   class=Act decision=Act
  [1] seq=1 origin=aa00 cmd_seq=65  class=Act decision=Reject(OutOfLimits)
  [2] seq=2 origin=aa00 cmd_seq=129 class=Act decision=Reject(OutOfLimits)
  [3] seq=3 origin=bb00 cmd_seq=1   class=Act decision=Reject(NotAuthorized)
  [4] seq=4 origin=0000 cmd_seq=0   class=Act decision=Reject(NotVerified)
VERDICT intact entries=5
```

Une acceptation et quatre refus, chacun attribué à son origine — « légitime **ou illégitime** »,
ce que demande l'annexe III 1.1.9 ¶5. Un refus réécrit en acceptation donne `VERDICT broken at=4`,
sortie 1. ⚠️ `at=4` est l'endroit où la vérification s'arrête, pas l'entrée falsifiée (c'était
l'entrée 1) : une seule empreinte de tête **détecte** une modification, elle ne la **localise** pas.

## 4. Le contrôle négatif, et c'est lui qui compte

Un lecteur pourrait objecter : l'automate refusait peut-être ces écritures de lui-même. La réponse
est non, et elle est mesurée. **Sans passer par OASIS**, avec le même client Modbus direct :

| Écriture directe | Résultat |
|---|---|
| 5000 dans le registre 100 (refusé par OASIS en C2) | **acceptée**, le registre porte 5000 |
| 42 dans le registre 200 (refusé par OASIS en C3) | **acceptée**, le registre porte 42 |

**Le LOGO! n'a aucune protection propre : il exécute tout ce qu'on lui envoie.** Les refus de la
campagne sont donc entièrement l'œuvre d'OASIS, et non une vertu de l'automate.

## 5. Ce que cette campagne ne montre pas

- **Un module logique, pas un automate de gamme haute.** Le LOGO! est l'entrée de gamme Siemens,
  vendu comme *module logique*. Ce n'est pas un S7-1200/1500, et « testé sur automate du
  commerce » doit être lu avec cette précision.
- **Un seul registre, une seule fonction.** FC06 sur un registre de la carte.
- **Aucun relais commandé ici.** On s'arrête à la mémoire. Le relais a été commandé le soir même,
  dans une campagne distincte : `../logo-relais/`.
- **Topologie T2** : l'outil d'ordre et la passerelle sont sur le même hôte.
- **Pas de cycle d'automate réaliste** : ni logique métier, ni entrées/sorties câblées.
- **Passages courts**, de quelques minutes.
- **Activation Modbus faite hors OASIS**, avec LOGO!Soft Comfort sous licence, par l'opérateur.

## 6. Ce que ce dossier publie

Les résultats : journaux d'exécution, journaux de décisions, verdicts du vérificateur. Les scripts
d'essai, les configurations et les identités de test ne sont pas publiés. `SHA256SUMS` couvre tous
les fichiers publiés.
