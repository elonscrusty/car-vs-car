# Builds 6 low-poly mesh karts (nose +Y, up +Z, metres = toy units), exports FBX + GLB per kart.
import bpy, bmesh, math, os, sys
from mathutils import Vector

OUT = os.environ.get("OUT", os.path.dirname(os.path.abspath(__file__)))
os.makedirs(OUT, exist_ok=True)

COL = {
    "Body": (0.85, 0.2, 0.18, 1), "Accent": (1, 0.78, 0.17, 1), "Trim": (0.11, 0.11, 0.18, 1),
    "Head": (0.96, 0.8, 0.19, 1), "Shirt": (0.24, 0.6, 1, 1), "Pants": (0.11, 0.11, 0.18, 1),
    "Headlights": (1, 0.98, 0.9, 1), "Taillights": (1, 0.2, 0.24, 1), "Tire": (0.11, 0.11, 0.12, 1),
    "WeaponMount": (0.11, 0.11, 0.18, 1),
}

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = COL[name]
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = COL[name]
    return m

def obj_from_bm(bm, group):
    me = bpy.data.meshes.new(group)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(group, me)
    bpy.context.scene.collection.objects.link(o)
    o["group"] = group
    return o

def box(group, size, loc, taper_front=None, bevel=0.06, segs=1, top_front_drop=0.0, top_back_drop=0.0, front_narrow=0.0):
    """Box: size (x,y,z), loc centre. Front = +Y. top_front_drop lowers the top-front edge (slope),
    front_narrow pulls the front face's x in (rounded/tapered nose)."""
    bm = bmesh.new()
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    vs = {}
    for ix in (-1, 1):
        for iy in (-1, 1):
            for iz in (-1, 1):
                x, y, z = ix * sx, iy * sy, iz * sz
                if iy == 1:
                    x *= (1 - front_narrow)
                    if iz == 1:
                        z -= top_front_drop
                if iy == -1 and iz == 1:
                    z -= top_back_drop
                vs[(ix, iy, iz)] = bm.verts.new((x + loc[0], y + loc[1], z + loc[2]))
    F = lambda *k: bm.faces.new([vs[i] for i in k])
    F((-1,-1,-1),(-1,1,-1),(1,1,-1),(1,-1,-1))
    F((-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1))
    F((-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1))
    F((-1,1,-1),(-1,1,1),(1,1,1),(1,1,-1))
    F((-1,-1,-1),(-1,-1,1),(-1,1,1),(-1,1,-1))
    F((1,-1,-1),(1,1,-1),(1,1,1),(1,-1,1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect='EDGES', profile=0.5)
    return obj_from_bm(bm, group)

def cyl(group, radius, depth, loc, axis="X", sides=12, bevel=0.03):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=depth)
    rot = {"X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0), "Z": (0, 0, 0)}[axis]
    from mathutils import Euler
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(loc))
    if bevel > 0:
        rims = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.2]
        bmesh.ops.bevel(bm, geom=rims, offset=bevel, segments=1, affect='EDGES')
    return obj_from_bm(bm, group)

def wheel(name, x, y, r, w):
    # one colour in game, so the rim is shape: each side face is inset into a sunken hub with a cap
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=r, radius2=r, depth=w)
    from mathutils import Euler
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler((0, math.pi / 2, 0)).to_matrix())
    caps = [f for f in bm.faces if abs(f.normal.x) > 0.9]
    rims = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.2]
    bmesh.ops.bevel(bm, geom=rims, offset=0.06, segments=1, affect='EDGES')
    caps = [f for f in bm.faces if abs(f.normal.x) > 0.9 and f.calc_area() > 0.3]
    for f in caps:
        r1 = bmesh.ops.inset_region(bm, faces=[f], thickness=0.13, depth=-0.08)
        r2 = bmesh.ops.inset_region(bm, faces=[f], thickness=0.16, depth=0.05)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((x, y, r)))
    return obj_from_bm(bm, name)

def driver(z0, y0, shirt="Accent"):
    # classic blocky R6 kid: torso, two arms reaching forward, a rounded block head
    box("Driver", (0.62, 0.36, 0.6), (0, y0, z0 + 0.3), bevel=0.04)
    for sx in (-1, 1):
        box("Driver", (0.22, 0.6, 0.22), (sx * 0.42, y0 + 0.22, z0 + 0.42), bevel=0.03)
    box("Head", (0.42, 0.42, 0.42), (0, y0, z0 + 0.86), bevel=0.1, segs=2)
    box("Trim", (0.06, 0.06, 0.32), (0, y0 + 0.55, z0 + 0.45), bevel=0)  # steering column
    cyl("Trim", 0.17, 0.05, (0, y0 + 0.5, z0 + 0.58), "Y", sides=10, bevel=0)

