output "cluster_name" {
  value = google_container_cluster.this.name
}

output "cluster_id" {
  value = google_container_cluster.this.id
}

output "workload_pool" {
  value = "${var.project_id}.svc.id.goog"
}

# Comando para conectarse por Connect Gateway (no requiere red al endpoint del cluster).
output "connect_command" {
  value = "gcloud container fleet memberships get-credentials ${google_container_cluster.this.name} --project ${var.project_id}"
}
