"""Build the editable Feiyue animation prototype and render fixed-pivot sprites."""
import bpy, math, json, argparse, sys
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/feiyue-3d-v1'
argv=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
parser=argparse.ArgumentParser()
parser.add_argument('--preview',action='store_true')
args=parser.parse_args(argv)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'feiyue-working.blend'))
scene=bpy.context.scene
body=next(o for o in scene.objects if o.type=='MESH')
body.name='Feiyue_Body'
mat=body.data.materials[0]
# Smooth welded surface + subdued two-band shadow, no PBR gloss/normal noise.
ramp=next(n for n in mat.node_tree.nodes if n.type=='VALTORGB')
ramp.color_ramp.elements[0].color=(0.78,0.75,0.84,1)
ramp.color_ramp.elements[1].position=0.33
mat.name='Feiyue_Cel_TwoTone'

bpy.ops.object.armature_add(enter_editmode=True,location=(0,0,0))
rig=bpy.context.object
rig.name='Feiyue_Rig'
rig.data.edit_bones.remove(rig.data.edit_bones[0])
segments={}
def bone(name,head,tail,parent=None):
    b=rig.data.edit_bones.new(name)
    b.head=head; b.tail=tail
    if parent: b.parent=rig.data.edit_bones[parent]
    segments[name]=(Vector(head),Vector(tail))
bone('root',(0,0,0),(0,0,.14))
bone('pelvis',(0,0,.40),(0,0,.52),'root')
bone('spine',(0,0,.52),(0,0,.68),'pelvis')
bone('head',(0,0,.68),(0,0,.97),'spine')
bone('hair',(0,.10,.83),(0,.16,.43),'head')
bone('face_expression',(0,-.17,.825),(0,-.17,.845),'head')
for action in ('sword','heavy','staff'):
    bone('weapon_'+action,(-.385,-.056,.516),(-.385,-.056,.616))
for suffix,s in [('L',1),('R',-1)]:
    bone('upper_arm.'+suffix,(s*.145,0,.715),(s*.27,-.03,.63),'spine')
    bone('forearm.'+suffix,(s*.27,-.03,.63),(s*.355,-.045,.577),'upper_arm.'+suffix)
    bone('hand.'+suffix,(s*.355,-.045,.577),(s*.415,-.056,.535),'forearm.'+suffix)
    bone('thigh.'+suffix,(s*.105,0,.40),(s*.106,-.006,.235),'pelvis')
    bone('shin.'+suffix,(s*.106,-.006,.235),(s*.112,.006,.070),'thigh.'+suffix)
    bone('foot.'+suffix,(s*.112,.006,.070),(s*.112,-.078,.032),'shin.'+suffix)
    bone('skirt.'+suffix,(s*.09,0,.47),(s*.18,0,.34),'pelvis')
for action in ('sword','heavy','staff'):
    rig.data.edit_bones['weapon_'+action].parent=rig.data.edit_bones['hand.R']
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front=True
rig.data.display_type='STICK'
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
groups={n:body.vertex_groups.new(name=n) for n in segments}
def segdist(p,n):
    a,b=segments[n]
    d=b-a
    t=max(0,min(1,(p-a).dot(d)/d.length_squared))
    return (p-(a+d*t)).length
def smoothstep(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)
def near_weights(p,names):
    pairs=sorted([(segdist(p,n),n) for n in names])[:2]
    ws=[1/(d+.018)**4 for d,n in pairs]; total=sum(ws)
    return {n:w/total for (d,n),w in zip(pairs,ws)}
