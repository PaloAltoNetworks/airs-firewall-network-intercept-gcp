################################################################################
# 2. VARIABLE DEFINITIONS (variables.tf)
#
# Defines input variables for the GCP Terraform configuration.
#
# IMPORTANT:
#  - Set your GCP project_id.
#  - Palo Alto VM-Series on GCP requires accepting the Marketplace terms:
#    https://console.cloud.google.com/marketplace/product/paloaltonetworksgcp-public/vmseries-flex-bundle2
#  - Set palo_alto_image_name to the specific image you want from the family.
################################################################################

variable "project_id" {
  description = "GCP Project ID where all resources will be deployed."
  type        = string
  default     = "<Put_your_GCP_Project_ID>" # CHANGE THIS
}

variable "region" {
  description = "GCP region. asia-south1 is Mumbai, equivalent to AWS ap-south-1."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Primary GCP zone within the region."
  type        = string
  default     = "us-central1-a"
}

variable "credentials_file" {
  description = "Path to GCP service account JSON key file for authentication"
  type        = string
  default     = "./gcp-key.json"
}


# --- Palo Alto VM-Series ---
# GCP Marketplace: paloaltonetworksgcp-public/vmseries-flex-bundle2
# Run: gcloud compute images list --project=paloaltonetworksgcp-public --no-standard-images
variable "palo_alto_image" {
  description = "Self-link or family for Palo Alto VM-Series image from GCP Marketplace."
  type        = string
  default     = "projects/paloaltonetworksgcp-public/global/images/ai-runtime-security-byol-1215"
}

# --- Windows Server 2022 (DEPRECATED - Bastion removed) ---
# The Bastion host has been removed. Direct admin access is now provided via public IPs.
# Keeping this variable for reference only.
# variable "windows_2022_image" {
#   description = "Windows Server 2022 image (deprecated - Bastion removed)"
#   type        = string
#   default     = "projects/windows-cloud/global/images/family/windows-2022"
# }

# --- Ubuntu 22.04 ---
variable "ubuntu_2204_image" {
  description = "Ubuntu 22.04 LTS image for web servers."
  type        = string
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
}

# --- SSH Keys ---
# IMPORTANT: Replace these placeholder SSH public keys with your own!
# The public keys below are examples only. To use your own private key for SSH access,
# replace these with the corresponding PUBLIC key from your SSH key pair.
# Format: "username:ssh-rsa AAAA... [optional comment]"

# Palo Alto firewall uses 'admin' as default SSH user
variable "palo_alto_ssh_key" {
  description = "SSH public key for Palo Alto firewall CLI access (format: 'admin:ssh-rsa AAAA...')."
  type        = string
  # NOTE: This is a placeholder public key. Replace with your own PUBLIC key
  # so you can SSH into the PA firewall using your corresponding PRIVATE key.
  # Generate a key pair: ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
  # Then use: echo "admin:$(cat ~/.ssh/id_rsa.pub)"
  default     = "admin:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCVGOp6vjeMmsqhXos2mWokGUCv4GWJhlaQpQ9R+tnRH59A+Dw0BInK/WJfS4R0T1n8ZT8tOT4OJ+kC1Khp+vO+Vl+6xKRMXmw6a2Eigjcp7MIqc1WYSQjwsRsyWz5t7xxCQsK9r7Kss4h+zBKb9bh632uo+nqKJoOUrWwGX2Gn+itfl948FjFvpaht1Nk21uEDSDQwzgmXSDWUtkq6iCkYm5IGkx6NIWphhg0AfQcoCInDBzk51LaryWw055IRtZMiFi7xAbLrDP7NIDjENlqx6swiF0j0NMK6PvesBCCsyFBDUtiVoNKceGjG9ZZhnllWIVtdYK9MXQBt4LomwfqmSNH2RiDOf+GyLVmg7u8RUPmgHrpJycfaZg1afHAlzgaXnXW3w5u5FEBeFD+Bf8fLBeTYaSOT4XjFf8VzofPGizgPTComR5CXHagmyE/xxp5N9NH72cIEXM5PEWmOHBkhfaJjo1FNCKYUfL0iCJ+Lys7faBTE3eyxJb20Z2QqNdKgFiqzd0XXHkRQKn4sEVdMIQmdyKgrC33cAixt5yS1IiEnvz9YjtbERm23w0rm7oiNbRdfgYNNsivQRbY6xvC8a3bV7UxrX3c8EK+ESAJ3T2m6zRtmwdwSYrbA5O9s1YC+KVD5lmKbF2XuLSNEoUCY9erLFrwLP1sNFC3scVwjyw==" # CHANGE THIS
}

