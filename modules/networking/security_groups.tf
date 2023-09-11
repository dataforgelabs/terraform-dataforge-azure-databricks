resource "azurerm_network_security_group" "main" {
  location            = var.region
  name                = "DataBricks-SG"
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "host" {
  subnet_id                 = var.existing_databricks_host_subnet_name == "" ? azurerm_subnet.host[0].id : data.azurerm_subnet.host[0].id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_subnet_network_security_group_association" "container" {
  subnet_id                 = var.existing_databricks_container_subnet_name == "" ? azurerm_subnet.container[0].id : data.azurerm_subnet.container[0].id
  network_security_group_id = azurerm_network_security_group.main.id
}
