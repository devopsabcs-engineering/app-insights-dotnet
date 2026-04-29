// Log Analytics workspace - PerGB2018 SKU, 30-day retention.
// Backing store for App Insights (workspace-based) + App Service diagnostic settings.

param location string

@minLength(13)
@maxLength(13)
param resourceToken string

param tags object

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    // Hard cap on daily ingestion to keep workshop costs predictable.
    workspaceCapping: {
      dailyQuotaGb: json('0.5')
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

output workspaceId string = law.id
output name string = law.name
