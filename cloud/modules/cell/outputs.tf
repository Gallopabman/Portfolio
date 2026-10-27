output "cluster_name" {
  value = module.gke.cluster_name
}

output "connect_command" {
  value = module.gke.connect_command
}

output "cloudsql_connection_name" {
  value = module.cloudsql.connection_name
}

# Lo que necesita el repo de GitOps para cada servicio: la service account para la anotación de
# Workload Identity y los ids de sus secretos para el ExternalSecret.
output "workloads" {
  value = {
    for k, w in module.workload : k => {
      service_account = w.service_account_email
      secrets         = w.secret_ids
      database_user   = w.database_user
      subscriptions   = w.subscriptions
    }
  }
}
