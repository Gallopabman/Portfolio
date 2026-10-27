output "network_id" {
  value = google_compute_network.this.id
}

output "network_name" {
  value = google_compute_network.this.name
}

output "subnet_id" {
  value = google_compute_subnetwork.nodes.id
}

output "pods_range_name" {
  value = "pods"
}

output "services_range_name" {
  value = "services"
}

# Cloud SQL con IP privada no se puede crear hasta que el peering exista: quien consuma este
# output hereda la dependencia.
output "private_services_connection" {
  value = google_service_networking_connection.private_services.id
}
