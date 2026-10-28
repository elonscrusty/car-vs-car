# carter's Meshy kart (10-28, 1.5M faces, textured; FBX kept in project files as
# 056bfc9c2a941eb7f88a3aff6e756242.fbx) -> per-part low-poly data for KartMesh, same format as
# build.py's karts.json. Wheels are cut out and rebuilt clean (tyre + rim in the car's colour), the
# driver's head is rebuilt (Meshy drew 3 eyes: carter "the face is messed up"), the rest is decimated
# and split into paint parts by its texture colour (ToyCars.kartPaint: Body/Shade/Trim/Dark/Head...).
# Run: F=<fbx> OUT=../out <bpy python> -I meshy.py, then to_luau.py. render.py draws the result.
import bpy, bmesh, os, json, math, numpy as np
from mathutils import Vector, Euler
TARGET = int(os.environ.get("TRIS", "3800"))
NAME = os.environ.get("NAME", "Kart_Carter1")
OUT = os.environ.get("OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out"))
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.environ["F"])
o = [o for o in bpy.data.objects if o.type == 'MESH'][0]
bpy.context.view_layer.objects.active = o; o.select_set(True)
o.rotation_euler[2] += math.pi  # Meshy's nose is -Y: turn it to +Y like build.py's karts
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
m = o.data
# wheels measured on the Meshy model (nose +Y, metres-ish units): centre y, centre z, radius
WHEELS = {"F": (0.291, 0.146, 0.146), "R": (-0.177, 0.167, 0.167)}
XIN, XOUT = 0.200, 0.356
S = 0.6 / ((0.146 + 0.167) / 2)  # tyres the size of build.py's (WR 0.6); the game rescales by wheel size
YMID = (0.291 + -0.177) / 2

def centres(me):
    nf = len(me.polygons); c = np.zeros(nf * 3); me.polygons.foreach_get("center", c); return c.reshape(-1, 3)
c = centres(m)
kill = np.zeros(len(c), bool)
for _, (cy, cz, R) in WHEELS.items():
    r = np.hypot(c[:, 1] - cy, c[:, 2] - cz)
    kill |= (abs(c[:, 0]) > XIN - 0.01) & (abs(c[:, 0]) < XOUT + 0.02) & (r < R * 1.04)
print("wheel faces removed", kill.sum())
# the driver's head and cap: Meshy's face has 3 eyes, so a clean Roblox head and cap replace them
HEAD = (0.027, 0.388)  # centre y, z of the head
head = (abs(c[:, 0]) < 0.078) & (c[:, 1] > -0.045) & (c[:, 1] < 0.10) & (c[:, 2] > 0.345) & (c[:, 2] < 0.52)
head |= (abs(c[:, 0]) < 0.19) & (c[:, 1] > -0.05) & (c[:, 1] < 0.12) & (c[:, 2] > 0.40) & (c[:, 2] < 0.47)
print("head faces removed", head.sum()); kill |= head
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
m.polygons.foreach_set("select", kill)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.delete(type='FACE'); bpy.ops.object.mode_set(mode='OBJECT')
# weld the near-duplicate verts Meshy leaves, then decimate
dec = o.modifiers.new("d", 'DECIMATE'); dec.decimate_type = 'COLLAPSE'
dec.ratio = TARGET / len(m.polygons); dec.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="d")
m = o.data
print("decimated to", len(m.polygons))
# drop crumbs: loose bits under a few faces
bm = bmesh.new(); bm.from_mesh(m)
seen = set(); crumbs = []
for f in bm.faces:
    if f.index in seen: continue
    stack = [f]; island = []
    seen.add(f.index)
    while stack:
        g = stack.pop(); island.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen: seen.add(h.index); stack.append(h)
    if len(island) < 6: crumbs += island
bmesh.ops.delete(bm, geom=crumbs, context='FACES'); bmesh.ops.triangulate(bm, faces=bm.faces)
bm.to_mesh(m); bm.free(); print("crumbs", len(crumbs))

nv = len(m.vertices); nf = len(m.polygons)
V = np.zeros(nv * 3); m.vertices.foreach_get("co", V); V = V.reshape(-1, 3)
F = np.zeros(nf * 3, dtype=np.int64); m.polygons.foreach_get("vertices", F); F = F.reshape(-1, 3)
uv = np.zeros(len(m.loops) * 2); m.uv_layers[0].data.foreach_get("uv", uv); uv = uv.reshape(-1, 3, 2)
img = [i for i in bpy.data.images if i.name == "texture_pbr_20250901.png"][0]
W, H = img.size; px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[:, :, :3]
BARY = np.array([[1/3, 1/3, 1/3], [.6, .2, .2], [.2, .6, .2], [.2, .2, .6], [.45, .45, .1], [.1, .45, .45], [.45, .1, .45]])
CLS = ["Trim", "Dark", "Light", "Head", "Shade", "Body"]
def classify(col):
    r, g, b = col[..., 0], col[..., 1], col[..., 2]
    mx = col.max(-1); mn = col.min(-1); sat = (mx - mn) / np.maximum(mx, 1e-6)
    hue = np.degrees(np.arctan2(np.sqrt(3) * (g - b), 2 * r - g - b)) % 360
    k = np.full(mx.shape, 1)  # Dark (steel grey)
    k[mx < 0.25] = 0
    k[(sat <= 0.35) & (mx > 0.8)] = 2
    colorful = (sat > 0.35) & (mx >= 0.25)
    k[colorful & ((hue < 75) | (hue > 340))] = 3
    k[colorful & (hue >= 205) & (hue < 340)] = 4
    k[colorful & (hue >= 245) & (hue < 340) & (mx >= 0.6)] = 5
    return k
