# RAID 50 / RAID 60 — Nested Parity Examples

Working scripts for the article: [RAID 50/60: Nested Parity Done Right](https://sumguy.com/posts/raid-50-vs-60-nested/)

All scripts use **loop devices backed by sparse files** — no real disks are touched. Safe to run on any Linux box for learning and testing.

## What's in Here

| File | Description |
|---|---|
| `create-raid-50.sh` | Builds two RAID 5 sub-arrays (3 drives each) striped with RAID 0 |
| `create-raid-60.sh` | Builds two RAID 6 sub-arrays (4 drives each) striped with RAID 0 |
| `mdadm.conf.example` | Example mdadm.conf showing how to persist a nested array |
| `monitor.sh` | Print mdstat + per-array detail, warn if any array is degraded |

## Prerequisites

- Linux (tested on Ubuntu 24.04 and Debian 12)
- `mdadm` installed: `sudo apt install mdadm`
- Root or sudo access (mdadm and losetup require it)
- ~6 GB free disk space for RAID 50 script; ~8 GB for RAID 60 script (sparse files, actual usage minimal)

```bash
sudo apt install mdadm
```

## Running the Scripts

Clone or download the examples:

```bash
git clone https://github.com/KingPin/sumguy-examples.git
cd sumguy-examples/linux/raid-50-vs-60-nested/
```

Build a RAID 50 test array:

```bash
sudo bash create-raid-50.sh
```

Build a RAID 60 test array (requires cleanup or separate run — uses different device names):

```bash
sudo bash create-raid-60.sh
```

Monitor array health:

```bash
sudo bash monitor.sh
```

Each script tears itself down at the end and prompts before doing so. You can also run just the setup portion by commenting out the cleanup block.

## Cleaning Up Manually

If a script fails mid-way and leaves loop devices or arrays around:

```bash
# Stop arrays
sudo mdadm --stop /dev/md10 /dev/md1 /dev/md0

# Remove loop devices
sudo losetup -D

# Remove sparse files
rm -f /tmp/raid-test-*.img
```

## Tested On

- Ubuntu 24.04 LTS
- Debian 12 (Bookworm)
- mdadm 4.2+

## More Reading

- Full article: https://sumguy.com/posts/raid-50-vs-60-nested/
- RAID 0/1/5 basics: https://sumguy.com/posts/raid-0-1-5-explained/
- RAID 6 vs RAID 10: https://sumguy.com/posts/raid-6-vs-raid-10/
- Rebuild math and monitoring: https://sumguy.com/posts/raid-reliability-and-recovery/
