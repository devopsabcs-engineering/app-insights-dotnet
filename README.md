<!-- markdownlint-disable MD013 MD033 MD041 -->
# App Insights .NET 10 — MAPAQ Workshop

A public bilingual (FR-primary / EN-parallel) 2-hour workshop demonstrating end-to-end Application Insights distributed tracing across **browser → ASP.NET Core 10 Razor Pages → Minimal API → Azure SQL**, themed around open data from the Ministère de l'Agriculture, des Pêcheries et de l'Alimentation du Québec (MAPAQ).

> **Workshop site (FR default):** <https://devopsabcs-engineering.github.io/app-insights-dotnet/fr/>
> **Workshop site (EN):** <https://devopsabcs-engineering.github.io/app-insights-dotnet/>

## What you'll build

* Two ASP.NET Core 10 Linux App Services (`Mapaq.Web` Razor Pages + `Mapaq.Api` Minimal API).
* An Azure SQL Database (serverless `GP_S_Gen5_1` with auto-pause, Entra-only auth).
* A workspace-based Application Insights resource that captures one distributed trace per UI click — browser pageView, server request, downstream API dependency, and SQL dependency all share a single `operation_Id`.

## Quick start

```pwsh
azd auth login
azd up
# play with the demo at the printed WEB_URI
azd down --purge --force
```

Cost target: **≤ $0.60 USD per attendee per 2-hour run** (B1 plan + serverless SQL with auto-pause).

## Repository navigation

| Area | EN | FR |
| --- | --- | --- |
| Workshop site (Jekyll) | [`labs/`](labs/) | [`fr/labs/`](fr/labs/) |
| Demo solution | [`src/`](src/) | — |
| Infrastructure | [`infra/`](infra/) | — |
| GitHub Actions | [`.github/workflows/`](.github/workflows/) | — |
| Azure DevOps Pipelines | [`azure-pipelines/`](azure-pipelines/) | — |
| ADO Boards seed | [`boards/`](boards/) | [`boards/README.md`](boards/README.md) |
| HTML + PPTX decks | [`docs/`](docs/) | [`docs/`](docs/) |
| Open-data snapshots | [`data/seed/`](data/seed/) | [`data/seed/`](data/seed/) |

## En français

Cet atelier public bilingue de 2 heures démontre la corrélation Application Insights de bout en bout entre le navigateur, ASP.NET Core 10 (Razor Pages), une API Minimal et Azure SQL, autour des données ouvertes du MAPAQ. La langue par défaut publiée est le français ; un commutateur permet de basculer en anglais.

* **Site de l'atelier (par défaut FR) :** <https://devopsabcs-engineering.github.io/app-insights-dotnet/fr/>
* **Démarrage rapide :** `azd up` puis `azd down --purge --force` (cible de coût ≤ 0,60 $ US par participant).
* **Modules :** `fr/labs/lab-00-installation` à `fr/labs/lab-06-demantelement`.

## License

[MIT](LICENSE)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
