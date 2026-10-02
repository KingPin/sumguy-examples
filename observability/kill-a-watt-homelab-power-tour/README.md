# Smart Plug Power Logger

A tiny logger that polls an energy-monitoring smart plug and writes `epoch,watts`
lines to a CSV, plus an awk script that turns that CSV into average watts and
kWh per day.

This is the working version of the code from
[Kill-A-Watt Tour of Every Box in the Rack](https://sumguy.com/kill-a-watt-homelab-power-tour/).

## What it does

- `poll_plug.py` calls a Shelly Gen2+ plug's `/rpc/Switch.GetStatus?id=0` endpoint
  every N seconds and appends the `apower` value (watts) with a Unix timestamp.
  Failed samples print to stderr and the loop keeps going.
- `avg_power.awk` integrates watts over the real time between samples, so a
  missed sample does not skew the average. Gaps longer than 300 seconds (logger
  down, plug offline) are skipped instead of being credited with the last reading.

## Prerequisites

- Python 3.8+ (standard library only)
- Any POSIX awk (tested with GNU awk 5.4)
- A Shelly Gen2 or newer plug reachable over HTTP on your LAN. For a Tasmota plug,
  change the URL to `/cm?cmnd=Status%2010` and read `["StatusSNS"]["ENERGY"]["Power"]`.

Calibrate the plug against a wall meter (Kill A Watt or similar) first. Cheap
metering chips read worst at low loads.

## How to run

```bash
# Sample every 5 seconds into nas.csv (Ctrl+C to stop, or run under systemd/tmux)
python3 poll_plug.py 192.168.1.50 5 nas.csv

# After 24 hours or more:
awk -F, -f avg_power.awk nas.csv
# avg 41.7 W over 24.0 h, 1.001 kWh/day   (example output format)
```

Use 10 to 30 second intervals for daily averages. Use 1 second for short runs
when you want to catch disk spin-up peaks.
