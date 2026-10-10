@tool
extends SceneTree
## Materialize the deterministic baseline ONCE into editable scene files.
## Existing files are deliberately protected. Afterwards edit/bake in Godot.
const Campaign=preload("res://scripts/story_campaign.gd")
const World=preload("res://scripts/story_world.gd")
var campaign
var world
var uv_cache: Dictionary={}
func _initialize() -> void: call_deferred("run")
func own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.scene_file_path=""
		child.owner=owner_node
		own(child,owner_node)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/story")
	campaign=Campaign.new(); campaign.save_enabled=false; campaign.state=campaign.new_state()
	world=World.new(); root.add_child(world)
	world.environment_builder.authoring=true
	var stages: Array=[0,1,7]
	var act := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--act="): act=int(arg.trim_prefix("--act="))
		if arg.begins_with("--stages="):
			stages=[]
			for value in arg.trim_prefix("--stages=").split(","): stages.append(int(value))
	if "--cache-outdoors" in OS.get_cmdline_user_args(): stages=range(1,9)
	for stage in stages:
		if "--camp-only" in OS.get_cmdline_user_args() and stage!=0: continue
		var path := "res://scenes/story/"+("opening-%d" % stage if act==1 else "act%d-%d" % [act,stage])+".tscn"
		if FileAccess.file_exists(path) and not "--replace-generated" in OS.get_cmdline_user_args(): print("PRESERVED ",path); continue
		campaign.enter(act,stage); world.geometry_key=""; world.build_story(campaign)
		if "--cache-outdoors" in OS.get_cmdline_user_args() and campaign.map.regions[stage].indoor: continue
		await process_frame
		var source: Node3D=world.environment_builder.chunks[0].node
		if not campaign.map.regions[stage].indoor:
			for chunk in world.environment_builder.chunks:
				if chunk.rect.position==campaign.map.regions[stage].origin: source=chunk.node; break
		var authored := Node3D.new(); authored.name="Opening%d" % stage if act==1 else "Act%dRegion%d" % [act,stage]; root.add_child(authored)
		for child in source.get_children(): source.remove_child(child); authored.add_child(child)
		# Register authoritative hide groups before baking: no roof/front baked ghosts.
		for item in world.environment_builder.roofs:
			if authored.is_ancestor_of(item.roof):
				item.roof.set_meta("reveal_roof_rect",item.rect)
				item.front.set_meta("reveal_front_rect",item.rect)
				if item.roof.get_parent()!=authored: item.roof.get_parent().set_meta("building_rect",item.rect)
		for item in world.environment_builder.occluders:
			if authored.is_ancestor_of(item.node): item.node.set_meta("occluder",{"p":item.p,"height":item.height})
		for item in world.environment_builder.cache_models:
			if authored.is_ancestor_of(item.node): item.node.set_meta("story_cache",item.id)
		for mesh in authored.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override is ShaderMaterial and mesh.material_override.shader==world.environment_builder.WATER:
				mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED; continue
			if mesh.material_override==null and mesh.mesh==null: continue
			var hide_group: bool=mesh.gi_mode==GeometryInstance3D.GI_MODE_DISABLED or mesh.name.begins_with("Roof") or mesh.name.begins_with("Front") or mesh.name.begins_with("Side") or mesh.get_parent().name.begins_with("Roof") or mesh.get_parent().name.begins_with("Front")
			if hide_group or mesh.get_parent().has_meta("licensed_tree") or mesh.get_parent().name.begins_with("woodland_tree"):
				mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED; continue
			var key := str(mesh.mesh.get_instance_id())
			if not uv_cache.has(key):
				var converted := ArrayMesh.new()
				for i in mesh.mesh.get_surface_count():
					converted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.mesh.surface_get_arrays(i))
					converted.surface_set_material(i,mesh.get_active_material(i))
				var unwrap_error := converted.lightmap_unwrap(Transform3D.IDENTITY,.24)
				if unwrap_error!=OK: push_error("UV2 unwrap failed "+str(unwrap_error)); quit(1); return
				uv_cache[key]=converted
			mesh.mesh=uv_cache[key]; mesh.gi_mode=GeometryInstance3D.GI_MODE_STATIC
		for light in authored.find_children("*","OmniLight3D",true,false):
			light.light_bake_mode=Light3D.BAKE_DYNAMIC
			light.shadow_enabled=false
		var moon := DirectionalLight3D.new(); moon.name="BakeMoon"; moon.rotation_degrees=Vector3(-52,-35,0)
		var open_sky: bool=campaign.map.regions[stage].exploration_plan.get("sky_open",false)
		moon.light_color=Color("b7c8e4"); moon.light_energy=.56 if open_sky else .24 if campaign.map.regions[stage].indoor else .63
		moon.light_bake_mode=Light3D.BAKE_DYNAMIC; moon.add_to_group("editor_only",true); authored.add_child(moon)
		if act>=2: moon.light_color=Color(preload("res://scripts/story_act_art.gd").palette(act).sun)
		var gi := LightmapGI.new(); gi.name="BakedIndirectLight"
		var previous_bake := path.get_basename()+".lmbake"
		if ResourceLoader.exists(previous_bake) and not "--replace-generated" in OS.get_cmdline_user_args(): gi.light_data=load(previous_bake)
		gi.quality=LightmapGI.BAKE_QUALITY_MEDIUM
		gi.environment_mode=LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
		gi.environment_custom_color=Color("829ab7"); gi.environment_custom_energy=.20 if stage!=7 else .12
		if act>=2:
			gi.environment_custom_color=Color(preload("res://scripts/story_act_art.gd").palette(act).ambient); gi.environment_custom_energy=.24
		gi.generate_probes_subdiv=LightmapGI.GENERATE_PROBES_SUBDIV_8
		authored.add_child(gi)
		var camera := Camera3D.new(); camera.name="EditorCamera"; camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=25; var r=campaign.map.regions[stage]
		var target := World.point(r.origin+r.extent*.5)
		camera.position=target+Vector3(12,24,19); camera.add_to_group("editor_only",true); authored.add_child(camera); camera.look_at(target)
		own(authored,authored)
		for cover in authored.find_children("*","MultiMeshInstance3D",true,false):
			if cover.has_method("prepare_capture"): cover.prepare_capture()
		var packed := PackedScene.new(); var error := packed.pack(authored)
		if error==OK: error=ResourceSaver.save(packed,path)
		if error==OK: error=ResourceSaver.save(packed,path.get_basename()+".scn",ResourceSaver.FLAG_COMPRESS)
		print("AUTHORED_SCENE ",path," error=",error)
		authored.queue_free(); await process_frame
	world.queue_free(); await process_frame; quit()
