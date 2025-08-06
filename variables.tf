variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "application_client_id" {
  description = "Azure Active Directory App Registration client secret. Needs access to create a resource group and resources in the subscription"
  type        = string
}

variable "application_client_secret" {
  description = "Azure Active Directory App Registration client id. Needs access to create a resource group and resources in the subscription"
  type        = string
}

variable "region" {
  description = "Azure Region to deploy the environment to. Ex: East US 2"
  type        = string
}

variable "environment_prefix" {
  description = "The environment prefix for created resources naming. Ex: Dev"
  type        = string
  validation {
    condition     = length(var.environment_prefix) > 0
    error_message = "Variable cannot be empty string"
  }
}

variable "existing_resource_group_name" {
  description = "Existing resource group to create Azure Databricks workspace in"
  type        = string
  default     = ""
}

variable "existing_resource_group_location" {
  description = "Existing resource group to create Azure Databricks workspace in"
  type        = string
  default     = ""
}

variable "vnet_cidr_block" {
  description = "Full CIDR range for VPC. DataForge default is 173.1.0.0/16. Only use if not using the vnet_first_two_octets variable"
  type        = string
  default     = ""
}

variable "vnet_first_two_octets" {
  description = "First two octets for VPC range, use if using default module deployment. DataForge default is 173.1"
  type        = string
  default     = "173.1"
}

variable "existing_vnet_name" {
  description = "Existing VPC to deploy Databricks workspace to"
  type        = string
  default     = ""
}


variable "databricks_host_subnet" {
  description = "Host subnet for Databricks, DataForge default is 173.1.128.0/18. Only use if not using the vnet_first_two_octets variable. Needs to be defined if using the existing_databricks_host_subnet_name variable"
  type        = string
  default     = ""
}


variable "databricks_container_subnet" {
  description = "Container subnet for Databricks, DataForge default is 173.1.192.0/18. Only use if not using the vnet_first_two_octets variable. Needs to be defined if using the existing_databricks_container_subnet_name variable"
  type        = string
  default     = ""
}

variable "existing_databricks_host_subnet_name" {
  description = "Existing host subnet name to deploy Databricks workspace to"
  type        = string
  default     = ""
}

variable "existing_databricks_container_subnet_name" {
  description = "Existing container subnet name to deploy Databricks workspace to"
  type        = string
  default     = ""
}

variable "databricks_workspace_sku" {
  description = "The SKU to use for the Databricks Workspace. Possible values are standard, premium, or trial"
  type        = string
  default     = "premium"
}

variable "enable_unity_catalog" {
  description = "Flag to enable Unity Catalog"
  type        = bool
  default     = false
}

variable "add_metastore" {
  description = "set to true when no metastore in the region"
  type        = bool
  default     = false
}

variable "databricks_workspace_admin_email" {
  description = "If using a service principal, add an admin account that will be the first user granted access to the workspace. If using user email/password, this is not needed, as that user will have access to the workspace."
  type        = string
  default     = ""
}