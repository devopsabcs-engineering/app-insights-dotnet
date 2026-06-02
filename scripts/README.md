# Local debug scripts

Helpers to launch the workshop demo apps locally without having to remember the dotnet flags.

| Script | Purpose |
| --- | --- |
| [start-local.ps1](start-local.ps1) | **Default:** builds and runs `Mapaq.Api` + `Mapaq.Web` as containers (`docker compose up --build -d`), polls the web app until it responds, then opens the browser. Pass `-NoContainer` for the classic `dotnet run` flow (two background pwsh windows on the https dev ports). Falls back to the dotnet flow automatically when Docker is unavailable. |
| [stop-local.ps1](stop-local.ps1) | Tears down the docker compose stack and stops any `Mapaq.Api` / `Mapaq.Web` `dotnet` processes started by `start-local.ps1`. |

## Quick start

```pwsh
pwsh ./scripts/start-local.ps1
```

Container defaults (root `compose.yaml`):

* `Mapaq.Web` — <http://localhost:5010>
* `Mapaq.Api` — <http://localhost:5020> (OpenAPI at `/openapi/v1.json`)

Prefer the classic `dotnet run` flow? Add `-NoContainer`:

```pwsh
pwsh ./scripts/start-local.ps1 -NoContainer
```

`-NoContainer` defaults (from the project `launchSettings.json`):

* `Mapaq.Web` — <https://localhost:7010>
* `Mapaq.Api` — <https://localhost:7020> (OpenAPI at `/openapi/v1.json`)

The API falls back to an in-memory EF Core database when no SQL connection string is supplied, so no Azure SQL or LocalDB is required for a smoke debug session.

## Wire up real telemetry (optional)

```pwsh
$cs = az monitor app-insights component show -g rg-workshop-dev -a appi-workshop-dev --query connectionString -o tsv
pwsh ./scripts/start-local.ps1 -NoContainer -ConnectionString $cs
```

This sets `APPLICATIONINSIGHTS_CONNECTION_STRING`, `ApplicationInsights__ConnectionString`, and `AzureMonitor__ConnectionString` for both processes so distributed traces land in your real App Insights resource. (`-ConnectionString` / `-SqlConnectionString` apply to the `-NoContainer` dotnet flow.)

## Wire up real Azure SQL (optional)

```pwsh
pwsh ./scripts/start-local.ps1 -NoContainer `
    -ConnectionString $cs `
    -SqlConnectionString 'Server=tcp:sql-workshop.database.windows.net;Database=mapaq;Authentication=Active Directory Default;Encrypt=True;'
```

## Stop

```pwsh
pwsh ./scripts/stop-local.ps1
```

Or close the spawned `Mapaq.Api` / `Mapaq.Web` pwsh windows (dotnet flow) / run `docker compose down` (container flow).
