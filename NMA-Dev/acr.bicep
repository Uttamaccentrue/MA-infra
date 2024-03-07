// Azure Container Repo is used to store all the Docker images.
// They will be accessed by the system or person doing the deployments
// and will be pulled by the AKS clusters that will be hosting/running the images

param location string = resourceGroup().location

resource dockerRepo 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: 'maportalrepo'
  location: location

  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    //publicNetworkAccess: 'string'
    zoneRedundancy: 'Disabled'
  }
}