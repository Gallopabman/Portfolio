# Todo lo que un microservicio necesita en la nube, declarado en un solo lugar:
#
#   identidad    service account de GCP ligada a su ServiceAccount de Kubernetes (Workload Identity)
#   permisos     solo los roles que pide, a nivel proyecto o sobre el recurso puntual
#   secretos     contenedores en Secret Manager con réplica en la región de la celda; los VALORES no
#                pasan por Terraform (no quedan en el state): se cargan por otro canal
#   base         base propia en la instancia de la celda y usuario IAM (sin contraseña)
#   mensajería   suscripciones con reintentos exponenciales y dead-letter topic
#
# Dar de alta un servicio nuevo = agregar una entrada al mapa `workloads` de la celda.

locals {
  # Las service accounts aceptan 6-30 caracteres.
  account_id = substr(replace(var.name, "_", "-"), 0, 30)
  k8s_member = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.name}]"
  member     = "serviceAccount:${google_service_account.this.email}"
}

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = local.account_id
  display_name = "Workload ${var.name}"
}

# El ServiceAccount de Kubernetes `<namespace>/<name>` puede actuar como esta service account.
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.k8s_member
}

resource "google_project_iam_member" "roles" {
  for_each = toset(var.project_roles)
  project  = var.project_id
  role     = each.value
  member   = local.member
}

# --- Secretos -----------------------------------------------------------------------------------

resource "google_secret_manager_secret" "this" {
  for_each  = toset(var.secrets)
  project   = var.project_id
  secret_id = "${var.name}-${each.value}"

  # Réplica solo en la región de la celda: el dato no sale de la región (residencia de datos).
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    workload = var.name
  }
}

# Acceso por secreto, no por proyecto: el servicio lee únicamente los suyos.
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each  = google_secret_manager_secret.this
  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.member
}

# --- Base de datos --------------------------------------------------------------------------------

resource "google_sql_database" "this" {
  count    = var.database == null ? 0 : 1
  project  = var.project_id
  instance = var.database.instance
  name     = var.database.name
}

# Usuario IAM: el servicio se autentica con el token de su service account. No hay contraseña que
# rotar ni que guardar.
resource "google_sql_user" "iam" {
  count    = var.database == null ? 0 : 1
  project  = var.project_id
  instance = var.database.instance
  name     = trimsuffix(google_service_account.this.email, ".gserviceaccount.com")
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_project_iam_member" "sql" {
  for_each = var.database == null ? toset([]) : toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])
  project  = var.project_id
  role     = each.value
  member   = local.member
}

# --- Pub/Sub ---------------------------------------------------------------------------------------

resource "google_pubsub_topic_iam_member" "publisher" {
  for_each = toset(var.publishes)
  project  = var.project_id
  topic    = var.topic_ids[each.value]
  role     = "roles/pubsub.publisher"
  member   = local.member
}

resource "google_pubsub_topic" "dead_letter" {
  for_each                   = toset(var.subscribes)
  project                    = var.project_id
  name                       = "${var.name}-${each.value}-dlq"
  message_retention_duration = "604800s"
}

resource "google_pubsub_subscription" "this" {
  for_each             = toset(var.subscribes)
  project              = var.project_id
  name                 = "${var.name}-${each.value}"
  topic                = var.topic_ids[each.value]
  ack_deadline_seconds = 60

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  # Tras 5 entregas fallidas el mensaje va a la DLQ en vez de bloquear la cola para siempre.
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter[each.value].id
    max_delivery_attempts = 5
  }

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_subscription_iam_member" "subscriber" {
  for_each     = google_pubsub_subscription.this
  project      = var.project_id
  subscription = each.value.name
  role         = "roles/pubsub.subscriber"
  member       = local.member
}

# Error clásico con dead-letter: el agente de servicio de Pub/Sub necesita publicar en la DLQ y
# suscribirse a la suscripción de origen. Sin estos permisos los mensajes nunca llegan a la DLQ.
data "google_project" "this" {
  project_id = var.project_id
}

locals {
  pubsub_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_topic_iam_member" "dlq_agent_publisher" {
  for_each = google_pubsub_topic.dead_letter
  project  = var.project_id
  topic    = each.value.id
  role     = "roles/pubsub.publisher"
  member   = local.pubsub_agent
}

resource "google_pubsub_subscription_iam_member" "dlq_agent_subscriber" {
  for_each     = google_pubsub_subscription.this
  project      = var.project_id
  subscription = each.value.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}
