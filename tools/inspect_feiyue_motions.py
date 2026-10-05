import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/feiyue-3d-v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'feiyue-character.blend'))
target=bpy.data.objects['Feiyue_Rig']
report={'target':{'matrix':list(map(list,target.matrix_world)),'bones':{b.name:{'head':list(b.head_local),'tail':list(b.tail_local)} for b in target.data.bones}},'sources':[]}
src=OUT/'motion-sources/kaykit-free-1.1'
for filename in ['Rig_Medium_CombatMelee.glb','Rig_Medium_CombatRanged.glb','Rig_Medium_MovementBasic.glb','Rig_Medium_MovementAdvanced.glb','Rig_Medium_General.glb']:
    before=set(bpy.data.objects); actions=set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(next(src.rglob(filename))))
    rig=next(o for o in set(bpy.data.objects)-before if o.type=='ARMATURE')
    entry={'file':filename,'rig':rig.name,'matrix':list(map(list,rig.matrix_world)),'bones':{b.name:{'parent':b.parent.name if b.parent else None,'head':list(b.head_local),'tail':list(b.tail_local)} for b in rig.data.bones},'actions':{a.name:list(a.frame_range) for a in set(bpy.data.actions)-actions}}
    if 'CombatMelee' in filename:
        from mathutils import Vector
        entry['sample_poses']={}
        for clip in ['Melee_1H_Attack_Chop','Melee_2H_Attack_Chop','Melee_2H_Idle']:
            action=next(a for a in set(bpy.data.actions)-actions if a.name==clip)
            rig.animation_data.action=action
            for track in rig.animation_data.nla_tracks: track.mute=True
            values=[]
            for phase in [0,.25,.5,.75,1]:
                frame=action.frame_range[1]*phase
                bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
                pb=rig.pose.bones['handslot.r']
                values.append({'phase':phase,'palm':list(pb.head),'axes':[list(pb.matrix.to_quaternion()@Vector(v)) for v in [(1,0,0),(0,1,0),(0,0,1)]],'upper':list(rig.pose.bones['upperarm.r'].tail),'hand':list(rig.pose.bones['hand.r'].head)})
            entry['sample_poses'][clip]=values
    report['sources'].append(entry)
    for o in set(bpy.data.objects)-before: bpy.data.objects.remove(o,do_unlink=True)
(OUT/'inspection/motion-rigs.json').write_text(json.dumps(report,indent=2))
print('MOTION RIG REPORT SAVED')
