<#
.SYNOPSIS
    Run the Mapaq Locust load tests against a local or remote Mapaq.Api / Mapaq.Web.

.DESCRIPTION
    Provisions an isolated Python virtual environment under .venv-loadtest at the
    repo root, installs Locust into it (idempotent — only when missing), then
    launches the load test defined in tests/load/locustfile.py.

    Defaults to "headless" mode so the script is runnable end-to-end with no
    interactive flags. Use -WebUi to instead open the Locust dashboard at
    http://localhost:8089 and drive the run from the browser.

    Reports are written to tests/load/reports/<timestamp>/ when running headless:
        report.html        — Locust HTML report
        stats.csv          — per-endpoint stats
        stats_history.csv  — time-series stats
        failures.csv       — failure log
        exceptions.csv     — Python exceptions raised in the test

.PARAMETER TargetUrl
    Base URL to load test. Defaults to https://localhost:7020 (Mapaq.Api).
    Pass https://localhost:7010 to drive the Razor pages instead, or an
    https://*.azurewebsites.net URL to load test the deployed app.

    The two Locust user classes still each pin to their own tier (see
    -ApiUrl / -WebUrl) so a single run exercises both /api/... and the
    Razor pages.

.PARAMETER ApiUrl
    Base URL the MapaqApiUser Locust class will hit. Defaults to
    https://localhost:7020. Override when load testing a deployed API.

.PARAMETER WebUrl
    Base URL the MapaqWebUser Locust class will hit. Defaults to
    https://localhost:7010. Override when load testing a deployed Web.

.PARAMETER Users
    Peak number of concurrent virtual users (Locust --users). Default: 25.

.PARAMETER SpawnRate
    Users to spawn per second until the peak is reached (Locust --spawn-rate).
    Default: 5.

.PARAMETER Duration
    Total run time in Locust duration syntax (e.g. 30s, 2m, 1h). Default: 2m.
    Ignored when -WebUi is set.

.PARAMETER WebUi
    Launch Locust with its web UI on http://localhost:8089 instead of headless.

.PARAMETER VerifySsl
    Validate TLS certificates on the target. Default is to skip validation
    so the dev cert on https://localhost works out of the box. Always pass
    -VerifySsl when targeting a real Azure environment.

.PARAMETER ReportDir
    Override the directory used to write the headless reports.

.PARAMETER Recreate
    Delete and rebuild the virtual environment from scratch before running.

.PARAMETER SkipAutoStart
    When the target is a localhost URL, this script automatically launches
    Mapaq.Api / Mapaq.Web via scripts/start-local.ps1 if /healthz is not
    reachable. Pass -SkipAutoStart to disable that behaviour.

.EXAMPLE
    pwsh ./scripts/run-load-test.ps1
    # 25 users, 2 minutes, headless, against https://localhost:7020

.EXAMPLE
    pwsh ./scripts/run-load-test.ps1 -TargetUrl https://localhost:7010 -Users 50 -Duration 5m
    # Drive the Razor pages tier with 50 users for 5 minutes

.EXAMPLE
    pwsh ./scripts/run-load-test.ps1 -WebUi
    # Open http://localhost:8089 and drive the run interactively
#>
[CmdletBinding()]
param(
    [string]$TargetUrl    = 'https://localhost:7020',
    [string]$ApiUrl       = 'https://localhost:7020',
    [string]$WebUrl       = 'https://localhost:7010',
    [int]   $Users        = 25,
    [int]   $SpawnRate    = 5,
    [string]$Duration     = '2m',
    [switch]$WebUi,
    [switch]$VerifySsl,
    [string]$ReportDir,
    [switch]$Recreate,
    [switch]$SkipAutoStart
)

$ErrorActionPreference = 'Stop'

# Resolve the repo root from the script's own location so any cwd works.
$RepoRoot   = Split-Path -Parent $PSScriptRoot
$LoadDir    = Join-Path $RepoRoot 'tests/load'
$LocustFile = Join-Path $LoadDir 'locustfile.py'
$Reqs       = Join-Path $LoadDir 'requirements.txt'
$VenvDir    = Join-Path $RepoRoot '.venv-loadtest'

if (-not (Test-Path $LocustFile)) { throw "Locust file not found at $LocustFile" }
if (-not (Test-Path $Reqs))       { throw "Requirements file not found at $Reqs" }

