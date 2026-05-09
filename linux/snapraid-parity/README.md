# SnapRAID + MergerFS Example

Working config files and a nightly sync script for a SnapRAID parity setup with MergerFS pooling.

**Article:** https://sumguy.com/posts/snapraid-parity-without-realtime/

---

## What's Here

| File | Purpose |
|---|---|
| `snapraid.conf.example` | Full SnapRAID config — 4 data drives + 1 parity drive |
| `mergerfs-fstab.example` | fstab entry to union data drives into `/mnt/storage` |
| `sync-cron.sh` | Nightly cron script with diff sanity-check and optional weekly scrub |

---

## Prerequisites

- Linux (Debian/Ubuntu recommended)
- `snapraid` installed: `sudo apt install snapraid`
- `mergerfs` installed: `sudo apt install mergerfs`
- At least 2 data drives (any sizes, formatted with ext4 or XFS)
- 1 dedicated parity drive, size >= your largest data drive
- Drives mounted at `/mnt/data1`, `/mnt/data2`, etc. and parity at `/mnt/parity`

**Tested with:** SnapRAID 11.x, MergerFS 2.40.x, Debian 12 / Ubuntu 24.04

---

## Setup Steps

### 1. Mount your drives

Add your drives to `/etc/fstab` using UUIDs (use `blkid` to find them):

```bash
# Get UUIDs
sudo blkid /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf
```

Create mountpoints:

```bash
sudo mkdir -p /mnt/data{1,2,3,4} /mnt/parity /mnt/storage
```

### 2. Install the SnapRAID config

```bash
sudo cp snapraid.conf.example /etc/snapraid.conf
# Edit paths and drive labels to match your setup
sudo nano /etc/snapraid.conf
```

### 3. Add MergerFS to fstab

```bash
# Append the mergerfs-fstab.example line to /etc/fstab
# Edit drive paths to match yours first
cat mergerfs-fstab.example
sudo nano /etc/fstab
sudo mount /mnt/storage
```

### 4. Initial sync

The first sync computes parity for your entire library — expect it to take several hours for large collections:

```bash
sudo snapraid sync
```

### 5. Install the cron script

```bash
sudo cp sync-cron.sh /usr/local/bin/snapraid-sync.sh
sudo chmod +x /usr/local/bin/snapraid-sync.sh

# Add to root crontab (runs nightly at 2 AM)
sudo crontab -e
# Add: 0 2 * * * /usr/local/bin/snapraid-sync.sh
```

---

## Verifying the Setup

```bash
# Check array status
sudo snapraid status

# Validate data integrity (5% sample)
sudo snapraid scrub -p 5

# Test recovery simulation (dry run)
sudo snapraid fix --dry-run
```

---

## Recovering from a Drive Failure

1. Replace the dead drive with a new one (same or larger size is fine)
2. Mount it at the same mountpoint
3. Run fix:

```bash
sudo snapraid fix -d dX  # where dX is the label of the failed drive
```

4. Verify:

```bash
sudo snapraid check -d dX
```

---

## Notes

- The parity drive does **not** add to your usable pool — it's overhead only
- Files written after the last `snapraid sync` are not protected until the next sync
- Each data drive is independently readable without SnapRAID or MergerFS installed
- Add a second `parity2` line in the config to survive two simultaneous failures
