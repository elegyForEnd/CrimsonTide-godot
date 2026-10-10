extends SceneTree
const Kit=preload("res://scripts/story_asset_kit.gd")
const Campaign=preload("res://scripts/story_campaign.gd")
func _initialize() -> void: call_deferred("run")
func own(node: Node, owner_root: Node) -> void:
	for child in node.get_children(): child.owner=owner_root; child.scene_file_path=""; own(child,owner_root)
func run() -> void:
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false; var kit=Kit.new()
	for model in ["a2_archive","a4_doll_station","a5_beacon","a6_scriptorium"]:
		if not ResourceLoader.exists(Kit.BASE+"models/"+model+".glb"):
			push_error("Import the new model before patching: "+model); quit(1); return
	for entry in [[2,3],[2,4],[3,3],[4,2],[4,3],[4,5],[4,6],[5,4],[5,6],[6,4],[6,5]]:
		var path := "res://scenes/story/act%d-%d" % entry
		var node: Node3D=load(path+".tscn").instantiate()
		c.enter(entry[0],entry[1]); var r=c.map.regions[entry[1]]
		var group: Node3D=node.get_node("CraftedSetDressing")
		var item: Dictionary=r.dressing.filter(func(raw): return raw.id.ends_with("_inside_0"))[0]
		var old: Node3D=group.get_node(item.id)
		# These facilities never contributed to the fixed GI bake. Preserve bake
		# users/UV2 and change only this explicitly dynamic occludable asset.
		var bake: LightmapGIData=node.get_node("BakedIndirectLight").light_data
		for user in bake.get_user_count():
			if item.id in str(bake.get_user_path(user)):
				push_error("Facility was baked; rebake instead of incremental replacement: "+item.id); node.free(); quit(1); return
		var transform: Transform3D=old.transform; group.remove_child(old); old.free()
		var fresh: Node3D=kit.instance(item.model,group,Vector3.ZERO); fresh.name=item.id; fresh.transform=transform
		fresh.scene_file_path=""
		fresh.set_meta("dressing_id",item.id); fresh.set_meta("movement_footprint",item.rect)
		fresh.set_meta("occluder",{"p":r.origin+item.position,"height":item.occlusion_height}); kit.prepare_reveal(fresh)
		fresh.owner=node; own(fresh,node)
		var packed := PackedScene.new(); assert(packed.pack(node)==OK)
		assert(ResourceSaver.save(packed,path+".tscn")==OK)
		assert(ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
		print("PATCHED_ROOM_FACILITY ",path," model=",item.model); node.free()
	kit.scenes.clear(); kit.materials.clear()
	await process_frame
	quit()
