extends Node3D
## Presentation only. Ruins remains the authoritative movement/collision map.
## 100 simulation pixels = one metre; simulation (x,y) maps to 3D (x,0,z).
const UNIT := 0.01
const AssetLibrary = preload("res://scripts/scene_assets.gd")
const AssetLayout = preload("res://scripts/scene_asset_layout.gd")
var assets := AssetLibrary.new()
var view_camera: Camera3D
var scenery: Node3D
var source: Ruins
var seed_value := -1
var sprites: Array[Sprite3D] = []
var used := 0
var materials: Dictionary = {}
var chest_meshes: Dictionary = {}

func prop(key: String, at: Vector2, size: Vector3, tint: Color = Color.WHITE, foliage: Color = Color.WHITE, angle: float = 0.0, base: float = 0.0) -> Node3D:
	return assets.place(scenery,key,point(at,base),size*UNIT,tint,foliage,angle)

func landmark(item: Dictionary, interior: bool) -> void:
	var at: Vector2=item.p
	var h: float=item.size
	var building: Dictionary={} if interior else AssetLayout.building(item)
	if not building.is_empty():
		var rect: Rect2=building.rect
		prop(building.model,rect.get_center(),Vector3(rect.size.x,building.height,rect.size.y),Color("d8ccd9"))
	elif int(item.type)==1:
		prop("nature/tree_1",at,Vector3(h*0.72,h,h*0.48),Color.WHITE,Color("a9859c"))
	elif int(item.type)==4:
		prop("halloween/tree_dead_large",at,Vector3(0,h,0),Color("aca8c2"))
		prop("halloween/shrine_candles",at+Vector2(48,18),Vector3(0,65,0))
	elif int(item.type)==5:
		prop("halloween/shrine_candles",at,Vector3(h*0.65,h*0.8,h*0.28),Color("e1c9d4"))
	else:
		prop("halloween/arch",at,Vector3(h*0.8,h*0.82,30),Color("d2c6df"))
	# Lanterns frame entrances without creating a solid plane across the opening.
	for side in [-1,1]:
		prop("halloween/lantern_standing",at+Vector2(side*h*0.48,40),Vector3(0,65,0),Color("ece0de"))

func wall_assets(wall: Rect2, interior: bool) -> void:
	if is_equal_approx(wall.size.x,wall.size.y):
		prop("dungeon/pillar_decorated",wall.get_center(),Vector3(wall.size.x,150,wall.size.y),Color("cfc3d8"))
		return
	var horizontal := wall.size.x>wall.size.y
	var length := maxf(wall.size.x,wall.size.y)
	var count := maxi(1,int(ceil(length/145.0)))
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	for i in count:
		var at := wall.get_center()+axis*((i+0.5)*length/count-length/2)
		var key := "dungeon/wall" if interior else ("dungeon/wall_cracked" if i%2==0 else "dungeon/wall_broken")
		prop(key,at,Vector3(length/count,110 if interior else 76,minf(wall.size.x,wall.size.y)),Color("c5bfd6"),Color.WHITE,0 if horizontal else PI/2)

func _ready() -> void:
	view_camera=Camera3D.new()
	view_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	view_camera.keep_aspect=Camera3D.KEEP_HEIGHT
	view_camera.near=0.1
	view_camera.far=180.0
	add_child(view_camera)
	view_camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-28,0)
	sun.light_color=Color("e0c6d5")
	sun.light_energy=0.65
	sun.shadow_enabled=true
	add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("172632")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("9bacc9")
	environment.environment.ambient_light_energy=0.5
	add_child(environment)

