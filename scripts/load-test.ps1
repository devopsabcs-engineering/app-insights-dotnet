<#
.SYNOPSIS
    One-liner load test for Mapaq. Zero arguments required.

.DESCRIPTION
    Wraps scripts/run-load-test.ps1 with sensible defaults so a workshop
    attendee can stress the locally running Mapaq.Api / Mapaq.Web with a
    single command:

        pwsh ./scripts/load-test.ps1

    What it does:
        1. Verifies the local apps are running on https://localhost:7020 and
           https://localhost:7010 (and starts them with start-local.ps1 if not).
        2. Runs Locust headless for 2 minutes with 25 virtual users against
           the API (https://localhost:7020).
        3. Opens the resulting HTML report in your default browser.

    Pass -WebUi to instead open the interactive Locust dashboard.
    Pass -SkipAutoStart to skip the auto-start of Mapaq.Api / Mapaq.Web.

.EXAMPLE
    pwsh ./scripts/load-test.ps1
    # Just runs everything. No knobs, no thinking.

.EXAMPLE
    pwsh ./scripts/load-test.ps1 -WebUi
    # Opens http://localhost:8089 instead of running headless.
#>
[CmdletBinding()]
param(
    [switch]$WebUi,
    [switch]$SkipAutoStart
)

$ErrorActionPreference = 'Stop'

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$RunScript  = Join-Path $PSScriptRoot 'run-load-test.ps1'
$StartLocal = Join-Path $PSScriptRoot 'start-local.ps1'

if (-not (Test-Path $RunScript)) { throw "Missing $RunScript" }

$ApiUrl = 'https://localhost:7020'

function Test-MapaqUp {
    try {
        $r = Invoke-WebRequest -Uri "$ApiUrl/healthz" -SkipCertificateCheck -TimeoutSec 2 -ErrorAction Stop
        return $r.StatusCode -eq 200
    } catch {
        return $false
    }
}

if (-not $SkipAutoStart -and -not (Test-MapaqUp)) {
    if (Test-Path $StartLocal) {
        Write-Host "Mapaq.Api not detected on $ApiUrl. Starting local apps..." -ForegroundColor Yellow
        & $StartLocal -NoBrowser
        # start-local.ps1 already polls until the web tier is online, but the
        # API itself may take an extra moment after that — short retry here.
        $deadline = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $deadline -and -not (Test-MapaqUp)) {
            Start-Sleep -Seconds 2
        }
        if (-not (Test-MapaqUp)) {
            Write-Warning "Mapaq.Api still not responding. Continuing anyway — Locust will surface the failure."
        }
    } else {
        Write-Warning "$StartLocal not found. Skipping auto-start."
    }
}

# Hand off to the full runner with simple, fixed defaults.
$forwarded = @{
    TargetUrl = $ApiUrl
    Users     = 25
    SpawnRate = 5
    Duration  = '2m'
}
if ($WebUi) { $forwarded['WebUi'] = $true }

& $RunScript @forwarded
$exit = $LASTEXITCODE

# Auto-open the HTML report on success when running headless.
if (-not $WebUi -and $exit -eq 0) {
    $latest = Get-ChildItem -Path (Join-Path $RepoRoot 'tests/load/reports') -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latest) {
        $html = Join-Path $latest.FullName 'report.html'
        if (Test-Path $html) {
            Write-Host "Opening report in browser: $html" -ForegroundColor Cyan
            Start-Process $html | Out-Null
        }
    }
}

exit $exit
