# carter's reference karts (v3): one shared go-kart chassis (tray, seat, engine with pipes,
# bumpers, side pods, fat wheels with rims and hub caps, a big blocky driver with a face) and six
# body shells. Blender: nose +Y, up +Z, units = toy units. Writes GLB/FBX previews and karts.json
# (per kart, per part: vertices + triangles) for the game's runtime mesh builder.
import bpy, bmesh, math, os, json
from mathutils import Vector, Euler

OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"))
os.makedirs(OUT, exist_ok=True)
COL = {"Body": (0.9, 0.2, 0.18, 1), "Accent": (1, 0.78, 0.17, 1), "Trim": (0.1, 0.1, 0.17, 1),
       "Metal": (0.8, 0.82, 0.86, 1), "Head": (1, 0.8, 0.17, 1), "Eyes": (0.1, 0.1, 0.17, 1),
       "Driver": (0.2, 0.45, 0.9, 1), "Headlights": (1, 0.98, 0.9, 1), "Taillights": (1, 0.2, 0.24, 1),
       "WeaponMount": (0.1, 0.1, 0.17, 1), "Cap": (0.9, 0.2, 0.18, 1), "Dark": (0.27, 0.29, 0.33, 1), "Glow": (1, 0.5, 1, 1), "Shade": (0.4, 0.2, 0.5, 1), "Seat": (1, 0.78, 0.17, 1), "Tire": (0.12, 0.12, 0.13, 1), "Rim": (1, 1, 1, 1)}

def obj(bm, group):
    me = bpy.data.meshes.new(group); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(group, me); bpy.context.scene.collection.objects.link(o); o["group"] = group
    return o

def box(group, size, loc, bevel=0.05, segs=1, front_narrow=0.0, back_narrow=0.0, top_front_drop=0.0,
        top_back_drop=0.0, top_narrow=0.0, rot=None):
    bm = bmesh.new(); sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2; vs = {}
    for ix in (-1, 1):
        for iy in (-1, 1):
            for iz in (-1, 1):
                x, y, z = ix * sx, iy * sy, iz * sz
                if iy == 1: x *= (1 - front_narrow)
                if iy == -1: x *= (1 - back_narrow)
                if iz == 1:
                    x *= (1 - top_narrow)
                    if iy == 1: z -= top_front_drop
                    if iy == -1: z -= top_back_drop
                vs[(ix, iy, iz)] = bm.verts.new((x, y, z))
    F = lambda *k: bm.faces.new([vs[i] for i in k])
    F((-1,-1,-1),(-1,1,-1),(1,1,-1),(1,-1,-1)); F((-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1))
    F((-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1)); F((-1,1,-1),(-1,1,1),(1,1,1),(1,1,-1))
    F((-1,-1,-1),(-1,-1,1),(-1,1,1),(-1,1,-1)); F((1,-1,-1),(1,1,-1),(1,1,1),(1,-1,1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect='EDGES', profile=0.5)
    if rot: bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(loc))
    return obj(bm, group)

def cyl(group, r, depth, loc, axis="X", sides=10, bevel=0.0, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    rot = {"X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0), "Z": (0, 0, 0)}[axis]
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    if bevel > 0:
        es = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.2]
        bmesh.ops.bevel(bm, geom=es, offset=bevel, segments=1, affect='EDGES')
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(loc))
    return obj(bm, group)


WR, WW, WX, WY = 0.6, 0.62, 1.12, 1.08  # big fat tyres; the game scales the kart so they match the race wheel
HT = 2.05  # cap top: the hat spot (ToyCars.HEAD_TOP 1.8) once scaled by the wheel size (0.524 / 0.6)

