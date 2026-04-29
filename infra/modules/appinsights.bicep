// Application Insights (workspace-based) - DisableLocalAuth: true (Entra only).

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
    DisableLocalAuth: true
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output name string = ai.name
output id string = ai.id
output connectionString string = ai.properties.ConnectionString
