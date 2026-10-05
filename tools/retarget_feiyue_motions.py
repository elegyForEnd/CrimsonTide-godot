"""Retarget CC0 KayKit clips, bake editable actions and render game sprites."""
import bpy, json, math, argparse, sys, shutil
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
from bpy_extras.object_utils import world_to_camera_view

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/feiyue-3d-v1'
parser=argparse.ArgumentParser()
parser.add_argument('--preview',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
base=OUT/'feiyue-procedural-backup.blend'
if not base.exists(): shutil.copy2(OUT/'feiyue-character.blend',base)
bpy.ops.wm.open_mainfile(filepath=str(base))
scene=bpy.context.scene
rig=bpy.data.objects['Feiyue_Rig']; body=bpy.data.objects['Feiyue_Body']
rig.animation_data_clear()
for action in list(bpy.data.actions):
    if action.name.startswith('Feiyue_'): bpy.data.actions.remove(action)
scene.render.fps=24
if args.preview:
    scene.render.resolution_percentage=50
source_root=OUT/'motion-sources/kaykit-free-1.1'
sources={}
for category in ['General','MovementBasic','MovementAdvanced','CombatMelee','CombatRanged']:
    existing=set(bpy.data.objects); oldactions=set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(next(source_root.rglob('Rig_Medium_'+category+'.glb'))))
    objects=set(bpy.data.objects)-existing
    source=next(o for o in objects if o.type=='ARMATURE')
    for track in source.animation_data.nla_tracks: track.mute=True
    actions={a.name:a for a in set(bpy.data.actions)-oldactions}
    for obj in objects: obj.hide_render=True
    sources[category]=(source,actions,objects)

# Absolute orientations collapse KayKit's extra chest/wrist bones into the
# smaller Feiyue rig. Arms are calibrated from A pose to the source T pose.
mapping={'pelvis':'hips','spine':'chest','head':'head'}
for side in ['L','R']:
    s=side.lower()
    mapping.update({'upper_arm.'+side:'upperarm.'+s,'forearm.'+side:'lowerarm.'+s,'hand.'+side:'hand.'+s,'thigh.'+side:'upperleg.'+s,'shin.'+side:'lowerleg.'+s,'foot.'+side:'foot.'+s})

clips={
 'idle':('General','Idle_A',6,True),
 'walk':('MovementBasic','Walking_A',3,True),
 'run':('MovementBasic','Running_A',2,True),
 'dodge':('MovementAdvanced','Dodge_Forward',1,False),
 'sword':('CombatMelee','Melee_1H_Attack_Chop',3,False),
 'heavy':('CombatMelee','Melee_2H_Attack_Chop',4,False),
 'staff':('CombatRanged','Ranged_Magic_Shoot',3,False),
 'idle_sword':('CombatMelee','Melee_1H_Attack_Chop',6,True),
 'idle_heavy':('CombatMelee','Melee_2H_Idle',6,True),
 'idle_staff':('CombatRanged','Ranged_Magic_Shoot',6,True),
}

def set_frame(frame):
    scene.frame_set(math.floor(frame),subframe=frame-math.floor(frame))

def aim(name,head,direction,roll=None):
    rest=rig.data.bones[name]
    q=(rest.tail_local-rest.head_local).rotation_difference(direction)@rest.matrix_local.to_quaternion()
    if roll is not None: q=Quaternion(direction.normalized(),roll)@q
    rig.pose.bones[name].matrix=Matrix.Translation(head)@q.to_matrix().to_4x4()
    bpy.context.view_layer.update()

def ik(side,target):
    upper='upper_arm.'+side; lower='forearm.'+side
    shoulder=rig.pose.bones[upper].head.copy()
    a=rig.data.bones[upper].length; b=rig.data.bones[lower].length
    delta=target-shoulder; distance=max(.015,min(delta.length,a+b-.002))
    direction=delta.normalized()
    along=(a*a-b*b+distance*distance)/(2*distance)
    hint=Vector((1 if side=='L' else -1,.35,-.65))
    perpendicular=(hint-direction*hint.dot(direction)).normalized()
    elbow=shoulder+direction*along+perpendicular*math.sqrt(max(0,a*a-along*along))
    aim(upper,shoulder,elbow-shoulder)
    aim(lower,elbow,shoulder+direction*distance-elbow)

