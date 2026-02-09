# Uptime Kuma Automated Installation Script

## ⚠️ Important Notice

**This installation script is designed for fresh, test Ubuntu Server installations.** It makes system-level changes including installing Docker, Nginx, configuring the firewall, and modifying network settings. 

**DO NOT run this script on:**
- Production servers
- Servers with existing applications or services
- Servers you don't have a backup of

**Recommended Use:**
- Fresh Ubuntu Server 24.04.3 minimal installation
- Test/lab environments
- Dedicated VM or container for Uptime Kuma

## Overview

This script automates the complete installation of Uptime Kuma with HTTPS on Ubuntu Server 24.04.3.

**Repository:** https://github.com/2plus2cabbage/uptime-kuma

## What It Does

**Automated Steps:**
- System updates
- Docker installation and configuration
- Uptime Kuma deployment with internal CA certificate trust
- SSL private key and CSR generation with SAN
- Nginx installation and configuration
- Firewall configuration (UFW)
- Service startup and verification

**Manual Steps Required:**
- Provide configuration information (domain, organization details)
- Submit CSR to your AD Certificate Authority
- Download and install the signed certificate

## Prerequisites

- **Fresh Ubuntu Server 24.04.3 minimal installation** (not for production servers with existing services)
- Root or sudo access
- Internal root CA certificate or certificate chain (base64 encoded)
- Access to your AD Certificate Authority for certificate signing
- DNS record pointing to your server

## Usage

### 1. Download the script

```bash
wget https://raw.githubusercontent.com/2plus2cabbage/uptime-kuma/main/install-uptime-kuma.sh
# or
curl -O https://raw.githubusercontent.com/2plus2cabbage/uptime-kuma/main/install-uptime-kuma.sh
```

### 2. Make it executable

```bash
chmod +x install-uptime-kuma.sh
```

### 3. Run the script

```bash
sudo ./install-uptime-kuma.sh
```

The script will display a warning and ask you to confirm this is a fresh test installation. Type `yes` to continue.

### 4. Follow the prompts

The script will ask for:
- Fully qualified domain name (e.g., uptime.yourdomain.com or uptime.local)
- Certificate details with defaults (press Enter to accept):
  - Country code [US]
  - State/Province [Virginia]
  - City [Anytown]
  - Organization name [Company]
  - Organizational unit [IT]

**Tip:** Press Enter for each field to quickly accept all defaults, or type custom values as needed.

### 5. Paste internal root CA certificate

The script will prompt you to paste your internal root CA certificate (or certificate chain):
- Have your CA certificate ready (base64 encoded)
- For certificate chains: paste all certificates in order (intermediate first, then root)
- Paste the entire certificate(s) including all BEGIN and END lines
- Press Enter after the last line, then press Enter again on a blank line to finish

**Single certificate format:**
```
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAKJ...
-----END CERTIFICATE-----
<blank line>
```

**Certificate chain format:**
```
-----BEGIN CERTIFICATE-----
(intermediate certificate)
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
(root certificate)
-----END CERTIFICATE-----
<blank line>
```

### 6. Complete certificate signing

The script will:
1. Display the generated CSR on screen
2. Provide instructions for submitting to your AD CA
3. Wait for you to paste the signed certificate content
4. Automatically continue after detecting the end of the certificate

