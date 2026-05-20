################################################################################
# 8. OUTPUTS (outputs.tf)
#
# Defines output values displayed after a successful terraform apply.
################################################################################

# ---------------------------------------------------------------------------
# Palo Alto Firewall Outputs
# ---------------------------------------------------------------------------

output "palo_alto_firewall_internet_public_ip" {
  description = "Public IP of the Palo Alto Firewall's internet-facing (Untrust) interface (nic1). Only available in Phase 2."
  value       = var.enable_palo_alto_firewall ? google_compute_address.fw_internet_eip[0].address : "N/A (Phase 1 - Firewall not deployed)"
}

output "palo_alto_firewall_management_public_ip" {
  description = "Public IP of the Palo Alto Firewall's management interface (nic0) for admin access. Only available in Phase 2."
  value       = var.enable_palo_alto_firewall ? google_compute_address.fw_management_eip[0].address : "N/A (Phase 1 - Firewall not deployed)"
}

output "palo_alto_firewall_management_private_ip" {
  description = "Private IP of the Palo Alto Firewall's management interface (nic0). Only available in Phase 2."
  value       = var.enable_palo_alto_firewall ? "172.16.61.10" : "N/A (Phase 1 - Firewall not deployed)"
}

output "palo_alto_firewall_management_url" {
  description = "Direct HTTPS URL to access PA firewall management interface (restricted to admin IP). Only available in Phase 2."
  value       = var.enable_palo_alto_firewall ? "https://${google_compute_address.fw_management_eip[0].address}" : "N/A (Phase 1 - Firewall not deployed)"
}

# ---------------------------------------------------------------------------
# AI Server Outputs
# ---------------------------------------------------------------------------

output "ai_server_public_ip" {
  description = "Public IP address of the AI Server (restricted to admin IP for SSH and Streamlit access)"
  value       = google_compute_address.ai_server_eip.address
}

output "ai_server_private_ip" {
  description = "Private IP of the AI Server in the Trust subnet (172.16.2.0/24)"
  value       = google_compute_instance.web_server.network_interface[0].network_ip
}

output "deployment_phase" {
  description = "Current deployment phase: Phase 1 (Unprotected) or Phase 2 (PA Firewall Protected)"
  value       = var.enable_palo_alto_firewall ? "Phase 2: Protected by Palo Alto Firewall" : "Phase 1: Unprotected (No Firewall)"
}

output "vertex_ai_service_account_email" {
  description = "Email of the Service Account attached to the AI Server for Vertex AI access"
  value       = google_service_account.vertex_ai_sa.email
}

# ---------------------------------------------------------------------------
# Network Infrastructure Outputs
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "Self-link of the HQ-DC VPC."
  value       = google_compute_network.vpc_hq.self_link
}

# ---------------------------------------------------------------------------
# Cloud Logging Storage Outputs (VPC Flow + Vertex AI Audit Logs)
# ---------------------------------------------------------------------------

output "cloud_logs_bucket" {
  description = "GCS bucket storing VPC flow logs and Vertex AI audit logs for Palo Alto AI Runtime Security"
  value       = google_storage_bucket.vpc_flow_logs.name
}

output "cloud_logs_bucket_url" {
  description = "GCS bucket URL for cloud logs (VPC flow + Vertex AI audit logs)"
  value       = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.vpc_flow_logs.name}"
}

output "cloud_logs_sink_name" {
  description = "Name of the Cloud Logging sink exporting VPC flow logs and Vertex AI audit logs to GCS"
  value       = google_logging_project_sink.cloud_logs_sink.name
}

output "cloud_logs_sink_writer_identity" {
  description = "Service account identity used by cloud logs sink (auto-managed by GCP)"
  value       = google_logging_project_sink.cloud_logs_sink.writer_identity
}

# ---------------------------------------------------------------------------
# Streamlit RAG Application Outputs
# ---------------------------------------------------------------------------

output "streamlit_application_url" {
  description = "URL to access the Streamlit RAG application (accessible from admin IP)"
  value       = "http://${google_compute_address.ai_server_eip.address}:8501"
}

