// B1 Linux App Service Plan + 2 sites (mapaq-web-*, mapaq-api-*).
// Each site has SystemAssigned + UserAssigned identities; the UAMI is used for
// Key Vault references (keyVaultReferenceIdentity) and Entra auth to App Insights / SQL.
// App settings inject:
//   APPLICATIONINSIGHTS_CONNECTION_STRING        (workspace-based AI)
//   APPLICATIONINSIGHTS_AUTHENTICATION_STRING    (Entra-only AI; uses UAMI client id)
//   OTEL_RESOURCE_ATTRIBUTES                     (service.name + namespace)
//   AZURE_CLIENT_ID                              (DefaultAzureCredential -> UAMI)
//   ConnectionStrings__Mapaq                     (Key Vault reference to sql-conn secret)

param location string
param resourceToken string
param tags object
param uamiResourceId string
param uamiClientId string
param appInsightsConnectionString string
param keyVaultName string
param sqlSecretName string
param workspaceId string
param appIntegrationSubnetId string

// Plan name: 'asp-mapaq-' (10) + token (13) = 23 chars; well under 40-char limit.
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-mapaq-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'B1'
    tier: 'Basic'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true // REQUIRED for Linux plans
  }
}

var sqlConnRef = '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${sqlSecretName})'

var commonAppSettings = [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsightsConnectionString
  }
  {
    // Required because App Insights is configured with DisableLocalAuth: true.
    // Format documented for the Azure Monitor OpenTelemetry distro.
    name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING'
    value: 'Authorization=AAD;ClientId=${uamiClientId}'
  }
  {
    name: 'AZURE_CLIENT_ID'
    value: uamiClientId
  }
  {
    name: 'ConnectionStrings__Mapaq'
    value: sqlConnRef
  }
]

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'mapaq-web-${resourceToken}'
  location: location
  tags: union(tags, { 'azd-service-name': 'web' })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${uamiResourceId}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    virtualNetworkSubnetId: appIntegrationSubnetId
    keyVaultReferenceIdentity: uamiResourceId
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      alwaysOn: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: [ '*' ]
      }
      appSettings: union(commonAppSettings, [
        {
          name: 'OTEL_RESOURCE_ATTRIBUTES'
          value: 'service.name=mapaq-web,service.namespace=mapaq,service.version=1.0.0'
        }
      ])
    }
  }
}

resource apiApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'mapaq-api-${resourceToken}'
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${uamiResourceId}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    virtualNetworkSubnetId: appIntegrationSubnetId
    keyVaultReferenceIdentity: uamiResourceId
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      alwaysOn: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: [ '*' ]
      }
      appSettings: union(commonAppSettings, [
        {
          name: 'OTEL_RESOURCE_ATTRIBUTES'
          value: 'service.name=mapaq-api,service.namespace=mapaq,service.version=1.0.0'
        }
      ])
    }
  }
}

// Diagnostic settings -> Log Analytics for both apps.
resource webDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: webApp
  name: 'send-to-law'
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource apiDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apiApp
  name: 'send-to-law'
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output webUri string = 'https://${webApp.properties.defaultHostName}'
output apiUri string = 'https://${apiApp.properties.defaultHostName}'
output webName string = webApp.name
output apiName string = apiApp.name
