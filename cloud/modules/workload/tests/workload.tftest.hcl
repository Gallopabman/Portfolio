# Los valores computados se fijan con formato válido: los aleatorios del mock no pasan las
# validaciones del provider (p.ej. el formato del nombre de una service account).
mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "123456789012"
    }
  }
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/test-project-1234/serviceAccounts/mock-sa@test-project-1234.iam.gserviceaccount.com"
      email = "mock-sa@test-project-1234.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_sql_database_instance" {
    defaults = {
      name = "dev-us-1-pg"
    }
  }
}

variables {
  project_id = "test-project-1234"
  region     = "us-east1"
  name       = "orders-api"
}

run "no_permite_roles_primitivos" {
  command = plan

  variables {
    project_roles = ["roles/editor"]
  }

  expect_failures = [var.project_roles]
}

run "workload_identity_apunta_al_ksa_correcto" {
  command = plan

  variables {
    k8s_namespace = "apps"
  }

  assert {
    condition     = google_service_account_iam_member.workload_identity.member == "serviceAccount:test-project-1234.svc.id.goog[apps/orders-api]"
    error_message = "El binding de Workload Identity debería apuntar a apps/orders-api."
  }
}

run "secretos_replicados_solo_en_la_region" {
  command = plan

  variables {
    secrets = ["jwt-signing-key"]
  }

  assert {
    condition     = one(one(google_secret_manager_secret.this["jwt-signing-key"].replication[0].user_managed).replicas).location == "us-east1"
    error_message = "El secreto debería replicarse solo en la región de la celda."
  }
}

run "dlq_con_permisos_del_agente_de_pubsub" {
  command = apply

  variables {
    subscribes = ["order-events"]
    topic_ids  = { "order-events" = "projects/test-project-1234/topics/order-events" }
  }

  assert {
    condition     = google_pubsub_topic_iam_member.dlq_agent_publisher["order-events"].member == "serviceAccount:service-123456789012@gcp-sa-pubsub.iam.gserviceaccount.com"
    error_message = "El agente de Pub/Sub necesita publicar en la DLQ."
  }

  assert {
    condition     = google_pubsub_subscription.this["order-events"].dead_letter_policy[0].max_delivery_attempts == 5
    error_message = "La suscripción debería mandar a la DLQ tras 5 intentos."
  }
}