**Workflow:**
- Copy the displayed CSR
- Submit to AD CA (https://your-ca-server/certsrv)
- Select "Web Server" template
- Download certificate in Base 64 format
- Copy the certificate content (should look like):
  ```
  -----BEGIN CERTIFICATE-----
  MIIDXTCCAkWgAwIBAgIJAKJ...
  (multiple lines of base64 text)
  ...vQIDAQAB
  -----END CERTIFICATE-----
  ```
- Paste it into the terminal
- Press Enter after the last line - script will automatically continue

### 7. Create admin account

After services start, the script will pause and ask you to:
1. Open your browser to `https://your-domain.com`
2. Select database type: Choose 'Embedded MariaDB Database' (recommended)
3. Create your admin account through the web interface
4. Return to the terminal and enter the username and password you created

### 8. Bulk import setup

The script will automatically:
1. Set up Python virtual environment
2. Install uptime-kuma-api library
3. Create import script with your credentials
4. Prompt for a test HTTPS URL
5. Create monitors.csv and add the test monitor
6. Verify the import works

### 9. Access Uptime Kuma

Once complete, access your instance at: `https://your-domain.com`

## What Gets Installed

- **Docker CE** - Container runtime
- **Uptime Kuma** - Monitoring application (Docker container)
- **Nginx** - Reverse proxy with SSL/TLS termination
- **UFW** - Firewall (SSH, HTTP, HTTPS allowed)
- **Internal CA** - Root certificate for trust
- **Python 3** - For bulk import automation
- **Bulk Import Environment** - Virtual environment with uptime-kuma-api library
- **Import Script** - Configured with your credentials
- **Test Monitor** - Validates bulk import works

## File Locations

| File/Directory | Purpose |
|---------------|---------|
| `/opt/uptime-kuma/` | Uptime Kuma installation directory |
| `/opt/uptime-kuma/data/` | Persistent data volume |
| `/etc/nginx/ssl/uptime-kuma.key` | SSL private key (600 permissions) |
| `/etc/nginx/ssl/uptime-kuma.crt` | SSL certificate (644 permissions) |
| `/etc/nginx/ssl/uptime-kuma.csr` | Certificate signing request |
| `/etc/nginx/ssl/csr.conf` | CSR configuration with SAN |
| `/etc/nginx/sites-available/uptime-kuma` | Nginx configuration |
| `/usr/local/share/ca-certificates/internal-root-ca.crt` | Internal root CA |
| `/root/uptime-kuma-import/` | Bulk import working directory |
| `/root/uptime-kuma-import/kuma-venv/` | Python virtual environment |
| `/root/uptime-kuma-import/import_monitors.py` | Import script (with credentials) |
| `/root/uptime-kuma-import/monitors.csv` | Monitor list CSV file |

## Troubleshooting

### Script fails during certificate paste

If you see "Invalid certificate content":
- Ensure you copied the entire certificate including `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`
- For certificate chains: ensure all certificates are included with their BEGIN/END markers
- Verify you downloaded the certificate in Base 64 encoded format (not DER/binary)
- Make sure there are no extra characters before or after the certificate(s)
- For chains: after pasting the last certificate, press Enter on a blank line to finish
- The script automatically detects certificate chains and will indicate how many certificates were found
- Try pasting again

### Script fails during execution

The script uses `set -e` which means it exits on any error. Check the error message and:
- Ensure you have internet connectivity
- Verify all prerequisites are met
- Check that the internal CA certificate file exists

### Certificate not trusted in browser

- **Domain-joined Windows:** Should work automatically via Group Policy
- **Non-domain machines:** Manually import the internal root CA certificate to Trusted Root Certification Authorities

### Can't access Uptime Kuma

1. Check Docker container is running: `docker ps`
2. Check Nginx is running: `systemctl status nginx`
3. Check firewall: `ufw status`
4. Check Nginx logs: `tail -f /var/log/nginx/uptime-kuma-error.log`

### Port 3001 accessible externally

This is blocked by the firewall by default. If you need to access it:
```bash
sudo ufw allow 3001/tcp
```

## Useful Commands

```bash
# Restart Uptime Kuma
docker restart uptime-kuma

# View Uptime Kuma logs
docker logs -f uptime-kuma

# Restart Nginx
sudo systemctl restart nginx

# Reload Nginx (no downtime)
sudo systemctl reload nginx

# Test Nginx configuration
sudo nginx -t

# Check firewall status
sudo ufw status

# Check listening ports
sudo netstat -tlnp | grep nginx

# Check certificate expiry
openssl x509 -in /etc/nginx/ssl/uptime-kuma.crt -noout -dates

# Run bulk monitor import
cd /root/uptime-kuma-import && source kuma-venv/bin/activate && python import_monitors.py && deactivate

# Edit monitor list
nano /root/uptime-kuma-import/monitors.csv
```

## Security Notes

- Private key has 600 permissions (root only)
- Port 3001 is blocked from external access
- All HTTP traffic redirects to HTTPS
- Strong TLS ciphers configured (TLS 1.2/1.3 only)
- Security headers enabled (HSTS, X-Frame-Options, etc.)

## Post-Installation

After installation completes, the admin account has already been created during the installation process.

**Next steps:**

1. Log into Uptime Kuma at `https://your-domain.com` with the credentials you created
2. Verify your test monitor appears in the dashboard
3. Configure notification methods (Settings → Notifications):
   - Email (SMTP)
   - Discord
   - Slack
   - Telegram
   - 90+ other options
4. Use bulk import to add more monitors

## Using Bulk Import

The bulk import environment is ready to use immediately after installation.

**To add more monitors:**

```bash
# Navigate to import directory
cd /root/uptime-kuma-import

# Edit the CSV file
nano monitors.csv
```

Add monitors in this format:
```csv
name,url
Google,https://www.google.com/
GitHub,https://github.com/
YourSite,https://yoursite.com/
```

**Run the import:**

```bash
# Activate virtual environment
source kuma-venv/bin/activate

# Run import script
python import_monitors.py

# Deactivate when done
deactivate
```

**Important Notes:**
- The CSV can contain ALL monitors - duplicates are automatically skipped
- Only HTTPS URLs are processed
- Monitors are created with 24-hour heartbeat interval
- Certificate expiry notifications are enabled automatically

## License

This script is provided as-is for use with the Uptime Kuma deployment guides.
