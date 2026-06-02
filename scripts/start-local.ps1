<#
.SYNOPSIS
    Starts Mapaq.Api and Mapaq.Web locally for debugging.

.DESCRIPTION
    By default this builds and runs both apps as containers via
    `docker compose up --build` (detached), waits for the web tier to answer,
    then opens the browser. Pass -NoContainer to use the classic `dotnet run`
    flow instead (two background pwsh windows on the https dev ports). If Docker
    is not available, the script automatically falls back to the -NoContainer
    dotnet flow.

    Container defaults (root compose.yaml):
        Mapaq.Web  http://localhost:5010
        Mapaq.Api  http://localhost:5020

    -NoContainer (dotnet run) defaults (matching launchSettings.json):
        Mapaq.Api  https://localhost:7020   http://localhost:5020
        Mapaq.Web  https://localhost:7010   http://localhost:5010

    The API falls back to an in-memory EF Core database when ConnectionStrings:MapaqSql
    is empty (see src/Mapaq.Api/Program.cs), so no SQL Server is required for a smoke
    debug session.

.PARAMETER ConnectionString
    Optional Application Insights connection string. When supplied, sets
    APPLICATIONINSIGHTS_CONNECTION_STRING for both processes so end-to-end
    correlation flows to a real App Insights resource. When omitted, the script
    auto-resolves it from the azd environment (APPINSIGHTS_CONNECTION_STRING
    output) so telemetry still reaches the cloud. If neither is available, the
    apps use the placeholder in appsettings.json (telemetry is exported but
    lands in a non-existent ingestion endpoint and is silently dropped).

.PARAMETER SqlConnectionString
    Optional SQL Server connection string. When supplied, sets
    ConnectionStrings__MapaqSql so EF Core uses the real database.

.PARAMETER NoBuild
    Skip the initial dotnet build.

.PARAMETER NoBrowser
    Do not open the default browser to the web URL after the apps boot.

.PARAMETER Container
    (Default behavior — retained for explicitness/back-compat.) Run both apps as
    containers via `docker compose up --build` (uses the root compose.yaml and the
    per-app Dockerfiles). Web -> API is reached over the compose network on port 8080.

.PARAMETER NoContainer
    Use the classic `dotnet run` flow (two background pwsh windows on the https dev
    ports) instead of containers. This is what the test-runner scripts use so they
    do not require a Docker daemon.

.PARAMETER PushToAcr
    Build and push both images to Azure Container Registry using `az acr build`
    (server-side build; no Docker daemon and no `docker login` required). Requires
    -AcrName and an active `az login`. This is passwordless and reuses the same
    mechanism as the CI/CD pipelines.

.PARAMETER AcrName
    Target Azure Container Registry name (without the .azurecr.io suffix). Required
    when -PushToAcr is set.

.PARAMETER ImageTag
    Optional image tag for -PushToAcr. Defaults to the short git SHA, falling back
    to 'local' when git is unavailable.

.EXAMPLE
    pwsh ./scripts/start-local.ps1
    # Default: builds + runs containers (docker compose), then opens the browser.

.EXAMPLE
    pwsh ./scripts/start-local.ps1 -NoContainer
    # Classic dotnet run flow on https://localhost:7010 / 7020.

.EXAMPLE
    $env:AI_CS = (az monitor app-insights component show -g rg-workshop -a appi-workshop --query connectionString -o tsv)
    pwsh ./scripts/start-local.ps1 -NoContainer -ConnectionString $env:AI_CS

.EXAMPLE
    pwsh ./scripts/start-local.ps1 -PushToAcr -AcrName acrworkshop123
#>
[CmdletBinding()]
param(
    [string]$ConnectionString,
    [string]$SqlConnectionString,
    [switch]$NoBuild,
    [switch]$NoBrowser,
    [switch]$SkipDevCertTrust,
    [switch]$Container,
    [switch]$NoContainer,
    [switch]$PushToAcr,
    [string]$AcrName,
    [string]$ImageTag
)

$ErrorActionPreference = 'Stop'

# Resolve repo root from the script's own location so this works from any cwd.
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

