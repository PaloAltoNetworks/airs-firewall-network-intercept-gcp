################################################################################
# 6. STATIC EXTERNAL IPs (static_ips.tf)
#
# GCP equivalent of AWS Elastic IPs (aws_eip).
# In GCP, static external IPs are reserved with google_compute_address and
# then assigned to instance network interfaces directly in the VM resource.
#
# AWS → GCP mapping:
#   aws_eip "fw_internet_eip"    → google_compute_address "fw_internet_eip"
#   aws_eip "fw_management_eip"  → google_compute_address "fw_management_eip"
#   aws_eip "ai_server_eip"      → google_compute_address "ai_server_eip"
#
# NOTE: There is no separate "EIP association" resource in GCP — the static IP
# is referenced directly in the network_interface.access_config block of the VM.
################################################################################

# --- Static IP for Palo Alto Firewall Internet Interface (Untrust) ---
# CONDITIONAL: Only created in Phase 2 when PA firewall is deployed
resource "google_compute_address" "fw_internet_eip" {
  count  = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name   = "eip-fw-internet"
  region = var.region

  description = "PHASE 2: Static external IP for the Palo Alto firewall internet-facing (Untrust) interface."

  # PREMIUM tier = static, globally routed (recommended for production)
  network_tier = "PREMIUM"
}

# --- Static IP for Palo Alto Firewall Management Interface ---
# CONDITIONAL: Only created in Phase 2 when PA firewall is deployed
resource "google_compute_address" "fw_management_eip" {
  count  = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name   = "eip-fw-management"
  region = var.region

  description = "PHASE 2: Static external IP for the Palo Alto firewall management interface (admin access from admin IP only)."

  network_tier = "PREMIUM"
}

# --- Static IP for AI Server ---
resource "google_compute_address" "ai_server_eip" {
  name   = "eip-ai-server"
  region = var.region

  description = "Static external IP for the AI Server (admin access from admin IP only)."

  network_tier = "PREMIUM"
}
