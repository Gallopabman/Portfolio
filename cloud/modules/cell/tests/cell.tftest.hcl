# Tests del módulo cell con el provider simulado: corren en segundos, sin credenciales y sin crear
# nada en GCP. Cubren el cableado entre módulos y las reglas de validación.

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
  mock_resource "google_compute_network" {
    defaults = {
      id = "projects/test-project-1234/global/networks/dev-us-1"
    }
  }
  mock_resource "google_compute_subnetwork" {
    defaults = {
      id = "projects/test-project-1234/regions/us-east1/subnetworks/dev-us-1-us-east1"
    }
  }
  mock_resource "google_pubsub_topic" {
    defaults = {
      id = "projects/test-project-1234/topics/order-events"
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
  name       = "dev-us-1"
  region     = "us-east1"
  cidrs = {
    nodes    = "10.0.0.0/20"
    pods     = "10.4.0.0/14"
    services = "10.8.0.0/20"
    master   = "172.16.0.0/28"
  }
  gke = {
    release_channel = "RAPID"
    node_pool       = { machine_type = "e2-standard-4", min_nodes = 1, max_nodes = 3 }
  }
  cloudsql = {
    tier              = "db-custom-1-3840"
    high_availability = false
  }
  deletion_protection = false
  topics              = ["order-events"]
  workloads = {
    orders-api = {
      database  = true
      secrets   = ["jwt-signing-key"]
      publishes = ["order-events"]
    }
    payments-api = {
      subscribes = ["order-events"]
    }
  }
}

run "celda_completa" {
  command = apply

  assert {
    condition     = length(output.workloads) == 2
    error_message = "Debería haber un workload por servicio."
  }

  assert {
    condition     = output.workloads["payments-api"].subscriptions["order-events"] == "payments-api-order-events"
    error_message = "La suscripción debería llamarse <servicio>-<topic>."
  }

  assert {
    condition     = output.workloads["orders-api"].secrets["jwt-signing-key"] == "orders-api-jwt-signing-key"
    error_message = "Los secretos deberían llevar el prefijo del servicio."
  }

  assert {
    condition     = output.workloads["payments-api"].database_user == null
    error_message = "Un servicio sin database no debería tener usuario en la base."
  }
}

run "rechaza_topic_no_declarado" {
  command = plan

  variables {
    workloads = {
      orders-api = { publishes = ["topic-inexistente"] }
    }
  }

  expect_failures = [var.workloads]
}

run "rechaza_nombre_de_celda_invalido" {
  command = plan

  variables {
    name = "produccion"
  }

  expect_failures = [var.name]
}
