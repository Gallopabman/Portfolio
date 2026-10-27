output "service_account_email" {
  description = "Va en la anotación iam.gke.io/gcp-service-account del ServiceAccount de Kubernetes."
  value       = google_service_account.this.email
}

output "secret_ids" {
  value = { for k, s in google_secret_manager_secret.this : k => s.secret_id }
}

output "database_user" {
  value = try(google_sql_user.iam[0].name, null)
}

output "subscriptions" {
  value = { for k, s in google_pubsub_subscription.this : k => s.name }
}
