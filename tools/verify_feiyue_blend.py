"""Verify saved actions reproduce the rendered sprites without the build code."""
import bpy, json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/feiyue-3d-v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'feiyue-character.blend'))
rig=bpy.data.objects['Feiyue_Rig']
scene=bpy.context.scene
spec=json.loads((OUT/'renders/render-spec.json').read_text())
body=bpy.data.objects['Feiyue_Body']
foot_indices=[v.index for v in body.data.vertices if any(body.vertex_groups[g.group].name.startswith('foot.') and g.weight>.4 for g in v.groups)]
audit=[]
for clip in spec:
    action=bpy.data.actions['Feiyue_'+clip]
    rig.animation_data.action=action
    if 'motion_source' in spec[clip]:
        assert action.get('license')=='CC0 1.0'
        assert spec[clip]['motion_source'] in action.get('motion_source','')
    quats=[]
    for index in range(8):
        scene.frame_set(index*spec[clip]['blender_frame_step']+1)
        bpy.context.view_layer.update()
        evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh=evaluated.to_mesh(); floor=min(mesh.vertices[i].co.z for i in foot_indices); evaluated.to_mesh_clear()
        assert abs(floor)<.001,(clip,index,'foot height',floor)
        held=clip[5:] if clip.startswith('idle_') else clip if clip in ['sword','heavy','staff'] else None
        for weapon in ['sword','heavy','staff']:
            assert (rig.pose.bones['weapon_'+weapon].scale.x>.5)==(held==weapon)
        assert (rig.pose.bones['face_expression'].scale.x>.5)==(clip in ['sword','heavy','staff'] and index in [4,5])
        distance=None
        if held=='heavy':
            r=rig.pose.bones['hand.R']; l=rig.pose.bones['hand.L']
            delta=(l.head+l.tail-r.head-r.tail)/2
            direction=(rig.pose.bones['weapon_heavy'].tail-rig.pose.bones['weapon_heavy'].head).normalized()
            distance=(delta-direction*delta.dot(direction)).length
            if 'motion_source' in spec[clip]:
                assert distance<.005,(clip,index,'floating left grip',distance)
        audit.append({'clip':clip,'frame':index,'ground_error':floor,'heavy_grip_lateral_error':distance})
        quats.append(rig.pose.bones['thigh.L' if clip in ['walk','run','dodge'] else 'upper_arm.R'].rotation_quaternion.copy())
    if clip in ['walk','run','dodge','sword','heavy','staff']:
        assert max(q.rotation_difference(quats[0]).angle for q in quats)>.1,(clip,'motion missing')
(OUT/'inspection/saved-motion-audit.json').write_text(json.dumps(audit,indent=2))
print('SAVED MOTION AUDIT',len(audit),'poses; max heavy grip lateral error',max(a['heavy_grip_lateral_error'] or 0 for a in audit))
for action,index in [('idle',0),('sword',4),('heavy',3),('walk',2)]:
    rig.animation_data.action=bpy.data.actions['Feiyue_'+action]
    scene.frame_set(index*spec[action]['blender_frame_step']+1)
    bpy.context.view_layer.update()
    scene.render.filepath=str(OUT/'inspection'/f'baked-{action}-{index:03}.png')
    bpy.ops.render.render(write_still=True)
print('SAVED ACTION PLAYBACK RENDERED')
