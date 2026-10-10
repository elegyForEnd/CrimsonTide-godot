"""Preserve bark and leaf silhouettes; never decimate the entire tree uniformly."""
import bpy,pathlib,math
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/opening-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
old=bpy.data.collections['woodland_tree']
if old.get('silhouette_safe_lod'): raise RuntimeError('Repaired tree already exists; preserve edits.')
for obj in list(old.objects): bpy.data.objects.remove(obj,do_unlink=True)
bpy.data.collections.remove(old)
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/story-environment/vendor/tree_small_02/tree_small_02.gltf'))
objects=[o for o in bpy.data.objects if o not in before and o.type=='MESH']
for o in objects: matrix=o.matrix_world.copy(); o.parent=None; o.matrix_world=matrix
minimum=Vector([min((o.matrix_world@Vector(c))[i] for o in objects for c in o.bound_box) for i in range(3)])
maximum=Vector([max((o.matrix_world@Vector(c))[i] for o in objects for c in o.bound_box) for i in range(3)])
center=Vector(((minimum.x+maximum.x)/2,(minimum.y+maximum.y)/2,minimum.z)); factor=3.8/(maximum.z-minimum.z)
for obj in objects:
    obj.location=(obj.location-center)*factor; obj.scale*=factor
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.separate(type='MATERIAL'); bpy.ops.object.mode_set(mode='OBJECT')
parts=[o for o in bpy.data.objects if o not in before and o.type=='MESH']
for obj in parts:
    name=obj.data.materials[0].name
    bpy.context.view_layer.objects.active=obj
    if 'leaves' in name:
        mod=obj.modifiers.new('Preserve leaf outline','DECIMATE'); mod.decimate_type='DISSOLVE'; mod.angle_limit=math.radians(12); mod.delimit={'MATERIAL'}
        bpy.ops.object.modifier_apply(modifier=mod.name)
        tris=sum(len(p.vertices)-2 for p in obj.data.polygons)
        if tris>130000:
            mod=obj.modifiers.new('Leaf curvature budget','DECIMATE'); mod.ratio=130000/tris; mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
    else:
        tris=sum(len(p.vertices)-2 for p in obj.data.polygons); budget=8000 if 'branches' in name else 5000
        mod=obj.modifiers.new('Bark surface budget','DECIMATE'); mod.ratio=min(1,budget/tris); mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    print('TREE_PART',name,sum(len(p.vertices)-2 for p in obj.data.polygons),flush=True)
col=bpy.data.collections.new('woodland_tree'); bpy.context.scene.collection.children.link(col)
for obj in parts:
    for previous in list(obj.users_collection): previous.objects.unlink(obj)
    col.objects.link(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts: obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); tree=bpy.context.object; tree.name='Tree'
tree.location=Vector((0,-57,0)); col['asset_origin']=[0,-57,0]; col['ct_asset']=True; col['ct_vendor']=True; col['silhouette_safe_lod']=True
bpy.ops.wm.save_as_mainfile(filepath=str(source))