for v in body.data.vertices:
    p=v.co; x,y,z=p; side='L' if x>=0 else 'R'
    base=near_weights(p,['pelvis','spine','head'] if z>.46 else ['pelvis','skirt.'+side])
    weights=dict(base)
    legmask=1-smoothstep(.29,.36,z)
    armdist=min(segdist(p,n) for n in ['upper_arm.'+side,'forearm.'+side,'hand.'+side])
    armmask=smoothstep(.16,.235,abs(x))*smoothstep(.425,.52,z)*(1-smoothstep(.065,.125,armdist))*(1-smoothstep(.05,.12,y))
    handmask=smoothstep(.32,.355,abs(x))*smoothstep(.49,.52,z)*(1-smoothstep(.61,.65,z))
    armmask=max(armmask,handmask)
    hairmask=smoothstep(.055,.12,y)*smoothstep(.38,.49,z)*(1-smoothstep(.65,.78,z))
    headmask=smoothstep(.70,.78,z)
    def blend(target,amount):
        for n in list(weights): weights[n]*=1-amount
        for n,w in target.items(): weights[n]=weights.get(n,0)+w*amount
    blend(near_weights(p,['thigh.'+side,'shin.'+side,'foot.'+side]),legmask)
    blend(near_weights(p,['upper_arm.'+side,'forearm.'+side,'hand.'+side]),armmask)
    blend({'hair':1},hairmask)
    blend({'head':1},headmask)
    # Fingers/palm move as a rigid hand rather than blending into skirt/torso.
    if abs(x)>.35 and .49<z<.62 and y<.075:
        weights={'hand.'+side:1}
    for n,w in weights.items():
        if w>.0001: groups[n].add([v.index],w,'REPLACE')
arm=body.modifiers.new('Feiyue_Skin','ARMATURE')
arm.object=rig
arm.use_deform_preserve_volume=True
body.parent=rig

def flatmat(name,color):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    ns=m.node_tree.nodes; ns.clear()
    e=ns.new('ShaderNodeEmission'); e.inputs['Color'].default_value=(*color,1)
    o=ns.new('ShaderNodeOutputMaterial'); m.node_tree.links.new(e.outputs[0],o.inputs[0])
    return m
gold=flatmat('Weapon_Gold',(.74,.43,.10))
red=flatmat('Sword_Crimson',(.43,.012,.045))
dark=flatmat('Grip_Dark',(.055,.025,.035))
cyan=flatmat('Staff_Cyan',(.02,.50,.62))
mouthmat=flatmat('Mouth_Interior',(.13,.018,.038))

def meshobj(name,vertices,faces,material):
    data=bpy.data.meshes.new(name); data.from_pydata(vertices,[],faces); data.update()
    o=bpy.data.objects.new(name,data); scene.collection.objects.link(o)
    o.data.materials.append(material)
    return o
def box(name,location,scale,material):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    return o
def parent_at_world(o,parent,bone_name,worldmatrix):
    o.parent=parent; o.parent_type='BONE'; o.parent_bone=bone_name
    bpy.context.view_layer.update()
    o.matrix_world=worldmatrix

