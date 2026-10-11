# Règlement Machines (UE) 2023/1230 — correspondance OASIS

**Rédigé le 2026-10-07.** Texte de référence : version **consolidée en vigueur au
27/07/2026**, CELEX `02023R1230-20260727`
([FR](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:02023R1230-20260727),
[EN](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:02023R1230-20260727)).
ELI : <http://data.europa.eu/eli/reg/2023/1230/oj>.

> ⚠️ **Ne jamais citer le PDF du JO L 165 du 29.6.2023 pour les dates.** Le texte publié
> portait « 14 janvier 2027 » ; un **rectificatif (JO L 169 du 4.7.2023, p. 35**, CELEX
> [`32023R1230R(01)`](https://eur-lex.europa.eu/legal-content/FR/TXT/?uri=CELEX:32023R1230R(01)))
> a remplacé toutes les dates en « 14/13 » par celles en « 20/19 ». Le consolidé fait foi.

> **Ce document ne revendique aucune fonction de sûreté.** OASIS n'est pas une fonction de
> sûreté certifiée : ni PL au sens d'ISO 13849-1, ni SIL au sens d'IEC 62061. OASIS est un
> composant logiciel d'**autorité de commande** : il décide si un ordre reçu est authentique,
> habilité, frais et dans les limites configurées. La réduction du risque machine reste
> assurée par le système de commande relatif à la sécurité du fabricant. Voir
> [`IEC_TS_63074.md`](IEC_TS_63074.md).

---

## 1. Dates — ce qui est applicable, et quand

| Disposition | Application | Statut au 2026-10-07 |
|---|---|---|
| Entrée en vigueur (art. 54, al. 1) | 19/07/2023 | en vigueur |
| Articles 26 à 42 (organismes notifiés) | 20/01/2024 | applicable |
| Article 50(1) — sanctions ; notification art. 50(2) | **20/10/2026** | **dans 13 jours** |
| **Annexe III 1.1.9 et 1.2.1**, art. 8, 10, 11, 20, 21, 24, 25 | **20/01/2027** | **pas encore applicable** |
| Abrogation de la directive 2006/42/CE (art. 51(2)) | 20/01/2027 | pas encore |
| Actes délégués « IA à haut risque » modifiant l'annexe III (art. 8, al. 3, inséré par (UE) 2026/1744) | « applicables le 2 août 2028 au plus tard » | non adoptés (non vérifié à la source) |

Article 54, al. 2 (consolidé, marqueur ►C1) : « Il est applicable à partir du **20 janvier
2027**. »

**Conséquence pour un dossier technique rédigé aujourd'hui :** jusqu'au 19/01/2027 inclus le
référentiel opposable est la directive 2006/42/CE, qui **ne contient aucun équivalent de
1.1.9**. 1.1.9 et 1.2.1 sont donc des exigences **futures, datées et certaines** — pas du
droit déjà opposable. Il n'existe **aucune période transitoire après** le 20/01/2027 pour
mettre un produit sur le marché sous l'ancien régime (art. 52(1) ne protège que les produits
déjà mis sur le marché avant cette date).

### Pas de présomption de conformité disponible

Au 2026-10-07, **aucune norme harmonisée n'est citée au Journal officiel au titre du
règlement (UE) 2023/1230** : toutes les décisions d'exécution en vigueur, y compris la plus
récente (septembre 2026), relèvent encore de la directive 2006/42/CE
([Commission européenne — Harmonised standards, Machinery](https://single-market-economy.ec.europa.eu/single-market/goods/european-standards/harmonised-standards/machinery-md_en)).
La page annonce une première liste « avant la fin de cette année » : **annonce non datée**, à
ne pas traiter comme une échéance.

Trois voies de présomption existent à l'article 20, dont une qui vise **nommément** nos deux
points :

> **Article 20, paragraphe 9** — « Les machines et produits connexes qui ont été certifiés ou
> pour lesquels une déclaration de conformité a été délivrée au titre d'un schéma de
> certification de cybersécurité adopté conformément au règlement (UE) 2019/881 dont les
> références ont été publiées au Journal officiel de l'Union européenne sont présumés
> conformes aux exigences essentielles de santé et de sécurité énoncées à l'annexe III,
> **sections 1.1.9 et 1.2.1** […] dans la mesure où ces exigences sont couvertes par le
> certificat de cybersécurité ou la déclaration de conformité […]. »

C'est **la** voie réglementaire qui transformerait OASIS en « aide au marquage CE » : un
schéma au titre du règlement (UE) 2019/881 (famille EUCC), pas IEC 62443 directement.
⚠️ **Non vérifié à la source** : je n'ai pas établi qu'un schéma 2019/881 ait aujourd'hui ses
références publiées au JO d'une manière qui active l'article 20(9) pour les machines.

---

## 2. Périmètre — qui est concerné

### Machines mobiles autonomes : incluses et spécifiquement réglementées

L'annexe III, partie 3, les définit et leur impose des exigences propres :

> « “machine mobile autonome”: une machine mobile qui dispose d'un mode autonome, dans lequel
> toutes les fonctions essentielles de sécurité de la machine mobile sont assurées dans sa
> zone de déplacement et de travail sans interaction permanente d'un opérateur; »

> « “fonction de supervision”: la surveillance à distance non permanente d'une machine mobile
> autonome par un dispositif permettant de recevoir des informations ou des alertes et de
> **donner des ordres limités** à cette machine. »

> « La fonction de supervision permet uniquement d'arrêter et de démarrer la machine ou le
> produit connexe à distance ou de les déplacer vers un endroit sûr et un état sûr […]. »
> « **Si la fonction de supervision n'est pas active, la machine ne peut pas fonctionner.** »
> « Pour les machines ou produits connexes mobiles autonomes, le système de commande est conçu
> pour assurer **lui-même** les fonctions de sécurité définies dans la présente section, même
> lorsque des actions sont ordonnées au moyen d'une fonction de supervision à distance. »

Et, pour la commande à distance en général :

> « Les machines ou les produits connexes commandés à distance sont conçus et construits de
> façon à **ne répondre qu'aux signaux des unités de commande prévues**. »

Cette dernière phrase est la formulation réglementaire la plus proche de ce que fait OASIS.

Les exclusions des articles 2(2)(g) à (i) ne jouent que pour les véhicules **homologués** au
titre des règlements (UE) 2018/858, n° 168/2013 et n° 167/2013, et même alors « à l'exclusion
des machines montées sur ces véhicules ». Un AGV ou AMR industriel non homologué route reste
une machine au sens du règlement.

### Composants de sécurité vendus séparément : couverts, logiciel inclus

> **Article 3, point 3)** — « “composant de sécurité”: un composant physique ou numérique,
> **y compris un logiciel**, d'un produit relevant du champ d'application du présent
> règlement, qui est conçu ou prévu pour assurer une **fonction de sécurité** et qui est **mis
> isolément sur le marché**, dont la défaillance ou le mauvais fonctionnement met en danger la
> sécurité des personnes […]. »

Les trois critères sont **cumulatifs**. OASIS, tel qu'il existe, ne remplit pas le premier :
il n'assure pas une fonction de sécurité au sens de l'article 3(4) (« une fonction remplie par
une mesure de protection destinée à éliminer un risque ou […] à le réduire »). Le présenter
comme un composant de sécurité serait à la fois faux et contraire à la règle n° 3 de ce projet.

### Aéronefs et drones : l'exclusion n'est **pas** simple ni acquise

C'est une correction par rapport à `POSITIONING_GAPS.md` A1, qui notait « les aéronefs sont en
principe exclus ». Le texte est plus subtil :

> **Article 2(2)(e)** — « moyens de transport par air, par eau et par réseaux ferroviaires,
> **à l'exception des machines montées sur ces moyens de transport**; »

> **Article 2(2)(f)** — « produits, pièces et équipements aéronautiques qui relèvent du champ
> d'application du règlement (UE) 2018/1139 […] et de la définition des machines prévue par le
> présent règlement, **dans la mesure où** le règlement (UE) 2018/1139 couvre les exigences
> essentielles de santé et de sécurité pertinentes définies dans le présent règlement; »

Le règlement ne contient **ni le mot « drone » ni « aéronef sans équipage »**, et aucun
considérant consacré à l'aviation. L'exclusion est donc **conditionnelle et partielle** : elle
dépend du produit concret et de la couverture effective des EESS par le régime aviation. Une
machine montée sur un drone (bras, treuil, pulvérisateur) n'est pas exclue par 2(2)(e).
⚠️ **Non vérifié à la source** : aucun guide ou FAQ de la Commission traitant du statut des
UAS au regard de 2(2)(e) et (f) n'a été trouvé. À traiter comme une qualification juridique à
faire, pas comme une exclusion acquise.

### Statut d'OASIS dans la chaîne

Le règlement n'impose d'obligations qu'aux opérateurs économiques **du produit**. Trois statuts
possibles pour un fournisseur de logiciel :

| Statut | Obligations | Cas d'OASIS |
|---|---|---|
| **Composant de sécurité** mis isolément sur le marché (art. 3(3)) | Produit à part entière : art. 10, documentation technique annexe IV-A, évaluation art. 25, déclaration UE de conformité art. 21, **marquage CE** art. 24 | **Non** — OASIS n'assure pas une fonction de sécurité au sens de l'art. 3(4) |
| **Quasi-machine** (art. 11) | EESS « pertinentes » seulement, **déclaration UE d'incorporation**, pas de marquage CE | Non — OASIS n'est pas un ensemble mécanique |
| **Sous-composant intégré** | **Aucune obligation propre au titre du règlement** | **Oui, aujourd'hui** |

Le règlement **n'organise pas** de chaîne d'obligations descendante vers les fournisseurs de
composants intégrés. Tout pèse sur le fabricant de la machine (art. 8 et 10). Les éléments
dont il a besoin pour démontrer 1.1.9 et 1.2.1 — identification des logiciels essentiels,
preuve d'intervention, journal 5 ans, et « le code source ou la logique de programmation […]
sur demande motivée » au titre de l'article 10(3) — doivent lui être fournis **par contrat**.

**C'est le modèle commercial que ce texte dicte** : OASIS ne se vend pas comme un produit
certifié, il se vend comme le **fournisseur de la preuve** qu'un fabricant devra produire aux
autorités, accompagné du droit contractuel d'accéder au code (la licence MIT le donne déjà).

Deux pièges à connaître : l'**article 17** requalifie en fabricant quiconque met un produit sur
le marché sous son nom ou le modifie au point d'affecter sa conformité ; l'**article 18** fait
de même pour une « modification substantielle » — livrer un logiciel qui change la sécurité
d'une machine déjà en service expose à cette requalification si l'intervention est la nôtre.

---

## 3. Annexe III 1.1.9 « Protection contre la corruption » — texte et correspondance

Texte verbatim (FR, consolidé ; identique au texte originel, aucun marqueur ►C1/▼M1/▼M2) :

> **1.1.9. Protection contre la corruption**
>
> La machine ou le produit connexe sont conçus et construits de telle sorte que le raccordement
> à ceux-ci d'un autre dispositif, par l'intermédiaire de toute caractéristique du dispositif
> connecté lui-même ou de tout dispositif distant qui communique avec la machine ou le produit
> connexe, ne crée pas de situation dangereuse.
>
> Un composant matériel informatique de transmission de signaux ou de données, pertinent pour
> le raccordement ou l'accès au logiciel qui est essentiel pour la conformité de la machine ou
> du produit connexe aux exigences essentielles de santé et de sécurité pertinentes, est conçu
> de manière à être protégé de manière adéquate contre la corruption accidentelle ou
> intentionnelle. La machine ou le produit connexe recueillent la preuve d'une intervention
> légitime ou illégitime dans ce composant matériel informatique, quand cela est pertinent pour
> la connexion ou l'accès à un logiciel essentiel pour la conformité de la machine ou du
> produit connexe.
>
> Les logiciels et les données essentiels pour la conformité de la machine ou du produit
> connexe aux exigences essentielles de santé et de sécurité pertinentes sont identifiés comme
> tels et sont protégés de manière adéquate contre la corruption accidentelle ou intentionnelle.
>
> La machine ou le produit connexe identifient les logiciels installés sur ceux-ci dont ils ont
> besoin pour fonctionner en toute sécurité, et ils sont en mesure de fournir ces informations
> à tout moment sous une forme aisément accessible.
>
> La machine ou le produit connexe recueillent la preuve d'une intervention légitime ou
> illégitime dans les logiciels ou d'une modification des logiciels installés sur ceux-ci ou de
> sa configuration.

Deux portées à retenir : (i) l'objet protégé est borné par la **sécurité machine** (« essentiel
pour la conformité […] aux EESS pertinentes »), pas par la sécurité de l'information en
général ; (ii) le texte dit « corruption accidentelle **ou intentionnelle** » — la menace
intentionnelle entre dans une exigence de santé et sécurité, ce qui est la nouveauté par
rapport à 2006/42/CE (voir considérant (25)).

Légende : ✅ prouvé sur silicium · 🟡 partiel · ❌ absent

| Alinéa | Exigence | OASIS aujourd'hui | Preuve | Ce qui manque |
|---|---|---|---|---|
| al. 1 | Le raccordement d'un dispositif, local ou distant, ne crée pas de situation dangereuse | 🟡 Un dispositif raccordé au bus mesh ne peut pas commander un actionneur : la porte d'actionnement exige **9** conditions ordonnées (7 à la rédaction de ce fichier), et un ordre non habilité, périmé, rejoué, hors limites ou NaN est refusé avant toute écriture | `evidence/silicon/2026-10-07/modbus/REPORT.md` : **12 refus de la porte** couvrant ses six raisons, 1 ordre malformé, et 3 injections brutes qui n'ont jamais atteint la porte — **0 octet** émis sur le bus de l'équipement ; `evidence/silicon/2026-10-06/ef/REPORT.md` | Ne vaut que si OASIS est **le seul chemin** vers l'actionneur. Un accès physique (BOOTSEL, SWD) contourne tout. Non démontré sur une machine réelle |
| al. 2 (1ʳᵉ phrase) | Le composant matériel de transmission est protégé contre la corruption accidentelle ou intentionnelle | 🟡 Les trames sont authentifiées de bout en bout, donc une corruption du médium est détectée ; le matériel lui-même n'est pas protégé | `evidence/silicon/2026-10-06/REPORT_MESH_V0B.md` : **0/150** inversions de bit acceptées (v0A : 12/50) | Aucune protection matérielle : pas d'élément sécurisé, clé lisible en flash |
| al. 2 (2ᵈᵉ phrase) | **Recueillir la preuve** d'une intervention, légitime ou illégitime, dans ce composant matériel | ❌ | — | Aucune détection d'intrusion matérielle, aucune trace |
| al. 3 | Les logiciels et données essentiels sont **identifiés comme tels** et protégés | 🟡 L'image est couverte par un condensé SHA-256 dans un manifeste signé ; un plancher anti-retour en arrière est persisté en flash sur deux emplacements | `evidence/silicon/2026-10-06/fwupdate/REPORT.md` : image altérée d'un octet → `HashMismatch` ; v1 ancienne → `Rollback` | L'**identification documentaire** (« identifiés comme tels ») n'existe pas : aucune liste des logiciels et données essentiels à la sécurité. Les clés privées sont lisibles en flash |
| al. 4 | La machine **identifie les logiciels installés** nécessaires à son fonctionnement sûr et fournit cette information **à tout moment sous une forme aisément accessible** | 🟡 La commande `@V` renvoie `version`, `floor`, état de démarrage, état du chargeur d'amorçage et empreinte du nœud | [`uart_mesh.rs:1317`](../../oasis-silicon-test/src/bin/uart_mesh.rs#L1317) ; `evidence/silicon/2026-10-06/fwupdate/REPORT.md` | `version` est une **constante de compilation**, pas un condensé mesuré de l'image en cours d'exécution ; accessible par USB seulement, pas par le mesh ; interface de test, non spécifiée comme interface produit |
| al. 5, 1ᵉʳ déclencheur | **Recueillir la preuve** d'une intervention, légitime ou illégitime, **dans les logiciels** | ✅ Journal en chaîne de hachages (partie I) : `h_n = SHA-256(DOMAIN‖h_{n−1}‖e_n)`, **toute** décision du chemin des commandes, acceptée *et refusée*, avec origine, `cmd_seq`, `boot_id` et drapeaux ; persisté entrée puis tête, vérifié depuis le PC par `oasis_journal_verify` recoupé contre une implémentation Python indépendante | `evidence/silicon/2026-10-08/hardening/` : journal relu de la flash **intact, exit 0** sur 10 entrées dont **4 refus** ; un bit inversé → exit 1 ; **S8, coupure d'alimentation réelle** — les entrées survivent et vérifient contre la tête capturée avant la coupure | Couvre le **chemin des commandes**, pas une intervention sur le logiciel par un autre moyen (BOOTSEL, SWD) |
| al. 5, 2ᵉ et 3ᵉ déclencheurs | **Recueillir la preuve** d'une **modification du logiciel installé** ou de **sa configuration** | ✅ `journal::ChangeKind` + `Journal::append_change` (2026-10-08) : installation de firmware, enrôlement, liste de révocation, élévation de politique, transfert de propriété — chacun sur **la même** chaîne de hachages, avec **qui l'a autorisé**, le numéro propre du changement (version installée, époque, `enroll_seq`, type de politique, compteur de transfert) et un bit **appliqué ou refusé** — un changement refusé est conservé, puisque la phrase dit « légitime **ou illégitime** ». Format d'entrée **inchangé** : rien de neuf à faire confiance | 6 tests + **6 harnais Kani vérifiés 6/6** (`evidence/kani/2026-10-08/journal-change/`, 2 contrôles négatifs en échec sur une propriété nommée, 0 `unwinding assertion`) ; câblé aux cinq sites réels du firmware, **+1 Kio de flash** | ⚠️ **Rien sur silicium** : le câblage compile mais aucune carte n'a été reflashée, donc la démonstration manque. La carte de registres Modbus reste **compilée**, donc son changement n'est pas un événement |

**Bilan 1.1.9, au 2026-10-09.** OASIS couvre la moitié « rejeter la corruption », et
désormais **la moitié « en garder la preuve » pour tout ce qui passe par le logiciel** :
les décisions (partie I) et, depuis le 2026-10-08, les **changements de logiciel et de
configuration** (alinéa 5, 2ᵈ et 3ᵉ déclencheurs).

**Ce qui reste absent, et pourquoi :**

- **Alinéa 2, 2ᵈᵉ phrase — la preuve d'une intervention dans le composant *matériel*.**
  Ne se ferme pas en logiciel : aucun programme ne détecte qu'on a branché BOOTSEL ou SWD.
  Il faut du matériel — élément sécurisé à broche d'alerte, contact de capot, boîtier
  tamper-respondent. OASIS fournit la **place** où ce signal devient une preuve
  infalsifiable (`ChangeKind::TamperSignal`, sur la même chaîne de hachages), et c'est la
  moitié « recueillir », pas la moitié « détecter ». Lié à **C14**.
- **Alinéa 3, l'identification documentaire : faite le 2026-10-09.**
  [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md) identifie les logiciels et données
  essentiels à la conformité — 25 chemins en cinq groupes (la décision d'agir,
  l'authenticité, la configuration d'autorité, ce qui atteint un équipement, la preuve),
  les huit données persistantes, **et ce qui est hors périmètre**. Chaque chemin est
  vérifié par `tools/check_claims.sh`, qui a trouvé une erreur dès son premier passage,
  donc la liste ne peut pas dériver en silence. ⚠️ « Essentiel à la conformité » reste un
  jugement : un fabricant doit le refaire pour sa machine, et la colonne « pourquoi »
  est là pour qu'il puisse le contester ligne à ligne.
- **Alinéa 4 : amélioré, pas fermé.** Depuis le 2026-10-09, l'entrée de journal d'une
  installation porte les **8 premiers octets du SHA-256 de l'image installée**, pris du
  condensé que `update::install` vérifiait déjà et jetait. La machine peut donc dire
  quels **octets** ont été installés, et plus seulement un numéro de version.
  ⚠️ Trois limites subsistent : c'est le condensé **vérifié à l'installation**, pas un
  condensé **mesuré maintenant** sur la flash, donc une réécriture par BOOTSEL ou SWD
  n'est pas détectée (c'est l'alinéa 2 et son matériel) ; `@V` renvoie toujours une
  `version` qui est une **constante de compilation** ; et tout cela n'est lisible que
  par **USB**, pas par le mesh. « À tout moment sous une forme aisément accessible »
  n'est donc pas satisfait.

**Ce qu'OASIS est, dit en une phrase :** il aide un fabricant à remplir 1.1.9 **sur le
chemin des commandes et sur les changements de configuration**. Il ne rend pas une machine
conforme à lui seul, il ne couvre pas le matériel, et trois des cinq alinéas gardent une
part non couverte.

---

## 4. Annexe III 1.2.1 « Sécurité et fiabilité des systèmes de commande »

Extraits verbatim utiles (FR, consolidé) :

> Les systèmes de commande sont conçus et construits de manière:
>
> a) à pouvoir résister, **lorsque les circonstances et les risques le justifient**, aux
> contraintes d'exploitation prévues et aux influences extérieures volontaires et
> involontaires, y compris **les tentatives malveillantes raisonnablement prévisibles de tiers
> conduisant à créer une situation dangereuse**;
>
> […] f) à ce que **le journal de suivi** des données générées dans le cadre d'une intervention
> et des versions des logiciels de sécurité téléchargés après la mise sur le marché ou la mise
> en service […] soit **activé pendant cinq ans** après ce téléchargement, exclusivement pour
> démontrer la conformité […] sur demande motivée d'une autorité nationale compétente.