# ---------------------------------------------------------------------------
# 1) Locate Python (>=3.10 recommended for current Locust).
# ---------------------------------------------------------------------------
function Resolve-PythonInvocation {
    foreach ($candidate in @(@('py', '-3'), @('python'), @('python3'))) {
        $cmd = Get-Command $candidate[0] -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        try {
            $extra = @()
            if ($candidate.Length -gt 1) { $extra = $candidate[1..($candidate.Length - 1)] }
            $checkArgs = @() + $extra + @('-c', 'import sys;print(sys.version_info[0])')
            $version = & $candidate[0] @checkArgs 2>$null
            if ($LASTEXITCODE -eq 0 -and "$version".Trim() -eq '3') {
                # Use the unary comma operator so PowerShell does NOT unwrap a
                # single-element array into a bare string when returning.
                return ,$candidate
            }
        } catch { }
    }
    throw "Python 3 not found on PATH. Install from https://www.python.org/downloads/ and re-run."
}

$pythonInvocation = Resolve-PythonInvocation
# Defensive: if a caller's PowerShell host still unwrapped, coerce back to array.
if ($pythonInvocation -isnot [System.Array]) {
    $pythonInvocation = @($pythonInvocation)
}
$pythonExe   = $pythonInvocation[0]
$pythonExtra = @()
if ($pythonInvocation.Count -gt 1) {
    $pythonExtra = @($pythonInvocation[1..($pythonInvocation.Count - 1)])
}
Write-Host "Using Python: $($pythonInvocation -join ' ')" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 2) Create / reuse the virtual env.
# ---------------------------------------------------------------------------
if ($Recreate -and (Test-Path $VenvDir)) {
    Write-Host "Removing existing virtual environment $VenvDir..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $VenvDir
}

if (-not (Test-Path $VenvDir)) {
    Write-Host "Creating virtual environment at $VenvDir..." -ForegroundColor Cyan
    $createArgs = @() + $pythonExtra + @('-m', 'venv', $VenvDir)
    & $pythonExe @createArgs
    if ($LASTEXITCODE -ne 0) { throw "Failed to create virtualenv (exit $LASTEXITCODE)." }
}

# Path to the venv's python and locust executables (Windows uses Scripts/, *nix uses bin/).
$VenvPython = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    Join-Path $VenvDir 'Scripts/python.exe'
} else {
    Join-Path $VenvDir 'bin/python'
}
$VenvLocust = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    Join-Path $VenvDir 'Scripts/locust.exe'
} else {
    Join-Path $VenvDir 'bin/locust'
}

if (-not (Test-Path $VenvPython)) {
    throw "Virtual env python not found at $VenvPython"
}

# ---------------------------------------------------------------------------
# 3) Install / refresh Locust + workshop deps. Always run pip so edits to
#    requirements.txt are picked up; pip is a no-op when everything is current.
# ---------------------------------------------------------------------------
Write-Host "Ensuring Python dependencies are installed (pip install -r requirements.txt)..." -ForegroundColor Cyan
& $VenvPython -m pip install --upgrade pip --quiet
if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed (exit $LASTEXITCODE)." }
& $VenvPython -m pip install -r $Reqs --quiet
if ($LASTEXITCODE -ne 0) { throw "pip install failed (exit $LASTEXITCODE)." }

if (-not (Test-Path $VenvLocust)) {
    throw "locust executable still missing at $VenvLocust after pip install. Re-run with -Recreate."
}

# ---------------------------------------------------------------------------
# 4) Pre-flight: probe /healthz, and auto-start local apps when targeting
#    localhost so the run is not just a giant pile of ConnectionRefused.
# ---------------------------------------------------------------------------
function Test-TargetUp {
    param([string]$Url)
    try {
        $r = Invoke-WebRequest -Uri "$Url/healthz" -SkipCertificateCheck -TimeoutSec 3 -ErrorAction Stop
        return $r.StatusCode -eq 200
    } catch {
        return $false
    }
}

$targetUp     = Test-TargetUp -Url $TargetUrl
$isLocalhost  = ([Uri]$TargetUrl).Host -in @('localhost', '127.0.0.1', '::1')

