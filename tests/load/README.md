# Mapaq Load Tests (Locust)

End-to-end load test for the workshop apps `Mapaq.Api` and `Mapaq.Web`,
written with [Locust](https://locust.io). Designed to drive enough realistic
traffic to populate the Application Insights dashboards built in lab 05
(failures, dependencies, performance, live metrics).

## Quick start

From the repo root:

```pwsh
pwsh ./scripts/load-test.ps1
```

That single command:

1. Auto-starts `Mapaq.Api` + `Mapaq.Web` if they are not already running.
2. Creates a Python virtual environment under `.venv-loadtest/` and installs Locust.
3. Runs Locust headless for **2 minutes with 25 virtual users** against `https://localhost:7020`.
4. Opens the HTML report in your default browser.

## More control

```pwsh
# Open the interactive Locust dashboard at http://localhost:8089
pwsh ./scripts/load-test.ps1 -WebUi

# Full set of knobs (target URL, users, spawn rate, duration, web UI, etc.)
pwsh ./scripts/run-load-test.ps1 -TargetUrl https://localhost:7010 -Users 50 -Duration 5m
```

## Running against Azure

Once the apps are deployed, point at the public hostnames and re-enable
TLS verification:

```pwsh
pwsh ./scripts/run-load-test.ps1 `
    -TargetUrl https://app-mapaq-api-<suffix>.azurewebsites.net `
    -Users 100 -SpawnRate 10 -Duration 10m -VerifySsl
```

## What is exercised

The locust file (`locustfile.py`) defines two user classes:

| Class | Weight | Purpose |
|-------|--------|---------|
| `MapaqApiUser` | 6 | Hits the API directly: search, drill-down, rollup, healthz |
| `MapaqWebUser` | 4 | Hits the Razor Pages, which fan out to the API server-side |

Mixing the two means a single run produces:

* HTTP server spans on `Mapaq.Web`
* HTTP client spans on `Mapaq.Web` calling `Mapaq.Api`
* HTTP server spans on `Mapaq.Api`
* SQL spans on the EF Core `MapaqDbContext`

…which is exactly the topology surfaced by the Application Map in lab 05.

The `POST /api/sync` endpoint targets the public CKAN service at
[donneesquebec.ca](https://www.donneesquebec.ca) and is **disabled by default**
(weight=0) so we don't hammer a public API. Bump its weight in `locustfile.py`
when you specifically want to exercise it.

## Reports

Headless runs write a timestamped folder under `tests/load/reports/`:

```text
tests/load/reports/20260430-141233/
    report.html          # Locust HTML report
    stats_stats.csv
    stats_stats_history.csv
    stats_failures.csv
    stats_exceptions.csv
```

The folder is git-ignored. Delete it freely.
