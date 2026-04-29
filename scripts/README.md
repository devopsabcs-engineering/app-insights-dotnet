# Local debug scripts

Helpers to launch the workshop demo apps locally without having to remember the dotnet flags.

| Script | Purpose |
| --- | --- |
| [start-local.ps1](start-local.ps1) | Builds the solution, starts `Mapaq.Api` and `Mapaq.Web` in two background pwsh windows, polls the web app until it responds, then opens the browser. |
| [stop-local.ps1](stop-local.ps1) | Stops any running `Mapaq.Api` / `Mapaq.Web` `dotnet` processes started by `start-local.ps1`. |

## Quick start

```pwsh
pwsh ./scripts/start-local.ps1
```

Defaults (from the project `launchSettings.json`):

* `Mapaq.Web` — <https://localhost:7010>
* `Mapaq.Api` — <https://localhost:7020> (OpenAPI at `/openapi/v1.json`)

The API falls back to an in-memory EF Core database when no SQL connection string is supplied, so no Azure SQL or LocalDB is required for a smoke debug session.

## Wire up real telemetry (optional)

```pwsh
$cs = az monitor app-insights component show -g rg-workshop-dev -a appi-workshop-dev --query connectionString -o tsv
pwsh ./scripts/start-local.ps1 -ConnectionString $cs
```

This sets `APPLICATIONINSIGHTS_CONNECTION_STRING`, `ApplicationInsights__ConnectionString`, and `AzureMonitor__ConnectionString` for both processes so distributed traces land in your real App Insights resource.

## Wire up real Azure SQL (optional)

```pwsh
pwsh ./scripts/start-local.ps1 `
    -ConnectionString $cs `
    -SqlConnectionString 'Server=tcp:sql-workshop.database.windows.net;Database=mapaq;Authentication=Active Directory Default;Encrypt=True;'
```

## Stop

```pwsh
pwsh ./scripts/stop-local.ps1
```

Or close the spawned `Mapaq.Api` / `Mapaq.Web` pwsh windows directly.
