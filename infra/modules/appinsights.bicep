// Application Insights (workspace-based).
// DisableLocalAuth is false so the browser JS SDK can send telemetry via
// connection string. Server-side apps still use Entra auth (UAMI) via
// APPLICATIONINSIGHTS_AUTHENTICATION_STRING.

param location string
param resourceToken string
param tags object
param workspaceResourceId string

resource ai 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai${resourceToken}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
    DisableLocalAuth: false
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output name string = ai.name
output id string = ai.id
output connectionString string = ai.properties.ConnectionString
