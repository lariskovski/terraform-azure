# Configure the Microsoft Azure Provider
provider azurerm {
      features {}
    #   version = "~>2.48"
      subscription_id = "${var.subscription_id}"
      client_id       = "${var.client_id}"
      client_secret   = "${var.client_secret}"
      tenant_id       = "${var.tenant_id}"
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "rg" {
  name = var.resource_group_name
  location = var.region
}

##########################################
# SQL SERVER
##########################################

resource "azurerm_sql_server" "server" {
  name                         = "mssql-${var.project_name}-${var.environment}" # NOTE: needs to be globally unique
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "${var.administrator_login}"
  administrator_login_password = "${var.administrator_login_password}"
}

resource "azurerm_sql_elasticpool" "pool" {
  name                = "${var.project_name}-${var.environment}-pool"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  server_name         = azurerm_sql_server.server.name
  edition             = "Basic"
  dtu                 = 50
  db_dtu_min          = 0
  db_dtu_max          = 5
  pool_size           = 5000
}

# resource "azurerm_storage_account" "sa" {
#   name                     = "${var.project_name}${var.environment}sa"
#   resource_group_name      = azurerm_resource_group.rg.name
#   location                 = azurerm_resource_group.rg.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }

resource "azurerm_sql_database" "database" {
  count = length(var.database_names)
  name                = "${var.database_names[count.index]}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  server_name         = azurerm_sql_server.server.name
  elastic_pool_name   = azurerm_sql_elasticpool.pool.name

#   extended_auditing_policy {
#     storage_endpoint                        = azurerm_storage_account.sa.primary_blob_endpoint
#     storage_account_access_key              = azurerm_storage_account.sa.primary_access_key
#     storage_account_access_key_is_secondary = true
#     retention_in_days                       = 6
#   }

  tags = {
    environment = "${var.environment}"
  }
}

#########################################
# WEB APPS
##########################################

resource "azurerm_app_service_plan" "asp" {
  name                = "${var.project_name}-${var.environment}-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Windows"
  reserved            = false
  sku {
    tier = "Standard"
    size = "S1"
  }
#     sku {
#     tier = "Premium"
#     size = "P1v2"
#   }
}

# data "template_file" "app_settings" {
#   template = "${file("settings/app-settings.txt")}"
# }

resource "azurerm_app_service" "as" {
  count               = length(var.app_names)
  name                = "${var.project_name}-${var.environment}-${var.app_names[count.index]}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id

  site_config {
    dotnet_framework_version = "${var.dot_net_version}"
    scm_type                 = "LocalGit"
  }

  app_settings = {
    "SOME_KEY" = "some-value",
    "ANOTHER_KEY" = "another-value"
  }

#   app_settings = "${data.template_file.app_settings.rendered}"

  connection_string {
    name  = "MSSQL"
    type  = "SQLServer"
    value = "Server=tcp:${azurerm_sql_server.server.fully_qualified_domain_name},1433;Database=${azurerm_sql_database.database[0].name};User ID=${azurerm_sql_server.server.administrator_login};Password=${azurerm_sql_server.server.administrator_login_password};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=600;"
  }
}