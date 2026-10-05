extends RefCounted
## SigilsVault Modular Cathedral Kit, CC0. Native stone trims, uniform scale.
const ROOT := "res://assets/vendor/sigils-cathedral/models/"
const FOUNTAIN := "res://assets/vendor/kenney-props/models/fountain.glb"
var templates: Dictionary = {}
var bounds: Dictionary = {}
var materials: Dictionary = {}
var site: Node3D
var buildings: Array = []
var open_stations: Array = []

func model(key: String, at: Vector2, scale_factor: float = 2.0, angle: float = 0.0, height: float = 0.0, roof: bool = false) -> Node3D:
	if not templates.has(key):
		templates[key] = load(FOUNTAIN if key == "fountain" else ROOT + key + ".glb")
	var node: Node3D = templates[key].instantiate()
	for mesh in site.assets.meshes(node):
		for surface in mesh.mesh.get_surface_count():
			var original: StandardMaterial3D = mesh.get_active_material(surface)
			var material_key := original.get_instance_id()
			if not materials.has(material_key):
				var styled: StandardMaterial3D = original.duplicate()
				styled.albedo_color = Color("bbb5c9")
				styled.emission_energy_multiplier = 0.28 if styled.emission_enabled else 1.0
				styled.emission = Color("9ca8e0")
				styled.roughness = 0.95
				materials[material_key] = styled
			mesh.set_surface_override_material(surface,materials[material_key])
	if not bounds.has(key): bounds[key] = site.assets.local_bounds(node)
	var box: AABB = bounds[key]
	var holder := Node3D.new()
	holder.name = "Town_" + key
	holder.set_meta("source_model", ("kenney/" if key == "fountain" else "sigils/") + key)
	holder.set_meta("fitted_size", box.size * scale_factor)
	site.scenery.add_child(holder)
	holder.add_child(node)
	node.scale = Vector3.ONE * scale_factor
	node.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale_factor
	holder.position = site.point(at, height)
	holder.rotation.y = angle
	if not roof and not key.begins_with("floor_"): site.register_occluder(holder)
	return holder

func wall(key: String, at: Vector2, angle: float, doorway: bool = false) -> void:
	model(key, at, 0.25, angle, 8)
	# The front module has a real central opening; collide only with its jambs.
	if doorway:
		for side in [-1, 1]:
			site.obstacles.append({"at": at + Vector2(side * 84, 0), "half": Vector2(16, 10), "angle": 0.0})
	else:
		site.obstacles.append({"at": at, "half": Vector2(100, 14), "angle": -angle})

func house(id: String, at: Vector2, columns: int = 3, rows: int = 2) -> void:
	var half := Vector2(columns * 100, rows * 100)
	var floor_rect := Rect2(at - half, half * 2)
	var floor_mesh: MeshInstance3D = site.home_box(at, Vector3(half.x * 2, 8, half.y * 2), Color("353746"))
	floor_mesh.name = "Floor_" + id
	site.plates.append({"polygon": PackedVector2Array([floor_rect.position, Vector2(floor_rect.end.x, floor_rect.position.y), floor_rect.end, Vector2(floor_rect.position.x, floor_rect.end.y)]), "top": 8.0})
	var roofs: Array = []
	for col in columns:
		var x: float = at.x - half.x + 100 + col * 200
		wall("wall_window_01", Vector2(x, at.y - half.y), PI)
		wall("doorway_inner_01" if col == int(columns / 2) else "wall_window_01", Vector2(x, at.y + half.y), 0, col == int(columns / 2))
	# Vaulted stone rooms use the kit's complete pitched roof bays.
	for row in rows:
		roofs.append(model("rooftop_01", Vector2(at.x, at.y - half.y + 100 + row * 200), 0.25, 0, 408, true))
	# The authored roof bay is open at its ends; close both visible gables.
	for side in [-1,1]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vertices := [site.point(at+Vector2(-half.x,side*half.y),408),site.point(at+Vector2(half.x,side*half.y),408),site.point(at+Vector2(0,side*half.y),700)]
		for index in ([0,1,2] if side == 1 else [0,2,1]):
			surface.set_uv(Vector2(vertices[index].x,vertices[index].y)*0.5)
			surface.add_vertex(vertices[index])
		surface.generate_normals()
		var gable: MeshInstance3D = site.mesh_node(surface.commit(),Vector3.ZERO,site.material(Color("646271"),load("res://assets/courtyard.png"),0.95,0.5))
		roofs.append(gable)
	for row in rows:
		var y: float = at.y - half.y + 100 + row * 200
		wall("wall_01", Vector2(at.x - half.x, y), -PI/2)
		wall("wall_01", Vector2(at.x + half.x, y), PI/2)
	# Floors and thresholds are traversable, roofs cut away on entering.
	buildings.append({"id": id, "rect": floor_rect, "door": Vector2(at.x, at.y + half.y), "roofs": roofs})
	site.home_box(Vector2(at.x, at.y + half.y + 40), Vector3(130, 4, 90), Color("5c5860"))

