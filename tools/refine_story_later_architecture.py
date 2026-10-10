"""Add service silhouettes and five distinct secondary dungeon centrepieces.
Run once on the new master; never rebuild the opening library.
"""
import bpy,pathlib,math,random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/acts-2-6-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
if bpy.context.scene.get('ct_service_silhouettes'): raise RuntimeError('Already refined; edit the master.')
MATS={m.name:m for m in bpy.data.materials}
code=(ROOT/'tools/build_story_models.py').read_text(encoding='utf8')
exec(code[code.index('collection = None'):code.index('for role in range(6): building(role)')])
def theme(a):
 for slot,suffix in [('Masonry','Stone'),('Trim','Stone'),('Rock','Ground')]: MATS[slot]=bpy.data.materials[f'A{a}{suffix}']
 MATS['Timber']=bpy.data.materials['CraftWood']; MATS['Slate']=bpy.data.materials['CraftMetal']; MATS['Iron']=bpy.data.materials['CraftMetal']
 cname=f'A{a}Crystal'
 if cname not in bpy.data.materials:
  m=bpy.data.materials.new(cname); m.diffuse_color={2:(.95,.35,.08,1),3:(.12,.58,.85,1),4:(.65,.18,.4,1),5:(.12,.60,.54,1),6:(.72,.045,.12,1)}[a]
 MATS['Glass']=bpy.data.materials[cname]
def join():
 for phase,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:
   obj.select_set(True); bpy.context.view_layer.objects.active=obj
   for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); bpy.context.object.name=phase
def circle(center,r,axis='d',mat='Iron',group='Body'):
 x,d,z=center
 for i in range(32):
  aa=i*math.tau/32; bb=(i+1)*math.tau/32
  def p(t): return (x+r*math.cos(t),d,z+r*math.sin(t)) if axis=='d' else (x+r*math.cos(t),d+r*math.sin(t),z)
  beam('Ring fitting',p(aa),p(bb),.035,mat,group)
