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
    - credentials.py file in the same directory
Usage:
    1. Activate virtual environment:
       source kuma-venv/bin/activate
    2. Run:
       python import_monitors.py
Notes:
    - Duplicate detection is by URL.
    - Only HTTPS URLs are processed.
    - credentials.py should contain USERNAME and PASSWORD variables
"""

import csv
import sys
import time
from uptime_kuma_api import UptimeKumaApi

# ===== Configuration =====
KUMA_URL = "http://127.0.0.1:3001"  # URL to your Uptime Kuma instance

# Load credentials from config file
try:
    exec(open('credentials.py').read())
except FileNotFoundError:
    print("ERROR: credentials.py file not found")
    print("Create this file with USERNAME and PASSWORD variables")
    sys.exit(1)

CSV_FILE = "monitors.csv"           # CSV file containing monitors

# ===== Connect to Uptime Kuma =====
print(f"Connecting to Uptime Kuma at {KUMA_URL}...")

try:
    api = UptimeKumaApi(KUMA_URL)
except Exception as e:
    print(f"ERROR: Failed to initialize connection: {e}")
    print("\nTroubleshooting:")
    print("1. Check if Uptime Kuma is running: docker ps | grep uptime-kuma")
    print("2. Check if port 3001 is accessible: curl http://127.0.0.1:3001")
    print("3. Verify Uptime Kuma container logs: docker logs uptime-kuma")
    sys.exit(1)

# Login with timeout handling
print("Logging in...")
try:
    api.login(USERNAME, PASSWORD)
    print("Successfully logged in!")
except Exception as e:
    print(f"ERROR: Login failed: {e}")
    print("\nTroubleshooting:")
    print("1. Verify credentials are correct")
    print("2. Check if Uptime Kuma web interface is accessible at https://your-domain.com")
    print("3. Try logging in manually through the web interface")
    print("4. Check Uptime Kuma logs: docker logs uptime-kuma")
    sys.exit(1)

# ===== Fetch existing monitors to handle duplicates =====
print("Fetching existing monitors...")
try:
    existing_monitors = api.get_monitors()
    existing_urls = {m["url"] for m in existing_monitors}
    print(f"Found {len(existing_monitors)} existing monitors")
except Exception as e:
    print(f"ERROR: Failed to fetch monitors: {e}")
    api.disconnect()
    sys.exit(1)

# ===== Read CSV and create monitors =====
try:
    with open(CSV_FILE, 'r') as f:
        pass
except FileNotFoundError:
    print(f"ERROR: CSV file '{CSV_FILE}' not found")
    api.disconnect()
    sys.exit(1)

print(f"\nProcessing {CSV_FILE}...")
added_count = 0
skipped_count = 0
error_count = 0

try:
    with open(CSV_FILE, newline="", encoding="utf-8") as csvfile:
        reader = csv.DictReader(csvfile)

        for row in reader:
            name = row["name"].strip()
            url = row["url"].strip()

            # Only process HTTPS URLs for certificate expiry monitoring
            if not url.lower().startswith("https://"):
                print(f"⊘ Skipping {name}: URL is not HTTPS")
                skipped_count += 1
                continue

            # Skip duplicates
            if url in existing_urls:
                print(f"⊘ Skipping {name}: URL already exists")
                skipped_count += 1
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

                print(f"✓ Added monitor: {name}")
                added_count += 1

                # Add URL to set to prevent future duplicates in same run
                existing_urls.add(url)

                # Brief pause to avoid overwhelming the API
                time.sleep(0.5)

            except Exception as e:
                print(f"✗ Failed to add {name}: {e}")
                error_count += 1

except Exception as e:
    print(f"ERROR: Failed to process CSV: {e}")
    api.disconnect()
    sys.exit(1)

# ===== Disconnect =====
api.disconnect()

# ===== Summary =====
print("\n" + "="*50)
print("Import Summary:")
print(f"  ✓ Added:   {added_count} monitors")
print(f"  ⊘ Skipped: {skipped_count} monitors")
print(f"  ✗ Errors:  {error_count} monitors")
print("="*50)
print("Import complete.")
