"""Add authored workplace furniture once; preserve existing master/artist edits."""
import bpy, bmesh, pathlib, math, random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/opening-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
if bpy.context.scene.get('workplace_revision'):
    raise RuntimeError('Workplaces already authored. Edit the master; do not recreate.')
MATS={n:bpy.data.materials[n] for n in ['Masonry','Trim','Timber','Slate','Iron','Gold','Glass','Cloth','Leaf','Bark','Rock','Dark']}
for name,color in [('Linen',(.68,.64,.49,1)),('Paper',(.58,.48,.30,1))]:
    mat=bpy.data.materials.new(name); mat.diffuse_color=color; mat.use_nodes=True
    bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if bs is None: bs=mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    bs.inputs['Base Color'].default_value=color
    MATS[name]=mat
code=(ROOT/'tools/build_story_models.py').read_text(encoding='utf-8')
exec(code[code.index('collection = None'):code.index('for role in range(6): building(role)')])

# Remove the identical prototype table from each joined Body. Work on its
# interior bounds only, leaving foundations, walls and authored roofs untouched.
for role in range(6):
    col=bpy.data.collections['service_%d'%role]; origin=Vector(col['asset_origin'])
    w=2.6+.3*(role%3); depth=2+.3*(role%2)
    body=next(o for o in col.objects if o.name.startswith('Body'))
    bm=bmesh.new(); bm.from_mesh(body.data)
    vertices=[v for v in bm.verts if abs((v.co+body.location-origin).x+w*.22)<.37
              and abs((v.co+body.location-origin).y-depth*.12)<.23
              and -.001<(v.co+body.location-origin).z<.57]
    bmesh.ops.delete(bm,geom=vertices,context='VERTS'); bm.to_mesh(body.data); bm.free()

