param location string = resourceGroup().location
param pgAdminLogin string = 'maadmin'

@secure()
param pgAdminPassword string

// PostgreSQL Flex Database
// Still need to configure firewall rule to allow traffic to it by hand
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: 'madb'
  location: location
  sku: {
    name: 'Standard_D4ds_v4'
    tier: 'GeneralPurpose'
  }
  properties: {
    administratorLogin: pgAdminLogin
    administratorLoginPassword: pgAdminPassword
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    dataEncryption: {
      type: 'SystemManaged'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    replicationRole: 'None'
    storage: {
      autoGrow: 'Enabled'
      storageSizeGB: 128
    }
    version: '15'
  }
}