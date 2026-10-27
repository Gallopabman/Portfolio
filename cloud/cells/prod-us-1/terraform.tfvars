project_id = "prd-platform-1234"
name       = "prod-us-1"
region     = "us-east1"

cidrs = {
  nodes    = "10.20.0.0/20"
  pods     = "10.24.0.0/14"
  services = "10.28.0.0/20"
  master   = "172.16.1.0/28"
}

master_authorized_networks = [
  { name = "ci-runners", cidr = "203.0.113.0/28" },
]

# prod: canal STABLE, nodos on-demand, Cloud SQL con HA regional y 30 backups.
gke = {
  release_channel = "STABLE"
  node_pool       = { machine_type = "n2-standard-8", min_nodes = 3, max_nodes = 15 }
}
cloudsql = {
  tier              = "db-custom-8-30720"
  high_availability = true
  retained_backups  = 30
}

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
