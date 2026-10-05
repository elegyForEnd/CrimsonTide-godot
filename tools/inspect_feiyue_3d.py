import bpy, json, math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/feiyue-3d-v1'
PREVIEW = OUT / 'inspection'
PREVIEW.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT / 'feiyue.glb'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
center = (lo + hi) / 2
height = hi.z - lo.z
report = {'bounds_min': list(lo), 'bounds_max': list(hi), 'meshes': [], 'images': [], 'armatures': []}
for o in meshes:
    report['meshes'].append({'name': o.name, 'vertices': len(o.data.vertices), 'polygons': len(o.data.polygons), 'triangles': sum(len(p.vertices)-2 for p in o.data.polygons), 'materials': [m.name if m else None for m in o.data.materials], 'shape_keys': list(o.data.shape_keys.key_blocks.keys()) if o.data.shape_keys else [], 'modifiers': [m.type for m in o.modifiers]})
for o in bpy.context.scene.objects:
    if o.type == 'ARMATURE': report['armatures'].append({'name': o.name, 'bones': len(o.data.bones)})
for im in bpy.data.images:
    report['images'].append({'name': im.name, 'size': list(im.size), 'packed': bool(im.packed_file)})
(PREVIEW / 'model-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in scene.render.bl_rna.properties['engine'].enum_items.keys() else 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 640
scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.world.color = (0.35,0.35,0.35)
scene.view_settings.view_transform = 'Standard'
def aim(obj, target):
    obj.rotation_euler = (target - obj.location).to_track_quat('-Z','Y').to_euler()
for name,offset,power in [('Key', (2,-3,4), 450),('Fill',(-3,-1,2),250),('Rim',(1,3,3),350)]:
    bpy.ops.object.light_add(type='AREA', location=center+Vector(offset)*height)
    lamp=bpy.context.object
    lamp.name=name
    lamp.data.energy=power*height*height
    lamp.data.shape='DISK'
    lamp.data.size=height*3
    aim(lamp,center)
bpy.ops.object.camera_add()
camera=bpy.context.object
camera.name='InspectionCamera'
camera.data.type='ORTHO'
camera.data.ortho_scale=max(height*1.15,(hi.x-lo.x)*1.15*768/640)
scene.camera=camera
for name, direction in [('front',(0,-1,0)),('back',(0,1,0)),('side',(-1,0,0)),('three-quarter',(0.65,-1,0.15))]:
    camera.location=center+Vector(direction).normalized()*height*4
    aim(camera,center)
    scene.render.filepath=str(PREVIEW / (name+'.png'))
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(PREVIEW / 'feiyue-inspection.blend'))
print(json.dumps(report))
