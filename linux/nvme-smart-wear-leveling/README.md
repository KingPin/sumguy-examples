# NVMe wear check

A small script that reads the NVMe SMART health log through `smartctl -j` and tells you whether the drive needs attention.
It is the companion to [NVMe SMART: Reading Wear Before It Dies](https://sumguy.com/nvme-smart-wear-leveling/).

It prints TB written, Percentage Used, Available Spare against its threshold, media errors, and the decoded
Critical Warning bits. Then it exits with a status you can alert on.

## Prerequisites

- Python 3 (stdlib only)
- smartmontools with JSON output (`smartctl -j`)
- Root for real devices. Reading SMART data needs raw device access.

Tested with: smartmontools 7.5, nvme-cli 2.16 (used to cross-check the numbers, the script itself does not call it), Python 3.14.

## Run it

```bash
sudo ./nvme-wear-check.py /dev/nvme0
./nvme-wear-check.py --json sample-smartctl.json     # test mode, no root, no drive
./nvme-wear-check.py --rated-tbw 600 /dev/nvme0      # also print percent of rated TBW written
```

`sample-smartctl.json` is real `smartctl -j -a` output from a healthy 1 TB OEM drive (serial number, namespace identifiers, and the smartctl version block removed).

## Exit codes

| Code | Meaning | Trigger (defaults) |
|---|---|---|
| 0 | OK | nothing below fired |
| 1 | WARN | `percentage_used` >= 80, spare within 10 points of threshold, or `media_errors` > 0 |
| 2 | CRIT | any Critical Warning bit set, or spare below threshold |
| 3 | Could not read | `smartctl` missing, no JSON, or not an NVMe device |

Tune with `--warn-used N` and `--spare-margin N`.

smartctl returns a bitmask exit status, so a nonzero code does not mean the JSON is bad.
The script parses the JSON whatever the exit status was.

## Run it daily

Install the script where cron can find it:

```bash
sudo install -m 755 nvme-wear-check.py /usr/local/bin/
```

```text
# /etc/cron.d/nvme-wear
17 6 * * * root /usr/local/bin/nvme-wear-check.py /dev/nvme0 >/dev/null || logger -t nvme-wear "exit $?"
```

Or wrap it in a systemd timer and let `OnFailure=` send the alert.

More in the post: https://sumguy.com/nvme-smart-wear-leveling/
