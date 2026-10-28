# render kart json the way the game paints it (ToyCars.kartPaint), flat shaded
import bpy, os, json, math, mathutils
bpy.ops.wm.read_factory_settings(use_empty=True)
J = json.load(open(os.environ["J"])); name = os.environ.get("K") or list(J)[0]; kart = J[name]
car = tuple(int(x) for x in os.environ.get("C", "150,80,255").split(","))
out = os.environ["O"]; os.makedirs(out, exist_ok=True)
def lit(c): return tuple(x + (255 - x) / 3 for x in c)
PAINT = {"Body": car, "Cap": car, "Driver": car, "Shade": tuple(x * .55 for x in car), "Trim": (27, 27, 47), "Eyes": (27, 27, 47),
         "Seat": (27, 27, 47), "Dark": (70, 74, 84), "Metal": (205, 210, 220), "Head": (255, 199, 44), "Headlights": lit(car),
         "Glow": lit(car), "Taillights": (255, 50, 60), "Accent": (255, 255, 255)}
def paint(g):
    if g.startswith("Wheel"): return (28, 28, 30)
    if g.startswith("Rim"): return car
    return PAINT[g]
def srgb2lin(c):
    c = c / 255; return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
for g, d in kart.items():
    me = bpy.data.meshes.new(g)
    # Roblox (X,Y,Z) -> Blender (-X, Z, Y)
    me.from_pydata([(-v[0], v[2], v[1]) for v in d["v"]], [], d["t"]); me.update()
    ob = bpy.data.objects.new(g, me); bpy.context.scene.collection.objects.link(ob)
    mt = bpy.data.materials.new(g); c = paint(g); mt.diffuse_color = (*[srgb2lin(x) for x in c], 1); me.materials.append(mt)
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'MATERIAL'
sc.display.shading.show_cavity = False; sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = sc.render.resolution_y = 800
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.75, 0.82, 0.9)
sc.display.shading.background_type = 'WORLD' if False else 'THEME'
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'
c = mathutils.Vector((0, 0, 0.9)); views = eval(os.environ.get("V", "{'q':(0.8,1,0.6),'front':(0,1,0.15),'side':(1,0,0.1),'chase':(0.3,-1,0.55)}"))
zoom = float(os.environ.get("Z", "1")); T = os.environ.get("T")
if T: c = mathutils.Vector(eval(T))
for n, d in views.items():
    d = mathutils.Vector(d).normalized(); cam.location = c + d * 10
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = 5.2 / zoom
    sc.render.filepath = f"{out}/{n}.png"; bpy.ops.render.render(write_still=True)
