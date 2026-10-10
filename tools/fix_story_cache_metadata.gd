extends SceneTree
func _initialize() -> void:
	for stage in [2,3,4]:
		var path := "res://scenes/story/opening-%d" % stage
		var scene: Node3D=load(path+".tscn").instantiate()
		scene.remove_meta("building_rect")
		var packed := PackedScene.new(); packed.pack(scene)
		ResourceSaver.save(packed,path+".tscn")
		ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)
		scene.free()
	quit()
