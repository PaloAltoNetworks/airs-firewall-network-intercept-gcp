################################################################################
# 10. IAM FOR VERTEX AI (iam_vertex_ai.tf)
#
# GCP equivalent of iam_bedrock.tf.
#
# AWS → GCP mapping:
#   aws_iam_role "bedrock_ec2_role"       → google_service_account "vertex_ai_sa"
#   aws_iam_policy "bedrock_policy"       → google_project_iam_member (built-in role)
#   aws_iam_role_policy_attachment        → google_project_iam_member
#   aws_iam_instance_profile              → service_account block on the VM resource
#
# NOTE: In GCP, EC2 instance profiles are replaced by Service Accounts.
# The VM is assigned a Service Account at creation time, and IAM bindings
# grant that Service Account permissions on GCP services.
#
# AWS Bedrock (bedrock:InvokeModel) → GCP Vertex AI (aiplatform.endpoints.predict)
# The closest built-in role is "roles/aiplatform.user" which grants permissions
# to invoke models (predict, explain, etc.).
################################################################################

# --- Service Account (equivalent to IAM Role for EC2) ---
resource "google_service_account" "vertex_ai_sa" {
  account_id   = "vertex-ai-sa-hq-dc"
  display_name = "Vertex AI Service Account - HQ DC"
  description  = "Allows LLM web server VMs to invoke Vertex AI models. Equivalent to bedrock-ec2-role."
  project      = var.project_id
}

# --- Grant Vertex AI User role to the Service Account ---
# Equivalent to the bedrock_policy allowing bedrock:InvokeModel on Resource: "*"
# roles/aiplatform.user grants: predict, explain, countTokens, etc.
resource "google_project_iam_member" "vertex_ai_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.vertex_ai_sa.email}"

  # Ensure Vertex AI API is enabled before granting permissions
  depends_on = [google_project_service.vertex_ai]
}

# --- Optional: Grant Storage Object Viewer for model artifacts ---
# Vertex AI models may need to read from GCS. Uncomment if needed.
# resource "google_project_iam_member" "vertex_ai_storage_reader" {
#   project = var.project_id
#   role    = "roles/storage.objectViewer"
#   member  = "serviceAccount:${google_service_account.vertex_ai_sa.email}"
# }