def wheel(tag, x, y, r=WR, w=WW, knobs=False):
    side = 1 if x > 0 else -1
    cyl("Wheel" + tag, r, w, (x, y, r), "X", sides=14, bevel=0.09)
    if knobs:  # monster tread blocks
        for i in range(10):
            a = i * math.pi * 2 / 10
            box("Wheel" + tag, (w * 0.9, 0.24, 0.12), (x, y + math.cos(a) * r, r + math.sin(a) * r), bevel=0, rot=(a + math.pi / 2, 0, 0))
    # coloured rim ring with a dark hub in it
    cyl("Rim" + tag, r * 0.66, 0.06, (x + side * w / 2, y, r), "X", sides=12)
    cyl("Wheel" + tag, r * 0.42, 0.08, (x + side * (w / 2 + 0.02), y, r), "X", sides=10)
    cyl("Rim" + tag, r * 0.14, 0.1, (x + side * (w / 2 + 0.05), y, r), "X", sides=6)

def wheels(r=WR, w=WW, knobs=False, wx=WX):
    for tag, x, y in (("FL", -wx, WY), ("FR", wx, WY), ("RL", -wx, -WY), ("RR", wx, -WY)):
        wheel(tag, x, y, r, w, knobs)

def tube(group, a, b, t=0.11):
    # square tube from point a to point b
    a, b = Vector(a), Vector(b); d = b - a
    o = box(group, (t, t, d.length), (0, 0, 0), bevel=0.02)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = q; o.location = (a + b) / 2
    bpy.context.view_layer.update(); o.data.transform(o.matrix_world); o.matrix_world.identity()

def base(seat_y=-0.35, seat_z=0.5, tub=True):
    box("Trim", (1.3, 2.4, 0.16), (0, 0.0, 0.42), bevel=0.04)  # floor pan
    if tub:  # the body wraps the driver: only shoulders, head and cap show (carter's picture)
        for sx in (-1, 1):
            box("Body", (0.32, 1.5, 0.78), (sx * 0.64, -0.3, 0.78), bevel=0.1, segs=2)
        box("Body", (1.3, 0.4, 0.62), (0, 0.3, 0.88), bevel=0.1, segs=2, top_front_drop=0.12)  # cowl
        box("Body", (1.4, 0.55, 0.72), (0, -1.0, 0.8), bevel=0.1, segs=2)  # deck behind the seat
    box("Trim", (0.78, 0.6, 0.22), (0, seat_y, seat_z), bevel=0.06)
    box("Seat", (0.7, 0.18, 0.62), (0, seat_y - 0.34, seat_z + 0.4), bevel=0.07, rot=(-0.22, 0, 0))
    box("Trim", (0.07, 0.07, 0.42), (0, seat_y + 0.72, seat_z + 0.32), bevel=0, rot=(0.6, 0, 0))
    cyl("Trim", 0.21, 0.06, (0, seat_y + 0.58, seat_z + 0.55), "Y", sides=12)

def driver(y0=-0.35, z0=0.62):
    # Roblox kid: shirt in the kart colour, yellow head with a smile, cap (kart colour) on top
    box("Driver", (0.74, 0.42, 0.62), (0, y0, z0 + 0.31), bevel=0.06)
    for sx in (-1, 1):
        box("Driver", (0.24, 0.6, 0.24), (sx * 0.48, y0 + 0.28, z0 + 0.46), bevel=0.05, rot=(0.3, 0, 0))
        box("Head", (0.2, 0.2, 0.2), (sx * 0.4, y0 + 0.62, z0 + 0.38), bevel=0.05)  # hands
    h = 0.66; top = HT - 0.15; hz = top - h / 2
    box("Head", (h, h, h), (0, y0, hz), bevel=0.15, segs=3)
    fy = y0 + h / 2 + 0.005
    for sx in (-1, 1):
        box("Eyes", (0.08, 0.03, 0.13), (sx * 0.13, fy, hz + 0.06), bevel=0.02)
    box("Eyes", (0.26, 0.03, 0.05), (0, fy, hz - 0.13), bevel=0.01)  # smile
    for sx in (-1, 1):
        box("Eyes", (0.05, 0.03, 0.05), (sx * 0.14, fy, hz - 0.1), bevel=0.01)
    box("Cap", (h + 0.06, h + 0.06, 0.2), (0, y0, top + 0.06), bevel=0.08, segs=2)
    box("Cap", (h * 0.8, 0.34, 0.06), (0, y0 + h / 2 + 0.12, top - 0.02), bevel=0.03, rot=(-0.15, 0, 0))

