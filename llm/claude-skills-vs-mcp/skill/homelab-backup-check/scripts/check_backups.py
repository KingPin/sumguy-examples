#!/usr/bin/env python3
"""Report how old the newest file in a backup directory is.

Usage: check_backups.py DIR [--max-age-hours N]
Exit 0 = fresh, 1 = stale, 2 = bad input.
"""
import argparse
import sys
import time
from pathlib import Path


def newest_age_hours(root: Path):
    """Return (age_in_hours, newest_path) or None if the tree has no files."""
    newest = None
    for p in root.rglob("*"):
        if p.is_file():
            m = p.stat().st_mtime
            if newest is None or m > newest[0]:
                newest = (m, p)
    if newest is None:
        return None
    return (time.time() - newest[0]) / 3600, newest[1]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("directory")
    ap.add_argument("--max-age-hours", type=float, default=26.0)
    a = ap.parse_args()
    root = Path(a.directory)
    if not root.is_dir():
        print(f"ERROR: {root} is not a directory")
        return 2
    res = newest_age_hours(root)
    if res is None:
        print(f"STALE: {root} contains no files")
        return 1
    age, path = res
    state = "FRESH" if age <= a.max_age_hours else "STALE"
    print(f"{state}: newest file {path.name} is {age:.1f}h old (limit {a.max_age_hours:g}h)")
    return 0 if state == "FRESH" else 1


if __name__ == "__main__":
    sys.exit(main())