# Ubuntu instances use 'ubuntu' as default SSH user
variable "ubuntu_ssh_key" {
  description = "SSH public key for Ubuntu instances (format: 'ubuntu:ssh-rsa AAAA...')."
  type        = string
  # NOTE: This is a placeholder public key. Replace with your own PUBLIC key
  # so you can SSH into the Ubuntu AI server using your corresponding PRIVATE key.
  # Generate a key pair: ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
  # Then use: echo "ubuntu:$(cat ~/.ssh/id_rsa.pub)"
  default     = "ubuntu:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCVGOp6vjeMmsqhXos2mWokGUCv4GWJhlaQpQ9R+tnRH59A+Dw0BInK/WJfS4R0T1n8ZT8tOT4OJ+kC1Khp+vO+Vl+6xKRMXmw6a2Eigjcp7MIqc1WYSQjwsRsyWz5t7xxCQsK9r7Kss4h+zBKb9bh632uo+nqKJoOUrWwGX2Gn+itfl948FjFvpaht1Nk21uEDSDQwzgmXSDWUtkq6iCkYm5IGkx6NIWphhg0AfQcoCInDBzk51LaryWw055IRtZMiFi7xAbLrDP7NIDjENlqx6swiF0j0NMK6PvesBCCsyFBDUtiVoNKceGjG9ZZhnllWIVtdYK9MXQBt4LomwfqmSNH2RiDOf+GyLVmg7u8RUPmgHrpJycfaZg1afHAlzgaXnXW3w5u5FEBeFD+Bf8fLBeTYaSOT4XjFf8VzofPGizgPTComR5CXHagmyE/xxp5N9NH72cIEXM5PEWmOHBkhfaJjo1FNCKYUfL0iCJ+Lys7faBTE3eyxJb20Z2QqNdKgFiqzd0XXHkRQKn4sEVdMIQmdyKgrC33cAixt5yS1IiEnvz9YjtbERm23w0rm7oiNbRdfgYNNsivQRbY6xvC8a3bV7UxrX3c8EK+ESAJ3T2m6zRtmwdwSYrbA5O9s1YC+KVD5lmKbF2XuLSNEoUCY9erLFrwLP1sNFC3scVwjyw==" # CHANGE THIS
}

# --- Palo Alto Bootstrapping Parameters ---
# Reference: https://docs.paloaltonetworks.com/vm-series/10-1/vm-series-deployment/bootstrap-the-vm-series-firewall/create-the-init-cfgtxt-file
variable "panorama_server" {
  description = "Panorama server IP or hostname for VM-Series registration (metadata key: panorama-server)"
  type        = string
  default     = "cloud"
}

variable "authcodes" {
  description = "BYOL licensing auth codes (comma-separated) (metadata key: authcodes)"
  type        = string
  default     = "<Put_your_CSP_AuthCode>"
}

variable "dns_primary" {
  description = "Primary DNS server (metadata key: dns-primary)"
  type        = string
  default     = "8.8.8.8"
}

variable "dhcp_send_hostname" {
  description = "Whether to send hostname via DHCP on mgmt (metadata key: dhcp-send-hostname)"
  type        = string
  default     = "yes"
}

variable "dhcp_send_client_id" {
  description = "Whether to send client-id via DHCP on mgmt (metadata key: dhcp-send-client-id)"
  type        = string
  default     = "yes"
}

variable "vmseries_pin_id" {
  description = "Auto-registration pin ID (metadata key: vm-series-auto-registration-pin-id)"
  type        = string
  default     = "<Put_your_CSP_Authorization_PIN_ID>"
}

variable "vmseries_pin_value" {
  description = "Auto-registration pin value (metadata key: vm-series-auto-registration-pin-value)"
  type        = string
  default     = "<Put_your_CSP_Authorization_PIN_Value>"
}

variable "mgmt_type" {
  description = "Management interface address type: dhcp-client or static (metadata key: type)"
  type        = string
  default     = "dhcp-client"
}

# --- Admin Source IP ---
# Equivalent to the /32 CIDRs used in AWS security groups
variable "admin_source_ip" {
  description = "Your public IP CIDR for administrative access (RDP/SSH). Restrict this!"
  type        = string
  default     = "<Put_your_Public_IP>/32" # CHANGE THIS to your IP
}

# --- IAP Authorized Users ---
variable "iap_authorized_users" {
  description = <<-EOT
    List of user emails authorized to access VMs via Identity-Aware Proxy (IAP).

    These users will be granted the 'roles/iap.tunnelResourceAccessor' role,
    allowing them to SSH to VMs through the GCP Console or gcloud CLI using IAP tunneling.

    Format: ["user:email1@example.com", "user:email2@example.com"]

    Example:
      - Corporate users: ["user:john.doe@paloaltonetworks.com", "user:jane.smith@paloaltonetworks.com"]
      - Service accounts: ["serviceAccount:automation@your-project-id.iam.gserviceaccount.com"]

    Leave empty to skip IAM binding (you can grant permissions manually via Console).
  EOT
  type        = list(string)
  default     = ["user:<Put_your_UserID>@paloaltonetworks.com"] # CHANGE THIS - Add your email addresses
}

