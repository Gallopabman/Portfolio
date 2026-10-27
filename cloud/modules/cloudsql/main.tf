# PostgreSQL administrado de una celda.
#   - Solo IP privada (sin IP pública) y TLS obligatorio.
#   - Autenticación IAM habilitada: los servicios se conectan con su service account, sin contraseña.
#   - Backups diarios + PITR. HA regional (réplica en otra zona con failover) donde se pida.
#   - deletion_protection en las dos capas: la API de GCP y Terraform.

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = var.name
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier                        = var.tier
    edition                     = "ENTERPRISE"
    availability_type           = var.high_availability ? "REGIONAL" : "ZONAL"
    disk_autoresize             = true
    deletion_protection_enabled = var.deletion_protection

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      ssl_mode                                      = "ENCRYPTED_ONLY"
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "04:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = var.retained_backups
      }
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    # Auditoría y diagnóstico: conexiones, esperas por locks, checkpoints, archivos temporales
    # (queries que no entran en memoria) y queries de más de 1 s.
    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = false
    }

    maintenance_window {
      day          = 7
      hour         = 5
      update_track = "stable"
    }
  }
}
