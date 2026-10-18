"""Minimal headless Blender build: two low-poly props -> GLB, with checks.

Run: blender -b --python-exit-code 1 --python build.py -- [--norender]
"""
import sys
from pathlib import Path

import bpy

OUT = Path(__file__).resolve().parent / "out"
BUDGET = {"crate": 24, "buoy": 120}  # triangle budget per prop
NORENDER = "--norender" in sys.argv


def fail(msg):
    print(f"build: FAIL {msg}", file=sys.stderr)
    sys.exit(1)  # exits 1; --python-exit-code 1 also covers uncaught exceptions


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1.0)
    return m


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def prop(name, op, mat, loc, **kw):
    op(location=loc, **kw)
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    o.data.materials.append(mat)
    return o


def build():
    red, wood = material("role_red", (0.8, 0.1, 0.1)), material("role_wood", (0.45, 0.28, 0.12))
    crate = prop("crate", bpy.ops.mesh.primitive_cube_add, wood, (0, 0, 0.5))  # 12 tris
    buoy = prop("buoy", bpy.ops.mesh.primitive_cone_add, red, (3, 0, 1), vertices=16, radius1=0.6, depth=2)
    for o in (crate, buoy):
        if tris(o) > BUDGET[o.name]:
            fail(f"{o.name} has {tris(o)} tris, budget {BUDGET[o.name]}")
    return [crate, buoy]


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True)


def reimport_check(path, names):
    reset()
    bpy.ops.import_scene.gltf(filepath=str(path))
    got = {o.name for o in bpy.data.objects if o.type == "MESH"}
    missing = set(names) - got
    if missing:
        fail(f"re-import is missing {sorted(missing)}")
    if not bpy.data.materials:
        fail("re-import lost the materials")


def preview(path):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 640, 400
    sc.render.filepath = str(path)
    bpy.ops.object.camera_add(location=(8, -8, 6), rotation=(1.1, 0, 0.785))
    sc.camera = bpy.context.active_object
    bpy.ops.object.light_add(type="SUN", location=(4, -4, 8), rotation=(0.8, 0.2, 0.6))
    bpy.ops.render.render(write_still=True)


def main():
    OUT.mkdir(exist_ok=True)
    reset()
    objs = build()
    glb = OUT / "props.glb"
    export(objs, glb)
    if not NORENDER:
        preview(OUT / "preview.png")  # look at this PNG, then critique and rebuild
    reimport_check(glb, [o.name for o in objs])
    print(f"build: ok {glb.name}")


main()
