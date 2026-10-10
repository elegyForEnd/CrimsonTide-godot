"""One-time outdoor/castle additions to the editable master, never regenerate it."""
import bpy, pathlib, math, random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/opening-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
if bpy.context.scene.get('outdoor_castle_revision'):
    raise RuntimeError('Already authored. Edit collections in the master instead.')
MATS={m.name:m for m in bpy.data.materials}
code=(ROOT/'tools/build_story_models.py').read_text(encoding='utf-8')
exec(code[code.index('collection = None'):code.index('for role in range(6): building(role)')])

def close(index):
    for phase,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True); bpy.context.view_layer.objects.active=obj
            for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name=phase
    origin=Vector((index*8,-90,0))
    for obj in collection.objects: obj.location+=origin
    collection['ct_asset']=True; collection['asset_origin']=list(origin)

names=['drain_channel','road_shrine','broken_wagon','fallen_oak','strata_outcrop',
       'cave_stalactites','mine_support','castle_wall','castle_wall_broken',
       'castle_tower','castle_gateway','castle_buttress','castle_vault',
       'castle_banner','castle_throne','castle_fountain']
for index,name in enumerate(names):
    start_asset(name)
    if name=='drain_channel':
        for x in [-.22,.22]:
            for row in range(5): box('Channel dressed block',(x,-.8+row*.4,.08),(.12,.38,.16),'Masonry')
        for y in [-.6,.6]:
            for x in [-.12,0,.12]: box('Drain grate',(x,y,.08),(.025,.30,.025),'Iron',bevel=.003)
        box('Channel silt',(0,0,.015),(.30,2,.025),'Rock',bevel=0)
    elif name=='road_shrine':
        for z,w in [(.10,.70),(.23,.53),(.85,.36)]: box('Marker stone',(0,0,z),(w,.38,.20 if z<.3 else 1.1),'Masonry')
        box('Inset waymark',(0,.205,.85),(.21,.015,.47),'Dark',bevel=.004)
        for z in [.72,.83,.94]: box('Inscribed brass',(0,.22,z),(.12,.013,.016),'Gold',bevel=.002)
        arch(0,.10,1.25,.22,.08,.38,'Body'); lantern(.43,0,.92,'Body')
    elif name=='broken_wagon':
        for y in [-.62,-.30,.02,.34,.66]: box('Split bed plank',(.12 if y==.34 else 0,y,.50),(1.35 if y!=.34 else .9,.29,.075),'Timber')
        for x in [-.62,.62]:
            for y in [-.58,.58]: beam('Axle support',(x,y,.1),(x,y,.70),.045,'Timber')
            beam('Upper side rail',(x,-.6,.73),(x,.65,.73),.05,'Timber')
        for y in [-.50,.48]:
            beam('Axle',(-.87,y,.28),(.87,y,.28),.065,'Iron')
            for x in [-.86,.86]:
                for i in range(12):
                    a=i*math.tau/12; b=(i+1)*math.tau/12
                    beam('Wheel rim',(x,y+math.cos(a)*.28,.28+math.sin(a)*.28),(x,y+math.cos(b)*.28,.28+math.sin(b)*.28),.035,'Iron')
                    if i%2==0: beam('Wheel spoke',(x,y,.28),(x,y+math.cos(a)*.25,.28+math.sin(a)*.25),.023,'Timber')
        beam('Snapped drawbar',(.35,.6,.4),(.35,1.6,.1),.055,'Timber')
        for i in range(3): box('Spilled crate',(i*.35-.3,.15,.69),(.29,.33,.28),'Timber')
    elif name=='fallen_oak':
        beam('Bark trunk',(-1.9,0,.22),(1.9,.1,.30),.24,'Bark',end_radius=.14,sides=18)
        beam('Exposed heartwood',(-1.92,0,.22),(-1.89,0,.22),.205,'Timber',sides=18)
        for x,sgn in [(-.8,1),(.4,-1),(1.1,1)]:
            beam('Broken branch',(x,0,.25),(x+.4,sgn*.7,.6),.075,'Bark',end_radius=.025)
        for i in range(7): beam('Root fan',(-1.4,0,.26),(-1.7-i*.08,math.sin(i)*.6,.12),.045,'Bark',end_radius=.012)
    elif name=='strata_outcrop':
        for row in range(6):
            for j in range(3):
                boulder('Weathered strata',(j*.80-.80+row*.05,math.sin(row)*.12,row*.27+.12),(1.20,.90,.47),index*71+row*13+j)
        for j in range(5): boulder('Talus',(j*.45-1,.50,.12),(.38,.37,.30),j+771)
    elif name=='cave_stalactites':
        for j in range(9):
            x=(j%3-1)*.40; y=(j//3-1)*.36; h=.48+(j%4)*.16
            beam('Mineral pendant',(x,y,h),(x+.06,y,0),.16,'Rock',end_radius=.013,sides=9)
    elif name=='mine_support':
        for x in [-1.40,1.40]:
            box('Hewn post',(x,0,1.10),(.20,.24,2.2),'Timber')
            box('Stone foot',(x,0,.12),(.35,.36,.24),'Masonry')
            beam('Angled brace',(x,0,1.4),(x*.60,0,2.1),.09,'Timber')
            for z in [.45,1.3,1.9]: box('Iron joint',(x,.132,z),(.23,.022,.06),'Iron')
        box('Ceiling lintel',(0,0,2.2),(3.1,.28,.24),'Timber')
        lantern(-1.12,.04,1.65,'Body')
    elif name in ['castle_wall','castle_wall_broken']:
        for row in range(7):
            for j in range(6):
                if name.endswith('broken') and row>3 and j in [2,3]: continue
                box('Coursed ashlar',(-1.5+(j+.5)*.5,0,.20+row*.4),(.48,.42,.38),'Masonry',bevel=.025)
        for z in [.06,2.8]: box('Chamfered belt',(0,0,z),(3.08,.54,.12),'Trim')
        for x in [-1.23,-.43,.37,1.17]:
            if name.endswith('broken') and x<.5 and x>-.5: continue
            box('Crenellation',(x,0,3.10),(.43,.50,.52),'Trim')
        if name.endswith('broken'):
            for j in range(6): box('Fallen masonry',(-.65+j*.22,.6+math.sin(j)*.2,.14),(.35,.30,.25),'Masonry')
    elif name=='castle_tower':
        # Octagonal tower with corbel ring, parapet and slit windows.
        beam('Tower core',(0,0,0),(0,0,5.0),1.05,'Masonry',sides=8)
        for z in [.20,1.65,3.30,4.70]: beam('Stone belt',(0,0,z),(0,0,z+.16),1.12,'Trim',sides=8)
        for i in range(8):
            a=i*math.tau/8; x=math.cos(a)*1.04; y=math.sin(a)*1.04
            box('Tower merlon',(x,y,5.12),(.38,.38,.52),'Trim')
            beam('Corbel',(x*.94,y*.94,4.45),(x*1.1,y*1.1,4.78),.095,'Trim')
        window(0,1.055,2.9,.23,.95,'Body')
    elif name=='castle_gateway':
        for x in [-2.1,2.1]:
            for row in range(9): box('Gate pier ashlar',(x,0,.20+row*.40),(1.15,.85,.38),'Masonry')
            box('Gate pier belt',(x,0,3.7),(1.3,1,.18),'Trim')
        arch(0,0,2.3,1.5,.28,.88,'Body')
        for x in [-1.6,1.6]:
            beam('Portcullis runner',(x,.1,0),(x,.1,3.6),.055,'Iron')
            lantern(x,.6,1.6,'Body')
        # Raised gate teeth: passage remains visibly open.
        for x in [-1.3,-.95,-.6,-.25,.1,.45,.8,1.15]: beam('Raised gate bar',(x,0,3.1),(x,0,3.65),.024,'Iron')
    elif name=='castle_buttress':
        for z,w,d in [(.25,.85,1.15),(.95,.66,.90),(1.70,.48,.65),(2.4,.34,.42)]:
            box('Stepped buttress',(0,0,z),(w,d,.50 if z<.5 else .9),'Masonry')
        box('Buttress coping',(0,0,2.94),(.46,.54,.13),'Trim')
    elif name=='castle_vault':
        for x in [-2.20,2.20]:
            beam('Clustered pier',(x,0,0),(x,0,2.6),.14,'Masonry')
            for dx in [-.10,.10]: beam('Pier shaft',(x+dx,.10,0),(x+dx,.10,2.6),.055,'Trim')
            box('Pier plinth',(x,0,.10),(.45,.45,.20),'Trim')
        arch(0,0,2.6,2.20,.16,.30,'Body')
        for sign in [-1,1]: beam('Vault diagonal',(sign*2.2,0,2.6),(0,1.6,4.8),.09,'Trim')
    elif name=='castle_banner':
        beam('Banner rod',(-.65,0,2.5),(.65,0,2.5),.035,'Iron')
        for j in range(6):
            box('Pleated banner',(-.48+j*.19,math.sin(j)*.035,1.6),(.18,.03,1.75-j%2*.16),'Cloth',bevel=.004)
        box('Guard crest',(0,.09,1.8),(.25,.045,.38),'Gold')
    elif name=='castle_throne':
        box('Dais',(0,0,.12),(1.7,1.7,.24),'Trim')
        box('Seat',(0,0,.75),(.85,.65,.16),'Timber')
        box('Cushion',(0,0,.87),(.73,.54,.11),'Cloth')
        box('Carved back',(0,-.28,1.40),(.95,.15,1.75),'Timber')
        for x in [-.40,.40]:
            box('Throne arm',(x,.07,1.05),(.12,.65,.12),'Gold')
            beam('Throne leg',(x,.23,.25),(x,.23,.80),.075,'Timber')
        arch(0,-.2,2.18,.44,.10,.15,'Body')
    elif name=='castle_fountain':
        for i in range(16):
            a=i*math.tau/16; b=(i+1)*math.tau/16
            beam('Basin curb',(math.cos(a)*1.15,math.sin(a)*1.15,.30),(math.cos(b)*1.15,math.sin(b)*1.15,.30),.12,'Trim')
        beam('Fountain centre',(0,0,0),(0,0,1.50),.18,'Masonry',end_radius=.12)
        beam('Empty bowl',(0,0,1.15),(0,0,1.32),.50,'Trim')
    close(index)
bpy.context.scene['outdoor_castle_revision']=1
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('AUTHORED_OUTDOOR_CASTLE',','.join(names))
