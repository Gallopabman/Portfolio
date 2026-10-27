# Copia de modules/cell/variables.tf (Terraform exige declarar las variables en la raíz).
# La CI verifica que sea idéntica al original: editar allá y copiar.

variable "project_id" {
  type = string
}

variable "name" {
  description = "Nombre de la celda: <ambiente>-<región corta>, p.ej. prod-eu-1."
  type        = string
  validation {
    condition     = can(regex("^(dev|staging|prod)-[a-z]{2}-[0-9]+$", var.name))
    error_message = "name debe tener la forma <dev|staging|prod>-<xx>-<n>, p.ej. prod-eu-1."
  }
}

variable "region" {
  type = string
}

variable "cidrs" {
  description = "Rangos de la celda. No deben solaparse entre celdas que se vayan a interconectar."
  type = object({
    nodes    = string
    pods     = string
    services = string
    master   = string
  })
}

variable "master_authorized_networks" {
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "gke" {
  type = object({
    release_channel = string
    node_pool = object({
      machine_type = string
      min_nodes    = number
      max_nodes    = number
      disk_size_gb = optional(number, 100)
      spot         = optional(bool, false)
    })
  })
}

variable "cloudsql" {
  type = object({
    tier              = string
    high_availability = bool
    retained_backups  = optional(number, 14)
  })
}

variable "topics" {
  description = "Topics de Pub/Sub de la celda."
  type        = list(string)
  default     = []
}

variable "workloads" {
  description = "Un servicio por clave; el nombre es también el de su ServiceAccount de Kubernetes."
  type = map(object({
    project_roles = optional(list(string), [])
    secrets       = optional(list(string), [])
    database      = optional(bool, false)
    publishes     = optional(list(string), [])
    subscribes    = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for w in values(var.workloads) : [for t in concat(w.publishes, w.subscribes) : contains(var.topics, t)]
    ]))
    error_message = "Todo topic en publishes/subscribes tiene que estar declarado en var.topics."
  }
}

variable "deletion_protection" {
  description = "true en todo lo que no sea un ambiente efímero."
  type        = bool
  default     = true
}
