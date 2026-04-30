// =============================================================================
// MAPAQ App Insights .NET 10 Bilingual Workshop - Subscription-scope orchestrator
// =============================================================================
// Creates rg-${environmentName} and dispatches all 7 workshop modules.
// Cost ceiling: <= $0.60 USD per attendee per 2-hour run (B1 plan + GP_S_Gen5_1
// serverless SQL with auto-pause).
// =============================================================================

targetScope = 'subscription'

@minLength(2)
@maxLength(20)
@description('azd environment name (e.g. ws01). Used in RG + resource naming.')
param environmentName string

@description('Azure region for all resources.')
param location string = 'canadacentral'

@description('Object ID of the Microsoft Entra principal that will be SQL admin (user or group).')
param sqlAdminPrincipalId string

@description('UPN or display name of the SQL admin principal (shown in portal).')
param sqlAdminLogin string

// Stable token unique per (subscription, env, region) - avoids name collisions across attendees.
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

var tags = {
  'azd-env-name': environmentName
  workshop: 'mapaq'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module law 'modules/loganalytics.bicep' = {
  name: 'law-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
  }
}

module ai 'modules/appinsights.bicep' = {
  name: 'ai-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    workspaceResourceId: law.outputs.workspaceId
  }
}

module id 'modules/identity.bicep' = {
  name: 'id-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
  }
}

module kv 'modules/keyvault.bicep' = {
  name: 'kv-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
  }
}

module vnet 'modules/vnet.bicep' = {
  name: 'vnet-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
  }
}

module sql 'modules/sql.bicep' = {
  name: 'sql-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPrincipalId: sqlAdminPrincipalId
    keyVaultName: kv.outputs.name
  }
}

module pe 'modules/privateEndpoints.bicep' = {
  name: 'pe-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    vnetId: vnet.outputs.vnetId
    privateEndpointsSubnetId: vnet.outputs.privateEndpointsSubnetId
    sqlServerId: sql.outputs.serverId
    keyVaultId: kv.outputs.id
  }
}

module app 'modules/appservice.bicep' = {
  name: 'app-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    uamiResourceId: id.outputs.id
    uamiClientId: id.outputs.clientId
    appInsightsConnectionString: ai.outputs.connectionString
    keyVaultName: kv.outputs.name
    sqlSecretName: sql.outputs.connStringSecretName
    workspaceId: law.outputs.workspaceId
    appIntegrationSubnetId: vnet.outputs.appIntegrationSubnetId
  }
}

module ra 'modules/roleAssignments.bicep' = {
  name: 'ra-${resourceToken}'
  scope: rg
  params: {
    keyVaultName: kv.outputs.name
    appInsightsName: ai.outputs.name
    uamiPrincipalId: id.outputs.principalId
  }
}

// =============================================================================
// Outputs (consumed by azd env, postprovision scripts, and CI workflows)
// =============================================================================

// Required by orchestrator
output WEB_URI string = app.outputs.webUri
output API_URI string = app.outputs.apiUri
output SQL_FQDN string = sql.outputs.serverFqdn
output KV_NAME string = kv.outputs.name
output APPINSIGHTS_CONNECTION_STRING string = ai.outputs.connectionString

// azd convention outputs
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_LOCATION string = location
output AZURE_CLIENT_ID string = id.outputs.clientId
output RESOURCE_TOKEN string = resourceToken

// Used by grant-sql-access.{sh,ps1} postprovision hooks
output SQL_DATABASE_NAME string = sql.outputs.dbName
output UAMI_NAME string = id.outputs.name
