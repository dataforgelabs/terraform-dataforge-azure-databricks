output "vnet_id" {
  value = var.existing_vnet_name == "" ? azurerm_virtual_network.main[0].id : data.azurerm_virtual_network.main[0].id
}

output "host_subnet" {
  value = var.existing_databricks_host_subnet_name == "" ? azurerm_subnet.host[0] : data.azurerm_subnet.host[0]
}

output "container_subnet" {
  value = var.existing_databricks_container_subnet_name == "" ? azurerm_subnet.container[0] : data.azurerm_subnet.container[0]
}

output "host_sg_association_id" {
  value = azurerm_subnet_network_security_group_association.host.id
}

output "container_sg_association_id" {
  value = azurerm_subnet_network_security_group_association.container.id
}

