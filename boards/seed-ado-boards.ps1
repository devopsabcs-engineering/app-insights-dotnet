#requires -Version 7.0
<#
.SYNOPSIS
  Seed Azure DevOps Boards from boards/work-items.yaml.

.DESCRIPTION
  Reads the bilingual work-items.yaml tree (Epics -> Features -> User
  Stories -> Tasks) and materializes it into Azure DevOps Boards via the
  `az boards` CLI. Each work item's System.Title is rendered as
  "<title_fr> -- <title_en>" so the French title appears first per the
  workshop's FR-default rule. System.Tags, System.Description, and (for
  stories) Microsoft.VSTS.Common.AcceptanceCriteria are populated through
  --fields. Parent linkage is established with `az boards work-item
  relation add --relation-type Parent`.

  Authentication: supports both
    * PAT  -- set $env:AZP_PAT (also exported as $env:AZURE_DEVOPS_EXT_PAT
             for the azure-devops extension).
    * WIF / interactive -- when AZP_PAT is empty, the script relies on the
             current `az login` context (works for OIDC / federated creds
             from GitHub Actions or a local interactive login).

.PARAMETER Organization
  Azure DevOps organization URL, e.g. https://dev.azure.com/contoso.

.PARAMETER Project
  Azure DevOps project name.

.PARAMETER Iteration
  Optional iteration path. When omitted, the project default is used.

.PARAMETER WorkItemsFile
  Path to the work-items YAML file. Defaults to boards/work-items.yaml
  (resolved relative to the current working directory).

.PARAMETER DryRun
  When supplied, no `az` calls are executed; the planned commands are
  printed instead.

