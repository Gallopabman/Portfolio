project_id = "stg-platform-1234"
name       = "staging-us-1"
region     = "us-east1"

cidrs = {
  nodes    = "10.40.0.0/20"
  pods     = "10.44.0.0/14"
  services = "10.48.0.0/20"
  master   = "172.16.3.0/28"
}

master_authorized_networks = [
  { name = "ci-runners", cidr = "203.0.113.0/28" },
]

# staging: misma forma que prod (canal, HA de la base, protección contra borrado) a menor escala,
# para que un problema de topología aparezca acá y no en prod.
gke = {
  release_channel = "STABLE"
  node_pool       = { machine_type = "e2-standard-4", min_nodes = 2, max_nodes = 4 }
}
cloudsql = {
  tier              = "db-custom-2-7680"
  high_availability = true
  retained_backups  = 7
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
