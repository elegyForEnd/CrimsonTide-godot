extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=preload("res://scripts/story_campaign.gd").new(); c.save_enabled=false; c.state=c.new_state()
	var checks := 0; var failures := 0
	for act in range(2,7):
		c.enter(act,0)
		for stage in range(9):
			for suffix in ["","-compat"]:
				var scene: Node3D=load("res://scenes/story/act%d-%d%s.scn" % [act,stage,suffix]).instantiate()
				for gi in scene.find_children("*","LightmapGI",true,false): gi.light_data=null; gi.free()
				for item in c.map.regions[stage].dressing:
					checks+=1
					var node: Node3D=scene.get_node("CraftedSetDressing/"+item.id)
					if node.get_meta("story_model","")!=item.model:
						failures+=1; push_error("Cached model differs from layout: "+item.id)
				scene.free()
	print("regional scene models: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
