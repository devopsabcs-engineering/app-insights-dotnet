#!/usr/bin/env bash
# infra/scripts/create-federated-credentials.sh
# Create one Entra application + service principal and seed every federated
# credential needed for GitHub Actions (workshop-dev, workshop-teardown,
# main branch, PRs) and Azure DevOps (per service connection).
#
# Prereqs: az login as a user with at least Application Administrator + Owner
# on the target subscription.
#
# Usage: ./create-federated-credentials.sh
set -euo pipefail

# ---------- Required configuration (edit these) ----------
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-app-insights-dotnet-workshop-cicd}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:?Set SUBSCRIPTION_ID}"

# GitHub
GH_OWNER="${GH_OWNER:-devopsabcs-engineering}"
GH_REPO="${GH_REPO:-app-insights-dotnet}"

# Azure DevOps (one service connection per environment)
ADO_ORG="${ADO_ORG:?Set ADO_ORG (e.g. mapaq-tenant)}"
ADO_PROJECT="${ADO_PROJECT:?Set ADO_PROJECT}"
ADO_SC_DEV="${ADO_SC_DEV:-sc-workshop-dev}"
ADO_SC_TEST="${ADO_SC_TEST:-sc-workshop-test}"
ADO_SC_TEARDOWN="${ADO_SC_TEARDOWN:-sc-workshop-teardown}"

# ---------- 1. Create / fetch the Entra application ----------
APP_ID=$(az ad app list --display-name "$APP_DISPLAY_NAME" --query '[0].appId' -o tsv)
if [[ -z "$APP_ID" ]]; then
  echo ">> Creating Entra application $APP_DISPLAY_NAME"
  APP_ID=$(az ad app create --display-name "$APP_DISPLAY_NAME" --query appId -o tsv)
fi
SP_OBJECT_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query '[0].id' -o tsv || true)
if [[ -z "$SP_OBJECT_ID" ]]; then
  SP_OBJECT_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
fi
echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"

# ---------- 2. Subscription role assignment ----------
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null  # required for azd to assign roles in Bicep

# ---------- 3. Helper to add a federated credential idempotently ----------
add_fic () {
  local name="$1" issuer="$2" subject="$3" audience="${4:-api://AzureADTokenExchange}"
  if az ad app federated-credential list --id "$APP_ID" --query "[?name=='$name'] | length(@)" -o tsv | grep -q '^1'; then
    echo ">> federated-credential '$name' already exists (skipping)"
    return
  fi
  echo ">> adding federated-credential '$name' (subject=$subject)"
  az ad app federated-credential create --id "$APP_ID" --parameters "$(cat <<JSON
{
  "name": "$name",
  "issuer": "$issuer",
  "subject": "$subject",
  "audiences": ["$audience"],
  "description": "Auto-created by create-federated-credentials.sh"
}
JSON
)" >/dev/null
}

# ---------- 4. GitHub federated credentials ----------
GH_ISSUER="https://token.actions.githubusercontent.com"
add_fic "gh-env-workshop-dev"      "$GH_ISSUER" "repo:$GH_OWNER/$GH_REPO:environment:workshop-dev"
add_fic "gh-env-workshop-teardown" "$GH_ISSUER" "repo:$GH_OWNER/$GH_REPO:environment:workshop-teardown"
add_fic "gh-env-workshop-boards"   "$GH_ISSUER" "repo:$GH_OWNER/$GH_REPO:environment:workshop-boards"
add_fic "gh-branch-main"           "$GH_ISSUER" "repo:$GH_OWNER/$GH_REPO:ref:refs/heads/main"
add_fic "gh-pull-request"          "$GH_ISSUER" "repo:$GH_OWNER/$GH_REPO:pull_request"

# ---------- 5. Azure DevOps federated credentials ----------
# Issuer for ADO WIF is per-organization. Resolve it once via the org settings page,
# or compute via the documented format. Both are valid; we use the canonical form.
ADO_ISSUER="https://vstoken.dev.azure.com/$(az devops invoke \
  --area connectionData --resource connectionData \
  --route-parameters connectOptions=authenticatedUser \
  --org "https://dev.azure.com/$ADO_ORG" --query 'instanceId' -o tsv 2>/dev/null || echo 'CHANGE-ME-ORG-GUID')"

add_fic "ado-sc-workshop-dev"      "$ADO_ISSUER" "sc://$ADO_ORG/$ADO_PROJECT/$ADO_SC_DEV"
add_fic "ado-sc-workshop-test"     "$ADO_ISSUER" "sc://$ADO_ORG/$ADO_PROJECT/$ADO_SC_TEST"
add_fic "ado-sc-workshop-teardown" "$ADO_ISSUER" "sc://$ADO_ORG/$ADO_PROJECT/$ADO_SC_TEARDOWN"

cat <<EOF

================================================================
Federated credentials wired up. Next steps:
  1. In GitHub repo Settings -> Secrets and variables -> Actions, set:
       AZURE_CLIENT_ID       = $APP_ID
       AZURE_TENANT_ID       = $(az account show --query tenantId -o tsv)
       AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID
  2. In each ADO service connection (sc-workshop-dev/test/teardown), choose
     "Use existing app registration" and paste $APP_ID.
  3. Grant the workshop-dev / workshop-teardown / workshop-boards GitHub
     Environments their reviewers, branch-protection rules, and the secrets
     above.
================================================================
EOF
