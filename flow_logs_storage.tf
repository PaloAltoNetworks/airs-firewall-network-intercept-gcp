################################################################################
# Cloud Logging Storage (flow_logs_storage.tf)
#
# Exports cloud logs from Cloud Logging to a GCS bucket for long-term storage
# and analysis. This includes:
#   - VPC Flow Logs: Network traffic from all subnets (enabled in vpc.tf)
#   - Vertex AI Audit Logs: AI model prediction requests and admin operations
#
# Required for Palo Alto AI Runtime Security Discovery:
#   - VPC Flow Logs: Discover non-AI cloud assets (VMs, Containers)
#   - Data Access Audit Logs: Discover and analyze Vertex AI model calls
#
# Reference: https://docs.paloaltonetworks.com/ai-runtime-security/activation-and-onboarding/onboard-and-activate-cloud-account-in-scm/gcp-onboarding-prereq-and-steps/discovery-onboarding-prerequisites-for-gcp
################################################################################

# GCS Bucket for VPC Flow Logs
resource "google_storage_bucket" "vpc_flow_logs" {
  name          = "dc-master-${var.userid}"
  location      = var.region
  storage_class = "STANDARD"

  # Auto-delete logs older than 90 days
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  # Optional: Transition to cheaper storage after 30 days
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Allow deletion of bucket with logs during terraform destroy
  force_destroy = true

  # Enable versioning for data protection
  versioning {
    enabled = true
  }

  # Uniform bucket-level access (recommended)
  uniform_bucket_level_access = true

  labels = {
    app         = var.ccoe_app
    environment = var.ccoe_group
    owner       = var.userid
    purpose     = "cloud-logs"
  }
}

# Log Sink - Exports Cloud Logs (VPC Flow + Vertex AI Audit) to GCS Bucket
# Combined filter approach per Palo Alto AI Runtime Security documentation
resource "google_logging_project_sink" "cloud_logs_sink" {
  name        = "cloud-logs-to-gcs"
  description = "Export VPC flow logs and Vertex AI audit logs to GCS bucket for Palo Alto AI Runtime Security discovery"

  # Destination: GCS bucket created above
  destination = "storage.googleapis.com/${google_storage_bucket.vpc_flow_logs.name}"

  # Combined Filter: Captures both VPC flow logs AND Vertex AI audit logs
  # Simplified for demo/lab environment - captures all VPC flow logs from all subnets
  #
  # Part 1: Vertex AI Data Access Audit Logs (AI model prediction requests)
  # Part 2: VPC Flow Logs (network traffic from ALL subnets)
  filter = <<-EOT
    (logName =~ "logs/cloudaudit.googleapis.com%2Fdata_access"
     AND protoPayload.methodName:("google.cloud.aiplatform."))
    OR
    logName=~"projects/${var.project_id}/logs/compute.googleapis.com%2Fvpc_flows"
  EOT

  # Use unique writer identity for better security
  unique_writer_identity = true

  depends_on = [
    google_project_service.logging,
    google_project_iam_audit_config.vertex_ai_audit
  ]
}

# Grant Log Sink permission to write to GCS bucket
resource "google_storage_bucket_iam_member" "cloud_logs_writer" {
  bucket = google_storage_bucket.vpc_flow_logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.cloud_logs_sink.writer_identity

  depends_on = [
    google_logging_project_sink.cloud_logs_sink
  ]
}
