"""Separate new wooden/metal construction from regional stone floor slots."""
import bpy,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=ROOT/'art/story-environment/acts-2-6-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(p))
for name,color in [('CraftWood',(.28,.22,.16,1)),('CraftMetal',(.19,.26,.29,1))]:
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.diffuse_color=color
for c in bpy.data.collections:
 if not c.get('ct_asset'): continue
 a=int(c.name[1])
 for o in c.objects:
  if o.type!='MESH': continue
  for slot in o.material_slots:
   if slot.material.name==f'A{a}Floor': slot.material=bpy.data.materials['CraftWood' if o.name!='Roof' or a in [3,5] else 'CraftMetal' if a in [2,4] else f'A{a}Stone']
   elif slot.material.name=='Iron': slot.material=bpy.data.materials['CraftMetal']
bpy.context.scene['ct_construction_slots']=1
bpy.ops.wm.save_as_mainfile(filepath=str(p))
