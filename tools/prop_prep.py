# Shrinks one Hunyuan prop: decimate to N tris, long side along X (rotZ degrees), feet at 0,
# middle at x=y=0, albedo only (px square). Usage: python3 prop_prep.py -- src.fbx tris rotZ px out.fbx
import bpy,sys,math,os
from mathutils import Vector,Matrix
a=sys.argv[sys.argv.index('--')+1:]
src,tris,rot,px,out=a[0],int(a[1]),float(a[2]),int(a[3]),a[4]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
ob=[o for o in bpy.context.scene.objects if o.type=='MESH'][0]
bpy.context.view_layer.objects.active=ob; ob.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
mod=ob.modifiers.new('d','DECIMATE'); mod.decimate_type='COLLAPSE'; mod.ratio=tris/len(ob.data.polygons); mod.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier='d')
ob.data.transform(Matrix.Rotation(math.radians(rot),4,'Z'))
bb=[Vector(v) for v in ob.bound_box]
lo=Vector([min(v[i] for v in bb) for i in range(3)]);hi=Vector([max(v[i] for v in bb) for i in range(3)])
ob.data.transform(Matrix.Translation((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z)))
ob.data.update()
print('PROP',os.path.basename(out),len(ob.data.polygons),[round(x,3) for x in hi-lo])
m=ob.data.materials[0]
for n in list(m.node_tree.nodes):
    nm=(n.image.name.lower() if n.type=='TEX_IMAGE' and n.image else '')
    if n.type=='TEX_IMAGE' and n.image and not any(k in nm for k in('normal','rough','metal')):
        tex=out[:-4]+'_texture.png'
        open(tex,'wb').write(n.image.packed_file.data if n.image.packed_file else open(bpy.path.abspath(n.image.filepath),'rb').read())
        img=bpy.data.images.load(tex); img.scale(px,px); img.filepath_raw=tex; img.file_format='PNG'; img.save(); img.pack()
        old=n.image; n.image=img; bpy.data.images.remove(old)
        base=m.node_tree.nodes['Principled BSDF']
        for l in list(m.node_tree.links):
            if l.to_node==base: m.node_tree.links.remove(l)
        m.node_tree.links.new(n.outputs['Color'],base.inputs['Base Color'])
    elif n.type in('TEX_IMAGE','NORMAL_MAP'): m.node_tree.nodes.remove(n)
b=m.node_tree.nodes['Principled BSDF']; b.inputs['Metallic'].default_value=0; b.inputs['Roughness'].default_value=0.8
for im in list(bpy.data.images):
    if im.users==0: bpy.data.images.remove(im)
print('IMGS',[(i.name,i.size[:],len(i.packed_file.data) if i.packed_file else 0) for i in bpy.data.images])
bpy.ops.export_scene.fbx(filepath=out,use_selection=False,path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y',global_scale=1.0,apply_unit_scale=True,bake_space_transform=False,mesh_smooth_type='FACE')
print('OUT',out,os.path.getsize(out))