def lights(front_y, back_y, z, w):
    for sx in (-1, 1):
        box("Headlights", (0.32, 0.05, 0.14), (sx * w, front_y, z), bevel=0.02)
        box("Taillights", (0.3, 0.05, 0.12), (sx * w, back_y, z), bevel=0.02)

WR, WW, WX, WY = 0.52, 0.55, 1.28, 1.25  # wheel radius, width, x, y (front +Y)

def pods(z=0.42, h=0.36, x=0.78, ln=1.35, group="Body"):
    for sx in (-1, 1):
        box(group, (0.5, ln, h), (sx * x, -0.05, z), bevel=0.1, segs=2, front_narrow=0.0, top_front_drop=0.1, top_back_drop=0.05)

def wheels():
    for nm, x, y in (("WheelFL", -WX, WY), ("WheelFR", WX, WY), ("WheelRL", -WX, -WY), ("WheelRR", WX, -WY)):
        wheel(nm, x, y, WR, WW)

# ---------------- the six karts ----------------
def kart_racer():  # open-wheel racer: long pointed nose, side pods, big rear wing
    box("Body", (1.0, 3.0, 0.42), (0, 0.15, 0.5), bevel=0.08, front_narrow=0.55, top_front_drop=0.18)
    box("Body", (0.5, 1.3, 0.38), (0, 1.15, 0.62), bevel=0.06, front_narrow=0.5, top_front_drop=0.2)  # cowl
    for sx in (-1, 1):
        box("Body", (0.42, 1.3, 0.36), (sx * 0.68, -0.25, 0.48), bevel=0.08, front_narrow=0.3, top_front_drop=0.15)  # pods
    box("Accent", (2.0, 0.4, 0.06), (0, 1.75, 0.22), bevel=0.02)  # front wing
    box("Trim", (0.06, 0.3, 0.2), (-0.98, 1.75, 0.3), bevel=0.01)
    box("Trim", (0.06, 0.3, 0.2), (0.98, 1.75, 0.3), bevel=0.01)
    box("Accent", (1.9, 0.42, 0.08), (0, -1.62, 1.22), bevel=0.02)  # rear wing
    for sx in (-1, 1):
        box("Trim", (0.06, 0.45, 0.5), (sx * 0.93, -1.62, 1.05), bevel=0.01)
    box("Trim", (0.9, 0.5, 0.35), (0, -0.25, 0.75), bevel=0.05)  # seat
    box("Trim", (1.1, 0.25, 0.25), (0, -1.75, 0.45), bevel=0.06)  # rear bumper
    box("WeaponMount", (0.42, 0.42, 0.12), (0, -0.85, 0.78), bevel=0.02)
    driver(0.86, -0.25)
    lights(1.93, -1.88, 0.45, 0.25)

def kart_buggy():  # dune buggy: chunky tub, roll hoop, big bumper, engine out back
    pods(0.42, 0.34, 0.8)
    box("Body", (1.8, 3.1, 0.62), (0, 0.05, 0.54), bevel=0.1, front_narrow=0.15, top_front_drop=0.2)
    box("Body", (1.5, 0.8, 0.35), (0, 1.15, 0.95), bevel=0.08, front_narrow=0.25, top_front_drop=0.22)  # hood
    for sx in (-1, 1):
        box("Accent", (0.3, 1.6, 0.16), (sx * 0.95, 0.0, 0.88), bevel=0.04)  # side rails
    box("Trim", (2.0, 0.3, 0.3), (0, 1.75, 0.45), bevel=0.08)  # bumper
    box("Trim", (1.7, 0.25, 0.25), (0, -1.65, 0.45), bevel=0.06)
    for sx in (-1, 1):
        box("Accent", (0.12, 0.12, 0.8), (sx * 0.65, -0.65, 1.25), bevel=0.02)  # hoop legs
    box("Accent", (1.42, 0.14, 0.14), (0, -0.65, 1.65), bevel=0.03)
    box("Trim", (1.0, 0.6, 0.45), (0, -1.25, 0.95), bevel=0.06)  # engine
    box("Trim", (0.9, 0.55, 0.4), (0, -0.1, 0.95), bevel=0.05)  # seat
    box("WeaponMount", (0.42, 0.42, 0.12), (0, -1.25, 1.24), bevel=0.02)
    driver(0.77, -0.1)
    lights(1.62, -1.55, 0.78, 0.5)

