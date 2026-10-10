"""Create editable terrain grids once. Export edited vertices separately."""
import bpy, pathlib, math, json
ROOT=pathlib.Path(__file__).resolve().parents[1]
dest=ROOT/'art/story-environment/opening-terrain.blend'
if dest.exists(): raise RuntimeError('Editable terrain exists; use export_story_terrain.py after edits.')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for stage,w,d in [(0,2200,2000),(1,4800,4800),(7,4800,4800)]:
    spacing=50; nx=w//spacing+1; ny=d//spacing+1; heights=[]; verts=[]
    shore=[]
    if stage==1:
        left=[]; right=[]
        for y in range(1050,4151,100):
            x=440+100*math.sin(y*.0021); left.append([round(x-65,2),y]); right.append([round(x+65,2),y])
        shore=left+list(reversed(right))
    for iy in range(ny):
        for ix in range(nx):
            x=ix*spacing; y=iy*spacing
            edge=min(x,y,w-x,d-y); blend=min(1,max(0,edge/250))
            if stage==0: h=0 # Foundations and drains are separate geometry.
            elif stage==1:
                h=(110*math.exp(-((x-4170)/750)**2-((y-960)/850)**2)+65*math.exp(-((x-700)/670)**2-((y-3500)/700)**2)-24*math.exp(-((x-1680)/600)**2-((y-2950)/600)**2))*blend
                if 950<y<4250: h-=28*math.exp(-((x-(440+100*math.sin(y*.0021)))/160)**2)*blend
                h+=8*math.sin(x*.004)*math.sin(y*.003)*blend
            else: h=(5*math.sin(x*.004)+4*math.cos(y*.005))*blend
            heights.append(round(h,3)); verts.append((x*.01,-y*.01,h*.01))
    faces=[]
    for iy in range(ny-1):
        for ix in range(nx-1):
            k=iy*nx+ix; faces.append((k,k+nx,k+nx+1,k+1))
    data=bpy.data.meshes.new('Authored height grid'); data.from_pydata(verts,[],faces); data.update()
    obj=bpy.data.objects.new('Terrain_%d'%stage,data); bpy.context.collection.objects.link(obj)
    obj.location.x=stage*60; obj['stage']=stage; obj['width']=nx; obj['depth']=ny; obj['spacing']=spacing; obj['shorelines']=json.dumps([shore] if shore else [])
    (ROOT/f'resources/story-terrain-{stage}.json').write_text(json.dumps({'spacing':spacing,'width':nx,'depth':ny,'heights':heights,'shorelines':[shore] if shore else []},separators=(',',':')),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(dest))
