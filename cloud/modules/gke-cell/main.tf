# Cluster GKE de una celda.
#   - Nodos privados (sin IP pública); el plano de control solo acepta las redes autorizadas.
#     El acceso operativo es por Connect Gateway (el cluster se registra en la flota).
#   - Workload Identity: cada pod usa su propia service account de GCP, sin llaves.
#   - Dataplane V2 (eBPF) con NetworkPolicy nativa.
#   - Canal de releases y ventana de mantenimiento fuera del horario de uso.
#   - Node pool propio con service account mínima (no la default de Compute).

resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.name}-nodes"
  display_name = "Nodos GKE ${var.name}"
}

# Lo mínimo para que el nodo escriba logs/métricas y baje imágenes del registry.
resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region

  network    = var.network_id
  subnetwork = var.subnet_id

  # El pool default no se puede configurar bien; se borra y se usa uno propio.
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.deletion_protection
  datapath_provider   = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Registro en la flota: habilita Connect Gateway (kubectl sin exponer el endpoint).
  fleet {
    project = var.project_id
  }

  release_channel {
    channel = var.release_channel
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  maintenance_policy {
    recurring_window {
      start_time = "2026-01-01T03:00:00Z"
      end_time   = "2026-01-01T07:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  enable_shielded_nodes = true
}

resource "google_container_node_pool" "workload" {
  project  = var.project_id
  name     = "workload"
  location = var.region
  cluster  = google_container_cluster.this.name

  autoscaling {
    min_node_count = var.node_pool.min_nodes
    max_node_count = var.node_pool.max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrades sin perder capacidad: primero sube un nodo nuevo, después baja uno viejo.
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.node_pool.machine_type
    disk_size_gb    = var.node_pool.disk_size_gb
    spot            = var.node_pool.spot
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      cell = var.name
    }
  }
}
