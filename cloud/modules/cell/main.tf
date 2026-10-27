# Una celda completa: APIs, red, cluster, base, topics y un workload por servicio.
# Cada carpeta de cells/ instancia este módulo con sus valores; las celdas no comparten
# recursos entre sí (cada una en su proyecto y su región), así un incidente o un cambio malo
# queda acotado a una celda.

locals {
  apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "pubsub.googleapis.com",
    "gkehub.googleapis.com",
    "connectgateway.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)
  project  = var.project_id
  service  = each.value
  # Destruir el stack no debe apagar APIs que otros recursos del proyecto pueden estar usando.
  disable_on_destroy = false
}

module "network" {
  source        = "../network"
  project_id    = var.project_id
  name          = var.name
  region        = var.region
  nodes_cidr    = var.cidrs.nodes
  pods_cidr     = var.cidrs.pods
  services_cidr = var.cidrs.services

  depends_on = [google_project_service.apis]
}

module "gke" {
  source                     = "../gke-cell"
  project_id                 = var.project_id
  name                       = var.name
  region                     = var.region
  network_id                 = module.network.network_id
  subnet_id                  = module.network.subnet_id
  pods_range_name            = module.network.pods_range_name
  services_range_name        = module.network.services_range_name
  master_cidr                = var.cidrs.master
  master_authorized_networks = var.master_authorized_networks
  release_channel            = var.gke.release_channel
  node_pool                  = var.gke.node_pool
  deletion_protection        = var.deletion_protection
}

module "cloudsql" {
  source              = "../cloudsql"
  project_id          = var.project_id
  name                = "${var.name}-pg"
  region              = var.region
  network_id          = module.network.network_id
  tier                = var.cloudsql.tier
  high_availability   = var.cloudsql.high_availability
  retained_backups    = var.cloudsql.retained_backups
  deletion_protection = var.deletion_protection

  # La IP privada necesita el peering de Private Service Access ya creado.
  depends_on = [module.network]
}

resource "google_pubsub_topic" "this" {
  for_each                   = toset(var.topics)
  project                    = var.project_id
  name                       = each.value
  message_retention_duration = "86400s"

  # Los mensajes se guardan solo en la región de la celda.
  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }

  depends_on = [google_project_service.apis]
}

module "workload" {
  source   = "../workload"
  for_each = var.workloads

  project_id    = var.project_id
  region        = var.region
  name          = each.key
  project_roles = each.value.project_roles
  secrets       = each.value.secrets
  publishes     = each.value.publishes
  subscribes    = each.value.subscribes
  topic_ids     = { for k, t in google_pubsub_topic.this : k => t.id }
  database = each.value.database ? {
    instance = module.cloudsql.instance_name
    name     = replace(each.key, "-", "_")
  } : null

  # El pool de Workload Identity existe recién cuando existe el cluster.
  depends_on = [module.gke]
}