> Une attention particulière est accordée aux points suivants: […]
> d) la machine ou le produit connexe **ne sont pas empêchés de s'arrêter** si l'ordre d'arrêt
> a déjà été donné; […]
> f) l'arrêt automatique ou manuel des éléments mobiles, quels qu'ils soient, **n'est pas
> empêché**;

> **Pour la commande sans fil, une défaillance de la communication ou de la connexion ou une
> connexion défectueuse n'entraîne pas de situation dangereuse.**

Deux lectures à ne pas rater :

- « **tiers** » (EN : *third parties*) exclut littéralement l'opérateur légitime de l'item a).
  Les dérives de l'opérateur sont traitées aux points e) (erreurs humaines) et d).
- La protection est due « **lorsque les circonstances et les risques le justifient** » : c'est
  un modèle de menace calibré par l'évaluation des risques du fabricant. Le règlement ne fixe
  **ni liste de menaces ni niveau de sécurité** — il n'existe pas d'équivalent du « SL »
  d'IEC 62443 dans le texte.

| Exigence | OASIS aujourd'hui | Preuve | Ce qui manque |
|---|---|---|---|
| al. 2 a) — résister aux **tentatives malveillantes raisonnablement prévisibles de tiers** | ✅ C'est le cœur d'OASIS, et la correspondance la plus forte de tout ce document. Trame liée au contenu, au compteur et au réseau ; rejeu refusé y compris après coupure de courant ; origine révoquée rejetée au premier saut ; déni de service par vérification forcée borné | `evidence/silicon/2026-10-06/REPORT_MESH_V0B.md` (0/150), `followup/` (mode strict 150/150, rejeu octet pour octet refusé après coupure), `ef/REPORT.md` (révocation), `evidence/silicon/2026-10-07/prefilter/REPORT.md` (179,4 ms → 0,70 ms par trame forgée ; 60/60 messages légitimes livrés à 19 % de charge contre 39/60 à 110 %) | Tiers **extérieur** et voisin **initié** testés ; pas d'attaquant physique, pas de radio réelle, deux nœuds sur un lien filaire |
| al. 2 b), c) — une défaillance ou une erreur de la logique de commande n'entraîne pas de situation dangereuse | 🟡 La règle d'actionnement est pure et prouvée formellement ; les parseurs ont été fuzzés | 196 harnais Kani (`grep -rE 'kani::proof' oasis-rt/src \| wc -l`). **175 des 182 d'alors vérifiés, 0 réfuté, 0 indéterminé**, un à la fois, dans le balayage séquentiel du 2026-10-08 (`evidence/kani/2026-10-08/sweep/`) ; le passage **parallèle** du 2026-10-07 (`evidence/kani/2026-10-07/full/`) avait donné 130 vérifiés, 10 indéterminés par manque de mémoire et 12 jamais atteints sur les 152 d'alors — l'OOM venait du parallélisme, pas des harnais. `kani_shards.sh --check` répartit les **196** en exactement un éclat chacun, donc la suite est exécutable en CI. 1,5 × 10⁹ exécutions de fuzzing (`evidence/fuzz/2026-10-07/`) | **Aucun passage sur les 196 d'un seul tenant, ni en CI ni en local**, donc « 196/196 » serait faux ; les **7 harnais lourds** ne sont pas tentés en local. Le reste du nœud n'est pas prouvé |
| al. 2 f) — **journal de suivi activé 5 ans** (interventions + versions de logiciel de sécurité téléchargées) | 🟡 **Partie I + journal des changements** (2026-10-08/09) : chaque décision, acceptée **et refusée**, et chaque modification de logiciel ou de configuration (installation de firmware avec sa **version et les 8 premiers octets du SHA-256 de l'image**, enrôlement, révocation, politique, propriété) entrent dans une chaîne de hachages persistée, relue par `oasis_journal_verify`. ⚠️ **La rétention de 5 ans n'est pas démontrée** : l'anneau n'a jamais bouclé dans un essai, sa capacité pour 5 ans n'est pas calculée, et aucun mécanisme de déchargement vers un stockage externe n'existe. C'est ce qui reste à faire sur cette ligne, et non la collecte. L'ancien texte ne citait que `FW_INSTALL` sur l'USB ; seul le plancher était persisté | `evidence/silicon/2026-10-06/fwupdate/REPORT.md` | **C5**, plus la persistance et la durée. Rien n'est conservé |
| al. 3 c) — « possible **à tout moment** de corriger la machine afin de préserver sa sécurité intrinsèque » | 🟡 Mise à jour A/B signée, sûre en cas de coupure, avec essai et retour automatique | `evidence/silicon/2026-10-06/fwupdate/REPORT.md` : coupure pendant le téléversement **et** pendant la bascule, image qui se bloque reprise par le chien de garde et **revenue en arrière** | Par USB seulement, pas par le mesh ; le chargeur d'amorçage n'est ni signé ni mettable à jour ; un défaut fonctionnel après confirmation n'est pas rattrapé |
| al. 4 d) et f) — la machine **n'est pas empêchée de s'arrêter** ; l'arrêt **n'est pas empêché** | ✅ **Fermé par la partie G** (2026-10-08). Un ordre porte une **classe signée** (`OAC1` octet 50) et `stop_decision` ne garde que **3 des 9 conditions** — authenticité, permission `STOP`, non-révocation — en abandonnant fraîcheur, verrou d'état des capteurs, limites et compteur de séquence ; pour le verrou des capteurs le sens est **inversé** (un capteur perdu est une raison de s'arrêter). Un arrêt **verrouille** (ISO 13850:2015 4.1.1.2) et seule une action locale le libère. `proof_stop_never_blocked` : aucune entrée ne peut bloquer un arrêt valide. Silicium 2026-10-08 : trois arrêts qui seraient chacun *refusés* comme des actes — `cmd_seq` périmé, `boot_id` antérieur, capteur perdu — tous **acceptés**. ⚠️ L'ancien texte de cette ligne était vrai avant la partie G et faux depuis : un ordre d'arrêt dont le compteur est en retard, ou dont l'origine vient d'être révoquée, est refusé | — | Politique asymétrique à spécifier : un ordre d'**arrêt** va dans le sens sûr et ne doit jamais être bloqué par une condition qui ne le concerne pas. Preuve Kani « aucune entrée ne peut empêcher un arrêt valide » |
| dernière phrase — **commande sans fil : une défaillance de communication n'entraîne pas de situation dangereuse** | ✅ **Fermé par la partie H** (2026-10-08). Une balise `OSB1` signée (kind 4 de l'enveloppe `OAU1`) est une **9e condition sur `Act` seulement**, bornée par `MAX_SUPERVISION_MS` = 5 min : supervision morte -> l'acte est refusé, **l'arrêt reste accepté**. Silicium 2026-10-08, et rejeu de balise comme balise d'un autre boot tous deux `applied=false`. ⚠️ Au SF12 le cycle de service EU868 n'autorise qu'environ 12 trames par heure, donc une supervision seconde par seconde est **impossible sur ce lien** — la borne de 5 min est un compromis, pas une préférence | — | C'est la phrase qui rend C2 **réglementaire** et non une simple préférence d'ingénieur. À traiter avec C2 |
| annexe III partie 3 — « **si la fonction de supervision n'est pas active, la machine ne peut pas fonctionner** » | ✅ **Fermé par la partie H** (C12, 2026-10-08) : l'autorisation d'agir est bien subordonnée à la vivacité du lien de supervision | — | Balise de supervision signée et périodique, dont l'absence retire l'autorisation. Proche de C2 et C4, mais distinct : c'est une condition de **présence**, pas de fraîcheur |
| annexe III partie 3 — « le système de commande assure **lui-même** les fonctions de sécurité, même sur ordre distant » | ➖ Confirme la frontière : la sûreté reste dans le système de commande de la machine. OASIS décide de l'**autorité** de l'ordre, pas de sa sûreté | — | Rien à faire côté OASIS ; à écrire noir sur blanc dans tout document d'acheteur |

