<#
.SYNOPSIS
    Stops the Mapaq.Api and Mapaq.Web processes started by start-local.ps1.

.DESCRIPTION
    Finds dotnet processes whose command line references the Mapaq.Api or
    Mapaq.Web project and terminates them. Safe to re-run.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$targets = @('Mapaq.Api', 'Mapaq.Web')
$killed = 0

# Use CIM to read CommandLine. Fall back to a name match on any 'dotnet' process
# spawned from the repo if CIM fails.
try {
    $procs = Get-CimInstance Win32_Process -Filter "Name = 'dotnet.exe'" -ErrorAction Stop
    foreach ($p in $procs) {
        $cmd = $p.CommandLine
        if (-not $cmd) { continue }
        foreach ($t in $targets) {
            if ($cmd -like "*$t*") {
                Write-Host "Stopping PID $($p.ProcessId) ($t)" -ForegroundColor Yellow
                try {
                    Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
                    $killed++
                } catch {
                    Write-Warning "Failed to stop PID $($p.ProcessId): $_"
                }
                break
            }
        }
    }
} catch {
    Write-Warning "CIM query failed; nothing stopped. ($_)"
}

if ($killed -eq 0) {
    Write-Host "No matching Mapaq dotnet processes were running." -ForegroundColor DarkGray
} else {
    Write-Host "Stopped $killed process(es)." -ForegroundColor Green
}
