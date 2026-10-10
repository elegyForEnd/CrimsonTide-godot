"""Batch the imported fern for MultiMesh and tree by materials for low draw overhead."""
import bpy,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/opening-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
for name in ['woodland_tree','woodland_fern']:
    col=bpy.data.collections[name]
    if col.get('batched'): continue
    objects=[o for o in col.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join(); obj=bpy.context.object; obj.name='Tree' if name=='woodland_tree' else 'Fern'
    tris=sum(len(p.vertices)-2 for p in obj.data.polygons)
    if name=='woodland_tree' and tris>40000:
        mod=obj.modifiers.new('Combined gameplay density','DECIMATE'); mod.ratio=40000/tris; bpy.ops.object.modifier_apply(modifier=mod.name)
    col['batched']=True
    print('BATCHED',name,sum(len(p.vertices)-2 for p in obj.data.polygons),len(obj.data.materials))
bpy.ops.wm.save_as_mainfile(filepath=str(source))
