# Bootstrap de un proyecto: lo que tiene que existir ANTES de poder gestionar una celda con
# Terraform desde la CI. Se aplica una vez por proyecto, a mano, con state local (es el huevo y la
# gallina: el bucket del state no puede guardar el state que lo crea). Después se puede migrar su
# state al bucket con `terraform init -migrate-state`.
#
#   1. Bucket del state: versionado (se puede volver a un state anterior), acceso uniforme, nunca
#      público.
#   2. Workload Identity Federation para GitHub Actions: la CI se autentica con el token OIDC del
#      job. No hay llaves de service account guardadas como secretos de GitHub.
#   3. Dos service accounts: una de solo lectura para los `plan` de los PR y otra para el `apply`,
#      que solo pueden usar los jobs de la rama main (y en prod, con aprobación del environment).

terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.14"
    }
  }
}

provider "google" {
  project = var.project_id
}

variable "project_id" {
  type = string
}

variable "state_location" {
  description = "Región del bucket del state (la misma de la celda)."
  type        = string
}

variable "github_repository" {
  description = "owner/repo autorizado a autenticarse."
  type        = string
}

resource "google_project_service" "apis" {
  for_each           = toset(["iam.googleapis.com", "iamcredentials.googleapis.com", "sts.googleapis.com", "storage.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_id}-tfstate"
  location                    = var.state_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  # Se guardan las últimas 20 versiones de cada state.
  lifecycle_rule {
    condition {
      num_newer_versions = 20
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Sin esta condición, cualquier repositorio de GitHub podría pedir tokens a este pool.
  attribute_condition = "assertion.repository == \"${var.github_repository}\""
}

locals {
  repo_principal = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# --- plan: solo lectura, cualquier job del repo (incluidos los PR) ---------------------------------

resource "google_service_account" "plan" {
  account_id   = "terraform-plan"
  display_name = "Terraform plan (CI, solo lectura)"
}

resource "google_project_iam_member" "plan" {
  for_each = toset(["roles/viewer", "roles/iam.securityReviewer", "roles/secretmanager.viewer"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.plan.email}"
}

resource "google_storage_bucket_iam_member" "plan_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectUser" # el plan toma el lock del state
  member = "serviceAccount:${google_service_account.plan.email}"
}

resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.repo_principal
}

# --- apply: escritura, solo desde main ---------------------------------------------------------

resource "google_service_account" "apply" {
  account_id   = "terraform-apply"
  display_name = "Terraform apply (CI, solo rama main)"
}

# serviceAccountUser a nivel proyecto: el apply necesita "actAs" sobre las service accounts que él
# mismo crea (nodos de GKE). Está acotado a la SA de apply, que solo usan jobs de main.
#trivy:ignore:AVD-GCP-0011
resource "google_project_iam_member" "apply" {
  for_each = toset([
    "roles/compute.networkAdmin",
    "roles/container.admin",
    "roles/cloudsql.admin",
    "roles/secretmanager.admin",
    "roles/pubsub.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/servicenetworking.networksAdmin",
    "roles/gkehub.admin",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.apply.email}"
}

resource "google_storage_bucket_iam_member" "apply_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.apply.email}"
}

# Solo los tokens de jobs que corren sobre refs/heads/main pueden impersonar a la de apply. Alcanza
# con filtrar por ref porque el attribute_condition del provider ya restringe el pool a este repo.
resource "google_service_account_iam_member" "apply_wif" {
  service_account_id = google_service_account.apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.ref/refs/heads/main"
}

output "wif_provider" {
  description = "Va en la variable GCP_WIF_PROVIDER del repo de GitHub."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "plan_service_account" {
  value = google_service_account.plan.email
}

output "apply_service_account" {
  value = google_service_account.apply.email
}
