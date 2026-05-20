################################################################################
# 1. PROVIDER CONFIGURATION (provider.tf)
#
# Configures the Google Cloud provider.
# GCP asia-south1 (Mumbai)
################################################################################

terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  credentials = var.credentials_file != null ? file(var.credentials_file) : null
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}
