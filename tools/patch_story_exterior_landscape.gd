extends SceneTree
## Append dressed background scenery, preserving all static floors and GI.
const Exterior=preload("res://scripts/story_exterior_composition.gd")
func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		# Exported GLB instances are flattened before assigning editable owners.
		# Keeping their scene path alongside owned children duplicates subnodes.
		child.scene_file_path=""; child.owner=scene; own(child,scene)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=preload("res://scripts/story_campaign.gd").new(); c.state=c.new_state(); c.save_enabled=false
	var w=preload("res://scripts/story_world.gd").new(); w.campaign=c; w.environment_builder.world=w
	for act in range(1,7):
		c.enter(act,0)
		for stage in c.map.outdoor:
			var r=c.map.regions[stage]
			var stem: String="opening-%d" % stage if act==1 else "act%d-%d" % [act,stage]
			var path := "res://scenes/story/"+stem
			# Strip our generated group before instantiation. An earlier imported
			# GLB scene path plus owned subnodes can otherwise create orphan meshes.
			var sections := FileAccess.get_file_as_string(path+".tscn").split("\n[node ")
			var kept := PackedStringArray([sections[0]])
			for i in range(1,sections.size()):
				var header: String=sections[i].get_slice("\n",0)
				var generated := false
				for group_name in ["DressedExteriorLandscape","BoundaryCliffShell","BoundaryApron"]:
					if header.begins_with("name=\""+group_name+"\"") or header.contains("parent=\""+group_name+"\"") or header.contains("parent=\""+group_name+"/"): generated=true
				if not generated: kept.append("\n[node "+sections[i])
			DirAccess.make_dir_recursive_absolute("res://build/landscape-input")
			var temporary := "res://build/landscape-input/"+stem+".tscn"
			var file := FileAccess.open(temporary,FileAccess.WRITE); file.store_string("".join(kept)); file.close()
			var scene: Node3D=load(temporary).instantiate(); var gi: LightmapGI=scene.get_node("BakedIndirectLight")
			assert(gi.light_data!=null)
			for i in gi.light_data.get_user_count():
				assert(not str(gi.light_data.get_user_path(i)).contains("DressedExteriorLandscape"))
			for group_name in ["BoundaryCliffShell","BoundaryApron","DressedExteriorLandscape"]:
				var previous: Node=scene.get_node_or_null(group_name)
				if previous:
					for mesh in previous.find_children("*","MeshInstance3D",true,false):
						assert(mesh.gi_mode==GeometryInstance3D.GI_MODE_DISABLED)
						for i in gi.light_data.get_user_count(): assert(gi.light_data.get_user_path(i)!=gi.get_path_to(mesh))
					previous.free()
			w.scenery=scene; Exterior.build(w.environment_builder,r); own(scene,scene)
			for cover in scene.find_children("*","MultiMeshInstance3D",true,false):
				if cover.has_method("prepare_capture"): cover.prepare_capture()
			var packed := PackedScene.new(); assert(packed.pack(scene)==OK)
			assert(ResourceSaver.save(packed,path+".tscn")==OK); assert(ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
			print("DRESSED_LANDSCAPE ",stem," decoration_count=",scene.get_node("DressedExteriorLandscape").get_meta("decoration_count")," GI_preserved=true"); scene.free(); w.scenery=null
	w.free(); quit()
