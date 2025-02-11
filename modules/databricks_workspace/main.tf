terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "1.61.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.0.2"
    }
  }
}

data "azuread_client_config" "current" {}

locals {
  commonTags = {
    Environment = var.environment_prefix
  }
}

resource "azurerm_databricks_workspace" "main" {
  name                = "${var.environment_prefix}-Databricks"
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = var.databricks_workspace_sku

  custom_parameters {
    no_public_ip                                         = true
    public_subnet_name                                   = var.host_subnet.name
    private_subnet_name                                  = var.container_subnet.name
    virtual_network_id                                   = var.vnet_id
    public_subnet_network_security_group_association_id  = var.host_sg_association_id
    private_subnet_network_security_group_association_id = var.container_sg_association_id
  }

  tags = merge(
    local.commonTags,
    tomap(
      { "Name" = "${var.environment_prefix}-Databricks", "createdBy" = "dataforge-terraform" }
    )
  )
}

resource "azuread_application" "databricks_main" {
  display_name = "${var.environment_prefix}-Databricks"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "databricks" {
  application_id        = azuread_application.databricks_main.id
  end_date              = "2040-01-01T01:02:03Z"
}

resource "azuread_service_principal" "main" {
  client_id                    = azuread_application.databricks_main.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "example" {
  service_principal_id = azuread_service_principal.main.id
}


provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.main.id
  azure_tenant_id             = var.tenant_id
  azure_client_id             = var.application_client_id
  azure_client_secret         = var.application_client_secret
}

resource "databricks_secret_scope" "ad_principal_secret" {
  name                     = "adprincipal"
  initial_manage_principal = "users"
}

resource "databricks_secret" "service_principal_key" {
  key          = "service_principal_key"
  string_value = azuread_application_password.databricks.value
  scope        = databricks_secret_scope.ad_principal_secret.name
}

resource "databricks_sql_global_config" "this" {
  security_policy = "DATA_ACCESS_CONTROL"
  data_access_config = {
    "spark.hadoop.fs.azure.account.auth.type" : "OAuth",
    "spark.hadoop.fs.azure.account.oauth.provider.type" : "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider",
    "spark.hadoop.fs.azure.account.oauth2.client.id" : "${azuread_application.databricks_main.client_id}",
    "spark.hadoop.fs.azure.account.oauth2.client.secret" : "{{secrets/adprincipal/service_principal_key}}",
    "spark.hadoop.fs.azure.account.oauth2.client.endpoint" : "https://login.microsoftonline.com/${var.tenant_id}/oauth2/token"
  }
  sql_config_params = {
    "ANSI_MODE" : "true"
  }
}

resource "databricks_mount" "datalake_mount" {
  //count = var.enable_unity_catalog ? 0 : 1

  name = "datalake"
  abfs {
    container_name         = azurerm_storage_data_lake_gen2_filesystem.datalake.name
    storage_account_name   = azurerm_storage_account.datalake.name
    tenant_id              = var.tenant_id
    client_id              = azuread_service_principal.main.client_id
    client_secret_scope    = databricks_secret_scope.ad_principal_secret.name
    client_secret_key      = databricks_secret.service_principal_key.key
    initialize_file_system = true
  }

}

resource "databricks_metastore" "unity_catalog" {
  count = var.enable_unity_catalog && var.add_metastore ? 1 : 0
  name          = "${var.environment_prefix}_unitycatalog"
  region        = var.region
  force_destroy = true

  depends_on = [azurerm_storage_data_lake_gen2_filesystem.datalake, azurerm_storage_account.datalake, azurerm_role_assignment.databricks_account_contributor, azurerm_role_assignment.databricks_data_contributor]
}

resource "databricks_metastore_assignment" "workspace_binding" {
  count        = var.enable_unity_catalog && var.add_metastore ? 1 : 0
  workspace_id = azurerm_databricks_workspace.main.workspace_id
  metastore_id = databricks_metastore.unity_catalog[0].id

  depends_on = [ databricks_metastore.unity_catalog ]
}

resource "azurerm_databricks_access_connector" "unity" {
  count = var.enable_unity_catalog ? 1 : 0
  name                = "${var.environment_prefix}-databricks-access-connector"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  identity {
        type = "SystemAssigned"
      }
}

resource "azurerm_role_assignment" "databricks_storage_contributor" {
  principal_id         = azurerm_databricks_access_connector.unity[0].identity[0].principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = azurerm_storage_account.datalake.id

  depends_on = [ azurerm_databricks_access_connector.unity ]
}

resource "databricks_storage_credential" "unity_catalog_storage" {
  count = var.enable_unity_catalog ? 1 : 0
  name  = azurerm_databricks_access_connector.unity[0].name

   azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.unity[0].id
  }
} 

resource "databricks_external_location" "unity_catalog_location" {
  count                    = var.enable_unity_catalog ? 1 : 0
  name                     = "unity_catalog_external_location"
  credential_name          = databricks_storage_credential.unity_catalog_storage[0].id
  url                      = format("abfss://%s@%s.dfs.core.windows.net",
    azurerm_storage_data_lake_gen2_filesystem.datalake.name,
    azurerm_storage_account.datalake.name)
  owner                    = var.databricks_workspace_admin_email
}

resource "databricks_catalog" "main_catalog" {
  count        = var.enable_unity_catalog ? 1 : 0
  name         = "${var.environment_prefix}"
  comment      = "Main Catalog for ${var.environment_prefix}"
  metastore_id = databricks_metastore.unity_catalog[0].id
  storage_root = format("abfss://%s@%s.dfs.core.windows.net",
    azurerm_storage_data_lake_gen2_filesystem.datalake.name,
    azurerm_storage_account.datalake.name)
  owner        = var.databricks_workspace_admin_email
}

resource "databricks_grants" "primary" {
  count = var.enable_unity_catalog ? 1 : 0
  metastore = databricks_metastore.unity_catalog[0].id
  grant {
    principal  = var.application_client_id
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION"]
  }
}

resource "databricks_grants" "lab" {
  count = var.enable_unity_catalog ? 1 : 0
  catalog = databricks_catalog.main_catalog[0].name

  grant {
    principal  = var.application_client_id
    privileges = ["ALL_PRIVILEGES"]
  }
  
}

resource "databricks_grants" "external_creds" {
  storage_credential = databricks_storage_credential.unity_catalog_storage[0].id
  grant {
    principal  = var.application_client_id
    privileges = ["ALL_PRIVILEGES"]
  }
}

resource "databricks_grants" "some" {
  external_location = databricks_external_location.unity_catalog_location[0].id
  grant {
    principal  = var.application_client_id
    privileges = ["ALL_PRIVILEGES"]
  }
}