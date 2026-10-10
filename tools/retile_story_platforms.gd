extends SceneTree
## Correct generated platform UV density without changing geometry or placements.
func _initialize() -> void:
	for stage in [1,7,9]:
		var path := "res://scenes/story/opening-%d.tscn" % stage
		var scene: Node3D=load(path).instantiate(); var changed := 0
		for mesh in scene.find_children("*","MeshInstance3D",true,false):
			var mat: Material=mesh.material_override
			if not mat is StandardMaterial3D or mat.albedo_texture==null or not "masonry_albedo" in mat.albedo_texture.resource_path: continue
			var size: Vector3=mesh.mesh.get_aabb().size
			if size.x<3 or size.z<3 or mat.uv1_world_triplanar: continue
			var tiled: StandardMaterial3D=mat.duplicate()
			tiled.uv1_triplanar=true; tiled.uv1_world_triplanar=true; tiled.uv1_scale=Vector3.ONE*.55
			mesh.material_override=tiled; mesh.set_meta("world_tiled_platform",true); changed+=1
		if changed>0:
			var packed := PackedScene.new(); packed.pack(scene)
			var error := ResourceSaver.save(packed,path)
			if error!=OK: push_error("Platform material save failed"); quit(1); return
		print("RETILED_PLATFORM ",stage," count=",changed); scene.free()
	quit()
