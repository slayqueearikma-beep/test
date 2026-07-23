@description('Azure region for all MarGem resources')
param location string = resourceGroup().location

@description('Environment name: dev, staging, prod')
param environmentName string = 'prod'

@description('PostgreSQL administrator login')
@secure()
param postgresAdminLogin string

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('JWT signing secret for the API')
@secure()
param jwtSecretKey string

@description('SMTP host for transactional email')
param smtpHost string

@description('SMTP port')
param smtpPort int = 587

@description('SMTP username')
@secure()
param smtpUsername string = ''

@description('SMTP password')
@secure()
param smtpPassword string = ''

@description('SMTP from address')
param smtpFrom string = 'MarGem <noreply@margem.ma>'

@description('Public app URL used in email deep links')
param publicAppUrl string = 'https://margem.ma'

@description('Public API URL')
param publicApiUrl string = 'https://api.margem.ma'

@description('Container image for the MarGem API (ACR or Docker Hub)')
param apiImage string = 'margemapi:latest'

var namePrefix = 'margem-${environmentName}'
var postgresName = '${namePrefix}-pg'
var storageName = replace('${namePrefix}media', '-', '')
var containerEnvName = '${namePrefix}-cae'
var containerAppName = '${namePrefix}-api'
var keyVaultName = take('${namePrefix}-kv-${uniqueString(resourceGroup().id)}', 24)

// --- PostgreSQL Flexible Server (Burstable B1ms — ~$15-25/mo) ---
resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: postgresName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

resource postgresDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: postgres
  name: 'margem'
}

resource postgresFirewall 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = {
  parent: postgres
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// --- Blob Storage for seller/product images ---
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storage.name}/default/margem-media'
  properties: {
    publicAccess: 'None'
  }
}

// --- Key Vault for secrets ---
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// --- Container Apps Environment + API ---
resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerEnvName
  location: location
  properties: {}
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
        allowInsecure: false
      }
      secrets: [
        {
          name: 'database-url'
          value: 'postgresql+asyncpg://${postgresAdminLogin}:${postgresAdminPassword}@${postgres.properties.fullyQualifiedDomainName}:5432/margem?ssl=require'
        }
        {
          name: 'jwt-secret'
          value: jwtSecretKey
        }
        {
          name: 'storage-conn'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
        }
        {
          name: 'smtp-password'
          value: smtpPassword
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'margem-api'
          image: apiImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'APP_ENV', value: environmentName }
            { name: 'DEBUG', value: 'false' }
            { name: 'AUTH_DEV_BYPASS', value: 'false' }
            { name: 'DATABASE_URL', secretRef: 'database-url' }
            { name: 'JWT_SECRET_KEY', secretRef: 'jwt-secret' }
            { name: 'AZURE_STORAGE_CONNECTION_STRING', secretRef: 'storage-conn' }
            { name: 'AZURE_STORAGE_CONTAINER', value: 'margem-media' }
            { name: 'CORS_ORIGINS', value: '["https://margem.ma"]' }
            { name: 'ALLOWED_HOSTS', value: 'api.margem.ma,localhost,127.0.0.1' }
            { name: 'AUTH_RATE_LIMIT', value: '30/minute' }
            { name: 'RATE_LIMIT', value: '300/minute' }
            { name: 'PUBLIC_APP_URL', value: publicAppUrl }
            { name: 'PUBLIC_API_URL', value: publicApiUrl }
            { name: 'SMTP_HOST', value: smtpHost }
            { name: 'SMTP_PORT', value: string(smtpPort) }
            { name: 'SMTP_USERNAME', value: smtpUsername }
            { name: 'SMTP_PASSWORD', secretRef: 'smtp-password' }
            { name: 'SMTP_FROM', value: smtpFrom }
            { name: 'SMTP_USE_TLS', value: 'true' }
            { name: 'ALLOW_INSECURE_EMAIL_FALLBACK', value: 'false' }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output apiUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output postgresHost string = postgres.properties.fullyQualifiedDomainName
output storageAccountName string = storage.name
output keyVaultName string = keyVault.name
