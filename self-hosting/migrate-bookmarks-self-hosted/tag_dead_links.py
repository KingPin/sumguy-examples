#!/usr/bin/env python3
"""Add dead-link (and has-wayback) tags in linkding from a linkcheck.py report. Deletes nothing."""
import csv, json, os, sys
import urllib.parse, urllib.request

BASE = os.environ["LINKDING_URL"].rstrip("/")
HEADERS = {"Authorization": "Token " + os.environ["LINKDING_TOKEN"],
           "Content-Type": "application/json"}


def call(path, method="GET", body=None):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(BASE + path, data, HEADERS, method=method)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


for row in csv.DictReader(open(sys.argv[1], newline="", encoding="utf-8")):
    if row["status_class"] != "gone":  # errors can be a bad day, not a dead site
        continue
    check = call("/api/bookmarks/check/?url=" + urllib.parse.quote(row["url"], safe=""))
    mark = check.get("bookmark")
    if not mark:
        continue
    tags = set(mark["tag_names"]) | {"dead-link"}
    if row["wayback_url"].startswith("http"):
        tags.add("has-wayback")
    call(f"/api/bookmarks/{mark['id']}/", "PATCH", {"tag_names": sorted(tags)})
    print("tagged", row["url"])
