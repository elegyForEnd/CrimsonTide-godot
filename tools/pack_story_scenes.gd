extends SceneTree
func _initialize() -> void:
	for stage in range(10):
		var path := "res://scenes/story/opening-%d" % stage
		if not FileAccess.file_exists(path+".tscn"): continue
		var packed: PackedScene=load(path+".tscn")
		var error := ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)
		print("PACKED ",stage," error=",error)
	quit()
