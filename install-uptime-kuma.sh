#!/bin/bash

#############################################################################
# Uptime Kuma Complete Installation Script
# 
# ⚠️  WARNING: This script is designed for FRESH TEST installations only!
# 
# This script makes system-level changes including:
# - Installing Docker, Nginx, Python, and system packages
# - Configuring and enabling UFW firewall
# - Modifying SSL/TLS certificates and Nginx configurations
# - Changing network and service configurations
#
# DO NOT run on production servers or systems with existing services!
#
# This script automates the installation of Uptime Kuma with HTTPS support
# on Ubuntu Server 24.04.3 using Nginx reverse proxy and internal AD CA
#
# Usage: sudo bash install-uptime-kuma.sh
#
# Requirements:
# - Fresh Ubuntu Server 24.04.3 minimal installation
# - Root or sudo access
# - Internal root CA certificate file
# - Access to AD Certificate Authority for certificate signing
# - DNS record pointing to this server
#############################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root or with sudo${NC}"
   exit 1
fi

# Warning for production systems
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                         ⚠️  WARNING ⚠️                              ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${RED}This script is designed for FRESH TEST installations ONLY!${NC}"
echo ""
echo "This script will make significant system changes including:"
echo "  • Installing Docker, Nginx, Python, and other packages"
echo "  • Configuring and enabling UFW firewall"
echo "  • Installing SSL/TLS certificates"
echo "  • Modifying network and service configurations"
echo ""
echo -e "${RED}DO NOT run this on production servers or systems with existing services!${NC}"
echo ""
read -p "Are you running this on a FRESH TEST Ubuntu installation? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo ""
    echo -e "${YELLOW}Installation cancelled. This script should only be run on fresh test systems.${NC}"
    exit 0
fi

echo ""
print_success "Confirmed - proceeding with installation"
echo ""

