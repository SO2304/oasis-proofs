# Antériorité et datation — ce qui a été fait, ce qui reste à faire

> *Expurgé pour publication le 2026-10-23 / redacted for publication on 2026-10-23 : chemins de sources, identifiants internes et noms de harnais retirés ; résultats inchangés.*

**11 octobre 2026.** Objectif : pouvoir prouver plus tard que ce code, ces rapports et cette méthode existaient à cette
date et qui en est l'auteur. Aucun de ces mécanismes ne crée un droit ; ensemble, ils rendent une contestation
d'antériorité très difficile.

## Fait depuis la session (vérifiable dans le dépôt)

| Élément | Valeur |
|---|---|
| Tag annoté `v0-mit-final` | sur le commit `b89def8` (dernier commit sous MIT), objet tag `5e45efdb…`, daté 2026-10-11 05:06:50 UTC |
| Bundle git complet (`git bundle create --all`) | `oasis-v0-mit-final.bundle`, 7 230 167 octets |
| SHA-256 du bundle | `b4f8eaffef1fe3653d0e538ae5f3eb079894b636fcee6e4fc70cd20fdd9a02af` |
| Relicenciement | commit suivant : `LICENSE` = AGPL-3.0-or-later, 11 [withheld: build configuration] mis à jour, `RELICENSING.md`, `COPYRIGHT`, `COMMERCIAL-LICENSE.md`, `GOVERNANCE.md`, `SECURITY.md`, `CONTRIBUTING.md` |

Le bundle n'est pas dans le dépôt (il contient le dépôt). Il est dans l'espace de travail de la session et doit être
**copié par le propriétaire** sur un support hors ligne ; son SHA-256 ci-dessus est la valeur à déposer.

## Non fait, et pourquoi

| Élément | Raison | À faire par |
|---|---|---|
| Tag **signé** (GPG) | aucune clé de signature dans la session ; un tag annoté non signé prouve la date du dépôt distant, pas l'identité | le propriétaire : `git tag -s v0-mit-final-signed b89def8` avec sa clé, puis `git push --tags` |
| OpenTimestamps (`ots stamp`) | client absent et serveurs calendrier injoignables depuis la session | le propriétaire : `ots stamp oasis-v0-mit-final.bundle.sha256`, puis `ots upgrade` quelques heures après ; commiter le `.ots` dans `oasis-proofs` |
| **i-DEPOT** (BOIP, 37 €) | compte personnel « my BOIP » nécessaire | le propriétaire : déposer le bundle, les SHA256SUMS de `evidence/` et une déclaration d'auteur nominative ; noter le numéro ici |
| Nom du titulaire dans `COPYRIGHT` | le nom légal de la personne physique n'est pas connu de la session (seul l'identifiant GitHub l'est) | le propriétaire : remplacer le crochet dans `COPYRIGHT` |
| Vérification Software Heritage | archive.softwareheritage.org injoignable depuis la session | le propriétaire : rechercher `https://github.com/SO2304/oasis` ; si archivé, la copie MIT y est définitive |
| Statistiques de clonage GitHub | pas d'outil pour `traffic/clones` | le propriétaire : Insights → Traffic (14 jours glissants) |
| Marque Benelux | registre BOIP et EUIPO injoignables ; décision de nom à prendre | le propriétaire |

## Secrets dans l'historique

Scan du 11 octobre : aucune graine, clé privée ni configuration client trouvée dans l'historique (`our_seed`, `seed`,
`private_key`, fichiers `.seed`/`.pem`). Les configurations de campagne ne contiennent que des clés publiques et des
chemins de graines hors dépôt. Les fichiers `mesh/shared/*_fed.bin` (état de fédération du 5 octobre, baseline
`d8681c5`) sont dans l'historique, public jusqu'au 11 octobre 2026 ; s'ils contenaient une clé, elle est à considérer comme brûlée et à ne jamais
réutiliser.
