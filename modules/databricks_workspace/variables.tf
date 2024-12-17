variable "region" {
  type = string
}

variable "environment_prefix" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "application_client_id" {
  type = string
}

variable "application_client_secret" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "resource_group_location" {
  type = string
}

variable "host_subnet" {
  type = object({
    id   = string
    name = string
  })
}

variable "container_subnet" {
  type = object({
    id   = string
    name = string
  })
}

variable "host_sg_association_id" {
  type = string
}

variable "container_sg_association_id" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "databricks_workspace_sku" {
  type = string
}

variable "enable_unity_catalog" {
  type = string
}

variable "databricks_workspace_admin_email" {
  type = string
}

variable "resource_group_id" {
  type = string
}