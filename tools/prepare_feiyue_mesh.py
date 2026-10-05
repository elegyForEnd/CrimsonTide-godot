import bpy, json
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/feiyue-3d-v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'feiyue-toon-preview.blend'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.context.view_layer.objects.active=obj
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# glTF splits vertices at UV/normal seams. Weld spatially coincident vertices
# before smoothing, retaining per-loop UVs, so seams do not shrink into cracks.
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.00001)
bpy.ops.object.mode_set(mode='OBJECT')
# Keep UVs and silhouette from the source, reduce to a practical deformation mesh.
dec=obj.modifiers.new('Prototype_Reduction','DECIMATE')
dec.ratio=60000/len(obj.data.polygons)
bpy.ops.object.modifier_apply(modifier=dec.name)
smooth=obj.modifiers.new('Surface_Cleanup','SMOOTH')
smooth.factor=0.55
smooth.iterations=3
bpy.ops.object.modifier_apply(modifier=smooth.name)
for p in obj.data.polygons: p.use_smooth=True
try:
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
except (AttributeError,RuntimeError):
    pass
parents=list(range(len(obj.data.vertices)))
def root(i):
    while parents[i]!=i:
        parents[i]=parents[parents[i]]
        i=parents[i]
    return i
for e in obj.data.edges:
    a,b=(root(i) for i in e.vertices)
    if a!=b: parents[b]=a
groups={}
for v in obj.data.vertices: groups.setdefault(root(v.index),[]).append(v)
summary=[]
for vs in sorted(groups.values(),key=len,reverse=True)[:30]:
    summary.append({'vertices':len(vs),'min':[min(v.co[i] for v in vs) for i in range(3)],'max':[max(v.co[i] for v in vs) for i in range(3)]})
report={'vertices':len(obj.data.vertices),'triangles':len(obj.data.polygons),'components':len(groups),'largest_components':summary}
(OUT/'inspection/reduced-mesh.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'feiyue-working.blend'))
print(json.dumps(report))
