#!/usr/bin/env pwsh
# infra/scripts/grant-sql-access.ps1
# azd postprovision hook (Windows / pwsh). Grants the workshop UAMI
# db_datareader + db_datawriter on the workshop SQL DB. Runs as the signed-in
# attendee, who is already the SQL Entra admin.
#
# Requires: SqlServer module (Install-Module SqlServer -Scope CurrentUser).
$ErrorActionPreference = 'Stop'

# In CI (GitHub Actions), SQL public access is disabled and the UAMI gets
# SQL access via Entra group membership instead. Skip this hook.
if ($env:GITHUB_ACTIONS -eq 'true') {
    Write-Host '>> Skipping SQL grant in CI - UAMI uses Entra group membership for SQL access.'
    exit 0
}

$sqlServer = & azd env get-value SQL_FQDN
$sqlDb     = & azd env get-value SQL_DATABASE_NAME
$uamiName  = & azd env get-value UAMI_NAME

if ([string]::IsNullOrWhiteSpace($sqlServer) -or
    [string]::IsNullOrWhiteSpace($sqlDb) -or
    [string]::IsNullOrWhiteSpace($uamiName)) {
    Write-Error "Missing one of SQL_FQDN / SQL_DATABASE_NAME / UAMI_NAME from azd env"
    exit 1
}

Write-Host ">> Granting [$uamiName] db_datareader/db_datawriter on $sqlServer/$sqlDb"

if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host ">> Installing SqlServer PowerShell module (CurrentUser scope)..."
    Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
}
Import-Module SqlServer

$query = @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$uamiName')
    CREATE USER [$uamiName] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [$uamiName];
ALTER ROLE db_datawriter ADD MEMBER [$uamiName];
"@

$connectionString = "Server=tcp:$sqlServer,1433;Database=$sqlDb;Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;"

Invoke-Sqlcmd -ConnectionString $connectionString -Query $query

Write-Host ">> Done."