def close(name,index):
    col=bpy.data.collections[name]
    for phase,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True); bpy.context.view_layer.objects.active=obj
            for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name=phase
    origin=Vector(((index%6)*4,-65-(index//6)*4,0))
    for obj in col.objects: obj.location+=origin
    col['ct_asset']=True; col['asset_origin']=list(origin)

def table(w,d,h=.66):
    for j in range(4): box('Separate tabletop plank',(-w/2+(j+.5)*w/4,0,h),(w/4-.008,d,.075),'Timber')
    for x in [-w*.37,w*.37]:
        for y in [-d*.33,d*.33]: box('Carved leg',(x,y,h/2),(.07,.07,h),'Timber')
    beam('Stretcher',(-w*.37,0,.20),(w*.37,0,.20),.03,'Timber')

def candle(x,y,z):
    beam('Wax candle',(x,y,z),(x,y,z+.13),.025,'Linen')
    beam('Flame',(x,y,z+.13),(x,y,z+.20),.02,'Glass',end_radius=.002)
    box('Candle tray',(x,y,z-.01),(.12,.12,.025),'Iron')

names=['watch_map_table','weapon_stand','ward_cot','medicine_cabinet','archive_lectern','archive_scrolls','cargo_shelves','inn_counter','inn_table','wood_stool','candle_cluster','forge_bellows']
for index,name in enumerate(names):
    start_asset(name)
    if name=='watch_map_table':
        table(1.10,.48)
        box('Spread chart',(0,0,.708),(.84,.36,.012),'Paper',bevel=.002)
        for x,y in [(-.31,-.09),(.26,.07),(.05,-.12)]:
            box('Troop marker',(x,y,.735),(.025,.025,.045),'Gold')
        beam('Rolled chart',(-.34,.16,.73),(.30,.16,.73),.035,'Paper')
        candle(.46,-.13,.71)
    elif name=='weapon_stand':
        for x in [-.41,.41]:
            box('Rack foot',(x,0,.05),(.16,.40,.10),'Timber')
            box('Rack upright',(x,0,.59),(.09,.10,1.18),'Timber')
        for z in [.34,.95]: box('Rack crossbar',(0,0,z),(.93,.10,.10),'Timber')
        for x in [-.25,0,.25]:
            beam('Practice haft',(x,.075,.13),(x+.05,.075,1.21),.022,'Timber')
            box('Steel blade',(x+.045,.075,1.04),(.055,.028,.34),'Iron')
            box('Guard',(x+.035,.075,.83),(.18,.05,.035),'Gold')
    elif name=='ward_cot':
        for x in [-.28,.28]:
            box('Bed rail',(x,0,.33),(.08,1.32,.12),'Timber')
            for y in [-.58,.58]: box('Bed post',(x,y,.24),(.075,.075,.48),'Timber')
        box('Mattress',(0,0,.41),(.52,1.25,.15),'Linen',bevel=.045)
        box('Blanket',(0,.18,.50),(.54,.77,.032),'Cloth',bevel=.012)
        box('Pillow',(0,-.46,.51),(.43,.24,.11),'Linen',bevel=.045)
        box('Headboard',(0,-.65,.55),(.64,.065,.45),'Timber')
        for x in [-.20,0,.20]: box('Headboard inset',(x,-.612,.59),(.07,.018,.23),'Iron')
    elif name in ['medicine_cabinet','cargo_shelves']:
        w=.70 if name=='medicine_cabinet' else 1.00
        for x in [-w/2,w/2]: box('Shelf side',(x,0,.65),(.055,.30,1.30),'Timber')
        box('Cabinet backing',(0,-.135,.65),(w,.035,1.30),'Timber')
        for row in range(4):
            z=.10+row*.32; box('Shelf',(0,0,z),(w,.30,.04),'Timber')
            if name=='medicine_cabinet':
                for j in range(4):
                    x=-.23+j*.15
                    beam('Apothecary jar',(x,.025,z+.04),(x,.025,z+.17),.045,'Glass' if j%2 else 'Linen')
                    box('Cork',(x,.025,z+.18),(.05,.05,.025),'Timber')
            else:
                for x in [-.25,.25]:
                    box('Packed crate',(x,0,z+.13),(.40,.25,.20),'Timber')
                    box('Crate strap',(x,0,z+.236),(.035,.26,.014),'Iron')
    elif name=='archive_lectern':
        table(.90,.44,.72)
        obj=box('Sloped reading board',(0,0,.81),(.72,.35,.07),'Timber'); obj.rotation_euler.x=.20
        obj=box('Open ledger',(0,0,.85),(.50,.29,.025),'Paper',bevel=.006); obj.rotation_euler.x=.20
        beam('Book spine',(0,-.14,.88),(0,.14,.825),.01,'Gold')
        candle(.37,.09,.765)
    elif name=='archive_scrolls':
        box('Scroll chest',(0,0,.25),(.80,.32,.50),'Timber')
        for i in range(7): beam('Rolled folio',(-.30+i*.10,-.11,.56),(-.30+i*.10,.11,.56),.04,'Paper')
        for x in [-.28,.28]: box('Chest iron strap',(x,0,.51),(.035,.35,.035),'Iron')
    elif name=='inn_counter':
        box('Counter panels',(0,0,.42),(1.18,.42,.84),'Timber')
        for x in [-.48,-.24,0,.24,.48]: box('Panel trim',(x,.22,.42),(.035,.035,.76),'Timber')
        box('Countertop',(0,0,.87),(1.29,.51,.065),'Timber')
        for x in [-.35,-.15,.05]:
            beam('Drinking cup',(x,.08,.91),(x,.08,1.01),.04,'Iron')
        barrel(.42,0,.90)
    elif name=='inn_table':
        table(.72,.56,.60)
        box('Runner',(0,0,.644),(.27,.57,.013),'Cloth')
        candle(-.20,-.13,.647)
        for x in [.17,.27]: beam('Tin cup',(x,.11,.65),(x,.11,.73),.03,'Iron')
    elif name=='wood_stool':
        box('Seat',(0,0,.40),(.30,.30,.065),'Timber')
        for x in [-.105,.105]:
            for y in [-.105,.105]: beam('Splayed leg',(x*1.2,y*1.2,.02),(x,y,.38),.027,'Timber')
    elif name=='candle_cluster':
        for x,y,z in [(-.08,0,0),(.05,.05,0),(.02,-.08,0)]: candle(x,y,z+.035)
    else:
        for x in [-.16,.16]: box('Bellows frame',(x,0,.34),(.07,.64,.07),'Timber')
        for i in range(6): box('Pleated leather',(0,-.23+i*.085,.25),(.30,.045,.23),'Cloth')
        beam('Air nozzle',(0,-.35,.27),(0,-.55,.30),.055,'Iron',end_radius=.025)
        beam('Bellows lever',(-.20,.22,.40),(.22,.22,.40),.025,'Timber')
    close(name,index)
bpy.context.scene['workplace_revision']=1
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('AUTHORED_WORKPLACES',len(names))