# --- Container path (DEFAULT) and other short-circuits before the dotnet run flow ---

# -PushToAcr: build + push both images to ACR with `az acr build` (passwordless,
# server-side, no Docker daemon and no `docker login`).
if ($PushToAcr) {
    if (-not $AcrName) {
        throw "-PushToAcr requires -AcrName <registry-name> (without the .azurecr.io suffix)."
    }

    $tag = $ImageTag
    if (-not $tag) {
        $tag = (& git rev-parse --short HEAD 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tag)) { $tag = 'local' }
    }
    $tag = $tag.Trim()

    Write-Host "Building and pushing images to ACR '$AcrName' with tag '$tag' (az acr build)..." -ForegroundColor Cyan

    & az acr build --registry $AcrName --image "mapaq-api:$tag" --file src/Mapaq.Api/Dockerfile .
    if ($LASTEXITCODE -ne 0) { throw "az acr build failed for mapaq-api (exit $LASTEXITCODE)" }

    & az acr build --registry $AcrName --image "mapaq-web:$tag" --file src/Mapaq.Web/Dockerfile .
    if ($LASTEXITCODE -ne 0) { throw "az acr build failed for mapaq-web (exit $LASTEXITCODE)" }

    Write-Host "Pushed:" -ForegroundColor Green
    Write-Host "  $AcrName.azurecr.io/mapaq-api:$tag"
    Write-Host "  $AcrName.azurecr.io/mapaq-web:$tag"
    return
}

# --- Resolve the Application Insights connection string so telemetry reaches the
# cloud. When -ConnectionString is not supplied, read the deployed resource's
# connection string from the azd environment (APPINSIGHTS_CONNECTION_STRING output).
# Without this the apps fall back to the placeholder in appsettings.json and
# telemetry is silently dropped at a non-existent ingestion endpoint.
if (-not $ConnectionString) {
    if (Get-Command azd -ErrorAction SilentlyContinue) {
        Write-Host "Resolving Application Insights connection string from azd environment..." -ForegroundColor Cyan
        $resolvedCs = (& azd env get-value APPINSIGHTS_CONNECTION_STRING 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($resolvedCs) `
                -and $resolvedCs -notmatch '^ERROR' `
                -and $resolvedCs -notlike '*00000000-0000-0000-0000-000000000000*') {
            $ConnectionString = $resolvedCs.Trim()
            Write-Host "Using Application Insights connection string from azd (telemetry -> cloud)." -ForegroundColor Green
        }
    }
    if (-not $ConnectionString) {
        Write-Warning "No Application Insights connection string resolved; telemetry will use the appsettings.json placeholder and be dropped. Pass -ConnectionString or run 'azd up' first to log to the cloud."
    }
}

# Decide whether to use the container flow. Containers are the default; -NoContainer
# opts into the classic dotnet run flow. If Docker is unavailable we transparently
# fall back to the dotnet flow so the script still works on machines without Docker.
$useContainers = -not $NoContainer
if ($useContainers) {
    $dockerAvailable = [bool](Get-Command docker -ErrorAction SilentlyContinue)
    if (-not $dockerAvailable) {
        Write-Warning "Docker not found on PATH; falling back to the -NoContainer (dotnet run) flow. Install Docker Desktop to use the default container flow."
        $useContainers = $false
    }
}

