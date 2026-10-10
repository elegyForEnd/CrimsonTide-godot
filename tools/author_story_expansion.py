"""One-time authoring pass. Creates a NEW editable master; never overwrites it.
Run Blender --background --python tools/author_story_expansion.py
Further edits belong in opening-master.blend; export_story_models.py only exports.
"""
import bpy, pathlib, math, json, random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
DEST=ROOT/'art/story-environment/opening-master.blend'
if DEST.exists(): raise RuntimeError('Master exists: edit it in Blender; authoring must not replace it.')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/story-environment/thunder-bastion-kit.blend'))
MATS={n:bpy.data.materials[n] for n in ['Masonry','Trim','Timber','Slate','Iron','Gold','Glass','Cloth','Leaf','Bark','Rock','Dark']}
# Reuse tested primitive authoring helpers, without the original reset/build pass.
code=(ROOT/'tools/build_story_models.py').read_text(encoding='utf-8')
exec(code[code.index('collection = None'):code.index('for role in range(6): building(role)')])
OUT=ROOT/'assets/story/environment/models'
original=[c for c in bpy.data.collections if c.name.startswith('service_') or c.name in ['south_gate','wall_section','rubble','forest_tree','cave_portal','rock_formation','grass_tuft']]
for i,c in enumerate(original): c['ct_asset']=True; c['asset_origin']=[(i%4)*5,-(i//4)*5,0]

def close_asset(name,index):
    col=bpy.data.collections[name]
    for phase,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            o.select_set(True); bpy.context.view_layer.objects.active=o
            for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name=phase
    origin=Vector(((index%8)*4,-25-(index//8)*4,0))
    for obj in col.objects: obj.location+=origin
    col['ct_asset']=True; col['asset_origin']=list(origin)

def module(kind,broken,index):
    name=kind+('_broken' if broken else '_intact'); start_asset(name)
    if kind in ['stone_wall','wall_corner','buttress','foundation']:
        rows=6 if kind!='foundation' else 2
        for row in range(rows):
            for j in range(4):
                if broken and row>2 and j>=2: continue
                width=.46 if kind!='buttress' else .24
                box('Dressed stone',(j*width-.7+(row%2)*.12,0,.15+row*.29),(width-.012,.32 if kind!='buttress' else .65,.275),'Masonry',bevel=.025)
        if kind=='wall_corner':
            for row in range(rows): box('Return stone',(-.72,-.45,.15+row*.29),(.32,.9,.27),'Masonry',bevel=.025)
    elif kind in ['pointed_arch','arcade']:
        for x in [-.9,.9]: box('Arch pillar',(x,0,.74),(.32,.46,1.48),'Masonry')
        arch(0,0,1.42,.9,.18,.45,'Body')
        if not broken: beam('Arch tie',(-.9,0,2.35),(.9,0,2.35),.055,'Iron')
        else: boulder('Broken arch crown',(.42,.18,.16),(.6,.45,.35),62)
        if kind=='arcade':
            for x in [-.9,.9]: beam('Vault rib',(x,0,1.4),(x,-1.2,1.4),.08,'Trim')
    elif kind=='stairs':
        for i in range(8 if not broken else 6): box('Worn stair',(0,i*.19,(i+1)*.065),(1.45,.20,(i+1)*.13),'Trim',bevel=.025)
    elif kind in ['wood_door','iron_door']:
        for j in range(7 if not broken else 4): box('Door plank',(-.43+j*.145,0,.67),(.13,.08,1.34),'Timber',bevel=.01)
        for z in [.22,.97]: box('Iron strap',(0,.052,z),(.98,.025,.07),'Iron')
        if kind=='iron_door':
            for j in range(5): box('Iron reinforcing',(-.36+j*.18,.056,.67),(.045,.02,1.28),'Iron')
    elif kind in ['gothic_window','window_sill','iron_grille','stained_window']:
        for x in [-.42,.42]: box('Window jamb',(x,0,.60),(.14,.16,1.2),'Trim')
        arch(0,0,1.10,.42,.09,.14,'Body')
        box('Window sill',(0,.04,.07),(1.04,.37,.13),'Trim')
        for x in [-.25,0,.25]:
            if not broken or x<.1: beam('Window tracery',(x,.05,.18),(x,.05,1.17),.022,'Iron')
        if kind=='stained_window' and not broken: box('Stained pane',(0,-.05,.61),(.69,.018,1.02),'Glass')
    elif kind in ['slate_roof','ridge','eaves','roof_beam','chimney']:
        if kind=='slate_roof': roof(2,1.5,.2,1.1,'Body')
        elif kind=='chimney':
            for z in range(5 if not broken else 3): box('Chimney course',(0,0,.16+z*.28),(.48,.5,.26),'Masonry')
            box('Chimney cap',(0,0,1.48 if not broken else .91),(.65,.66,.14),'Trim')
        else:
            beam('Carved timber',(-1,0,.12),(.4 if broken else 1,0,.12),.085,'Timber')
            if kind=='roof_beam': beam('Truss brace',(-.8,0,.12),(0,0,1.0),.045,'Timber')
            if kind=='ridge': beam('Ridge iron',(-1,.03,.22),(.4 if broken else 1,.03,.22),.025,'Gold')
    elif kind in ['ruin_column','rubble_pile','exposed_frame']:
        if kind=='ruin_column': beam('Stone column',(0,0,0),(.06,0,1.25 if broken else 2.1),.23,'Trim',end_radius=.18,sides=10)
        elif kind=='exposed_frame':
            for x in [-.85,.85]: beam('Exposed upright',(x,0,0),(x,0,1.65),.075,'Timber')
            beam('Broken lintel',(-.85,0,1.65),(.25 if broken else .85,0,1.65),.08,'Timber')
        else:
            for j in range(12): boulder('Rubble',(math.sin(j*2.4)*.65,math.cos(j*2.4)*.4,.1+(j%3)*.07),(.3,.25,.2),j+9)
    close_asset(name,index)

kinds=['stone_wall','wall_corner','buttress','pointed_arch','arcade','stairs','foundation','wood_door','iron_door','gothic_window','window_sill','iron_grille','stained_window','slate_roof','ridge','eaves','roof_beam','chimney','ruin_column','rubble_pile','exposed_frame']
for i,kind in enumerate(kinds):
    for broken in [False,True]: module(kind,broken,i*2+int(broken))

for index,name in enumerate(['anvil','forge','tool_rack','cargo','rope_coil','handcart','canopy','bookshelf','tree_root','dead_tree','cave_wall','cave_ceiling','cliff'],42):
    start_asset(name)
    if name=='anvil':
        box('Anvil stump',(0,0,.3),(.48,.45,.6),'Timber'); box('Anvil',(0,0,.69),(.75,.35,.18),'Iron'); beam('Horn',(.24,0,.72),(.59,0,.73),.08,'Iron',end_radius=.015)
    elif name=='forge':
        for x in [-.45,.45]: box('Hearth cheek',(x,0,.53),(.25,.9,1.06),'Masonry')
        box('Hearth',(0,0,.18),(1.08,.95,.36),'Masonry'); box('Coals',(0,.08,.39),(.59,.63,.035),'Glass')
        box('Flue',(0,-.26,1.26),(.65,.5,.7),'Masonry'); box('Hood',(0,0,.94),(.95,.9,.14),'Iron')
    elif name=='tool_rack':
        for x in [-.5,.5]: beam('Rack post',(x,0,0),(x,0,1.25),.035,'Timber')
        beam('Rack bar',(-.5,0,1.1),(.5,0,1.1),.035,'Timber')
        for x in [-.3,0,.3]: beam('Tool handle',(x,0,.4),(x,0,1.05),.015,'Timber'); box('Tool head',(x,0,.88),(.19,.05,.1),'Iron')
    elif name=='cargo':
        for x,d,z in [(-.35,0,.25),(.35,0,.25),(0,0,.77)]:
            box('Crate',(x,d,z),(.64,.55,.48),'Timber'); beam('Crate brace',(x-.28,d+.29,z-.20),(x+.28,d+.29,z+.2),.025,'Iron')
        barrel(.8,.12,0)
    elif name=='rope_coil':
        for layer in range(3):
            for j in range(20):
                a=j*math.tau/20; b=(j+1)*math.tau/20
                beam('Hemp rope',(math.cos(a)*(.30+layer*.05),math.sin(a)*(.30+layer*.05),.035+layer*.04),(math.cos(b)*(.30+layer*.05),math.sin(b)*(.30+layer*.05),.035+layer*.04),.018,'Timber',sides=6)
    elif name=='handcart':
        for i in range(5): box('Cart bed',(-.42+i*.21,0,.48),(.19,1.24,.07),'Timber')
        for x in [-.52,.52]:
            box('Cart side',(x,0,.72),(.07,1.24,.44),'Timber'); beam('Cart handle',(x,.4,.47),(x,1.45,.40),.035,'Timber')
            for j in range(12):
                a=j*math.tau/12; b=(j+1)*math.tau/12
                beam('Wheel rim',(x,math.cos(a)*.29,math.sin(a)*.29+.31),(x,math.cos(b)*.29,math.sin(b)*.29+.31),.032,'Iron')
                beam('Wheel spoke',(x,0,.31),(x,math.cos(a)*.27,math.sin(a)*.27+.31),.015,'Timber')
    elif name=='canopy':
        for x in [-.8,.8]:
            for d in [-.5,.5]: beam('Canopy post',(x,d,0),(x,d,1.65),.035,'Timber')
        box('Sagging canvas',(0,0,1.7),(1.8,1.25,.06),'Cloth'); beam('Canvas ridge',(-.9,0,1.76),(.9,0,1.76),.02,'Timber')
    elif name=='bookshelf':
        for x in [-.62,.62]: box('Bookcase side',(x,0,.7),(.08,.38,1.4),'Timber')
        for z in [.10,.5,.90,1.3]:
            box('Shelf',(0,0,z),(1.32,.38,.065),'Timber')
            for i in range(9): box('Ledger',(-.54+i*.13,0,z+.14),(.08,.26,.22),'Cloth' if i%3==0 else 'Timber')
    elif name in ['tree_root','dead_tree']:
        if name=='dead_tree': beam('Dead trunk',(0,0,0),(.18,0,2.6),.13,'Bark',end_radius=.04)
        for j in range(6):
            a=j*2.4; beam('Root or branch',(.03,0,.16 if name=='tree_root' else .9+j*.2),(math.cos(a)*.75,math.sin(a)*.7,.02 if name=='tree_root' else 1.4+j*.2),.07,'Bark',end_radius=.015)
    else:
        for i in range(7): boulder('Stratified rock',((i%3-1)*.7,(i//3)*.35,.50+(i%2)*.65),(1.6,1.1,1.5),200+i)
    close_asset(name,index)

# Source preview shares the actual downloaded PBR maps, including ORM.
for name,palette in [('Masonry','masonry'),('Trim','masonry'),('Timber','timber'),('Slate','slate'),('Bark','bark'),('Rock','rock'),('Iron','iron'),('Cloth','cloth')]:
    mat=MATS[name]; tree=mat.node_tree; bs=tree.nodes.get('Principled BSDF')
    for node in list(tree.nodes):
        if node.type in ['TEX_IMAGE','NORMAL_MAP','SEPRGB','SEP_COLOR']: tree.nodes.remove(node)
    def tex(channel):
        n=tree.nodes.new('ShaderNodeTexImage'); n.image=bpy.data.images.load(str(OUT.parent/'pbr'/f'{palette}_{channel}.png'),check_existing=True)
        if channel!='albedo': n.image.colorspace_settings.name='Non-Color'
        return n
    tree.links.new(tex('albedo').outputs['Color'],bs.inputs['Base Color'])
    normal=tree.nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.6
    tree.links.new(tex('normal').outputs['Color'],normal.inputs['Color']); tree.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
    split=tree.nodes.new('ShaderNodeSeparateColor'); tree.links.new(tex('orm').outputs['Color'],split.inputs['Color'])
    tree.links.new(split.outputs['Green'],bs.inputs['Roughness']); tree.links.new(split.outputs['Blue'],bs.inputs['Metallic'])
bpy.context.scene['production_note']='Editable master. Export-only tool preserves all modelling edits.'
bpy.ops.wm.save_as_mainfile(filepath=str(DEST)); bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_as_mainfile(filepath=str(DEST))
print('AUTHORED_MODULES',len(kinds)*2+13)
