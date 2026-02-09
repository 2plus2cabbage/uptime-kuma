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
from uptime_kuma_api import UptimeKumaApi

# ===== Configuration =====
KUMA_URL = "http://127.0.0.1:3001"  # URL to your Uptime Kuma instance

# Load credentials from config file
exec(open('credentials.py').read())

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