# Function to print colored messages
print_header() {
    echo -e "\n${BLUE}===================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to prompt for input with validation
prompt_input() {
    local prompt_text="$1"
    local var_name="$2"
    local validation_regex="$3"
    local error_msg="$4"
    
    while true; do
        read -p "$prompt_text: " input
        if [[ -z "$validation_regex" ]] || [[ "$input" =~ $validation_regex ]]; then
            eval "$var_name='$input'"
            break
        else
            print_error "$error_msg"
        fi
    done
}

# Function to pause for manual steps
pause_for_manual_step() {
    echo -e "\n${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  MANUAL STEP REQUIRED - Press ENTER when complete           ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    read -p "Press ENTER to continue..."
}

#############################################################################
# STEP 0: Collect Configuration Information
#############################################################################

print_header "STEP 0: Configuration"

echo "This script will install Uptime Kuma with HTTPS support."
echo "Please provide the following information:"
echo ""

# Domain name
prompt_input "Enter the fully qualified domain name (e.g., uptime.yourdomain.com or uptime.yourdomain.local)" \
    DOMAIN_NAME \
    "^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$" \
    "Invalid domain name format"

# Organization details for CSR
echo ""
print_info "Certificate details (press Enter to use defaults):"
echo ""

# Country code
read -p "Country code [US]: " COUNTRY
COUNTRY=${COUNTRY:-US}
if [[ ! "$COUNTRY" =~ ^[A-Z]{2}$ ]]; then
    print_error "Country code must be 2 uppercase letters"
    exit 1
fi

# State
read -p "State/Province [Virginia]: " STATE
STATE=${STATE:-Virginia}

# City
read -p "City [Anytown]: " CITY
CITY=${CITY:-Anytown}

# Organization
read -p "Organization name [Company]: " ORGANIZATION
ORGANIZATION=${ORGANIZATION:-Company}

# Organizational unit
read -p "Organizational unit [IT]: " ORG_UNIT
ORG_UNIT=${ORG_UNIT:-IT}

echo ""
print_success "Configuration collected"
echo ""
print_info "Certificate will be generated with:"
echo "  Domain: $DOMAIN_NAME"
echo "  Country: $COUNTRY"
echo "  State: $STATE"
echo "  City: $CITY"
echo "  Organization: $ORGANIZATION"
echo "  Organizational Unit: $ORG_UNIT"
echo ""

# Internal CA certificate
echo ""
print_info "You will need your internal root CA certificate."
echo ""
print_warning "Paste your internal root CA certificate below:"
print_info "(Paste the entire certificate and press Enter after the last line)"
echo ""
echo "Certificate should look like:"
echo "-----BEGIN CERTIFICATE-----"
echo "MIIDXTCCAkWgAwIBAgIJAKJ..."
echo "..."
echo "-----END CERTIFICATE-----"
echo ""

# Read multi-line certificate input until END CERTIFICATE is found
CA_CERT_CONTENT=""
while IFS= read -r line; do
    CA_CERT_CONTENT="${CA_CERT_CONTENT}${line}"$'\n'
    if [[ "$line" =~ "END CERTIFICATE" ]]; then
        break
    fi
done

# Validate certificate content
if [[ ! "$CA_CERT_CONTENT" =~ "BEGIN CERTIFICATE" ]]; then
    print_error "Invalid certificate content. Must contain '-----BEGIN CERTIFICATE-----'"
    exit 1
fi

if [[ ! "$CA_CERT_CONTENT" =~ "END CERTIFICATE" ]]; then
    print_error "Invalid certificate content. Must contain '-----END CERTIFICATE-----'"
    exit 1
fi

print_success "Configuration collected"

#############################################################################
# STEP 1: System Update
#############################################################################

print_header "STEP 1: Updating System"

apt update
apt upgrade -y

print_success "System updated"

#############################################################################
# STEP 2: Install Prerequisites
#############################################################################

print_header "STEP 2: Installing Prerequisites"

apt install -y ca-certificates curl gnupg ufw python3 python3-pip python3-venv net-tools

print_success "Prerequisites installed"

#############################################################################
# STEP 3: Install Docker
#############################################################################

print_header "STEP 3: Installing Docker"

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify Docker installation
docker --version

print_success "Docker installed"

#############################################################################
# STEP 4: Install Internal Root CA Certificate
#############################################################################

print_header "STEP 4: Installing Internal Root CA Certificate"

# Write CA certificate to trusted store
echo "$CA_CERT_CONTENT" > /usr/local/share/ca-certificates/internal-root-ca.crt

# Verify certificate was written and is valid
if [[ ! -f /usr/local/share/ca-certificates/internal-root-ca.crt ]]; then
    print_error "Failed to write CA certificate file"
    exit 1
fi

# Validate certificate is valid
if openssl x509 -in /usr/local/share/ca-certificates/internal-root-ca.crt -noout -text &>/dev/null; then
    print_success "Valid internal root CA certificate"
else
    print_error "CA certificate validation failed. Please check the certificate content."
    exit 1
fi

# Update CA certificates
update-ca-certificates

print_success "Internal root CA certificate installed"

#############################################################################
# STEP 5: Install Uptime Kuma
#############################################################################

print_header "STEP 5: Installing Uptime Kuma"

# Create directory
mkdir -p /opt/uptime-kuma
cd /opt/uptime-kuma

# Create docker-compose.yml with CA certificate mount
cat > compose.yaml <<EOF
services:
  uptime-kuma:
    image: louislam/uptime-kuma:2
    restart: unless-stopped
    volumes:
      - ./data:/app/data
      - /usr/local/share/ca-certificates/internal-root-ca.crt:/usr/local/share/ca-certificates/internal-root-ca.crt
    ports:
      - "3001:3001"
    environment:
      - NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/internal-root-ca.crt
EOF

# Start Uptime Kuma
docker compose up -d

# Wait for Uptime Kuma to start
sleep 10

# Verify Uptime Kuma is running
if docker ps | grep -q uptime-kuma; then
    print_success "Uptime Kuma container started"
else
    print_error "Failed to start Uptime Kuma container"
    exit 1
fi

# Test local access
if curl -s http://localhost:3001 > /dev/null; then
    print_success "Uptime Kuma is accessible on port 3001"
else
    print_error "Uptime Kuma is not responding on port 3001"
    exit 1
fi

#############################################################################
# STEP 6: Generate SSL Certificate Request
#############################################################################

print_header "STEP 6: Generating SSL Certificate Request"

# Create SSL directory
mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl

# Generate private key
openssl genrsa -out uptime-kuma.key 2048
chmod 600 uptime-kuma.key

# Create CSR configuration with SAN
cat > csr.conf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=$COUNTRY
ST=$STATE
L=$CITY
O=$ORGANIZATION
OU=$ORG_UNIT
CN=$DOMAIN_NAME

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN_NAME
EOF

# Generate CSR
openssl req -new -key uptime-kuma.key -out uptime-kuma.csr -config csr.conf

# Verify CSR includes SAN
if openssl req -text -noout -verify -in uptime-kuma.csr | grep -q "Subject Alternative Name"; then
    print_success "CSR generated with Subject Alternative Names"
else
    print_error "CSR does not include Subject Alternative Names"
    exit 1
fi

print_success "SSL private key and CSR generated"

#############################################################################
# STEP 7: Submit CSR to AD CA (MANUAL STEP)
#############################################################################

print_header "STEP 7: Submit CSR to AD Certificate Authority"

echo "The Certificate Signing Request (CSR) has been generated."
echo ""
print_info "CSR CONTENT (copy everything below):"
echo ""
echo "==============================================================================="
cat /etc/nginx/ssl/uptime-kuma.csr
echo "==============================================================================="
echo ""
print_warning "MANUAL STEPS:"
echo ""
echo "1. Copy the CSR content above (including BEGIN and END lines)"
echo ""
echo "2. Submit to your AD CA via web enrollment:"
echo "   - Navigate to: https://your-ca-server/certsrv"
echo "   - Click 'Request a certificate'"
echo "   - Click 'Advanced certificate request'"
echo "   - Click 'Submit a certificate request by using a base-64-encoded...'"
echo "   - Paste the CSR content"
echo "   - Select 'Web Server' template"
echo "   - Click Submit"
echo ""
echo "3. Download the certificate in Base 64 encoded format"
echo ""
echo "4. Copy the downloaded certificate content to your clipboard"
echo ""
echo ""
print_warning "When ready, paste the SIGNED CERTIFICATE below:"
print_info "(Paste the entire certificate and press Enter after the last line)"
echo ""

# Read multi-line certificate input until END CERTIFICATE is found
CERT_CONTENT=""
while IFS= read -r line; do
    CERT_CONTENT="${CERT_CONTENT}${line}"$'\n'
    if [[ "$line" =~ "END CERTIFICATE" ]]; then
        break
    fi
done

# Validate certificate content
if [[ ! "$CERT_CONTENT" =~ "BEGIN CERTIFICATE" ]]; then
    print_error "Invalid certificate content. Must contain '-----BEGIN CERTIFICATE-----'"
    exit 1
fi

if [[ ! "$CERT_CONTENT" =~ "END CERTIFICATE" ]]; then
    print_error "Invalid certificate content. Must contain '-----END CERTIFICATE-----'"
    exit 1
fi

# Write certificate to file
echo "$CERT_CONTENT" > /etc/nginx/ssl/uptime-kuma.crt

# Set permissions
chmod 644 /etc/nginx/ssl/uptime-kuma.crt

# Verify certificate was written
if [[ ! -f /etc/nginx/ssl/uptime-kuma.crt ]]; then
    print_error "Failed to write certificate file"
    exit 1
fi

# Verify certificate is valid
if openssl x509 -in /etc/nginx/ssl/uptime-kuma.crt -noout -text &>/dev/null; then
    print_success "Valid SSL certificate installed"
else
    print_error "Certificate validation failed. Please check the certificate content."
    exit 1
fi

#############################################################################
# STEP 8: Install and Configure Nginx
#############################################################################

print_header "STEP 8: Installing and Configuring Nginx"

# Install Nginx
apt update
apt install -y nginx

# Create Nginx configuration
cat > /etc/nginx/sites-available/uptime-kuma <<EOF
# HTTP - Redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME;
    
    # Redirect all HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS - Main configuration
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN_NAME;

    # SSL Certificate Configuration
    ssl_certificate /etc/nginx/ssl/uptime-kuma.crt;
    ssl_certificate_key /etc/nginx/ssl/uptime-kuma.key;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Logging
    access_log /var/log/nginx/uptime-kuma-access.log;
    error_log /var/log/nginx/uptime-kuma-error.log;
    
    # Proxy to Uptime Kuma Docker container
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        
        # WebSocket support (required for Uptime Kuma)
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Standard proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Timeouts
        proxy_read_timeout 86400;
        proxy_connect_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/uptime-kuma /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
if nginx -t; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration test failed"
    exit 1
fi

print_success "Nginx installed and configured"

#############################################################################
# STEP 9: Configure Firewall
#############################################################################

print_header "STEP 9: Configuring Firewall"

# Allow SSH first (critical!)
ufw allow 22/tcp comment 'SSH'

# Allow HTTP and HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Deny direct access to Uptime Kuma port
ufw deny 3001/tcp comment 'Block direct Uptime Kuma access'

# Enable UFW
echo "y" | ufw enable

ufw status

print_success "Firewall configured"

#############################################################################
# STEP 10: Start Services
#############################################################################

print_header "STEP 10: Starting Services"

# Restart Nginx
systemctl restart nginx
systemctl enable nginx

# Verify Nginx is running
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_error "Nginx failed to start"
    systemctl status nginx
    exit 1
fi

# Verify Nginx is listening on ports 80 and 443
if netstat -tlnp | grep -q ':80.*nginx' && netstat -tlnp | grep -q ':443.*nginx'; then
    print_success "Nginx is listening on ports 80 and 443"
else
    print_error "Nginx is not listening on expected ports"
    netstat -tlnp | grep nginx
    exit 1
fi

#############################################################################
# STEP 11: Create Admin Account (MANUAL STEP)
#############################################################################

print_header "STEP 11: Create Uptime Kuma Admin Account"

echo -e "${GREEN}✓ All services are running!${NC}"
echo ""
print_warning "MANUAL STEP REQUIRED:"
echo ""
echo "You must now create your Uptime Kuma admin account through the web interface."
echo ""
echo "1. Open your web browser"
echo ""
echo -n "2. Navigate to: "
echo -e "${BLUE}https://$DOMAIN_NAME${NC}"
echo ""
echo "3. You will see the Uptime Kuma setup page"
echo ""
echo "4. Select database type:"
echo "   - Choose 'Embedded MariaDB Database' (recommended)"
echo ""
echo "5. Create your admin account:"
echo "   - Enter a username (e.g., admin, your name, etc.)"
echo "   - Enter a strong password"
echo "   - Re-enter the password to confirm"
echo "   - Click 'Create'"
echo ""
echo "6. You will be automatically logged in"
echo ""
print_warning "IMPORTANT: Save these credentials - you'll need them in the next step!"
echo ""

pause_for_manual_step

echo ""
print_info "Now enter the credentials you just created:"
echo ""

# Prompt for username
prompt_input "Enter your Uptime Kuma username" \
    KUMA_USERNAME \
    ".+" \
    "Username cannot be empty"

# Prompt for password (hidden input)
while true; do
    read -sp "Enter your Uptime Kuma password: " KUMA_PASSWORD
    echo ""
    if [[ -n "$KUMA_PASSWORD" ]]; then
        break
    else
        print_error "Password cannot be empty"
    fi
done

print_success "Admin credentials captured"

#############################################################################
# STEP 12: Set Up Bulk Monitor Import
#############################################################################

print_header "STEP 12: Setting Up Bulk Monitor Import"

# Create bulk import directory
mkdir -p /root/uptime-kuma-import
cd /root/uptime-kuma-import

print_success "Created bulk import directory: /root/uptime-kuma-import"

# Create Python virtual environment
python3 -m venv kuma-venv

print_success "Created Python virtual environment"

# Activate venv and install uptime-kuma-api
source kuma-venv/bin/activate
pip install --quiet uptime-kuma-api

print_success "Installed uptime-kuma-api library"

# Create import script
cat > import_monitors.py <<'IMPORT_SCRIPT'
"""
Script Name: import_monitors.py
Description: Bulk import HTTPS monitors into Uptime Kuma from a CSV file.
             Automatically handles duplicates by URL, sets heartbeat interval,
             and enables certificate expiry notifications.
Author: Auto-generated
Requirements:
    - Python 3.8+
    - uptime-kuma-api Python library
    - monitors.csv file in the same directory
Usage:
    1. Activate virtual environment:
       source kuma-venv/bin/activate
    2. Run:
       python import_monitors.py
Notes:
    - Duplicate detection is by URL.
    - Only HTTPS URLs are processed.
"""

import csv
from uptime_kuma_api import UptimeKumaApi

# ===== Configuration =====
KUMA_URL = "http://127.0.0.1:3001"  # URL to your Uptime Kuma instance
USERNAME = "PLACEHOLDER_USERNAME"    # Uptime Kuma username
PASSWORD = "PLACEHOLDER_PASSWORD"    # Uptime Kuma password
CSV_FILE = "monitors.csv"           # CSV file containing monitors

# ===== Connect to Uptime Kuma =====
api = UptimeKumaApi(KUMA_URL)
api.login(USERNAME, PASSWORD)

# ===== Fetch existing monitors to handle duplicates =====
existing_monitors = api.get_monitors()
existing_urls = {m["url"] for m in existing_monitors}

# ===== Read CSV and create monitors =====
with open(CSV_FILE, newline="", encoding="utf-8") as csvfile:
    reader = csv.DictReader(csvfile)

    for row in reader:
        name = row["name"].strip()
        url = row["url"].strip()

        # Only process HTTPS URLs for certificate expiry monitoring
        if not url.lower().startswith("https://"):
            print(f"Skipping {name}: URL is not HTTPS")
            continue

        # Skip duplicates
        if url in existing_urls:
            print(f"Skipping {name}: URL already exists")
            continue

        try:
            # ===== Create HTTPS monitor =====
            api.add_monitor(
                type="http",
                name=name,
                url=url,
                interval=86400,           # Heartbeat interval in seconds (24 hours)
                retryInterval=60,
                maxretries=3,
                expiryNotification=True,  # Enable certificate expiry alerts
                ignoreTls=False           # Validate certificates
            )

            print(f"Added monitor: {name}")

            # Add URL to set to prevent future duplicates in same run
            existing_urls.add(url)

        except Exception as e:
            print(f"Failed to add {name}: {e}")

# ===== Disconnect =====
api.disconnect()
print("Import complete.")
IMPORT_SCRIPT

# Replace placeholders with actual credentials
sed -i "s/PLACEHOLDER_USERNAME/$KUMA_USERNAME/g" import_monitors.py
sed -i "s/PLACEHOLDER_PASSWORD/$KUMA_PASSWORD/g" import_monitors.py

print_success "Created import_monitors.py script with credentials"

# Prompt for test site
echo ""
print_info "Let's add a test monitor to verify the bulk import works."
echo ""

prompt_input "Enter a test HTTPS URL to monitor (e.g., https://google.com)" \
    TEST_URL \
    "^https://.+" \
    "URL must start with https://"

# Extract domain for monitor name
TEST_NAME=$(echo "$TEST_URL" | sed -e 's|^https://||' -e 's|/.*||')

# Create monitors.csv with test site
cat > monitors.csv <<CSV_CONTENT
name,url
$TEST_NAME,$TEST_URL
CSV_CONTENT

print_success "Created monitors.csv with test site"

# Run the import script
echo ""
print_info "Running bulk import to add test monitor..."
echo ""

python import_monitors.py

echo ""

# Verify import worked by checking if we can connect
if python -c "from uptime_kuma_api import UptimeKumaApi; api = UptimeKumaApi('http://127.0.0.1:3001'); api.login('$KUMA_USERNAME', '$KUMA_PASSWORD'); monitors = api.get_monitors(); api.disconnect(); exit(0 if len(monitors) > 0 else 1)" 2>/dev/null; then
    print_success "Bulk import test successful! Monitor added to Uptime Kuma"
else
    print_warning "Could not verify monitor was added, but import script completed"
fi

deactivate  # Deactivate venv

print_success "Bulk import environment configured"

#############################################################################
# INSTALLATION COMPLETE
#############################################################################

print_header "INSTALLATION COMPLETE"

echo -e "${GREEN}✓ Uptime Kuma has been successfully installed and configured!${NC}"
echo ""
echo "Access your Uptime Kuma instance at:"
echo -e "${BLUE}  https://$DOMAIN_NAME${NC}"
echo ""
echo "Login credentials:"
echo -e "  Username: ${BLUE}$KUMA_USERNAME${NC}"
echo -e "  Password: ${BLUE}(the password you created)${NC}"
echo ""
echo "WHAT WAS INSTALLED:"
echo ""
echo "✓ Docker & Docker Compose"
echo "✓ Uptime Kuma (running in Docker on port 3001)"
echo "✓ Nginx reverse proxy (HTTPS on port 443, HTTP on port 80)"
echo "✓ Internal root CA certificate"
echo "✓ UFW firewall (SSH, HTTP, HTTPS allowed)"
echo "✓ Python 3 and virtual environment"
echo "✓ Bulk monitor import environment"
echo "✓ Test monitor added: $TEST_NAME"
echo ""
echo "BULK MONITOR IMPORT:"
echo ""
echo "The bulk import environment is ready at: /root/uptime-kuma-import"
echo ""
echo "To add more monitors:"
echo "  1. cd /root/uptime-kuma-import"
echo "  2. Edit monitors.csv (add one monitor per line: name,url)"
echo "  3. source kuma-venv/bin/activate"
echo "  4. python import_monitors.py"
echo "  5. deactivate"
echo ""
echo "The CSV can contain ALL monitors - duplicates are automatically skipped."
echo ""
echo "IMPORTANT FILE LOCATIONS:"
echo "  - Uptime Kuma data: /opt/uptime-kuma/data"
echo "  - SSL private key: /etc/nginx/ssl/uptime-kuma.key (600)"
echo "  - SSL certificate: /etc/nginx/ssl/uptime-kuma.crt (644)"
echo "  - Nginx config: /etc/nginx/sites-available/uptime-kuma"
echo "  - Internal CA: /usr/local/share/ca-certificates/internal-root-ca.crt"
echo "  - Bulk import: /root/uptime-kuma-import/"
echo "  - Import script: /root/uptime-kuma-import/import_monitors.py"
echo "  - Monitor list: /root/uptime-kuma-import/monitors.csv"
echo ""
echo "USEFUL COMMANDS:"
echo "  - Restart Uptime Kuma: docker restart uptime-kuma"
echo "  - View Uptime Kuma logs: docker logs uptime-kuma"
echo "  - Restart Nginx: systemctl restart nginx"
echo "  - Test Nginx config: nginx -t"
echo "  - Check firewall: ufw status"
echo "  - Run bulk import: cd /root/uptime-kuma-import && source kuma-venv/bin/activate && python import_monitors.py"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Log into Uptime Kuma at https://$DOMAIN_NAME"
echo "2. Verify your test monitor ($TEST_NAME) appears in the dashboard"
echo "3. Configure notification methods (Settings → Notifications)"
echo "4. Add more monitors using the bulk import or web interface"
echo ""
print_success "Installation and configuration completed successfully!"