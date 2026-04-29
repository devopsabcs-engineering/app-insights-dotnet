#!/usr/bin/env bash
# infra/scripts/grant-sql-access.sh
# azd postprovision hook (POSIX). Grants the workshop UAMI db_datareader +
# db_datawriter on the workshop SQL DB. Runs as the signed-in attendee, who is
# already the SQL Entra admin (set via Bicep `administrators` block).
#
# Reads outputs from `azd env get-value`:
#   SQL_FQDN           - SQL logical server FQDN
#   SQL_DATABASE_NAME  - DB name (mapaqdb)
#   UAMI_NAME          - User-Assigned Managed Identity display name
set -euo pipefail

SQL_SERVER="$(azd env get-value SQL_FQDN)"
SQL_DB="$(azd env get-value SQL_DATABASE_NAME)"
UAMI_NAME="$(azd env get-value UAMI_NAME)"

if [[ -z "${SQL_SERVER}" || -z "${SQL_DB}" || -z "${UAMI_NAME}" ]]; then
  echo "ERROR: missing one of SQL_FQDN / SQL_DATABASE_NAME / UAMI_NAME from azd env" >&2
  exit 1
fi

echo ">> Granting [${UAMI_NAME}] db_datareader/db_datawriter on ${SQL_SERVER}/${SQL_DB}"

# go-sqlcmd v1.x supports -G with --authentication-method=ActiveDirectoryDefault,
# which uses the same credential chain as azd / az login.
sqlcmd \
  -S "${SQL_SERVER}" \
  -d "${SQL_DB}" \
  -G \
  --authentication-method=ActiveDirectoryDefault \
  -Q "
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'${UAMI_NAME}')
    CREATE USER [${UAMI_NAME}] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [${UAMI_NAME}];
ALTER ROLE db_datawriter ADD MEMBER [${UAMI_NAME}];
"

echo ">> Done."
