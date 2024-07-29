variable "subscription_id" {
  type = string
  description = "The Azure subscription ID"
  sensitive = true
}

variable "tenant_id" {
  type = string
  description = "The Azure tenant ID"
  sensitive = true
}

variable "client_id" {
  type = string
  description = "The Azure client ID"
  sensitive = true
}

variable "client_secret" {
    type = string
    description = "The Azure client secret"
    sensitive = true
}

variable "admin_password" {
    type = string
    description = "The admin password for the VM"
    sensitive = true
}

variable "admin_username" {
    type = string
    description = "The admin username for the VM"
    sensitive = true
}