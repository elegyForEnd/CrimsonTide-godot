"""Edit the master once to give the six workplaces distinct silhouettes."""
import bpy,pathlib,math,random
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/opening-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
if bpy.context.scene.get('silhouette_revision')==2: raise RuntimeError('Revision already authored; do not overwrite artist edits.')
MATS={n:bpy.data.materials[n] for n in ['Masonry','Trim','Timber','Slate','Iron','Gold','Glass','Cloth','Leaf','Bark','Rock','Dark']}
code=(ROOT/'tools/build_story_models.py').read_text(encoding='utf-8')
exec(code[code.index('collection = None'):code.index('for role in range(6): building(role)')])
for role in range(6):
    collection=bpy.data.collections['service_%d'%role]; groups={}
    w=2.6+.3*(role%3); d=2+.3*(role%2); h=1.8+.25*(role%3)
    if role==0:
        box('Watch tower',(-.65,-.43,h+.50),(.75,.72,1.00),'Masonry','Roof')
        for x in [-.94,-.65,-.36]: box('Tower crown',(x,-.43,h+1.11),(.20,.75,.28),'Trim','Roof')
        window(-.65,d/2+.01,1.05,.25,.64,'Front')
    elif role==1:
        # Slender chapel bell spire rises above the surrounding domestic roofs.
        beam('Bell spire',(0,-.70,h+1.6),(0,-.70,h+2.65),.44,'Slate','Roof',end_radius=.015,sides=8)
        for x in [-w/2+.2,w/2-.2]: box('Chapel pilaster',(x,.35,1.05),(.22,.50,2.1),'Trim','Body')
        arch(0,d/2+.09,1.36,.56,.07,.12,'Front')
    elif role==2:
        # Broad soot-dark hood and twin industrial stacks distinguish the forge.
        box('Stone furnace flue',(.79,-.58,h+.64),(.62,.63,1.28),'Masonry','Roof')
        for z in [h+.19,h+.79,h+1.32]: box('Flue iron belt',(.79,-.58,z),(.68,.69,.055),'Iron','Roof')
        box('Forge shelter',(0,d/2+.18,h-.12),(2.60,.65,.12),'Timber','Front')
        for x in [-1.13,1.13]: beam('Shelter brace',(x,d/2+.03,h-.42),(x,d/2+.45,h-.12),.032,'Iron','Front')
    elif role==3:
        box('Archive turret',(.52,-.44,h+1.01),(.83,.82,1.62),'Masonry','Roof')
        beam('Archive turret cap',(.52,-.44,h+1.84),(.52,-.44,h+2.7),.60,'Slate','Roof',end_radius=.02,sides=4)
        for x in [-w/2+.14,w/2-.14]:
            box('Archive flying pier',(x,-.22,1.23),(.26,.46,2.46),'Trim')
            beam('Carved flying brace',(x,-.5,1.4),(x,0,2.1),.045,'Trim')
    elif role==4:
        old=next(o for o in collection.objects if o.name.startswith('Roof'))
        bpy.data.objects.remove(old,do_unlink=True)
        # Open timber rafters and a low shed roof instead of a fifth stone cottage.
        verts=[(-w/2-.12,-d/2-.12,h+.45),(w/2+.12,-d/2-.12,h+.45),(-w/2-.12,d/2+.2,h),(w/2+.12,d/2+.2,h)]
        mesh('Warehouse lean-to',verts,[(0,2,3,1)],'Slate','Roof')
        for x in [-w/2,0,w/2]: beam('Warehouse exposed rafter',(x,-d/2-.1,h+.38),(x,d/2+.2,h-.05),.05,'Timber','Roof')
        box('Cargo gantry',(0,d/2+.16,h+.12),(2.7,.25,.22),'Timber','Front')
        beam('Hanging hoist',(0,d/2+.25,h+.15),(0,d/2+.25,h-.45),.018,'Iron','Front')
        for x in [-.96,.96]: box('Warehouse lintel post',(x,d/2+.14,h/2),(.15,.15,h),'Timber','Front')
    else:
        # Inn's projecting upper gallery and roof dormers form a domestic landmark.
        box('Inn balcony',(0,d/2+.31,h-.12),(w+.18,.78,.13),'Timber','Front')
        for x in [-1.2,-.8,-.4,0,.4,.8,1.2]: beam('Gallery spindle',(x,d/2+.69,h-.06),(x,d/2+.69,h+.40),.018,'Timber','Front')
        beam('Gallery handrail',(-1.28,d/2+.69,h+.40),(1.28,d/2+.69,h+.40),.036,'Timber','Front')
        for x in [-.66,.66]:
            box('Inn dormer',(x,0,h+.69),(.54,.67,.53),'Timber','Roof')
            window(x,.35,h+.62,.28,.34,'Roof')
    origin=Vector(collection['asset_origin'])
    for phase,objects in groups.items():
        for obj in objects: obj.location+=origin
        original=next((o for o in collection.objects if o.name.startswith(phase) and o not in objects),None)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True); bpy.context.view_layer.objects.active=obj
            for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        if original: original.select_set(True); bpy.context.view_layer.objects.active=original
        else: bpy.context.view_layer.objects.active=objects[0]
        if len(objects)+(1 if original else 0)>1: bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name=phase
bpy.context.scene['silhouette_revision']=2
bpy.ops.wm.save_as_mainfile(filepath=str(source))
