"""Separate camera-facing side walls in the master, keeping floor/back wall solid."""
import bpy,bmesh,pathlib
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/opening-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
if bpy.context.scene.get('sidewall_revision'): raise RuntimeError('Side walls already split; preserve artist edits.')
for role in range(6):
    col=bpy.data.collections['service_%d'%role]; origin=Vector(col['asset_origin'])
    body=next(o for o in col.objects if o.name.startswith('Body'))
    bm=bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
    remaining=set(bm.verts); selected=set(); w=2.6+.3*(role%3)
    while remaining:
        first=remaining.pop(); component={first}; queue=[first]
        while queue:
            for edge in queue.pop().link_edges:
                for vertex in edge.verts:
                    if vertex in remaining: remaining.remove(vertex); component.add(vertex); queue.append(vertex)
        centre=sum((v.co+body.location-origin for v in component),Vector())/len(component)
        if centre.x>w/2-.32 and centre.z>.10: selected.update(v.index for v in component)
    side_data=body.data.copy(); side_data.name='Camera facing wall'
    side_bm=bmesh.new(); side_bm.from_mesh(side_data); side_bm.verts.ensure_lookup_table()
    bmesh.ops.delete(side_bm,geom=[v for v in side_bm.verts if v.index not in selected],context='VERTS')
    side_bm.to_mesh(side_data); side_bm.free()
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index in selected],context='VERTS')
    bm.to_mesh(body.data); bm.free()
    side=bpy.data.objects.new('Side',side_data); col.objects.link(side); side.location=body.location.copy()
    print('SPLIT_SIDE',role,len(side_data.polygons))
bpy.context.scene['sidewall_revision']=1
bpy.ops.wm.save_as_mainfile(filepath=str(source))