static func point(p: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(p.x*UNIT,height*UNIT,p.y*UNIT)

func sync(world: Ruins, focus: Vector2, screen: Vector2) -> void:
	if source!=world or seed_value!=world.map_seed:
		rebuild(world)
	view_camera.size=screen.y*UNIT
	var target := point(focus)
	view_camera.position=target+Vector3(0,24,19)
	view_camera.look_at(target)

func project(p: Vector2) -> Vector2:
	return view_camera.unproject_position(point(p))

func unproject(screen: Vector2) -> Vector2:
	var hit: Variant=Plane(Vector3.UP,0).intersects_ray(view_camera.project_ray_origin(screen),view_camera.project_ray_normal(screen))
	if hit==null: return Vector2.ZERO
	return Vector2(hit.x,hit.z)/UNIT

func ground_transform() -> Transform2D:
	var origin := project(Vector2.ZERO)
	return Transform2D((project(Vector2.RIGHT*100)-origin)/100,(project(Vector2.DOWN*100)-origin)/100,origin)

func material(color: Color, texture: Texture2D = null) -> StandardMaterial3D:
	var key := str(color)+":"+str(texture.get_instance_id() if texture else 0)
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.albedo_texture=texture
	if texture:
		mat.uv1_triplanar=true
		mat.uv1_scale=Vector3.ONE*0.7
	mat.roughness=0.92
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	materials[key]=mat
	return mat

func mesh_node(mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh
	node.position=at
	node.material_override=mat
	scenery.add_child(node)
	return node

func box(rect: Rect2, height: float, color: Color, base: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=Vector3(rect.size.x,height,rect.size.y)*UNIT
	return mesh_node(mesh,point(rect.get_center(),base+height/2),material(color,load("res://assets/world/terrain-1.png")))

func floor_tile(rect: Rect2, texture: Texture2D, color: Color = Color.WHITE, height: float = 0.0) -> void:
	var mesh := PlaneMesh.new()
	mesh.size=rect.size*UNIT
	var mat: StandardMaterial3D=material(color,texture).duplicate()
	mat.uv1_triplanar=false
	mat.uv1_scale=Vector3.ONE
	mesh_node(mesh,point(rect.get_center(),height),mat)

func polygon(points: PackedVector2Array, height: float, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty(): return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(point(points[index],height))
	mesh_node(surface.commit(),Vector3.ZERO,material(color))

func prism(points: PackedVector2Array, height: float, color: Color) -> void:
	polygon(points,height,color)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var a := point(points[i])
		var b := point(points[(i+1)%points.size()])
		var c := b+Vector3.UP*height*UNIT
		var d := a+Vector3.UP*height*UNIT
		for vertex in [a,b,c,a,c,d]: surface.add_vertex(vertex)
	surface.generate_normals()
	mesh_node(surface.commit(),Vector3.ZERO,material(color.darkened(0.2)))

func cone(at: Vector2, radius: float, height: float, color: Color, base: float = 0.0, tip: float = 0.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius=radius*UNIT
	mesh.top_radius=tip*UNIT
	mesh.height=height*UNIT
	mesh.radial_segments=7
	mesh_node(mesh,point(at,base+height/2),material(color))

func rebuild(world: Ruins) -> void:
	if scenery:
		remove_child(scenery)
		scenery.queue_free()
	scenery=Node3D.new()
	scenery.name="Scenery"
	add_child(scenery)
	chest_meshes.clear()
	source=world
	seed_value=world.map_seed
	if world.interior:
		for y in range(0,2200,400):
			for x in range(0,2800,400):
				floor_tile(Rect2(x,y,400,400),load("res://assets/world/terrain-5.png"),Color("a39da9"))
		box(Rect2(1280,370,240,1580),1,Color("683b51"))
		for site in world.sites:
			box(site.rect,0.5,Color("9b8d93"))
	else:
		for y in 3:
			for x in 4:
				floor_tile(Rect2(Vector2(x,y)*1600*Ruins.MAP_SCALE,Vector2.ONE*1600*Ruins.MAP_SCALE),load("res://assets/world/ground-%d-%d.jpg" % [x,y]))
		polygon(world.river,0.8,Color("416c7f"))
		for feature in world.features:
			if feature.kind=="lake": polygon(feature.polygon,1,Color("446d80"))
			else:
				# Preserve the exact irregular collision silhouette below the rock crowns.
				prism(feature.polygon,75,Color("8a8297"))
				prop("medieval/rock_single_A",feature.p,Vector3(feature.radius,70,feature.radius),Color("b0a3c3"),Color.WHITE,0,74)
		for bridge in world.bridges:
			# Imported plank modules end at the simulation plane (no false raised deck).
			for i in 4:
				var x: float=bridge.position.x+(i+0.5)*bridge.size.x/4
				prop("dungeon/floor_wood_large",Vector2(x,bridge.get_center().y),Vector3(bridge.size.x/4,12,bridge.size.y),Color("c1adb6"),Color.WHITE,0,-10.5)
				for y in [bridge.position.y,bridge.end.y]:
					prop("dungeon/barrier",Vector2(x,y),Vector3(bridge.size.x/4,35,10),Color("d0c2da"))
	for wall in world.walls:
		wall_assets(wall,world.interior)
	for item in world.decor:
		var at: Vector2=item.p
		var h: float=item.size
		var biome := world.biome_at(at)
		if item.landmark:
			landmark(item,world.interior)
		elif int(item.type)==1:
			var leaves := Color("9c718d") if biome==3 else Color("76958a")
			prop("nature/tree_1" if int(at.x)%2==0 else "nature/tree_3",at,Vector3(h*0.7,h,h*0.6),Color.WHITE,leaves,at.x)
		elif int(item.type)==4:
			prop("halloween/tree_dead_medium",at,Vector3(0,h,0),Color("9c9fb5"),Color.WHITE,at.x)
			prop("medieval/waterplant_A",at+Vector2(22,12),Vector3(0,30,0),Color("94bac0"))
		elif int(item.type)==2:
			prop("medieval/rock_single_B",at,Vector3(h*0.6,h*0.65,h*0.5),Color("c2abd9"),Color.WHITE,at.x)
		elif int(item.type)==3:
			prop("dungeon/rubble_large",at,Vector3(0,h*0.4,0),Color("bab0c8"),Color.WHITE,at.x)
		else:
			prop("halloween/gravestone",at,Vector3(0,h*0.5,0),Color("cbbfd4"),Color.WHITE,0.2)
	if world.interior:
		for x in [700,2100]:
			for y in [400,760,1210,1760]:
				prop("dungeon/banner_shield_red",Vector2(x,y),Vector3(0,84,0),Color("ddc4da"),Color.WHITE,0,70)
		for x in [1120,1680]:
			prop("dungeon/table_long_decorated_A",Vector2(x,400),Vector3(135,65,55),Color("d3bfd1"))

func begin_sprites() -> void:
	used=0

func end_sprites() -> void:
	for i in range(used,sprites.size()): sprites[i].hide()

func submit_sprite(texture: Texture2D, rect: Rect2, region: Rect2, tint: Color, pose: Transform2D) -> void:
	if used==sprites.size():
		var sprite := Sprite3D.new()
		sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		sprite.no_depth_test=false
		sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		sprites.append(sprite)
	var sprite := sprites[used]
	used+=1
	sprite.show()
	sprite.texture=texture
	sprite.region_enabled=region.size!=Vector2.ZERO
	sprite.region_rect=region
	var source_size := region.size if sprite.region_enabled else texture.get_size()
	var factor := rect.size/source_size
	sprite.pixel_size=UNIT
	# A fully camera-facing quad leans backwards into cliffs at head height.
	# Keep its entire height over the ground anchor. Compensate foreshortening
	# so authored frame sizes and upright nameplates retain their screen scale.
	var vertical_projection := maxf(0.1,view_camera.global_basis.y.dot(Vector3.UP))
	sprite.scale=Vector3(factor.x,factor.y/vertical_projection,1)
	sprite.offset=Vector2(rect.get_center().x/factor.x,-rect.get_center().y/factor.y)
	sprite.flip_h=pose.determinant()<0
	if sprite.flip_h: sprite.offset.x=-sprite.offset.x
	sprite.position=point(pose.origin,2)
	sprite.modulate=tint


func sync_chests(chests: Array) -> void:
	var live := {}
	for chest in chests:
		var key := str(chest.p)
		live[key]=true
		var empty: bool=chest.open and chest.items.is_empty()
		if not chest_meshes.has(key):
			var gold: bool=int(chest.get("cache_tier",0))>=3 or chest.get("bonus",false)
			var tone: Color=Color.WHITE.lerp(Catalog.quality_color(int(chest.get("cache_tier",0))),0.2)
			chest_meshes[key]=prop("dungeon/chest_gold" if gold else "dungeon/chest",chest.p,Vector3(48,34,32),tone)
		assets.chest_state(chest_meshes[key],chest.open,empty)
	for key in chest_meshes.keys():
		if not live.has(key):
			chest_meshes[key].queue_free()
			chest_meshes.erase(key)
