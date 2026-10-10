extends RefCounted
## Original modular architecture and continuous terrain; no reference-game art.
const GROUND = preload("res://resources/story_ground.gdshader")
const STONE = preload("res://resources/story_stone.gdshader")
const WATER = preload("res://resources/story_water.gdshader")
const Floors=preload("res://scripts/story_floor_palette.gd")
const Regional=preload("res://scripts/story_regional_environment.gd")
var kit = preload("res://scripts/story_asset_kit.gd").new()
var world
var roofs: Array=[]
var occluders: Array=[]
var chunks: Array=[]
var lights: Array=[]
var cache_models: Array=[]
var authoring := false
var pending_paths: Dictionary={}
const SLICE := "res://scenes/story/"
func scene_path(stage: int, act: int = 1) -> String:
	return SLICE+("opening-%d" % stage if act==1 else "act%d-%d" % [act,stage])+("-compat.scn" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ".scn")
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
		chunks[-1]["region"]=r
		if authoring or Rect2(r.origin,r.extent).grow(2000).has_point(world.campaign.hero_at): populate_chunk(r,chunk)
	if not authoring and DisplayServer.get_name()!="headless":
		for s in world.campaign.map.outdoor+([7,9] if world.campaign.map.act==1 else [7,8]):
			var preload_path := scene_path(s,world.campaign.map.act)
			if ResourceLoader.exists(preload_path) and ResourceLoader.load_threaded_get_status(preload_path)==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_request(preload_path); pending_paths[preload_path]=true
	if world.campaign.map.layer==0:
		for c in world.campaign.map.connectors:
			var r: Rect2=c.rect
			var mat := ShaderMaterial.new(); mat.shader=GROUND
			mat.set_shader_parameter("ground_tex",load("res://assets/world/terrain-0.png")); mat.set_shader_parameter("road_tex",load("res://assets/world/terrain-2.png"))
			mat.set_shader_parameter("earth",EARTH[world.campaign.map.act-1]); mat.set_shader_parameter("road",ROAD[world.campaign.map.act-1])
			if world.campaign.map.act==1: physical_ground(mat,false)
			else: Regional.ground(self,mat,world.campaign.map.regions[c.to])
			connector_ground(r,mat)
	else:
		var p: Vector2=world.campaign.map.spawn
		if world.campaign.map.act>=2: kit.instance("a%d_gate" % world.campaign.map.act,world.scenery,world.point(p+Vector2(0,-90)),Vector3(.8,.8,.8))
		elif world.campaign.map.layout=="castle": kit.instance("castle_gateway",world.scenery,world.point(p+Vector2(0,-90)),Vector3(.8,.8,.8))
		else: world.prop("halloween/arch",p+Vector2(0,-90),Vector3(420,290,80),Color("918c84"))
		for i in (7 if world.campaign.map.act==1 else 0): block(Rect2(p+Vector2(-150,-210+i*35),Vector2(300,35)),10,7*(6-i),stone(Color("6e685f")))
	for door in world.campaign.map.entrances():
		if door.kind=="entrance": entrance(door)

func populate_chunk(r, chunk: Node3D) -> void:
	var saved: Node3D=world.scenery; world.scenery=chunk
	if not authoring and ResourceLoader.exists(scene_path(r.stage,r.act)):
		var path := scene_path(r.stage,r.act)
		var packed: PackedScene=ResourceLoader.load_threaded_get(path) if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED else load(path)
		var authored: Node3D=packed.instantiate()
		if DisplayServer.get_name()=="headless":
			for node in authored.find_children("*","LightmapGI",true,false): node.light_data=null; node.free()
			for node in authored.find_children("*","ReflectionProbe",true,false): node.free()
		chunk.add_child(authored)
		register_authored(authored,r)
		if r.act>=2:
			Regional.feature_lights(self,r,authored); Regional.wall_joints(self,r,authored)
		world.scenery=saved
		return
	terrain(r)
	if r.indoor: dungeon_walls(r)
	for b in r.buildings: house(r,b)
	for item in r.props:
		var p: Vector2=r.origin+item.p
		var holder: Node3D=detail_prop(r,item,p)
		occluders.append({"node":holder,"p":p,"height":item.size.y})
		holder.set_meta("occluder",{"p":p,"height":item.size.y})
		kit.prepare_reveal(holder)
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
		if r.act==1: kit.instance("south_gate",world.scenery,world.point(Vector2(1100,1790)))
		else: kit.instance("a%d_gate" % r.act,world.scenery,world.point(Vector2(1100,1790)),Vector3(.85,.85,.85))
		camp_details(r)
		for at in r.npc_at:
			var light := OmniLight3D.new(); light.position=world.point(at+Vector2(58,15),115)
			light.light_color=Color("f4b57c"); light.light_energy=.7; light.omni_range=2.8
			chunk.add_child(light); lights.append(light)
	if r.act==1:
		ground_cover(r)
		if r.stage in [0,1,7]: authored_details(r)
		crafted_details(r,chunk)
	else:
		crafted_details(r,chunk); Regional.wall_joints(self,r,chunk)
	world.scenery=saved

