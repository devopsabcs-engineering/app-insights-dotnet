// Virtual Network with two subnets:
//   snet-appintegration    - delegated to Microsoft.Web/serverFarms (App Service VNet integration)
//   snet-private-endpoints - hosts private endpoints for SQL + Key Vault

param location string
param resourceToken string
param tags object

var vnetName = 'vnet-${resourceToken}'

resource nsgPe 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${vnetName}-snet-pe-nsg'
  location: location
  tags: tags
}

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${vnetName}-snet-app-nsg'
  location: location
  tags: tags
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.40.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-appintegration'
        properties: {
          addressPrefix: '10.40.1.0/27'
          networkSecurityGroup: {
            id: nsgApp.id
          }
          delegations: [
            {
              name: 'Microsoft.Web-serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: '10.40.2.0/28'
          networkSecurityGroup: {
            id: nsgPe.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output appIntegrationSubnetId string = vnet.properties.subnets[0].id
output privateEndpointsSubnetId string = vnet.properties.subnets[1].id
