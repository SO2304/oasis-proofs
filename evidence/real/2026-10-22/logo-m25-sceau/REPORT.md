# Le dernier N tombe : 35 critères, 32 J, 0 N, trois fois

**2026-10-22, nuit.** Cinquième et dernier état de l'essai aligné sur `GS-IFA-M25`. Le seul critère
qui restait en **nein** était **T43 *Exklusiv*** — *l'effacement du journal peut-il être exécuté
exclusivement par le processus décrit ?* Il est en **J**, et la façon d'y arriver mérite d'être
expliquée, parce que la réponse naïve était impossible.

> ⚠️ **Erratum de provenance, 2026-10-23.** Les passages de ce dossier annoncent
> `build=b90c6d780ec4`. **Ce commit ne contenait pas le code qu'ils ont exécuté** : le sceau de continuité que ce dossier éprouve n'existe qu'à partir du commit suivant. Le binaire
> avait été compilé à partir d'un arbre de travail **non encore commité**, et la première version
> du script qui grave l'empreinte ne le signalait pas — il gravait le commit **parent**. Les
> verdicts restent des observations exactes de ce que le code exécuté a fait ; mais ces passages ne
> sont **attribuables à aucun commit par leurs propres pièces**, ce qui est précisément ce que
> **T03** existe pour empêcher. T03 n'est donc **pas** satisfait ici, quoi qu'en dise la suite du
> rapport. Le défaut est corrigé (l'empreinte porte désormais `-dirty` pour un arbre modifié), et
> l'essai compare maintenant l'empreinte annoncée aux entrées de la compilation du dépôt.
> **Un passage attribuable existe** : `../../2026-10-23/verification/`, où T03 est satisfait, et
> chaque essai y a tourné trois fois.

| | critères | J | N | E |
|---|---:|---:|---:|---:|
| matin, `../logo-m25/` | 22 | 15 | 4 | 3 |
| après correction des quatre | 22 | 20 | 0 | 2 |
| avec l'actionneur physique | 29 | 26 | 1 | 2 |
| avec les cinq formes de manipulation | 33 | 30 | 1 | 2 |
| **ici** | **35** | **32** | **0** | 3 |

Trois passages, verdicts identiques à l'empreinte près, 35 critères ayant tous un verdict.

Les deux états intermédiaires du tableau ne sont pas publiés — cinq copies du même essai seraient du bruit. Ce dossier porte le **premier** état, `../logo-m25/`, parce qu'il contient les quatre critères en échec, et le **dernier**, celui-ci. Les chiffres des deux lignes du milieu sont donnés pour la progression, sans pièce à l'appui dans ce corpus.

⚠️ **Les verdicts sont les nôtres.** Personne n'a examiné OASIS, `GS-IFA-M25` est une
*Teilprüfung* sans marque de contrôle, et EN 50742 n'est pas publiée.

## 1. Le cadrage, parce qu'il décide de ce qui est atteignable

Sur un hôte généraliste, « **exclusivement** » ne peut pas devenir littéralement vrai : qui a les
droits sur un fichier le supprime, et aucun logiciel ne change cela. Prétendre le contraire aurait
été la seule vraie faute possible ici.

Ce qui **peut** devenir vrai, et qui est maintenant mesuré : **aucune autre voie ne donne un
effacement *utilisable***. Toute route hors du processus décrit coûte la passerelle, et se voit.

## 2. Le sceau de continuité

La passerelle garde, **hors du journal**, la tête de la chaîne vivante — `<préfixe>.seal`, écrit dès
l'ouverture puis à chaque décision, synchronisé sur le médium. Au démarrage, avant d'ouvrir une
chaîne neuve, elle vérifie que la chaîne scellée est là, à la tête scellée.

| Situation | La passerelle sert ? | Ce qu'elle dit |
|---|---|---|
| premier démarrage | oui | *first run on this prefix* |
| redémarrage normal | oui | *the sealed chain is where it was left* |
| **chaîne vivante supprimée** | **non** | nomme le démarrage disparu et jusqu'où il allait |
| **sceau supprimé, archives restantes** | **non** | *this gateway has run here before* |
| **tête réécrite pendant l'arrêt** | **non** | montre la tête scellée et celle trouvée |
| `--accept-journal-loss` | oui | et **la perte entre dans la nouvelle chaîne** : `Change(TamperSignal)` |

Reprendre après une perte exige donc un drapeau **nommé**, et l'acquittement laisse une trace. C'est
le même motif que `--no-journal` pour T36 et `new_without_duty_limit` côté radio : ce qui affaiblit
la preuve doit être demandé à voix haute.

**Le processus décrit ne déclenche jamais ce refus.** `--keep-journals N` ne touche que les archives
et enregistre ce qu'il retire (T44). Un test le tient : rendre la rétention documentée inutilisable
aurait été pire que le défaut d'origine.

## 3. Ce qui le vérifie

- **5 tests** sur la persistance du journal : première exécution, redémarrage normal, chaîne supprimée, tête
  réécrite, sceau effacé, et la non-régression de la rétention.
- **3 contrôles négatifs**, tous en échec comme voulu : une détection aveugle (5 tests tombent), un
  sceau jamais écrit (5 tombent), et une rétention qui effacerait le sceau (2 tombent) — ce dernier
  prouve que le garde-fou ne casse pas le processus légitime.
- **699 tests de bibliothèque.** Un test antérieur, `a_first_start_moves_nothing`, a correctement vu
  le changement en comptant les fichiers d'un premier démarrage : 3 au lieu de 2. Il les **nomme**
  désormais (`jrn.entries`, `jrn.head`, `jrn.seal`), pour qu'un prochain ajout dise lequel est
  arrivé au lieu d'un chiffre qui a bougé.
- **Les six situations éprouvées sur le banc**, contre le LOGO! réel, archivées dans `run*/t43/`.

## 4. Le résidu, déclaré en E et non caché

Qui supprime la chaîne, le sceau **et** chaque archive ne laisse plus rien sur l'hôte. À ce point,
seul l'**ancrage hors hôte** témoigne encore — et c'est pourquoi `T43:temoin_divergence` l'éprouve
dans le même passage : `WITNESS DIVERGENCE` sur une chaîne réécrite.

**Le sceau ne rend pas l'effacement impossible. Il le rend inutilisable et visible.** C'est la
formulation à employer devant un évaluateur, et elle est dans le verdict `T43:residuel`.

Deux limites de l'ancrage restent, inchangées : l'ancre est ici **sur le même disque** (la mécanique
est démontrée, la séparation non), et une réécriture **entre deux ancrages** n'est pas vue.

## 5. Ce que cet essai ne montre pas

- Les **44 autres critères** sont documentaires et plusieurs sont à produire par le client. Les
  critères éprouvables sur banc sont désormais épuisés : ce qui reste n'est pas de la mesure.
- Les trois **E** sont sans objet pour un banc, non des échecs : T38 pour les changements de
  configuration autres (démontrés ailleurs), T48 (conformité BSI TR-02102-1, documentaire), et
  `T43:residuel` ci-dessus.
- Un **module logique**, pas un S7-1200/1500 ; un relais, à vide ; deux registres ; topologie T2.
- **T45 est satisfait par chaîne et non par entrée** : lecture défendable, pas officielle.
- Le sceau vit **à côté** du journal. Un déploiement sérieux le met hors de portée du compte qui
  sert — attribut d'ajout seul, support séparé — ce que la notice doit décrire.

## 6. Le harnais d'essai n'est pas publié : ce corpus porte les **résultats**, pas la méthode. Chaque
passage archive ici sa trace complète, ses journaux de décisions et le verdict rendu par le
vérificateur indépendant, de sorte qu'un lecteur contrôle les conclusions sans exécuter quoi que ce
soit. `SHA256SUMS` couvre tous les fichiers présents.
