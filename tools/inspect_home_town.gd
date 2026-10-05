extends SceneTree

func _initialize() -> void:
	var library = preload("res://scripts/scene_assets.gd").new()
	for key in ["wall_01", "wall_window_01", "wall_rose_window_01", "doorway_01", "doorway_inner_01", "facade_wall_01", "column_small_01", "floor_01", "rooftop_01", "rooftop_02", "sanctum_roof_01", "tower_small_01", "tower_cap_01", "spire_01", "altar_01", "chandelier_01", "vault_large_01", "sanctum_base_01"]:
		var model = load("res://assets/vendor/sigils-cathedral/models/" + key + ".glb").instantiate()
		print(key, " ", library.local_bounds(model))
		if key == "doorway_inner_01":
			for mesh in library.meshes(model):
				print("part ",mesh.name," ",mesh.get_aabb())
				var xs: Array = []
				for vertex in mesh.mesh.get_faces():
					if vertex.y > 0.2 and vertex.y < 3.0 and not xs.has(snappedf(vertex.x,0.01)): xs.append(snappedf(vertex.x,0.01))
				xs.sort()
				print("foot vertices x=",xs)
				for i in mesh.mesh.get_surface_count():
					var mat = mesh.get_active_material(i)
					print("material ",mat.resource_name," emit=",mat.emission," energy=",mat.emission_energy_multiplier," texture=",mat.albedo_texture)
		model.free()
	quit()