.EXAMPLE
  pwsh boards/seed-ado-boards.ps1 `
    -Organization https://dev.azure.com/contoso `
    -Project Demo `
    -DryRun

.NOTES
  Requires:
    * PowerShell 7+
    * Azure CLI 2.60+
    * `az extension add --name azure-devops`
    * powershell-yaml module (auto-installed for the current user when missing)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Organization,
    [Parameter(Mandatory)] [string] $Project,
    [string] $Iteration,
    [switch] $DryRun,
    [string] $WorkItemsFile = 'boards/work-items.yaml'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Strict-mode-safe accessor: returns property value, or $null when absent.
function Get-Prop {
    param($Object, [Parameter(Mandatory)] [string] $Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [hashtable] -or $Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] } else { return $null }
    }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value } else { return $null }
}

# ---------------------------------------------------------------------------
# Module bootstrap: powershell-yaml provides ConvertFrom-Yaml.
# ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
    Write-Host 'Installing powershell-yaml module for the current user...' -ForegroundColor Yellow
    Install-Module -Name 'powershell-yaml' -Scope CurrentUser -Force -AllowClobber | Out-Null
}
Import-Module 'powershell-yaml' -ErrorAction Stop

# ---------------------------------------------------------------------------
# Authentication: PAT (preferred for CI) or current az login (WIF / dev).
# ---------------------------------------------------------------------------
if ($env:AZP_PAT) {
    # The azure-devops CLI extension reads AZURE_DEVOPS_EXT_PAT.
    $env:AZURE_DEVOPS_EXT_PAT = $env:AZP_PAT
    Write-Host 'Auth: using PAT from $env:AZP_PAT.' -ForegroundColor DarkGray
} else {
    Write-Host 'Auth: no AZP_PAT set; relying on current az login context (WIF / interactive).' -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Resolve and load the YAML.
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $WorkItemsFile)) {
    throw "Work items file not found: $WorkItemsFile"
}
$resolvedItemsFile = (Resolve-Path -LiteralPath $WorkItemsFile).Path
Write-Host "Loading work items from: $resolvedItemsFile" -ForegroundColor DarkGray

$plan = Get-Content -Raw -LiteralPath $resolvedItemsFile | ConvertFrom-Yaml
$epics = Get-Prop $plan 'epics'
if (-not $epics) {
    throw "No epics found in $resolvedItemsFile."
}

# ---------------------------------------------------------------------------
# Configure az defaults (skipped in DryRun to avoid mutating local config).
# ---------------------------------------------------------------------------
if (-not $DryRun) {
    & az devops configure --defaults "organization=$Organization" "project=$Project" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to set az devops defaults; ensure the azure-devops extension is installed.'
    }
}

# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------
function Format-Title {
    param(
        [Parameter(Mandatory)] [string] $TitleFr,
        [Parameter(Mandatory)] [string] $TitleEn
    )
    # FR first per FR-default workshop rule.
    return "$TitleFr -- $TitleEn"
}

function Format-CommandPreview {
    param([Parameter(Mandatory)] [string[]] $AzArgs)
    $rendered = foreach ($a in $AzArgs) {
        if ($a -match '\s|;|=|"') { '"{0}"' -f ($a -replace '"', '\"') } else { $a }
    }
    return 'az ' + ($rendered -join ' ')
}

function New-WorkItem {
    param(
        [Parameter(Mandatory)] [string] $Type,
        [Parameter(Mandatory)] [string] $Title,
        [string] $Description,
        [string] $AcceptanceCriteria,
        [string[]] $Tags,
        [string] $Iteration
    )

    $fieldPairs = New-Object System.Collections.Generic.List[string]
    if ($Tags -and $Tags.Count -gt 0) {
        # Azure DevOps tag delimiter is ';'.
        $fieldPairs.Add("System.Tags=$([string]::Join(';', $Tags))")
    }
    if ($AcceptanceCriteria) {
        # ADO accepts HTML; preserve newlines as <br/>.
        $ac = $AcceptanceCriteria.Trim() -replace "`r`n", "`n" -replace "`n", '<br/>'
        $fieldPairs.Add("Microsoft.VSTS.Common.AcceptanceCriteria=$ac")
    }

    $azArgs = @(
        'boards', 'work-item', 'create',
        '--type', $Type,
        '--title', $Title,
        '--organization', $Organization,
        '--project', $Project
    )
    if ($Description) {
        $desc = $Description.Trim() -replace "`r`n", "`n" -replace "`n", '<br/>'
        $azArgs += @('--description', $desc)
    }
    if ($Iteration) { $azArgs += @('--iteration', $Iteration) }
    if ($fieldPairs.Count -gt 0) { $azArgs += @('--fields') + $fieldPairs.ToArray() }
    $azArgs += @('--output', 'json')

    Write-Host (">> CREATE {0}: {1}" -f $Type, $Title) -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host ('   ' + (Format-CommandPreview -AzArgs $azArgs)) -ForegroundColor DarkGray
        return [pscustomobject]@{ id = -1; title = $Title; type = $Type }
    }

    $json = & az @azArgs
    if ($LASTEXITCODE -ne 0) {
        throw "az boards work-item create failed for '$Title' ($Type)."
    }
    return ($json | ConvertFrom-Json)
}

function Add-ParentLink {
    param(
        [Parameter(Mandatory)] $ChildId,
        [Parameter(Mandatory)] $ParentId
    )

    $azArgs = @(
        'boards', 'work-item', 'relation', 'add',
        '--id', "$ChildId",
        '--relation-type', 'Parent',
        '--target-id', "$ParentId",
        '--organization', $Organization,
        '--output', 'none'
    )

    Write-Host ("   LINK Parent: child={0} -> parent={1}" -f $ChildId, $ParentId) -ForegroundColor DarkCyan

    if ($DryRun) {
        Write-Host ('   ' + (Format-CommandPreview -AzArgs $azArgs)) -ForegroundColor DarkGray
        return
    }

    & az @azArgs
    if ($LASTEXITCODE -ne 0) {
        throw "az boards work-item relation add failed (child=$ChildId, parent=$ParentId)."
    }
}

# ---------------------------------------------------------------------------
# Walk the tree: epics -> features -> stories -> tasks.
# ---------------------------------------------------------------------------
$totalCreated = 0
foreach ($epic in $epics) {
    $epicWi = New-WorkItem `
        -Type 'Epic' `
        -Title (Format-Title -TitleFr (Get-Prop $epic 'title_fr') -TitleEn (Get-Prop $epic 'title_en')) `
        -Description (Get-Prop $epic 'description') `
        -Tags (Get-Prop $epic 'tags') `
        -Iteration $Iteration
    $totalCreated++

    $features = Get-Prop $epic 'features'
    if (-not $features) { continue }
    foreach ($feature in $features) {
        $featureWi = New-WorkItem `
            -Type 'Feature' `
            -Title (Format-Title -TitleFr (Get-Prop $feature 'title_fr') -TitleEn (Get-Prop $feature 'title_en')) `
            -Description (Get-Prop $feature 'description') `
            -Tags (Get-Prop $feature 'tags') `
            -Iteration $Iteration
        Add-ParentLink -ChildId $featureWi.id -ParentId $epicWi.id
        $totalCreated++

        $stories = Get-Prop $feature 'stories'
        if (-not $stories) { continue }
        foreach ($story in $stories) {
            $storyWi = New-WorkItem `
                -Type 'User Story' `
                -Title (Format-Title -TitleFr (Get-Prop $story 'title_fr') -TitleEn (Get-Prop $story 'title_en')) `
                -Description (Get-Prop $story 'description') `
                -AcceptanceCriteria (Get-Prop $story 'acceptance_criteria') `
                -Tags (Get-Prop $story 'tags') `
                -Iteration $Iteration
            Add-ParentLink -ChildId $storyWi.id -ParentId $featureWi.id
            $totalCreated++

            $tasks = Get-Prop $story 'tasks'
            if (-not $tasks) { continue }
            foreach ($task in $tasks) {
                $taskWi = New-WorkItem `
                    -Type 'Task' `
                    -Title (Format-Title -TitleFr (Get-Prop $task 'title_fr') -TitleEn (Get-Prop $task 'title_en')) `
                    -Description (Get-Prop $task 'description') `
                    -Tags (Get-Prop $task 'tags') `
                    -Iteration $Iteration
                Add-ParentLink -ChildId $taskWi.id -ParentId $storyWi.id
                $totalCreated++
            }
        }
    }
}

$mode = if ($DryRun) { 'DRY-RUN' } else { 'APPLY' }
Write-Host ''
Write-Host "Done ($mode). Planned/created work items: $totalCreated." -ForegroundColor Green