---

## 5. Ce que ce texte change pour le positionnement

1. **Le déclencheur d'achat est daté : 20 janvier 2027**, et il porte sur les machines
   mobiles autonomes et les actionneurs industriels, pas sur les drones.
2. **La moitié manquante de 1.1.9 est un produit** : « recueillir la preuve d'une intervention
   légitime ou illégitime » plus l'inventaire logiciel interrogeable. C'est C5, et c'est exigé
   trois fois dans le texte (1.1.9 al. 2, al. 4, al. 5) puis une quatrième avec une durée de
   5 ans (1.2.1 al. 2 f)).
3. **C2 n'est pas optionnel** : « pour la commande sans fil, une défaillance de la communication
   […] n'entraîne pas de situation dangereuse » et « l'arrêt […] n'est pas empêché » sont dans
   le texte. Tant que la porte traite un ordre d'arrêt comme un ordre d'action, OASIS est
   *contraire* à 1.2.1 al. 4 d) et f) sur ce point précis.
4. **OASIS ne peut pas être vendu comme un composant de sécurité** (art. 3(3)) : il n'assure
   pas une fonction de sécurité. Il se vend comme fournisseur de preuve au fabricant.
5. **La seule voie de présomption qui cite 1.1.9 et 1.2.1 est l'article 20(9)**, via un schéma
   de certification de cybersécurité au titre du règlement (UE) 2019/881 — à instruire.

## 6. Limites de ce document

- Les points 1.1.9 et 1.2.1 ont été relevés sur EUR-Lex en comparant le texte originel
  (CELEX `32023R1230`) et le consolidé au 27/07/2026 : **identiques mot pour mot**.
- **Non vérifié à la source** : tout guide d'application de la Commission sur 1.1.9 ; le statut
  des UAS au regard de 2(2)(e) et (f) ; l'existence d'un acte d'exécution portant spécifications
  communes au titre de l'article 20(3) ; l'activation effective de l'article 20(9) par un
  schéma 2019/881 ; la demande de normalisation au CEN/CENELEC ; le contenu complet des
  règlements modificatifs (UE) 2024/2748 et (UE) 2026/1744 (seuls les passages insérés dans le
  consolidé ont été lus).
- EUR-Lex ne fournit pas d'ancre HTML par point d'annexe : la citation se fait par « annexe III,
  point 1.1.9 » + URL du document.
- Notes de recherche brutes, avec les verbatim EN et les considérants :
  `research_notes/Conformité réglementaire OASIS phase 0/machinery_regulation.md`.
