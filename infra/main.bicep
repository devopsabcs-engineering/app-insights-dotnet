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

@allowed(['User', 'Group'])
@description('Entra principal type for the SQL admin (User or Group).')
param sqlAdminPrincipalType string = 'Group'

@description('Container image tag for the mapaq-api site (azd substitutes API_IMAGE_TAG).')
param apiImageTag string = 'latest'

@description('Container image tag for the mapaq-web site (azd substitutes WEB_IMAGE_TAG).')
param webImageTag string = 'latest'

@allowed(['Basic', 'Standard', 'Premium'])
@description('SKU for the Azure Container Registry.')
param acrSku string = 'Basic'

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
    sqlAdminPrincipalType: sqlAdminPrincipalType
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
  }
}

module acr 'modules/acr.bicep' = {
  name: 'acr-${resourceToken}'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    sku: acrSku
  }
}

module acrRoleAssignment 'modules/acrRoleAssignment.bicep' = {
  name: 'acrra-${resourceToken}'
  scope: rg
  params: {
    acrName: acr.outputs.name
    uamiPrincipalId: id.outputs.principalId
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
    sqlConnectionString: sql.outputs.connectionString
    workspaceId: law.outputs.workspaceId
    appIntegrationSubnetId: vnet.outputs.appIntegrationSubnetId
    acrLoginServer: acr.outputs.loginServer
    apiImageTag: apiImageTag
    webImageTag: webImageTag
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
output UAMI_PRINCIPAL_ID string = id.outputs.principalId

// Container registry (consumed by CI: az acr build + azd env get-value)
output ACR_NAME string = acr.outputs.name
output ACR_LOGIN_SERVER string = acr.outputs.loginServer