weapons={}
for action,length,width in [('sword',.45,.025),('heavy',.61,.046),('staff',.70,.015)]:
    bpy.ops.object.empty_add(type='PLAIN_AXES')
    holder=bpy.context.object; holder.name='Weapon_'+action
    objects=[]
    if action!='staff':
        # Symmetric straight blade: two bevel faces around a central ridge.
        vertices=[(-width,0,.10),(width,0,.10),(-width,.0,length*.76),(width,0,length*.76),(0,0,length),(0,-.007,.10),(0,-.007,length*.76)]
        blade=meshobj(action+'_straight_blade',vertices,[(0,5,6,2),(5,1,3,6),(2,6,4),(6,3,4)],red)
        objects.append(blade)
        for s in [-1,1]:
            edge=meshobj(action+'_edge',[(s*width,-.001,.10),(s*(width-.004),-.002,.10),(s*width,0,length*.76),(s*(width-.004),-.002,length*.76),(0,0,length)],[(0,1,3,2),(2,3,4)],gold)
            objects.append(edge)
        guard=meshobj(action+'_guard',[(-.08,0,.061),(-.065,0,.085),(-.025,0,.100),(.025,0,.100),(.065,0,.085),(.08,0,.061),(.04,0,.072),(-.04,0,.072)],[(0,1,2,3,4,5,6,7)],gold)
        objects.append(guard)
        objects.append(box(action+'_grip',(0,0,.035),(.018,.018,.078),dark))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.024,location=(0,-.012,.084))
        gem=bpy.context.object; gem.name=action+'_guard_ruby'; gem.data.materials.append(red); objects.append(gem)
    else:
        objects.append(box('Staff_shaft',(0,0,.27),(.016,.016,.65),gold))
        objects.append(box('Staff_grip',(0,0,.11),(.02,.02,.22),cyan))
        # Cyan crystal crown with gold side prongs.
        crystal=meshobj('Staff_crystal',[(0,0,.78),(-.058,0,.69),(0,-.032,.60),(.058,0,.69),(0,.032,.66)],[(0,1,2),(0,2,3),(0,3,4),(0,4,1),(1,4,2),(2,4,3)],cyan)
        objects.append(crystal)
        for s in [-1,1]:
            prong=box('Staff_gold_prong',(s*.05,0,.66),(.012,.018,.14),gold)
            prong.rotation_euler.y=s*.32; objects.append(prong)
            ribbon=meshobj('Staff_teal_ribbon',[(s*.035,.012,.66),(s*.060,.012,.64),(s*.09,.016,.51),(s*.11,.012,.38),(s*.068,.01,.42),(s*.048,.012,.54)],[(0,1,2,3,4,5)],cyan)
            objects.append(ribbon)
    for o in objects: o.parent=holder
    # Attach the independent weapon to the right palm in world space.
    parent_at_world(holder,rig,'weapon_'+action,Matrix.Translation(Vector((-.385,-.056,.516))))
    weapons[action]=(holder,objects)

# Grip corrective shape: curl the generated outstretched finger region around
# the weapon grip, preserving wrist position and the two hands separately.
body.shape_key_add(name='Basis')
grip=body.shape_key_add(name='Grip_Right')
grip_left=body.shape_key_add(name='Grip_Left')
for i,v in enumerate(body.data.vertices):
    x,y,z=v.co
    if x<-.365 and .50<z<.615 and y<.045:
        t=min(1,max(0,(-x-.365)/.05))
        grip.data[i].co.x=x+(x+.383)*(-.65*t)
        grip.data[i].co.y=y-.012*t
        grip.data[i].co.z=z+(.555-z)*.70*t
    if x>.365 and .50<z<.615 and y<.045:
        t=min(1,max(0,(x-.365)/.05))
        grip_left.data[i].co.x=x-(x-.383)*.65*t
        grip_left.data[i].co.y=y-.012*t
        grip_left.data[i].co.z=z+(.555-z)*.70*t
for key,prop in [(grip,'grip_right'),(grip_left,'grip_left')]:
    rig[prop]=0.0
    driver=key.driver_add('value').driver
    variable=driver.variables.new(); variable.name='amount'; variable.type='SINGLE_PROP'
    variable.targets[0].id=rig; variable.targets[0].data_path='["'+prop+'"]'
    driver.expression='amount'

# Small mouth mesh located from an actual ray hit on the face, attached to head.
hit,location,normal,index=body.ray_cast(Vector((0,-1,.825)),Vector((0,1,0)))
mouth_y=location.y-.003 if hit else -.16
vertices=[(0,mouth_y,.825)]+[(.010*math.cos(i*math.tau/24),mouth_y-.0002,.825+.011*math.sin(i*math.tau/24)) for i in range(24)]
mouth=meshobj('Attack_Exertion_Mouth',vertices,[(0,i+1,(i+1)%24+1) for i in range(24)],mouthmat)
parent_at_world(mouth,rig,'face_expression',Matrix.Identity(4))

def rotate(name,axis,angle):
    basis=rig.data.bones[name].matrix_local.to_quaternion()
    rig.pose.bones[name].rotation_quaternion=basis.inverted()@Quaternion(Vector(axis),angle)@basis
def aim_bone(name,head,tail):
    rest=rig.data.bones[name]
    q=(rest.tail_local-rest.head_local).rotation_difference(tail-head)@rest.matrix_local.to_quaternion()
    rig.pose.bones[name].matrix=Matrix.Translation(head)@q.to_matrix().to_4x4()
    bpy.context.view_layer.update()