def mount(y, z):  # (carter 10-28: no weapon on the kart; it shows as an icon above it)
    pass

def taillights(y, z, x=0.55):
    for sx in (-1, 1):
        box("Taillights", (0.3, 0.06, 0.14), (sx * x, y, z), bevel=0.03)

def roundlight(x, y, z, r=0.13, ring="Body"):
    cyl(ring, r + 0.04, 0.08, (x, y - 0.03, z), "Y", sides=8)
    cyl("Headlights", r, 0.08, (x, y + 0.01, z), "Y", sides=8)

def kart_racer():  # red sports car: low wedge, hood stripes, splitter, big rear wing
    base()
    box("Body", (1.8, 1.5, 0.5), (0, 0.75, 0.68), bevel=0.12, segs=2, front_narrow=0.3, top_front_drop=0.26)
    box("Body", (1.8, 1.1, 0.9), (0, -0.85, 0.72), bevel=0.12, segs=2, top_back_drop=0.05)
    for sx in (-1, 1):
        box("Body", (0.35, 1.0, 0.45), (sx * 0.78, -0.05, 0.65), bevel=0.1)
        box("Trim", (0.05, 0.4, 0.2), (sx * 0.96, -0.1, 0.68), bevel=0.01)  # intakes
        box("Accent", (0.13, 1.52, 0.03), (sx * 0.16, 0.75, 0.815), bevel=0, rot=(-0.172, 0, 0))  # stripes
        box("Accent", (0.13, 0.42, 0.03), (sx * 0.16, 0.3, 1.2), bevel=0)
        box("Accent", (0.13, 1.1, 0.03), (sx * 0.16, -0.85, 1.17), bevel=0)
        box("Headlights", (0.4, 0.08, 0.08), (sx * 0.5, 1.48, 0.62), bevel=0.02, rot=(0, 0, sx * 0.2))
    box("Body", (0.5, 1.3, 0.14), (0, 0.85, 0.84), bevel=0.05, front_narrow=0.4, rot=(-0.172, 0, 0))  # nose ridge
    box("Trim", (2.0, 0.38, 0.07), (0, 1.55, 0.3), bevel=0.02)  # splitter
    box("Trim", (1.0, 0.05, 0.15), (0, 1.5, 0.45), bevel=0.01)  # grille
    for sx in (-1, 1):
        box("Trim", (0.08, 0.14, 0.45), (sx * 0.55, -1.25, 1.15), bevel=0.02)
        box("Body", (0.08, 0.5, 0.36), (sx * 0.92, -1.3, 1.42), bevel=0.02)
    box("Body", (1.9, 0.5, 0.12), (0, -1.3, 1.42), bevel=0.04, top_back_drop=-0.06)
    box("Trim", (1.4, 0.15, 0.25), (0, -1.45, 0.4), bevel=0.04)  # diffuser
    taillights(-1.41, 0.85, 0.6); mount(-0.95, 1.05); driver()

