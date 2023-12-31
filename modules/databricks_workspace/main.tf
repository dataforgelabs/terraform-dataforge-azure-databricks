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
  application_object_id = azuread_application.databricks_main.id
  end_date              = "2040-01-01T01:02:03Z"
}

resource "azuread_service_principal" "main" {
  application_id               = azuread_application.databricks_main.application_id
  app_role_assignment_required = false
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
    "spark.hadoop.fs.azure.account.oauth2.client.id" : "${azuread_application.databricks_main.application_id}",
    "spark.hadoop.fs.azure.account.oauth2.client.secret" : "{{secrets/adprincipal/service_principal_key}}",
    "spark.hadoop.fs.azure.account.oauth2.client.endpoint" : "https://login.microsoftonline.com/${var.tenant_id}/oauth2/token"
  }
  sql_config_params = {
    "ANSI_MODE" : "true"
  }
}

resource "databricks_mount" "datalake_mount" {
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

