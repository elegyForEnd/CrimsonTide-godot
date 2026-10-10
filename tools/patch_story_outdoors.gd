@tool
extends SceneTree
## Append only new tagged placements. Existing transforms/artists' edits survive.
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
		assert(error==OK,"Outdoor UV2 generation failed")
		uv_cache[key]=converted
	mesh.mesh=uv_cache[key]; mesh.gi_mode=GeometryInstance3D.GI_MODE_STATIC
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state(); c.enter(1,0)
	var w=World.new(); w.campaign=c; w.environment_builder.world=w
	for stage in [0,1,2]:
		var path := "res://scenes/story/opening-%d.tscn" % stage
		var scene: Node3D=load(path).instantiate(); var r=c.map.regions[stage]
		var group: Node3D=scene.get_node_or_null("CraftedSetDressing")
		if group==null: group=Node3D.new(); group.name="CraftedSetDressing"; scene.add_child(group)
		var existing: Dictionary={}
		for node in group.get_children(): existing[node.get_meta("dressing_id","")]=true
		var additions: Array=[]
		for entry in r.dressing:
			if not existing.has(entry.id): additions.append(entry)
		if additions.is_empty(): scene.free(); continue
		var old: Array=r.dressing; r.dressing=additions
		w.environment_builder.crafted_details(r,scene); r.dressing=old
		var new_group: Node3D=scene.get_children()[-1]
		for child in new_group.get_children(): new_group.remove_child(child); group.add_child(child)
		new_group.free()
		for mesh in group.find_children("*","MeshInstance3D",true,false):
			if mesh.gi_mode!=GeometryInstance3D.GI_MODE_DISABLED and not mesh.mesh.surface_get_format(0)&Mesh.ARRAY_FORMAT_TEX_UV2: unwrap(mesh)
		own(scene,scene)
		var packed := PackedScene.new(); var error := packed.pack(scene)
		if error==OK: error=ResourceSaver.save(packed,path)
		if error!=OK: push_error("Outdoor save failed"); quit(1); return
		print("OUTDOOR_APPEND ",stage," count=",additions.size()); scene.free()
	w.free(); quit()
