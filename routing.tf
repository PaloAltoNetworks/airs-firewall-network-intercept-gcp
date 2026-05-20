################################################################################
# 4. ROUTING CONFIGURATION (routing.tf)
#
# GCP equivalent of AWS Route Tables and associations.
#
# KEY DIFFERENCE: In GCP, routes are VPC-wide resources, not per-subnet.
# To simulate per-subnet routing (e.g., trust zone traffic via PA firewall),
# routes use priority + destination CIDR to steer traffic, and are
# optionally scoped to instances via network tags.
#
# Routing behavior by phase:
#
#   PHASE 1 (No PA Firewall):
#     - Trust zone (AI server): Direct internet via public IP (priority 800)
#     - PA management: Not deployed
#
#   PHASE 2 (With PA Firewall):
#     - Trust zone (AI server): Routes via PA Trust interface 172.16.2.10 (priority 800)
#     - PA management: Direct internet via public IP
#     - PA internet (Untrust): Direct internet via public IP
#
# Priority values: Lower number = higher priority (800 > 1000)
# The custom routes (priority 800) override the default internet gateway route (priority 1000)
#
# NAT Gateway: Not needed - all instances have public IPs
################################################################################

# --- Default internet route for public subnet ---
# In GCP this already exists implicitly, but we declare it explicitly
# for parity and tagging clarity.
resource "google_compute_route" "public_default_route" {
  name             = "rt-public-default"
  network          = google_compute_network.vpc_hq.id
  dest_range       = "0.0.0.0/0"
  priority         = 1000
  next_hop_gateway = "global/gateways/default-internet-gateway"

  description = "Default internet route for public subnet instances."

  # Scoped to instances with the pa-public tag (public subnet residents)
  tags = ["pa-public"]
}

# --- Trust subnet: PHASE 1 - Direct internet route (no firewall) ---
# Only active when PA firewall is disabled
resource "google_compute_route" "trust_direct_internet" {
  count            = var.enable_palo_alto_firewall ? 0 : 1 # Phase 1 only
  name             = "rt-trust-direct-internet"
  network          = google_compute_network.vpc_hq.id
  dest_range       = "0.0.0.0/0"
  priority         = 800
  next_hop_gateway = "global/gateways/default-internet-gateway"

  description = "PHASE 1: Direct internet route for trust subnet via public IP (NO FIREWALL PROTECTION). AI server uses its public IP for outbound traffic."

  tags = ["trust-zone"]

  depends_on = [google_compute_subnetwork.private_trust]
}

# --- Trust subnet: PHASE 2 - Route via PA Trust interface (172.16.2.10) ---
# Only active when PA firewall is enabled
resource "google_compute_route" "trust_default_via_fw" {
  count       = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name        = "rt-trust-default-via-fw"
  network     = google_compute_network.vpc_hq.id
  dest_range  = "0.0.0.0/0"
  priority    = 800           # Higher priority than the default internet route
  next_hop_ip = "172.16.2.10" # PA Trust ENI IP

  description = "PHASE 2: Route all Trust subnet outbound traffic through PA firewall trust interface for inspection. Inbound admin traffic to AI server bypasses PA (acceptable for trusted admin IP)."

  tags = ["trust-zone"]

  depends_on = [google_compute_subnetwork.private_trust, google_compute_instance.palo_alto_fw]
}

# --- Trust subnet: PHASE 2 - Admin IP exception route (symmetric routing fix) ---
# CRITICAL: This route prevents asymmetric routing for admin access
# Without this, return traffic to admin IP would go through PA firewall,
# but PA has no session (inbound came direct), causing drops.
resource "google_compute_route" "trust_admin_direct" {
  count            = var.enable_palo_alto_firewall ? 1 : 0 # Phase 2 only
  name             = "rt-trust-admin-direct"
  network          = google_compute_network.vpc_hq.id
  dest_range       = var.admin_source_ip # Admin IP (e.g., 122.171.171.171/32)
  priority         = 700                 # Higher priority than PA route (700 < 800)
  next_hop_gateway = "global/gateways/default-internet-gateway"

  description = "PHASE 2: Direct route for admin IP to prevent asymmetric routing. Ensures responses to admin connections bypass PA firewall (same path as inbound)."

  tags = ["trust-zone"]

  depends_on = [google_compute_subnetwork.private_trust]
}

# ---------------------------------------------------------------------------
# Routing Summary
# ---------------------------------------------------------------------------
#
# PHASE 1 (No PA Firewall):
#   - AI server outbound: Direct to internet via public IP (priority 800 route)
#   - AI server inbound: Direct from admin IP via public IP
#   - PA management: Not deployed
#
# PHASE 2 (With PA Firewall):
#   - AI server outbound to admin IP: Direct to internet (priority 700) ← SYMMETRIC ROUTING
#     ✓ Prevents asymmetric routing (inbound direct, outbound via PA would be dropped)
#   - AI server outbound to internet: Routes via PA Trust (172.16.2.10) → PA Untrust (priority 800)
#     ✓ INSPECTED by PA firewall (SSL decryption, AI Security profiles)
#   - AI server inbound: Direct from admin IP (bypasses PA - acceptable for trusted IP)
#   - PA management: Direct internet access via public IP
#   - Vertex AI API calls: Outbound via PA firewall for inspection (priority 800)
#
# Priority logic:
#   - Priority 700 (admin IP) overrides priority 800 (PA firewall) for symmetric routing
#   - Priority 800 (PA firewall) overrides priority 1000 (default internet gateway)
# Tag-based routing: "trust-zone" tag ensures only AI server uses these custom routes