output "ai_server_ssh_command" {
  description = "SSH command to access the AI Server directly (from admin IP only)"
  value       = "ssh ubuntu@${google_compute_address.ai_server_eip.address}"
}

output "streamlit_deployment_status_command" {
  description = "SSH command to check the Streamlit application deployment status"
  value       = "ssh ubuntu@${google_compute_address.ai_server_eip.address} 'sudo cat /var/log/streamlit-deployment.log'"
}

output "streamlit_service_status_command" {
  description = "SSH command to check the Streamlit service status"
  value       = "ssh ubuntu@${google_compute_address.ai_server_eip.address} 'sudo systemctl status streamlit-rag'"
}

output "streamlit_application_logs_command" {
  description = "SSH command to view live Streamlit application logs"
  value       = "ssh ubuntu@${google_compute_address.ai_server_eip.address} 'sudo journalctl -u streamlit-rag -f'"
}

output "access_instructions" {
  description = "Complete access instructions for the DC MasterClass infrastructure"
  value       = <<-EOT
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║              DC MASTERCLASS - INFRASTRUCTURE ACCESS                       ║
    ╚═══════════════════════════════════════════════════════════════════════════╝

    🌐 ARCHITECTURE OVERVIEW:
    ───────────────────────────────────────────────────────────────────────────
    • AI Server: Public IP (restricted to admin IP ${var.admin_source_ip})
    • PA Firewall Management: Public IP (restricted to admin IP, Phase 2 only)
    • Outbound traffic inspection: AI Server → PA Firewall → Internet
    • No Bastion host - Direct admin access to resources

    📌 AI SERVER ACCESS (Always Available):
    ───────────────────────────────────────────────────────────────────────────
    Public IP:        ${google_compute_address.ai_server_eip.address}
    Private IP:       ${google_compute_instance.web_server.network_interface[0].network_ip}

    • Streamlit App:  http://${google_compute_address.ai_server_eip.address}:8501
    • SSH Access:     ssh ubuntu@${google_compute_address.ai_server_eip.address}

    IMPORTANT: Only accessible from admin IP ${var.admin_source_ip}

    🔧 PA FIREWALL MANAGEMENT (Phase 2 Only):
    ───────────────────────────────────────────────────────────────────────────
    ${var.enable_palo_alto_firewall ? "Management URL:  https://${google_compute_address.fw_management_eip[0].address}\nPublic IP:       ${google_compute_address.fw_management_eip[0].address}\nPrivate IP:      172.16.61.10\n\nIMPORTANT: Only accessible from admin IP ${var.admin_source_ip}" : "N/A - PA Firewall not deployed in Phase 1"}

    📊 DEPLOYMENT STATUS COMMANDS:
    ───────────────────────────────────────────────────────────────────────────
    Check deployment logs:
      ssh ubuntu@${google_compute_address.ai_server_eip.address} 'sudo cat /var/log/streamlit-deployment.log'

    Check service status:
      ssh ubuntu@${google_compute_address.ai_server_eip.address} 'sudo systemctl status streamlit-rag'

    View live logs:
      ssh ubuntu@${google_compute_address.ai_server_eip.address} 'sudo journalctl -u streamlit-rag -f'

    🔐 SECURITY MODEL:
    ───────────────────────────────────────────────────────────────────────────
    Inbound Traffic:
      • Admin IP → AI Server: Direct (bypasses PA firewall)
      • Admin IP → PA Management: Direct (Phase 2 only)

    Outbound Traffic (includes Vertex AI API):
      • AI Server → PA Trust (172.16.2.10) → PA Untrust → Internet
      • ✅ INSPECTED by PA firewall (SSL decryption, AI Security profiles)

    Current Phase: ${var.enable_palo_alto_firewall ? "Phase 2 (Protected by PA Firewall)" : "Phase 1 (Unprotected)"}

    Traffic Inspection: ${var.enable_palo_alto_firewall ? "✅ All outbound traffic from AI Server inspected by PA Firewall" : "❌ No firewall inspection in Phase 1"}
  EOT
}

