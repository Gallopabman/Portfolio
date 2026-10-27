variable "project_id" {
  type = string
}

variable "name" {
  description = "Nombre del cluster (el de la celda)."
  type        = string
}

variable "region" {
  description = "Cluster regional: plano de control y nodos repartidos en las zonas de la región."
  type        = string
}

variable "network_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "master_cidr" {
  description = "Rango /28 para el plano de control privado."
  type        = string
}

variable "master_authorized_networks" {
  description = "Redes que pueden hablar con el plano de control (p.ej. los runners de CI)."
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "release_channel" {
  description = "RAPID en dev para detectar incompatibilidades antes; REGULAR o STABLE en prod."
  type        = string
  default     = "REGULAR"
  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel debe ser RAPID, REGULAR o STABLE."
  }
}

variable "node_pool" {
  type = object({
    machine_type = string
    min_nodes    = number
    max_nodes    = number
    disk_size_gb = optional(number, 100)
    spot         = optional(bool, false)
  })
}

variable "deletion_protection" {
  type    = bool
  default = true
}
