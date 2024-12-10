//need storage account and mount
//resource group (existing?)
//vnet (existing?)
//host subnet
//internal subnet
//workspace

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "1.18.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.43.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.25.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.application_client_id
  client_secret   = var.application_client_secret
}

provider "azuread" {
  tenant_id       = var.tenant_id
  client_id       = var.application_client_id
  client_secret   = var.application_client_secret
}

locals {
  vnet_cidr_full                   = var.vnet_cidr_block == "" ? "${var.vnet_first_two_octets}.0.0/16" : var.vnet_cidr_block
  databricks_host_subnet_full      = var.databricks_host_subnet == "" ? "${var.vnet_first_two_octets}.128.0/18" : var.databricks_host_subnet
  databricks_container_subnet_full = var.databricks_container_subnet == "" ? "${var.vnet_first_two_octets}.192.0/18" : var.databricks_container_subnet
  commonTags = {
    Environment = var.environment_prefix
  }
}

resource "azurerm_resource_group" "main" {
  count    = var.existing_resource_group_name == "" ? 1 : 0
  name     = "${var.environment_prefix}-DB-Workspace-RG"
  location = var.region

  tags = merge(
    local.commonTags,
    tomap(
      { "Name" = "${var.environment_prefix}-ResourceGroup", "createdBy" = "dataforge-terraform" }
    )
  )
}

locals {
  resource_group_name = var.existing_resource_group_name == "" ? azurerm_resource_group.main[0].name : var.existing_resource_group_name
  resource_group_location = var.existing_resource_group_location == "" ? azurerm_resource_group.main[0].location : var.existing_resource_group_location

}

module "networking" {
  source = "./modules/networking"
  environment_prefix                        = var.environment_prefix
  region                                    = var.region
  resource_group_name                       = local.resource_group_name
  vnet_cidr_full                            = local.vnet_cidr_full
  databricks_host_subnet_full               = local.databricks_host_subnet_full
  databricks_container_subnet_full          = local.databricks_container_subnet_full
  existing_vnet_name                        = var.existing_vnet_name
  existing_databricks_host_subnet_name      = var.existing_databricks_host_subnet_name
  existing_databricks_container_subnet_name = var.existing_databricks_container_subnet_name

}

module "databricks_workspace" {
  source = "./modules/databricks_workspace"
  environment_prefix          = var.environment_prefix
  region                      = var.region
  subscription_id             = var.subscription_id
  tenant_id                   = var.tenant_id
  application_client_id       = var.application_client_id
  application_client_secret   = var.application_client_secret
  resource_group_name         = local.resource_group_name
  resource_group_location     = local.resource_group_location
  host_subnet                 = module.networking.host_subnet
  container_subnet            = module.networking.container_subnet
  host_sg_association_id      = module.networking.host_sg_association_id
  container_sg_association_id = module.networking.container_sg_association_id
  vnet_id                     = module.networking.vnet_id
  databricks_workspace_sku    = var.databricks_workspace_sku
  enable_unity_catalog        = var.enable_unity_catalog
}