def kart_speedster():  # low wedge supercar kart: sharp nose, side intakes, fastback, low wing
    pods(0.36, 0.3, 0.8)
    box("Body", (1.9, 3.4, 0.45), (0, 0.0, 0.5), bevel=0.1, front_narrow=0.2, top_front_drop=0.25)
    for sx in (-1, 1):
        box("Body", (0.45, 1.5, 0.4), (sx * 0.78, -0.45, 0.85), bevel=0.1, front_narrow=0.2, top_front_drop=0.32)  # pods
        box("Trim", (0.06, 0.6, 0.2), (sx * 1.0, -0.4, 0.85), bevel=0.01)  # intakes
    box("Body", (1.1, 0.9, 0.35), (0, 0.8, 0.85), bevel=0.08, front_narrow=0.3, top_front_drop=0.3)  # cowl
    box("Accent", (0.35, 3.2, 0.02), (0, 0.0, 0.73), bevel=0)  # centre stripe
    box("Accent", (1.9, 0.38, 0.07), (0, -1.55, 1.15), bevel=0.02)  # wing
    box("Trim", (0.12, 0.2, 0.35), (0, -1.55, 0.95), bevel=0.02)
    box("Trim", (2.0, 0.22, 0.2), (0, 1.72, 0.35), bevel=0.06)  # splitter bumper
    box("Trim", (1.8, 0.2, 0.22), (0, -1.72, 0.4), bevel=0.06)
    box("Trim", (0.85, 0.5, 0.35), (0, -0.25, 0.85), bevel=0.05)
    box("WeaponMount", (0.42, 0.42, 0.12), (0, -1.0, 0.8), bevel=0.02)
    driver(0.75, -0.25)
    lights(1.62, -1.72, 0.55, 0.6)

def kart_muscle():  # muscle kart: long raised hood with scoop, twin stripes, ducktail
    pods(0.38, 0.32, 0.8)
    box("Body", (1.9, 3.3, 0.65), (0, 0.05, 0.5), bevel=0.12, segs=2, front_narrow=0.08, top_front_drop=0.1)
    box("Body", (1.6, 1.2, 0.3), (0, 1.0, 0.95), bevel=0.1, front_narrow=0.1, top_front_drop=0.12)  # hood
    box("Trim", (0.5, 0.45, 0.18), (0, 0.95, 1.15), bevel=0.04, top_front_drop=0.1)  # scoop
    for sx in (-1, 1):
        box("Accent", (0.22, 1.25, 0.02), (sx * 0.3, 1.0, 1.105), bevel=0)  # stripes
    box("Accent", (1.8, 0.4, 0.18), (0, -1.5, 0.92), bevel=0.04, top_back_drop=0.0, top_front_drop=-0.08)  # ducktail
    box("Trim", (2.0, 0.28, 0.3), (0, 1.72, 0.42), bevel=0.08)
    box("Trim", (2.0, 0.26, 0.28), (0, -1.68, 0.42), bevel=0.08)
    box("Trim", (0.9, 0.55, 0.4), (0, -0.45, 0.95), bevel=0.05)
    box("WeaponMount", (0.42, 0.42, 0.12), (0, -1.05, 0.9), bevel=0.02)
    driver(0.77, -0.45)
    lights(1.62, -1.62, 0.65, 0.6)

def kart_bubble():  # round bubble kart: rounded everything, a big round cowl, cute eyes
    pods(0.42, 0.36, 0.78)
    box("Body", (1.9, 3.1, 0.6), (0, 0.0, 0.6), bevel=0.28, segs=3, front_narrow=0.1)
    box("Body", (1.3, 0.9, 0.45), (0, 0.85, 1.0), bevel=0.2, segs=3)  # round cowl
    for sx in (-1, 1):
        cyl("Headlights", 0.18, 0.08, (sx * 0.45, 1.58, 0.75), "Y", sides=10, bevel=0)
    box("Accent", (1.94, 3.0, 0.12), (0, 0.0, 0.72), bevel=0.05)  # belt
    box("Trim", (1.6, 0.25, 0.25), (0, 1.55, 0.38), bevel=0.1, segs=2)
    box("Trim", (1.6, 0.25, 0.25), (0, -1.55, 0.38), bevel=0.1, segs=2)
    box("Trim", (0.85, 0.5, 0.38), (0, -0.3, 1.0), bevel=0.08)
    box("Accent", (0.6, 0.3, 0.5), (0, -1.25, 1.15), bevel=0.12, segs=2)  # round tail fin
    box("WeaponMount", (0.42, 0.42, 0.12), (0, -0.9, 0.97), bevel=0.02)
    driver(0.7, -0.3)
    for sx in (-1, 1):
        box("Taillights", (0.3, 0.05, 0.12), (sx * 0.55, -1.56, 0.7), bevel=0.02)

