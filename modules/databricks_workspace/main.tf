terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "1.18.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.25.0"
    }
  }
}

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
}

resource "azuread_application_password" "databricks" {
  application_object_id        = azuread_application.databricks_main.id
  end_date              = "2040-01-01T01:02:03Z"
}

resource "azuread_service_principal" "main" {
  application_id                    = azuread_application.databricks_main.application_id
  app_role_assignment_required = false
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.main.id
  azure_tenant_id             = var.tenant_id
  azure_client_id             = var.application_client_id
  azure_client_secret         = var.application_client_secret
}

data "databricks_group" "admins" {
  count        = var.databricks_workspace_admin_email != "" ? 1 : 0
  display_name = "admins"
  depends_on   = [azurerm_databricks_workspace.main]
}

resource "databricks_user" "admin" {
  count      = var.databricks_workspace_admin_email != "" ? 1 : 0
  user_name  = var.databricks_workspace_admin_email
  depends_on = [azurerm_databricks_workspace.main]
}

resource "databricks_group_member" "admin" {
  count      = var.databricks_workspace_admin_email != "" ? 1 : 0
  group_id   = data.databricks_group.admins[0].id
  member_id  = databricks_user.admin[0].id
  depends_on = [azurerm_databricks_workspace.main]
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
    "spark.hadoop.fs.azure.account.oauth2.client.id" : "${azuread_application.databricks_main.application_id}",
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
    client_id              = azuread_service_principal.main.application_id
    client_secret_scope    = databricks_secret_scope.ad_principal_secret.name
    client_secret_key      = databricks_secret.service_principal_key.key
    initialize_file_system = true
  }

}

resource "databricks_metastore" "unity_catalog" {
  count = var.enable_unity_catalog ? 1 : 0

  name          = "${var.environment_prefix}-UnityCatalog"
  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_data_lake_gen2_filesystem.datalake.name,
    azurerm_storage_account.datalake.name)
  region        = var.region
  owner         = var.databricks_workspace_admin_email
}

resource "databricks_metastore_assignment" "workspace_binding" {
  count = var.enable_unity_catalog ? 1 : 0

  workspace_id = azurerm_databricks_workspace.main.workspace_id
  metastore_id = databricks_metastore.unity_catalog[0].id
}


resource "azurerm_user_assigned_identity" "databricks_identity" {
  count = var.enable_unity_catalog ? 1 : 0

  name                = "${var.environment_prefix}-databricks-identity"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
}

resource "databricks_storage_credential" "unity_catalog_storage" {
  count = var.enable_unity_catalog ? 1 : 0

  name         = "unity_catalog_storage_credential"
  metastore_id = databricks_metastore.unity_catalog[0].id

  azure_managed_identity {
    access_connector_id = azurerm_user_assigned_identity.databricks_identity[0].id
  }
}

resource "databricks_external_location" "unity_catalog_location" {
  count                    = var.enable_unity_catalog ? 1 : 0

  name                     = "unity_catalog_external_location"
  metastore_id             = databricks_metastore.unity_catalog[0].id
  credential_name          = databricks_storage_credential.unity_catalog_storage[0].name
  url                      = "abfss://${var.environment_prefix}-data@${azurerm_storage_account.datalake.name}.dfs.core.windows.net/"
}

resource "databricks_catalog" "main_catalog" {
  count        = var.enable_unity_catalog ? 1 : 0

  name         = "dataforge_catalog"
  comment      = "Main Catalog"
  metastore_id = databricks_metastore.unity_catalog[0].id
}

resource "databricks_schema" "dataforge" {
  count        = var.enable_unity_catalog ? 1 : 0

  name         = "dataforge"
  catalog_name = databricks_catalog.main_catalog[0].name
  comment      = "Schema for DataForge application"
}