# -Container (now the default): build + run both apps via docker compose, detached,
# then health-gate the web tier so this returns non-blocking (mirrors the dotnet flow).
if ($useContainers) {
    $composeFile = Join-Path $RepoRoot 'compose.yaml'
    if (-not (Test-Path $composeFile)) { throw "Cannot find $composeFile" }

    # Forward the connection string into compose; both services read it via
    # ${APPLICATIONINSIGHTS_CONNECTION_STRING} substitution in compose.yaml so
    # container telemetry flows to the real App Insights resource.
    if ($ConnectionString) {
        $env:APPLICATIONINSIGHTS_CONNECTION_STRING = $ConnectionString
    }

    $WebUrl = 'http://localhost:5010'
    $ApiUrl = 'http://localhost:5020'

    Write-Host "Building and starting Mapaq via docker compose (build + up -d)..." -ForegroundColor Cyan
    if ($NoBuild) {
        & docker compose -f $composeFile up -d
    } else {
        & docker compose -f $composeFile up --build -d
    }
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed (exit $LASTEXITCODE)" }

    Write-Host ""
    Write-Host "Waiting for Mapaq.Web to come online at $WebUrl ..." -ForegroundColor Cyan
    $deadline = (Get-Date).AddSeconds(90)
    $ready = $false
    do {
        Start-Sleep -Seconds 2
        try {
            $resp = Invoke-WebRequest -Uri "$WebUrl/" -TimeoutSec 3 -ErrorAction Stop
            if ($resp.StatusCode -eq 200) { $ready = $true; break }
        } catch {
            # not ready yet
        }
    } while ((Get-Date) -lt $deadline)

    if ($ready) {
        Write-Host "READY (containers):" -ForegroundColor Green
        Write-Host "  Mapaq.Web    -> $WebUrl"
        Write-Host "  Mapaq.Api    -> $ApiUrl"
        Write-Host "  Swagger UI   -> $ApiUrl/swagger"
        Write-Host "  OpenAPI JSON -> $ApiUrl/openapi/v1.json"
        if (-not $NoBrowser) {
            Start-Process $WebUrl | Out-Null
        }
    } else {
        Write-Warning "Mapaq.Web did not respond within 90s. Check 'docker compose logs' for build/runtime errors."
    }

    Write-Host ""
    Write-Host "View logs:   docker compose -f compose.yaml logs -f" -ForegroundColor Yellow
    Write-Host "Stop:        pwsh ./scripts/stop-local.ps1   (or docker compose -f compose.yaml down)" -ForegroundColor Yellow
    return
}

# --- Classic flow (-NoContainer): run both apps with `dotnet run` ---

$ApiProject = Join-Path $RepoRoot 'src/Mapaq.Api/Mapaq.Api.csproj'
$WebProject = Join-Path $RepoRoot 'src/Mapaq.Web/Mapaq.Web.csproj'
$ApiUrl     = 'https://localhost:7020'
$WebUrl     = 'https://localhost:7010'

if (-not (Test-Path $ApiProject)) { throw "Cannot find $ApiProject" }
if (-not (Test-Path $WebProject)) { throw "Cannot find $WebProject" }

# Always stop any prior Mapaq.Api / Mapaq.Web instances before restart so the
# .dll lock from the previous run does not block the build.
$stopScript = Join-Path $PSScriptRoot 'stop-local.ps1'
if (Test-Path $stopScript) {
    Write-Host "Stopping any existing Mapaq processes..." -ForegroundColor Cyan
    & $stopScript
    # Give the OS a moment to release file handles on bin/Debug/*.dll.
    Start-Sleep -Milliseconds 500
}

# Ensure ASP.NET Core dev cert is present and trusted, otherwise the typed
# HttpClient in Mapaq.Web fails with UntrustedRoot when calling Mapaq.Api on
# https://localhost:7020. `--check --trust` exits non-zero when action is
# needed; `--trust` then installs and trusts the cert (may prompt UAC).
if (-not $SkipDevCertTrust) {
    Write-Host "Checking ASP.NET Core dev certificate..." -ForegroundColor Cyan
    & dotnet dev-certs https --check --trust *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Trusting ASP.NET Core dev certificate (may prompt UAC)..." -ForegroundColor Yellow
        & dotnet dev-certs https --trust
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "dotnet dev-certs https --trust returned $LASTEXITCODE. Web -> API HTTPS calls may fail with UntrustedRoot."
        }
    } else {
        Write-Host "Dev certificate already trusted." -ForegroundColor Green
    }
}

# Create empty wwwroot folders so the StaticFileMiddleware does not warn at
# startup. They are intentionally empty for the workshop demo (no bundled
# static assets); add CSS / JS here as the labs progress.
foreach ($wwwroot in @(
    (Join-Path $RepoRoot 'src/Mapaq.Web/wwwroot'),
    (Join-Path $RepoRoot 'src/Mapaq.Api/wwwroot'))) {
    if (-not (Test-Path $wwwroot)) {
        New-Item -ItemType Directory -Path $wwwroot -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $wwwroot '.gitkeep') -Force | Out-Null
    }
}

