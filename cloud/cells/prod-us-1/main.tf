module "cell" {
  source = "../../modules/cell"

  project_id                 = var.project_id
  name                       = var.name
  region                     = var.region
  cidrs                      = var.cidrs
  master_authorized_networks = var.master_authorized_networks
  gke                        = var.gke
  cloudsql                   = var.cloudsql
  topics                     = var.topics
  workloads                  = var.workloads
  deletion_protection        = var.deletion_protection
}

output "cell" {
  value = {
    cluster         = module.cell.cluster_name
    connect_command = module.cell.connect_command
    cloudsql        = module.cell.cloudsql_connection_name
    workloads       = module.cell.workloads
  }
}
