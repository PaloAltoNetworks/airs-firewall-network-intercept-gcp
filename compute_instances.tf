################################################################################
# 7. COMPUTE INSTANCES (compute_instances.tf)
#
#  1. Multi-NIC: GCP supports multiple network_interface blocks directly on
#     the VM resource — no separate ENI resource needed (unlike aws_network_interface).
#     The first interface (nic0) is always the primary/boot interface.
#
#  2. source_dest_check = false (AWS) → can_ip_forward = true on the VM resource.
#     In GCP this is a VM-level flag, not per-interface.
#
#  3. Security groups → Network tags. Each VM has tags that match firewall rules.
#
#  4. Static IPs → Assigned in access_config { nat_ip = ... } blocks within
#     network_interface, referencing google_compute_address resources.
#
#  5. IAM instance profiles → google_service_account + VM's service_account block.
#
#  6. user_data → metadata { "startup-script" = "..." }
#
# Instance layout:
#   palo_alto_fw  → 3 NICs: management (nic0, public IP), internet (nic1, public IP), trust (nic2, private)
#   web_server    → 1 NIC:  trust subnet, 172.16.2.50 (public IP for admin access)
################################################################################

# No local variables needed for compute instances

# ---------------------------------------------------------------------------
# Palo Alto VM-Series Firewall
# CONDITIONAL: Only deployed when enable_palo_alto_firewall = true (Phase 2)
# ---------------------------------------------------------------------------
resource "google_compute_instance" "palo_alto_fw" {
  count        = var.enable_palo_alto_firewall ? 1 : 0 # Only deploy in Phase 2
  name         = "dc-master-pa-firewall"
  machine_type = "n1-standard-4" # Equivalent to m5.xlarge (4 vCPU, 16 GB RAM)
  zone         = var.zone

  # CRITICAL: Enables the firewall to forward traffic between interfaces.
  # Equivalent to source_dest_check = false on AWS ENIs.
  can_ip_forward = true

  # Boot disk — PA VM-Series image from GCP Marketplace
  boot_disk {
    initialize_params {
      image = var.palo_alto_image
      size  = 60
      type  = "pd-ssd"
    }
  }

  # nic0: Management interface (primary — must be first for GCP serial console)
  # Maps to device_index=0 in AWS (pa_management_eni → 172.16.61.10)
  network_interface {
    subnetwork = google_compute_subnetwork.private_management.id
    network_ip = "172.16.61.10"

    # External IP for direct admin access (restricted to admin IP via firewall rules)
    access_config {
      nat_ip       = google_compute_address.fw_management_eip[0].address
      network_tier = "PREMIUM"
    }
  }

  # nic1: Internet-facing interface
  # Maps to device_index=1 (pa_internet_eni → 172.16.1.10)
  network_interface {
    subnetwork = google_compute_subnetwork.public_internet.id
    network_ip = "172.16.1.10"

    access_config {
      # Attach the reserved static external IP (equivalent to aws_eip_association)
      nat_ip       = google_compute_address.fw_internet_eip[0].address
      network_tier = "PREMIUM"
    }
  }

  # nic2: Trust interface (MOVED from nic3 after removing LLM interface)
  # Maps to device_index=2 (pa_trust_eni → 172.16.2.10)
  network_interface {
    subnetwork = google_compute_subnetwork.private_trust.id
    network_ip = "172.16.2.10"
    # No external IP — Trust is a private zone
  }

  # Network tags map to firewall rules (replacing per-ENI security groups).
  # pa-mgmt    → rules targeting the management interface (nic0)
  # pa-public  → rules targeting the internet-facing interface (nic1)
  # pa-trust   → rules targeting the trust interface (nic2, 172.16.2.10)
  #
  # NOTE: GCP applies tags at the VM level, not per NIC. All three tags are
  # carried by this single VM so that firewall rules scoped to each tag
  # correctly match ingress/egress on the corresponding subnet.
  tags = ["pa-mgmt", "pa-public", "pa-trust"]

  metadata = merge(
    {
      serial-port-enable                    = "1"
      ssh-keys                              = var.palo_alto_ssh_key
      panorama-server                       = var.panorama_server
      authcodes                             = var.authcodes
      hostname                              = "Dc-Tme-Airs-Fw"
      dns-primary                           = var.dns_primary
      dhcp-send-hostname                    = var.dhcp_send_hostname
      dhcp-send-client-id                   = var.dhcp_send_client_id
      plugin-op-commands-advance-routing    = "enable"
      vm-series-auto-registration-pin-id    = var.vmseries_pin_id
      vm-series-auto-registration-pin-value = var.vmseries_pin_value
      type                                  = var.mgmt_type
    },
    {} # Empty map - placeholder for future custom metadata
  )

  labels = {
    # Required by org policy
    ccoe-app   = var.ccoe_app
    ccoe-group = var.ccoe_group
    userid     = var.userid
    # Optional labels for cost tracking
    instancelife = var.instancelife
    runstatus    = var.runstatus
    # Optional descriptive labels
    name        = "dc-master-pa-firewall"
    environment = "demo"
    project     = "dc-masterclass"
  }
}

# ---------------------------------------------------------------------------
# Bastion Host - REMOVED
# No longer needed - Direct admin access to PA management and AI server via public IPs
# ---------------------------------------------------------------------------
# The Bastion host has been removed from this architecture. Admin access is now provided via:
#   - PA Firewall Management: Public IP restricted to admin IP (HTTPS/SSH)
#   - AI Server: Public IP restricted to admin IP (SSH/Streamlit)
# This simplifies the architecture while maintaining security through firewall rules.


# ---------------------------------------------------------------------------
# Trust Zone: Ubuntu 22.04 Web Server
# ---------------------------------------------------------------------------
resource "google_compute_instance" "web_server" {
  name         = "dc-master-ai-server"
  machine_type = "n1-standard-4" # 4 vCPU, 15 GB RAM for better AI performance
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.ubuntu_2204_image
      size  = 60
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_trust.id
    network_ip = "172.16.2.50"

    # External IP for direct admin access (restricted to admin IP via firewall rules)
    # Outbound traffic still routes through PA firewall trust interface (172.16.2.10)
    # due to higher priority custom route (priority 800 vs 1000)
    access_config {
      nat_ip       = google_compute_address.ai_server_eip.address
      network_tier = "PREMIUM"
    }
  }

  # Attach the Vertex AI service account (equivalent to iam_instance_profile)
  service_account {
    email  = google_service_account.vertex_ai_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # trust-zone → matched by allow_ingress_trust_zone firewall rule and
  #              rt-trust-default-via-fw VPC route (priority 800, next hop 172.16.2.10)
  tags = ["trust-zone"]

  metadata = {
    ssh-keys = var.ubuntu_ssh_key
  }

  # Startup script that deploys the Streamlit RAG application
  # Defined in app_deployment.tf as local.streamlit_startup_script
  metadata_startup_script = local.streamlit_startup_script

  labels = {
    # Required by org policy
    ccoe-app   = var.ccoe_app
    ccoe-group = var.ccoe_group
    userid     = var.userid
    # Optional labels for cost tracking
    instancelife = var.instancelife
    runstatus    = var.runstatus
    # Optional descriptive labels
    name        = "dc-master-ai-server"
    environment = "demo"
    project     = "dc-masterclass"
    workload    = "ai-application"
  }
}
