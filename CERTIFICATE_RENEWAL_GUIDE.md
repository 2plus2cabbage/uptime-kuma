# Uptime Kuma Certificate Renewal Guide

## Overview

This guide covers two certificate renewal scenarios:
1. **Web Server Certificate Renewal** - Renewing the SSL/TLS certificate for your Uptime Kuma web interface
2. **Root CA Certificate Replacement** - Replacing the internal root CA certificate when it expires or is renewed

Both procedures can be performed without data loss and with minimal downtime.

---

## Scenario 1: Web Server Certificate Renewal

### When to Renew

Check your certificate expiration date:
```bash
sudo openssl x509 -in /etc/nginx/ssl/uptime-kuma.crt -noout -dates
```

**Recommendation:** Renew certificates 30 days before expiration.

### Prerequisites

- SSH access to your Uptime Kuma server
- Access to your AD Certificate Authority
- Original certificate details (domain, organization, etc.)

### Step 1: Check Current Certificate Details

View your current certificate information:
```bash
sudo openssl x509 -in /etc/nginx/ssl/uptime-kuma.crt -noout -subject -issuer
```

This shows the details you'll need to match in the new CSR.

### Step 2: Generate New Private Key (Optional)

**Option A: Reuse existing private key (simpler)**
- Skip this step and reuse `/etc/nginx/ssl/uptime-kuma.key`

**Option B: Generate new private key (more secure)**
```bash
cd /etc/nginx/ssl
sudo mv uptime-kuma.key uptime-kuma.key.old
sudo openssl genrsa -out uptime-kuma.key 2048
sudo chmod 600 uptime-kuma.key
```

### Step 3: Generate New CSR

The existing CSR configuration can be reused:
```bash
cd /etc/nginx/ssl
sudo openssl req -new -key uptime-kuma.key -out uptime-kuma-renewal.csr -config csr.conf
```

**Verify the CSR includes Subject Alternative Names:**
```bash
sudo openssl req -text -noout -verify -in uptime-kuma-renewal.csr | grep -A 2 "Subject Alternative Name"
```

### Step 4: Display CSR for Submission

```bash
sudo cat /etc/nginx/ssl/uptime-kuma-renewal.csr
```

Copy the entire output including `-----BEGIN CERTIFICATE REQUEST-----` and `-----END CERTIFICATE REQUEST-----`.

### Step 5: Submit CSR to AD CA

1. Navigate to your AD CA web enrollment page:
   - `https://your-ca-server/certsrv`

2. Click **"Request a certificate"**

3. Click **"Advanced certificate request"**

4. Click **"Submit a certificate request by using a base-64-encoded..."**

5. Paste your CSR content

6. Select **"Web Server"** template

7. Click **Submit**

8. Download the certificate in **Base 64 encoded** format

### Step 6: Backup Current Certificate

```bash
sudo cp /etc/nginx/ssl/uptime-kuma.crt /etc/nginx/ssl/uptime-kuma.crt.backup.$(date +%Y%m%d)
```

### Step 7: Install New Certificate

Save the downloaded certificate content to a file on your local machine, then copy it to the server:

**Option A: Using SCP**
```bash
scp uptime-kuma-new.cer user@your-server:/tmp/
```

Then on the server:
```bash
sudo mv /tmp/uptime-kuma-new.cer /etc/nginx/ssl/uptime-kuma.crt
sudo chmod 644 /etc/nginx/ssl/uptime-kuma.crt
```

**Option B: Direct paste (via SSH session)**
```bash
sudo nano /etc/nginx/ssl/uptime-kuma.crt
```
Paste the certificate content, save and exit.

### Step 8: Verify New Certificate

Check the certificate is valid:
```bash
sudo openssl x509 -in /etc/nginx/ssl/uptime-kuma.crt -noout -text
```

Verify the dates:
```bash
sudo openssl x509 -in /etc/nginx/ssl/uptime-kuma.crt -noout -dates
```

Test Nginx configuration:
```bash
sudo nginx -t
```

### Step 9: Reload Nginx

