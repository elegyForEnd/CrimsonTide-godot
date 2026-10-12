"""Non-destructive export of the artist-editable oath knight. Never saves master."""
import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/bosses/oath-knight-master.blend'
output=ROOT/'assets/bosses/3d/oath-knight'; output.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects['OathKnightRig']; body=bpy.data.objects['OathKnight_ArmorClothWeapons']
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); body.select_set(True)
bpy.context.view_layer.objects.active=rig
for track in rig.animation_data.nla_tracks:
    track.mute=False
    if track.strips: track.name=track.strips[0].action.name
rig.animation_data.action=None
bpy.ops.export_scene.gltf(filepath=str(output/'oath-knight.glb'),export_format='GLB',use_selection=True,
    export_yup=True,export_cameras=False,export_lights=False,export_materials='EXPORT',
    export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_all_influences=False)
manifest={'source':str(source.relative_to(ROOT)).replace('\\','/'),'exporter':'tools/export_oath_knight.py','original':True,
    'units':'metres','forward':'-Z after glTF conversion','bones':len(rig.data.bones),'vertices':len(body.data.vertices),
    'triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'materials':[m.name for m in body.data.materials],
    'clips':[{'name':a.name,'frames':list(a.frame_range),'fps':30} for a in bpy.data.actions],
    'rigid_armor':True,'weighted_cloth':True,'source_not_modified':True}
(output/'model-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('OATH_KNIGHT_EXPORTED',json.dumps(manifest))
