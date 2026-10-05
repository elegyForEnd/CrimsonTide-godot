"""Create a non-destructive static cel-shading proof from the imported model."""
import bpy, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/feiyue-3d-v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT / 'inspection/feiyue-inspection.blend'))
scene = bpy.context.scene
mesh = next(o for o in scene.objects if o.type == 'MESH')
mesh.name = 'Feiyue_Generated_Source'
source_mat = mesh.data.materials[0]
bsdf = next(n for n in source_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
color_link = bsdf.inputs['Base Color'].links[0]
color_image = color_link.from_node.image
mat = bpy.data.materials.new('Feiyue_Cel_Prototype')
mat.use_nodes = True
nodes = mat.node_tree.nodes
nodes.clear()
links = mat.node_tree.links
tex = nodes.new('ShaderNodeTexImage')
tex.image = color_image
tex.location = (-600,150)
tex.label = 'Original base color; PBR normal and metallic excluded'
diff = nodes.new('ShaderNodeBsdfDiffuse')
diff.inputs['Color'].default_value = (1,1,1,1)
diff.inputs['Roughness'].default_value = 0
diff.location = (-600,-150)
convert = nodes.new('ShaderNodeShaderToRGB')
convert.location = (-400,-150)
links.new(diff.outputs[0],convert.inputs[0])
ramp = nodes.new('ShaderNodeValToRGB')
ramp.location = (-200,-150)
ramp.color_ramp.interpolation = 'CONSTANT'
ramp.color_ramp.elements[0].position = 0
ramp.color_ramp.elements[0].color = (0.64,0.59,0.70,1)
ramp.color_ramp.elements[1].position = 0.43
ramp.color_ramp.elements[1].color = (1,1,1,1)
links.new(convert.outputs[0],ramp.inputs[0])
multiply = nodes.new('ShaderNodeMixRGB')
multiply.blend_type = 'MULTIPLY'
multiply.inputs[0].default_value = 1
multiply.location = (100,150)
links.new(tex.outputs['Color'],multiply.inputs[1])
links.new(ramp.outputs['Color'],multiply.inputs[2])
emit = nodes.new('ShaderNodeEmission')
emit.location = (350,150)
links.new(multiply.outputs[0],emit.inputs['Color'])
output = nodes.new('ShaderNodeOutputMaterial')
output.location = (550,150)
links.new(emit.outputs[0],output.inputs['Surface'])
mesh.data.materials.clear()
mesh.data.materials.append(mat)
# Keep original dense geometry intact for this appearance proof. Rigging/retopology
# is a separate stage; decimation alone cannot create deformation-ready topology.
scene.view_settings.view_transform = 'Standard'
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
points = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
center = (lo + hi)/2
height = hi.z-lo.z
camera = scene.camera
for name,direction in [('toon-front',(0,-1,0)),('toon-three-quarter',(0.65,-1,0.10))]:
    camera.location = center + Vector(direction).normalized()*height*4
    camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(OUT / (name+'.png'))
    bpy.ops.render.render(write_still=True)
# Present an uncluttered material preview when the blend file is opened.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.shading.type = 'MATERIAL'
            area.spaces.active.region_3d.view_distance = height*2.2
            area.spaces.active.region_3d.view_location = center
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'feiyue-toon-preview.blend'))
print('STATIC_TOON_PROOF_COMPLETE; rigging and gameplay animation are not yet present')
