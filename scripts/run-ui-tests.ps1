<#
.SYNOPSIS
    Run the Mapaq Playwright UI tests against a local or remote Mapaq.Web.

.DESCRIPTION
    Provisions the Playwright project under tests/ui/ (npm install + browser
    install — both idempotent), optionally auto-starts Mapaq.Api / Mapaq.Web
    via scripts/start-local.ps1 when the target is localhost and the web tier
    is unreachable, then runs `npx playwright test`.

    Outputs:
        tests/ui/playwright-report/index.html   — HTML report
        tests/ui/test-results/junit.xml         — JUnit XML for CI surfaces
        tests/ui/screenshots/*.png              — deterministic per-test screenshots
        tests/ui/test-results/raw/              — traces / videos for failures

.PARAMETER WebUrl
    Base URL the Razor pages are served from. Defaults to https://localhost:7010.
    Pass an https://*.azurewebsites.net URL to test the deployed app.

.PARAMETER Headed
    Run Chromium in headed mode so you can watch the browser drive the page.

.PARAMETER UI
    Launch Playwright's interactive UI mode (`npx playwright test --ui`).
    Mutually exclusive with -Headed.

.PARAMETER Grep
    Pattern forwarded to Playwright's --grep flag (e.g. -Grep "Detail").

.PARAMETER Reinstall
    Force `npm install` and `npx playwright install` to run even when the
    cache appears warm. Use after upgrading the @playwright/test version.

.PARAMETER SkipAutoStart
    Do not auto-start Mapaq.Web when the target is localhost and unreachable.

.EXAMPLE
    pwsh ./scripts/run-ui-tests.ps1
    # Default: https://localhost:7010, headless, all tests

.EXAMPLE
    pwsh ./scripts/run-ui-tests.ps1 -Headed -Grep Rollup
    # Watch the rollup tests run in a real browser

.EXAMPLE
    pwsh ./scripts/run-ui-tests.ps1 -WebUrl https://mapaq-web-xxxxx.azurewebsites.net
    # Drive the deployed environment
#>
[CmdletBinding()]
param(
    [string]$WebUrl = 'https://localhost:7010',
    [switch]$Headed,
    [switch]$UI,
    [string]$Grep,
    [switch]$Reinstall,
    [switch]$SkipAutoStart
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$UiDir    = Join-Path $RepoRoot 'tests/ui'
if (-not (Test-Path (Join-Path $UiDir 'playwright.config.ts'))) {
    throw "Playwright config not found at $UiDir/playwright.config.ts"
}

# ---------------------------------------------------------------------------
# 1) Verify Node.js is available.
# ---------------------------------------------------------------------------
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    throw "Node.js is required to run Playwright. Install Node 20+ from https://nodejs.org/ and re-run."
}
$nodeVersion = (& node --version).Trim()
Write-Host "Using Node $nodeVersion" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 2) npm install (idempotent — npm itself short-circuits when up-to-date).
# ---------------------------------------------------------------------------
Push-Location $UiDir
try {
    if ($Reinstall -or -not (Test-Path (Join-Path $UiDir 'node_modules/@playwright/test'))) {
        Write-Host "Installing npm dependencies (this can take a minute on first run)..." -ForegroundColor Cyan
        & npm install --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)." }
    } else {
        Write-Host "npm dependencies already installed (pass -Reinstall to refresh)." -ForegroundColor DarkGray
    }

    # `npx playwright install` is the official way to fetch matching browser binaries.
    # It is a no-op once the cache (per @playwright/test version) is warm.
    Write-Host "Ensuring Playwright browsers are installed..." -ForegroundColor Cyan
    & npx --no-install playwright install chromium
    if ($LASTEXITCODE -ne 0) { throw "playwright install failed (exit $LASTEXITCODE)." }

    # ---------------------------------------------------------------------------
    # 3) Auto-start local apps when targeting localhost and the web tier is down.
    # ---------------------------------------------------------------------------
    function Test-WebUp {
        param([string]$Url)
        try {
            $r = Invoke-WebRequest -Uri "$Url/" -SkipCertificateCheck -TimeoutSec 3 -ErrorAction Stop
            return $r.StatusCode -eq 200
        } catch { return $false }
    }

    $isLocalhost = ([Uri]$WebUrl).Host -in @('localhost', '127.0.0.1', '::1')
    if ($isLocalhost -and -not $SkipAutoStart -and -not (Test-WebUp -Url $WebUrl)) {
        $startScript = Join-Path $RepoRoot 'scripts/start-local.ps1'
        if (Test-Path $startScript) {
            Write-Host "Mapaq.Web not detected on $WebUrl. Starting local apps..." -ForegroundColor Yellow
            & $startScript -NoBrowser
            $deadline = (Get-Date).AddSeconds(60)
            while ((Get-Date) -lt $deadline -and -not (Test-WebUp -Url $WebUrl)) {
                Start-Sleep -Seconds 2
            }
            if (-not (Test-WebUp -Url $WebUrl)) {
                Write-Warning "Mapaq.Web still not responding. Continuing — Playwright will surface the failures."
            }
        } else {
            Write-Warning "$startScript not found; cannot auto-start. Run it manually then retry."
        }
    } elseif (Test-WebUp -Url $WebUrl) {
        Write-Host "Target $WebUrl reachable." -ForegroundColor Green
    }

    # ---------------------------------------------------------------------------
    # 4) Run Playwright.
    # ---------------------------------------------------------------------------
    $env:MAPAQ_WEB_URL = $WebUrl

    $playwrightArgs = @('--no-install', 'playwright', 'test')
    if ($UI)     { $playwrightArgs += '--ui' }
    if ($Headed) { $playwrightArgs += '--headed' }
    if ($Grep)   { $playwrightArgs += @('--grep', $Grep) }

    Write-Host ""
    Write-Host "Running Playwright against $WebUrl" -ForegroundColor Green
    Write-Host "  args: $($playwrightArgs -join ' ')" -ForegroundColor DarkGray
    Write-Host ""

    & npx @playwrightArgs
    $exit = $LASTEXITCODE

    Write-Host ""
    $reportPath = Join-Path $UiDir 'playwright-report/index.html'
    if (Test-Path $reportPath) {
        Write-Host "HTML report: $reportPath" -ForegroundColor Cyan
        if ($exit -ne 0 -and -not $UI) {
            Write-Host "Open the HTML report:    npx playwright show-report" -ForegroundColor Yellow
        }
    }
    $screenshotDir = Join-Path $UiDir 'screenshots'
    if (Test-Path $screenshotDir) {
        $count = (Get-ChildItem -Path $screenshotDir -Filter '*.png' -ErrorAction SilentlyContinue).Count
        Write-Host "Screenshots ($count): $screenshotDir" -ForegroundColor Cyan
    }

    exit $exit
}
finally {
    Pop-Location
}