def pose(action,index,phase):
    category,clip,step,loop=clips[action]
    source,actions,objects=sources[category]
    motion=actions[clip]; source.animation_data.action=motion
    start,end=motion.frame_range
    # Frame 4 matches combat's damage tick; retain full preparation/recovery.
    sample=phase
    if action=='sword':
        sample=[0,.16,.33,.50,.67,.78,.89,1][index]
    if action.startswith('idle_') and action!='idle_heavy': sample=0
    set_frame(start+(end-start)*sample)
    for pb in rig.pose.bones:
        pb.location=(0,0,0); pb.rotation_quaternion=Quaternion(); pb.scale=(1,1,1)
    bpy.context.view_layer.update()
    for target_name,source_name in mapping.items():
        dst=rig.pose.bones[target_name]; src=source.pose.bones[source_name]
        rest=rig.data.bones[target_name]
        src_rest=source.data.bones[source_name]
        delta=src.matrix.to_quaternion()@src_rest.matrix_local.to_quaternion().inverted()
        if target_name.startswith(('upper_arm.','forearm.','hand.')):
            calibration=(rest.tail_local-rest.head_local).rotation_difference(src_rest.tail_local-src_rest.head_local)
        else: calibration=Quaternion()
        orientation=delta@calibration@rest.matrix_local.to_quaternion()
        head=dst.head.copy()
        dst.matrix=Matrix.Translation(head)@orientation.to_matrix().to_4x4()
        bpy.context.view_layer.update()
    held=action[5:] if action.startswith('idle_') else action if action in ['sword','heavy','staff'] else None
    rig['grip_right']=float(held is not None); rig['grip_left']=float(held=='heavy')
    for weapon in ['sword','heavy','staff']:
        rig.pose.bones['weapon_'+weapon].scale=(1,1,1) if held==weapon else (.00001,)*3
    rig.pose.bones['face_expression'].scale=(1,1,1) if action in ['sword','heavy','staff'] and index in [4,5] else (.00001,)*3
    if held:
        # KayKit's hand slot is the rigid weapon orientation reference. Its
        # local Y axis points from the grip along a sword blade.
        slot=source.pose.bones['handslot.r']
        direction=(slot.matrix.to_quaternion()@Vector((0,1,0))).normalized()
        if held=='staff':
            # Spell clips animate an empty casting hand: hold the staff upright
            # with the right hand while keeping the casting body's motion.
            direction=Vector((0,-.15,1)).normalized()
        right=rig.pose.bones['hand.R']
        hand_orientation=right.matrix.to_quaternion().copy()
        wrist=right.head.copy()
        if held=='heavy':
            # The short target arms cannot reach KayKit's wide two-hand pose.
            # Bring the grip between the shoulders while preserving lift/twist.
            wrist.x=max(-.045,min(.045,wrist.x))
            wrist.y=max(-.20,min(-.12,wrist.y))
            wrist.z=max(.55,min(.83,wrist.z))
            left_orientation=hand_orientation@Quaternion((0,0,1),math.pi)
            hand_offset=(hand_orientation@Vector((0,1,0)))*rig.data.bones['hand.R'].length*.5-direction*.05-(left_orientation@Vector((0,1,0)))*rig.data.bones['hand.L'].length*.5
            # Project the grip into the intersection of both arm reach balls.
            # This avoids an apparently attached wrist with a floating palm.
            for _ in range(20):
                for side,offset in [('R',Vector((0,0,0))),('L',hand_offset)]:
                    shoulder=rig.pose.bones['upper_arm.'+side].head-offset
                    reach=rig.data.bones['upper_arm.'+side].length+rig.data.bones['forearm.'+side].length-.006
                    delta=wrist-shoulder
                    if delta.length>reach: wrist=shoulder+delta.normalized()*reach
        else:
            wrist.y=min(wrist.y,-.12)
        ik('R',wrist)
        right.matrix=Matrix.Translation(right.head)@hand_orientation.to_matrix().to_4x4()
        bpy.context.view_layer.update()
        palm=(rig.pose.bones['hand.R'].head+rig.pose.bones['hand.R'].tail)/2
        if held=='heavy':
            # Keep both palms on the same grip despite different arm lengths.
            left_orientation=hand_orientation@Quaternion((0,0,1),math.pi)
            left_palm=palm-direction*.05
            left_wrist=left_palm-(left_orientation@Vector((0,1,0)))*rig.data.bones['hand.L'].length*.5
            ik('L',left_wrist)
            hand=rig.pose.bones['hand.L']
            hand.matrix=Matrix.Translation(hand.head)@left_orientation.to_matrix().to_4x4()
            bpy.context.view_layer.update()
        aim('weapon_'+held,palm-direction*.035,direction,.85)
    wave=math.sin(phase*math.tau)
    if action.startswith('idle_'):
        rig.pose.bones['spine'].scale=(1,1+.004*wave,1)
    for name,amount in [('hair',.045 if action in ['run','dodge','sword','heavy'] else .02),('skirt.L',.035),('skirt.R',-.035)]:
        rest=rig.data.bones[name].matrix_local.to_quaternion()
        rig.pose.bones[name].rotation_quaternion=rest.inverted()@Quaternion((1,0,0),wave*amount)@rest
    bpy.context.view_layer.update()
    # Use only foot-weighted vertices to ground the actual shoes, even in a
    # wide stance. Source root translation is omitted; Godot drives movement.
    indices=[v.index for v in body.data.vertices if any(body.vertex_groups[g.group].name.startswith('foot.') and g.weight>.4 for g in v.groups)]
    evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated.to_mesh()
    floor=min(mesh.vertices[i].co.z for i in indices)
    evaluated.to_mesh_clear()
    rig.pose.bones['root'].location=rig.data.bones['root'].matrix_local.to_quaternion().inverted()@Vector((0,0,-floor))
    bpy.context.view_layer.update()