def arm_ik(side,target):
    upper='upper_arm.'+side; lower='forearm.'+side
    shoulder=rig.pose.bones[upper].head.copy()
    a=rig.data.bones[upper].length; b=rig.data.bones[lower].length
    delta=Vector(target)-shoulder
    distance=min(delta.length,a+b-.001)
    direction=delta.normalized()
    along=(a*a-b*b+distance*distance)/(2*distance)
    height=math.sqrt(max(0,a*a-along*along))
    hint=Vector((1 if side=='L' else -1,.2,-.7))
    perpendicular=(hint-direction*hint.dot(direction)).normalized()
    elbow=shoulder+direction*along+perpendicular*height
    wrist=shoulder+direction*distance
    aim_bone(upper,shoulder,elbow)
    aim_bone(lower,elbow,wrist)
def hide_weapons(action):
    for key,(holder,objects) in weapons.items():
        rig.pose.bones['weapon_'+key].scale=(1,1,1) if key==action else (.00001,)*3
def pose(action,index):
    if action.startswith('idle_'):
        pose(action[5:],0)
        wave=math.sin(index/8*math.tau)
        rig.pose.bones['spine'].scale=(1,1+.006*wave,1)
        rotate('hair',(1,0,0),.018*wave)
        bpy.context.view_layer.update()
        return
    for pb in rig.pose.bones:
        pb.rotation_quaternion=Quaternion(); pb.location=(0,0,0); pb.scale=(1,1,1)
    t=index/8
    wave=math.sin(t*math.tau)
    attack=action in weapons
    hide_weapons(action)
    rig['grip_right']=1.0 if attack else 0.0
    rig['grip_left']=1.0 if action=='heavy' else 0.0
    rig.pose.bones['face_expression'].scale=(1,1,1) if attack and index in (4,5) else (.00001,)*3
    rotate('upper_arm.R',(0,1,0),-.48)
    rotate('upper_arm.L',(0,1,0),.48)
    if action=='idle':
        rig.pose.bones['spine'].scale=(1,1+.008*wave,1)
        rotate('hair',(1,0,0),.018*wave)
    elif action in ('walk','run'):
        running=action=='run'
        stride=.65 if running else .36
        stride_wave=math.cos(t*math.tau)
        for side,s in [('L',1),('R',-1)]:
            rotate('thigh.'+side,(1,0,0),-stride_wave*s*stride)
            rotate('shin.'+side,(1,0,0),max(0,-wave*s)*(.95 if running else .52))
            rotate('foot.'+side,(1,0,0),-.13*stride_wave*s)
            # Compose arm lowering with a modest opposing forward/back swing.
            rotate('upper_arm.'+side,(0,1,0),s*.48)
            pb=rig.pose.bones['upper_arm.'+side]
            basis=rig.data.bones[pb.name].matrix_local.to_quaternion()
            pb.rotation_quaternion=pb.rotation_quaternion@(basis.inverted()@Quaternion((1,0,0),stride_wave*s*(.48 if running else .24))@basis)
            rotate('forearm.'+side,(0,0,1),s*(.45 if running else .10))
        rotate('spine',(1,0,0),.15 if running else .025)
        rotate('hair',(1,0,0),.10+wave*.07 if running else wave*.035)
        rotate('skirt.L',(1,0,0),-.06*wave)
        rotate('skirt.R',(1,0,0),.06*wave)
    elif action=='dodge':
        crouch=[.12,.30,.48,.48,.40,.28,.14,.02][index]
        rotate('thigh.L',(1,0,0),-crouch)
        rotate('thigh.R',(1,0,0),-crouch*.75)
        rotate('shin.L',(1,0,0),crouch*1.7)
        rotate('shin.R',(1,0,0),crouch*1.55)
        rotate('spine',(1,0,0),crouch*.65)
        rotate('hair',(1,0,0),-.16*math.sin(index*math.pi/7))
        rotate('upper_arm.R',(0,1,0),-.2)
        rotate('upper_arm.L',(0,1,0),.2)
    elif attack:
        # Frame 4 is the impact to match GeneratedAttacks.timeline_frame.
        lift=[.05,.35,.72,1.05,-.30,-.42,-.16,.05][index]
        sweep=[.12,-.08,-.35,-.55,.95,1.08,.50,.12][index]
        if action=='heavy': lift*=1.25; sweep*=1.10
        if action=='staff':
            lift=[.0,.12,.30,.45,.20,.15,.07,.0][index]
            sweep=[.22,.30,.38,.42,.62,.53,.36,.22][index]
        rotate('upper_arm.R',(0,1,0),lift)
        pb=rig.pose.bones['upper_arm.R']; basis=rig.data.bones[pb.name].matrix_local.to_quaternion()
        pb.rotation_quaternion=pb.rotation_quaternion@(basis.inverted()@Quaternion((0,0,1),sweep)@basis)
        rotate('forearm.R',(0,0,1),-.15 if action!='staff' else -.10)
        rotate('spine',(0,0,1),[-.03,-.06,-.12,-.16,.14,.10,.05,-.03][index])
        rotate('spine',(1,0,0),.045 if index>=4 else -.025)
        rotate('upper_arm.L',(0,1,0),.38 if action!='heavy' else .05)
        rotate('forearm.L',(0,0,1),.25 if action!='heavy' else 1.0)
        rotate('hair',(1,0,0),[0,-.03,-.06,-.08,.08,.12,.07,0][index])
        bend=.08 if action=='sword' else .18 if action=='heavy' else .04
        rotate('thigh.L',(1,0,0),-bend); rotate('shin.L',(1,0,0),bend*1.4)
        rotate('thigh.R',(1,0,0),bend*.7)
        bpy.context.view_layer.update()
        targets=[(-.12,-.15,.60),(-.17,-.10,.65),(-.21,-.025,.74),(-.19,.02,.83),(-.065,-.25,.60),(-.07,-.24,.53),(-.10,-.18,.56),(-.12,-.15,.60)]
        if action=='heavy': targets=[(-.05,-.14,.62),(-.03,-.12,.69),(-.015,-.10,.76),(0,-.06,.84),(-.02,-.22,.62),(-.03,-.21,.54),(-.04,-.17,.59),(-.05,-.14,.62)]
        if action=='staff': targets=[(-.12,-.12,.58),(-.12,-.13,.62),(-.13,-.10,.65),(-.12,-.09,.67),(-.08,-.23,.62),(-.09,-.21,.60),(-.11,-.16,.59),(-.12,-.12,.58)]
        arm_ik('R',targets[index])
        if action=='heavy':
            palm=(rig.pose.bones['hand.R'].head+rig.pose.bones['hand.R'].tail)/2
            arm_ik('L',palm+Vector((.035,.025,.02)))
        bpy.context.view_layer.update()
        direction=Vector([(0,-.45,.75),(0,-.15,1),(0,.20,1),(0,.4,1),(0,-1,.06),(0,-.95,-.25),(0,-.65,.35),(0,-.45,.75)][index]).normalized()
        if action=='staff': direction=Vector((0,-(.3 if index in (4,5) else .1),1)).normalized()
        palm=(rig.pose.bones['hand.R'].head+rig.pose.bones['hand.R'].tail)/2
        origin=palm-direction*.035
        aim_bone('weapon_'+action,origin,origin+direction*.1)
        wp=rig.pose.bones['weapon_'+action]
        roll=Quaternion(direction,.85)@wp.matrix.to_quaternion()
        wp.matrix=Matrix.Translation(origin)@roll.to_matrix().to_4x4()
    bpy.context.view_layer.update()
    # Ground the lower evaluated foot vertices; a fixed world ground origin is
    # preserved rather than recentering or resizing each image's changing bounds.
    evalbody=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    evaluated=evalbody.to_mesh()
    ground=min(v.co.z for v in evaluated.vertices if abs(v.co.x)<.20 and v.co.z<.20)
    evalbody.to_mesh_clear()
    rig.pose.bones['root'].location=rig.data.bones['root'].matrix_local.to_quaternion().inverted()@Vector((0,0,-ground))
    bpy.context.view_layer.update()