func crafted_details(r, parent: Node3D) -> void:
	var group := Node3D.new(); group.name="CraftedSetDressing"; parent.add_child(group)
	group.set_meta("dressing_revision",1)
	for item in r.dressing:
		var values: Array=item.get("scale",[1,1,1])
		var p: Vector2=item.position
		var node: Node3D=kit.instance(item.model,group,world.point(r.origin+p,r.height_at(p)+float(item.get("height",0))),Vector3(values[0],values[1],values[2]),float(item.get("angle",0)))
		node.name=item.id; node.set_meta("dressing_id",item.id)
		if item.has("footprint"): node.set_meta("movement_footprint",item.rect)
		if item.get("reveal",false):
			kit.prepare_reveal(node)
			node.set_meta("occluder",{"p":r.origin+p,"height":float(item.get("occlusion_height",250))})
			occluders.append({"node":node,"p":r.origin+p,"height":float(item.get("occlusion_height",250))})
		if item.model in ["watch_map_table","archive_lectern","inn_table","candle_cluster"] or item.id=="forge_hearth":
			var light := OmniLight3D.new(); light.name="WorkLight"; node.add_child(light)
			light.position=Vector3(0,.95,0); light.light_color=Color("ffc083")
			light.light_energy=.32 if item.id!="forge_hearth" else .60
			light.omni_range=1.65; light.shadow_enabled=false; light.light_bake_mode=Light3D.BAKE_DYNAMIC
			lights.append(light)

func terrain(r) -> void:
	var mat := ShaderMaterial.new(); mat.shader=GROUND
	mat.set_shader_parameter("ground_tex",load("res://assets/world/terrain-%d.png" % ([0,5,2,3,4,5][r.act-1] if not r.indoor else 5)))
	mat.set_shader_parameter("road_tex",load("res://assets/world/terrain-2.png"))
	mat.set_shader_parameter("earth",EARTH[r.act-1]); mat.set_shader_parameter("road",ROAD[r.act-1])
	if r.act==1: physical_ground(mat,r.stage==0 or (r.indoor and r.stage!=7))
	else: Regional.ground(self,mat,r)
	if r.act==1 and r.stage in [0,1,7]:
		var soil_name := "mud" if r.stage==0 else "rock" if r.stage==7 else "soil"
		var road_name := "mud" if r.stage==1 else "rock" if r.stage==7 else "paving"
		for channel in ["albedo","normal","orm"]:
			mat.set_shader_parameter("ground_tex" if channel=="albedo" else "ground_"+channel,load(kit.BASE+"pbr/"+soil_name+"_"+channel+".png"))
			mat.set_shader_parameter("road_tex" if channel=="albedo" else "road_"+channel,load(kit.BASE+"pbr/"+road_name+"_"+channel+".png"))
	if Floors.architectural(r): mat=Floors.material(r)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 50 if r.act==1 and r.stage in [0,1,7] else 100
	var margin := 1000 if r.stage==0 else 0
	for y in range(-margin,int(r.extent.y)+margin,step):
		for x in range(-margin,int(r.extent.x)+margin,step):
			var center := Vector2(x+step*.5,y+step*.5)
			if r.indoor and r.floor_polygon.is_empty() and not room_at(r,center): continue
			if r.submerged(center): continue
			var pieces: Array[Rect2]=[Rect2(x,y,step,step)]
			if r.act>=2:
				for building in r.buildings: pieces=cut_rectangles(pieces,building.rect)
			for item in r.stairs:
				pieces=cut_rectangles(pieces,item.terrace); pieces=cut_rectangles(pieces,item.rect)
			if r.stage==0:
				for stage in world.campaign.map.outdoor:
					if stage==0: continue
					var other=world.campaign.map.regions[stage]
					pieces=cut_rectangles(pieces,Rect2(other.origin-r.origin,other.extent))
				for connector in world.campaign.map.connectors:
					var connector_parts: Array[Rect2]=[Rect2(connector.rect.position-r.origin,connector.rect.size)]
					connector_parts=cut_rectangles(connector_parts,Rect2(Vector2.ZERO,r.extent))
					for outside in connector_parts: pieces=cut_rectangles(pieces,outside)
			for piece in pieces:
				var vertices: Array[Vector2]=rect_vertices(piece)
				if not r.floor_polygon.is_empty():
					vertices=[]
					var quad := PackedVector2Array([piece.position,Vector2(piece.end.x,piece.position.y),piece.end,Vector2(piece.position.x,piece.end.y)])
					for polygon in Geometry2D.intersect_polygons(quad,r.floor_polygon):
						var indices := Geometry2D.triangulate_polygon(polygon)
						for i in range(0,indices.size(),3):
							var a: Vector2=polygon[indices[i]]; var b: Vector2=polygon[indices[i+1]]; var c: Vector2=polygon[indices[i+2]]
							if (b-a).cross(c-a)<0: vertices.append_array([a,c,b])
							else: vertices.append_array([a,b,c])
				for p in vertices:
					var path: float=1.0-smoothstep(55,150,r.path_distance(p))
					for b in r.buildings:
						if b.rect.grow(16).has_point(p): path=1.0
					st.set_color(Color(1,1,1,path)); st.set_uv(p/100)
					st.add_vertex(world.point(p+r.origin,r.base_height_at(p)))
	st.generate_normals()
	world.mesh_node(st.commit(),Vector3.ZERO,mat)
	for shoreline in r.shorelines: curved_river(r,shoreline)
	if not r.indoor and r.stage>0:
		# Rough stone ridges enclose sectors while leaving exit spans clear.
		var rng := RandomNumberGenerator.new(); rng.seed=r.act*311+r.stage*53
		for i in range(0,int(r.extent.x),180):
			for p in [Vector2(i,40),Vector2(i,r.extent.y-40),Vector2(40,i),Vector2(r.extent.x-40,i)]:
				if r.path_distance(p)<240: continue
				if r.act==1: kit.instance("rock_formation",world.scenery,world.point(r.origin+p,-30),Vector3(1.8,rng.randf_range(1.5,2.7),1.5),rng.randf()*TAU)
				else: kit.instance("a%d_rock" % r.act,world.scenery,world.point(r.origin+p,-30),Vector3(1.6,rng.randf_range(.8,1.5),1),rng.randf()*TAU)

