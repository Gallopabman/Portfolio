variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  description = "Nombre del servicio. Es también el nombre de su ServiceAccount de Kubernetes."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,29}$", var.name))
    error_message = "name: 5-30 caracteres, minúsculas, números y guiones, empezando con letra."
  }
}

variable "k8s_namespace" {
  type    = string
  default = "apps"
}

variable "project_roles" {
  description = "Roles a nivel proyecto. Preferir permisos sobre el recurso puntual cuando existan."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for r in var.project_roles : !contains(["roles/owner", "roles/editor"], r)])
    error_message = "Roles primitivos (owner/editor) no permitidos para workloads."
  }
}

variable "secrets" {
  description = "Nombres cortos de secretos; se crean como <name>-<secreto>."
  type        = list(string)
  default     = []
}

variable "database" {
  description = "Base propia en la instancia de la celda (null = el servicio no usa base)."
  type = object({
    instance = string
    name     = string
  })
  default = null
}

variable "publishes" {
  description = "Topics (de la celda) en los que publica."
  type        = list(string)
  default     = []
}

variable "subscribes" {
  description = "Topics (de la celda) a los que se suscribe; cada uno con su suscripción y DLQ."
  type        = list(string)
  default     = []
}

variable "topic_ids" {
  description = "Mapa nombre -> id de los topics de la celda."
  type        = map(string)
  default     = {}
}
