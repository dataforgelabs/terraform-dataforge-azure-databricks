locals {
  commonTags = {
    Environment = var.environment_prefix
  }
}

resource "azurerm_virtual_network" "main" {
  count               = var.existing_vnet_name == "" ? 1 : 0
  name                = "${var.environment_prefix}-Network"
  resource_group_name = var.resource_group_name
  location            = var.region
  address_space       = [var.vnet_cidr_full]

  lifecycle {
    ignore_changes = [dns_servers]
  }

  tags = merge(
    local.commonTags,
    tomap(
      { "Name" = "${var.environment_prefix}-Network" }
    )
  )
}

data "azurerm_virtual_network" "main" {
  count               = var.existing_vnet_name == "" ? 0 : 1
  name                = var.existing_vnet_name
  resource_group_name = var.resource_group_name
}

locals {
  vnet_name = var.existing_vnet_name == "" ? azurerm_virtual_network.main[0].name : var.existing_vnet_name
}