func room_at(r, p: Vector2) -> bool:
	return r.floor_contains(p)

func rect_vertices(rect: Rect2) -> Array[Vector2]:
	var a := rect.position; var b := Vector2(rect.end.x,rect.position.y); var c := rect.end; var d := Vector2(rect.position.x,rect.end.y)
	return [a,b,c,a,c,d]

func cut_rectangles(input: Array[Rect2], hole: Rect2) -> Array[Rect2]:
	var output: Array[Rect2]=[]
	for piece in input:
		var overlap := piece.intersection(hole)
		if not overlap.has_area(): output.append(piece); continue
		for remainder in [Rect2(piece.position,Vector2(overlap.position.x-piece.position.x,piece.size.y)),Rect2(overlap.end.x,piece.position.y,piece.end.x-overlap.end.x,piece.size.y),Rect2(overlap.position.x,piece.position.y,overlap.size.x,overlap.position.y-piece.position.y),Rect2(overlap.position.x,overlap.end.y,overlap.size.x,piece.end.y-overlap.end.y)]:
			if remainder.has_area(): output.append(remainder)
	return output

func connector_ground(rect: Rect2, material: Material) -> void:
	var pieces: Array[Rect2]=[rect]
	for stage in world.campaign.map.outdoor:
		var r=world.campaign.map.regions[stage]
		pieces=cut_rectangles(pieces,Rect2(r.origin,r.extent))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces:
		for p in rect_vertices(piece):
			st.set_normal(Vector3.UP); st.set_color(Color(1,1,1,.9)); st.set_uv(p/100); st.add_vertex(world.point(p))
	if not pieces.is_empty(): world.mesh_node(st.commit(),Vector3.ZERO,material)

func dungeon_walls(r) -> void:
	if r.act>=2:
		Regional.walls(self,r); return
	if not r.floor_polygon.is_empty():
		cave_shell(r); dungeon_lights(r); return
	if r.layout=="castle":
		castle_shell(r); dungeon_lights(r); return
	var mat: Material=kit.pbr("masonry",Color("aab0ba")) if r.act==1 else stone(Color("69665f"))
	# Extract exposed edges of the union, so overlapping rooms have open joins.
	for y in range(0,4800,100):
		for x in range(0,4800,100):
			var p := Vector2(x+50,y+50)
			if not room_at(r,p): continue
			for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				if room_at(r,p+d*100): continue
				var at: Vector2=p+d*50+r.origin
				var size := Vector2(28,100) if d.x!=0 else Vector2(100,28)
				if r.act==1 and r.stage==7:
					if (x+y)%200==0:
						var rock_at: Vector2=at+d*15
						var rock: Node3D=kit.instance("rock_formation",world.scenery,world.point(rock_at,-12),Vector3(1.3,2.05,.32),PI*.5 if d.x!=0 else 0.0)
						occluders.append({"node":rock,"p":rock_at,"height":220.0})
					continue
				var node := block(Rect2(at-size*.5,size),190,0,mat)
				occluders.append({"node":node,"p":at,"height":190.0})
				# Capstones and pillars break up long wall silhouettes.
				block(Rect2(at-size*.5-Vector2.ONE*5,size+Vector2.ONE*10),12,190,stone(Color("878174")))
				if (x+y)%400==0:
					world.prop("dungeon/column",at,Vector3(52,230,52),Color("a49d8a"))
	dungeon_lights(r)

func dungeon_lights(r) -> void:
	for at in r.anchors+r.side_anchors:
		var light := OmniLight3D.new(); light.position=world.point(r.origin+at,180)
		light.light_color=Color("ffd094"); light.light_energy=1.2; light.omni_range=5.5
		world.scenery.add_child(light); lights.append(light)
		world.prop("dungeon/torch_lit",r.origin+at+Vector2(130,-90),Vector3(25,130,25),Color.WHITE,Color.WHITE,0,r.height_at(at))
	dungeon_details(r)

