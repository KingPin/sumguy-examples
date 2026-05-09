# hardware-vs-software-raid

Working examples for the SumGuy's Ramblings article: **Hardware RAID vs Software RAID in 2026**

Article: https://sumguy.com/posts/hardware-vs-software-raid/

---

## What's Here

| File | What it is |
|---|---|
| `cpu-overhead-test.sh` | Bash script: creates loop-device RAID 6, runs fio, measures CPU during scrub |
| `flash-lsi-it-mode.md` | Procedure document for flashing LSI 9211/9300 to IT mode HBA firmware |

---

## Why There's No Flash Script

Flashing firmware is a destructive, hardware-specific operation. Running the wrong firmware image, flashing to the wrong card revision, or losing power mid-flash can result in a card that won't POST. The procedure is documented step-by-step in `flash-lsi-it-mode.md` — read it fully before touching anything. A one-liner script is the wrong tool for this job.

---

## Running the CPU Overhead Test

**Requirements:**
- Linux kernel 4.x or later
- `mdadm` installed
- `fio` installed (`apt install fio` / `dnf install fio`)
- `sysstat` installed for `mpstat` (`apt install sysstat` / `dnf install sysstat`)
- Root or sudo access
- ~2 GB free disk space for loop device backing files

**Run it:**

```bash
sudo bash cpu-overhead-test.sh
```

The script:
1. Creates 8 sparse loop device backing files (256 MB each)
2. Attaches loop devices
3. Assembles a RAID 6 array from them (`/dev/md99`)
4. Runs `fio` sequential and random 4K workloads against the array
5. Triggers a scrub and captures `mpstat` CPU usage during the scrub
6. Prints a summary
7. Tears everything down cleanly, even on failure

The point: see how little CPU software RAID 6 parity actually uses on a modern system.

**This script explicitly refuses to run against real disks.** It detects and exits if the loop devices can't be created, and never touches `/dev/sd*` or `/dev/nvme*`.

---

## Tested On

- Ubuntu 24.04 LTS (kernel 6.8)
- Debian 12 (kernel 6.1)
- Fedora 40 (kernel 6.8)

---

## See Also

- [RAID 0/1/5 Explained](https://sumguy.com/posts/raid-0-1-5-explained/)
- [RAID 6 vs RAID 10](https://sumguy.com/posts/raid-6-vs-raid-10/)
- [ZFS RAID-Z and dRAID](https://sumguy.com/posts/raid-z-and-draid-explained/)
- [SMART Monitoring with smartmontools](https://sumguy.com/posts/smart-monitoring-smartmontools/)
- [fio Disk Benchmarking](https://sumguy.com/posts/fio-disk-benchmarking/)
