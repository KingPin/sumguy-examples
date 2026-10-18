#!/usr/bin/env python3
"""Stdlib-only GLB check: triangles per mesh, fail over budget.

Usage: check_glb.py FILE.glb [--budget N]
"""
import json
import struct
import sys

# glTF primitive modes: 4 = TRIANGLES, 5 = STRIP, 6 = FAN
def tri_count(gltf, prim):
    n = gltf["accessors"][prim["indices"]]["count"] if "indices" in prim else \
        gltf["accessors"][prim["attributes"]["POSITION"]]["count"]
    mode = prim.get("mode", 4)
    return n // 3 if mode == 4 else max(n - 2, 0) if mode in (5, 6) else 0


def read_json(path):
    with open(path, "rb") as f:
        magic, version, _ = struct.unpack("<4sII", f.read(12))
        if magic != b"glTF" or version != 2:
            sys.exit(f"{path}: not a glTF 2 binary")
        length, kind = struct.unpack("<I4s", f.read(8))
        if kind != b"JSON":
            sys.exit(f"{path}: first chunk is not JSON")
        return json.loads(f.read(length))


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    budget = int(args[args.index("--budget") + 1]) if "--budget" in args else 500
    gltf = read_json(args[0])
    bad = 0
    for mesh in gltf.get("meshes", []):
        t = sum(tri_count(gltf, p) for p in mesh["primitives"])
        over = t > budget
        bad += over
        print(f"{'FAIL' if over else 'ok  '} {mesh.get('name', '?'):12} {t:5} tris (budget {budget})")
    sys.exit(1 if bad else 0)


main()