fuv = np.einsum("pk,fkd->fpd", BARY, uv)
xi = np.clip((fuv[..., 0] % 1 * W).astype(int), 0, W - 1); yi = np.clip((fuv[..., 1] % 1 * H).astype(int), 0, H - 1)
votes = classify(px[yi, xi])
cls = np.array([np.bincount(v, minlength=len(CLS)).argmax() for v in votes])
cen = V[F].mean(1)
grp = np.array([CLS[k] for k in cls], dtype=object)
FY = 0.09
# white bits: front ones are the headlights, the rest is paint
grp[(grp == "Light") & ~(cen[:, 1] > 0.38)] = "Body"
grp[grp == "Light"] = "Headlights"
for g in sorted(set(grp)): print(g, (grp == g).sum())

def roblox(p):  # Blender (Meshy-scaled) -> Roblox toy units, nose +Z
    x, y, z = (p[0]) * S, (p[1] - YMID) * S, p[2] * S
    return [round(-x, 3), round(z, 3), round(y, 3)]
data = {}
for g in sorted(set(grp)):
    fs = F[grp == g]; used = np.unique(fs); remap = {int(v): i for i, v in enumerate(used)}
    data[g] = {"v": [roblox(V[v]) for v in used], "t": [[remap[int(i)] for i in f] for f in fs]}

# new parts made here, straight in toy units (Blender axes, nose +Y)
parts = {}
def add(group, bm):
    bmesh.ops.triangulate(bm, faces=bm.faces); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    d = parts.setdefault(group, {"v": [], "t": []}); base = len(d["v"])
    bm.verts.index_update()
    for v in bm.verts: d["v"].append([round(-v.co.x, 3), round(v.co.z, 3), round(v.co.y, 3)])
    for f in bm.faces: d["t"].append([base + v.index for v in f.verts])
    bm.free()
def cyl(group, r, depth, loc, sides=14, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r, radius2=r, depth=depth)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler((0, math.pi / 2, 0)).to_matrix())
    if bevel > 0:
        es = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.2]
        bmesh.ops.bevel(bm, geom=es, offset=bevel, segments=1, affect='EDGES')
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(loc)); add(group, bm)
def box(group, size, loc, rot=(0, 0, 0), bevel=0.0, segs=1):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0: bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect='EDGES', profile=0.5)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(loc)); add(group, bm)
# wheels like carter's model: black tyre, coloured rim ring, dark hub
w = (XOUT - XIN) * S; wx = (XIN + XOUT) / 2 * S
for tag, key in (("FL", "F"), ("FR", "F"), ("RL", "R"), ("RR", "R")):
    cy, cz, R = WHEELS[key]; y = (cy - YMID) * S; r = R * S
    x = wx if tag[1] == "R" else -wx; side = 1 if x > 0 else -1
    cyl("Wheel" + tag, r, w, (x, y, r), 14, bevel=0.08)
    cyl("Rim" + tag, r * 0.68, 0.06, (x + side * w / 2, y, r), 14)
    cyl("Wheel" + tag, r * 0.48, 0.08, (x + side * (w / 2 + 0.02), y, r), 12)
    cyl("Rim" + tag, r * 0.16, 0.1, (x + side * (w / 2 + 0.05), y, r), 6)
# a clean Roblox head (carter: the face was messed up): yellow block, two eyes and a smile, cap on top
h = 0.58; hy = (HEAD[0] - YMID) * S; hz = HEAD[1] * S; top = hz + h / 2
box("Head", (h, h, h), (0, hy, hz), bevel=0.13, segs=2)
fy = hy + h / 2 + 0.005
for sx in (-1, 1):
    box("Eyes", (0.07, 0.03, 0.12), (sx * 0.12, fy, hz + 0.06))
box("Eyes", (0.24, 0.03, 0.045), (0, fy, hz - 0.12))  # smile
for sx in (-1, 1):
    box("Eyes", (0.045, 0.03, 0.05), (sx * 0.13, fy, hz - 0.09))
box("Cap", (h + 0.06, h + 0.06, 0.2), (0, hy, top + 0.06), bevel=0.08, segs=2)
box("Cap", (h * 0.8, 0.32, 0.06), (0, hy + h / 2 + 0.11, top - 0.02), rot=(-0.15, 0, 0), bevel=0.02)
for g, d in parts.items():
    if g in data:
        base = len(data[g]["v"]); data[g]["v"] += d["v"]; data[g]["t"] += [[i + base for i in t] for t in d["t"]]
    else:
        data[g] = d
tris = sum(len(d["t"]) for d in data.values())
print("TOTAL", tris, "S", S, "cap top", max(v[1] for v in data["Cap"]["v"]), "parts", sorted(data))
json.dump({NAME: data}, open(f"{OUT}/carter1.json", "w"), separators=(",", ":"))
