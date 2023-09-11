resource "azurerm_storage_account" "datalake" {
  name                            = lower("${var.environment_prefix}datalake")
  resource_group_name             = var.resource_group_name
  location                        = var.region
  account_replication_type        = "LRS"
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = "true"
  allow_nested_items_to_be_public = false
  tags = merge(
    local.commonTags,
    tomap(
      { "Name" = "${var.environment_prefix}-DB-Storage" }
    )
  )
}

resource "azurerm_storage_account_network_rules" "main" {
  storage_account_id = azurerm_storage_account.datalake.id

  default_action = "Deny"
  virtual_network_subnet_ids = [
    var.host_subnet.id,
  var.container_subnet.id]

  lifecycle {
    ignore_changes = [virtual_network_subnet_ids]
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "datalake" {
  name               = lower("${var.environment_prefix}-datalake")
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_role_assignment" "databricks_account_contributor" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azuread_service_principal.main.object_id
}

resource "azurerm_role_assignment" "databricks_data_contributor" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.main.object_id
}