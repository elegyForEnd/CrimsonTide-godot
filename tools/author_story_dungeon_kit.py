"""Create an original dungeon detail kit in a separate editable Blender master.
Existing sources/exports are never rebuilt. Reopen this master for later edits.
"""
import bpy,pathlib,math,random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/dungeon-master.blend'
if source.exists(): raise RuntimeError('Dungeon master exists; edit the source instead.')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
MATS={}
colors={'Masonry':(.30,.31,.29,1),'Trim':(.40,.41,.38,1),'Timber':(.18,.12,.07,1),'Iron':(.09,.11,.13,1),'Gold':(.45,.28,.08,1),'Glass':(.8,.37,.08,1),'Cloth':(.29,.06,.09,1),'Paper':(.66,.60,.43,1),'Rock':(.27,.28,.28,1),'Dark':(.025,.03,.04,1),'Slate':(.15,.19,.23,1)}
for a in range(2,7): colors[f'A{a}Stone']=[(.31,.20,.16,1),(.35,.40,.45,1),(.34,.36,.31,1),(.34,.35,.29,1),(.47,.45,.42,1)][a-2]
for name,color in colors.items():
 m=bpy.data.materials.new(name); m.diffuse_color=color; m.use_nodes=True
 m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color; MATS[name]=m
code=(ROOT/'tools/build_story_models.py').read_text(encoding='utf8')
exec(code[code.index('collection = None'):code.index('for role in range(6): building(role)')])
asset_count=0
def finish():
 global asset_count
 for phase,objects in groups.items():
  if not objects: continue
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:
   obj.select_set(True); bpy.context.view_layer.objects.active=obj
   for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); bpy.context.object.name=phase
 origin=Vector((asset_count%8*7,asset_count//8*7,0))
 for obj in collection.objects: obj.location+=origin
 collection['ct_asset']=True; collection['asset_origin']=list(origin); asset_count+=1
for a in range(1,7):
 stone='Masonry' if a==1 else f'A{a}Stone'; MATS['Trim']=MATS[stone]
 start_asset(f'd{a}_pier')
 # Stepped base, chamfered body, plinth, capital and theme-specific ribs.
 beam('Octagonal foundation',(0,0,-.16),(0,0,.16),.52,stone,sides=8)
 beam('Lower moulding',(0,0,.16),(0,0,.32),.43,stone,sides=8)
 beam('Pier shaft',(0,0,.32),(0,0,2.9),.31,stone,sides=8)
 for z,r in [(2.85,.38),(3,.46),(3.13,.52)]: beam('Capital moulding',(0,0,z),(0,0,z+.10),r,stone,sides=8)
 for i in range(4):
  t=i*math.tau/4; x,d=math.cos(t)*.30,math.sin(t)*.30
  beam('Pier rib',(x,d,.35),(x,d,2.90),.075,'Iron' if a in [2,5] else stone,sides=8)
 if a==3:
  for i in range(4): box('Miner band',(0,0,.6+i*.6),(.7,.7,.05),'Iron')
 if a==4: arch(0,.31,1.4,.22,.06,.04,'Body')
 if a==6: beam('Votive finial',(0,0,3.2),(0,0,3.8),.18,'Gold',end_radius=.02,sides=8)
 finish()
 start_asset(f'd{a}_niche')
 box('Niche footing',(0,0,.1),(1.75,.70,.2),stone)
 for x in [-.71,.71]: box('Niche jamb',(x,0,.9),(.24,.55,1.6),stone)
 box('Niche recess',(0,-.23,1.1),(1.2,.08,1.95),'Dark')
 arch(0,0,1.55,.60,.17,.5,'Body',pointed=a not in [2,5])
 if a in [1,3,6]:
  box('Resting casket',(0,.13,.47),(.98,.45,.35),stone)
  for i in range(3): beam('Candle',(i*.18-.18,.13,.68),(i*.18-.18,.13,.83),.035,'Paper')
 elif a==2:
  for z in [.5,.95,1.4]: box('Valve cabinet shelf',(0,0,z),(1.15,.44,.07),'Iron')
  for x in [-.36,0,.36]: beam('Boiler fittings',(x,0,.55),(x,0,1.38),.065,'Iron')
 elif a==4:
  for i in range(3): beam('Displayed mask',(i*.32-.32,.05,.75),(i*.32-.32,.05,1.1),.12,'Paper',sides=12)
 else:
  for z in [.6,1,1.4]: box('Marine locker shelf',(0,.1,z),(1.16,.5,.08),'Timber')
  for x in [-.35,.35]: beam('Stored rope',(x,0,.55),(x,0,1.6),.065,'Cloth')
 finish()
 start_asset(f'd{a}_portal')
 for x in [-2.0,2.0]:
  box('Door footing',(x,0,.14),(.85,.95,.28),stone)
  box('Deep jamb',(x,0,1.42),(.46,.7,2.55),stone)
  for z in [.5,1.5,2.65]: box('Jamb collar',(x,0,z),(.58,.84,.15),stone)
 arch(0,0,2.55,1.77,.28,.70,'Body',pointed=a not in [2,5])
 for x in [-2.0,2.0]: lantern(x,.48,2.3,'Body')
 finish()
 start_asset(f'd{a}_retainer')
 # A structural foundation/drain edge, not a floating platform.
 for j in range(6):
  box('Foundation coursed stone',(-1.25+j*.5,0,-.24),(.48,.5,.48),stone)
  box('Coping stone',(-1.25+j*.5,0,.08),(.50,.65,.14),stone)
 for x in [-1.3,1.3]: box('Retaining buttress',(x,-.12,-.35),(.22,.8,.75),stone)
 finish()
MATS['Trim']=MATS['Masonry']
for kind in ['rubble','ossuary','storage','workbench','fallen_pier','grate','chain_lamp','rail','relief','roots']:
 start_asset('dungeon_'+kind)
 if kind=='rubble':
  rng=random.Random(173)
  for i in range(15): boulder('Broken masonry',(rng.uniform(-.9,.9),rng.uniform(-.65,.65),rng.uniform(.1,.25)),(rng.uniform(.15,.5),rng.uniform(.12,.4),rng.uniform(.1,.3)),i+9)
 elif kind=='ossuary':
  box('Carved sarcophagus',(0,0,.45),(1.02,2.12,.64),'Masonry')
  box('Chamfered lid',(0,0,.83),(1.17,2.28,.18),'Trim')
  for x in [-.49,.49]:
   for d in [-.7,0,.7]: box('Relief panel',(x,d,.48),(.025,.47,.32),'Dark',bevel=.003)
  beam('Recumbent relief',(0,-.43,.99),(0,.63,.99),.18,'Masonry',sides=12)
  boulder('Carved face',(0,-.65,1.01),(.30,.26,.15),28)
 elif kind=='storage':
  for x,d,z in [(-.5,0,.35),(.5,0,.35),(-.5,0,1.05)]:
   box('Crate',(x,d,z),(.85,.74,.7),'Timber')
   for zz in [z-.24,z+.24]: box('Crate iron strap',(x,d-.39,zz),(.9,.035,.05),'Iron')
  for i in range(5): beam('Propped lumber',(.7+i*.12,.6,0),(.5+i*.12,.23,1.85),.05,'Timber')
 elif kind=='workbench':
  box('Worn work surface',(0,0,.86),(2.25,.95,.13),'Timber')
  for x in [-.85,.85]:
   for d in [-.3,.3]: beam('Leg',(x,d,0),(x,d,.8),.065,'Timber')
  box('Lower shelf',(0,0,.3),(1.9,.8,.07),'Timber')
  for i in range(5): box('Tools',(-.65+i*.25,.1,.96),(.14,.35,.045),'Iron')
  for x in [-.60,.15]: box('Plans',(x,-.15,.955),(.44,.5,.014),'Paper',bevel=0)
 elif kind=='fallen_pier':
  beam('Broken column',(-1.3,0,.3),(.8,0,.3),.30,'Masonry',sides=12)
  for x in [-1.2,0,.7]: beam('Broken bands',(x-.05,0,.3),(x+.05,0,.3),.38,'Trim',sides=12)
  for i in range(5): boulder('Column fragments',(i*.3-.5,.6,.13),(.28,.22,.20),i+33)
 elif kind=='grate':
  for x in [-.5,.5]: box('Drain frame',(x,0,.028),(.08,2,.055),'Iron')
  for i in range(18): box('Drain bar',(0,-.9+i*.10,.028),(1,.025,.055),'Iron',bevel=.003)
 elif kind=='chain_lamp':
  beam('Lamp stem',(0,0,0),(0,0,2.2),.045,'Iron')
  beam('Lamp base',(0,0,0),(0,0,.15),.27,'Iron',sides=8)
  for x in [-.34,.34]:
   beam('Bowed arm',(0,0,2.1),(x,0,2.28),.028,'Iron'); lantern(x,0,2,'Body')
 elif kind=='rail':
  for x in [-1.4,0,1.4]: beam('Balustrade post',(x,0,0),(x,0,.9),.045,'Iron')
  for z in [.25,.9]: beam('Cross rail',(-1.4,0,z),(1.4,0,z),.035,'Iron')
  for i in range(14): beam('Baluster',(-1.3+i*.2,0,.25),(-1.3+i*.2,0,.9),.022,'Iron')
 elif kind=='relief':
  box('Weathered relief slab',(0,0,1.15),(1.65,.22,2.3),'Masonry')
  arch(0,.13,1.35,.52,.11,.08,'Body')
  for x in [-.66,.66]: box('Relief frame',(x,.13,1.05),(.11,.1,1.7),'Trim')
  beam('Relief spear',(0,.17,.4),(0,.17,1.65),.038,'Gold')
 elif kind=='roots':
  rng=random.Random(15)
  for i in range(9):
   t=i*math.tau/9; x,d=math.cos(t),math.sin(t)
   beam('Root',(0,0,.65),(x*.5,d*.5,.13),.07,'Timber',end_radius=.035)
   beam('Root tip',(x*.5,d*.5,.13),(x*1.6,d*1.6,.02),.035,'Timber',end_radius=.008)
 finish()
bpy.context.scene['ct_dungeon_revision']=1
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('AUTHORED_DUNGEON_MODELS',asset_count)