**No downtime reload:**
```bash
sudo systemctl reload nginx
```

**Alternative (brief downtime):**
```bash
sudo systemctl restart nginx
```

### Step 10: Verify in Browser

1. Open your browser
2. Navigate to `https://your-uptime-kuma-domain.com`
3. Click the padlock icon
4. Verify the new certificate details and expiration date

### Cleanup (Optional)

After confirming the new certificate works:
```bash
sudo rm /etc/nginx/ssl/uptime-kuma-renewal.csr
sudo rm /etc/nginx/ssl/uptime-kuma.crt.backup.*
# Only if you generated a new key:
sudo rm /etc/nginx/ssl/uptime-kuma.key.old
```

---

## Scenario 2: Root CA Certificate Replacement

### When to Replace

Your internal root CA certificate needs replacement when:
- The root CA certificate has expired or is about to expire
- Your organization has renewed/replaced the root CA
- You need to update to a new internal CA

### Prerequisites

- SSH access to your Uptime Kuma server
- New internal root CA certificate file (Base 64 encoded .crt or .cer)

### Step 1: Obtain New Root CA Certificate

Get the new root CA certificate from your IT/Security team or download it from your organization's certificate distribution point.

### Step 2: Backup Current Root CA Certificate

```bash
sudo cp /usr/local/share/ca-certificates/internal-root-ca.crt \
       /usr/local/share/ca-certificates/internal-root-ca.crt.backup.$(date +%Y%m%d)
```

### Step 3: Install New Root CA Certificate

**Option A: Copy from local machine**
```bash
scp new-root-ca.crt user@your-server:/tmp/
```

Then on the server:
```bash
sudo mv /tmp/new-root-ca.crt /usr/local/share/ca-certificates/internal-root-ca.crt
sudo chmod 644 /usr/local/share/ca-certificates/internal-root-ca.crt
```

**Option B: Direct paste**
```bash
sudo nano /usr/local/share/ca-certificates/internal-root-ca.crt
```
Paste the certificate content, save and exit (Ctrl+X, Y, Enter).

### Step 4: Update System CA Trust Store

```bash
sudo update-ca-certificates
```

You should see output indicating certificates were added/updated.

### Step 5: Verify New Root CA

```bash
sudo openssl x509 -in /usr/local/share/ca-certificates/internal-root-ca.crt -noout -subject -dates
```

Verify the subject and dates match your new root CA.

### Step 6: Update Uptime Kuma Docker Container

The Uptime Kuma container needs to be updated with the new root CA certificate.

**Stop the container:**
```bash
cd /opt/uptime-kuma
docker compose down
```

The compose.yaml file already mounts the CA certificate, so the new certificate will be automatically available when you restart.

**Start the container:**
```bash
docker compose up -d
```

### Step 7: Verify Container Started

```bash
docker ps | grep uptime-kuma
```

Check logs for any errors:
```bash
docker logs uptime-kuma
```

### Step 8: Test Uptime Kuma

1. Open browser and navigate to `https://your-uptime-kuma-domain.com`
2. Log in to Uptime Kuma
3. Check that existing monitors are working
4. If you have monitors checking internal HTTPS resources:
   - Verify they are still functioning correctly
   - Check for any certificate validation errors

### Step 9: Test Internal Certificate Validation

If you monitor internal resources with certificates issued by your root CA, test one:

1. In Uptime Kuma, check a monitor that accesses an internal HTTPS resource
2. Verify it shows as "Up" and not experiencing certificate errors
3. Check the certificate expiry information is displayed correctly

### Cleanup (Optional)

After confirming everything works:
```bash
sudo rm /usr/local/share/ca-certificates/internal-root-ca.crt.backup.*
```

---

## Troubleshooting

### Web Server Certificate Issues

**Nginx fails to start after certificate replacement:**
```bash
# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Verify certificate and key match
sudo openssl x509 -noout -modulus -in /etc/nginx/ssl/uptime-kuma.crt | openssl md5
sudo openssl rsa -noout -modulus -in /etc/nginx/ssl/uptime-kuma.key | openssl md5
# The MD5 hashes should match
```

