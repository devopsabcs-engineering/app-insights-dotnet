<#
.SYNOPSIS
    Starts Mapaq.Api and Mapaq.Web locally for debugging.

.DESCRIPTION
    Launches both projects in parallel (each in its own pwsh window so logs are
    independent), wires their App Insights connection strings if you supply one,
    and tails any log output back to this terminal. Stop with Ctrl+C in each
    spawned window, or call .\scripts\stop-local.ps1.

    Defaults (matching launchSettings.json):
        Mapaq.Api  https://localhost:7020   http://localhost:5020
        Mapaq.Web  https://localhost:7010   http://localhost:5010

    The API falls back to an in-memory EF Core database when ConnectionStrings:MapaqSql
    is empty (see src/Mapaq.Api/Program.cs), so no SQL Server is required for a smoke
    debug session.

.PARAMETER ConnectionString
    Optional Application Insights connection string. When supplied, sets
    APPLICATIONINSIGHTS_CONNECTION_STRING for both processes so end-to-end
    correlation flows to a real App Insights resource. When omitted, the apps
    use the placeholder in appsettings.json (telemetry is exported but lands in
    a non-existent ingestion endpoint and is silently dropped).

.PARAMETER SqlConnectionString
    Optional SQL Server connection string. When supplied, sets
    ConnectionStrings__MapaqSql so EF Core uses the real database.

.PARAMETER NoBuild
    Skip the initial dotnet build.

.PARAMETER NoBrowser
    Do not open the default browser to the web URL after the apps boot.

.EXAMPLE
    pwsh ./scripts/start-local.ps1

.EXAMPLE
    $env:AI_CS = (az monitor app-insights component show -g rg-workshop -a appi-workshop --query connectionString -o tsv)
    pwsh ./scripts/start-local.ps1 -ConnectionString $env:AI_CS
#>
[CmdletBinding()]
param(
    [string]$ConnectionString,
    [string]$SqlConnectionString,
    [switch]$NoBuild,
    [switch]$NoBrowser,
    [switch]$SkipDevCertTrust
)

$ErrorActionPreference = 'Stop'

# Resolve repo root from the script's own location so this works from any cwd.
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

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