func cave_shell(r) -> void:
	var boundary: PackedVector2Array=r.floor_polygon
	var group := Node3D.new(); group.name="CaveRockShell"; world.scenery.add_child(group)
	group.set_meta("shared_boundary",true)
	var mat: StandardMaterial3D=kit.pbr("rock",Color("b2bcc6")).duplicate()
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	for i in boundary.size():
		var a: Vector2=boundary[i]; var b: Vector2=boundary[(i+1)%boundary.size()]
		# Leave the surface return opening unobstructed.
		if maxf(a.y,b.y)<5: continue
		var d := (b-a).normalized(); var n := d.orthogonal()
		if r.floor_contains((a+b)*.5+n*8): n=-n
		var h0 := 270+48*sin(i*.67); var h1 := 270+48*sin((i+1)*.67)
		var points: Array[Vector3]=[world.point(r.origin+a,-8),world.point(r.origin+b,-8),world.point(r.origin+b+n*65,-8),world.point(r.origin+a+n*65,-8),world.point(r.origin+a+n*12,h0),world.point(r.origin+b+n*12,h1),world.point(r.origin+b+n*92,h1+22),world.point(r.origin+a+n*92,h0+22)]
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Rock face and sloping exposed ceiling rim; use two-sided geology only here.
		for face in [[0,1,5,4],[4,5,6,7],[3,7,6,2],[0,4,7,3],[1,2,6,5]]:
			for index in [face[0],face[1],face[2],face[0],face[2],face[3]]:
				st.set_uv(Vector2(points[index].x,points[index].y)*.5); st.add_vertex(points[index])
		st.generate_normals()
		var mesh := MeshInstance3D.new(); mesh.mesh=st.commit(); mesh.material_override=mat; group.add_child(mesh)
		var at: Vector2=r.origin+(a+b)*.5
		mesh.set_meta("occluder",{"p":at,"height":h0}); kit.prepare_reveal(mesh)
		occluders.append({"node":mesh,"p":at,"height":h0})
		if i%5==0:
			var rock: Node3D=kit.instance("strata_outcrop",group,world.point(r.origin+(a+b)*.5+n*45,-15),Vector3(.45,.9,.7),-atan2(d.y,d.x))
			rock.set_meta("occluder",{"p":at,"height":200.0}); kit.prepare_reveal(rock)
			occluders.append({"node":rock,"p":at,"height":200.0})
		if i%11==0: kit.instance("cave_stalactites",group,world.point(r.origin+(a+b)*.5+n*20,h0-65),Vector3(.7,.7,.7))

func castle_shell(r) -> void:
	var group := Node3D.new(); group.name="CastleArchitecture"; world.scenery.add_child(group)
	# Merge collinear boundaries before placing modules, preserving brick density.
	var lines: Dictionary={}
	for y in range(0,int(r.extent.y),100):
		for x in range(0,int(r.extent.x),100):
			var p := Vector2(x+50,y+50)
			if not room_at(r,p): continue
			for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				if room_at(r,p+d*100) or (y==0 and d==Vector2.UP): continue
				var at: Vector2=p+d*50
				var key := "%d:%d:%d" % [int(d.x),int(d.y),int(at.x if d.x!=0 else at.y)]
				if not lines.has(key): lines[key]={"d":d,"line":at.x if d.x!=0 else at.y,"starts":[]}
				lines[key].starts.append(y if d.x!=0 else x)
	var count := 0
	for entry in lines.values():
		entry.starts.sort()
		var starts: Array=entry.starts; var cursor := 0
		while cursor<starts.size():
			var first: float=starts[cursor]; var last: float=first+100; cursor+=1
			while cursor<starts.size() and starts[cursor]==last: last+=100; cursor+=1
			var begin := first
			while begin<last:
				var length := minf(300,last-begin)
				var at := Vector2(entry.line,begin+length*.5) if entry.d.x!=0 else Vector2(begin+length*.5,entry.line)
				at+=r.origin
				var node: Node3D=kit.instance("castle_wall_broken" if count%13==0 else "castle_wall",group,world.point(at),Vector3(length/300,1,1),PI*.5 if entry.d.x!=0 else 0)
				node.set_meta("occluder",{"p":at,"height":325.0}); kit.prepare_reveal(node)
				occluders.append({"node":node,"p":at,"height":325.0})
				if count%2==0: kit.instance("castle_buttress",group,world.point(at+entry.d*50),Vector3(.7,1,.7),PI*.5 if entry.d.x!=0 else 0)
				begin+=length; count+=1
	for p in [Vector2(1570,1410),Vector2(4830,1410),Vector2(710,2180),Vector2(5690,2180),Vector2(2510,5300),Vector2(3890,5300)]:
		var tower: Node3D=kit.instance("castle_tower",group,world.point(p+r.origin),Vector3.ONE)
		tower.set_meta("occluder",{"p":p+r.origin,"height":540.0}); kit.prepare_reveal(tower)
		occluders.append({"node":tower,"p":p+r.origin,"height":540.0})
	kit.instance("castle_gateway",group,world.point(r.origin+Vector2(3200,1250)))
	for y in [2950,3750,4400]:
		var vault: Node3D=kit.instance("castle_vault",group,world.point(r.origin+Vector2(3200,y)),Vector3(.85,1,.85))
		vault.set_meta("occluder",{"p":r.origin+Vector2(3200,y),"height":550.0}); kit.prepare_reveal(vault)
		occluders.append({"node":vault,"p":r.origin+Vector2(3200,y),"height":550.0})
	for at in [Vector2(2800,1100),Vector2(3600,1100),Vector2(1600,1700),Vector2(4800,1700),Vector2(950,3100),Vector2(5450,3100),Vector2(2700,3000),Vector2(3700,3000),Vector2(2700,4200),Vector2(3700,4200),Vector2(2800,6100),Vector2(3600,6100)]:
		var base: float=r.height_at(at)
		kit.instance("road_shrine",group,world.point(r.origin+at,base))
		var light := OmniLight3D.new(); light.position=world.point(r.origin+at,base+150)
		light.light_color=Color("ffd19a"); light.light_energy=.8; light.omni_range=4.2
		light.light_bake_mode=Light3D.BAKE_DYNAMIC; group.add_child(light); lights.append(light)

