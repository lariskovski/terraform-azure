# AUTH CONFIG
variable "client_id" {
  type = string
}
variable "client_secret" {
  type = string
}
variable "subscription_id" {
  type = string
}
variable "tenant_id" {
  type = string
}

# AZURE CONFIG
variable "region" {
  type = string
  default = "eastus"
}

variable "resource_group_name" {
  type = string
}

# GENERAL CONFIG
variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}

# WEB APP CONFIG
variable "dot_net_version" {
  type = string
  default = "v5.0"
}

variable "app_names" {
  description = "List of app names to be created."
}

# SQL CONFIG
variable "administrator_login" {
  type = string
}
variable "administrator_login_password" {
  type = string
}

variable "database_names" {
  description = "List of dbs names to be created."
}