if ($targetUp) {
    Write-Host "Target /healthz responded: 200" -ForegroundColor Green
} elseif ($isLocalhost -and -not $SkipAutoStart) {
    $startScript = Join-Path $PSScriptRoot 'start-local.ps1'
    if (Test-Path $startScript) {
        Write-Host "Target $TargetUrl not responding. Starting Mapaq.Api / Mapaq.Web via start-local.ps1..." -ForegroundColor Yellow
        & $startScript -NoBrowser
        $deadline = (Get-Date).AddSeconds(60)
        while ((Get-Date) -lt $deadline -and -not (Test-TargetUp -Url $TargetUrl)) {
            Start-Sleep -Seconds 2
        }
        if (Test-TargetUp -Url $TargetUrl) {
            Write-Host "Target /healthz responded: 200" -ForegroundColor Green
        } else {
            Write-Warning "Mapaq.Api still not responding on $TargetUrl. Continuing — Locust will surface the failures."
        }
    } else {
        Write-Warning "$startScript not found; cannot auto-start. Run it manually then retry."
    }
} else {
    Write-Warning "Could not reach $TargetUrl/healthz. Locust will retry once the run starts."
    if ($isLocalhost) {
        Write-Warning "Tip: start the apps locally with  pwsh ./scripts/start-local.ps1  (or omit -SkipAutoStart)."
    }
}

# ---------------------------------------------------------------------------
# 5) Build the Locust command line.
# ---------------------------------------------------------------------------
# Scope SSL verification through an env var consumed by locustfile.py.
$env:LOCUST_VERIFY_SSL = if ($VerifySsl) { '1' } else { '0' }

# Per-tier host overrides so MapaqApiUser and MapaqWebUser each hit the right
# port even though --host can only carry one value. We deliberately do NOT
# pass --host to Locust because its runner unconditionally overwrites every
# user class's .host attribute with environment.host when --host is set
# (see locust/runners.py: `user_class.host = self.environment.host`).
$env:MAPAQ_API_HOST = $ApiUrl
$env:MAPAQ_WEB_HOST = $WebUrl
Write-Host "  api host -> $ApiUrl" -ForegroundColor DarkGray
Write-Host "  web host -> $WebUrl" -ForegroundColor DarkGray

$locustArgs = @(
    '-f', $LocustFile,
    '--users', $Users,
    '--spawn-rate', $SpawnRate
)

if ($WebUi) {
    Write-Host ""
    Write-Host "Starting Locust web UI at http://localhost:8089 ..." -ForegroundColor Green
    Write-Host "  api -> $ApiUrl" -ForegroundColor Green
    Write-Host "  web -> $WebUrl" -ForegroundColor Green
    Write-Host "Open http://localhost:8089 in a browser, then click 'Start swarming'." -ForegroundColor Green
    Write-Host "Press Ctrl+C in this window to stop."                     -ForegroundColor DarkGray
    Write-Host ""
    & $VenvLocust @locustArgs
    exit $LASTEXITCODE
}

# Headless run: build a timestamped report folder.
if (-not $ReportDir) {
    $stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
    $ReportDir = Join-Path $LoadDir "reports/$stamp"
}
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null

$htmlReport = Join-Path $ReportDir 'report.html'
$csvPrefix  = Join-Path $ReportDir 'stats'

$locustArgs += @(
    '--headless',
    '--run-time', $Duration,
    '--html',     $htmlReport,
    '--csv',      $csvPrefix,
    '--only-summary'
)

Write-Host ""
Write-Host "Running Locust headless" -ForegroundColor Green
Write-Host "  api -> $ApiUrl" -ForegroundColor Green
Write-Host "  web -> $WebUrl" -ForegroundColor Green
Write-Host "  users=$Users spawn-rate=$SpawnRate duration=$Duration" -ForegroundColor Green
Write-Host "  reports -> $ReportDir" -ForegroundColor Green
Write-Host ""

& $VenvLocust @locustArgs
$exit = $LASTEXITCODE

Write-Host ""
if ($exit -eq 0) {
    Write-Host "Load test complete. Open the HTML report:" -ForegroundColor Green
    Write-Host "  $htmlReport" -ForegroundColor Cyan
} else {
    Write-Warning "Locust exited with code $exit. Inspect $ReportDir for details."
}

exit $exit
