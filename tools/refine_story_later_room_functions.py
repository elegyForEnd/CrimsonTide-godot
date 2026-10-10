"""Author specific archive, doll, glazing and beacon facilities for story rooms."""
import bpy,pathlib,math,random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]; source=ROOT/'art/story-environment/acts-2-6-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
if bpy.context.scene.get('ct_room_functions'): raise RuntimeError('Room facilities already authored.')
MATS={m.name:m for m in bpy.data.materials}
code=(ROOT/'tools/build_story_models.py').read_text(encoding='utf8')
exec(code[code.index('collection = None'):code.index('for role in range(6): building(role)')])
MATS['Timber']=MATS['CraftWood']; MATS['Iron']=MATS['CraftMetal']
for index,(a,kind) in enumerate([(2,'archive'),(4,'doll_station'),(5,'beacon'),(6,'scriptorium')]):
 MATS['Masonry']=bpy.data.materials[f'A{a}Stone']; MATS['Trim']=MATS['Masonry']; MATS['Glass']=bpy.data.materials[f'A{a}Crystal']
 MATS['Rock']=MATS['Masonry']
 start_asset(f'a{a}_{kind}')
 if kind=='archive':
  for x in [-1.05,1.05]: box('Archive cabinet side',(x,0,1.05),(.12,.62,2.1),'Timber')
  box('Cabinet back',(0,-.27,1.05),(2.2,.08,2.1),'Timber')
  for z in [.1,.62,1.14,1.66,2.18]:
   box('Archive shelf',(0,0,z),(2.2,.65,.07),'Timber')
   if z>2: continue
   for i in range(12):
    x=-.91+i*.165; height=.27+(i%3)*.05
    box('Bound repair folio',(x,.03,z+height*.5+.04),(.12,.36,height),'Cloth' if i%3==0 else 'Timber')
    box('Folio pages',(x,.19,z+height*.5+.04),(.085,.018,height*.85),'Paper',bevel=.003)
    for zz in [z+.10,z+height-.04]: box('Binder clasp',(x,.22,zz),(.05,.016,.018),'Gold',bevel=.002)
  box('Record examination desk',(0,.85,.77),(1.5,.65,.10),'Timber')
  for x in [-.55,.55]: beam('Desk trestle',(x,.85,0),(x,.85,.75),.055,'Timber')
  for i in range(4): box('Unbound plans',(-.4+i*.25,.85,.84+i*.008),(.35,.48,.012),'Paper',bevel=0)
 elif kind=='doll_station':
  for x in [-1.1,1.1]: beam('Tailoring frame',(x,0,0),(x,0,2.6),.055,'Iron')
  beam('Suspension beam',(-1.1,0,2.6),(1.1,0,2.6),.05,'Iron')
  for x in [-.60,.55]:
   beam('Suspension cord',(x,0,2.6),(x,0,1.95),.012,'Cloth')
   boulder('Porcelain doll torso',(x,0,1.4),(.40,.20,.55),a*91+int(x*100)); groups['Body'][-1].data.materials[0]=MATS['Paper']
   boulder('Porcelain doll head',(x,0,1.9),(.29,.23,.33),a*19+int(x*100)); groups['Body'][-1].data.materials[0]=MATS['Paper']
   for s in [-1,1]:
    beam('Doll upper arm',(x+s*.15,0,1.6),(x+s*.27,.02,1.35),.038,'Paper')
    beam('Doll forearm',(x+s*.27,.02,1.35),(x+s*.36,.07,1.18),.030,'Paper')
    beam('Doll thigh',(x+s*.09,0,1.2),(x+s*.11,.01,.84),.047,'Paper')
    beam('Doll calf',(x+s*.11,.01,.84),(x+s*.14,.04,.50),.035,'Paper')
  box('Tailoring bench',(0,.6,.65),(2.1,.62,.09),'Timber')
  for x in [-.8,.8]: beam('Tailoring bench leg',(x,.6,0),(x,.6,.65),.055,'Timber')
  for i in range(5): beam('Thread spool',(-.6+i*.30,.65,.71),(-.6+i*.30,.65,.86),.055,'Cloth',sides=12)
 elif kind=='scriptorium':
  box('Glazier work table',(0,0,.86),(2.3,1.2,.12),'Timber')
  for x in [-.9,.9]:
   for d in [-.4,.4]: beam('Worktable leg',(x,d,0),(x,d,.82),.065,'Timber')
  for i in range(8):
   x=-.85+(i%4)*.55; d=-.3+(i//4)*.5
   mesh('Cut stained glass shard',[(x,d,.94),(x+.35,d,.94),(x+.2,d+.32,.94),(x,d,.96),(x+.35,d,.96),(x+.2,d+.32,.96)],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'Glass',bevel=.003)
  for x in [-1,1]: beam('Frame storage upright',(x,-.7,0),(x,-.7,2.1),.065,'Iron')
  arch(0,-.7,1.4,1,.08,.13,'Body')
  for i in range(5): beam('Leading frame',(-.8+i*.4,-.7,1),(-.8+i*.4,-.7,2),.017,'Gold')
  for i in range(3): box('Rolled design',(-.6+i*.5,.15,.98),(.35,.28,.016),'Paper',bevel=0)
 else:
  beam('Octagonal beacon base',(0,0,0),(0,0,.55),.80,'Masonry',sides=8)
  beam('Beacon stem',(0,0,.55),(0,0,2.1),.35,'Masonry',sides=12)
  for i in range(8):
   t=i*math.tau/8
   beam('Beacon lantern cage',(math.cos(t)*.6,math.sin(t)*.6,2),(math.cos(t)*.6,math.sin(t)*.6,3.1),.035,'Iron')
  beam('Lantern crystal',(0,0,2.1),(0,0,3),.30,'Glass',end_radius=.12,sides=8)
  beam('Lantern roof',(0,0,3.05),(0,0,3.7),.72,'Iron',end_radius=.02,sides=8)
 for phase,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:
   o.select_set(True); bpy.context.view_layer.objects.active=o
   for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); bpy.context.object.name=phase
 origin=Vector((index*9,145,0))
 for o in collection.objects: o.location+=origin
 collection['ct_asset']=True; collection['asset_origin']=list(origin)
bpy.context.scene['ct_room_functions']=1; bpy.ops.wm.save_as_mainfile(filepath=str(source))
