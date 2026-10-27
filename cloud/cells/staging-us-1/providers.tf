terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.14"
    }
  }

  # Un state por celda, en un bucket por proyecto con versionado. Un plan o un apply nunca toca
  # más de una celda a la vez.
  backend "gcs" {
    bucket = "stg-platform-1234-tfstate"
    prefix = "cells/staging-us-1"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    cell       = var.name
    managed-by = "terraform"
  }
}
