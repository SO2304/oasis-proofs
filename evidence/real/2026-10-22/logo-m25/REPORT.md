# L'essai, dit dans le vocabulaire de l'examinateur : GS-IFA-M25 sur le LOGO! réel

> *Expurgé pour publication le 2026-10-23 / redacted for publication on 2026-10-23 : chemins de sources, identifiants internes et noms de harnais retirés ; résultats inchangés.*

**2026-10-22.** Les campagnes précédentes prouvaient de bonnes choses sans répondre à une seule
question d'un examinateur. Celle-ci ne prouve **rien de nouveau sur le produit** : elle produit la
même preuve, sur le même automate, **critère par critère** dans la notation du référentiel qui sert
à examiner l'annexe III 1.1.9 — et elle est conçue pour échouer là où OASIS échoue.

## 1. Le référentiel, et pourquoi c'est celui-là

**`GS-IFA-M25`**, « Grundsätze für die Prüfung und Zertifizierung des Schutzes vor Korrumpierung »,
DGUV Test / IFA, Stand 07-2026. Il traduit l'annexe III 1.1.9 du règlement (UE) 2023/1230 en
**66 critères testables T01–T66**, dont **quinze (T31–T45) portent sur la journalisation**, et il
s'applique « als **Teilprüfung** bei einer EU-Baumusterprüfung ». Il est public et gratuit.
⚠️ **Aucune marque de contrôle n'est délivrée** pour ce volet, et **EN 50742 n'est pas publiée** :
il n'existe donc aujourd'hui aucune présomption de conformité, par aucune voie.

Le texte des critères cités ici vient du PDF, extrait en texte dans `GS-IFA-M25_extrait.txt`.
⚠️ Les verdicts ci-dessous sont **les nôtres**, pas ceux d'un organisme. Personne n'a examiné OASIS.

La notation est celle du document : **E** = *entfällt* (sans objet), **J** = *ja*, **N** = *nein*.

## 2. Le montage

Siemens **LOGO! 230RCE** de série, port Modbus 510, registre 100, **aucun relais commandé**. La
vérité terrain est la valeur relue dans l'automate par un client Modbus **indépendant et en lecture
seule** ; rien n'est écrit en direct, sinon l'essai ne mesurerait plus OASIS. Trois passages
(`run2/`, `run3/`, `run4/`) — les verdicts sont **identiques aux trois**, à l'empreinte près.

## 3. Résultat : 15 J, 4 N, 0 contrôle imprévu, et 22 critères sur 22 ont un verdict

| Critère | Question du référentiel | Verdict |
|---|---|---|
| T31 | moyens numériques de traçabilité des interventions | **J** journal chaîné par hachage |
| T37 | le lieu de stockage est-il documenté ? | **J** annoncé au démarrage, fichiers sur l'hôte |
| T35 | la collecte est-elle **automatique, sans intervention de l'utilisateur** ? (*Eingriffsversuch*) | **J** 0 → 1 entrée sur une tentative, sans aucune action |
| T38a | intervention légitime exécutée | **J** valeur portée par l'automate |
| T38 | au moins la dernière entrée **pour chaque type** d'intervention | **J** `Act`, `OutOfLimits`, `NotAuthorized`, `NotVerified` |
| T38 *(Change)* | entrées de changement de configuration | **E** démontré ailleurs (`evidence/pilot/2026-10-09`, C15–C17), pas ici |
| T33 | les preuves sont-elles **lisibles et accessibles** ? (*Zugriffsversuch*) | **J** un outil indépendant lit et rend un verdict |
| T47 | lisibles par un humain ? | **J** une ligne en clair par décision |
| T45 | *Art des Eingriffs* | **J** classe de l'ordre et décision |
| T45 | *laufende Nummer* | **J** `seq`, et un trou donne `SeqGap` |
| T45 | *Boot-Zähler* | **J** `boot_id` |
| T45 | version logicielle et configuration dans l'entrée | **N** § 4 |
| T45 | horodatage en temps système | **E** § 4 |
| T42 | protégés contre une manipulation **ciblée** ? (*Versuch der Manipulation*) | **J** un refus réécrit en acceptation → la vérification échoue |
| T36 | la collecte est-elle protégée contre la **désactivation** ? | **N** § 4 |
| T44 | un **effacement** crée-t-il une entrée sur cet effacement ? | **N** § 4 |
| T46 | configuration fournie sur demande | **J** cible, unité, nombre de registres, lieu du journal |
| T46 | version logicielle fournie sur demande | **N** § 4 |
| T48 | algorithmes conformes à BSI TR-02102-1 | **E** vérification documentaire, pas un essai de banc |

