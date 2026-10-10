extends SceneTree
## Only adjusts unbaked geological materials after actual screenshot review.
func _initialize() -> void:
	for stem in ["opening-7","act3-3"]:
		var path: String="res://scenes/story/"+stem
		var node: Node3D=load(path+".tscn").instantiate()
		var gi: LightmapGI=node.get_node("BakedIndirectLight")
		var changed := 0
		var meshes: Array=[node.get_node("SurroundingBedrock")]; meshes.append_array(node.get_node("CentralStructures").get_children())
		for mesh in meshes:
			if not mesh is MeshInstance3D: continue
			assert(mesh.gi_mode==GeometryInstance3D.GI_MODE_DISABLED)
			for i in gi.light_data.get_user_count(): assert(gi.light_data.get_user_path(i)!=gi.get_path_to(mesh))
			var mat: StandardMaterial3D=mesh.material_override.duplicate()
			if mesh.name=="SurroundingBedrock": mat.albedo_color=Color("b5bdc4")
			mat.emission_enabled=true; mat.emission_texture=mat.albedo_texture; mat.emission=Color("758da3"); mat.emission_energy_multiplier=.11
			mesh.material_override=mat; changed+=1
		var packed := PackedScene.new(); assert(packed.pack(node)==OK)
		assert(ResourceSaver.save(packed,path+".tscn")==OK); assert(ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
		print("BEDROCK_MATERIAL_PATCH ",stem," count=",changed," GI_preserved=true"); node.free()
	quit()
