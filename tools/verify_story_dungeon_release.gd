extends SceneTree
## Run against source or an exported embedded PCK; detect stale scene/data mixes.
func _initialize() -> void: call_deferred("run")
func fail(message: String) -> void:
	push_error(message); quit(1)
func run() -> void:
	var c=preload("res://scripts/story_campaign.gd").new(); c.state=c.new_state(); c.save_enabled=false
	var checked := 0; var placements := 0
	for act in range(1,7):
		c.enter(act,0)
		for r in c.map.regions.values():
			if not r.indoor: continue
			if r.exploration_plan.get("layout_revision",0)!=2: fail("Stale layout data"); return
			var stem := "res://scenes/story/"+("opening-%d" % r.stage if act==1 else "act%d-%d" % [act,r.stage])
			for suffix in ["","-compat"]:
				var scene: Node3D=load(stem+suffix+".scn").instantiate()
				var gi: LightmapGI=scene.get_node("BakedIndirectLight")
				if gi.light_data==null: fail("Missing bake "+stem); return
				gi.light_data=null; gi.free()
				var floor_node: Node=scene.get_node("AuthoredDungeonFloor")
				if floor_node.get_meta("layout_family","")!=r.exploration_plan.layout_family or floor_node.get_meta("exploration_revision",0)!=2: fail("Stale floor cache "+stem); return
				for item in r.dressing:
					var node: Node=scene.get_node_or_null("CraftedSetDressing/"+item.id)
					if node==null or node.get_meta("story_model","")!=item.model: fail("Stale dressing "+stem+" "+item.id); return
					placements+=1
				scene.free()
			checked+=1
	if checked!=30 or c.content.quests.size()!=73 or not FileAccess.file_exists("res://resources/story-exploration.json"): fail("Incomplete release content"); return
	print("PACKED_IDENTITIES_READY dungeons=",checked," quests=",c.content.quests.size()," model_identities=",placements," forward_and_compat=true"); quit()
