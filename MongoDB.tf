resource "azurerm_cosmosdb_account" "cosmos_account" {
  name                = "cosmos-account"
  resource_group_name = azurerm_resource_group.CloudProject.name
  location            = azurerm_resource_group.CloudProject.location
  offer_type          = "Standard"
  kind                = "MongoDB"

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }

  geo_location {
    location          = "northeurope"
    failover_priority = 0
  }

  capabilities {
    name = "EnableMongo"
  }
  capabilities {
    name = "EnableMongoRoleBasedAccessControl"
  }
}

resource "kubernetes_secret" "mongo_auth" {
  metadata {
    name      = "mongo-auth"
    namespace = kubernetes_namespace.cloud_namespace.metadata.0.name
  }

  data = {
    connection = azurerm_cosmosdb_account.cosmos_account.primary_mongodb_connection_string
  }

  type = "Opaque"
}

resource "azurerm_cosmosdb_mongo_database" "mongodb" {
  name                = "mindentudoter"
  resource_group_name = azurerm_cosmosdb_account.cosmos_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos_account.name
  throughput          = 400
}

resource "azurerm_cosmosdb_mongo_collection" "Users" {
  name                = "Users"
  resource_group_name = azurerm_cosmosdb_account.cosmos_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos_account.name
  database_name       = azurerm_cosmosdb_mongo_database.mongodb.name

  default_ttl_seconds = "777"
  shard_key           = "uniqueKey"
  throughput          = 400

  index {
    keys   = ["_id"]
    unique = true
  }
}

resource "azurerm_cosmosdb_mongo_collection" "BlogPosts" {
  name                = "BlogPosts"
  resource_group_name = azurerm_cosmosdb_account.cosmos_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos_account.name
  database_name       = azurerm_cosmosdb_mongo_database.mongodb.name

  default_ttl_seconds = "777"
  shard_key           = "uniqueKey"
  throughput          = 400

  index {
    keys   = ["_id"]
    unique = true
  }
}

output "mongodb_endpoint" {
  description = "MongoDB endpoint"
  value       = azurerm_cosmosdb_account.cosmos_account.primary_mongodb_connection_string
  sensitive   = true
}