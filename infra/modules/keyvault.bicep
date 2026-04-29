// Key Vault - RBAC-only, soft-delete + purge protection ON.
// NOTE: purge protection is IRREVOCABLE. Once enabled, even `azd down --purge --force`
// cannot fully delete the vault for the soft-delete retention window
// (90 days minimum once purge protection is on). Workshop attendees who reuse the same
// AZURE_ENV_NAME within that window may hit "VaultAlreadyExists" 409 errors.

param location string
param resourceToken string
param tags object

resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  // Vault names: 3-24 chars, global. Token = 13 chars; 'kv' prefix = 15.
  name: 'kv${resourceToken}'
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

output name string = kv.name
output id string = kv.id
output uri string = kv.properties.vaultUri
