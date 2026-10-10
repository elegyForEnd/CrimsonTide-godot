"""Import licensed vegetation into the editable master, normalize and simplify."""
import bpy,pathlib
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/opening-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
for slug,name,height,index in [('tree_small_02','woodland_tree',3.8,0),('fern_02','woodland_fern',.65,1)]:
    if bpy.data.collections.get(name): raise RuntimeError('Vegetation already imported: preserve master edits.')
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/story-environment/vendor'/slug/(slug+'.gltf')))
    objects=[o for o in bpy.data.objects if o not in before and o.type=='MESH']
    col=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(col)
    for obj in objects:
        matrix=obj.matrix_world.copy(); obj.parent=None; obj.matrix_world=matrix
        for previous in list(obj.users_collection): previous.objects.unlink(obj)
        col.objects.link(obj)
    minimum=Vector([min((o.matrix_world@Vector(c))[i] for o in objects for c in o.bound_box) for i in range(3)])
    maximum=Vector([max((o.matrix_world@Vector(c))[i] for o in objects for c in o.bound_box) for i in range(3)])
    center=Vector(((minimum.x+maximum.x)/2,(minimum.y+maximum.y)/2,minimum.z)); factor=height/(maximum.z-minimum.z)
    for obj in objects:
        obj.location=(obj.location-center)*factor; obj.scale*=factor
        bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
        if name=='woodland_tree' and triangles>12000:
            mod=obj.modifiers.new('Gameplay LOD authoring','DECIMATE'); mod.ratio=min(1,12000/triangles)
            bpy.ops.object.modifier_apply(modifier=mod.name)
        obj['license']='CC0-1.0'; obj['source']='https://polyhaven.com/a/'+slug
    origin=Vector((index*5,-57,0))
    for obj in objects: obj.location+=origin
    col['ct_asset']=True; col['ct_vendor']=True; col['asset_origin']=list(origin)
    print('VEGETATION_TRIANGLES',name,sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects))
bpy.ops.wm.save_as_mainfile(filepath=str(source)); bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_as_mainfile(filepath=str(source))