func house(r, b: Dictionary) -> void:
	if r.act>=2:
		Regional.house(self,r,b); return
	var rect: Rect2=Rect2(b.rect.position+r.origin,b.rect.size)
	if r.act==1 and r.stage==0:
		var role: int=b.role
		var node: Node3D=kit.instance("service_%d" % role,world.scenery,world.point(rect.get_center()))
		var roof: Node3D=node.find_child("Roof*",true,false); var front: Node3D=node.find_child("Front*",true,false)
		kit.prepare_reveal(roof); kit.prepare_reveal(front)
		var side: Node3D=node.find_child("Side*",true,false)
		if side: kit.prepare_reveal(side)
		node.set_meta("building_rect",rect)
		roofs.append({"roof":roof,"front":front,"side":side,"rect":rect,"amount":1.0,"inside":false})
		return
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
	var mat: Material=kit.pbr("masonry",Color("cec4ae")) if r.act==1 else kit.pbr("a%d_wall" % r.act,Color("dedbd2"))
	if Floors.architectural(r): mat=Floors.material(r)
	if mat is StandardMaterial3D:
		var tiled: StandardMaterial3D=mat.duplicate()
		tiled.uv1_triplanar=true; tiled.uv1_world_triplanar=true; tiled.uv1_scale=Vector3.ONE*.55
		mat=tiled
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
	world.mesh_node(mesh,world.point(p,base+4),kit.pbr("paving",Color("adb1b9")) if world.campaign.map.act==1 else stone(Color("6a6564")))
	var ring := TorusMesh.new(); ring.inner_radius=.86; ring.outer_radius=1.01
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color("537f88"); mat.emission_enabled=true; mat.emission=Color("365c66"); mat.emission_energy_multiplier=.3
	world.mesh_node(ring,world.point(p,base+10),mat)
	for i in 5:
		var at := p+Vector2(cos(i*TAU/5),sin(i*TAU/5))*147
		if world.campaign.map.act==1:
			block(Rect2(at-Vector2(22,18),Vector2(44,36)),45,base,kit.pbr("masonry",Color("bcc4ce")))
			block(Rect2(at-Vector2(12,10),Vector2(24,20)),3,base+45,world.material(Color("6e9aa9")))
		else: block(Rect2(at-Vector2(22,18),Vector2(44,36)),45,base,kit.pbr("a%d_wall" % world.campaign.map.act))

func entrance(door: Dictionary) -> void:
	var p: Vector2=door.p
	if world.campaign.map.act==1:
		if door.get("architecture","")=="castle":
			kit.instance("castle_gateway",world.scenery,world.point(p+Vector2(0,-100)))
			for offset in [-380,380]:
				kit.instance("castle_tower",world.scenery,world.point(p+Vector2(offset,-170)),Vector3(1.2,1.2,1.2))
				kit.instance("castle_wall",world.scenery,world.point(p+Vector2(offset,-310)),Vector3(1.5,1.2,1))
		else: kit.instance("cave_portal",world.scenery,world.point(p+Vector2(0,-100)))
	else: kit.instance("a%d_gate" % world.campaign.map.act,world.scenery,world.point(p+Vector2(0,-100)))
	if world.campaign.map.act!=1:
		var black: StandardMaterial3D=world.material(Color("111319"))
		block(Rect2(p-Vector2(120,110),Vector2(240,240)),4,-3,black)
	for i in (6 if world.campaign.map.act==1 else 0): block(Rect2(p+Vector2(-90,-120+i*20),Vector2(180,20)),6,3+i*2,kit.pbr("masonry"))