for a in range(2,7):
 theme(a)
 for role in range(6):
  collection=bpy.data.collections[f'a{a}_service_{role}']
  origin=Vector(collection['asset_origin'])
  for o in collection.objects: o.location-=origin
  groups={o.name:[o] for o in collection.objects}
  h=1.8+.25*(role%3); w=2.6+.3*(role%3); depth=2+.3*(role%2)
  if role==0:
   beam('Octagonal guard turret',(-.42,-.30,h),(-.42,-.30,h+1.35),.35,'Masonry','Roof',sides=8)
   for i in range(8):
    t=i*math.tau/8
    box('Turret crown',(-.42+math.cos(t)*.30,-.30+math.sin(t)*.30,h+1.43),(.16,.16,.23),'Trim','Roof')
   beam('Watch pinnacle',(-.42,-.30,h+1.40),(-.42,-.30,h+2.2),.30,'Slate','Roof',end_radius=.01,sides=8)
  elif role==1:
   for x in [-.25,.25]: beam('Bell tower upright',(x,-.35,h+.2),(x,-.35,h+1.25),.06,'Masonry','Roof')
   arch(0,-.35,h+.95,.25,.065,.32,'Roof',a!=5)
   beam('Cast bell',(0,-.35,h+.88),(0,-.35,h+.58),.13,'Gold','Roof',end_radius=.22,sides=16)
   beam('Bell canopy',(0,-.35,h+1.18),(0,-.35,h+1.8),.35,'Slate','Roof',end_radius=.01,sides=8)
   for x in [-w*.35,w*.35]: beam('Clinic railing',(x,depth/2+.17,.9),(x,depth/2+.17,1.5),.026,'Gold','Front')
  elif role==2:
   box('Brick flue pedestal',(-.80,-.6,h+.55),(.4,.4,1.1),'Masonry','Roof')
   beam('Forging chimney',(-.80,-.6,h+.9),(-.80,-.6,h+1.8),.18,'Iron','Roof',sides=12)
   for z in [h+1.1,h+1.5,h+1.8]: circle((-.80,-.6,z),.21,'z','Iron','Roof')
   arch(-.65,-.42,.9,.22,.08,.25,'Body',False)
   box('Furnace embers',(-.65,-.43,.78),(.32,.32,.04),'Glass')
  elif role==3:
   box('Archive clerestory',(0,-.3,h+.48),(.82,.7,.96),'Masonry','Roof')
   window(0,.08,h+.58,.36,.58,'Roof')
   beam('Archive steep finial',(0,-.3,h+.94),(0,-.3,h+1.70),.54,'Slate','Roof',end_radius=.01,sides=4)
   for x in [-w/2-.08,w/2+.08]: beam('Archive buttress',(x,-.4,.2),(x*.85,-.4,h+.15),.08,'Masonry','Side')
  elif role==4:
   beam('Loading crane mast',(-.65,.15,h-.2),(-.65,.15,h+1.5),.085,'Timber','Roof')
   beam('Crane jib',(-.65,.15,h+1.42),(.7,depth/2+.5,h+1.15),.065,'Timber','Roof')
   beam('Jib tie',(-.65,.15,h+1.5),(.7,depth/2+.5,h+1.15),.02,'Iron','Roof')
   circle((.7,depth/2+.5,h+1.04),.10,'d','Iron','Roof')
   beam('Hoist rope',(.7,depth/2+.5,h+1.1),(.7,depth/2+.5,h+.05),.015,'Cloth','Roof')
  else:
   box('Tavern upper porch',(0,depth/2+.26,h-.12),(w*.70,.8,.10),'Timber','Roof')
   for x in [-w*.3,w*.3]: beam('Porch support',(x,depth/2+.56,h-.1),(x,depth/2+.56,h+.70),.05,'Timber','Roof')
   beam('Porch rail',(-w*.3,depth/2+.56,h+.4),(w*.3,depth/2+.56,h+.4),.04,'Timber','Roof')
   for i in range(7): beam('Porch baluster',(-w*.28+i*w*.56/6,depth/2+.56,h),( -w*.28+i*w*.56/6,depth/2+.56,h+.4),.022,'Iron','Roof')
   beam('Hanging pub sign',(w*.4,depth/2,h-.2),(w*.4,depth/2+.6,h-.2),.035,'Iron','Front')
   circle((w*.4,depth/2+.59,h-.55),.20,'d','Gold','Front')
  # Newly authored gutter and fastenings catch oblique light.
  for x in [-w/2,w/2]:
   beam('Rain gutter',(x,-depth/2,h),(x,depth/2,h),.032,'Iron','Roof')
   beam('Down pipe',(x,depth/2-.05,.08),(x,depth/2-.05,h),.025,'Iron','Side')
  join()
  for o in collection.objects: o.location+=origin
 for kind in ['secondary']:
  start_asset(f'a{a}_{kind}')
  if a in [2,5]:
   for x in [-.55,.55]:
    beam('Pump cylinder',(x,0,.18),(x,0,1.6),.30,'Iron',sides=20)
    for z in [.3,1.3]: circle((x,0,z),.33,'z')
    beam('Delivery pipe',(x,0,1.65),(x,.8,1.65),.10,'Iron')
   circle((0,.4,1.1),.58,'d','Gold')
   for i in range(6):
    t=i*math.tau/6; beam('Wheel spokes',(0,.4,1.1),(math.cos(t)*.55,.4,1.1+math.sin(t)*.55),.025,'Iron')
   box('Pump foundation',(0,0,.1),(2.1,1.8,.2),'Masonry')
  elif a==3:
   box('Ossuary base',(0,0,.14),(2.0,1.0,.28),'Masonry')
   for x in [-.68,.68]:
    beam('Tomb pilaster',(x,0,.15),(x,0,1.7),.12,'Masonry',sides=8)
    arch(x,0,1.6,.32,.1,.65,'Body')
    box('Ossuary inset',(x,-.20,1.2),(.45,.12,.7),'Dark')
    for i in range(5): beam('Bone bundles',(x-.16+i*.08,.05,.8),(x-.16+i*.08,.05,1.3),.026,'Paper')
   box('Carved coffin',(0,.75,.38),(1.55,.7,.48),'Masonry')
   for x in [-.65,.65]: box('Coffin shoulder',(x,.75,.38),(.18,.86,.52),'Trim')
  elif a==4:
   for x in [-.85,.85]: beam('Mask cabinet post',(x,0,0),(x,0,2.2),.06,'Timber')
   for z in [.45,1.25,2.05]:
    box('Mask shelf',(0,0,z),(1.9,.5,.07),'Timber')
    for x in [-.6,0,.6]:
     boulder('Porcelain mask',(x,.1,z+.25),(.30,.10,.39),a*700+int(z*11+x*10))
     groups['Body'][-1].data.materials[0]=MATS['Paper']
     for dx in [-.065,.065]: box('Mask eye slit',(x+dx,.168,z+.28),(.05,.013,.03),'Dark',bevel=0)
  else:
   for z,r in [(.3,1.35),(.45,1.1),(1.7,.95)]: circle((0,0,z),r,'z','Gold')
   for i in range(8):
    t=i*math.tau/8; x=math.cos(t)*1.1; d=math.sin(t)*1.1
    beam('Astral spoke',(0,0,.35),(x,d,.35),.025,'Gold')
    beam('Red shard mirror',(x,d,.5),(x,d,1.6),.16,'Glass',end_radius=.01,sides=6)
   beam('Ritual needle',(0,0,0),(0,0,2.5),.05,'Gold')
  join()
  origin=Vector((a*9,120,0))
  for o in collection.objects: o.location+=origin
  collection['ct_asset']=True; collection['asset_origin']=list(origin)
bpy.context.scene['ct_service_silhouettes']=1
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('REFINED_LATER_SERVICE_SILHOUETTES_AND_SECONDARY',35)