def kart_dozer():  # blue bulldozer: boxy body, roll cage with light bar, big blade with teeth
    base()
    box("Body", (1.6, 2.2, 0.55), (0, -0.05, 0.75), bevel=0.08)
    box("Body", (1.3, 0.8, 0.3), (0, 0.65, 1.12), bevel=0.06, top_front_drop=0.08)  # hood
    for sx in (-1, 1):
        roundlight(sx * 0.42, 1.06, 1.06, 0.12)
        tube("Body", (sx * 0.72, 0.25, 1.0), (sx * 0.62, 0.05, 2.05), 0.13); tube("Body", (sx * 0.72, -1.0, 1.0), (sx * 0.62, -0.75, 2.05), 0.13)
        tube("Body", (sx * 0.62, 0.05, 2.05), (sx * 0.62, -0.75, 2.05), 0.13)
        tube("Body", (sx * 0.7, 0.9, 0.6), (sx * 0.95, 1.5, 0.55), 0.18)  # scoop arms
        box("Body", (0.1, 0.6, 0.7), (sx * 1.1, 1.75, 0.48), bevel=0.02, top_front_drop=0.25)  # scoop sides
    tube("Body", (-0.62, 0.05, 2.05), (0.62, 0.05, 2.05), 0.13)
    for i in (-1, 0, 1):
        roundlight(i * 0.32, 0.12, 2.12, 0.11)
    box("Dark", (2.3, 0.14, 0.75), (0, 1.5, 0.5), bevel=0.04, rot=(0.15, 0, 0))  # scoop back
    box("Dark", (2.3, 0.55, 0.1), (0, 1.78, 0.18), bevel=0.03, rot=(-0.5, 0, 0))  # lip, tipped forward
    box("Body", (2.34, 0.12, 0.14), (0, 1.48, 0.9), bevel=0.03)
    for i in range(5):
        box("Dark", (0.24, 0.3, 0.12), (-0.88 + i * 0.44, 2.05, 0.06), bevel=0.03, front_narrow=0.4)
    taillights(-1.16, 0.9, 0.55); mount(-0.85, 1.08); driver()

def kart_buggy():  # yellow dune buggy: tube cage, small nose, bumper with 3 round lights, rear engine
    base()
    box("Body", (1.3, 0.9, 0.4), (0, 0.85, 0.7), bevel=0.08, front_narrow=0.15, top_front_drop=0.15)
    box("Body", (1.5, 1.2, 0.3), (0, -0.6, 0.65), bevel=0.06)
    for sx in (-1, 1):
        tube("Body", (sx * 0.68, 0.75, 0.95), (sx * 0.58, 0.05, 1.9), 0.1)  # front pillars lean forward
        tube("Body", (sx * 0.7, -1.1, 0.9), (sx * 0.58, -0.8, 1.9), 0.1)
        tube("Body", (sx * 0.58, 0.05, 1.9), (sx * 0.58, -0.8, 1.9), 0.1)
        tube("Body", (sx * 0.68, 0.75, 0.95), (sx * 0.45, 1.35, 0.72), 0.1)
    tube("Body", (-0.58, 0.05, 1.9), (0.58, 0.05, 1.9), 0.1)
    tube("Body", (-0.58, -0.8, 1.9), (0.58, -0.8, 1.9), 0.1)
    box("Trim", (1.6, 0.18, 0.24), (0, 1.42, 0.5), bevel=0.05)
    for i in (-1, 0, 1):
        roundlight(i * 0.46, 1.53, 0.74, 0.19)
    box("Trim", (0.6, 0.45, 0.35), (0, -1.15, 1.0), bevel=0.06)
    for sx in (-1, 1):
        cyl("Trim", 0.07, 0.5, (sx * 0.2, -1.35, 1.25), "Z", sides=8)
    taillights(-1.22, 0.65, 0.6); mount(-0.8, 2.06); driver()

