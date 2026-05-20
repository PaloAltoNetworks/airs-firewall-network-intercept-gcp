################################################################################
# GCP APIs Configuration (apis.tf)
#
# Enables required GCP APIs for the DC MasterClass infrastructure.
# This ensures all necessary services are available before deploying resources.
################################################################################

# Enable Vertex AI API
resource "google_project_service" "vertex_ai" {
  project = var.project_id
  service = "aiplatform.googleapis.com"

  # Prevent disabling the API when the resource is destroyed
  disable_on_destroy = false

  # Allow time for API to propagate
  timeouts {
    create = "10m"
    update = "10m"
  }
}

# Enable Compute Engine API (already implicitly enabled, but explicit for completeness)
resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false

  timeouts {
    create = "10m"
    update = "10m"
  }
}

# Enable Cloud Resource Manager API (for IAM and project operations)
resource "google_project_service" "cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = false

  timeouts {
    create = "10m"
    update = "10m"
  }
}

# Enable Service Usage API (required for enabling other APIs)
resource "google_project_service" "serviceusage" {
  project = var.project_id
  service = "serviceusage.googleapis.com"

  disable_on_destroy = false

  timeouts {
    create = "10m"
    update = "10m"
  }
}

# Enable IAM API
resource "google_project_service" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"

  disable_on_destroy = false

  timeouts {
    create = "10m"
    update = "10m"
  }
}

# Enable Cloud Logging API (for VPC flow log export to GCS)
resource "google_project_service" "logging" {
  project = var.project_id
  service = "logging.googleapis.com"

  disable_on_destroy = false

  timeouts {
    create = "10m"
    update = "10m"
  }
}

# Note: Ensure resources that depend on these APIs wait for them to be enabled
# Use depends_on in other resources as needed
