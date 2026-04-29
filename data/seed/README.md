# MAPAQ workshop seed data — `data/seed/`

## Français (FR — primaire)

Cet atelier livre **un échantillon représentatif** des données ouvertes
publiées par le Ministère de l'Agriculture, des Pêcheries et de
l'Alimentation du Québec (MAPAQ) sur **Données Québec**. Les fichiers de
référence intégrale comptent plus de 16 000 lignes — bien trop pour un
atelier de quelques heures. Les CSV ci-dessous sont **fictifs mais
réalistes** ; ils respectent la structure des jeux de données réels et
permettent de jouer chaque scénario hors-ligne.

### Provenance des jeux de données réels

Tous les jeux sont sous licence **Attribution (CC-BY 4.0)**, langue `fr`,
géographie `quebec_canada`. Les `resource_id` ci-dessous ont été vérifiés
le **2026-04-29**.

| Fichier d'échantillon | Jeu de données Données Québec | resource_id | Lignes (réelles) |
|---|---|---|---|
| `condamnations.csv` (10 lignes fictives) | [Condamnations des établissements alimentaires](https://www.donneesquebec.ca/recherche/dataset/condamnations-des-etablissements-alimentaires-et-condamnations-concernant-le-bien-etre-des-anim) | `40105615-3abf-414b-bcba-182e8f2c5eb2` | 2 936 |
| `inspections-cumulatif.csv` (10 lignes fictives) | [Activités d'inspection des aliments — vente au détail et restauration](https://www.donneesquebec.ca/recherche/dataset/rapport-cumulatif-inspection-aliments-csv) | `3e7a2432-b533-4e8c-8ac0-143643412e5a` | 13 238 |
| `suspensions-schema.csv` (en-tête seul) | [Suspensions de permis ou des opérations](https://www.donneesquebec.ca/recherche/dataset/suspension-permis) | `cffa7c37-09ed-44c6-a7d3-94ae3c1680b3` | 0 (fenêtre glissante de 30 jours) |

### Pourquoi des échantillons et non l'instantané complet ?

- L'atelier doit démarrer en **moins d'une minute** sur un poste
  hors-ligne ; télécharger 16 000+ lignes via CKAN au démarrage casse
  cette promesse.
- Les **traces distribuées** d'Application Insights restent identiques
  sur 10 ou 16 000 lignes — le jeu suffit pour démontrer browser → API
  → SQL → CKAN.
- Le bouton **`POST /api/sync`** appelle quand même la véritable API
  CKAN (résidu réel d'observabilité) ; c'est le seul appel sortant
  visible dans la carte d'application.

### Mention de droits

> Les données réelles citées ci-dessus sont publiées sous licence
> **Attribution (CC-BY 4.0)**. Les fichiers d'échantillon livrés ici
> sont **fictifs** et ne reflètent ni un établissement ni une infraction
> réelle. Toute ressemblance avec un cas réel est fortuite.

---

## English (EN — secondary)

This workshop ships **a representative sample** of the open data
published by the Quebec Ministry of Agriculture, Fisheries and Food
(MAPAQ) on **Données Québec**. The full snapshots are 16 000+ rows —
far too large for a 2-hour workshop. The CSVs below are **fictional but
realistic** and mirror the schema of the live datasets so each lab
scenario can run offline.

### Provenance of the live datasets

All datasets are licensed **Attribution (CC-BY 4.0)**, language `fr`,
geography `quebec_canada`. The `resource_id`s below were verified on
**2026-04-29**.

| Sample file | Données Québec dataset | resource_id | Rows (live) |
|---|---|---|---|
| `condamnations.csv` (10 fictional rows) | [Convictions of food establishments](https://www.donneesquebec.ca/recherche/dataset/condamnations-des-etablissements-alimentaires-et-condamnations-concernant-le-bien-etre-des-anim) | `40105615-3abf-414b-bcba-182e8f2c5eb2` | 2 936 |
| `inspections-cumulatif.csv` (10 fictional rows) | [Food-inspection activities — retail and foodservice](https://www.donneesquebec.ca/recherche/dataset/rapport-cumulatif-inspection-aliments-csv) | `3e7a2432-b533-4e8c-8ac0-143643412e5a` | 13 238 |
| `suspensions-schema.csv` (header only) | [Permit or operations suspensions](https://www.donneesquebec.ca/recherche/dataset/suspension-permis) | `cffa7c37-09ed-44c6-a7d3-94ae3c1680b3` | 0 (rolling 30-day window) |

### Why samples instead of full snapshots?

- The workshop must boot in **under a minute** offline; pulling 16 000+
  rows from CKAN on startup breaks that promise.
- The **distributed traces** in Application Insights look identical at
  10 or 16 000 rows — the sample is enough to demonstrate browser → API
  → SQL → CKAN.
- The **`POST /api/sync`** button still calls the real CKAN API, which
  is the one outbound dependency visible in the Application Map.

### Attribution

> The live datasets referenced above are published under **Attribution
> (CC-BY 4.0)**. The sample files shipped here are **fictional** and do
> not reflect any actual establishment or offence. Any resemblance to
> real-world cases is coincidental.
