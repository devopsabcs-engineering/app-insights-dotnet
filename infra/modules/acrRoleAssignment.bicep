// Grants the shared UAMI the AcrPull role scoped to the workshop ACR so the
// App Service for Containers sites can pull images passwordless (no admin user,
// no registry credentials). Mirrors the pattern in roleAssignments.bicep.

param acrName string
param uamiPrincipalId string

// Built-in role ID (stable GUID)
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull

resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = {
  name: acrName
}

resource raAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, uamiPrincipalId, acrPullRoleId)
  properties: {
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
  }
}
