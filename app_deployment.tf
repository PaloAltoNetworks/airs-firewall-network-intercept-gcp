################################################################################
# 8. APPLICATION DEPLOYMENT (app_deployment.tf)
#
# Packages and deploys the Streamlit RAG application to the web_server VM.
#
# Deployment approach: Git Clone
#    - VM clones the Git repository on first boot
#    - Application source: var.streamlit_app_git_repo
#    - Easy to update: git pull or redeploy VM
#
# Application details:
#  - Location: /opt/streamlit-rag-app
#  - Service: systemd (streamlit-rag.service)
#  - Port: 8501
#  - Python: venv with requirements.txt
################################################################################

# ---------------------------------------------------------------------------
# Startup Script - Git Clone Deployment
# ---------------------------------------------------------------------------
locals {
  streamlit_startup_script_git = <<-EOF
    #!/bin/bash
    set -e

    # Log everything to a deployment log file
    exec > >(tee -a /var/log/streamlit-deployment.log)
    exec 2>&1

    echo "=================================================="
    echo "DC MasterClass - AI Server Initial Setup (Git Clone Method)"
    echo "Started: $(date)"
    echo "=================================================="

    # Wait for cloud-init to complete (prevents apt lock issues)
    echo "Waiting for package manager to be available..."
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
      sleep 5
    done

    # Install Apache Web Server (for Phase 1 demo page)
    echo "[Setup] Installing system packages..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq apache2 git

    # Create demo landing page
    cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>DC MasterClass - AI Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 30px; border-radius: 8px; max-width: 800px; margin: 0 auto; }
        h1 { color: #1a73e8; }
        .status { padding: 15px; background: #e8f5e9; border-left: 4px solid #4caf50; margin: 20px 0; }
        .info { padding: 10px; background: #e3f2fd; margin: 10px 0; }
        a { color: #1a73e8; text-decoration: none; }
        a:hover { text-decoration: underline; }
        code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🤖 DC MasterClass - AI Server</h1>
        <h2>Deployed via Terraform on GCP</h2>

        <div class="status">
            <strong>✓ Server Status:</strong> Online<br>
            <strong>✓ Instance:</strong> dc-master-ai-server (172.16.2.50)<br>
            <strong>✓ Streamlit App:</strong> Running on port 8501
        </div>

        <h3>📄 Access the RAG Application</h3>
        <div class="info">
            <p><strong>Internal URL:</strong> <a href="http://172.16.2.50:8501" target="_blank">http://172.16.2.50:8501</a> (from trust network)</p>
            <p><em>External access via public IP - restricted to admin IP only</em></p>
        </div>

        <h3>🔧 System Information</h3>
        <ul>
            <li><strong>Application Path:</strong> /opt/streamlit-rag-app</li>
            <li><strong>Service Name:</strong> streamlit-rag</li>
            <li><strong>Python:</strong> venv (Python 3.10+)</li>
            <li><strong>Framework:</strong> Streamlit + LangChain + ChromaDB</li>
        </ul>

        <h3>📊 Useful Commands</h3>
        <div class="info">
            <p>Check service status: <code>sudo systemctl status streamlit-rag</code></p>
            <p>View application logs: <code>sudo journalctl -u streamlit-rag -f</code></p>
            <p>View deployment logs: <code>sudo cat /var/log/streamlit-deployment.log</code></p>
        </div>

        <h3>🔒 Phase 2: SSL Decryption Setup</h3>
        <div class="info">
            <p><strong>For PA Firewall SSL inspection:</strong></p>
            <ol>
                <li>Configure decryption policy on PA firewall</li>
                <li>Download root CA certificate (.pem file) from Strata Cloud Manager</li>
                <li>Upload certificate: <code>scp &lt;cert-name&gt;.pem ubuntu@172.16.2.50:/opt/streamlit-rag-app/</code></li>
                <li>Install certificate: <code>sudo bash /opt/streamlit-rag-app/install_pa_root_ca.sh</code></li>
            </ol>
            <p><em>Note: The script auto-detects any .pem file in the app directory.</em></p>
        </div>
    </div>
</body>
</html>
HTML

    systemctl start apache2
    systemctl enable apache2
    echo "[Setup] ✓ Apache configured with landing page"

    # Clone application from Git repository
    echo "[Deployment] Cloning Streamlit application from Git..."
    GIT_REPO="${var.streamlit_app_git_repo}"
    GIT_BRANCH="${var.streamlit_app_git_branch}"

    if [ -z "$GIT_REPO" ]; then
      echo "ERROR: Git repository URL not configured"
      exit 1
    fi

    # Clone the repository
    git clone --branch "$GIT_BRANCH" --depth 1 "$GIT_REPO" /tmp/streamlit-rag-app
    echo "[Deployment] ✓ Application cloned from $GIT_REPO (branch: $GIT_BRANCH)"

    # Make deployment script executable
    chmod +x /tmp/streamlit-rag-app/deployment/deploy.sh

    # Run the deployment script
    echo "[Deployment] Running application deployment script..."
    /tmp/streamlit-rag-app/deployment/deploy.sh

    # Override .env file with Terraform-configured model settings
    # CRITICAL: This must happen AFTER the Git repo's deploy.sh has run,
    # but we need to restart the service afterward to pick up the new values
    echo "[Deployment] Configuring Gemini model settings from Terraform..."
    cat > /opt/streamlit-rag-app/.env <<ENVFILE
GCP_PROJECT=${var.project_id}
GCP_LOCATION=${var.region}
GEMINI_CHAT_MODEL=${var.gemini_chat_model}
GEMINI_EMBEDDING_MODEL=${var.gemini_embedding_model}
ENVFILE
    chown ubuntu:ubuntu /opt/streamlit-rag-app/.env
    chmod 600 /opt/streamlit-rag-app/.env

    # CRITICAL VALIDATION: Ensure variables were expanded (not literal strings)
    if grep -q '$${var\.' /opt/streamlit-rag-app/.env; then
        echo "❌ FATAL ERROR: Environment variables not expanded properly!"
        echo "   .env file contains literal Terraform variables instead of actual values"
        echo "   This is a deployment script bug - contact support"
        echo ""
        echo "Contents of .env file:"
        cat /opt/streamlit-rag-app/.env
        exit 1
    fi

    echo "✓ Gemini model configured: ${var.gemini_chat_model}"
    echo "✓ Environment variables validated (no literal Terraform variables)"

    # CRITICAL FIX: Restart the service to pick up the new .env file
    # The Git repo's deploy.sh started the service before we created this .env
    # So we must restart it to load the correct Terraform-configured values
    echo "[Deployment] Restarting Streamlit service to load new configuration..."
    systemctl restart streamlit-rag.service
    sleep 3

    # Verify service restarted successfully
    if systemctl is-active --quiet streamlit-rag.service; then
        echo "✓ Service restarted successfully with correct environment"
    else
        echo "⚠ WARNING: Service may not have restarted properly"
        systemctl status streamlit-rag.service --no-pager || true
    fi

    # PRODUCTION FIX 1: Increase token limit to prevent truncated responses
    echo "[Production Fix] Configuring token limits in chat_engine.py..."
    CHAT_ENGINE="/opt/streamlit-rag-app/rag/chat_engine.py"
    if [ -f "$CHAT_ENGINE" ]; then
        # Backup original
        cp "$CHAT_ENGINE" "$CHAT_ENGINE.original"

        # Method 1: Replace existing max_output_tokens if present
        sed -i 's/max_output_tokens[[:space:]]*=[[:space:]]*[0-9]\+/max_output_tokens=8192/g' "$CHAT_ENGINE"

        # Method 2: Add generation_config to generate_content calls if not present
        # This ensures proper token limits even if GitHub code changes
        if ! grep -q "max_output_tokens" "$CHAT_ENGINE"; then
            # Insert after any generate_content call
            sed -i '/\.generate_content(/a\        # Production fix: Ensure full responses\n        generation_config={"max_output_tokens": 8192, "temperature": 0.7},' "$CHAT_ENGINE"
        fi

        echo "✓ Token limit configured: max_output_tokens=8192"
    else
        echo "WARNING: chat_engine.py not found, skipping token limit fix"
    fi

    # PRODUCTION FIX 2: Create inline auto-load PDFs functionality
    echo "[Production Fix] Creating auto-load PDFs functionality..."
    cat > /opt/streamlit-rag-app/auto_load_pdfs.py <<'AUTOLOAD_INLINE'
#!/usr/bin/env python3
"""Auto-load existing PDFs/DOCX from cache into ChromaDB on startup."""
import os, sys
from pathlib import Path

# Set working directory and Python path
APP_DIR = Path("/opt/streamlit-rag-app")
os.chdir(str(APP_DIR))
sys.path.insert(0, str(APP_DIR))

try:
    from rag.loader import load_document
    from rag.vector_store import add_to_vector_store
    import chromadb

    cache_dir = APP_DIR / "cache" / "uploaded_files"
    cache_dir.mkdir(parents=True, exist_ok=True)

    docs = list(cache_dir.glob("*.pdf")) + list(cache_dir.glob("*.docx"))
    if not docs:
        print("No cached documents to load")
        sys.exit(0)

    print(f"Auto-loading {len(docs)} document(s) from cache...")

    # Check which documents are already loaded
    chroma_client = chromadb.PersistentClient(path="./chroma_data")
    collection = chroma_client.get_or_create_collection(name="rag_docs")
    existing_docs = collection.get()
    existing_sources = set(meta.get("source", "") for meta in existing_docs.get("metadatas", []))

    for doc_path in docs:
        try:
            if doc_path.name in existing_sources:
                print(f"  ⊳ Skipped (already loaded): {doc_path.name}")
                continue

            chunks = load_document(doc_path)

            if chunks:
                add_to_vector_store(doc_path.name, chunks, log=False)
                print(f"  ✓ Loaded: {doc_path.name} ({len(chunks)} chunks)")
        except Exception as e:
            print(f"  ✗ Error loading {doc_path.name}: {e}")

    print("Auto-load complete")
except Exception as e:
    print(f"Auto-load skipped: {e}")
    sys.exit(0)
AUTOLOAD_INLINE
    chmod +x /opt/streamlit-rag-app/auto_load_pdfs.py
    chown ubuntu:ubuntu /opt/streamlit-rag-app/auto_load_pdfs.py
    echo "✓ Auto-load PDFs script created"

    # PRODUCTION FIX 3: Create bash wrapper for auto-load with proper environment
    echo "[Production Fix] Creating auto-load wrapper script..."
    cat > /opt/streamlit-rag-app/run_auto_load.sh <<'WRAPPER'
#!/bin/bash
cd /opt/streamlit-rag-app
export PYTHONPATH=/opt/streamlit-rag-app:$PYTHONPATH
/opt/streamlit-rag-app/venv/bin/python3 /opt/streamlit-rag-app/auto_load_pdfs.py
WRAPPER
    chmod +x /opt/streamlit-rag-app/run_auto_load.sh
    chown ubuntu:ubuntu /opt/streamlit-rag-app/run_auto_load.sh
    echo "✓ Auto-load wrapper script created"

    # PHASE 2 FIX: Create PA Root CA certificate installation script (for SSL decryption)
    echo "[Phase 2 Setup] Creating PA Root CA certificate installation script..."
    cat > /opt/streamlit-rag-app/install_pa_root_ca.sh <<'CERTINSTALL'
#!/bin/bash
################################################################################
# MANUAL SCRIPT: Install Palo Alto Root CA Certificate
#
# PURPOSE:
#   Install the PA firewall's Forward Trust root CA certificate into the
#   system trust store and Python's certifi bundle. This allows the Streamlit
#   app to trust SSL connections decrypted by the Palo Alto firewall.
#
# PREREQUISITES:
#   1. Configure SSL Forward Proxy decryption policy on PA firewall
#   2. Download root CA certificate from Strata Cloud Manager:
#      - Navigate to: Manage > Configuration > NGFW and Prisma Access
#      - Select your firewall > Device Settings > Certificate Management
#      - Find the "Forward Trust Certificate" (default certificate)
#      - Export the root CA certificate as .pem file
#   3. Upload the .pem file to this directory (any filename is supported):
#      scp <your-cert-name>.pem ubuntu@172.16.2.50:/opt/streamlit-rag-app/
#      (e.g., PA-ROOT-CA.pem, forward-trust-cert.pem, default-cert.pem, etc.)
#
# USAGE:
#   cd /opt/streamlit-rag-app
#   sudo bash install_pa_root_ca.sh
#
# WHAT THIS SCRIPT DOES:
#   1. Validates the PA root CA certificate exists
#   2. Installs it to Ubuntu's system CA trust store
#   3. Updates Python's certifi bundle (used by requests library)
#   4. Configures environment variables for SSL verification
#   5. Restarts the Streamlit service
#
################################################################################

set -e

echo "=================================================="
echo "Palo Alto Root CA Certificate Installer"
echo "=================================================="
echo ""

# Certificate file path (same directory as this script)
SCRIPT_DIR="$$( cd "$$( dirname "$${BASH_SOURCE[0]}" )" && pwd )"

# Auto-detect .pem files in the directory (excluding venv directory)
PEM_FILES=($(find "$$SCRIPT_DIR" -maxdepth 1 -name "*.pem" -type f 2>/dev/null))

# Validate certificate file exists
if [ $${#PEM_FILES[@]} -eq 0 ]; then
    echo "❌ ERROR: No .pem certificate files found in $$SCRIPT_DIR"
    echo ""
    echo "Expected: Any .pem file (e.g., PA-ROOT-CA.pem, forward-trust-cert.pem, etc.)"
    echo ""
    echo "📥 HOW TO GET THE CERTIFICATE:"
    echo "   1. Log in to Strata Cloud Manager (https://pan.dev)"
    echo "   2. Navigate to: Manage > Configuration > NGFW and Prisma Access"
    echo "   3. Select your firewall > Device Settings > Certificate Management"
    echo "   4. Locate the 'Forward Trust Certificate' or 'Default Forward Trust'"
    echo "   5. Click Export and download as .pem file"
    echo ""
    echo "📤 HOW TO UPLOAD THE CERTIFICATE:"
    echo "   From your local machine, run:"
    echo "   scp <your-cert-name>.pem ubuntu@172.16.2.50:/opt/streamlit-rag-app/"
    echo ""
    echo "   Then run this script again:"
    echo "   cd /opt/streamlit-rag-app"
    echo "   sudo bash install_pa_root_ca.sh"
    echo ""
    exit 1
elif [ $${#PEM_FILES[@]} -eq 1 ]; then
    # Only one .pem file found, use it automatically
    CERT_FILE="$${PEM_FILES[0]}"
    echo "✓ Certificate found: $$(basename "$$CERT_FILE")"
else
    # Multiple .pem files found, ask user to choose
    echo "📁 Multiple .pem files found in $$SCRIPT_DIR:"
    echo ""
    for i in "$${!PEM_FILES[@]}"; do
        echo "  [$$(( i + 1 ))]: $$(basename "$${PEM_FILES[$$i]}")"
    done
    echo ""
    read -p "Select certificate file [1-$${#PEM_FILES[@]}]: " CERT_CHOICE

    # Validate choice
    if [[ ! "$$CERT_CHOICE" =~ ^[0-9]+$$ ]] || [ "$$CERT_CHOICE" -lt 1 ] || [ "$$CERT_CHOICE" -gt $${#PEM_FILES[@]} ]; then
        echo "❌ Invalid selection. Exiting."
        exit 1
    fi

    CERT_FILE="$${PEM_FILES[$$(( CERT_CHOICE - 1 ))]}"
    echo "✓ Selected: $$(basename "$$CERT_FILE")"
fi

echo ""

# Validate it's a valid PEM certificate
if ! grep -q "BEGIN CERTIFICATE" "$$CERT_FILE"; then
    echo "❌ ERROR: File does not appear to be a valid PEM certificate"
    echo "Expected: -----BEGIN CERTIFICATE-----"
    exit 1
fi

echo "✓ Certificate format validated"
echo ""

# Display certificate details
echo "📜 Certificate Details:"
openssl x509 -in "$$CERT_FILE" -noout -subject -issuer -dates 2>/dev/null || echo "  (Unable to parse certificate details)"
echo ""

read -p "⚠️  Install this certificate to the system trust store? (y/N): " -n 1 -r
echo ""
if [[ ! $$REPLY =~ ^[Yy]$$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "=================================================="
echo "Starting Installation..."
echo "=================================================="
echo ""

# Step 1: Install to system CA trust store
echo "[1/6] Installing certificate to system CA trust store..."
cp "$$CERT_FILE" /usr/local/share/ca-certificates/PA-ROOT-CA.crt
chmod 644 /usr/local/share/ca-certificates/PA-ROOT-CA.crt
echo "      ✓ Copied to /usr/local/share/ca-certificates/PA-ROOT-CA.crt"

# Step 2: Update system CA certificates
echo "[2/6] Updating system CA certificates..."
update-ca-certificates
echo "      ✓ System CA trust store updated"

# Step 3: Verify system installation
echo "[3/6] Verifying system installation..."
if [ -f /etc/ssl/certs/PA-ROOT-CA.pem ]; then
    echo "      ✓ Certificate verified in /etc/ssl/certs/"
else
    echo "      ⚠ Warning: Certificate symlink not found (may still work)"
fi

# Step 4: Install to Python certifi bundle
echo "[4/6] Installing certificate to Python certifi bundle..."

# Update system Python certifi (if exists)
SYSTEM_CERTIFI=$$(python3 -c "import certifi; print(certifi.where())" 2>/dev/null || echo "")
if [ -n "$$SYSTEM_CERTIFI" ] && [ -f "$$SYSTEM_CERTIFI" ]; then
    # Check if PA cert already present by searching for unique Subject line
    # Extract Subject from PA cert to use as search key
    PA_SUBJECT=$$(openssl x509 -in /usr/local/share/ca-certificates/PA-ROOT-CA.crt -subject -noout 2>/dev/null)
    if grep -qF "$$PA_SUBJECT" "$$SYSTEM_CERTIFI" 2>/dev/null; then
        echo "      ⊳ Already present in system certifi bundle"
    else
        cat /usr/local/share/ca-certificates/PA-ROOT-CA.crt >> "$$SYSTEM_CERTIFI"
        echo "      ✓ Appended to system certifi: $$SYSTEM_CERTIFI"
    fi
else
    echo "      ⊳ System certifi not found, skipping"
fi

# Update venv certifi bundle
VENV_CERTIFI="/opt/streamlit-rag-app/venv/lib/python*/site-packages/certifi/cacert.pem"
VENV_CERTIFI_FILES=$$(ls $$VENV_CERTIFI 2>/dev/null || echo "")
if [ -n "$$VENV_CERTIFI_FILES" ]; then
    PA_SUBJECT=$$(openssl x509 -in /usr/local/share/ca-certificates/PA-ROOT-CA.crt -subject -noout 2>/dev/null)
    for certifi_file in $$VENV_CERTIFI_FILES; do
        # Check for PA cert by Subject line
        if grep -qF "$$PA_SUBJECT" "$$certifi_file" 2>/dev/null; then
            echo "      ⊳ Already present in venv certifi bundle: $$certifi_file"
        else
            cat /usr/local/share/ca-certificates/PA-ROOT-CA.crt >> "$$certifi_file"
            echo "      ✓ Appended to venv certifi: $$certifi_file"
        fi
    done
else
    echo "      ⊳ Venv certifi not found, skipping"
fi

# Step 5: Configure environment variables
echo "[5/6] Configuring SSL environment variables..."

# Update .env file to use system CA bundle
if ! grep -q "SSL_CERT_FILE" /opt/streamlit-rag-app/.env 2>/dev/null; then
    cat >> /opt/streamlit-rag-app/.env <<'ENVEOF'

# SSL Certificate Configuration (for PA firewall SSL decryption)
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENVEOF
    chown ubuntu:ubuntu /opt/streamlit-rag-app/.env
    echo "      ✓ Environment variables added to .env"
else
    echo "      ⊳ SSL environment variables already configured"
fi

# Update systemd service to use environment variables
if ! grep -q "SSL_CERT_FILE" /etc/systemd/system/streamlit-rag.service 2>/dev/null; then
    sed -i '/Environment="PYTHONPATH/a Environment="SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"' /etc/systemd/system/streamlit-rag.service
    sed -i '/SSL_CERT_FILE/a Environment="REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt"' /etc/systemd/system/streamlit-rag.service
    sed -i '/REQUESTS_CA_BUNDLE/a Environment="GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=/etc/ssl/certs/ca-certificates.crt"' /etc/systemd/system/streamlit-rag.service
    systemctl daemon-reload
    echo "      ✓ Systemd service environment updated (curl, requests, gRPC)"
else
    echo "      ⊳ Systemd service already configured"
fi

# Step 6: Restart Streamlit service
echo "[6/6] Restarting Streamlit RAG service..."
systemctl restart streamlit-rag.service
sleep 3

if systemctl is-active --quiet streamlit-rag.service; then
    echo "      ✓ Streamlit service restarted successfully"
else
    echo "      ✗ ERROR: Streamlit service failed to start!"
    echo "      Check logs: sudo journalctl -u streamlit-rag -n 50"
    exit 1
fi

echo ""
echo "=================================================="
echo "✅ INSTALLATION COMPLETE!"
echo "=================================================="
echo ""
echo "📍 Certificate Locations:"
echo "   • System trust store:  /usr/local/share/ca-certificates/PA-ROOT-CA.crt"
echo "   • System CA bundle:    /etc/ssl/certs/ca-certificates.crt"
echo "   • Python certifi:      $$SYSTEM_CERTIFI"
echo "   • Original file:       $$(basename "$$CERT_FILE")"
echo ""
echo "🔍 Verification Commands:"
echo "   • Test system SSL:     curl -v https://aiplatform.googleapis.com"
echo "   • Check service:       sudo systemctl status streamlit-rag"
echo "   • View logs:           sudo journalctl -u streamlit-rag -f"
echo "   • Test in Python:      python3 -c 'import requests; requests.get(\"https://aiplatform.googleapis.com\")'"
echo ""
echo "🚀 Next Steps:"
echo "   1. Access Streamlit app: http://172.16.2.50:8501"
echo "   2. Upload a document and chat with Vertex AI"
echo "   3. Monitor PA firewall logs for decrypted traffic"
echo "   4. Check AI Security profile for prompt/response visibility"
echo ""
CERTINSTALL
    chmod +x /opt/streamlit-rag-app/install_pa_root_ca.sh
    chown ubuntu:ubuntu /opt/streamlit-rag-app/install_pa_root_ca.sh
    echo "✓ PA Root CA certificate installation script created"

    # PRODUCTION FIX 4: Override systemd service with auto-load capability
    # NOTE: The Git repo's deploy.sh already created a basic systemd service.
    # We MUST overwrite it to add the auto-load functionality.
    echo "[Production Fix] Overriding systemd service to add auto-load capability..."

    # Stop the service before modifying (if running)
    systemctl stop streamlit-rag.service 2>/dev/null || true

    # Create new service file with auto-load pre-start hook
    cat > /etc/systemd/system/streamlit-rag.service <<'SYSTEMD'
[Unit]
Description=Streamlit RAG Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/streamlit-rag-app
Environment="PATH=/opt/streamlit-rag-app/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="PYTHONPATH=/opt/streamlit-rag-app"

# CRITICAL: Auto-load existing PDFs/DOCX from cache before starting the app
# This ensures documents persist across service restarts and VM reboots
ExecStartPre=/opt/streamlit-rag-app/run_auto_load.sh

# Start the Streamlit app
ExecStart=/opt/streamlit-rag-app/venv/bin/streamlit run app.py --server.port=8501 --server.address=0.0.0.0 --server.headless=true

Restart=always
RestartSec=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=streamlit-rag

[Install]
WantedBy=multi-user.target
SYSTEMD

    # Reload systemd to pick up the new service file
    systemctl daemon-reload
    echo "✓ Systemd service file updated with auto-load capability"

    # Enable and restart the service with the new configuration
    systemctl enable streamlit-rag.service
    systemctl restart streamlit-rag.service
    echo "✓ Streamlit service restarted with auto-load enabled"

    # Wait for service to start
    sleep 3

    # Verify service is running
    if systemctl is-active --quiet streamlit-rag.service; then
        echo "✓ Service is running with auto-load enabled"
    else
        echo "⚠ WARNING: Service may not be running properly"
        systemctl status streamlit-rag.service --no-pager || true
    fi

    echo "=================================================="
    echo "Deployment completed: $(date)"
    echo "=================================================="
    echo ""
    echo "✓ Apache Web Server: http://172.16.2.50"
    echo "✓ Streamlit RAG App: http://172.16.2.50:8501"
    echo "✓ Git Repository: $GIT_REPO"
    echo "✓ Git Branch: $GIT_BRANCH"
    echo "✓ Gemini Model: ${var.gemini_chat_model}"
    echo "✓ Token Limit Fix: Applied"
    echo "✓ Auto-load PDFs: Enabled"
    echo ""
    echo "📋 Available Scripts in /opt/streamlit-rag-app/:"
    echo "   • auto_load_pdfs.py        - Auto-load cached documents"
    echo "   • run_auto_load.sh         - Wrapper for auto-load"
    echo "   • install_pa_root_ca.sh    - Install PA firewall root CA (for Phase 2)"
    echo ""
    echo "🔒 Phase 2 SSL Decryption Setup:"
    echo "   After configuring PA firewall decryption policy:"
    echo "   1. Download root CA certificate (.pem file) from Strata Cloud Manager"
    echo "   2. scp <your-cert-name>.pem ubuntu@172.16.2.50:/opt/streamlit-rag-app/"
    echo "   3. sudo bash /opt/streamlit-rag-app/install_pa_root_ca.sh"
    echo ""
  EOF

  # Use Git clone startup script for deployment
  streamlit_startup_script = local.streamlit_startup_script_git
}
