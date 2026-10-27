project_id = "prd-platform-eu-1234"
name       = "prod-eu-1"
region     = "europe-west1"

# Rangos distintos de los de prod-us-1: si algún día se interconectan las celdas, no pueden solaparse.
cidrs = {
  nodes    = "10.30.0.0/20"
  pods     = "10.32.0.0/14"
  services = "10.36.0.0/20"
  master   = "172.16.2.0/28"
}

master_authorized_networks = [
  { name = "ci-runners", cidr = "203.0.113.0/28" },
]

gke = {
  release_channel = "STABLE"
  node_pool       = { machine_type = "n2-standard-4", min_nodes = 3, max_nodes = 9 }
}
cloudsql = {
  tier              = "db-custom-4-15360"
  high_availability = true
  retained_backups  = 30
}

topics = ["order-events"]

# eu-1 todavía no tiene pagos (igual que en el repo de GitOps): el servicio se habilita por celda.
workloads = {
  orders-api = {
    database  = true
    secrets   = ["jwt-signing-key"]
    publishes = ["order-events"]
  }
}
