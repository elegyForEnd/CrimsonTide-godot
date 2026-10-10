"""Merge every service fade phase after additive authoring; preserve geometry."""
import bpy,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]; p=ROOT/'art/story-environment/acts-2-6-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(p))
for c in bpy.data.collections:
 if not c.get('ct_asset'): continue
 a=int(c.name[1])
 for o in c.objects:
  for slot in o.material_slots:
   if slot.material.name=='Glass': slot.material=bpy.data.materials[f'A{a}Crystal']
 groups={}
 for o in c.objects: groups.setdefault(o.name.split('.')[0],[]).append(o)
 for phase,objects in groups.items():
  if len(objects)<2: continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects: o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); bpy.context.object.name=phase
bpy.ops.wm.save_as_mainfile(filepath=str(p))
