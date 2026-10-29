# Writes each kart in KartMeshData as an .fbx for Studio's 3D Importer (File > Import 3D), one
# object per part, named as CarSkin expects (Body, WheelFL.., RimFL.., Cap, Head...). Backup for
# when the Studio bake (studio_bake.luau) can't upload: carter imports the files into
# ReplicatedStorage.CarSkins by hand, and CarSkin paints the parts by name.
# Run: lune decode first (see IMPORT-STEPS.md), then
#   J=<karts.json> OUT=<folder> <blender python> -I export_fbx.py
# With ALL=1 it writes them all into one Karts.fbx instead (one import for carter): each part is
# named "<kart>__<part>" (Kart_Buggy__Body) and the karts stand in a row 12 studs apart;
# studio_import_fix.luau sorts the parts back into one model per kart.
import json
import os

import bpy

# a starting colour per part (CarSkin repaints each one by its name for the car anyway)
COLORS = {
    "Body": (0.85, 0.15, 0.15),
    "Cap": (0.85, 0.15, 0.15),
    "Driver": (0.85, 0.15, 0.15),
    "Head": (0.96, 0.8, 0.19),
    "Eyes": (0.1, 0.1, 0.18),
    "Trim": (0.1, 0.1, 0.18),
    "Seat": (0.1, 0.1, 0.18),
    "Dark": (0.27, 0.29, 0.33),
    "Metal": (0.8, 0.82, 0.86),
    "Shade": (0.45, 0.08, 0.08),
    "Accent": (1.0, 0.82, 0.25),
    "Headlights": (1.0, 0.95, 0.8),
    "Glow": (1.0, 0.95, 0.8),
    "Taillights": (1.0, 0.25, 0.25),
}

data = json.load(open(os.environ["J"]))
out = os.environ["OUT"]
one = os.environ.get("ALL") == "1"
os.makedirs(out, exist_ok=True)


def add(name, mesh, label, dx):
    v = mesh["v"]
    # Roblox (x, y, z) -> Blender (x, -z, y): the FBX exporter's Y-up turns it straight back
    verts = [(v[i] + dx, -v[i + 2], v[i + 1]) for i in range(0, len(v), 3)]
    t = mesh["t"]
    faces = [(t[i] - 1, t[i + 1] - 1, t[i + 2] - 1) for i in range(0, len(t), 3)]
    me = bpy.data.meshes.new(label)
    me.from_pydata(verts, [], faces)
    me.validate()
    mat = bpy.data.materials.new(label)
    if name.startswith("Wheel"):
        col = (0.11, 0.11, 0.12)
    elif name.startswith("Rim"):
        col = (1.0, 1.0, 1.0)
    else:
        col = COLORS.get(name, (0.8, 0.8, 0.8))
    mat.diffuse_color = (*col, 1.0)
    me.materials.append(mat)
    ob = bpy.data.objects.new(label, me)
    bpy.context.scene.collection.objects.link(ob)


def export(path):
    bpy.ops.export_scene.fbx(
        filepath=path,
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        mesh_smooth_type="FACE",
        bake_space_transform=True,
    )


if one:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for i, (kart, parts) in enumerate(sorted(data.items())):
        for name, mesh in sorted(parts.items()):
            add(name, mesh, kart + "__" + name, i * 12)
    export(os.path.join(out, "Karts.fbx"))
    print("wrote Karts.fbx", len(data), "karts")
else:
    for kart, parts in sorted(data.items()):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        for name, mesh in sorted(parts.items()):
            add(name, mesh, name, 0)
        export(os.path.join(out, kart + ".fbx"))
        print("wrote", kart, len(parts), "parts")