## 4. Les quatre échecs, et c'est le résultat le plus utile de cet essai

Le référentiel **demande** qu'on les déclare : T27, T28, T30 et T34 obligent le fabricant à
documenter ce qui n'a pas pu être fait et pourquoi. Un essai qui ne montre que ce qui marche ne sert
à rien dans un dossier technique.

| | Ce que l'essai constate | Ce qu'il faudrait |
|---|---|---|
| **T36** | Omettre `--journal` démarre la passerelle, qui **écoute et sert**, décisions en RAM seulement et perdues à l'arrêt. Elle avertit sur la sortie d'erreur, et c'est tout. Un examinateur qui tente la désactivation **réussit** | refuser de servir sans journal — changement de comportement, à décider |
| **T44** | Une purge supprime les fichiers et compte sur la sortie standard. **Rien n'entre dans la chaîne** : aucune nature d'enregistrement ne décrit l'effacement d'un journal | une variante `ChangeKind` et une entrée à la purge — additif, mais touche une constante que des harnais Kani lisent |
| **T45** *(version)* | Une entrée porte le type, le numéro d'ordre, le compteur de démarrage et l'origine. Elle ne porte **ni version logicielle ni configuration** | les joindre à l'entrée, ou à l'en-tête de la chaîne |
| **T46** *(version)* | **Aucune version n'est annoncée par le binaire.** Elle n'existe qu'au dehors, dans l'empreinte git et les `SHA256SUMS` du dépôt — ce qui ne répond ni à T46 ni à T03 (identification du logiciel par un condensé) | l'afficher au démarrage : le moins cher des quatre, purement additif |

Aucun n'est corrigé à la date de ce rapport. Les corriger avant de mesurer aurait inversé l'ordre.

## 5. Ce que cet essai ne montre pas

- **Les verdicts sont les nôtres.** Aucun organisme n'a examiné OASIS, et aucune marque de contrôle
  n'existe pour ce volet.
- **Les 44 autres critères sont documentaires** : analyse de risques ISO 12100, *threat assessment*,
  contexte de sécurité, notice d'utilisation, détermination du SRSL par interface. Un banc n'y
  répond pas ; ils relèvent du dossier, et plusieurs sont **à produire par le client**.
- **T45, horodatage** : il n'y a pas de temps système dans une entrée. T45 cite le numéro d'ordre et
  le compteur de démarrage parmi les moyens de corrélation, et les deux sont présents — mais c'est à
  l'organisme de dire si cela suffit, pas à nous. Classé **E** et non **J** pour cette raison.
- **T42 vaut contre un attaquant distant.** Un accès local réécrit entrées et tête ensemble ; la
  parade documentée est le témoin hors hôte ([withheld: off-host witness tool]).
- Un module logique, pas un S7-1200/1500 ; un registre ; mémoire seule ; topologie T2.

## 6. Trois défauts de mon propre harnais, trouvés au premier passage

Ils sont consignés parce qu'ils étaient tous du même genre — un contrôle qui passe pour une raison
étrangère à ce qu'il mesure — et parce que deux d'entre eux donnaient un **faux succès** sur
exactement les critères que le produit échoue :

1. **T36 a d'abord répondu J.** La passerelle lancée sans journal était morte — mais parce que le
   port était déjà pris par celle du début de l'essai. Un échec de démarrage se lisait comme un
   refus de servir. Corrigé : port distinct, et l'essai vérifie que l'écoute a bien été établie
   avant de juger.
2. **T46 (version) a d'abord répondu J.** Le motif cherchait un numéro « x.y.z » et a reconnu une
   version dans **`127.0.0.1`**. Corrigé : seul un mot-clé explicite compte.
3. **T35 a disparu sans verdict.** Ma fonction de comptage rendait deux lignes, l'arithmétique a
   échoué, et le total est sorti quand même — un critère sans verdict se lit comme une absence
   d'objection. Corrigé, et l'essai **compare désormais la liste des critères attendus à celle des
   verdicts écrits** et refuse de conclure s'il en manque un.

Les trois passages archivés sont postérieurs aux correctifs. Le premier passage n'est pas archivé :
il ne mesurait pas ce qu'il annonçait.

## 7. Le harnais d'essai n'est pas publié : ce corpus porte les **résultats**, pas la méthode. Chaque
passage archive ici sa trace complète, ses journaux de décisions et le verdict rendu par le
vérificateur indépendant, de sorte qu'un lecteur contrôle les conclusions sans exécuter quoi que ce
soit. `SHA256SUMS` couvre tous les fichiers présents.

Chaque passage écrit `verdicts.tsv` : critère, verdict, intitulé, pièce.
