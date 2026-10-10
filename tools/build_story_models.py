"""Original Blender modular kit for the opening story slice.

Run: blender --background --factory-startup --python tools/build_story_models.py
Blender 4.5; Z up in source, glTF exports to Godot Y up. Dimensions are metres.
Material slots are intentionally named: Godot replaces them with shared PBR
materials, so the GLBs do not embed duplicate texture sets.
"""
import bpy
import json
import math
import pathlib
import random
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/story/environment/models'
SOURCE = ROOT / 'art/story-environment'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / '.gdignore').write_text('')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
MATS = {}
for name, color in {
    'Masonry': (.34, .34, .31, 1), 'Trim': (.49, .46, .39, 1),
    'Timber': (.19, .14, .10, 1), 'Slate': (.15, .18, .21, 1),
    'Iron': (.10, .12, .13, 1), 'Gold': (.45, .29, .11, 1),
    'Glass': (.7, .36, .10, 1), 'Cloth': (.26, .035, .065, 1),
    'Leaf': (.16, .21, .11, 1), 'Bark': (.20, .18, .14, 1),
    'Rock': (.32, .34, .31, 1), 'Dark': (.055, .062, .07, 1),
}.items():
    m = bpy.data.materials.new(name)
    m.diffuse_color = color
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = color
    bs.inputs['Roughness'].default_value = .87
    if name in ['Gold', 'Iron']:
        bs.inputs['Metallic'].default_value = .75
    if name == 'Glass':
        bs.inputs['Emission Color'].default_value = color
        bs.inputs['Emission Strength'].default_value = .5
    MATS[name] = m

collection = None
groups = {}
manifest = []


def mesh(name, verts, faces, material, group='Body', bevel=0):
    # Author in game coordinates (x, depth, height) for unambiguous door placement.
    data = bpy.data.meshes.new(name)
    # Mapping depth -> -Y is a reflection, so reverse winding as well. Otherwise
    # the exported meshes are inside out and back-face culling shows half rocks.
    data.from_pydata([(x, -d, z) for x, d, z in verts], [], [tuple(reversed(f)) for f in faces])
    data.materials.append(MATS[material])
    data.update()
    # Every solid is a convex building block before joining. Normalize its face
    # orientation in Blender space too (cylinders are authored in that space,
    # whereas walls/arches are authored in game space). Open roof panels use the
    # same outward test; a single coplanar leaf uses the upward-facing fallback.
    center=sum((v.co for v in data.vertices),Vector())/len(data.vertices)
    for poly in data.polygons:
        direction=poly.center-center
        dot=poly.normal.dot(direction)
        if dot < -1e-7 or (direction.length < 1e-6 and poly.normal.z < 0):
            poly.flip()
    data.update()
    uv = data.uv_layers.new(name='UVMap')
    for poly in data.polygons:
        n = poly.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        axes = [i for i in range(3) if i != axis]
        for loop in poly.loop_indices:
            v = data.vertices[data.loops[loop].vertex_index].co
            uv.data[loop].uv = (v[axes[0]] * .55, v[axes[1]] * .55)
    # Roof panels need surface-length UVs, not vertical face projection.
    if material == 'Slate':
        for poly in data.polygons:
            for loop in poly.loop_indices:
                v = data.vertices[data.loops[loop].vertex_index].co
                uv.data[loop].uv = (v.y * .40, abs(v.x) * .48)
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    groups.setdefault(group, []).append(obj)
    if bevel:
        mod = obj.modifiers.new('Worn edge bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    return obj


def box(name, at, size, material='Masonry', group='Body', bevel=.018):
    x, d, z = at
    w, depth, h = size
    v = [(x + dx*w/2, d + dy*depth/2, z + dz*h/2)
         for dz in [-1, 1] for dy in [-1, 1] for dx in [-1, 1]]
    return mesh(name, v, [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),
                         (0,4,6,2),(1,3,7,5)], material, group, bevel)


