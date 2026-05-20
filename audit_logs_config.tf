################################################################################
# Audit Logs Configuration (audit_logs_config.tf)
#
# Enables Data Access Audit Logs for Vertex AI to capture AI model interactions.
#
# Required for Palo Alto AI Runtime Security Discovery:
# - Tracks all Vertex AI model prediction requests (generateContent, streamGenerateContent)
# - Captures feature store queries and list/get operations
# - Provides compliance audit trail for AI workloads
#
# Reference: https://docs.paloaltonetworks.com/ai-runtime-security/administration/discover-your-cloud-resources
################################################################################

# Enable Data Access Audit Logs for Vertex AI
# This allows Palo Alto AI Runtime Security to discover and monitor AI model usage
resource "google_project_iam_audit_config" "vertex_ai_audit" {
  project = var.project_id
  service = "aiplatform.googleapis.com"

  # DATA_READ: Captures model prediction calls (generateContent, streamGenerateContent)
  # Critical for tracking Gemini model usage in the RAG application
  audit_log_config {
    log_type = "DATA_READ"
  }

  # DATA_WRITE: Captures data modifications (model uploads, dataset writes)
  audit_log_config {
    log_type = "DATA_WRITE"
  }

  # ADMIN_READ: Captures list/get operations on Vertex AI resources
  audit_log_config {
    log_type = "ADMIN_READ"
  }

  depends_on = [google_project_service.vertex_ai]
}