**Browser shows certificate warning:**
- Clear browser cache and try again
- Verify certificate is valid: `sudo openssl x509 -in /etc/nginx/ssl/uptime-kuma.crt -noout -dates`
- Check certificate chain is complete
- Ensure the certificate's Common Name or SAN matches your domain

**Certificate appears valid but browser doesn't trust it:**
- Verify the issuing CA is trusted
- On domain-joined Windows: Wait for Group Policy to update (or run `gpupdate /force`)
- On non-domain machines: Import the internal root CA certificate manually

### Root CA Certificate Issues

**Uptime Kuma container won't start:**
```bash
# Check container logs
docker logs uptime-kuma

# Verify certificate file exists and is readable
ls -la /usr/local/share/ca-certificates/internal-root-ca.crt

# Verify certificate is valid
sudo openssl x509 -in /usr/local/share/ca-certificates/internal-root-ca.crt -noout -text
```

**Internal monitors show certificate errors:**
- Verify the new root CA is correctly installed: `sudo update-ca-certificates --fresh`
- Restart the Uptime Kuma container: `docker restart uptime-kuma`
- Check the certificate chain on the internal resource being monitored
- Verify the internal resource's certificate was issued by the new root CA

**System doesn't trust the new root CA:**
```bash
# Force update CA certificates
sudo update-ca-certificates --fresh

# Verify the certificate is in the trust store
ls -la /etc/ssl/certs/ | grep internal-root-ca
```

---

## Preventive Maintenance

### Set Up Certificate Expiration Monitoring

**For Web Server Certificate:**

Use Uptime Kuma itself to monitor your certificate:
1. Create a new HTTPS monitor
2. Point it to your own domain: `https://your-uptime-kuma-domain.com`
3. Enable "Certificate Expiry" notification
4. Set notification threshold (e.g., 30 days)

**Calendar Reminders:**

Set recurring calendar reminders:
- Web server certificate: 30 days before expiration
- Root CA certificate: Review annually or when IT announces renewal

### Keep Records

Document in a secure location:
- Certificate expiration dates
- Certificate serial numbers
- Renewal dates
- Who performed the renewal
- Any issues encountered

---

## Quick Reference

### File Locations

| File | Purpose | Permissions |
|------|---------|-------------|
| `/etc/nginx/ssl/uptime-kuma.key` | Web server private key | 600 |
| `/etc/nginx/ssl/uptime-kuma.crt` | Web server certificate | 644 |
| `/etc/nginx/ssl/csr.conf` | CSR configuration | 644 |
| `/usr/local/share/ca-certificates/internal-root-ca.crt` | Root CA certificate | 644 |

### Common Commands

```bash
# Check web server certificate expiration
sudo openssl x509 -in /etc/nginx/ssl/uptime-kuma.crt -noout -dates

# Check root CA certificate expiration
sudo openssl x509 -in /usr/local/share/ca-certificates/internal-root-ca.crt -noout -dates

# Reload Nginx (no downtime)
sudo systemctl reload nginx

# Restart Uptime Kuma container
docker restart uptime-kuma

# Update CA trust store
sudo update-ca-certificates

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log

# Check Uptime Kuma logs
docker logs -f uptime-kuma
```

---

## Best Practices

1. **Plan Ahead**: Start the renewal process 30 days before expiration
2. **Test First**: If possible, test the renewal process in a non-production environment
3. **Backup Everything**: Always backup current certificates before replacing
4. **Document Changes**: Keep records of renewal dates and any issues
5. **Verify Thoroughly**: After renewal, test both web access and internal monitors
6. **Schedule Maintenance**: Perform renewals during maintenance windows when possible
7. **Monitor Continuously**: Use Uptime Kuma to monitor your own certificate expiration

---

## Support

For issues related to:
- **Certificate Issuance**: Contact your IT/Security team or AD CA administrator
- **Uptime Kuma**: See https://github.com/louislam/uptime-kuma
- **This Deployment**: See https://github.com/2plus2cabbage/uptime-kuma
