variable "project_id" {
  type = string
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "network_id" {
  description = "VPC con Private Service Access ya configurado."
  type        = string
}

variable "database_version" {
  type    = string
  default = "POSTGRES_17"
}

variable "tier" {
  type    = string
  default = "db-custom-2-7680"
}

variable "high_availability" {
  type    = bool
  default = false
}

variable "retained_backups" {
  type    = number
  default = 14
}

variable "deletion_protection" {
  type    = bool
  default = true
}