def beam(name, start, end, radius=.035, material='Timber', group='Body', end_radius=None, sides=10):
    a = Vector((start[0], -start[1], start[2]))
    b = Vector((end[0], -end[1], end[2]))
    axis = (b-a).normalized()
    u = axis.cross(Vector((0, 0, 1)))
    if u.length < .1:
        u = axis.cross(Vector((0, 1, 0)))
    u.normalize()
    v = axis.cross(u)
    verts = []
    for point, r in [(a, radius), (b, end_radius if end_radius is not None else radius)]:
        for i in range(sides):
            p = point + (u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*r
            verts.append((p.x, -p.y, p.z))
    faces = [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    faces += [tuple(reversed(range(sides))), tuple(range(sides, sides*2))]
    return mesh(name, verts, faces, material, group)


def arch(x, d, spring, radius, thickness=.15, depth=.24, group='Front', pointed=True):
    # Two circular arcs meet at a pointed apex; ring blocks remain separate stones.
    if pointed:
        rise = radius * 1.23
        pts = [(x-radius + radius*(1-math.cos(t*math.pi/2)), spring+rise*math.sin(t*math.pi/2))
               for t in [i/7 for i in range(8)]]
        pts += [(2*x-px,pz) for px,pz in pts[-2::-1]]
    else:
        pts = [(x+radius*math.cos(t*math.pi), spring+radius*math.sin(t*math.pi))
               for t in [i/14 for i in range(15)]]
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        mid = Vector(((a[0]+b[0])/2-x, (a[1]+b[1])/2-spring)).normalized()
        aa = (a[0]+mid.x*thickness, a[1]+mid.y*thickness)
        bb = (b[0]+mid.x*thickness, b[1]+mid.y*thickness)
        verts = [(px, dd, zz) for dd in [d-depth/2,d+depth/2] for px, zz in [a,b,bb,aa]]
        mesh('Arch voussoir %02d'%i, verts, [(0,3,2,1),(4,5,6,7),(0,1,5,4),
             (1,2,6,5),(2,3,7,6),(3,0,4,7)], 'Trim', group, .012)


def lantern(x, d, z, group='Front'):
    beam('Lantern bracket', (x,d,z+.21),(x,d+.18,z+.21), .025, 'Iron', group)
    box('Lantern glowing panes',(x,d+.17,z),(.13,.13,.20),'Glass',group,.003)
    for dx in [-.075,.075]:
        for dy in [-.075,.075]:
            beam('Lantern cage',(x+dx,d+.17+dy,z-.12),(x+dx,d+.17+dy,z+.12),.012,'Iron',group)
    box('Lantern base',(x,d+.17,z-.13),(.18,.18,.035),'Gold',group,.008)
    box('Lantern cap',(x,d+.17,z+.13),(.18,.18,.055),'Iron',group,.008)


def window(x, d, z, width=.32, height=.63, group='Front'):
    box('Recessed window',(x,d,z),(width,.035,height),'Dark',group,0)
    box('Warm glass',(x,d+.023,z),(width*.68,.02,height*.8),'Glass',group,0)
    for dx in [-width/2,width/2]:
        box('Window jamb',(x+dx,d+.035,z),(.065,.12,height+.10),'Trim',group)
    for zz in [z-height/2,z+height/2]:
        box('Window sill',(x,d+.055,zz),(width+.18,.18,.08),'Trim',group)
    beam('Window mullion',(x,d+.055,z-height/2),(x,d+.055,z+height/2),.018,'Iron',group)
    arch(x,d+.035,z+height/2-.04,width/2,.06,.10,group)


def roof(w, depth, h, rise, group='Roof'):
    e = .14
    verts = [(-w/2-e,-depth/2-e,h),(w/2+e,-depth/2-e,h),
             (-w/2-e,depth/2+e,h),(w/2+e,depth/2+e,h),
             (0,-depth/2-e,h+rise),(0,depth/2+e,h+rise)]
    mesh('Steep slate roof',verts,[(0,2,5,4),(4,5,3,1),(0,4,1),(2,3,5)],'Slate',group)
    # Thin overlapping courses give the roof a physical edge profile.
    for side in [-1,1]:
        for row in range(9):
            t0=row/9; t1=(row+1)/9
            xx=side*(w/2+e)
            for col in range(7):
                d0=-depth/2-e+(depth+2*e)*(col/7)
                d1=d0+(depth+2*e)/7-.012
                x0=xx*(1-t0); x1=xx*(1-t1)
                z0=h+rise*t0+.018; z1=h+rise*t1+.025
                mesh('Slate course',[(x0,d0,z0),(x0,d1,z0),(x1,d1,z1),(x1,d0,z1)],
                     [(0,1,2,3)] if side<0 else [(3,2,1,0)],'Slate',group)
    beam('Ridge cap',(0,-depth/2-.22,h+rise+.03),(0,depth/2+.22,h+rise+.03),.075,'Gold',group)
    for d in [-depth/2-.14,depth/2+.14]:
        for side in [-1,1]:
            beam('Gable fascia',(side*(w/2+e),d,h),(0,d,h+rise),.045,'Timber',group)
        beam('Gable tie',(-w/2,d,h),(w/2,d,h),.045,'Timber',group)
        beam('Gable kingpost',(0,d,h),(0,d,h+rise),.042,'Timber',group)
    for d in [-depth/2-.23,depth/2+.23]:
        beam('Finial',(0,d,h+rise-.06),(0,d,h+rise+.26),.024,'Gold',group,.005)


def barrel(x, d, z, group='Body'):
    # Faceted coopered barrel with raised iron bands.
    for i in range(14):
        a=i*math.tau/14
        beam('Barrel stave',(x+math.cos(a)*.14,d+math.sin(a)*.14,z),
             (x+math.cos(a)*.14,d+math.sin(a)*.14,z+.38),.038,'Timber',group)
    for h in [.07,.29]:
        for i in range(14):
            a=i*math.tau/14; b=(i+1)*math.tau/14
            beam('Barrel hoop',(x+math.cos(a)*.177,d+math.sin(a)*.177,z+h),
                 (x+math.cos(b)*.177,d+math.sin(b)*.177,z+h),.015,'Iron',group)
    box('Barrel lid',(x,d,z+.39),(.24,.24,.025),'Timber',group)


def boulder(name, at, size, seed):
    rng=random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
    temp=bpy.context.object
    vertices=[]
    for v in temp.data.vertices:
        factor=rng.uniform(.87,1.13)
        vertices.append((at[0]+v.co.x*size[0]*.5*factor,
                         at[1]+v.co.y*size[1]*.5*factor,
                         at[2]+v.co.z*size[2]*.5*factor))
    faces=[tuple(p.vertices) for p in temp.data.polygons]
    bpy.data.objects.remove(temp,do_unlink=True)
    return mesh(name,vertices,faces,'Rock')


def start_asset(name):
    global collection, groups
    collection=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    groups={}


def finish_asset(name):
    # Apply bevels, then batch geometry by roof/front/body for low node overhead.
    for phase, objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            o.select_set(True)
            bpy.context.view_layer.objects.active=o
            for mod in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name=phase
    bpy.ops.object.select_all(action='DESELECT')
    objects=list(collection.objects)
    for o in objects: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',
        use_selection=True,export_apply=True,export_yup=True,export_cameras=False,
        export_lights=False,export_materials='EXPORT')
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
    manifest.append({'name':name,'triangles':triangles,'meshes':len(objects),
                     'file':name+'.glb','coordinates':'metres, Y up, front +Z'})
    return collection


def building(role):
    start_asset('service_%d'%role)
    w=2.6+.3*(role%3); depth=2+.3*(role%2); h=1.8+.25*(role%3)
    front=depth/2
    box('Foundation',(0,0,.03),(w,depth,.06),'Trim')
    for x in [-w/2+.14,w/2-.14]:
        box('Side wall',(x,0,h/2),(.28,depth,h))
    box('Back wall',(0,-depth/2+.14,h/2),(w,.28,h))
    for side in [-1,1]:
        span=w/2-.55
        box('Door flank',(side*(.55+span/2),front-.14,h/2),(span,.28,h),group='Front')
        box('Dressed door jamb',(side*.63,front+.01,.67),(.14,.18,1.34),'Trim','Front')
        window(side*(w/2-.40),front+.015,1.04,.26,.55)
    # The 1.10 m door matches the collision opening; nothing crosses at head height.
    box('Door lintel',(0,front-.14,h-.18),(1.1,.28,.36),group='Front')
    arch(0,front+.025,1.32,.55,.14,.22)
    lantern(.80,front+.035,1.30)
    for x in [-w/2+.02,w/2-.02]:
        for d in [-depth/2+.06,front-.06]:
            for i in range(int(h/.23)):
                box('Corner quoin',(x,d,.115+i*.23),(.31,.30,.205),'Trim','Front' if d>0 else 'Body')
        box('Buttress',(x,-depth*.22,.68),(.28,.42,1.36),'Masonry')
        box('Buttress cap',(x,-depth*.22,1.41),(.33,.46,.10),'Trim')
    for level in [.18,h-.08]:
        box('Back belt',(0,-depth/2-.02,level),(w+.06,.12,.09),'Trim')
        for x in [-w/2,w/2]: box('Side belt',(x,0,level),(.12,depth,.09),'Trim')
    box('Interior table',(-w*.22,-depth*.12,.48),(.64,.38,.08),'Timber')
    for x in [-w*.22-.25,-w*.22+.25]:
        for d in [-depth*.12-.13,-depth*.12+.13]: box('Table leg',(x,d,.23),(.07,.07,.46),'Timber')
    if role==0:
        box('Battlement floor',(0,0,h+.07),(w+.15,depth+.15,.14),'Trim','Roof')
        for x in [-w/2,w/2]: box('Parapet',(x,0,h+.28),(.20,depth,.36),group='Roof')
        for d in [-depth/2,depth/2]:
            box('Parapet',(0,d,h+.28),(w,.20,.36),group='Roof')
            for i in range(5): box('Merlon',(-w/2+i*w/4,d,h+.61),(.30,.27,.32),group='Roof')
        for x in [-w/2,w/2]:
            for i in range(4): box('Merlon',(x,-depth/2+i*depth/3,h+.61),(.27,.30,.32),group='Roof')
        box('Crimson standard',(-.96,front+.05,1.1),(.25,.03,.76),'Cloth','Front',0)
        beam('Standard pole',(-1.12,front+.08,1.55),(-.78,front+.08,1.55),.025,'Gold','Front')
    else:
        rise=[0,1.22,.85,1.42,.67,.94][role]
        roof(w,depth,h,rise)
        if role in [2,5]:
            box('Chimney stack',(-w*.27,-depth*.22,h+.75),(.42,.40,1.5),'Masonry','Roof')
            box('Chimney crown',(-w*.27,-depth*.22,h+1.52),(.53,.51,.13),'Trim','Roof')
            box('Soot opening',(-w*.27,-depth*.22,h+1.59),(.30,.29,.025),'Dark','Roof',0)
        if role in [1,3]:
            window(0,front+.16,h+.43,.34,.52,'Roof')
            for side in [-1,1]:
                beam('Gothic dormer trim',(side*.30,front+.19,h+.21),(0,front+.19,h+.92),.04,'Gold','Roof')
        if role==2:
            box('Forge hearth',(w*.26,-.52,.28),(.63,.59,.56),'Masonry')
            box('Forge coals',(w*.26,-.23,.29),(.39,.05,.20),'Glass')
            box('Anvil plinth',(w*.25,.22,.35),(.33,.35,.70),'Timber')
            box('Anvil',(w*.25,.22,.76),(.55,.25,.16),'Iron')
            beam('Tool rack',(-w*.31,-depth/2+.30,.55),(-w*.31,-depth/2+.30,1.45),.05)
        if role==3:
            for z in [.32,.72,1.12]:
                box('Archive shelves',(0,-depth/2+.30,z),(w*.66,.35,.08),'Timber')
                for i in range(9):
                    box('Bound ledger',(-w*.29+i*w*.07,-depth/2+.3,z+.15),(.08,.22,.24),'Cloth' if i%3==0 else 'Timber')
        if role==4:
            for x in [-w/2+.18,w/2-.18]: box('Warehouse beam',(x,front-.18,h/2),(.14,.15,h),'Timber','Front')
            for x in [-.73,.73]: barrel(x,-depth*.25,.08)
            box('Cargo stack',(.68,.26,.39),(.55,.58,.70),'Timber')
            # A visibly timber warehouse rather than another masonry cottage.
            for x in [-w/2-.025,w/2+.025]:
                for d in [-.62,0,.62]:
                    beam('Warehouse side braces',(x,d-.25,.25),(x,d+.25,h-.22),.055,'Timber')
                box('Side timber infill',(x,0,h*.55),(.035,depth-.26,h*.58),'Timber')
            for side in [-1,1]:
                beam('Warehouse facade brace',(side*.73,front+.035,.24),(side*(w/2-.22),front+.035,h-.18),.055,'Timber','Front')
        if role==1:
            # The infirmary has a small bell turret, a different vertical landmark.
            for x in [-.20,.20]:
                for d in [-depth/2+.14,-depth/2+.52]:
                    box('Bell turret post',(x,d,h+rise+.19),(.065,.065,.54),'Timber','Roof')
            box('Turret cap',(0,-depth/2+.33,h+rise+.52),(.57,.57,.12),'Slate','Roof')
            beam('Bell', (0,-depth/2+.33,h+rise+.1),(0,-depth/2+.33,h+rise+.27),.085,'Gold','Roof',.04)
        if role==5:
            beam('Sign bracket',(-w*.32,front+.1,1.66),(-w*.32,front+.39,1.66),.035,'Iron','Front')
            box('Inn sign',(-w*.32,front+.39,1.42),(.32,.07,.32),'Timber','Front')
            box('Sign brass inlay',(-w*.32,front+.435,1.42),(.18,.018,.18),'Gold','Front')
            barrel(w*.26,-.45,.06)
    return finish_asset('service_%d'%role)


for role in range(6): building(role)

start_asset('south_gate')
for x in [-2.20,2.20]:
    box('Gate pier',(x,0,1.28),(1.10,.9,2.56))
    for z in [.12,1.35,2.57]: box('Pier belt',(x,0,z),(1.19,1.02,.12),'Trim')
    for dx in [-.40,0,.40]: box('Pier merlon',(x+dx,0,2.86),(.27,.86,.45))
    lantern(x,-.48,1.58,'Body')
    box('Gate banner',(x,.49,1.57),(.35,.035,.92),'Cloth')
arch(0,.04,2.2,1.65,.28,.8,'Body')
box('Gate upper span',(0,0,4.42),(1.10,.90,.33))
for i in [-1,0,1]: box('Span crown',(i*.37,0,4.70),(.25,.82,.30))
finish_asset('south_gate')

start_asset('wall_section')
box('Defensive wall',(0,0,.50),(3,.5,1.0))
box('Wall plinth',(0,0,.09),(3.10,.62,.18),'Trim')
box('Wall coping',(0,0,1.03),(3.10,.57,.12),'Trim')
for i in range(6):
    box('Wall merlon',(-1.30+i*.52,0,1.28),(.32,.52,.36))
finish_asset('wall_section')

start_asset('rubble')
rng=random.Random(52)
for i in range(19):
    at=(rng.uniform(-.8,.8),rng.uniform(-.55,.55),rng.uniform(.02,.18))
    o=box('Broken masonry',at,(rng.uniform(.15,.40),rng.uniform(.14,.32),rng.uniform(.1,.24)),'Rock',bevel=.035)
    o.rotation_euler.z=rng.uniform(-.6,.6)
finish_asset('rubble')

start_asset('forest_tree')
rng=random.Random(71)
beam('Trunk',(0,0,0),(.09,.02,2.6),.14,'Bark',end_radius=.045,sides=12)
for i in range(10):
    angle=i*2.399; h=.9+i*.15
    tip=(math.cos(angle)*.83,math.sin(angle)*.78,h+.85)
    beam('Branch',(.03,0,h),tip,.045,'Bark',end_radius=.012)
    for j in range(4):
        t=j/3
        beam('Twig',(tip[0]*.6,tip[1]*.6,h+.52),
             (tip[0]+rng.uniform(-.32,.32),tip[1]+rng.uniform(-.30,.30),tip[2]+t*.23),.018,'Bark',end_radius=.004)
leaf_v=[]; leaf_f=[]
for i in range(780):
    a=rng.uniform(0,math.tau); radial=math.sqrt(rng.random())*1.03
    z=rng.uniform(1.7,3.3)-radial*.22
    x=math.cos(a)*radial; d=math.sin(a)*radial
    size=rng.uniform(.06,.15); angle=rng.uniform(0,math.tau)
    u=(math.cos(angle)*size,math.sin(angle)*size)
    v=(-math.sin(angle)*size*.42,math.cos(angle)*size*.42)
    k=len(leaf_v)
    leaf_v.extend([(x-u[0],d-u[1],z),(x+v[0],d+v[1],z+.016),
                   (x+u[0],d+u[1],z+.035),(x-v[0],d-v[1],z-.02)])
    leaf_f.append((k,k+1,k+2,k+3))
mesh('Individual leaves',leaf_v,leaf_f,'Leaf','Leaves')
finish_asset('forest_tree')

start_asset('cave_portal')
rng=random.Random(84)
for side in [-1,1]:
    for i in range(5):
        x=side*(1.3+rng.uniform(-.15,.15)); z=.20+i*.42
        boulder('Rock arch flank',(x,rng.uniform(-.25,.35),z),(.86,1.02,.89),84+i+side*31)
for i in range(7):
    x=-1.4+i*.47
    boulder('Rock arch crown',(x,.08,2.40+.33*(1-abs(x)/1.5)),(.85,1.13,.92),120+i)
for side in [-1,1]:
    box('Mine upright',(side*.89,.23,.89),(.16,.18,1.78),'Timber')
    beam('Support brace',(side*.89,.24,1.2),(side*.42,.24,1.82),.065)
box('Mine lintel',(0,.23,1.84),(1.94,.22,.21),'Timber')
# Back plane is below the aperture crown and behind, never on the walking line.
box('Dark recess',(0,-.30,1.02),(1.78,.03,1.92),'Dark',bevel=0)
lantern(-1.00,.44,1.24,'Body')
finish_asset('cave_portal')

start_asset('rock_formation')
rng=random.Random(93)
for i in range(5):
    x=rng.uniform(-.5,.5); d=rng.uniform(-.4,.4); h=rng.uniform(.4,1.1)
    # Uneven tapered rock mass rather than a single cube.
    n=7; verts=[]
    for z,rad in [(0,.50),(h*.55,.48),(h,.23)]:
        for j in range(n):
            a=j*math.tau/n; rr=rad*rng.uniform(.75,1.2)
            verts.append((x+math.cos(a)*rr,d+math.sin(a)*rr,z+rng.uniform(-.08,.08)))
    faces=[]
    for layer in range(2):
        for j in range(n): faces.append((layer*n+j,layer*n+(j+1)%n,(layer+1)*n+(j+1)%n,(layer+1)*n+j))
    faces += [tuple(range(n-1,-1,-1)),tuple(range(2*n,3*n))]
    mesh('Weathered outcrop',verts,faces,'Rock',bevel=.035)
finish_asset('rock_formation')

start_asset('grass_tuft')
rng=random.Random(14)
verts=[]; faces=[]
for i in range(16):
    a=rng.uniform(0,math.tau); x=rng.uniform(-.10,.10); d=rng.uniform(-.10,.10)
    h=rng.uniform(.16,.34); w=.017
    k=len(verts)
    verts += [(x-w,d,0),(x+w,d,0),(x+math.cos(a)*.05+w*.5,d+math.sin(a)*.05,h*.55),
              (x+math.cos(a)*.10,d+math.sin(a)*.10,h),(x+math.cos(a)*.05-w*.5,d+math.sin(a)*.05,h*.55)]
    faces += [(k,k+1,k+2,k+4),(k+4,k+2,k+3)]
mesh('Grass blades',verts,faces,'Leaf')
finish_asset('grass_tuft')

(OUT.parent/'model-manifest.json').write_text(json.dumps({'author':'Crimson Tide project',
    'source':'art/story-environment/thunder-bastion-kit.blend', 'builder':'tools/build_story_models.py',
    'models':manifest},indent=2),encoding='utf-8')
# Set up the editable source with the same offline PBR maps used in Godot.
for material_name, palette in [('Masonry','masonry'),('Trim','masonry'),('Timber','timber'),
                             ('Bark','timber'),('Slate','slate'),('Rock','masonry')]:
    material=MATS[material_name]
    tree=material.node_tree; bs=tree.nodes.get('Principled BSDF')
    color=tree.nodes.new('ShaderNodeTexImage')
    color.image=bpy.data.images.load(str(OUT.parent/'pbr'/f'{palette}_albedo.png'),check_existing=True)
    tree.links.new(color.outputs['Color'],bs.inputs['Base Color'])
    normal=tree.nodes.new('ShaderNodeTexImage')
    normal.image=bpy.data.images.load(str(OUT.parent/'pbr'/f'{palette}_normal.png'),check_existing=True)
    normal.image.colorspace_settings.name='Non-Color'
    converter=tree.nodes.new('ShaderNodeNormalMap'); converter.inputs['Strength'].default_value=.35
    tree.links.new(normal.outputs['Color'],converter.inputs['Color'])
    tree.links.new(converter.outputs['Normal'],bs.inputs['Normal'])
# Spread the original, editable parts into an inspection sheet in the .blend.
for i, col in enumerate([c for c in bpy.data.collections if c.name.startswith('service_') or c.name in
                         ['south_gate','wall_section','rubble','forest_tree','cave_portal','rock_formation','grass_tuft']]):
    for obj in col.objects: obj.location += Vector(((i%4)*5, -(i//4)*5, 0))
reference_path=SOURCE/'thunder-bastion-reference-v1.png'
if reference_path.exists():
    reference=bpy.data.objects.new('ImageGen architectural reference',None)
    bpy.context.scene.collection.objects.link(reference)
    reference.empty_display_type='IMAGE'
    reference.data=bpy.data.images.load(str(reference_path),check_existing=True)
    reference.empty_display_size=14
    reference.location=Vector((-10,-4,6))
    reference.rotation_euler=(math.pi/2,0,0)
    reference.show_in_front=True
bpy.ops.object.select_all(action='DESELECT')
bpy.context.scene.world.color=(.06,.075,.09)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=24
            area.spaces.active.region_3d.view_location=Vector((7,-5,1.5))
            area.spaces.active.region_3d.view_rotation=Vector((12,-18,18)).to_track_quat('Z','Y')
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'thunder-bastion-kit.blend'))
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'thunder-bastion-kit.blend'))
print('STORY_MODEL_KIT '+json.dumps(manifest),flush=True)
