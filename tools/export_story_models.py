"""Export tagged collections from the editable master; never rebuild/save it."""
import bpy,pathlib,json,sys
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/opening-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
out=ROOT/'assets/story/environment/models'; manifest=[]
requested=next((x.split('=',1)[1].split(',') for x in sys.argv if x.startswith('--assets=')),None)
old_manifest=json.loads((out.parent/'model-manifest.json').read_text(encoding='utf-8'))['models'] if requested else []
if requested:
    missing=set(requested)-{c.name for c in bpy.data.collections if c.get('ct_asset')}
    if missing: raise RuntimeError('Unknown asset collections: '+str(missing))
preview_nodes={mat.name:mat.use_nodes for mat in bpy.data.materials}
for mat in bpy.data.materials: mat.use_nodes=False
for col in bpy.data.collections:
    if not col.get('ct_asset'): continue
    if requested and col.name not in requested: continue
    origin=Vector(col['asset_origin']); objects=list(col.objects)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.location-=origin; o.select_set(True)
    if col.get('ct_vendor'):
        for obj in objects:
            if obj.type=='MESH':
                for mat in obj.data.materials: mat.use_nodes=preview_nodes.get(mat.name,True)
    try:
        bpy.ops.export_scene.gltf(filepath=str(out/(col.name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_cameras=False,export_lights=False,export_materials='EXPORT')
    finally:
        for o in objects: o.location+=origin
    # Named scalar slots; the master file is never saved with preview nodes disabled.
    manifest.append({'name':col.name,'file':col.name+'.glb','triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects if o.type=='MESH'),'meshes':len(objects),'vendor':bool(col.get('ct_vendor',False))})
if requested: manifest=[item for item in old_manifest if item['name'] not in requested]+manifest
manifest.sort(key=lambda item:item['name'])
(out.parent/'model-manifest.json').write_text(json.dumps({'source':str(source.relative_to(ROOT)).replace('\\','/'),'exporter':'tools/export_story_models.py','models':manifest},indent=2),encoding='utf-8')
print('EXPORTED_MODELS',len(manifest))