# --- Resource Labels (Required by Org Policy) ---
# IMPORTANT: Your GCP org requires specific labels for all VMs
variable "ccoe_app" {
  description = "CCOE Application/Product name (e.g., cloud-ngfw, vm-series, saas-security)"
  type        = string
  default     = "vm-series" # Application: Palo Alto VM-Series
}

variable "ccoe_group" {
  description = "CCOE Environment/Group (e.g., dev, stage, prod, cpt, regression)"
  type        = string
  default     = "dev" # Development/Demo environment
}

variable "userid" {
  description = "User ID - owner of the resources (username only - no email domain)"
  type        = string
  default     = "<Put_your_UserID>" # CHANGE THIS to your username
}

variable "instancelife" {
  description = "Instance lifecycle value (optional, for cost tracking)"
  type        = string
  default     = "5000"
}

variable "runstatus" {
  description = "Run status for the instance (optional, e.g., nostop, autostop)"
  type        = string
  default     = "nostop"
}

# --- Windows Bastion RDP Credentials (DEPRECATED - Bastion removed) ---
# The Bastion host has been removed from this architecture.
# Direct admin access is now provided to PA management and AI server via public IPs.
# variable "windows_admin_username" {
#   description = "Windows Administrator username (deprecated - Bastion removed)"
#   type        = string
#   default     = "dcadmin"
# }
#
# variable "windows_admin_password" {
#   description = "Windows Administrator password (deprecated - Bastion removed)"
#   type        = string
#   default     = "ChangeMe123!"
#   sensitive   = true
# }

# --- DEMO PHASE TOGGLE ---
variable "enable_palo_alto_firewall" {
  description = <<-EOT
    Toggle to enable/disable Palo Alto Firewall deployment.

    Phase 1 (false): AI app deployed WITHOUT firewall protection.
                     - Direct internet routing for trust subnet
                     - No PA firewall instance deployed
                     - Demonstrates unprotected AI application

    Phase 2 (true):  AI app deployed WITH firewall protection.
                     - All traffic routed through PA firewall
                     - PA firewall inspects all AI app traffic
                     - Demonstrates secure AI application deployment

    Usage: Set to false for Phase 1 demo, then change to true and re-apply for Phase 2.
  EOT
  type        = bool
  default     = false # Start with Phase 1 (no firewall)
}

# --- STREAMLIT APPLICATION GIT REPOSITORY ---
variable "streamlit_app_git_repo" {
  description = <<-EOT
    Git repository URL for the Streamlit RAG application.

    Examples:
      - Public repo:  "https://github.com/your-org/streamlit-rag-app.git"
      - Private repo: "https://github.com/your-org/streamlit-rag-app.git" (requires authentication)

    Leave empty to use the embedded deployment method (zip archive in metadata).
  EOT
  type        = string
  default     = "https://github.com/tany78/RAG_APP_AIRS_FW" # Empty = use embedded method; populated = use git clone
}

variable "streamlit_app_git_branch" {
  description = "Git branch to clone (e.g., main, master, develop)"
  type        = string
  default     = "main"
}

# --- GEMINI MODEL CONFIGURATION ---
variable "gemini_chat_model" {
  description = <<-EOT
    Vertex AI Gemini model to use for chat/RAG application.

    Available models (as of April 2026):
      - gemini-2.5-flash          : Gemini 2.5 Flash (Recommended - fastest, cost-effective)
      - gemini-2.5-pro            : Gemini 2.5 Pro (highest quality, slower)
      - gemini-2.5-flash-lite     : Gemini 2.5 Flash Lite (lighter/faster)

    IMPORTANT: Gemini 1.5 models are shutdown. Gemini 2.0 models sunset June 1, 2026.
    Gemini 2.5 models use NO version suffix (e.g., "gemini-2.5-flash", not "gemini-2.5-flash-001")

    See: https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash
  EOT
  type        = string
  default     = "gemini-2.5-flash" # Gemini 2.5 Flash - current stable model
}

variable "gemini_embedding_model" {
  description = "Vertex AI embedding model for vector embeddings (text-only: gemini-embedding-001, multimodal: gemini-embedding-2-preview)"
  type        = string
  default     = "gemini-embedding-001" # Stable text embedding model (3072-dimensional)
}
