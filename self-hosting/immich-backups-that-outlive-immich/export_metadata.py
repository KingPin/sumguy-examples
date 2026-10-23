#!/usr/bin/env python3
"""Export Immich album and named-person membership as plain folders of symlinks.

Albums and face names live only in Postgres. This script asks the Immich API
which files belong to each album and each named person, then builds
<out>/albums/<name>/ and <out>/people/<name>/ with relative symlinks to the
library files, plus albums.json and people.json manifests.

Put <out> inside the Immich upload location (default /srv/immich/export) so the
relative links resolve inside the backup.
"""
import argparse
import json
import os
import re
import shutil
import urllib.request

URL = os.environ.get("IMMICH_URL", "http://localhost:2283").rstrip("/")
KEY = os.environ["IMMICH_API_KEY"]


def api(method, path, body=None):
    req = urllib.request.Request(
        f"{URL}/api{path}",
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"x-api-key": KEY, "Accept": "application/json", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def asset_paths(filter_):
    """Yield originalPath for every asset matching a v3 search filter."""
    cursor = None
    while True:
        body = {"filter": filter_, "size": 1000}
        if cursor:
            body["cursor"] = cursor
        page = api("POST", "/search/metadata", body)["assets"]
        for item in page["items"]:
            yield item["originalPath"]
        cursor = page.get("nextCursor")
        if not cursor:
            return


def people():
    page = 1
    while True:
        res = api("GET", f"/people?page={page}&size=1000")
        yield from (p for p in res["people"] if p["name"])
        if not res["hasNextPage"]:
            return
        page += 1


def safe(name):
    name = re.sub(r"[^\w .()-]", "_", name).strip()
    return name if name.strip(".") else "unnamed"  # never ".", "..", or empty


def link_tree(root, folder_name, paths, prefix_from, prefix_to):
    folder = os.path.join(root, folder_name)
    os.makedirs(folder, exist_ok=True)
    for p in paths:
        target = prefix_to + p[len(prefix_from):] if p.startswith(prefix_from) else p
        link = os.path.join(folder, os.path.basename(p))
        n = 1
        while os.path.lexists(link):  # same filename from another day: add a counter
            stem, ext = os.path.splitext(os.path.basename(p))
            link = os.path.join(folder, f"{stem}_{n}{ext}")
            n += 1
        os.symlink(os.path.relpath(target, folder), link)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default="/srv/immich/export")
    ap.add_argument("--prefix-from", default="/data", help="media path inside the container")
    ap.add_argument("--prefix-to", default=os.environ.get("UPLOAD_LOCATION", "/srv/immich"),
                    help="same path on the host (default: $UPLOAD_LOCATION or /srv/immich)")
    a = ap.parse_args()

    jobs = {"albums": [], "people": []}
    for album in api("GET", "/albums"):
        jobs["albums"].append((album["albumName"], album["id"], {"albumIds": {"any": [album["id"]]}}))
    for person in people():
        jobs["people"].append((person["name"], person["id"], {"personIds": {"any": [person["id"]]}}))

    for kind, items in jobs.items():
        root = os.path.join(a.out, kind)
        shutil.rmtree(root, ignore_errors=True)  # links are rebuilt on every run
        manifest, used = {}, set()
        for name, id_, flt in items:
            folder = safe(name)
            if folder.lower() in used:  # two names that sanitize to the same folder
                folder = f"{folder} ({id_[:8]})"
            used.add(folder.lower())
            paths = list(asset_paths(flt))
            manifest[name if name not in manifest else f"{name} ({id_[:8]})"] = paths
            link_tree(root, folder, paths, a.prefix_from, a.prefix_to)
            print(f"{kind}: {name}: {len(paths)} files")
        with open(os.path.join(a.out, f"{kind}.json"), "w") as f:
            json.dump(manifest, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main()
