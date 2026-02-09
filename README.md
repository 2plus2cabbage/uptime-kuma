<img align="right" width="150" src="https://github.com/2plus2cabbage/2plus2cabbage/blob/main/images/2plus2cabbage.png">

<img src="https://github.com/2plus2cabbage/2plus2cabbage/blob/main/images/uptime-kuma.png" alt="uptime-kuma" width="300" align="left">
<br clear="left">

# Uptime Kuma Deployment with HTTPS

Deploys Uptime Kuma monitoring platform on Ubuntu Server 24.04.3 with Docker, secured by Nginx reverse proxy and internal AD Certificate Authority.  The default docker install of Uptime Kuma only supports HTTP.  This guide shows how to secure the connection with HTTPS using a reverse proxy.  The addition of the internal root CA certificate allows you to use Uptime Kuma to check certificate expirations for internal resources in addition to public web sites.

## Documentation
The project includes three comprehensive PDF guides that cover the complete deployment process:
- [Uptime_Kuma_Installation_Guide.pdf](Uptime_Kuma_Installation_Guide.pdf): Installing Uptime Kuma with Docker and internal root certificate support.
- [Uptime_Kuma_HTTPS_Setup_Guide.pdf](Uptime_Kuma_HTTPS_Setup_Guide.pdf): Configuring Nginx reverse proxy with SSL/TLS from your internal AD Certificate Authority.
- [Uptime_Kuma_Bulk_Monitor_Import.pdf](Uptime_Kuma_Bulk_Monitor_Import.pdf): Automating monitor creation using Python scripts and CSV files for bulk imports.

**Automated Installation (Test Environments Only):**
- [install-uptime-kuma.sh](install-uptime-kuma.sh): Complete automated installation script for fresh Ubuntu installations.
- [INSTALL_SCRIPT_README.md](INSTALL_SCRIPT_README.md): Installation script documentation and usage guide.

## Files
The deployment creates several key configuration files across the system:
- `compose.yaml`: Docker Compose configuration for Uptime Kuma container.
- `/etc/nginx/ssl/csr.conf`: OpenSSL CSR configuration with Subject Alternative Names (SAN).
- `/etc/nginx/ssl/uptime-kuma.key`: Private key for SSL/TLS (600 permissions).
- `/etc/nginx/ssl/uptime-kuma.crt`: SSL certificate from your AD CA (644 permissions).
- `/etc/nginx/sites-available/uptime-kuma`: Nginx reverse proxy configuration.
- `/usr/local/share/ca-certificates/internal-root-ca.crt`: Your internal root CA certificate.
- `~/uptime-kuma-import/import_monitors.py`: Python script for bulk monitor imports (optional).
- `~/uptime-kuma-import/monitors.csv`: CSV file containing monitor list (optional).

## How It Works
- **Container**: Uptime Kuma runs in Docker with persistent data storage and internal CA certificate trust configured via `NODE_EXTRA_CA_CERTS`.
- **Reverse Proxy**: Nginx terminates SSL/TLS on port 443 and proxies to Docker container on localhost:3001. WebSocket support enabled for real-time updates.
- **Local Firewall**: UFW is used to secure inbound access to the web server, restricting access to only ports 80 and 443 and blocking direct access to 3001, the default Uptime Kuma port.
- **Security**: HTTP (port 80) redirects to HTTPS (port 443). TLS 1.2/1.3 with strong cipher suites. Security headers prevent XSS, clickjacking, and enforce HSTS.
- **Certificate**: Uses certificates from internal Active Directory CA with Subject Alternative Names (SAN) for modern browser compatibility.
- **Bulk Operations**: Python script automates monitor creation from CSV files with duplicate detection, consistent configuration, and certificate expiry notifications.

## Bulk Monitor Management
For organizations monitoring multiple HTTPS endpoints, manual monitor creation can be time-consuming. The bulk import feature provides:
- **Automated Creation**: Import dozens or hundreds of monitors from a simple CSV file (name, url format).
- **Duplicate Detection**: Script automatically skips existing monitors based on URL, allowing you to maintain a master CSV list.
- **Consistent Configuration**: All monitors created with identical settings (24-hour heartbeat, certificate expiry alerts, TLS validation).
- **Simple Workflow**: Edit CSV file, activate Python virtual environment, run script. Updates are incremental - only new monitors are added.

This is particularly useful for monitoring certificate expiration dates across multiple internal web applications or external vendor sites.

## Prerequisites
- Ubuntu Server 24.04.3 (minimal installation).
- Sudo/root access on the Ubuntu server.
- Internal root CA certificate file from your organization.
- Access to your Windows Active Directory Certificate Authority (or internal CA of your choice) for certificate issuance.
- DNS record pointing to your server (e.g., `uptime.yourdomain.com` or `uptime.yourdomain.local`).
- Ports 80 and 443 available and accessible; port 3001 blocked from external access.
- Basic understanding of Linux command line, Docker, and Nginx.

## Deployment Overview

**Option 1: Automated Installation Script (Recommended for Test Environments)**
- Run `install-uptime-kuma.sh` for automated setup on fresh Ubuntu installations
- See [INSTALL_SCRIPT_README.md](INSTALL_SCRIPT_README.md) for details
- ⚠️ For fresh test installations only, not production servers

**Option 2: Manual Installation (Recommended for Production)**
1. Follow `Uptime_Kuma_Installation_Guide.pdf` to install Docker, configure internal certificate trust, and deploy Uptime Kuma container.
2. Follow `Uptime_Kuma_HTTPS_Setup_Guide.pdf` to generate CSR with SAN, obtain certificate from AD CA, configure Nginx reverse proxy, and enable HTTPS.
3. Access your secured Uptime Kuma instance at `https://uptime.yourdomain.com`.
4. On domain-joined Windows clients, certificates are trusted automatically via Group Policy. For non-domain clients, manually import the internal root CA certificate.
5. (Optional) Follow `Uptime_Kuma_Bulk_Monitor_Import.pdf` to set up automated bulk monitor creation from CSV files.

## Architecture
```
Internet/Users → Port 443 (HTTPS) → Nginx (SSL Termination) → Port 3001 (HTTP) → Uptime Kuma Docker Container
```

All HTTP traffic on port 80 is redirected to HTTPS on port 443. Nginx handles SSL/TLS encryption and forwards unencrypted traffic to the Docker container on localhost only.

## Potential costs and licensing
- The resources deployed using this guide should generally incur minimal costs on self-hosted infrastructure.
- It is important to fully understand your organization's policies regarding certificate issuance, SSL/TLS configurations, and security requirements.
- You are responsible for maintaining certificate validity, monitoring for security updates, and ensuring compliance with your organization's security standards.
- Regular backups of the Uptime Kuma data volume are recommended for disaster recovery.