def kart_truck():  # monster kart: tall chunky body, light bar, bull bar, fat fenders
    box("Body", (1.9, 3.3, 0.6), (0, 0.0, 0.8), bevel=0.1, front_narrow=0.05, top_front_drop=0.12)
    box("Body", (1.7, 1.0, 0.45), (0, 1.05, 1.25), bevel=0.1, front_narrow=0.12, top_front_drop=0.18)  # hood
    for sx in (-1, 1):
        box("Body", (0.22, 1.4, 0.4), (sx * 0.84, -0.9, 1.25), bevel=0.06)  # bed sides
    box("Body", (1.9, 0.22, 0.4), (0, -1.55, 1.25), bevel=0.06)  # tailgate
    box("Trim", (1.4, 0.7, 0.35), (0, 0.6, 0.3), bevel=0.06)  # skid under the nose
    for sx in (-1, 1):
        box("Accent", (0.5, 1.0, 0.18), (sx * 1.25, 1.25, 1.12), bevel=0.05, top_front_drop=0.08)  # fenders
        box("Accent", (0.5, 1.0, 0.18), (sx * 1.25, -1.25, 1.12), bevel=0.05, top_back_drop=0.08)
    box("Trim", (2.1, 0.3, 0.42), (0, 1.75, 0.65), bevel=0.08)  # bull bar
    box("Trim", (2.0, 0.28, 0.3), (0, -1.72, 0.65), bevel=0.08)
    box("Trim", (1.2, 0.22, 0.14), (0, 0.35, 2.05), bevel=0.04)  # light bar frame
    for sx in (-1, 1):
        box("Trim", (0.1, 0.1, 0.65), (sx * 0.55, 0.35, 1.7), bevel=0.02)
    box("Headlights", (1.0, 0.06, 0.1), (0, 0.47, 2.05), bevel=0.01)
    box("Trim", (0.9, 0.55, 0.42), (0, -0.4, 1.25), bevel=0.05)
    box("WeaponMount", (0.42, 0.42, 0.12), (0, -1.0, 1.16), bevel=0.02)
    driver(0.81, -0.4)
    lights(1.66, -1.66, 0.9, 0.6)

KARTS = {"Kart_Racer": kart_racer, "Kart_Buggy": kart_buggy, "Kart_Speedster": kart_speedster,
         "Kart_Muscle": kart_muscle, "Kart_Bubble": kart_bubble, "Kart_Truck": kart_truck}

def finish(name):
    # join by group into one object per part name, flat shaded, triangulated, with its material
    groups = {}
    for o in list(bpy.context.scene.objects):
        groups.setdefault(o["group"], []).append(o)
    tris = 0
    for g, objs in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        o.name = g
        o.data.name = g
        cname = g if g in COL else ("Tire" if g.startswith("Wheel") else ("Accent" if g == "Driver" else "Body"))
        o.data.materials.clear()
        o.data.materials.append(mat(cname))
        bm = bmesh.new(); bm.from_mesh(o.data)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        for f in bm.faces: f.smooth = False
        tris += len(bm.faces)
        bm.to_mesh(o.data); bm.free()
        # origin at its own middle (Studio MeshParts pivot there)
        bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    ys = [ (o.matrix_world @ Vector(c)).y for o in bpy.context.scene.objects for c in o.bound_box ]
    hz = max((bpy.data.objects["Head"].matrix_world @ Vector(c)).z for c in bpy.data.objects["Head"].bound_box)
    ln = max(ys) - min(ys)
    print(name, "length", round(ln, 2), "head top in game", round(hz * 3.6 / ln, 2), "wheel dia", round(2 * WR * 3.6 / ln, 2))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.fbx(filepath=f"{OUT}/{name}.fbx", use_selection=True, apply_unit_scale=True,
                             global_scale=1.0, axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE')
    bpy.ops.export_scene.gltf(filepath=f"{OUT}/{name}.glb", export_format='GLB', use_selection=True)
    return tris, sorted(groups)

for name, fn in KARTS.items():
    clear()
    fn()
    wheels()
    tris, parts = finish(name)
    print(name, tris, "tris", parts)
