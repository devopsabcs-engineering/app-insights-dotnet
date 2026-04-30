// Private Endpoints + Private DNS Zones for SQL Server and Key Vault.
// Each PE is placed in snet-private-endpoints and registered in the
// corresponding privatelink DNS zone linked to the VNet.

param location string
param resourceToken string
param tags object
param vnetId string
param privateEndpointsSubnetId string
param sqlServerId string
param keyVaultId string

// ─── SQL Server Private Endpoint ───
resource dnsSql 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: tags
}

resource dnsSqlLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dnsSql
  name: 'vnet-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

resource peSql 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pe-sql-${resourceToken}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-sql-${resourceToken}'
        properties: {
          privateLinkServiceId: sqlServerId
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource peSqlDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: peSql
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-sql'
        properties: {
          privateDnsZoneId: dnsSql.id
        }
      }
    ]
  }
}

// ─── Key Vault Private Endpoint ───
resource dnsKv 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource dnsKvLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dnsKv
  name: 'vnet-link-kv'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

resource peKv 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pe-kv-${resourceToken}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-kv-${resourceToken}'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource peKvDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: peKv
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-kv'
        properties: {
          privateDnsZoneId: dnsKv.id
        }
      }
    ]
  }
}
