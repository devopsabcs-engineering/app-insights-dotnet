<#
.SYNOPSIS
    Opens the live Application Insights monitoring dashboard for the MAPAQ
    workshop directly in the Azure portal.

.DESCRIPTION
    Resolves the Application Insights component inside a resource group
    dynamically (no hard-coded resource names or token suffixes), then opens
    the requested portal blade in your default browser via Start-Process.

    By default it targets the resource group used by the workshop deployment
    (rg-dev-001) and opens the Application Insights Overview blade. Use -Blade
    to jump straight to the panel you want to demo (Live Metrics, Application
    Map, Failures, Performance, Transaction Search, or Logs / KQL).

    The script uses the Azure CLI (az) to discover the component, so you must be
    signed in (az login) and have the subscription selected (az account set).

.PARAMETER ResourceGroup
    The resource group containing the Application Insights resource.
    Defaults to 'rg-dev-001'.

.PARAMETER AppInsightsName
    Optional explicit Application Insights component name. When omitted, the
    script discovers the first component in the resource group.

.PARAMETER Blade
    Which monitoring blade to open. One of: Overview, LiveMetrics,
    ApplicationMap, Failures, Performance, TransactionSearch, Logs.
    Defaults to 'Overview'.

.PARAMETER Subscription
    Optional subscription id or name to scope the lookup. When omitted, the
    current az default subscription is used.

.EXAMPLE
    ./open-monitoring-dashboard.ps1
    Opens the Application Insights Overview blade for rg-dev-001.

.EXAMPLE
    ./open-monitoring-dashboard.ps1 -Blade LiveMetrics
    Jumps straight to Live Metrics for the live demo.

.EXAMPLE
    ./open-monitoring-dashboard.ps1 -ResourceGroup rg-test-001 -Blade Failures
    Opens the Failures blade for a different environment.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-dev-001',

    [string]$AppInsightsName,

    [ValidateSet('Overview', 'LiveMetrics', 'ApplicationMap', 'Failures', 'Performance', 'TransactionSearch', 'Logs')]
    [string]$Blade = 'Overview',

    [string]$Subscription
)

$ErrorActionPreference = 'Stop'

# --- Verify Azure CLI is available -------------------------------------------
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) was not found on PATH. Install it from https://aka.ms/azcli and run 'az login'."
}

# --- Resolve subscription -----------------------------------------------------
if ($Subscription) {
    Write-Host "Setting subscription to '$Subscription'..." -ForegroundColor Cyan
    az account set --subscription $Subscription | Out-Null
}

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    throw "Not signed in to Azure. Run 'az login' first."
}
$subscriptionId = $account.id
Write-Host "Subscription : $($account.name) ($subscriptionId)" -ForegroundColor DarkGray
Write-Host "Tenant       : $($account.tenantId)" -ForegroundColor DarkGray

# --- Discover the Application Insights component ------------------------------
if (-not $AppInsightsName) {
    Write-Host "Discovering Application Insights component in '$ResourceGroup'..." -ForegroundColor Cyan
    # Wrap in @() so a single-element JSON array is not unwrapped into a bare
    # string (which would make $components[0] index the first character).
    $components = @(az resource list `
        --resource-group $ResourceGroup `
        --resource-type 'Microsoft.Insights/components' `
        --query "[].name" `
        --output json 2>$null | ConvertFrom-Json)

    if (-not $components -or $components.Count -eq 0) {
        throw "No Application Insights component found in resource group '$ResourceGroup'. Pass -AppInsightsName explicitly or check the resource group name."
    }

    if ($components.Count -gt 1) {
        Write-Host "Multiple components found; using the first one. Use -AppInsightsName to choose:" -ForegroundColor Yellow
        $components | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }

    $AppInsightsName = $components[0]
}

Write-Host "App Insights : $AppInsightsName" -ForegroundColor Green

# --- Fetch the component details (id + appId) --------------------------------
$component = az monitor app-insights component show `
    --resource-group $ResourceGroup `
    --app $AppInsightsName `
    --output json 2>$null | ConvertFrom-Json

if (-not $component) {
    throw "Could not read Application Insights component '$AppInsightsName' in '$ResourceGroup'."
}

$resourceId = $component.id
$appId = $component.appId
Write-Host "Resource Id  : $resourceId" -ForegroundColor DarkGray
Write-Host "App Id       : $appId" -ForegroundColor DarkGray

# --- Build the portal deep link ----------------------------------------------
# The Application Insights portal menu blades are addressed via the menuId
# fragment on the resource URL.
$bladeMenu = @{
    'Overview'          = 'overview'
    'LiveMetrics'       = 'quickPulse'
    'ApplicationMap'    = 'applicationMap'
    'Failures'          = 'failures'
    'Performance'       = 'performance'
    'TransactionSearch' = 'searchV1'
    'Logs'              = 'logs'
}[$Blade]

$portalUrl = "https://portal.azure.com/#@$($account.tenantId)/resource$resourceId/$bladeMenu"

Write-Host ""
Write-Host "Opening '$Blade' blade in the Azure portal..." -ForegroundColor Cyan
Write-Host $portalUrl -ForegroundColor Blue

Start-Process $portalUrl

Write-Host ""
Write-Host "Done. If the browser did not open, copy the URL above." -ForegroundColor Green
