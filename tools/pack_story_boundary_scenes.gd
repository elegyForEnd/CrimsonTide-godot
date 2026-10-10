extends SceneTree
## Normalize only the six camps and nineteen fields after editor baking.
## Mesh geometry and GI remain intact; no native vegetation RIDs are saved.
func _initialize() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/story-exploration.json"))
	var keys: Array=data.outdoor.keys()
	for act in range(1,7): keys.append("%d:0" % act)
	for key in keys:
		var parts: PackedStringArray=str(key).split(":")
		var stem := "opening-"+parts[1] if parts[0]=="1" else "act"+parts[0]+"-"+parts[1]
		var path := "res://scenes/story/"+stem
		var scene: Node3D=load(path+".tscn").instantiate()
		var count := 0
		for cover in scene.find_children("*","MultiMeshInstance3D",true,false):
			assert(cover.has_method("prepare_capture"),"Unknown vegetation capture contract")
			cover.prepare_capture(); assert(cover.multimesh.instance_count==0); count+=1
		var packed := PackedScene.new(); assert(packed.pack(scene)==OK)
		assert(ResourceSaver.save(packed,path+".tscn")==OK)
		assert(ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
		print("BOUNDARY_CAPTURE ",stem," foliage=",count," GI_preserved=true"); scene.free()
	quit()
