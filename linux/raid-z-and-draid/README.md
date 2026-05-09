# ZFS RAID-Z and dRAID Examples

Working shell scripts for the article: **[RAID-Z and dRAID: ZFS Parity Explained](https://sumguy.com/posts/raid-z-and-draid-explained/)**

These scripts use loop devices only — no real disks are touched. Safe to run on any Linux box with ZFS installed.

---

## What's in Here

| File | What it does |
|---|---|
| `create-raidz2.sh` | Creates a 6-drive RAID-Z2 pool using loop devices |
| `create-draid.sh` | Creates an 11-drive dRAID2:8d:1s pool using loop devices |
| `expand-raidz.sh` | Demonstrates adding a drive to an existing RAID-Z vdev (OpenZFS 2.3+) |
| `vdev-layouts.md` | Reference: capacity math for common vdev layouts |

---

## Prerequisites

- Linux (tested on Ubuntu 24.04)
- OpenZFS **2.1+** for dRAID support (`create-draid.sh`)
- OpenZFS **2.3+** for RAID-Z expansion (`expand-raidz.sh`)
- 8+ loop devices available (default Linux kernel provides 255)
- `sudo` access (ZFS pool operations require root)

Check your OpenZFS version:

```bash
zfs --version
```

Install OpenZFS on Ubuntu 24.04:

```bash
sudo apt install -y zfsutils-linux
```

---

## How to Run

Clone the repo and run any script directly:

```bash
git clone https://github.com/KingPin/sumguy-examples.git
cd sumguy-examples/linux/raid-z-and-draid

# Create a RAID-Z2 test pool
sudo bash create-raidz2.sh

# Create a dRAID test pool
sudo bash create-draid.sh

# Test RAID-Z expansion (needs OpenZFS 2.3+)
sudo bash expand-raidz.sh
```

All scripts clean up after themselves (destroy the pool and remove loop devices) unless you interrupt them. If a script exits early, clean up manually:

```bash
sudo zpool destroy testpool 2>/dev/null || true
sudo losetup -D
rm -f /tmp/zfs-test-*.img
```

---

## Tested On

- Ubuntu 24.04 LTS
- OpenZFS 2.3.0 (for expansion script)
- OpenZFS 2.1.x (for dRAID script — works on 2.1+)

---

## Back to the Article

Full explanation of RAID-Z vs dRAID, when each is appropriate, and what dRAID actually changes about resilver speed:
**https://sumguy.com/posts/raid-z-and-draid-explained/**
