extends SceneTree
const Campaign=preload("res://scripts/story_campaign.gd")
var kit=preload("res://scripts/story_asset_kit.gd").new()
var world
func _initialize() -> void: call_deferred("run")
func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.scene_file_path=""; child.owner=scene; own(child,scene)
func run() -> void:
	world=preload("res://scripts/story_world.gd").new(); root.add_child(world)
	var builder=preload("res://scripts/story_environment.gd").new(); builder.world=world; builder.kit=kit
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	for a in range(1,7):
		c.enter(a,0)
		for r in c.map.regions.values():
			if not r.indoor: continue
			var stem := "opening-%d" % r.stage if a==1 else "act%d-%d" % [a,r.stage]
			var path := "res://scenes/story/"+stem
			var scene: Node3D=load(path+".tscn").instantiate()
			var group: Node3D=scene.get_node("CraftedSetDressing")
			var previous_core := scene.get_node_or_null("CentralStructures")
			if previous_core: previous_core.free()
			world.scenery=scene; preload("res://scripts/story_exploration_environment.gd").void_structures(builder,r)
			own(scene.get_node("CentralStructures"),scene); scene.get_node("CentralStructures").owner=scene
			if scene.has_node("BakeMoon"): scene.get_node("BakeMoon").light_energy=.24
			for id in r.exploration_plan.removed_dressing_ids:
				var obsolete := group.get_node_or_null(NodePath(id))
				if obsolete: obsolete.free()
			var item: Dictionary=r.dressing[-1]
			var old := group.get_node_or_null(NodePath(item.id))
			if old: old.free()
			var node: Node3D=kit.instance(item.model,group,Vector3(item.position.x,r.height_at(item.position),item.position.y)*.01,Vector3.ONE*1.15)
			node.name=item.id; node.scene_file_path=""; node.owner=scene; own(node,scene)
			node.set_meta("dressing_id",item.id); node.set_meta("movement_footprint",item.rect)
			node.set_meta("occluder",{"p":item.position,"height":float(item.occlusion_height)}); kit.prepare_reveal(node)
			for mesh in kit.mesh_nodes(node): mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
			var packed := PackedScene.new(); var error := packed.pack(scene)
			if error==OK: error=ResourceSaver.save(packed,path+".tscn")
			if error==OK: error=ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)
			print("PATCHED_DUNGEON_CENTRE ",stem," error=",error); scene.free()
	world.scenery=null; world.queue_free(); kit.scenes.clear(); kit.materials.clear(); await process_frame; quit()
