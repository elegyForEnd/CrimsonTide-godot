"""Author five original regional kits in a separate editable Blender master.

Construction helpers are shared code, never meshes from the opening collection.
This initial authoring script refuses to overwrite the master. After creation,
edit the blend collections and use export_story_models.py --source=... only.
"""
import bpy, pathlib, math, random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/story-environment/acts-2-6-master.blend'
if SOURCE.exists(): raise RuntimeError('Master exists: edit it, do not regenerate it.')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
MATS={}
for name,color in {'Masonry':(.42,.40,.35,1),'Trim':(.66,.60,.44,1),
 'Timber':(.27,.20,.13,1),'Rock':(.35,.38,.42,1),'Slate':(.16,.24,.29,1),
 'Iron':(.18,.22,.25,1),'Gold':(.58,.40,.15,1),'Glass':(.65,.40,.15,1),
 'Dark':(.025,.04,.055,1),'Cloth':(.28,.04,.09,1),'Leaf':(.12,.24,.11,1),
 'Bark':(.29,.25,.20,1),'Paper':(.65,.57,.4,1)}.items():
 m=bpy.data.materials.new(name); m.diffuse_color=color; MATS[name]=m
for act,color in {2:(.41,.27,.20,1),3:(.43,.50,.56,1),4:(.49,.48,.36,1),5:(.44,.50,.46,1),6:(.69,.66,.58,1)}.items():
 for suffix in ['Stone','Ground','Floor']:
  m=bpy.data.materials.new(f'A{act}{suffix}'); m.diffuse_color=color; MATS[m.name]=m
code=(ROOT/'tools/build_story_models.py').read_text(encoding='utf8')
exec(code[code.index('collection = None'):code.index('for role in range(6): building(role)')])
# Alias the helper's structural slots to each region's brand-new PBR material.
def theme(a):
 for slot,suffix in [('Masonry','Stone'),('Trim','Stone'),('Rock','Ground'),('Timber','Floor'),('Slate','Floor')]: MATS[slot]=bpy.data.materials[f'A{a}{suffix}']
