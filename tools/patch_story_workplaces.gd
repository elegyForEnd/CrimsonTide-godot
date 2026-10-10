@tool
extends SceneTree
## Incremental authoring: keep terrain/layout edits, replace only tagged assets.
const Campaign=preload("res://scripts/story_campaign.gd")
const World=preload("res://scripts/story_world.gd")
var uv_cache: Dictionary={}
func own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.scene_file_path=""; child.owner=owner_node; own(child,owner_node)
func unwrap(mesh: MeshInstance3D) -> void:
	var key := str(mesh.mesh.get_instance_id())
	if not uv_cache.has(key):
		var converted := ArrayMesh.new()
		for i in mesh.mesh.get_surface_count():
			converted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.mesh.surface_get_arrays(i))
			converted.surface_set_material(i,mesh.get_active_material(i))
		var error := converted.lightmap_unwrap(Transform3D.IDENTITY,.12)
		assert(error==OK,"Furniture UV2 generation failed")
		uv_cache[key]=converted
	mesh.mesh=uv_cache[key]; mesh.gi_mode=GeometryInstance3D.GI_MODE_STATIC
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state(); c.enter(1,0)
	var w=World.new(); w.campaign=c
	var env=w.environment_builder; env.world=w
	for stage in [0,1,7]:
		var refresh: bool="--refresh-buildings" in OS.get_cmdline_user_args()
		if refresh and stage!=0: continue
		var path := "res://scenes/story/opening-%d.tscn" % stage
		var scene: Node3D=load(path).instantiate()
		if scene.has_node("CraftedSetDressing") and not refresh:
			print("PRESERVED artist workplace scene ",stage); scene.free(); continue
		var region=c.map.regions[stage]; w.scenery=scene
		if stage==0:
			for old in scene.get_children():
				if old.has_meta("building_rect"):
					var role: int=int(str(old.name).trim_prefix("service_"))
					var fresh: Node3D=env.kit.instance("service_%d" % role,scene,old.position)
					fresh.transform=old.transform
					var rect: Rect2=old.get_meta("building_rect")
					fresh.set_meta("building_rect",rect)
					fresh.find_child("Roof*",true,false).set_meta("reveal_roof_rect",rect)
					fresh.find_child("Front*",true,false).set_meta("reveal_front_rect",rect)
					for mesh in fresh.find_children("*","MeshInstance3D",true,false):
						if mesh.name.begins_with("Body"): unwrap(mesh)
					env.kit.prepare_reveal(fresh.find_child("Roof*",true,false))
					env.kit.prepare_reveal(fresh.find_child("Front*",true,false))
					env.kit.prepare_reveal(fresh.find_child("Side*",true,false))
					scene.remove_child(old); old.free(); fresh.name="service_%d" % role
				elif old is Node3D:
					for building in region.buildings:
						var at := World.point(building.rect.get_center()+Vector2(-25,-35))
						if old.position.distance_to(at)<.01:
							scene.remove_child(old); old.free(); break
		if not scene.has_node("CraftedSetDressing"):
			env.crafted_details(region,scene)
			for mesh in scene.get_node("CraftedSetDressing").find_children("*","MeshInstance3D",true,false): unwrap(mesh)
		# Keep the existing bake destination until the mandatory rebake. Clearing it
		# sends the editor through a save dialog while restoring scene tabs.
		own(scene,scene)
		var packed := PackedScene.new(); var error := packed.pack(scene)
		if error==OK: error=ResourceSaver.save(packed,path)
		if error!=OK:
			push_error("Workplace authoring could not save "+path+" error="+str(error))
			scene.free(); w.free(); quit(1); return
		print("PATCHED_WORKPLACES ",stage," count=",region.dressing.size())
		scene.free()
	w.free(); quit()