if (-not $NoBuild) {
    Write-Host "Building solution..." -ForegroundColor Cyan
    dotnet build "$RepoRoot/Mapaq.sln" --nologo -v minimal
    if ($LASTEXITCODE -ne 0) { throw "dotnet build failed (exit $LASTEXITCODE)" }
}

# Build per-process environment via a hashtable expanded into the spawned shell.
$envCommon = @{
    ASPNETCORE_ENVIRONMENT = 'Development'
}
if ($ConnectionString) {
    $envCommon['APPLICATIONINSIGHTS_CONNECTION_STRING'] = $ConnectionString
    $envCommon['ApplicationInsights__ConnectionString'] = $ConnectionString
    $envCommon['AzureMonitor__ConnectionString']        = $ConnectionString
}

$envApi = @{} + $envCommon
if ($SqlConnectionString) {
    $envApi['ConnectionStrings__MapaqSql'] = $SqlConnectionString
}

$envWeb = @{} + $envCommon
$envWeb['MapaqApi__BaseAddress'] = "$ApiUrl/"

function Start-DotnetProcess {
    param(
        [string]$Title,
        [string]$Project,
        [hashtable]$EnvVars
    )

    # Build a small bootstrap that sets env vars, then runs dotnet run.
    $sb = [System.Text.StringBuilder]::new()
    foreach ($k in $EnvVars.Keys) {
        $v = $EnvVars[$k] -replace "'", "''"
        [void]$sb.AppendLine("`$env:$k = '$v'")
    }
    [void]$sb.AppendLine("`$Host.UI.RawUI.WindowTitle = '$Title'")
    [void]$sb.AppendLine("Set-Location '$RepoRoot'")
    [void]$sb.AppendLine("dotnet run --project '$Project' --no-build --launch-profile (Split-Path -Leaf (Split-Path -Parent '$Project'))")

    $bootstrap = $sb.ToString()
    $tmp = Join-Path $env:TEMP ("mapaq-start-{0}.ps1" -f ($Title -replace '\W','-'))
    Set-Content -LiteralPath $tmp -Value $bootstrap -Encoding UTF8

    Write-Host "Starting $Title..." -ForegroundColor Green
    Start-Process pwsh -ArgumentList @('-NoExit', '-NoProfile', '-File', $tmp) | Out-Null
}

Start-DotnetProcess -Title 'Mapaq.Api'  -Project $ApiProject -EnvVars $envApi
Start-Sleep -Seconds 2
Start-DotnetProcess -Title 'Mapaq.Web' -Project $WebProject -EnvVars $envWeb

Write-Host ""
Write-Host "Waiting for Mapaq.Web to come online at $WebUrl ..." -ForegroundColor Cyan
$deadline = (Get-Date).AddSeconds(60)
$ready = $false
do {
    Start-Sleep -Seconds 2
    try {
        # Ignore self-signed cert during dev.
        $resp = Invoke-WebRequest -Uri "$WebUrl/" -SkipCertificateCheck -TimeoutSec 3 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) { $ready = $true; break }
    } catch {
        # not ready yet
    }
} while ((Get-Date) -lt $deadline)

if ($ready) {
    Write-Host "READY:" -ForegroundColor Green
    Write-Host "  Mapaq.Web    -> $WebUrl"
    Write-Host "  Mapaq.Api    -> $ApiUrl"
    Write-Host "  Swagger UI   -> $ApiUrl/swagger"
    Write-Host "  OpenAPI JSON -> $ApiUrl/openapi/v1.json"
    if (-not $NoBrowser) {
        Start-Process $WebUrl | Out-Null
    }
}
else {
    Write-Warning "Mapaq.Web did not respond within 60s. Check the spawned windows for build/runtime errors."
}

Write-Host ""
Write-Host "Stop both processes:    pwsh ./scripts/stop-local.ps1" -ForegroundColor Yellow
Write-Host "(or close the spawned 'Mapaq.Api' and 'Mapaq.Web' pwsh windows)" -ForegroundColor DarkGray
