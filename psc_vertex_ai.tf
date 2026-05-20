################################################################################
# 11. PRIVATE SERVICE CONNECT FOR VERTEX AI (psc_vertex_ai.tf)
#
# REMOVED: PSC infrastructure has been removed from this configuration.
#
# Vertex AI is now accessed via public internet endpoints. Traffic flows:
#   Trust zone → PA Firewall (Trust → Untrust) → Internet → Vertex AI
#
# This allows the PA firewall to inspect and decrypt Vertex AI API traffic
# using SSL Forward Proxy decryption and AI Security profiles.
#
# PREVIOUS ARCHITECTURE (removed due to GCP routing limitations):
# - PSC endpoint at 172.16.3.10
# - LLM subnet (172.16.4.0/24)
# - Private DNS zones for aiplatform.googleapis.com
#
# LIMITATION: GCP does not allow custom routes to PSC endpoints, preventing
# traffic from being routed through security appliances for inspection.
################################################################################

# No resources defined - Vertex AI uses public internet endpoints