def kart_monster():  # green monster: knobbly tyres, lifted body, shocks, cage with 4 lights, grille lights
    base()
    box("Body", (1.65, 2.3, 0.55), (0, 0.0, 1.0), bevel=0.08)
    box("Body", (1.5, 0.95, 0.14), (0, 0.75, 1.3), bevel=0.05)  # hood
    box("Trim", (1.4, 0.1, 0.4), (0, 1.16, 0.95), bevel=0.02)  # grille
    for i in (-1, 0, 1):
        roundlight(i * 0.42, 1.2, 0.95, 0.15, "Body")
    box("Trim", (1.7, 0.2, 0.2), (0, 1.25, 0.62), bevel=0.05)
    for sx in (-1, 1):
        for y in (WY, -WY):
            cyl("Metal", 0.06, 0.55, (sx * 0.72, y * 0.6, 0.75), "Z", sides=6)
            cyl("Accent", 0.1, 0.25, (sx * 0.72, y * 0.6, 0.62), "Z", sides=8)
        tube("Trim", (sx * 0.7, 0.3, 1.25), (sx * 0.62, 0.05, 2.0)); tube("Trim", (sx * 0.7, -1.0, 1.25), (sx * 0.62, -0.75, 2.0))
        tube("Trim", (sx * 0.62, 0.05, 2.0), (sx * 0.62, -0.75, 2.0))
        for y in (WY, -WY):  # boxy flares over each tyre
            box("Body", (0.66, 1.0, 0.2), (sx * 1.2, y, 1.44), bevel=0.06, front_narrow=0.0, top_front_drop=0.06, top_back_drop=0.06)

    tube("Trim", (-0.62, 0.05, 2.0), (0.62, 0.05, 2.0))
    for i in range(4):
        roundlight(-0.48 + i * 0.32, 0.12, 2.08, 0.12, "Body")
    taillights(-1.16, 1.05, 0.55); mount(-0.75, 1.32); driver(z0=0.62)

def kart_rocket():  # purple rocket: pointed nose, tall swept fins, big jet engine with a glowing nozzle
    base()
    box("Body", (1.6, 1.6, 0.45), (0, 0.7, 0.62), bevel=0.1, segs=2, front_narrow=0.7, top_front_drop=0.22)
    box("Body", (1.7, 1.1, 0.5), (0, -0.7, 0.7), bevel=0.1, segs=2)
    box("Trim", (0.7, 0.6, 0.12), (0, 0.6, 0.84), bevel=0.04, front_narrow=0.4)  # dark canopy
    for sx in (-1, 1):
        box("Headlights", (0.35, 0.08, 0.08), (sx * 0.35, 1.45, 0.62), bevel=0.02, rot=(0, 0, -sx * 0.35))
        box("Body", (0.1, 1.05, 1.0), (sx * 0.74, -1.05, 1.25), bevel=0.03, top_front_drop=0.8, rot=(0, sx * 0.22, 0))  # bat-wing fins, tip behind the head
        box("Body", (0.5, 0.7, 0.08), (sx * 0.95, -0.5, 0.82), bevel=0.02, front_narrow=0.6)
    cyl("Shade", 0.45, 0.9, (0, -1.05, 1.2), "Y", sides=12)
    cyl("Trim", 0.5, 0.15, (0, -0.65, 1.2), "Y", sides=12)
    cyl("Trim", 0.4, 0.15, (0, -1.55, 1.2), "Y", sides=12, r2=0.46)
    cyl("Glow", 0.32, 0.08, (0, -1.62, 1.2), "Y", sides=12)  # glowing nozzle
    taillights(-1.3, 0.65, 0.6); driver()

