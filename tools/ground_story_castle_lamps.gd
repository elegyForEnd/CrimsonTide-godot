extends SceneTree
## Correct only the two generated lamps on the raised lord's floor.
func _initialize() -> void:
	var path := "res://scenes/story/opening-9.tscn"
	var scene: Node3D=load(path).instantiate(); var changed := 0
	for node in scene.get_node("CastleArchitecture").get_children():
		if not node is Node3D: continue
		for at in [Vector2(28,61),Vector2(36,61)]:
			if Vector2(node.position.x,node.position.z).distance_to(at)>.01: continue
			var target := 2.7 if node is OmniLight3D else 1.2
			if node.position.y<target-.01: node.position.y=target; changed+=1
	var packed := PackedScene.new(); packed.pack(scene)
	var error := ResourceSaver.save(packed,path)
	print("GROUNDED_CASTLE_LAMPS ",changed," error=",error)
	scene.free(); quit(1 if error!=OK else 0)
