// Azure Container Registry for MAPAQ workshop images.
// Passwordless: admin user disabled; UAMI AcrPull (see acrRoleAssignment.bicep)
// provides image pull for the App Service for Containers sites.

@description('Azure Container Registry for MAPAQ workshop images.')
param location string
param tags object
param resourceToken string

@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Basic'

resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  // resourceToken is uniqueString() (always 13 chars), so 'acr' + token = 16 chars,
  // always above the registry name minimum of 5. BCP334 cannot infer the param length statically.
  #disable-next-line BCP334
  name: 'acr${resourceToken}' // alphanumeric only, no hyphens
  location: location
  tags: tags
  sku: { name: sku }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled' // Basic + public pull; UAMI AcrPull still passwordless
  }
}

output id string = acr.id
output name string = acr.name
output loginServer string = acr.properties.loginServer