func sync(focus: Vector2, dt: float = 0.0) -> void:
	for chunk in chunks:
		if chunk.rect.grow(2000).has_point(focus) and chunk.node.get_child_count()==0: populate_chunk(chunk.region,chunk.node)
		elif not chunk.rect.grow(3500).has_point(focus) and chunk.node.get_child_count()>0:
			for child in chunk.node.get_children(): chunk.node.remove_child(child); child.queue_free()
	roofs=roofs.filter(func(item): return is_instance_valid(item.roof) and item.roof.is_inside_tree())
	occluders=occluders.filter(func(item): return is_instance_valid(item.node) and item.node.is_inside_tree())
	cache_models=cache_models.filter(func(item): return is_instance_valid(item.node) and item.node.is_inside_tree())
	lights=lights.filter(func(node): return is_instance_valid(node) and node.is_inside_tree())
	for item in cache_models:
		var opened: bool=world.campaign.state.get("opened_chests",{}).has(item.id)
		world.assets.chest_state(item.node,opened,opened)
	for chunk in chunks: chunk.node.visible=chunk.rect.grow(1700).has_point(focus)
	for item in roofs:
		var inside: bool=item.rect.grow(85 if item.get("inside",false) else 45).has_point(world.campaign.hero_at)
		item.inside=inside
		var target := 0.0 if inside else 1.0
		item.amount=move_toward(float(item.get("amount",1.0)),target,dt*4.0) if dt>0 else target
		kit.reveal(item.roof,0.0 if item.get("ruined",false) else item.amount); kit.reveal(item.front,item.amount)
		if item.get("side")!=null: kit.reveal(item.side,item.amount)
	for item in occluders:
		var distance: float=item.p.distance_to(focus)
		# Reveal the character behind a foreground tree or tall wall; collision stays.
		var projected: Vector2=world.project(item.p)-world.project(focus)
		var blocked: bool=distance<320 and projected.y>0 and absf(projected.x)<95 and item.height>140
		var amount := move_toward(float(item.get("amount",1.0)),0.0 if blocked else 1.0,dt*4.0) if dt>0 else (0.0 if blocked else 1.0)
		item.amount=amount; kit.reveal(item.node,amount)
	for light in lights: light.visible=Vector2(light.global_position.x,light.global_position.z).distance_to(focus*.01)<16

func camp_details(r) -> void:
	if r.act>=2:
		Regional.camp(self,r); return
	var mat: Material=kit.pbr("masonry",Color("b7bbbf")) if r.act==1 else stone(Color("666054"),r.act in [1,3,5])
	# Outer enclosure keeps the playable border legible in the orthographic view.
	for x in range(80,2200,180):
		block(Rect2(x,60,175,30),95,0,mat)
		if absf(x-1100)>300: block(Rect2(x,1880,175,35),95,0,mat)
	for y in range(120,1800,180):
		for x in [60,2110]: block(Rect2(x,y,30,175),95,0,mat)
	for at in [Vector2(-180,100),Vector2(2290,480),Vector2(2340,1590),Vector2(-240,1660)]:
		if r.act==1: kit.instance("woodland_tree",world.scenery,world.point(at),Vector3.ONE)
		else: world.prop("nature/tree_3" if r.act==4 else "halloween/tree_dead_large",at,Vector3(260,410,210),Color("9a968d"),Color("666959"))
	if r.act==1:
		# Broken defensive tops, drains and scattered rubble frame the open street.
		for x in range(90,2140,120):
			block(Rect2(x,45,65,60),45,95,mat)
			if absf(x-1100)>300: block(Rect2(x,1870,65,60),36,95,mat)
		for y in range(160,1790,140):
			for x in [55,2105]: block(Rect2(x,y,60,62),36,95,mat)
		for at in [Vector2(250,900),Vector2(1910,1370),Vector2(310,1610),Vector2(1770,1740)]:
			kit.instance("rubble",world.scenery,world.point(at),Vector3.ONE*.65)
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
	elif r.layout=="mine" and not (r.act==1 and r.stage==7):
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
	if r.act==1 and r.stage==7:
		# Exposed rock and supports distinguish the first optional cave from a hall.
		for p in r.side_anchors:
			kit.instance("rock_formation",world.scenery,world.point(r.origin+p+Vector2(180,-110)),Vector3(1.3,1.1,1.0))

func physical_ground(mat: ShaderMaterial, paved: bool) -> void:
	mat.set_shader_parameter("use_pbr",true)
	for prefix in ["ground","road"]:
		var role := "soil" if prefix=="ground" else "paving"
		for slot in ["normal","orm"]: mat.set_shader_parameter(prefix+"_"+slot,load(kit.BASE+"pbr/"+role+"_"+slot+".png"))
		mat.set_shader_parameter(prefix+"_tex",load(kit.BASE+"pbr/"+role+"_albedo.png"))
	mat.set_shader_parameter("earth",Color("c7c8bd")); mat.set_shader_parameter("road",Color("d5d3cd"))
	mat.set_shader_parameter("paving",.04 if paved else 0.0)

