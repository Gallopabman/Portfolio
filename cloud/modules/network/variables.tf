variable "project_id" {
  type = string
}

variable "name" {
  description = "Nombre de la VPC (suele ser el de la celda)."
  type        = string
}

variable "region" {
  type = string
}

variable "nodes_cidr" {
  description = "Rango primario de la subred (nodos)."
  type        = string
}

variable "pods_cidr" {
  description = "Rango secundario para los pods de GKE (VPC-native)."
  type        = string
}

variable "services_cidr" {
  description = "Rango secundario para los Services de GKE."
  type        = string
}

variable "private_services_prefix_length" {
  description = "Tamaño del rango para Private Service Access (Cloud SQL con IP privada)."
  type        = number
  default     = 20
}
