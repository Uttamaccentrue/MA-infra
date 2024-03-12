// K8s cluster that is used to host the servies / applications


param location string = resourceGroup().location


resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-03-01' = {
  name: 'maaks'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: '1.25.11'
    dnsPrefix: 'dnsprefix'
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 1
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        mode: 'System'
      }
    ]
  }
}