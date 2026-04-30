// Azure SQL Logical Server (Entra-only auth) + Serverless DB (GP_S_Gen5_1).
// - administrators block + azureADOnlyAuthentications/Default both set true (belt-and-braces).
// - autoPauseDelay = 60 min, minCapacity = 0.5 vCore -> caps idle cost at storage-only.
// - Writes the 'sql-conn' secret into the shared Key Vault for App Service Key Vault refs.

param location string
param resourceToken string
param tags object
param sqlAdminLogin string
param sqlAdminPrincipalId string
@allowed(['User', 'Group'])
@description('Entra principal type for the SQL admin (User or Group).')
param sqlAdminPrincipalType string = 'Group'
param keyVaultName string

var serverName = 'sql${resourceToken}'
var dbName = 'mapaqdb'
var sqlConnSecretName = 'sql-conn'

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: serverName
  location: location
  tags: tags
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: sqlAdminPrincipalType
      login: sqlAdminLogin
      sid: sqlAdminPrincipalId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
    }
  }
}

// Belt-and-braces: also set the dedicated child resource so it persists across redeploys.
resource entraOnly 'Microsoft.Sql/servers/azureADOnlyAuthentications@2023-08-01-preview' = {
  parent: sqlServer
  name: 'Default'
  properties: {
    azureADOnlyAuthentication: true
  }
}

resource db 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: dbName
  location: location
  tags: tags
  sku: {
    name: 'GP_S_Gen5_1'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB
    minCapacity: json('0.5')
    autoPauseDelay: 60 // minutes; -1 to disable
    zoneRedundant: false
    requestedBackupStorageRedundancy: 'Local'
  }
}

// Reference the existing Key Vault and write the SQL connection string secret.
resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: kv
  name: sqlConnSecretName
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${dbName};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;'
  }
}

output serverId string = sqlServer.id
output serverName string = sqlServer.name
output serverFqdn string = sqlServer.properties.fullyQualifiedDomainName
output dbName string = dbName
output connStringSecretName string = secret.name
