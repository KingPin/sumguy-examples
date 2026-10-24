#!/usr/bin/env python3
"""Check NVMe wear from the SMART health log. Exit 0 OK, 1 WARN, 2 CRIT, 3 could not read."""
import argparse, json, subprocess, sys

CRIT_BITS = ["available spare below threshold", "temperature out of range",
             "reliability degraded", "media read-only", "volatile memory backup failed",
             "persistent memory region read-only"]


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(3)


def load(args):
    if args.json:
        try:
            with open(args.json) as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError) as e:
            die(f"cannot read {args.json}: {e}")
    try:
        # smartctl exit status is a bitmask; nonzero does not mean the JSON is bad
        out = subprocess.run(["smartctl", "-j", "-a", args.device], capture_output=True, text=True).stdout
    except FileNotFoundError:
        die("smartctl not found (install smartmontools)")
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        die(f"no JSON from smartctl for {args.device} (need root?)")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("device", nargs="?", default="/dev/nvme0")
    p.add_argument("--json", metavar="FILE", help="read saved `smartctl -j -a` output instead")
    p.add_argument("--warn-used", type=int, default=80, help="WARN at percentage_used >= N (80)")
    p.add_argument("--spare-margin", type=int, default=10, help="WARN when spare is within N points of threshold (10)")
    p.add_argument("--rated-tbw", type=float, help="vendor rated TBW, prints percent of it written")
    args = p.parse_args()

    log = load(args).get("nvme_smart_health_information_log")
    if log is None:
        die(f"{args.device}: no NVMe health log (not an NVMe device, or smartctl could not read it)")

    tb = log["data_units_written"] * 512000 / 1e12  # 1 unit = 1000 x 512 bytes
    used, spare, thr = log["percentage_used"], log["available_spare"], log["available_spare_threshold"]
    media, cw = log["media_errors"], log["critical_warning"]
    flags = [n for i, n in enumerate(CRIT_BITS) if cw >> i & 1]

    print(f"written:     {tb:.2f} TB")
    if args.rated_tbw:
        print(f"rated TBW:   {tb / args.rated_tbw * 100:.1f}% of {args.rated_tbw:g} TB written")
    print(f"used:        {used}% (controller estimate)")
    print(f"spare:       {spare}% (threshold {thr}%)")
    print(f"media errs:  {media}")
    print(f"crit warn:   {cw:#04x} {', '.join(flags) or 'none'}")

    if cw or spare < thr:
        print("CRIT: back up now"); return 2
    if used >= args.warn_used or spare - thr <= args.spare_margin or media > 0:
        print("WARN: plan a replacement"); return 1
    print("OK"); return 0


if __name__ == "__main__":
    sys.exit(main())
