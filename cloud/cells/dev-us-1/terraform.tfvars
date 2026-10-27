project_id = "dev-platform-1234"
name       = "dev-us-1"
region     = "us-east1"

cidrs = {
  nodes    = "10.10.0.0/20"
  pods     = "10.12.0.0/14"
  services = "10.16.0.0/20"
  master   = "172.16.0.0/28"
}

master_authorized_networks = [
  { name = "ci-runners", cidr = "203.0.113.0/28" },
]

# dev: canal RAPID (las incompatibilidades de una versión nueva de GKE aparecen acá primero),
# nodos spot y base sin HA. Sin deletion_protection: el ambiente se puede recrear.
gke = {
  release_channel = "RAPID"
  node_pool       = { machine_type = "e2-standard-4", min_nodes = 1, max_nodes = 3, spot = true }
}
cloudsql = {
  tier              = "db-custom-1-3840"
  high_availability = false
  retained_backups  = 3
}
deletion_protection = false

topics = ["order-events"]

workloads = {
  orders-api = {
    database  = true
    secrets   = ["jwt-signing-key"]
    publishes = ["order-events"]
  }
  payments-api = {
    database      = true
    secrets       = ["provider-api-key"]
    subscribes    = ["order-events"]
    project_roles = ["roles/cloudtrace.agent"]
  }
}
