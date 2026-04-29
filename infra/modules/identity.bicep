// Single shared User-Assigned Managed Identity (DD-01).
// Both web and api apps attach this same UAMI -> one SQL CREATE USER, one KV
// role assignment, simpler trace correlation.

param location string
param resourceToken string
param tags object

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id${resourceToken}'
  location: location
  tags: tags
}

output id string = uami.id
output principalId string = uami.properties.principalId
output clientId string = uami.properties.clientId
output name string = uami.name
