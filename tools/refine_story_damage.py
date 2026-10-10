"""Remove whole authored components to make structural broken variants distinct."""
import bpy,pathlib,bmesh
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=ROOT/'art/story-environment/opening-master.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
if bpy.context.scene.get('damage_revision')==1: raise RuntimeError('Damage revision exists; preserve artist edits.')
for name in ['pointed_arch_broken','arcade_broken','slate_roof_broken']:
    for obj in bpy.data.collections[name].objects:
        if obj.type!='MESH': continue
        bm=bmesh.new(); bm.from_mesh(obj.data); unseen=set(bm.faces); remove=[]
        while unseen:
            first=unseen.pop(); component={first}; queue=[first]
            while queue:
                for edge in queue.pop().edges:
                    for neighbour in edge.link_faces:
                        if neighbour in unseen: unseen.remove(neighbour); component.add(neighbour); queue.append(neighbour)
            vertices=set(v for f in component for v in f.verts)
            x=sum(v.co.x for v in vertices)/len(vertices); z=sum(v.co.z for v in vertices)/len(vertices)
            if name!='slate_roof_broken': damaged=x>.15 and z>1.70
            else:
                slate=all(obj.data.materials[f.material_index].name.startswith('Slate') for f in component)
                damaged=slate and ((len(component)>1 and len(vertices)<=8) or (x>.1 and z>.35))
            if damaged: remove.extend(component)
        bmesh.ops.delete(bm,geom=remove,context='FACES'); bm.to_mesh(obj.data); bm.free()
bpy.context.scene['damage_revision']=1; bpy.ops.wm.save_as_mainfile(filepath=str(source))