func update() -> void:
	for building in buildings:
		var inside: bool = building.rect.grow(-12).has_point(site.hero_at)
		for roof in building.roofs: roof.visible = not inside

func open_station(id: String, at: Vector2, canopy: bool = false) -> void:
	var rect := Rect2(at-Vector2(270,180),Vector2(540,360))
	open_stations.append({"id":id,"rect":rect,"canopy":canopy})
	var floor_node: MeshInstance3D = site.home_box(at,Vector3(540,8,360),Color("44404e"))
	floor_node.name = "Open_" + id
	floor_node.material_override = site.material(Color("9b909e"),load("res://assets/courtyard.png"),0.95,0.45)
	site.plates.append({"polygon": PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),"top":8.0})
	for side in [-1,1]:
		var column_at := at+Vector2(side*235,-120)
		model("column_small_01",column_at,0.30,0,8)
		site.obstacles.append({"at":column_at,"half":Vector2(27,27),"angle":0.0})
	if canopy:
		# A gently sagging cloth canopy and scalloped trim, open on every side.
		var cloth := SurfaceTool.new()
		cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 8:
			var x1: float = -235+i*58.75
			var x2: float = x1+58.75
			var h1: float = 280-20*sin(float(i)*PI/8)
			var h2: float = 280-20*sin(float(i+1)*PI/8)
			var corners := [site.point(at+Vector2(x1,-175),h1),site.point(at+Vector2(x2,-175),h2),site.point(at+Vector2(x2,55),h2-14),site.point(at+Vector2(x1,55),h1-14)]
			for index in [0,2,1,0,3,2]: cloth.add_vertex(corners[index])
			for vertex in [corners[3],corners[2],site.point(at+Vector2((x1+x2)*0.5,55),minf(h1,h2)-28)]: cloth.add_vertex(vertex)
		cloth.generate_normals()
		var awning: MeshInstance3D = site.mesh_node(cloth.commit(),Vector3.ZERO,site.material(Color("653044")))
		awning.name = "Awning_"+id

func workbench(at: Vector2, width: float = 180.0) -> Node3D:
	var factor := width/300.0
	var node := model("altar_01",at,factor,0,site.ground_height(at))
	site.obstacles.append({"at":at,"half":Vector2(width*0.5,width*0.25),"angle":0.0})
	return node

func castle_boundary() -> void:
	for x in range(1200,4801,100):
		for y in [1300,4770]:
			if y == 4770 and abs(x-2800) < 250: continue
			model("wall_01",Vector2(x,y),0.125,0)
			site.obstacles.append({"at":Vector2(x,y),"half":Vector2(50,8),"angle":0.0})
	for y in range(1400,4701,100):
		for x in [1150,4850]:
			model("wall_01",Vector2(x,y),0.125,PI/2)
			site.obstacles.append({"at":Vector2(x,y),"half":Vector2(8,50),"angle":0.0})
	for at in [Vector2(1200,1350),Vector2(4770,1350),Vector2(1200,4700),Vector2(4770,4700)]:
		model("column_small_01",at,0.5)
		model("tower_cap_01",at,0.18,0,450)
		site.obstacles.append({"at":at,"half":Vector2(50,50),"angle":0.0})
