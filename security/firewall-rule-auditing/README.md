# Firewall Rule Audit: Find the Dead Rules

Working files for auditing an existing nftables ruleset with counters: a daily
JSON snapshot of the ruleset, and a diff script that flags rules whose packet
count did not move between two snapshots.

Article: https://sumguy.com/firewall-rule-auditing/

## What's here

```
snapshot-fw.sh        # dumps `nft -j list ruleset` to /var/lib/fw-snapshots/YYYY-MM-DD.json
snapshot-fw.service   # oneshot unit that runs the script
snapshot-fw.timer     # fires the service daily, catches up after downtime
fw-diff.sh            # compares two snapshots, prints family/table/handle, comment, packets then/now, delta
sample-snapshots/     # two hand-built snapshots in the nft JSON shape, for a dry run
```

## Prerequisites

- nftables with JSON output (`nft -j`). Tested with nftables 1.1.7.
- `jq`, `awk`, and `column` (util-linux) for `fw-diff.sh`.
- Root for the snapshot (reading the ruleset needs it). The diff runs as any user.
- Rules you want to audit must carry an anonymous `counter` statement. Rules
  with a named counter (`counter name foo`) are skipped by the diff script.

## How to run it

1. Dry run against the samples, no root needed:

   ```bash
   ./fw-diff.sh sample-snapshots/2026-09-18.json sample-snapshots/2026-10-18.json
   ```

   Rules with a delta of 0 are marked `CANDIDATE`.
2. Install the snapshot on a real box:

   ```bash
   sudo install -m 0755 snapshot-fw.sh /usr/local/bin/snapshot-fw.sh
   sudo install -m 0644 snapshot-fw.service snapshot-fw.timer /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now snapshot-fw.timer
   ```

3. After 30 days, diff the oldest and newest snapshot:

   ```bash
   sudo ./fw-diff.sh /var/lib/fw-snapshots/<old>.json /var/lib/fw-snapshots/<new>.json
   ```

A counter reset or a ruleset reload between two snapshots makes the delta go
negative. Pick two snapshots from the same uninterrupted stretch.
