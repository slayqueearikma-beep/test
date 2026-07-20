using './main.bicep'

param environmentName = 'prod'
param postgresAdminLogin = 'margemadmin'
// Set via CLI: az deployment group create ... --parameters postgresAdminPassword=<secret> jwtSecretKey=<secret>
param postgresAdminPassword = readEnvironmentVariable('MARGEM_PG_PASSWORD', '')
param jwtSecretKey = readEnvironmentVariable('MARGEM_JWT_SECRET', '')