func detail_prop(r, item: Dictionary, p: Vector2) -> Node3D:
	if item.key.begins_with("kit/"):
		return kit.instance(item.key.trim_prefix("kit/"),world.scenery,world.point(p,r.height_at(item.p)),Vector3.ONE,item.angle)
	if r.act>=2:
		var model := "rock"
		if "tree" in item.key or "waterplant" in item.key: model="tree"
		elif "pillar" in item.key or "arch" in item.key: model="arch"
		elif "building" in item.key: model="hero"
		elif "wall" in item.key: model="wall_broken"
		var scale: Vector3=Vector3.ONE*(item.size.y/300.0 if model=="tree" else .7)
		return kit.instance("a%d_%s" % [r.act,model],world.scenery,world.point(p,r.height_at(item.p)),scale,item.angle)
	if r.act==1:
		var at: Vector3=world.point(p,r.height_at(item.p))
		if item.key=="story/rubble": return kit.instance("rubble",world.scenery,at,Vector3.ONE*.85)
		if item.key=="story/pier": return block(Rect2(p-Vector2(20,20),Vector2(40,40)),item.size.y,r.height_at(item.p),kit.pbr("masonry",Color("a2a5a1")))
		if item.key=="story/fence":
			var holder := Node3D.new(); world.scenery.add_child(holder)
			block(Rect2(p-Vector2(7,7),Vector2(14,14)),75,r.height_at(item.p),kit.pbr("timber"),holder)
			block(Rect2(p-Vector2(5,80),Vector2(10,160)),10,r.height_at(item.p)+47,kit.pbr("timber"),holder)
			return holder
		if item.key.begins_with("nature/tree"):
			return kit.instance("woodland_tree",world.scenery,at,Vector3.ONE*(item.size.y/380.0),item.angle)
		if "tree_dead" in item.key:
			var tree: Node3D=kit.instance("forest_tree",world.scenery,at,item.size*Vector3(.005,.00303,.005),item.angle)
			tree.find_child("Leaves*",true,false).hide()
			return tree
		if "rock_single" in item.key:
			return kit.instance("rock_formation",world.scenery,at,item.size*Vector3(.008,.009,.009),item.angle)
		if item.key=="medieval/building_castle_red":
			return kit.instance("service_0",world.scenery,at,Vector3(2.0,1.8,1.5))
		if item.key=="medieval/building_tower_A_red":
			return kit.instance("service_0",world.scenery,at,Vector3(.65,1.3,.65))
		if item.key=="dungeon/wall_broken":
			return kit.instance("wall_section",world.scenery,at,item.size*Vector3(.00333,.0083,.02),item.angle)
	return world.prop(item.key,p,item.size,Color("adaba0"),Color("657666"),item.angle,r.height_at(item.p))

func ground_cover(r) -> void:
	if r.indoor: return
	if r.indoor: return
	var rng := RandomNumberGenerator.new(); rng.seed=19001+r.stage*617
	var transforms: Array[Transform3D]=[]
	for i in (1200 if r.stage>0 else 260):
		var p := Vector2(rng.randf_range(120,r.extent.x-120),rng.randf_range(120,r.extent.y-120))
		if r.path_distance(p)<150 or not r.walkable(p,35): continue
		if r.stage==0 and p.x>420 and p.x<1780: continue
		var size := rng.randf_range(.65,1.25)
		var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size)
		transforms.append(Transform3D(basis,world.point(r.origin+p,r.height_at(p)+1)))
	var cells: Dictionary={}
	for transform in transforms:
		var cell := Vector2i(floori(transform.origin.x/16),floori(transform.origin.z/16))
		if not cells.has(cell): cells[cell]=[]
		cells[cell].append(transform)
	for group in cells.values():
		cover_batch(kit.grass_mesh(),group,kit.surface("Leaf"))
		var chosen: Array=[]
		for i in range(0,group.size(),3): chosen.append(group[i])
		cover_batch(kit.fern_mesh(),chosen)

func cover_batch(mesh: Mesh, transforms: Array, material: Material = null) -> void:
	var multi := MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=mesh; multi.instance_count=transforms.size()
	for i in transforms.size(): multi.set_instance_transform(i,transforms[i])
	var node := MultiMeshInstance3D.new(); node.multimesh=multi; node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world.scenery.add_child(node)

func register_authored(root: Node3D, region) -> void:
	for node in root.find_children("*","Node3D",true,false):
		if node.has_meta("licensed_tree") or node.name.begins_with("woodland_tree"):
			kit.refresh_tree(node)
		if node is FogVolume and world.has_node("/root/GraphicsQuality"):
			var graphics=world.get_node("/root/GraphicsQuality")
			node.visible=graphics.advanced() and graphics.quality==0
		if node is MeshInstance3D and node.material_override is ShaderMaterial and node.material_override.shader==GROUND:
			if Floors.architectural(region): node.material_override=Floors.material(region)
			elif region.act>=2: Regional.ground(self,node.material_override,region)
			else:
				node.material_override.set_shader_parameter("earth",Color("c7c8bd")); node.material_override.set_shader_parameter("road",Color("d5d3cd"))
		if node.has_meta("building_rect"):
			var roof: Node3D=node.find_child("Roof*",true,false); var front: Node3D=node.find_child("Front*",true,false)
			var side: Node3D=node.find_child("Side*",true,false)
			kit.prepare_reveal(roof); kit.prepare_reveal(front)
			if side: kit.prepare_reveal(side)
			roofs.append({"roof":roof,"front":front,"side":side,"rect":node.get_meta("building_rect"),"amount":1.0,"inside":false})
		elif node.has_meta("reveal_roof_rect") and not node.get_parent().has_meta("building_rect"):
			for front in root.find_children("*","Node3D",true,false):
				if front.has_meta("reveal_front_rect") and front.get_meta("reveal_front_rect")==node.get_meta("reveal_roof_rect"):
					roofs.append({"roof":node,"front":front,"rect":node.get_meta("reveal_roof_rect"),"amount":1.0,"inside":false})
		if node.has_meta("occluder"):
			kit.prepare_reveal(node)
			var entry: Dictionary=node.get_meta("occluder").duplicate(); entry.node=node; occluders.append(entry)
		if node.has_meta("story_cache"): cache_models.append({"node":node,"id":node.get_meta("story_cache")})
		if node is Light3D and not node is DirectionalLight3D: lights.append(node)
		if node.is_in_group("editor_only"): node.queue_free()

