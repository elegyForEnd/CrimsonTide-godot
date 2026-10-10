"""Edit the master terrain grid so the existing stair lower landing remains level."""
import bpy,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
path=ROOT/'art/story-environment/opening-terrain.blend'
bpy.ops.wm.open_mainfile(filepath=str(path))
obj=bpy.data.objects['Terrain_1']
for vertex in obj.data.vertices:
    x=vertex.co.x*100; y=-vertex.co.y*100
    if 3070<x<3690 and 1650<y<2220:
        distance=min(x-3070,3690-x,y-1650,2220-y)
        t=max(0,min(1,distance/110)); vertex.co.z*=1-t*t*(3-2*t)
bpy.ops.wm.save_as_mainfile(filepath=str(path))
