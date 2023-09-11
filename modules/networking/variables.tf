variable "region" {
  type = string
}

variable "environment_prefix" {
  type = string
}

variable "vnet_cidr_full" {
  type = string
}

variable "databricks_host_subnet_full" {
  type = string
}

variable "databricks_container_subnet_full" {
  type = string
}

variable "existing_vnet_name" {
  type = string
}

variable "existing_databricks_host_subnet_name" {
  type = string
}

variable "existing_databricks_container_subnet_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}