def finish(index):
 for phase,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:
   obj.select_set(True); bpy.context.view_layer.objects.active=obj
   for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
  bpy.context.object.name=phase
 origin=Vector((index%10*9,index//10*12,0))
 for obj in collection.objects: obj.location+=origin
 collection['ct_asset']=True; collection['asset_origin']=list(origin)
 collection['authoring']='Original acts 2-6, metres, door centred on +depth'
def ring(name,center,radius,material='Iron',group='Body',axis='z',width=.035,n=32):
 x,d,z=center
 for i in range(n):
  a=i*math.tau/n; b=(i+1)*math.tau/n
  def p(t):
   if axis=='z': return (x+radius*math.cos(t),d+radius*math.sin(t),z)
   if axis=='x': return (x,d+radius*math.cos(t),z+radius*math.sin(t))
   return (x+radius*math.cos(t),d,z+radius*math.sin(t))
  beam(name,p(a),p(b),width,material,group,sides=8)
def ribs(width,depth,height,group='Roof',material='Iron'):
 for d in [-depth/2,0,depth/2]:
  for i in range(16):
   a=i*math.pi/16; b=(i+1)*math.pi/16
   beam('Curved rib',(width/2*math.cos(a),d,height+width/2*math.sin(a)),(width/2*math.cos(b),d,height+width/2*math.sin(b)),.045,material,group)
def service(a,role):
 # The same 1.1m doorway contract supports every service; geometry is new.
 w=2.60+.30*(role%3); depth=2.0+.30*(role%2); h=1.80+.25*(role%3)
 box('Interior single floor',(0,0,.03),(w,depth,.06),'Timber')
 box('Rear wall',(0,-depth/2+.14,h/2),(w,.28,h),'Masonry')
 for x in [-w/2+.14,w/2-.14]: box('Side wall',(x,0,h/2),(.28,depth,h),'Masonry','Side')
 for s in [-1,1]:
  ww=w/2-.55
  box('Door side',(s*(.55+ww/2),depth/2-.14,h/2),(ww,.28,h),'Masonry','Front')
 arch(0,depth/2-.10,1.55,.55,.085,.28,'Front',pointed=a!=5)
 # Door head is an actual solid; front group can fade independently.
 box('Door lintel',(0,depth/2-.14,h-.12),(1.10,.28,.24),'Masonry','Front')
 for x in [-w*.34,w*.34]: window(x,depth/2+.01,1.15,.23,.50,'Front')
 lantern(w/2-.27,depth/2+.08,1.15,'Front')
 if a==2:
  # Brick mansard / workshop sawtooth instead of the first act gable.
  for row in range(5):
   zz=h+row*.16; ww=w+.32-row*.24
   box('Stepped mansard tile',(0,0,zz),(ww,depth+.28,.17),'Slate','Roof')
  for x in [-w*.36,w*.36]: box('Stone pilaster',(x,depth/2+.035,h/2),(.14,.14,h+.15),'Trim','Front')
  if role==2:
   box('Smokestack',(-w*.31,-depth*.25,h+.82),(.38,.4,1.5),'Masonry','Roof')
   for z in [h+.2,h+.65,h+1.1]: ring('Stack collar',(-w*.31,-depth*.25,z),.28,'Iron','Roof')
  elif role in [0,3]: ring('Mechanical clock',(0,depth/2+.14,h+.35),.24,'Gold','Roof',axis='d')
 elif a==3:
  # Steep timber trusses, deep eaves, separate snow ledges.
  roof(w,depth,h,1.25,'Roof')
  for d in [-depth/2,depth/2]:
   for s in [-1,1]: beam('Raised verge',(s*(w/2+.2),d,h),(0,d,h+1.28),.08,'Timber','Roof')
  for x in [-w/2+.15,w/2-.15]: beam('Splayed mountain brace',(x,depth/2+.08,.25),(x*.65,depth/2+.08,h),.06,'Timber','Front')
  if role==0: beam('Watch mast',(0,-depth*.25,h+1),(0,-depth*.25,h+2.1),.07,'Timber','Roof')
 elif a==4:
  # Garden villas: curved iron canopies, turret roof and rose tracery.
  ribs(w+.28,depth+.22,h,'Roof')
  for i in range(10):
   a0=i*math.pi/10; a1=(i+1)*math.pi/10
   beam('Canopy roof slat',((w+.28)/2*math.cos(a0),-depth/2,h+(w+.28)/2*math.sin(a0)),((w+.28)/2*math.cos(a1),depth/2,h+(w+.28)/2*math.sin(a1)),.085,'Slate','Roof')
  for x in [-w*.36,w*.36]: ring('Rose window',(x,depth/2+.07,1.35),.20,'Gold','Front',axis='d')
  if role in [0,3]: beam('Garden finial',(0,0,h+1.3),(0,0,h+1.85),.075,'Gold','Roof',end_radius=.015)
 elif a==5:
  # Shipwright architecture: shingled barrel roofs, ribs and nautical fittings.
  ribs(w+.32,depth+.25,h,'Roof','Timber')
  for i in range(18):
   ang=(i+.5)*math.pi/18
   box('Hull roof plank',((w+.32)/2*math.cos(ang),0,h+(w+.32)/2*math.sin(ang)),(.15,depth+.28,.11),'Timber','Roof')
  for x in [-w*.37,w*.37]: beam('Mooring column',(x,depth/2+.15,0),(x,depth/2+.15,h+.12),.09,'Timber','Front')
  ring('Nautical sign',(0,depth/2+.24,h+.12),.22,'Gold','Roof',axis='d')
 else:
  # Pale stone pavilions with flying buttresses and needle spires.
  for x in [-w/2-.08,w/2+.08]:
   beam('Flying buttress',(x*1.15,0,.2),(x*.90,0,h),.13,'Trim','Side')
  roof(w,depth,h,1.15,'Roof')
  for x in [-w*.34,w*.34]: beam('Needle pinnacle',(x,0,h),(x,0,h+1.5),.16,'Trim','Roof',end_radius=.012)
  ring('Rose oculus',(0,depth/2+.08,h+.4),.24,'Gold','Roof',axis='d')
 # Role-specific interiors, not a single table in every building.
 if role==2:
  box('Workshop bench',(-.65,-.35,.70),(.85,.55,.12),'Timber'); beam('Anvil horn',(-.90,-.35,.83),(-.3,-.35,.83),.08,'Iron')
 elif role==3:
  for z in [.4,.8,1.2]:
   box('Archive shelf',(0,-depth/2+.35,z),(1.6,.28,.06),'Timber')
   for i in range(9): box('Archive folio',(-.7+i*.17,-depth/2+.35,z+.15),(.11,.20,.25),'Paper')
 elif role==1:
  for x in [-.65,.65]:
   box('Patient cot',(x,-.35,.40),(.50,1.0,.16),'Timber'); box('Bedding',(x,-.35,.50),(.46,.90,.08),'Cloth')
 elif role==4:
  for x in [-.65,.65]: box('Store bins',(x,-.50,.35),(.55,.65,.7),'Timber')
 else:
  box('Service desk',(-.6,-.25,.68),(.65,.65,.08),'Timber')
  for x in [-.82,-.38]: beam('Desk legs',(x,-.25,0),(x,-.25,.66),.04,'Timber')
def module(a,kind):
 if kind in ['wall','wall_broken']:
  for z in range(6):
   for i in range(6):
    if kind=='wall_broken' and z>2 and i in [2,3,4]: continue
    box('Regional block',(-1.25+i*.5+(z%2)*.025,0,.20+z*.40),(.48,.34,.38),'Masonry')
  box('Cornice',(0,0,2.48),(3.1,.46,.16),'Trim')
  if kind=='wall_broken':
   for i in range(6): boulder('Collapsed stone',(-.8+i*.28,.52,.13),(.38,.43,.26),a*100+i)
  elif a==2:
   for x in [-1.2,0,1.2]: beam('Rivet pipe',(x,.21,.25),(x,.21,2.25),.035,'Iron')
  elif a in [4,6]:
   for x in [-1,0,1]: arch(x,.21,1.05,.35,.08,.14,'Body')
  elif a==5:
   for x in [-1.2,0,1.2]: beam('Timber seawall brace',(x,.25,.1),(x+.3,.25,2.4),.085,'Timber')
 elif kind=='gate':
  for x in [-1.7,1.7]:
   for z in range(7): box('Portal pier',(x,0,.2+z*.4),(.65,.60,.38),'Masonry')
  arch(0,0,1.8,1.4,.20,.50,'Body',pointed=a not in [3,5]); lantern(-1.6,.36,1.35,'Body'); lantern(1.6,.36,1.35,'Body')
  if a==2: beam('Workshop duct',(-1.7,0,2.8),(1.7,0,2.8),.12,'Iron')
  if a==3: beam('Mountain gate lintel',(-1.8,0,2.8),(1.8,0,2.8),.13,'Timber')
 elif kind=='tree':
  if a==3:
   beam('Pine trunk',(0,0,0),(0,0,3.4),.16,'Bark',end_radius=.03)
   for row in range(7):
    z=.8+row*.34; r=1.05-row*.13
    for i in range(7):
     t=i*math.tau/7+row*.3
     beam('Evergreen bough',(0,0,z+.35),(r*math.cos(t),r*math.sin(t),z),.10,'Leaf',end_radius=.03)
  elif a==4:
   beam('Topiary stem',(0,0,0),(0,0,2.3),.075,'Bark')
   for z,r in [(1.1,.72),(1.9,.56),(2.6,.35)]:
    # Closed sculpted leaf volumes, not alpha planes.
    boulder('Clipped crown',(0,0,z),(r*2,r*2,r*1.6),a*71+int(z*10))
    groups['Body'][-1].data.materials[0]=MATS['Leaf']
  else:
   beam('Weathered trunk',(0,0,0),(.12,0,2.7),.14,'Bark',end_radius=.035)
   for i in range(7):
    t=i*2.39; z=.9+i*.22
    beam('Gnarled branch',(.05,0,z),(math.cos(t)*.8,math.sin(t)*.8,z+.60),.065,'Bark',end_radius=.012)
 elif kind=='rock':
  for i in range(7): boulder('Regional outcrop',((i%3-1)*.52,(i//3-1)*.30,.3+(i%3)*.20),(.95,.80,.95),a*199+i)
 elif kind=='arch':
  for x in [-1.50,1.50]:
   beam('Gallery pier',(x,0,0),(x,0,2.5),.13,'Masonry',sides=12); box('Pier base',(x,0,.12),(.48,.48,.24),'Trim')
  arch(0,0,2.3,1.50,.16,.30,'Body',pointed=a not in [3,5])
 elif a==2:
  if kind=='hero':
   # Furnace with a recessed mouth, hood, flue and charge chute.
   for x in [-.9,.9]: box('Furnace jamb',(x,0,1.05),(.5,1.15,2.1),'Masonry')
   arch(0,.6,1.05,.62,.15,.35,'Body',False)
   box('Fire recess',(0,-.5,.65),(1.2,.08,1.2),'Dark'); box('Ember bed',(0,-.25,.16),(1.2,.85,.10),'Glass')
   box('Furnace hood',(0,0,2.15),(2.45,1.35,.4),'Iron'); beam('Flue',(0,0,2.3),(0,0,4),.3,'Iron')
   for z in [2.6,3.2,3.8]: ring('Flue collar',(0,0,z),.33,'Iron')
  elif kind=='prop':
   for x in [-.7,.7]: beam('Press frame',(x,0,0),(x,0,2),.10,'Iron')
   box('Press top',(0,0,2),(1.7,.7,.2),'Iron'); beam('Screw',(0,0,1),(0,0,2.5),.06,'Iron')
   ring('Press handwheel',(0,0,2.5),.45,'Iron'); box('Pressed dies',(0,0,.8),(1.1,.7,.18),'Iron')
  else:
   for i in range(12):
    t=i*math.tau/12; beam('Waterwheel paddle',(math.cos(t)*1.2,-.3,1.2+math.sin(t)*1.2),(math.cos(t)*1.2,.3,1.2+math.sin(t)*1.2),.10,'Timber')
   for d in [-.32,.32]: ring('Wheel rim',(0,d,1.2),1.1,'Iron',axis='d',width=.07)
 elif a==3:
  if kind=='hero':
   box('Observatory footing',(0,0,.16),(2.8,2.8,.32),'Masonry')
   for axis in ['z','x','d']: ring('Astronomical armillary',(0,0,1.8),1.1,'Gold',axis=axis,width=.035)
   for x in [-.7,.7]: beam('Telescope fork',(x,0,.3),(x,0,1.9),.08,'Iron')
   beam('Telescope tube',(-.7,-.7,1.1),(.7,.7,2.4),.23,'Iron',end_radius=.30,sides=24)
  elif kind=='prop':
   for x in [-.8,.8]: beam('Hoist post',(x,0,0),(x,0,2.4),.12,'Timber')
   beam('Hoist axle',(-.9,0,2.35),(.9,0,2.35),.09,'Iron'); ring('Hoist pulley',(0,0,2.3),.35,'Iron',axis='d')
   for x in [-.08,.08]: beam('Hoist rope',(x,0,0),(x,0,2.5),.02,'Cloth')
   box('Lift basket',(0,0,.4),(1.1,.8,.2),'Timber')
  else:
   for i in range(7):
    t=i*2.4; beam('Mineral shard',(math.cos(t)*.5,math.sin(t)*.5,0),(math.cos(t)*.6,math.sin(t)*.6,.7+i*.16),.12,'Glass',end_radius=.012,sides=6)
 elif a==4:
  if kind=='hero':
   # Freestanding conservatory frame with real, open arches.
   ribs(3.4,2.8,1.7,'Body')
   for x in [-1.7,1.7]:
    for d in [-1.4,0,1.4]: beam('Greenhouse upright',(x,d,0),(x,d,1.75),.04,'Iron')
   for z in [.5,1.2,1.7]:
    for x in [-1.7,1.7]: beam('Lattice rails',(x,-1.4,z),(x,1.4,z),.025,'Gold')
   for x in [-.9,.9]: box('Growing bed',(x,0,.25),(.65,2.2,.5),'Masonry')
  elif kind=='prop':
   for x in [-.85,.85]: beam('Rose trellis post',(x,0,0),(x,0,2.2),.05,'Iron')
   for z in [.3,.8,1.3,1.8]: beam('Trellis crossbar',(-.9,0,z),(.9,0,z),.025,'Iron')
   for i in range(12):
    t=i*.9; x=math.sin(t)*.7; z=.15+i*.15
    beam('Rose climbing stem',(x,0,z),(math.sin(t+.9)*.7,0,z+.15),.02,'Bark')
    ring('Sculpted rose',(x,.05,z+.1),.055,'Cloth',axis='d',width=.02,n=7)
  else:
   box('Pipe organ cabinet',(0,0,1),(1.7,.8,2),'Timber')
   for i in range(11):
    h=1.2+abs(i-5)*.18
    beam('Organ pipe',(-.75+i*.15,.45,.6),(-.75+i*.15,.45,h+1),.047,'Gold')
   for i in range(13): box('Organ key',(-.6+i*.095,.58,.78),(.08,.20,.02),'Paper')
 elif a==5:
  if kind=='hero':
   # Actual keel and curved ribbed open hull, 5m long; dry dock hero piece.
   beam('Keel',(0,-2.5,.3),(0,2.5,.3),.12,'Timber')
   for row in range(9):
    d=-2.2+row*.55; radius=1.0*(1-(abs(d)/3)**2)
    for i in range(12):
     a0=i*math.pi/12; a1=(i+1)*math.pi/12
     beam('Hull rib',(radius*math.cos(a0),d,1.5-radius*math.sin(a0)),(radius*math.cos(a1),d,1.5-radius*math.sin(a1)),.055,'Timber')
   for s in [-1,1]: beam('Gunwale',(s*.5,-2.5,1.5),(s*.5,2.5,1.5),.10,'Timber')
  elif kind=='prop':
   beam('Capstan drum',(0,0,.12),(0,0,1.2),.3,'Timber',sides=16)
   for z in [.18,.9]: ring('Capstan iron band',(0,0,z),.32,'Iron')
   for t in [0,math.pi/2]: beam('Turning arm',(-math.cos(t)*1,-math.sin(t)*1,1.1),(math.cos(t),math.sin(t),1.1),.05,'Timber')
  else:
   beam('Anchor shank',(0,0,0),(0,0,1.8),.075,'Iron')
   ring('Anchor eye',(0,0,1.9),.15,'Iron',axis='d'); beam('Anchor stock',(-.8,0,1.4),(.8,0,1.4),.09,'Timber')
   for s in [-1,1]: beam('Anchor fluke',(0,0,.05),(s*.75,0,.48),.1,'Iron',end_radius=.04)
 else:
  if kind=='hero':
   box('Reliquary plinth',(0,0,.18),(2,2,.36),'Masonry')
   for x in [-.6,.6]:
    for d in [-.6,.6]: beam('Relic canopy column',(x,d,.3),(x,d,2.7),.08,'Gold')
   for d in [-.6,.6]: arch(0,d,2.2,.6,.08,.18,'Body')
   box('Glass casket',(0,0,1),(.9,.7,.6),'Dark'); beam('Red relic',(0,0,.8),(0,0,1.6),.18,'Glass',end_radius=.015,sides=6)
   for x in [-.6,.6]: beam('Reliquary pinnacle',(x,0,2.4),(x,0,3.5),.1,'Masonry',end_radius=.01)
  elif kind=='prop':
   box('Ritual base',(0,0,.16),(1.4,1.4,.32),'Masonry')
   for axis in ['x','d','z']: ring('Blood armillary',(0,0,1.8),.88,'Gold',axis=axis,width=.035)
   beam('Crystal heart',(0,0,1.2),(0,0,2.5),.22,'Glass',end_radius=.01,sides=6)
  else:
   for x in [-.6,.6]:
    for z in [.3,1.1,1.9]:
     arch(x,0,z,.25,.06,.32,'Body'); box('Votive niche',(x,-.2,z+.1),(.4,.06,.4),'Dark'); lantern(x,.20,z+.05,'Body')
index=0
for a in range(2,7):
 theme(a)
 for role in range(6):
  start_asset(f'a{a}_service_{role}'); service(a,role); finish(index); index+=1
 for kind in ['wall','wall_broken','gate','tree','rock','arch','hero','prop','detail']:
  start_asset(f'a{a}_{kind}'); module(a,kind); finish(index); index+=1
bpy.context.scene['ct_later_acts_revision']=1
bpy.context.scene['ct_units']='metres / Godot export Y up'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
print('AUTHORED_LATER_ACTS',index)
