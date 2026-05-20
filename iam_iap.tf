################################################################################
# IAM PERMISSIONS FOR IDENTITY-AWARE PROXY (IAP)
#
# Grants users the ability to access Compute Engine VMs via IAP tunneling.
# This enables browser-based SSH from the GCP Console and gcloud SSH with --tunnel-through-iap.
#
# Reference: https://cloud.google.com/iap/docs/using-tcp-forwarding
################################################################################

# Grant IAP tunnel access to authorized users
# This allows them to SSH to VMs via GCP Console or gcloud CLI using IAP
resource "google_project_iam_binding" "iap_tunnel_user" {
  count   = length(var.iap_authorized_users) > 0 ? 1 : 0
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"

  members = var.iap_authorized_users
}
