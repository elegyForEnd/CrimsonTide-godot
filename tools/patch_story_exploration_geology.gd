extends SceneTree
const Campaign=preload("res://scripts/story_campaign.gd")
const EnvironmentBuilder=preload("res://scripts/story_environment.gd")
const Geometry=preload("res://scripts/story_exploration_environment.gd")
var kit=preload("res://scripts/story_asset_kit.gd").new()
func _initialize() -> void: call_deferred("run")
func own(node: Node, scene: Node) -> void:
	for child in node.get_children(): child.scene_file_path=""; child.owner=scene; own(child,scene)
func run() -> void:
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	var world=preload("res://scripts/story_world.gd").new(); root.add_child(world)
	var builder=EnvironmentBuilder.new(); builder.world=world; builder.kit=kit
	for a in range(1,7):
		c.enter(a,0)
		for r in c.map.regions.values():
			if r.exploration_plan.is_empty(): continue
			var stem := "opening-%d" % r.stage if a==1 else "act%d-%d" % [a,r.stage]
			var path := "res://scenes/story/"+stem
			var scene: Node3D=load(path+".tscn").instantiate(); world.scenery=scene
			if r.exploration_plan.natural:
				for name in ["CaveRockShell","CentralStructures"]:
					if scene.has_node(name): scene.get_node(name).free()
				Geometry.walls(builder,r)
			else:
				var group: Node3D=scene.get_node("CastleArchitecture" if r.layout=="castle" else "RegionalArchitecture")
				if not group.has_node("FacilityWorkLight"):
					var item: Dictionary=r.dressing[-1]; var light := OmniLight3D.new(); group.add_child(light); light.name="FacilityWorkLight"
					light.position=Vector3(item.position.x,r.height_at(item.position)+145,item.position.y-180)*.01
					light.light_color=Color("ff9551") if a==2 else Color("94cdd7") if a in [3,5] else Color("e1b5ca")
					light.light_energy=1.9 if a==2 else 1.1; light.omni_range=4.8; light.light_bake_mode=Light3D.BAKE_DISABLED
			own(scene,scene)
			var packed := PackedScene.new(); packed.pack(scene); ResourceSaver.save(packed,path+".tscn"); ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)
			print("PATCHED_GEOLOGY_LIGHT ",stem); scene.free()
	world.scenery=null; world.queue_free(); kit.scenes.clear(); kit.materials.clear(); await process_frame; quit()
