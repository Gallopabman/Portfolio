output "instance_name" {
  value = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Lo usa el Cloud SQL Auth Proxy / los conectores de cada lenguaje."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip" {
  value = google_sql_database_instance.this.private_ip_address
}