renderroot=OUT/('motion-preview' if args.preview else 'renders')
renderroot.mkdir(exist_ok=True)
spec={}
for action,(category,clip,step,loop) in clips.items():
    rig.animation_data_create(); rig.animation_data.action=None
    directory=renderroot/action; directory.mkdir(exist_ok=True)
    for index in range(9 if loop else 8):
        rig.animation_data.action=None
        phase=(index%8)/8 if loop else index/7
        pose(action,index%8,phase)
        frame=1+index*step
        if index>0: rig.animation_data.action=output_action
        for pb in rig.pose.bones:
            for attr in ['location','rotation_quaternion','scale']: pb.keyframe_insert(data_path=attr,frame=frame)
        for prop in ['grip_right','grip_left']: rig.keyframe_insert(data_path='["'+prop+'"]',frame=frame)
        # Source timeline evaluation must never evaluate partially baked target
        # action: detach it until the entire clip has been authored.
        baked=rig.animation_data.action
        if index<8 and (not args.preview or index in [0,2,4,6]):
            scene.frame_set(frame)
            scene.render.filepath=str(directory/f'{index:03}.png')
            bpy.ops.render.render(write_still=True)
        rig.animation_data.action=None
        if index==0: output_action=baked
        elif baked!=output_action:
            # Reuse the same action for subsequent key insertions.
            raise RuntimeError('Target action changed during baking')
        rig.animation_data.action=output_action
    output_action.name='Feiyue_'+action
    output_action.use_fake_user=True
    output_action['motion_source']='KayKit Character Animations 1.1 / '+clip
    output_action['license']='CC0 1.0'
    track=rig.animation_data.nla_tracks.new(); track.name=action; track.mute=True
    track.strips.new(action,1,output_action)
    rig.animation_data.action=None
    pivot=world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
    spec[action]={'frame_count':8,'pivot':[pivot.x*768,(1-pivot.y)*768],'standing_height_pixels':1.14614/1.85*768,'camera':'orthographic','facing':1,'blender_frame_step':step,'preview':args.preview,'motion_source':clip,'license':'CC0 1.0'}
    print('RETARGETED',action,clip,flush=True)
(renderroot/'render-spec.json').write_text(json.dumps(spec,indent=2))
for source,actions,objects in sources.values():
    for obj in objects: bpy.data.objects.remove(obj,do_unlink=True)
rig.animation_data.action=bpy.data.actions['Feiyue_idle']
scene.frame_start=1; scene.frame_end=49; scene.frame_set(1)
scene.render.filepath=''
readme=bpy.data.texts.get('README_Feiyue')
readme.clear(); readme.write('Feiyue toon character. The Feiyue_* actions are retargeted from KayKit Character Animations 1.1 (CC0). Source clips and URLs: motion-sources/README.md. All body poses, weapon orientation/visibility, hand grip and exertion mouth are baked into the rig actions. Select Feiyue_Rig and change its action. NLA tracks are muted. Render using EEVEE. Rebuild with tools/retarget_feiyue_motions.py. The original procedural .blend is kept in feiyue-procedural-backup.blend.')
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/('feiyue-motion-preview.blend' if args.preview else 'feiyue-character.blend')))
print('FREE MOTION RETARGET COMPLETE',flush=True)
