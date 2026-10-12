"""Build the ORIGINAL editable armored boss, skin and keyframe clips in Blender.

First creation only. Refuses to overwrite an existing authoritative .blend.
Subsequent artists edit that .blend and run export_oath_knight.py instead.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"art/bosses/oath-knight-master.blend"
if SOURCE.exists(): raise RuntimeError("Editable master already exists; edit it and use export_oath_knight.py.")
SOURCE.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
materials={}
for name in ["steel","brass","blade","leather","cloth"]:
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    for kind in ['albedo','normal','orm']:
        image=bpy.data.images.load(str(ROOT/f"assets/bosses/3d/oath-knight/textures/{name}-{kind}.png"))
        image.colorspace_settings.name='sRGB' if kind=='albedo' else 'Non-Color'
        t=mat.node_tree.nodes.new('ShaderNodeTexImage'); t.image=image
        if kind=='albedo': mat.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
        elif kind=='normal':
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.34
            mat.node_tree.links.new(t.outputs['Color'],normal.inputs['Color']); mat.node_tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])
        else:
            split=mat.node_tree.nodes.new('ShaderNodeSeparateColor'); mat.node_tree.links.new(t.outputs['Color'],split.inputs[0])
            mat.node_tree.links.new(split.outputs['Green'],p.inputs['Roughness']); mat.node_tree.links.new(split.outputs['Blue'],p.inputs['Metallic'])
    materials[name]=mat
mat=bpy.data.materials.new('soul'); mat.use_nodes=True
p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); p.inputs['Base Color'].default_value=(.035,.22,.27,1)
p.inputs['Emission Color'].default_value=(.08,.65,.88,1); p.inputs['Emission Strength'].default_value=2.1
p.inputs['Roughness'].default_value=.27; materials['soul']=mat
parts=[]
def finish(obj, material, bone, bevel=0):
    obj.data.materials.append(materials[material]); obj['bone']=bone
    if bevel:
        mod=obj.modifiers.new('Forged edge bevel','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons: poly.use_smooth=True
    # Every component has UVs, including edge trim and rivets.
    if not obj.data.uv_layers:
        bpy.context.view_layer.objects.active=obj; bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(island_margin=.018); bpy.ops.object.mode_set(mode='OBJECT')
    group=obj.vertex_groups.new(name=bone); group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    parts.append(obj); return obj
def mesh(name,verts,faces,material,bone,bevel=0):
    m=bpy.data.meshes.new(name); m.from_pydata(verts,[],faces); m.update()
    obj=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj; bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    return finish(obj,material,bone,bevel)
def sphere(name,at,size,material,bone,segments=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=6,location=at)
    o=bpy.context.object; o.name=name; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,material,bone)
def tube(name,points,radius,material,bone):
    cu=bpy.data.curves.new(name,'CURVE'); cu.dimensions='3D'; cu.resolution_u=1
    cu.bevel_depth=radius; cu.bevel_resolution=1; cu.resolution_u=1
    s=cu.splines.new('POLY'); s.points.add(len(points)-1)
    for p,v in zip(s.points,points): p.co=(*v,1)
    ob=bpy.data.objects.new(name,cu); bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active=ob; bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
    bpy.ops.object.convert(target='MESH'); return finish(ob,material,bone)
def plate(name,outline,depth,material,bone):
    verts=[(x,y,z) for x,y,z in outline]+[(x,y+depth,z) for x,y,z in outline]
    n=len(outline); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,material,bone,.007)
def loft(name,rings,material,bone,segments=28):
    # rings = z,cx,cy,rx,ry; gently fluted forging, full closed outward shell.
    verts=[]; faces=[]
    for z,cx,cy,rx,ry in rings:
        for i in range(segments):
            a=i*math.tau/segments; flute=1+.022*math.cos(a*8)
            verts.append((cx+rx*math.cos(a)*flute,cy+ry*math.sin(a)*flute,z))
    for j in range(len(rings)-1):
        for i in range(segments):
            a=j*segments+i; b=j*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces += [tuple(range(segments-1,-1,-1)),tuple((len(rings)-1)*segments+i for i in range(segments))]
    return mesh(name,verts,faces,material,bone,.008)
def ellipse(name,z,cx,cy,rx,ry,material,bone):
    return tube(name,[(cx+rx*math.cos(i*math.tau/40),cy+ry*math.sin(i*math.tau/40),z) for i in range(41)],.012,material,bone)
def emblem(cx,cy,z,size,bone):
    # Architectural quatrefoil seal, actual geometry instead of a painted circle.
    for angle in [0,math.pi/2,math.pi,math.pi*1.5]:
        points=[]
        for i in range(17):
            a=i*math.tau/16
            points.append((cx+size*(math.cos(angle)*.5+math.cos(a)*.43),cy,z+size*(math.sin(angle)*.5+math.sin(a)*.43)))
        tube('Oath quatrefoil',points,.009,'brass',bone)
    tube('Seal cross',[(cx,cy,z-size),(cx,cy-.018,z+size)],.015,'brass',bone)
    tube('Seal arms',[(cx-size*.7,cy,z),(cx+size*.7,cy,z)],.011,'brass',bone)

# Torso: continuous fitted cuirass with waist, sternum ridge, articulated faulds.
loft('Gambeson underlayer',[(1.30,0,0,.34,.23),(1.7,0,0,.37,.24),(2.22,0,0,.5,.26)],'leather','spine')
loft('Forged cuirass',[(1.55,0,0,.35,.25),(1.68,0,-.015,.4,.28),(1.91,0,0,.51,.30),(2.16,0,0,.5,.28),(2.30,0,0,.39,.23)],'steel','chest')
for z,rx,ry in [(1.57,.356,.258),(2.19,.484,.285),(2.28,.396,.236)]: ellipse('Cuirass rolled border',z,0,0,rx,ry,'brass','chest')
tube('Sternum ridge',[(0,-.262,1.56),(0,-.33,1.86),(0,-.31,2.13),(0,-.23,2.28)],.016,'brass','chest')
for side in [-1,1]:
    for k in range(3):
        base=.07+k*.105
        pts=[(side*(base+.11),-.29,1.69),(side*(base+.09),-.31,1.93),(side*(base+.055),-.287,2.065),(side*base,-.27,2.16)]
        tube('Gothic breastplate tracery',pts,.011,'brass','chest')
        for z in [1.75,1.9,2.08]: sphere('Breastplate rivet',(side*.365,-.243,z),(.018,.012,.018),'brass','chest',8)
emblem(0,-.345,1.99,.13,'chest')
for k in range(3):
    z=1.50-k*.105; rx=.36+k*.032
    loft('Articulated fauld',[(z-.09,0,0,rx+.025,.272),(z,0,0,rx,.25)],'steel','pelvis')
    ellipse('Fauld edge',z-.082,0,0,rx+.03,.28,'brass','pelvis')
loft('Leather girdle',[(1.5,0,0,.39,.275),(1.59,0,0,.39,.275)],'leather','pelvis')
plate('Belt clasp',[(-.09,-.295,1.50),(.09,-.295,1.50),(.09,-.295,1.59),(-.09,-.295,1.59)],.035,'brass','pelvis')
for i in range(12):
    a=i*math.tau/12
    sphere('Girdle studs',(.39*math.cos(a),.283*math.sin(a),1.55),(.016,.016,.016),'brass','pelvis',8)

# Helmet: narrow raised visor, pointed crest, vent slots and gorget.
loft('Gorget',[(2.24,0,0,.31,.20),(2.32,0,0,.25,.185),(2.39,0,0,.205,.17)],'steel','chest')
ellipse('Gorget lip',2.39,0,0,.21,.175,'brass','chest')
loft('Closed bascinet',[(2.35,0,0,.17,.16),(2.45,0,-.015,.22,.21),(2.69,0,0,.235,.215),(2.81,0,.015,.17,.17),(2.93,0,.025,.035,.065)],'steel','head')
for side in [-1,1]:
    outline=[(side*.014,-.236,2.43),(side*.19,-.204,2.46),(side*.20,-.21,2.64),(side*.10,-.238,2.70),(side*.015,-.257,2.65)]
    plate('Visor cheek',outline,.032,'steel','head')
    tube('Visor brass lip',outline+[outline[0]],.010,'brass','head')
    tube('Soul eye slit',[(side*.027,-.270,2.661),(side*.16,-.239,2.686)],.013,'soul','head')
    for k in range(3):
        vx=side*(.048+k*.04)
        tube('Breathing slit',[(vx,-.251+abs(vx)*.11,2.47),(vx,-.251+abs(vx)*.11,2.60)],.011,'leather','head')
    tube('Crown buttress',[(side*.205,0,2.66),(side*.175,.01,2.86),(side*.09,.03,3.04),(side*.025,.03,3.17)],.017,'brass','head')
plate('Cathedral crest',[(-.035,.00,2.89),(0,-.022,3.20),(.035,.00,2.89),(0,-.055,2.83)],.06,'steel','head')
tube('Visor nose spine',[(0,-.274,2.42),(0,-.279,2.64),(0,-.253,2.71)],.012,'brass','head')

# Limbs: independent articulation, lames, knee cops, finger armor, sabatons.
for side,tag in [(1,'R'),(-1,'L')]:
    upper=f'upper_arm.{tag}'; fore=f'forearm.{tag}'; hand=f'hand.{tag}'
    thigh=f'thigh.{tag}'; shin=f'shin.{tag}'; foot=f'foot.{tag}'
    sphere('Shoulder joint',(side*.57,0,2.18),(.20,.20,.20),'leather',upper)
    for k in range(4):
        cx=side*(.53+k*.075); z=2.22-k*.115
        outline=[(cx-side*.18,-.18,z-.03),(cx+side*.21,-.175,z-.12),(cx+side*.26,-.03,z+.04),(cx+side*.10,.15,z+.17),(cx-side*.13,.10,z+.15)]
        plate('Overlapping pauldron lame',outline,.16,'steel',upper)
        tube('Pauldron rolled edge',outline+[outline[0]],.014,'brass',upper)
        sphere('Pauldron pin',(cx,-.198,z+.03),(.025,.017,.025),'brass',upper,10)
    loft('Rerebrace',[(1.76,side*.84,0,.16,.145),(2.06,side*.70,0,.185,.16)],'steel',upper)
    ellipse('Arm cuff',1.78,side*.835,0,.166,.15,'brass',upper)
    sphere('Elbow cop',(side*.87,-.02,1.77),(.19,.165,.15),'steel',fore)
    plate('Elbow wing',[(side*.91,-.15,1.68),(side*1.09,-.14,1.8),(side*.93,-.15,1.91),(side*.80,-.16,1.79)],.08,'steel',fore)
    loft('Vambrace',[(1.35,side*.95,-.07,.135,.13),(1.48,side*.94,-.05,.17,.15),(1.70,side*.88,-.02,.16,.145)],'steel',fore)
    for z,cx in [(1.38,.949),(1.65,.894)]: ellipse('Vambrace edge',z,side*cx,-.055,.144,.14,'brass',fore)
    tube('Vambrace ridge',[(side*.95,-.202,1.39),(side*.93,-.205,1.54),(side*.88,-.17,1.68)],.010,'brass',fore)
    loft('Gauntlet',[(1.18,side*.96,-.07,.145,.12),(1.32,side*.95,-.07,.14,.14),(1.39,side*.95,-.06,.17,.15)],'steel',hand)
    for finger in range(4):
        fx=side*(.85+finger*.067)
        for joint in range(3):
            sphere('Finger lame',(fx,-.125+joint*.025,1.22-joint*.032),(.029,.045,.029),'steel',hand,8)
        sphere('Knuckle rivet',(fx,-.163,1.24),(.014,.011,.014),'brass',hand,8)
    sphere('Hip mail',(side*.265,0,1.29),(.24,.21,.20),'leather',thigh)
    loft('Cuisse',[(.83,side*.29,0,.16,.175),(1.02,side*.27,0,.205,.19),(1.28,side*.25,0,.235,.22)],'steel',thigh)
    for k in range(3):
        z=1.36-k*.15; cx=side*.28
        outline=[(cx-.20,-.255,z),(cx+.20,-.255,z),(cx+.18,-.28,z-.16),(cx,-.29,z-.22),(cx-.18,-.28,z-.16)]
        plate('Hanging tasset',outline,.055,'steel',thigh)
        tube('Tasset filigree',outline+[outline[0]],.011,'brass',thigh)
    sphere('Knee cop',(side*.3,-.02,.79),(.20,.23,.17),'steel',shin)
    emblem(side*.3,-.253,.80,.075,shin)
    plate('Knee wing',[(side*.40,-.12,.69),(side*.55,-.10,.80),(side*.40,-.12,.93),(side*.32,-.18,.81)],.09,'steel',shin)
    loft('Greave',[(.23,side*.32,0,.145,.15),(.42,side*.32,0,.165,.17),(.70,side*.30,0,.185,.19)],'steel',shin)
    for z in [.28,.65]: ellipse('Greave edging',z,side*.32,0,.163,.175,'brass',shin)
    tube('Greave flute',[(side*.32,-.174,.27),(side*.32,-.193,.50),(side*.30,-.21,.69)],.014,'brass',shin)
    sphere('Leather sole',(side*.33,-.105,.092),(.17,.32,.065),'leather',foot)
    for k in range(5):
        cy=-.34+k*.095; z=.125+k*.019
        loft('Sabatons overlapping plates',[(z,side*.33,cy,.135+k*.008,.08),(z+.075,side*.33,cy,.105+k*.011,.083)],'steel',foot,16)
        ellipse('Sabatons seam',z+.02,side*.33,cy,.14,.084,'brass',foot)

# Sword: diamond cross section and fuller; edge surfaces have their own material.
cx=.97; cy=-.19
loft('Bound sword grip',[(1.19,cx,cy,.044,.044),(1.44,cx,cy,.044,.044)],'leather','hand.R',16)
for k in range(9): ellipse('Grip winding',1.21+k*.025,cx,cy,.047,.047,'brass','hand.R')
sphere('Sword pommel',(cx,cy,1.49),(.082,.075,.105),'brass','hand.R',16)
outline=[(cx-.37,cy-.055,1.16),(cx-.29,cy-.055,1.27),(cx-.06,cy-.055,1.25),(cx,cy-.055,1.21),(cx+.06,cy-.055,1.25),(cx+.29,cy-.055,1.27),(cx+.37,cy-.055,1.16),(cx+.27,cy-.055,1.20),(cx-.27,cy-.055,1.20)]
plate('Gothic quillons',outline,.11,'brass','hand.R')
verts=[]
for z,width in [(1.15,.135),(.98,.15),(.25,.095),(-.20,0)]:
    verts.extend([(cx-width,cy,z),(cx,cy-.041,z),(cx+width,cy,z),(cx,cy+.041,z)])
faces=[]
for j in range(3):
    for i in range(4): faces.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
faces.extend([(3,2,1,0),(12,13,14,15)])
mesh('Forged diamond blade',verts,faces,'blade','hand.R',.002)
tube('Recessed blade fuller',[(cx,cy-.044,.31),(cx,cy-.045,.95),(cx,cy-.045,1.10)],.009,'steel','hand.R')
tube('Sword luminous oath',[(cx,cy-.049,.47),(cx,cy-.050,.87)],.005,'soul','hand.R')

# Heater shield: curved 3D body, rim, boss, structural straps and raised crest.
sx=-1.0; sy=-.255
outline=[(sx-.37,sy,1.96),(sx+.36,sy,1.96),(sx+.40,sy-.03,1.60),(sx+.29,sy-.02,1.03),(sx,sy-.035,.76),(sx-.29,sy-.02,1.03),(sx-.40,sy-.03,1.60)]
plate('Heater shield',outline,.085,'steel','hand.L')
tube('Shield outer rim',outline+[outline[0]],.026,'brass','hand.L')
inner=[(sx+(x-sx)*.87,y-.024,1.43+(z-1.43)*.87) for x,y,z in outline]
tube('Shield inner border',inner+[inner[0]],.011,'brass','hand.L')
emblem(sx,sy-.10,1.43,.24,'hand.L')
for side in [-1,1]:
    tube('Shield pointed arch',[(sx+side*.24,sy-.07,1.10),(sx+side*.25,sy-.07,1.62),(sx+side*.18,sy-.07,1.78),(sx,sy-.07,1.87)],.012,'brass','hand.L')
for x,y,z in outline: sphere('Shield rim rivet',(x,y-.033,z),(.024,.014,.024),'brass','hand.L',8)
for z in [1.18,1.64]: tube('Shield rear strap',[(sx-.24,sy+.11,z),(sx,sy+.20,z),(sx+.24,sy+.11,z)],.034,'leather','hand.L')

# Sewn cloth panels: actual jagged hems and sewn border geometry, skinned folds.
def cloth_panel(name,width,top,bottom,back,bone):
    nx=18; nz=18; verts=[]; faces=[]
    for j in range(nz+1):
        t=j/nz
        for i in range(nx+1):
            u=i/nx; xx=(u-.5)*width*(.65+.35*t)
            zz=top+(bottom-top)*t
            if j==nz: zz+=.10*math.sin(i*2.7)+.11*(i%3==0)
            yy=(.22+.34*t if back else -.30-.055*t)+math.sin(u*math.tau*4+t*.6)*(.022+.045*t)
            if back: yy+=.08*math.sin(t*math.pi)
            verts.append((xx,yy,zz))
    for j in range(nz):
        for i in range(nx):
            if j>=nz-2 and ((i+j*3)%11==0 or (j==nz-1 and i%5==0)): continue
            a=j*(nx+1)+i; faces.append((a,a+1,a+nx+2,a+nx+1))
    ob=mesh(name,verts,faces,'cloth',bone)
    solid=ob.modifiers.new('Sewn cloth thickness','SOLIDIFY'); solid.thickness=.009
    bpy.context.view_layer.objects.active=ob; bpy.ops.object.modifier_apply(modifier=solid.name)
    ob.vertex_groups.clear()
    upper=ob.vertex_groups.new(name=bone); lower=ob.vertex_groups.new(name='cloak' if back else 'tabard')
    for v in ob.data.vertices:
        t=max(0,min(1,(top-v.co.z)/(top-bottom))); w=max(0,min(1,(t-.15)/.70))
        upper.add([v.index],1-w,'REPLACE'); lower.add([v.index],w,'REPLACE')
    for side in [-1,1]:
        pts=[(side*width*(.5)*(.65+.35*j/nz),(.22+.34*j/nz if back else -.308-.055*j/nz),top+(bottom-top)*j/nz) for j in range(nz+1)]
        tube('Sewn brass thread',pts,.005,'brass','cloak' if back else 'tabard')
    return ob
cloth_panel('Split torn cloak',1.16,2.27,.36,True,'chest')
cloth_panel('Tattered oath tabard',.42,1.47,.47,False,'pelvis')
emblem(0,-.383,.89,.09,'tabard')
for side in [-1,1]:
    sphere('Cloak clasp',(side*.41,-.20,2.22),(.08,.026,.08),'brass','chest',16)
    emblem(side*.41,-.231,2.22,.058,'chest')
    tube('Cloak chain',[(side*.40,-.22,2.22),(side*.23,-.32,2.13),(0,-.34,2.09)],.012,'brass','chest')

# Soul seams are sculpted in the armor. Low intensity until actual phase change.
for side in [-1,1]:
    tube('Phase fracture',[(side*.22,-.289,1.82),(side*.26,-.302,1.90),(side*.21,-.30,1.96),(side*.28,-.28,2.08)],.006,'soul','chest')

# Combine into ONE skinned mesh, retaining material slots and per-bone weights.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts: ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); body=bpy.context.object
body.name='OathKnight_ArmorClothWeapons'; bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
arm_data=bpy.data.armatures.new('OathKnightSkeleton'); arm=bpy.data.objects.new('OathKnightRig',arm_data)
bpy.context.collection.objects.link(arm); bpy.context.view_layer.objects.active=arm
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
spec=[('root',(0,0,0),(0,0,.35),None),('pelvis',(0,0,1.3),(0,0,1.62),'root'),('spine',(0,0,1.62),(0,0,1.95),'pelvis'),('chest',(0,0,1.95),(0,0,2.3),'spine'),('head',(0,0,2.32),(0,0,2.85),'chest'),('cloak',(0,.22,2.12),(0,.45,.60),'chest'),('tabard',(0,-.30,1.45),(0,-.36,.55),'pelvis')]
for side,tag in [(1,'R'),(-1,'L')]:
    spec += [(f'upper_arm.{tag}',(side*.56,0,2.22),(side*.87,0,1.77),'chest'),(f'forearm.{tag}',(side*.87,0,1.77),(side*.95,-.06,1.35),f'upper_arm.{tag}'),(f'hand.{tag}',(side*.95,-.06,1.35),(side*.96,-.06,1.16),f'forearm.{tag}'),(f'thigh.{tag}',(side*.25,0,1.30),(side*.3,0,.79),'pelvis'),(f'shin.{tag}',(side*.3,0,.79),(side*.32,0,.23),f'thigh.{tag}'),(f'foot.{tag}',(side*.32,0,.23),(side*.32,-.35,.13),f'shin.{tag}')]
for name,head,tail,parent in spec:
    bone=arm_data.edit_bones.new(name); bone.head=head; bone.tail=tail
    if parent: bone.parent=arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
body.parent=arm; mod=body.modifiers.new('Real skeletal deformation','ARMATURE'); mod.object=arm
arm['ct_asset']='oath-knight'; arm['metres']=True
for p in arm.pose.bones: p.rotation_mode='QUATERNION'
def pose(frame,angles=None,root_z=0,root_x=0):
    angles=angles or {}
    for b in arm.pose.bones:
        world=Euler(tuple(math.radians(v) for v in angles.get(b.name,(0,0,0))),'XYZ').to_matrix()
        rest=b.bone.matrix_local.to_3x3()
        b.rotation_quaternion=(rest.inverted()@world@rest).to_quaternion()
        b.location=(0,0,0)
        if b.name=='root': b.location=(root_x,root_z,0) # local Y is world Z
        b.keyframe_insert(data_path='rotation_quaternion',frame=frame); b.keyframe_insert(data_path='location',frame=frame)
def clip(name,keys):
    arm.animation_data_create(); arm.animation_data.action=bpy.data.actions.new(name)
    for frame,angles,z in keys: pose(frame,angles,z)
    action=arm.animation_data.action; action.use_fake_user=True
    strip=arm.animation_data.nla_tracks.new().strips.new(name,1,action); strip.name=name
    strip.action_frame_start=keys[0][0]; strip.action_frame_end=keys[-1][0]; strip.mute=False
    arm.animation_data.nla_tracks[-1].mute=True
    return action
neutral={'upper_arm.R':(-6,0,-5),'forearm.R':(-8,0,0),'hand.R':(-6,0,0),'upper_arm.L':(-9,0,5),'forearm.L':(-15,0,0)}
clip('idle',[(1,neutral,0),(31,{**neutral,'chest':(1.2,0,0),'head':(0,0,-2),'cloak':(2,0,1)},.015),(61,neutral,0)])
walk=[]
for frame,angle in [(1,23),(9,0),(17,-23),(25,0),(33,23)]:
    walk.append((frame,{**neutral,'thigh.R':(angle,0,0),'thigh.L':(-angle,0,0),'shin.R':(max(0,-angle)*1.6,0,0),'shin.L':(max(0,angle)*1.6,0,0),'upper_arm.R':(-angle*.5,0,-5),'upper_arm.L':(angle*.45,0,5),'cloak':(4,0,angle*.1)},.025 if angle==0 else 0))
clip('walk',walk)
charge={**neutral,'chest':(-7,0,-12),'upper_arm.R':(-137,5,-22),'forearm.R':(-32,0,8),'hand.R':(35,0,-15),'upper_arm.L':(-35,0,-10),'thigh.R':(-10,0,0),'shin.R':(16,0,0),'cloak':(-7,0,3)}
strike={**neutral,'chest':(22,0,27),'upper_arm.R':(-40,-20,75),'forearm.R':(-35,0,0),'hand.R':(-12,0,0),'upper_arm.L':(-12,0,22),'cloak':(8,0,-9)}
clip('charge',[(1,neutral,0),(21,charge,-.03),(31,{**charge,'head':(8,0,-6)},-.045)])
clip('slash',[(1,charge,-.02),(5,{**charge,'chest':(-3,0,-26)},-.015),(9,strike,-.08),(19,{**strike,'upper_arm.R':(-18,0,65)},-.05),(31,neutral,0)])
clip('sweep',[(1,{**charge,'chest':(0,0,-38),'upper_arm.R':(-85,0,-80)},-.03),(9,{**strike,'chest':(5,0,45),'upper_arm.R':(-75,0,90)},-.07),(20,{**neutral,'chest':(3,0,25)},-.025),(31,neutral,0)])
clip('thrust',[(1,{**neutral,'chest':(-9,0,-18),'forearm.R':(-97,0,0),'hand.R':(-65,0,0)},0),(8,{**neutral,'chest':(17,0,8),'upper_arm.R':(-92,0,0),'forearm.R':(0,0,0),'hand.R':(-92,0,0)},-.04),(19,{**neutral,'upper_arm.R':(-82,0,0),'hand.R':(-80,0,0)},-.025),(31,neutral,0)])
clip('slam',[(1,charge,0),(7,{**charge,'chest':(-15,0,0)},.04),(11,{**strike,'chest':(33,0,0),'upper_arm.R':(-35,0,0),'forearm.R':(-7,0,0),'hand.R':(0,0,0)},-.15),(21,{**neutral,'chest':(22,0,0)},-.08),(37,neutral,0)])
guard={**neutral,'upper_arm.L':(-65,0,-17),'forearm.L':(-65,0,22),'chest':(3,0,12),'upper_arm.R':(-65,0,0),'forearm.R':(-52,0,0),'hand.R':(-40,0,0)}
clip('guard',[(1,neutral,0),(10,guard,-.045),(31,guard,-.045)])
clip('hit',[(1,neutral,0),(5,{**neutral,'chest':(-12,0,-8),'head':(-14,0,5),'cloak':(-10,0,4)},-.02),(16,neutral,0)])
clip('break',[(1,guard,0),(8,{**neutral,'chest':(28,0,0),'head':(15,0,0),'upper_arm.L':(10,0,30),'thigh.R':(-32,0,0),'shin.R':(75,0,0),'cloak':(12,0,0)},-.26),(31,{**neutral,'chest':(17,0,0),'head':(13,0,0)},-.12),(46,neutral,0)])
clip('phase',[(1,neutral,0),(16,{**charge,'chest':(-12,0,0),'head':(-12,0,0),'upper_arm.L':(-45,0,-55)},.045),(31,{**neutral,'upper_arm.R':(-38,0,32),'upper_arm.L':(-20,0,-35),'cloak':(-11,0,3)},-.07),(49,neutral,0)])
clip('cast',[(1,{**neutral,'upper_arm.R':(-130,0,0),'forearm.R':(-20,0,0),'head':(-8,0,0)},.03),(14,{**neutral,'chest':(15,0,0),'upper_arm.R':(-95,0,12),'hand.R':(-45,0,0)},-.04),(31,neutral,0)])
clip('entrance',[(1,{**neutral,'chest':(25,0,0),'head':(20,0,0),'thigh.R':(-55,0,0),'shin.R':(110,0,0)},-.43),(30,{**neutral,'head':(8,0,0)},-.08),(61,neutral,0)])
dead={**neutral,'root':(83,0,-10),'chest':(15,0,0),'head':(18,0,0),'upper_arm.R':(0,0,40),'upper_arm.L':(0,0,-32),'thigh.R':(-23,0,0),'shin.R':(30,0,0),'cloak':(-17,0,0)}
clip('death',[(1,neutral,0),(14,{**neutral,'chest':(28,0,0),'head':(25,0,0),'shin.R':(60,0,0),'thigh.R':(-30,0,0)},-.25),(34,dead,.05),(61,dead,.05)])
clip('corpse',[(1,dead,.05),(31,dead,.05)])
arm.animation_data.action=bpy.data.actions['idle']
bpy.context.scene.frame_set(1)
# Keep clean neutral source on disk, no preview objects exported.
bpy.context.scene.render.fps=30
bpy.context.scene['ct_notes']='Editable source. Do not regenerate over this file. Export selection with tools/export_oath_knight.py.'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
print('OATH_KNIGHT_MASTER',len(body.data.vertices),'vertices',len(arm_data.bones),'bones',len(bpy.data.actions),'clips')