for lamp in [o for o in scene.objects if o.type=='LIGHT']:
    lamp.data.energy*=.6
camera=scene.camera
camera.data.ortho_scale=1.85
target=Vector((0,0,.59))
camera.location=target+Vector((-.72,-1,0))*4
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=768; scene.render.resolution_y=768
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
scene.render.fps=24
scene.view_settings.view_transform='Standard'
scene.frame_start=1; scene.frame_end=8
actions=['idle','walk','run','dodge','sword','heavy','staff','idle_sword','idle_heavy','idle_staff']
renderroot=OUT/'renders'; renderroot.mkdir(exist_ok=True)
spec={}
for action in actions:
    step=6 if action.startswith('idle') else 3 if action in ('walk','sword','staff') else 4 if action=='heavy' else 2 if action=='run' else 1
    rig.animation_data_create(); rig.animation_data.action=None
    directory=renderroot/action; directory.mkdir(exist_ok=True)
    indices=[0,4] if args.preview else range(8)
    # Bake all eight poses as editable actions even for a two-frame preview.
    for index in range(8):
        timeline_frame=index*step+1
        scene.frame_set(timeline_frame)
        pose(action,index)
        for pb in rig.pose.bones:
            for attr in ('rotation_quaternion','location','scale'): pb.keyframe_insert(data_path=attr,frame=timeline_frame)
        rig.keyframe_insert(data_path='["grip_right"]',frame=timeline_frame)
        rig.keyframe_insert(data_path='["grip_left"]',frame=timeline_frame)
        if index in indices:
            scene.render.filepath=str(directory/f'{index:03}.png')
            bpy.ops.render.render(write_still=True)
    if action.startswith('idle') or action in ('walk','run'):
        scene.frame_set(8*step+1); pose(action,0)
        for pb in rig.pose.bones:
            for attr in ('rotation_quaternion','location','scale'): pb.keyframe_insert(data_path=attr,frame=8*step+1)
        rig.keyframe_insert(data_path='["grip_right"]',frame=8*step+1)
        rig.keyframe_insert(data_path='["grip_left"]',frame=8*step+1)
    rig.animation_data.action.name='Feiyue_'+action
    track=rig.animation_data.nla_tracks.new(); track.name=action
    strip=track.strips.new(action,1,rig.animation_data.action); track.mute=True
    rig.animation_data.action.use_fake_user=True
    # Model-space ground projection from the camera, shared by every frame.
    from bpy_extras.object_utils import world_to_camera_view
    pivot=world_to_camera_view(scene,camera,Vector((0,0,0)))
    spec[action]={'frame_count':8,'pivot':[pivot.x*768,(1-pivot.y)*768],'standing_height_pixels':1.14614/1.85*768,'camera':'orthographic','facing':1,'blender_frame_step':step,'preview':args.preview}
(renderroot/'render-spec.json').write_text(json.dumps(spec,indent=2))
rig.animation_data.action=bpy.data.actions['Feiyue_idle']
scene.frame_end=49
scene.frame_set(1); pose('idle',0)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='RENDERED'
            area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.context.view_layer.objects.active=rig
readme=bpy.data.texts.new('README_Feiyue')
readme.write('Feiyue cel-shaded 3D-to-2D character. Select Feiyue_Rig and switch its Action in the Action Editor. Actions: '+', '.join('Feiyue_'+a for a in actions)+'. Idle uses frames 1-49; walk 1-25; run 1-17; dodge 1-8; sword/staff 1-22; heavy 1-29. Mouth and weapon visibility, and hand grip properties are baked into each rig action. Use EEVEE for Shader to RGB. Fixed orthographic camera/ground; render source sprites with tools/build_feiyue_character.py. Source UV texture packed. Reduction mesh is a practical prototype, not hand-authored quad topology.')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'feiyue-character.blend'))
print('FEIYUE BUILD COMPLETE',json.dumps(spec))
