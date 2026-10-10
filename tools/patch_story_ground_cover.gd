extends SceneTree
func _initialize() -> void: call_deferred("run")
func own(node: Node, scene: Node) -> void:
	for child in node.get_children(): child.scene_file_path=""; child.owner=scene; own(child,scene)
func run() -> void:
	var c=preload("res://scripts/story_campaign.gd").new(); c.state=c.new_state(); c.save_enabled=false; c.enter(1,0)
	var world=preload("res://scripts/story_world.gd").new(); root.add_child(world)
	var builder=preload("res://scripts/story_environment.gd").new(); builder.world=world
	for stage in c.map.outdoor:
		var path := "res://scenes/story/opening-%d" % stage
		var scene: Node3D=load(path+".tscn").instantiate(); world.scenery=scene
		var gi: LightmapGI=scene.get_node("BakedIndirectLight")
		for multi in scene.find_children("*","MultiMeshInstance3D",true,false):
			if gi.light_data!=null:
				for i in gi.light_data.get_user_count():
					if str(gi.light_data.get_user_path(i))=="../"+str(scene.get_path_to(multi)): push_error("Vegetation is baked; rebake instead"); quit(1); return
			multi.free()
		builder.ground_cover(c.map.regions[stage])
		for multi in scene.find_children("*","MultiMeshInstance3D",true,false): multi.prepare_capture()
		own(scene,scene)
		var packed := PackedScene.new(); packed.pack(scene)
		var error := ResourceSaver.save(packed,path+".tscn")
		if error!=OK: push_error("Ground cover scene save failed "+path); quit(1); return
		error=ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)
		if error!=OK: push_error("Ground cover packed save failed "+path); quit(1); return
		print("SAFE_GROUND_COVER ",stage); scene.free()
	world.scenery=null; world.queue_free(); builder.release_resources(); await process_frame; quit()
