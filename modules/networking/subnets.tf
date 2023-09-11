resource "azurerm_subnet" "host" {
  count                = var.existing_databricks_host_subnet_name == "" ? 1 : 0
  name                 = "${var.environment_prefix}-DataBricks-Host"
  resource_group_name  = var.resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.databricks_host_subnet_full]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault"]

  delegation {
    name = "DatabricksPublicDelegation"

    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
      name = "Microsoft.Databricks/workspaces"
    }
  }
}

resource "azurerm_subnet" "container" {
  count                = var.existing_databricks_container_subnet_name == "" ? 1 : 0
  name                 = "${var.environment_prefix}-DataBricks-Container"
  resource_group_name  = var.resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.databricks_container_subnet_full]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault"]

  delegation {
    name = "DatabricksPrivateDelegation"

    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
      name = "Microsoft.Databricks/workspaces"
    }
  }
}

data "azurerm_subnet" "host" {
  count                = var.existing_databricks_host_subnet_name == "" ? 0 : 1
  name                 = var.existing_databricks_host_subnet_name
  virtual_network_name = local.vnet_name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "container" {
  count                = var.existing_databricks_container_subnet_name == "" ? 0 : 1
  name                 = var.existing_databricks_container_subnet_name
  virtual_network_name = local.vnet_name
  resource_group_name  = var.resource_group_name
}