func curved_river(r, polygon: PackedVector2Array) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(polygon)
	for index in triangles:
		st.set_normal(Vector3.UP); st.add_vertex(world.point(r.origin+polygon[index],-25))
	var material := ShaderMaterial.new(); material.shader=WATER
	world.mesh_node(st.commit(),Vector3.ZERO,material)
	for i in range(0,polygon.size(),3):
		var p: Vector2=polygon[i]
		kit.instance("rock_formation",world.scenery,world.point(r.origin+p,-27),Vector3(.38,.20,.38),i*.83)

func authored_details(r) -> void:
	if r.stage==0:
		for b in r.buildings:
			var rect: Rect2=b.rect
			# Small worn aprons organize each workplace instead of paving the whole camp.
			block(Rect2(rect.position+r.origin-Vector2(12,12),rect.size+Vector2(24,24)),5,-2,kit.pbr("paving",Color("a4a9a8")))
		for y in range(230,1720,150):
			block(Rect2(1000,y,18,140),5,-2,kit.pbr("rock",Color("7a8184")))
			block(Rect2(1190,y,18,140),5,-2,kit.pbr("rock",Color("7a8184")))
		kit.instance("arcade_intact",world.scenery,world.point(Vector2(190,900)),Vector3.ONE*.8,PI/2)
		kit.instance("ruin_column_broken",world.scenery,world.point(Vector2(1850,1800)))
	elif r.stage==1:
		kit.instance("pointed_arch_broken",world.scenery,world.point(r.origin+Vector2(1200,280)),Vector3.ONE*.8)
		var ridges := [Vector2(3950,600),Vector2(4180,930),Vector2(4100,1270),Vector2(810,3500)]
		for i in ridges.size():
			kit.instance("cliff",world.scenery,world.point(r.origin+ridges[i],r.height_at(ridges[i])-45),Vector3(.8,.7,.65),float(i)*.8)
	elif r.stage==7:
		for i in range(r.side_anchors.size()):
			var p: Vector2=r.side_anchors[i]+Vector2(-210,110)
			kit.instance("tool_rack" if i==0 else "cargo" if i==1 else "handcart",world.scenery,world.point(p,r.height_at(p)))
			var puddle := PlaneMesh.new(); puddle.size=Vector2(1.6,1.0)
			var water := ShaderMaterial.new(); water.shader=WATER; water.set_shader_parameter("puddle",true)
			var pool: MeshInstance3D=world.mesh_node(puddle,world.point(p+Vector2(90,35),r.height_at(p)+4),water)
			pool.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	# Local fog stays near the ground, leaving silhouettes and the road readable.
	var positions: Array=[Vector2(180,800),Vector2(2040,1400)] if r.stage==0 else [Vector2(520,1900),Vector2(520,3300),Vector2(900,2200)] if r.stage==1 else [Vector2(1100,1900),Vector2(2800,3300)]
	for p in positions:
		var volume := FogVolume.new(); volume.size=Vector3(5,1.7,6)
		volume.position=world.point(r.origin+p,r.height_at(p)+50)
		var material := ShaderMaterial.new(); material.shader=preload("res://resources/story_mist.gdshader")
		volume.material=material; world.scenery.add_child(volume); volume.add_to_group("quality_fog",true)
		if world.has_node("/root/GraphicsQuality"): volume.visible=world.get_node("/root/GraphicsQuality").advanced() and world.get_node("/root/GraphicsQuality").quality==0
	var probe := ReflectionProbe.new(); probe.size=Vector3(r.extent.x*.01,8,r.extent.y*.01)
	probe.position=world.point(r.origin+r.extent*.5,160); probe.intensity=.45
	probe.box_projection=true; probe.update_mode=ReflectionProbe.UPDATE_ONCE
	world.scenery.add_child(probe)

func release_resources() -> void:
	for path in pending_paths:
		if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: ResourceLoader.load_threaded_get(path)
	pending_paths.clear()
	kit.scenes.clear(); kit.materials.clear(); kit.vendor_tree_mesh=null
