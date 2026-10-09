extends RefCounted
## Original modular architecture and continuous terrain; no reference-game art.
const GROUND = preload("res://resources/story_ground.gdshader")
const STONE = preload("res://resources/story_stone.gdshader")
const WATER = preload("res://resources/story_water.gdshader")
var world
var roofs: Array=[]
var occluders: Array=[]
var chunks: Array=[]
var lights: Array=[]
var cache_models: Array=[]
const EARTH := [Color("4b5140"),Color("55534c"),Color("4d514d"),Color("535048"),Color("394b48"),Color("45434b")]
const ROAD := [Color("675849"),Color("767063"),Color("635d52"),Color("6a5a55"),Color("596764"),Color("655963")]

func stone(color: Color, wood: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); mat.shader=STONE
	mat.set_shader_parameter("stone",color); mat.set_shader_parameter("wood",wood)
	return mat

func block(r: Rect2, h: float, base: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size=Vector3(r.size.x,h,r.size.y)*.01
	var node := MeshInstance3D.new(); node.mesh=mesh; node.material_override=mat
	(parent if parent else world.scenery).add_child(node)
	node.position=world.point(r.get_center(),base+h*.5)
	return node

func build(w) -> void:
	world=w; roofs.clear(); occluders.clear(); chunks.clear(); lights.clear(); cache_models.clear()
	for s in world.campaign.map.floors:
		var r=world.campaign.map.regions[s]
		var chunk := Node3D.new(); world.scenery.add_child(chunk)
		chunks.append({"node":chunk,"rect":Rect2(r.origin,r.extent)})
		var saved: Node3D=world.scenery; world.scenery=chunk
		terrain(r)
		if r.indoor: dungeon_walls(r)
		for b in r.buildings: house(r,b)
		for item in r.props:
			var p: Vector2=r.origin+item.p
			var holder: Node3D=world.prop(item.key,p,item.size,Color("adaba0"),Color("657666"),item.angle,r.height_at(item.p))
			occluders.append({"node":holder,"p":p,"height":item.size.y})
		for item in r.stairs: stairway(r,item)
		for rect in r.water:
			river(r,rect)
		if r.layout=="bridge":
			for i in 12:
				block(Rect2(r.origin+Vector2(2130,2530+i*37.5),Vector2(540,36)),15,-13,stone(Color("594d3c"),true))
		for at in [r.waypoint]+r.chests:
			if at==r.waypoint: waypoint(r.origin+at,r.height_at(at))
			else:
				var holder: Node3D=world.prop("dungeon/chest_gold",r.origin+at,Vector3(75,55,55),Color("b1a385"),Color.WHITE,0,r.height_at(at))
				cache_models.append({"node":holder,"id":"%d:%d:cache:%d" % [r.act,r.stage,r.chests.find(at)]})
		if r.stage==0:
			world.prop("halloween/arch",Vector2(1100,1790),Vector3(390,260,55),Color("a29f95"))
			camp_details(r)
			for at in r.npc_at:
				var light := OmniLight3D.new(); light.position=world.point(at+Vector2(58,15),115)
				light.light_color=Color("f4b57c"); light.light_energy=.7; light.omni_range=2.8
				chunk.add_child(light); lights.append(light)
		world.scenery=saved
	if world.campaign.map.layer==0:
		for c in world.campaign.map.connectors:
			var r: Rect2=c.rect
			var mat := ShaderMaterial.new(); mat.shader=GROUND
			mat.set_shader_parameter("ground_tex",load("res://assets/world/terrain-0.png")); mat.set_shader_parameter("road_tex",load("res://assets/world/terrain-2.png"))
			mat.set_shader_parameter("earth",EARTH[world.campaign.map.act-1]); mat.set_shader_parameter("road",ROAD[world.campaign.map.act-1])
			var mesh := PlaneMesh.new(); mesh.size=r.size*.01
			world.mesh_node(mesh,world.point(r.get_center(),-.5),mat)
	else:
		var p: Vector2=world.campaign.map.spawn
		world.prop("halloween/arch",p+Vector2(0,-90),Vector3(420,290,80),Color("918c84"))
		for i in 7: block(Rect2(p+Vector2(-150,-210+i*35),Vector2(300,35)),10,7*(6-i),stone(Color("6e685f")))
	for door in world.campaign.map.entrances():
		if door.kind=="entrance": entrance(door)

func terrain(r) -> void:
	var mat := ShaderMaterial.new(); mat.shader=GROUND
	mat.set_shader_parameter("ground_tex",load("res://assets/world/terrain-%d.png" % ([0,5,2,3,4,5][r.act-1] if not r.indoor else 5)))
	mat.set_shader_parameter("road_tex",load("res://assets/world/terrain-2.png"))
	mat.set_shader_parameter("earth",EARTH[r.act-1]); mat.set_shader_parameter("road",ROAD[r.act-1])
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 100
	var margin := 1000 if r.stage==0 else 0
	for y in range(-margin,int(r.extent.y)+margin,step):
		for x in range(-margin,int(r.extent.x)+margin,step):
			var center := Vector2(x+step*.5,y+step*.5)
			if r.indoor and not room_at(r,center): continue
			var submerged := false
			for rect in r.water:
				if rect.has_point(center): submerged=true; break
			if submerged: continue
			for offset in [Vector2(0,0),Vector2(step,0),Vector2(step,step),Vector2(0,0),Vector2(step,step),Vector2(0,step)]:
				var p: Vector2=Vector2(x,y)+offset
				var path: float=1.0-smoothstep(65,185,r.path_distance(p))
				st.set_color(Color(1,1,1,path)); st.set_uv(p/100)
				st.add_vertex(world.point(p+r.origin,r.height_at(p)))
	st.generate_normals()
	world.mesh_node(st.commit(),Vector3.ZERO,mat)
	if not r.indoor and r.stage>0:
		# Rough stone ridges enclose sectors while leaving exit spans clear.
		var rng := RandomNumberGenerator.new(); rng.seed=r.act*311+r.stage*53
		for i in range(0,int(r.extent.x),180):
			for p in [Vector2(i,40),Vector2(i,r.extent.y-40),Vector2(40,i),Vector2(r.extent.x-40,i)]:
				if r.path_distance(p)<240: continue
				world.prop("medieval/rock_single_B",r.origin+p,Vector3(240,rng.randf_range(120,240),170),Color("827e72"),Color.WHITE,rng.randf()*TAU,-30)

func room_at(r, p: Vector2) -> bool:
	for rect in r.rooms:
		if rect.has_point(p): return true
	return false

func dungeon_walls(r) -> void:
	var mat := stone(Color("69665f"))
	# Extract exposed edges of the union, so overlapping rooms have open joins.
	for y in range(0,4800,100):
		for x in range(0,4800,100):
			var p := Vector2(x+50,y+50)
			if not room_at(r,p): continue
			for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				if room_at(r,p+d*100): continue
				var at: Vector2=p+d*50+r.origin
				var size := Vector2(28,100) if d.x!=0 else Vector2(100,28)
				var node := block(Rect2(at-size*.5,size),190,0,mat)
				occluders.append({"node":node,"p":at,"height":190.0})
				# Capstones and pillars break up long wall silhouettes.
				block(Rect2(at-size*.5-Vector2.ONE*5,size+Vector2.ONE*10),12,190,stone(Color("878174")))
				if (x+y)%400==0:
					world.prop("dungeon/column",at,Vector3(52,230,52),Color("a49d8a"))
	for at in r.anchors+r.side_anchors:
		var light := OmniLight3D.new(); light.position=world.point(r.origin+at,180)
		light.light_color=Color("ffd094"); light.light_energy=1.2; light.omni_range=5.5
		world.scenery.add_child(light); lights.append(light)
		world.prop("dungeon/torch_lit",r.origin+at+Vector2(130,-90),Vector3(25,130,25),Color.WHITE,Color.WHITE,0,r.height_at(at))
	dungeon_details(r)

func house(r, b: Dictionary) -> void:
	var rect: Rect2=Rect2(b.rect.position+r.origin,b.rect.size)
	var mat := stone(Color("69665b") if r.act!=6 else Color("5e5661"),r.act in [3,5])
	var h: float=b.height
	block(rect,6,0,stone(Color("6a6256")))
	var front := Node3D.new(); world.scenery.add_child(front)
	var walls: Array=r.building_walls(rect)
	for i in walls.size(): block(walls[i],h,0,mat,front if i>=3 else null)
	block(Rect2(rect.get_center().x-55,rect.end.y-28,110,28),50,h-50,mat,front)
	var roof := Node3D.new(); world.scenery.add_child(roof)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left := Vector2(rect.position.x-25,rect.position.y-25)
	var right := Vector2(rect.end.x+25,rect.end.y+25)
	var v := [world.point(left,h),world.point(Vector2(right.x,left.y),h),world.point(Vector2(right.x,right.y),h),world.point(Vector2(left.x,right.y),h),world.point(Vector2((left.x+right.x)*.5,left.y),h+110),world.point(Vector2((left.x+right.x)*.5,right.y),h+110)]
	for i in [0,3,5,0,5,4,4,5,2,4,2,1,0,4,1,3,2,5]: st.add_vertex(v[i])
	st.generate_normals()
	var mesh := MeshInstance3D.new(); mesh.mesh=st.commit(); mesh.material_override=stone([Color("594239"),Color("5c5753"),Color("4e443b"),Color("5e424e"),Color("455357"),Color("444149")][r.act-1],true); roof.add_child(mesh)
	roofs.append({"roof":roof,"front":front,"rect":rect})
	world.prop("dungeon/table_long_decorated_A",rect.get_center()+Vector2(0,-30),Vector3(90,60,60),Color("b5a68f"))
	world.prop("halloween/lantern_standing",r.origin+b.door+Vector2(72,45),Vector3(20,90,20))
	var timber := stone(Color("39342c"),true)
	# Timber framing, recessed windows and chimney preserve a readable silhouette.
	for x in [rect.position.x+18,rect.end.x-18]:
		block(Rect2(x-9,rect.end.y-36,18,40),h+10,0,timber)
	block(Rect2(rect.position.x,rect.end.y-37,rect.size.x,22),16,h*.66,timber)
	for x in [rect.position.x+40,rect.end.x-65]:
		block(Rect2(x,rect.end.y-39,25,8),45,h*.43,world.material(Color("192327")))
		block(Rect2(x-5,rect.end.y-45,35,10),8,h*.43,timber)
	if r.act not in [4,6]: block(Rect2(rect.position+Vector2(25,20),Vector2(35,40)),110,h,mat,roof)
	if r.act==6: roof.visible=false; roofs[-1]["ruined"]=true
	var role: int=int(b.get("role",r.stage%6))
	if role==2:
		world.prop("dungeon/torch_lit",r.origin+b.door+Vector2(80,-10),Vector3(40,75,40))
		world.prop("dungeon/rubble_large",r.origin+b.door+Vector2(-100,25),Vector3(100,35,70))
	elif role==3:
		world.prop("dungeon/shelf_small_candles",rect.get_center()+Vector2(-50,-35),Vector3(85,100,55))
	elif role==4:
		for i in 3: world.prop("dungeon/chest",r.origin+b.door+Vector2(-80+i*75,90),Vector3(50,40,38),Color("ac9b84"))

func stairway(r, item: Dictionary) -> void:
	var rect: Rect2=Rect2(item.rect.position+r.origin,item.rect.size)
	var terrace: Rect2=Rect2(item.terrace.position+r.origin,item.terrace.size)
	var mat := stone(Color("797167"))
	block(terrace,item.top,0,mat)
	for i in 14:
		var h: float=item.top*((14-i)/14.0 if item.north else (i+1)/14.0)
		block(Rect2(rect.position+Vector2(0,i*rect.size.y/14),Vector2(rect.size.x,rect.size.y/14)),h,0,mat)
	for x in [rect.position.x-26,rect.end.x+26]:
		for i in 6:
			var at := Vector2(x,rect.position.y+(i+.5)*rect.size.y/6)
			world.prop("dungeon/column",at,Vector3(30,55,30),Color("9a8e7b"),Color.WHITE,0,r.height_at(at-r.origin))

func waypoint(p: Vector2, base: float) -> void:
	var mesh := CylinderMesh.new(); mesh.top_radius=1.2; mesh.bottom_radius=1.2; mesh.height=.08; mesh.radial_segments=32
	world.mesh_node(mesh,world.point(p,base+4),stone(Color("6a6564")))
	var ring := TorusMesh.new(); ring.inner_radius=.86; ring.outer_radius=1.01
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color("537f88"); mat.emission_enabled=true; mat.emission=Color("365c66"); mat.emission_energy_multiplier=.3
	world.mesh_node(ring,world.point(p,base+10),mat)
	for i in 5:
		var at := p+Vector2(cos(i*TAU/5),sin(i*TAU/5))*147
		world.prop("halloween/gravestone",at,Vector3(45,65,30),Color("89887a"),Color.WHITE,i*TAU/5,base)

func entrance(door: Dictionary) -> void:
	var p: Vector2=door.p
	world.prop("halloween/arch",p+Vector2(0,-100),Vector3(400,300,85),Color("91887c"))
	var black: StandardMaterial3D=world.material(Color("111319"))
	block(Rect2(p-Vector2(120,110),Vector2(240,240)),4,-3,black)
	for i in 6: block(Rect2(p+Vector2(-120,-100+i*35),Vector2(240,35)),6,-25+i*4,stone(Color("696458")))

func sync(focus: Vector2) -> void:
	for item in cache_models:
		var opened: bool=world.campaign.state.get("opened_chests",{}).has(item.id)
		world.assets.chest_state(item.node,opened,opened)
	for chunk in chunks: chunk.node.visible=chunk.rect.grow(1700).has_point(focus)
	for item in roofs:
		var inside: bool=item.rect.grow(65).has_point(focus)
		item.roof.visible=not inside and not item.get("ruined",false); item.front.visible=not inside
	for item in occluders:
		var distance: float=item.p.distance_to(focus)
		# Reveal the character behind a foreground tree or tall wall; collision stays.
		var projected: Vector2=world.project(item.p)-world.project(focus)
		item.node.visible=not (distance<320 and projected.y>0 and absf(projected.x)<95 and item.height>140)
	for light in lights: light.visible=Vector2(light.global_position.x,light.global_position.z).distance_to(focus*.01)<16

func camp_details(r) -> void:
	var mat := stone(Color("666054"),r.act in [1,3,5])
	# Outer enclosure keeps the playable border legible in the orthographic view.
	for x in range(80,2200,180):
		block(Rect2(x,60,175,30),95,0,mat)
		if absf(x-1100)>300: block(Rect2(x,1880,175,35),95,0,mat)
	for y in range(120,1800,180):
		for x in [60,2110]: block(Rect2(x,y,30,175),95,0,mat)
	for at in [Vector2(-180,100),Vector2(2290,480),Vector2(2340,1590),Vector2(-240,1660)]:
		world.prop("nature/tree_3" if r.act in [1,4] else "halloween/tree_dead_large",at,Vector3(260,410,210),Color("9a968d"),Color("666959"))
	if r.act==2:
		for x in [310,1890]:
			for y in [310,770,1210]: world.prop("dungeon/pillar_decorated",Vector2(x,y),Vector3(80,300,80),Color("aeaa9a"))
	elif r.act==3:
		world.prop("medieval/building_tower_A_red",Vector2(1920,290),Vector3(180,450,180),Color("887969"))
	elif r.act==4:
		for x in [370,1840]:
			for y in [350,800,1240,1700]: world.prop("halloween/gravestone",Vector2(x,y),Vector3(45,85,35),Color("a29791"))
	elif r.act==5:
		for y in range(260,1740,170): world.prop("dungeon/floor_wood_large",Vector2(360,y),Vector3(200,18,170),Color("8e8471"),Color.WHITE,0,-14)
	elif r.act==6:
		for at in [Vector2(350,250),Vector2(1820,220),Vector2(1750,1730)]: world.prop("dungeon/rubble_large",at,Vector3(190,90,130),Color("a497a1"))

func river(r, rect: Rect2) -> void:
	var shape := rect
	var surface := ShaderMaterial.new(); surface.shader=WATER
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var horizontal: bool=rect.size.x>rect.size.y
	var length: float=rect.size.x if horizontal else rect.size.y
	var count := maxi(1,int(ceil(length/80)))
	var bank_mat := stone(Color("5c5b4c"))
	for i in count:
		var p0: float=float(i)/count
		var p1: float=float(i+1)/count
		var wobble0 := sin(i*1.61+float(r.stage))*30
		var wobble1 := sin((i+1)*1.61+float(r.stage))*30
		var a := Vector2(rect.position.x+p0*rect.size.x,rect.position.y+wobble0) if horizontal else Vector2(rect.position.x+wobble0,rect.position.y+p0*rect.size.y)
		var b := Vector2(rect.position.x+p1*rect.size.x,rect.position.y+wobble1) if horizontal else Vector2(rect.position.x+wobble1,rect.position.y+p1*rect.size.y)
		var offset := Vector2(0,rect.size.y) if horizontal else Vector2(rect.size.x,0)
		for p in [a,b,b+offset,a,b+offset,a+offset]: st.set_normal(Vector3.UP); st.add_vertex(world.point(p+r.origin,-14))
		for p in [a,a+offset]:
			var size := Vector2(length/count+4,70) if horizontal else Vector2(70,length/count+4)
			block(Rect2(p+r.origin-size*.5,size),28,-24,bank_mat)
			if i%2==0: world.prop("medieval/rock_single_A",p+r.origin,Vector3(90,38,55),Color("a8a493"),Color.WHITE,i*.4,-12)
	world.mesh_node(st.commit(),Vector3.ZERO,surface)

func dungeon_details(r) -> void:
	var stone_mat := stone(Color("7b7568"))
	if r.layout in ["chapel","cathedral"]:
		# A nave, lateral pews and a raised altar give this room a purpose.
		for y in [1150,1580,2450,2850,3200]:
			for x in [1750,3020]:
				var at := Vector2(x,y)
				if not room_at(r,at): continue
				world.prop("dungeon/column",r.origin+at+Vector2(-130,0),Vector3(75,330,75),Color("b2ac9c"))
		for x in [1660,3130]:
			world.prop("dungeon/banner_shield_red",r.origin+Vector2(x,2550),Vector3(100,220,22),Color("9d808c"),Color.WHITE,0,160)
		var p: Vector2=r.origin+r.anchors[-1]+Vector2(0,-300)
		for i in 8:
			var a := i*TAU/8
			world.prop("dungeon/column",p+Vector2(cos(a)*280,sin(a)*190),Vector3(52,160,52),Color("bab3a2"),Color.WHITE,0,r.height_at(p-r.origin))
	elif r.layout=="mine":
		for y in range(800,3500,350):
			var at := Vector2(2400,y)
			if not room_at(r,at): continue
			for x in [2130,2680]: block(Rect2(r.origin+Vector2(x,y),Vector2(32,40)),230,0,stone(Color("524c3b"),true))
			block(Rect2(r.origin+Vector2(2130,y),Vector2(580,40)),35,220,stone(Color("524c3b"),true))
		for p in [Vector2(800,2750),Vector2(3520,2760),Vector2(1760,4250)]:
			world.prop("medieval/rock_single_B",r.origin+p,Vector3(190,155,120),Color("9ba3a8"))
	elif r.layout=="crypt":
		for y in [1150,2700,4050]:
			for x in [710,1320,3300,3970]:
				var p := Vector2(x,y)
				if not room_at(r,p): continue
				world.prop("halloween/gravestone",p+r.origin+Vector2(-95,0),Vector3(50,110,30),Color("acaa9c"))
	elif r.layout=="library": pass
	else:
		for p in [Vector2(1050,1470),Vector2(1300,3100),Vector2(3180,1470)]:
			if room_at(r,p): world.prop("dungeon/banner_red",p+r.origin,Vector3(100,200,20),Color("9f8982"))
