################################################################################
# 5. FIREWALL RULES (firewall_rules.tf)
#
# GCP firewall rules are VPC-wide and applied via NETWORK TAGS on instances.
# Each instance is tagged (e.g., "pa-mgmt", "trust-zone") and rules target those tags.
#
# Tag inventory (all tags used across the VPC):
#   pa-mgmt        → PA firewall management interface (nic0, 172.16.61.10)
#   pa-public      → PA firewall internet-facing interface (nic1, 172.16.1.10)
#   pa-trust       → PA firewall trust interface (nic2, 172.16.2.10)
#   trust-zone     → VMs resident in the trust subnet (e.g., AI server at 172.16.2.50)
#
# Admin Access Model:
#   - PA management and AI server have public IPs restricted to admin IP only
#   - No Bastion host needed - direct admin access to resources
#
# NOTE: Vertex AI is accessed via public internet endpoints. Traffic flows
# from Trust zone through PA firewall (Trust → Untrust) for inspection.
################################################################################

# ---------------------------------------------------------------------------
# Admin Access to AI Server
# ---------------------------------------------------------------------------

# --- Allow admin IP to access AI Server (SSH, HTTP, Streamlit) ---
resource "google_compute_firewall" "allow_admin_to_ai_server" {
  name    = "allow-admin-to-ai-server"
  network = google_compute_network.vpc_hq.id

  description = "Allow SSH, HTTP (Apache landing page), and Streamlit access from admin IP to AI Server."

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "8501"] # SSH, HTTP, Streamlit
  }

  allow {
    protocol = "icmp" # Allow ping for connectivity testing
  }

  source_ranges = [var.admin_source_ip]
  target_tags   = ["trust-zone"]
}

# --- Allow IAP SSH access to AI Server ---
resource "google_compute_firewall" "allow_iap_to_ai_server" {
  name    = "allow-iap-to-ai-server"
  network = google_compute_network.vpc_hq.id

  description = "Allow SSH from Identity-Aware Proxy to AI Server for browser-based SSH access from GCP Console."

  allow {
    protocol = "tcp"
    ports    = ["22"] # SSH
  }

  # IAP's IP range for SSH and TCP forwarding
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["trust-zone"]

  priority = 1000
}

# ---------------------------------------------------------------------------
# PA firewall — management interface (nic0, tag: pa-mgmt)
# CONDITIONAL: Only active in Phase 2 when PA firewall is deployed
# ---------------------------------------------------------------------------

# --- Allow admin IP to access PA management interface (SSH, HTTPS) ---
resource "google_compute_firewall" "allow_admin_to_pa_mgmt" {
  count   = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name    = "allow-admin-to-pa-mgmt"
  network = google_compute_network.vpc_hq.id

  description = "PHASE 2: Allow SSH and HTTPS from admin IP to PA firewall management interface for direct admin access."

  allow {
    protocol = "tcp"
    ports    = ["22", "443"] # SSH and HTTPS for management
  }

  allow {
    protocol = "icmp" # Allow ping for connectivity testing
  }

  source_ranges = [var.admin_source_ip]
  target_tags   = ["pa-mgmt"]
}

# --- Allow all egress from PA management ---
resource "google_compute_firewall" "allow_egress_pa_mgmt" {
  count     = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name      = "allow-egress-pa-mgmt"
  network   = google_compute_network.vpc_hq.id
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["pa-mgmt"]
}

# --- Allow IAP SSH access to PA management interface ---
resource "google_compute_firewall" "allow_iap_to_pa_mgmt" {
  count   = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name    = "allow-iap-to-pa-mgmt"
  network = google_compute_network.vpc_hq.id

  description = "PHASE 2: Allow SSH and HTTPS from Identity-Aware Proxy to PA firewall management interface for browser-based SSH access from GCP Console."

  allow {
    protocol = "tcp"
    ports    = ["22", "443"] # SSH and HTTPS for IAP TCP forwarding
  }

  # IAP's IP range for SSH and TCP forwarding
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["pa-mgmt"]

  priority = 1000
}

# ---------------------------------------------------------------------------
# PA firewall — internet-facing interface (nic1, tag: pa-public)
# CONDITIONAL: Only active in Phase 2 when PA firewall is deployed
# ---------------------------------------------------------------------------

# --- Allow all inbound traffic to PA public (internet-facing) interface ---
# This allows return traffic from the internet for connections initiated by Trust zone.
# The PA firewall itself enforces security policies; GCP firewall acts as outer layer.
resource "google_compute_firewall" "allow_ingress_pa_public" {
  count   = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name    = "allow-ingress-pa-public"
  network = google_compute_network.vpc_hq.id

  description = "PHASE 2: Allow all inbound traffic to PA internet-facing interface for return traffic. PA enforces security policy."

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"] # Allow all for return traffic; PA firewall enforces policy
  target_tags   = ["pa-public"]
}

# --- Allow all egress from PA public ---
resource "google_compute_firewall" "allow_egress_pa_public" {
  count     = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name      = "allow-egress-pa-public"
  network   = google_compute_network.vpc_hq.id
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["pa-public"]
}

# ---------------------------------------------------------------------------
# PA firewall — trust interface (nic2, tag: pa-trust)
# CONDITIONAL: Only active in Phase 2 when PA firewall is deployed
#
# Allows the trust subnet (172.16.2.0/24) to send traffic back to the PA
# trust NIC at 172.16.2.10 (return traffic, ICMP health checks, etc.).
# ---------------------------------------------------------------------------

# --- Allow ingress to PA trust interface from trust subnet ---
resource "google_compute_firewall" "allow_ingress_pa_trust" {
  count   = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name    = "allow-ingress-pa-trust"
  network = google_compute_network.vpc_hq.id

  description = "PHASE 2: Allow traffic from trust subnet to PA firewall trust interface (nic3, 172.16.2.10)."

  allow {
    protocol = "all"
  }

  source_ranges = [google_compute_subnetwork.private_trust.ip_cidr_range]
  target_tags   = ["pa-trust"]
}

# --- Allow all egress from PA trust interface ---
resource "google_compute_firewall" "allow_egress_pa_trust" {
  count     = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name      = "allow-egress-pa-trust"
  network   = google_compute_network.vpc_hq.id
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["pa-trust"]
}

# ---------------------------------------------------------------------------
# Trust zone — AI server and other trust-subnet VMs (tag: trust-zone)
#
# Ingress is permitted from:
#   1. Within the trust subnet (172.16.2.0/24) - traffic via PA trust interface (172.16.2.10)
#   2. Admin IP (via the allow_admin_to_ai_server rule above)
# PA enforces inter-zone policy before traffic reaches this subnet.
# ---------------------------------------------------------------------------

# --- Allow ingress to trust-zone VMs from the trust subnet ---
resource "google_compute_firewall" "allow_ingress_trust_zone" {
  name    = "allow-ingress-trust-zone"
  network = google_compute_network.vpc_hq.id

  description = "Allow HTTP, HTTPS, SSH, and Streamlit (8501) from within the trust subnet to trust-zone VMs (e.g., web_server)."

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8501"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [google_compute_subnetwork.private_trust.ip_cidr_range]
  target_tags   = ["trust-zone"]
}

# --- Allow all egress from trust-zone VMs ---
# Egress routes via the PA trust interface (172.16.2.10) as defined in routing.tf.
resource "google_compute_firewall" "allow_egress_trust_zone" {
  name      = "allow-egress-trust-zone"
  network   = google_compute_network.vpc_hq.id
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["trust-zone"]
}