def kart_hotrod():  # orange hot-rod: long hood, open engine with blower stacks, grille, round lamps, flames, pipes
    base()
    box("Body", (1.2, 1.3, 0.5), (0, 0.85, 0.72), bevel=0.08)
    box("Body", (1.7, 1.3, 0.75), (0, -0.65, 0.85), bevel=0.1, segs=2)  # cab
    box("Trim", (1.0, 0.1, 0.62), (0, 1.52, 0.72), bevel=0.03)  # grille frame
    for i in range(6):
        box("Metal", (0.05, 0.06, 0.5), (-0.36 + i * 0.144, 1.56, 0.72), bevel=0)
    for sx in (-1, 1):
        cyl("Trim", 0.05, 0.3, (sx * 0.72, 1.35, 0.95), "X", sides=6)
        cyl("Trim", 0.27, 0.16, (sx * 0.88, 1.3, 0.98), "Y", sides=12)  # lamp shell
        cyl("Headlights", 0.22, 0.1, (sx * 0.88, 1.4, 0.98), "Y", sides=12)
        for (yy, zz, ln, hh) in ((-0.55, 0.95, 0.9, 0.24), (-0.3, 0.72, 0.8, 0.16), (-0.75, 1.12, 0.5, 0.14)):
            box("Accent", (0.04, ln, hh), (sx * 0.87, yy, zz), bevel=0, front_narrow=0.0, top_front_drop=hh * 0.7)  # flames
        cyl("Metal", 0.08, 0.9, (sx * 0.75, -1.15, 1.35), "Z", sides=8)  # exhaust stacks
    box("Metal", (0.85, 0.9, 0.45), (0, 0.85, 1.17), bevel=0.06)  # chrome engine
    box("Trim", (0.65, 0.55, 0.28), (0, 0.85, 1.53), bevel=0.05)  # black blower
    for i in (-1, 0, 1):
        cyl("Metal", 0.1, 0.26, (i * 0.21, 0.85, 1.79), "Z", sides=8)
        cyl("Trim", 0.06, 0.27, (i * 0.21, 0.85, 1.8), "Z", sides=8)  # scoop holes
    for sx in (-1, 1):
        box("Metal", (0.2, 0.8, 0.28), (sx * 0.5, 0.85, 1.12), bevel=0.05, rot=(0, sx * 0.5, 0))  # cylinder heads
    box("Trim", (1.5, 0.15, 0.2), (0, 1.62, 0.38), bevel=0.04)
    taillights(-1.31, 0.95, 0.6); mount(-0.95, 1.28); driver()

KARTS = {"Kart_Racer": kart_racer, "Kart_Dozer": kart_dozer, "Kart_Buggy": kart_buggy,
         "Kart_Monster": kart_monster, "Kart_Rocket": kart_rocket, "Kart_HotRod": kart_hotrod}
def colname(g):
    if g.startswith("Wheel"): return "Tire"
    if g.startswith("Rim"): return "Rim"
    return g

def finish(name):
    groups = {}
    for o in list(bpy.context.scene.objects): groups.setdefault(o["group"], []).append(o)
    data = {}; tris = 0
    for g, objs in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs: o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1: bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active; o.name = g; o.data.name = g
        m = bpy.data.materials.get(colname(g)) or bpy.data.materials.new(colname(g))
        m.diffuse_color = COL[colname(g)]; m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = COL[colname(g)]
        o.data.materials.clear(); o.data.materials.append(m)
        bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        for f in bm.faces: f.smooth = False
        bm.verts.index_update()
        # Roblox: X = -x, Y = z, Z = y (nose +Z, as the game's skins expect)
        data[g] = {"v": [[round(-v.co.x, 3), round(v.co.z, 3), round(v.co.y, 3)] for v in bm.verts],
                   "t": [[v.index for v in f.verts] for f in bm.faces]}
        tris += len(bm.faces); bm.to_mesh(o.data); bm.free()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=f"{OUT}/{name}.glb", export_format='GLB', use_selection=True)
    return tris, data

allk = {}
for name, fn in KARTS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    fn(); wheels(knobs=(name == "Kart_Monster"), r=(0.66 if name == "Kart_Monster" else WR), w=(0.7 if name == "Kart_Monster" else WW), wx=(1.18 if name == "Kart_Monster" else WX))
    tris, data = finish(name); allk[name] = data
    hz = max(v[1] for g in ("Cap",) for v in data[g]["v"])
    print(name, tris, "tris", "cap top", hz, sorted(data))
json.dump(allk, open(f"{OUT}/karts.json", "w"), separators=(",", ":"))
