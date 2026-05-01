// Key Vault - RBAC-only, soft-delete ON, purge protection OFF (workshop-disposable).
//
// Design notes (AB#2227):
//   * The vault is provisioned for pedagogical reasons and to keep the lab
//     content honest, but no app code or workflow currently reads from it.
//     The CI/CD path uses GitHub OIDC + UAMI, not vault-stored secrets.
//   * Purge protection is intentionally OFF. Once enabled it is irrevocable
//     and blocks attendees from re-using the same AZURE_ENV_NAME for 90 days
//     (VaultAlreadyExists 409 on re-deploy). The teardown workflow purges
//     the soft-deleted vault explicitly to free the name immediately.
//   * Soft-delete retention is set to the minimum (7 days) so any vault that
//     escapes explicit purge still reaps quickly.
//   * Resource name prefix is `kvw` (not `kv`) so this disposable vault does
//     not collide with any pre-existing purge-protected `kv*` vaults that
//     may still be locked from earlier deployments of this workshop.

param location string
param resourceToken string
param tags object

resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  // Vault names: 3-24 chars, global. Token = 13 chars; 'kvw' prefix = 16 total.
  name: 'kvw${resourceToken}'
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
    softDeleteRetentionInDays: 7
    // enablePurgeProtection intentionally omitted (defaults to false).
    // Do NOT set this to true for workshop environments.
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

output name string = kv.name
output id string = kv.id
output uri string = kv.properties.vaultUri
