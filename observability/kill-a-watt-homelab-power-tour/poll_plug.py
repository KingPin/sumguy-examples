#!/usr/bin/env python3
"""Poll a Shelly Gen2+ plug and append 'epoch,watts' lines to a CSV."""
import json
import sys
import time
import urllib.request

host = sys.argv[1]            # e.g. 192.168.1.50
interval = float(sys.argv[2])  # seconds between samples
out = sys.argv[3]              # e.g. nas.csv

url = f"http://{host}/rpc/Switch.GetStatus?id=0"

with open(out, "a", buffering=1) as f:
    while True:
        try:
            with urllib.request.urlopen(url, timeout=5) as r:
                watts = json.load(r)["apower"]
            f.write(f"{int(time.time())},{watts}\n")
        except Exception as e:
            print(f"sample failed: {e}", file=sys.stderr)
        time.sleep(interval)
