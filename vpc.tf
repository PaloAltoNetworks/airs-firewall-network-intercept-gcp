################################################################################
# 3. VPC AND NETWORKING SETUP (vpc.tf)
#
# Defines the core network: VPC and Subnets.
#
# AWS → GCP mapping:
#   aws_vpc                  → google_compute_network
#   aws_subnet               → google_compute_subnetwork
#   aws_internet_gateway     → implicit in GCP (routes to 0.0.0.0/0 via default gateway)
#
# Subnet layout:
#   public_internet    → 172.16.1.0/24   (asia-south1-a) - PA firewall Untrust interface
#   private_management → 172.16.61.0/24  (asia-south1-a) - PA firewall Management interface (public IP)
#   private_trust      → 172.16.2.0/24   (asia-south1-a) - AI Server (public IP)
#
# NAT Gateway: REMOVED - All instances have public IPs, no NAT needed
# Private Service Connect: REMOVED - Vertex AI accessed via public internet
################################################################################

# --- VPC ---
resource "google_compute_network" "vpc_hq" {
  name                    = "vpc-hq-dc"
  auto_create_subnetworks = false # Custom mode — we define subnets manually
  routing_mode            = "REGIONAL"

  description = "HQ-DC security lab VPC"
}

# --- Subnets ---

# Public Internet subnet (Firewall internet-facing interface)
resource "google_compute_subnetwork" "public_internet" {
  name          = "subnet-public-internet"
  ip_cidr_range = "172.16.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_hq.id

  # GCP VPC Flow Logs — equivalent to aws_flow_log on the subnet
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  private_ip_google_access = false # Public subnet — internet access via external IP
}

# Management subnet (Firewall management interface)
resource "google_compute_subnetwork" "private_management" {
  name          = "subnet-private-management"
  ip_cidr_range = "172.16.61.0/24"
  region        = var.region
  network       = google_compute_network.vpc_hq.id

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  # Not needed - PA management interface has public IP
  private_ip_google_access = false
}

# Trust subnet (Ubuntu AI Server) — AZ-a
resource "google_compute_subnetwork" "private_trust" {
  name          = "subnet-private-trust-lan"
  ip_cidr_range = "172.16.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc_hq.id

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  # Not needed - AI server has public IP and can access Google APIs via internet
  # Phase 2: Traffic routed through PA firewall for inspection
  private_ip_google_access = false
}

# ---------------------------------------------------------------------------
# Cloud Router and Cloud NAT - REMOVED
# ---------------------------------------------------------------------------
# Cloud NAT is no longer needed because:
#   - PA management interface has public IP (Phase 2)
#   - AI server has public IP (both phases)
#   - Phase 1: AI server uses public IP for outbound traffic
#   - Phase 2: AI server routes through PA firewall trust interface
#
# The Cloud Router and Cloud NAT resources have been removed to simplify
# the architecture and reduce costs.
# ---------------------------------------------------------------------------
