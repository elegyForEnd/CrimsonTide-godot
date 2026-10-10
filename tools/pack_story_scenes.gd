extends SceneTree
func _initialize() -> void:
	for stage in [0,1,2,3,4,7,9]:
		var path := "res://scenes/story/opening-%d" % stage
		var packed: PackedScene=load(path+".tscn")
		var error := ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)
		print("PACKED ",stage," error=",error)
	quit()
