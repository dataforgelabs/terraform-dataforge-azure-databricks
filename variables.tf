variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "application_client_id" {
  description = "Azure client secret"
  type        = string
}

variable "application_client_secret" {
  description = "Azure client secret"
  type        = string
}

variable "region" {
  description = "Azure region to deploy the environment to"
  type        = string
}

variable "environment_prefix" {
  description = "the environment to be deployed. Ex: Dev"
  type        = string
  validation {
    condition     = length(var.environment_prefix) > 0
    error_message = "Variable cannot be empty string"
  }
}

variable "existing_resource_group_name" {
  description = "Full CIDR range for VPC. Ex: 10.1.0.0/16"
  type        = string
  default     = ""
}

variable "vnet_cidr_block" {
  description = "Full CIDR range for VPC. Ex: 10.1.0.0/16"
  type        = string
  default     = ""
}

variable "vnet_first_two_octets" {
  description = "First two octets for VPC range, use if using IDO default deployment"
  type        = string
  default     = ""
}

variable "existing_vnet_name" {
  description = "Existing VPC to deploy Databricks workspace to"
  type        = string
  default     = ""
}


variable "databricks_host_subnet" {
  description = "host Subnet for Databricks, Ex: 10.1.128.0/18"
  type        = string
  default     = ""
}


variable "databricks_container_subnet" {
  description = "container Subnet for Databricks, Ex: 10.1.192.0/18"
  type        = string
  default     = ""
}

variable "existing_databricks_host_subnet_name" {
  description = "Existing host subnet to deploy Databricks workspace to"
  type        = string
  default     = ""
}

variable "existing_databricks_container_subnet_name" {
  description = "Existing container subnet to deploy Databricks workspace to"
  type        = string
  default     = ""
}

variable "databricks_workspace_sku" {
  description = "The SKU to use for the Databricks Workspace. Possible values are standard, premium, or trial"
  type        = string
  default     = "premium"
}