// UAMI role assignments:
//   - Key Vault Secrets User on the workshop Key Vault
//   - Monitoring Metrics Publisher on App Insights (required for Entra-auth ingestion)
// SQL DB user creation cannot be done in Bicep - see infra/scripts/grant-sql-access.{sh,ps1}.

param keyVaultName string
param appInsightsName string
param uamiPrincipalId string

// Built-in role IDs (stable GUIDs)
var kvSecretsUser = '4633458b-17de-408a-b874-0445c86b69e6'             // Key Vault Secrets User
var monitoringMetricsPublisher = '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher

resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

resource ai 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource raKv 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(kv.id, uamiPrincipalId, kvSecretsUser)
  properties: {
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUser)
  }
}

resource raAi 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: ai
  name: guid(ai.id, uamiPrincipalId, monitoringMetricsPublisher)
  properties: {
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisher)
  }
}
