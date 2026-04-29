# Boards seed -- semence des Boards Azure DevOps

> Bilingual README -- this folder turns the workshop's bilingual backlog
> defined in [`work-items.yaml`](work-items.yaml) into Azure DevOps Boards
> work items via [`seed-ado-boards.ps1`](seed-ado-boards.ps1).
>
> README bilingue -- ce dossier transforme le backlog bilingue de l'atelier
> defini dans [`work-items.yaml`](work-items.yaml) en éléments de travail
> Azure DevOps Boards via [`seed-ado-boards.ps1`](seed-ado-boards.ps1).

---

## FR -- Vue d'ensemble

Le dossier `boards/` est la source unique de vérité du backlog de l'atelier
MAPAQ App Insights .NET 10 :

- [`work-items.yaml`](work-items.yaml) déclare la hiérarchie
  `epics -> features -> stories -> tasks`.
- [`seed-ado-boards.ps1`](seed-ado-boards.ps1) lit le YAML et crée les
  éléments de travail dans Azure DevOps via `az boards`.
- Les titres sont rendus comme `<title_fr> -- <title_en>` (FR d'abord)
  conformément à la règle FR par défaut de l'atelier.

## EN -- Overview

The `boards/` folder is the single source of truth for the MAPAQ App
Insights .NET 10 workshop backlog:

- [`work-items.yaml`](work-items.yaml) declares the
  `epics -> features -> stories -> tasks` hierarchy.
- [`seed-ado-boards.ps1`](seed-ado-boards.ps1) reads the YAML and creates
  work items in Azure DevOps via `az boards`.
- Titles are rendered as `<title_fr> -- <title_en>` (FR first) per the
  workshop's FR-default rule.

---

## FR -- Prérequis

- PowerShell 7+ (`pwsh --version`).
- Module `powershell-yaml` (le script l'installe automatiquement pour
  l'utilisateur courant si absent).
- Azure CLI 2.60+ (`az version`).
- Extension Azure DevOps : `az extension add --name azure-devops`.
- Une session `az login` valide ou un PAT exporté via `$env:AZP_PAT`.

## EN -- Prerequisites

- PowerShell 7+ (`pwsh --version`).
- The `powershell-yaml` module (the script installs it for the current
  user if missing).
- Azure CLI 2.60+ (`az version`).
- Azure DevOps extension: `az extension add --name azure-devops`.
- A valid `az login` session or a PAT exported via `$env:AZP_PAT`.

---

## FR -- Exécution locale

Toujours commencer par un essai à blanc pour vérifier les commandes
planifiées sans appeler Azure DevOps :

```pwsh
pwsh boards/seed-ado-boards.ps1 `
  -Organization https://dev.azure.com/<org> `
  -Project <Projet> `
  -DryRun
```

Pour appliquer pour de vrai (omettre `-DryRun`) :

```pwsh
pwsh boards/seed-ado-boards.ps1 `
  -Organization https://dev.azure.com/<org> `
  -Project <Projet> `
  -Iteration "<Projet>\Iteration 1"
```

Pour pointer vers un autre fichier YAML :

```pwsh
pwsh boards/seed-ado-boards.ps1 `
  -Organization https://dev.azure.com/<org> `
  -Project <Projet> `
  -WorkItemsFile boards/work-items.yaml `
  -DryRun
```

## EN -- Local run

Always start with a dry run to inspect the planned commands without
calling Azure DevOps:

```pwsh
pwsh boards/seed-ado-boards.ps1 `
  -Organization https://dev.azure.com/<org> `
  -Project <Project> `
  -DryRun
```

To apply for real (drop `-DryRun`):

```pwsh
pwsh boards/seed-ado-boards.ps1 `
  -Organization https://dev.azure.com/<org> `
  -Project <Project> `
  -Iteration "<Project>\Iteration 1"
```

To point at a different YAML file:

```pwsh
pwsh boards/seed-ado-boards.ps1 `
  -Organization https://dev.azure.com/<org> `
  -Project <Project> `
  -WorkItemsFile boards/work-items.yaml `
  -DryRun
```

---

## FR -- Exécution depuis le workflow GitHub

Le workflow `.github/workflows/seed-ado-boards.yml` expose ce script
comme déclencheur manuel `workflow_dispatch`. Le job :

1. configure PowerShell 7 et l'extension `azure-devops`,
2. s'authentifie auprès d'Azure DevOps :
   - via un secret PAT GitHub (`AZP_PAT`) lorsqu'il est défini, ou
   - via la fédération d'identité de charge de travail (WIF / OIDC) avec
     `azure/login@v2`,
3. exécute `pwsh boards/seed-ado-boards.ps1` avec les paramètres saisis
   par l'utilisateur (`organization`, `project`, `iteration`, `dry_run`).

Le mode `dry_run: true` est par défaut pour empêcher les appels
involontaires sur le Boards de production.

## EN -- Run from the GitHub workflow

The `.github/workflows/seed-ado-boards.yml` workflow exposes this script
as a `workflow_dispatch` trigger. The job:

1. sets up PowerShell 7 and the `azure-devops` extension;
2. authenticates to Azure DevOps either:
   - with a GitHub PAT secret (`AZP_PAT`) when set, or
   - via Workload Identity Federation (WIF / OIDC) using
     `azure/login@v2`;
3. runs `pwsh boards/seed-ado-boards.ps1` with the user-supplied inputs
   (`organization`, `project`, `iteration`, `dry_run`).

The `dry_run: true` mode is the default to prevent accidental writes
into a production Boards instance.

---

## FR -- PAT contre WIF : compromis

| Critère                | PAT (`$env:AZP_PAT`)                                | WIF / OIDC (via `az login` ou `azure/login`) |
|------------------------|-----------------------------------------------------|-----------------------------------------------|
| Mise en place          | Simple : créer un PAT, le stocker en secret GitHub. | Plus complexe : configurer une federated credential et un service principal. |
| Rotation               | Manuelle ; expire au plus 1 an.                     | Automatique ; aucun secret de longue durée.   |
| Surface d'exposition   | Secret partagé, large portée si mal scopé.          | Aucun secret stocké côté GitHub.              |
| Audit                  | Lié à l'identité du créateur du PAT.                | Lié à l'identité fédérée et au workflow.      |
| Dev local              | Pratique pour itérer hors CI.                       | Possible via `az login` interactif.           |
| Recommandation         | À limiter aux ateliers ou à l'amorçage manuel.      | À privilégier en production CI/CD.            |

Le script `seed-ado-boards.ps1` détecte automatiquement `$env:AZP_PAT` ;
sinon il tombe sur le contexte `az login` courant.

## EN -- PAT vs WIF: trade-offs

| Criterion              | PAT (`$env:AZP_PAT`)                                  | WIF / OIDC (via `az login` or `azure/login`) |
|------------------------|-------------------------------------------------------|-----------------------------------------------|
| Setup                  | Simple: create a PAT, store as GitHub secret.         | More involved: configure a federated credential plus service principal. |
| Rotation               | Manual; expires within at most 1 year.                | Automatic; no long-lived secret.              |
| Exposure surface       | Shared secret, broad scope if poorly scoped.          | No stored secret on the GitHub side.          |
| Audit                  | Tied to the PAT creator's identity.                   | Tied to the federated identity and workflow.  |
| Local dev              | Convenient for iterating outside CI.                  | Possible through interactive `az login`.      |
| Recommendation         | Limit to workshops or manual bootstrap.               | Prefer for production CI/CD.                  |

The `seed-ado-boards.ps1` script automatically detects `$env:AZP_PAT`;
otherwise it falls back to the current `az login` context.

---

## FR -- Dépannage rapide

- `ConvertFrom-Yaml: The term 'ConvertFrom-Yaml' is not recognized` ->
  installer le module : `Install-Module powershell-yaml -Scope CurrentUser`.
- `az: 'boards' is not in the 'az' command group` ->
  ajouter l'extension : `az extension add --name azure-devops`.
- `TF400813 -- The user is not authorized` -> vérifier le PAT (portée
  *Work items: Read & write*) ou la federated credential.

## EN -- Quick troubleshooting

- `ConvertFrom-Yaml: The term 'ConvertFrom-Yaml' is not recognized` ->
  install the module: `Install-Module powershell-yaml -Scope CurrentUser`.
- `az: 'boards' is not in the 'az' command group` ->
  add the extension: `az extension add --name azure-devops`.
- `TF400813 -- The user is not authorized` -> check the PAT scope
  (*Work items: Read & write*) or the federated credential.
