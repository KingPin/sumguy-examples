# cloud-gaming-latency-beyond-ping

A jitter probe and the Sunshine config keys that affect stream latency. Companion to the post on why cloud gaming "feel" depends on variance and the whole input-to-display chain, not on ping alone.

Full writeup: [sumguy.com/cloud-gaming-latency-beyond-ping/](https://sumguy.com/cloud-gaming-latency-beyond-ping/)

## Files

- `jitter.sh`: wraps `ping` and prints sample count, loss, p50, p95, and max in ms. The p95 and max are the numbers that predict stutter; the average is what everyone already looks at.
- `sunshine.conf`: the five Sunshine keys the post discusses (`encoder`, `nvenc_preset`, `nvenc_latency_over_power`, `fec_percentage`, `minimum_fps_target`), each at its documented default.

## Prerequisites

- Linux with iputils `ping` (tested with iputils 20250605 on a 2026 kernel), `awk`, `grep`, `sort`. No root needed at the 0.2 s probe interval.
- Sunshine from LizardByte (tested against the v2026.914 docs) if you use `sunshine.conf`.

## Run it

```bash
./jitter.sh 192.168.1.1          # your router, 200 probes (about 40 s)
./jitter.sh 192.168.1.50 500     # your Sunshine host, 500 probes
```

Example output:

```text
samples=200 loss=0.0% p50=0.8 ms p95=1.4 ms max=3.1 ms
```

Run it twice: once with the network idle, once while another device uploads or downloads at full speed. A p95 that jumps by tens of milliseconds under load is bufferbloat on the router, and the fix is SQM (cake on OpenWrt), not a codec setting.

## Sunshine

Sunshine reads `sunshine.conf` from its config directory (`~/.config/sunshine/` on Linux). The keys in this file are documented at https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2configuration.html. Leave `nvenc_preset` at `1` unless the Moonlight overlay shows host processing latency with headroom to spare.
