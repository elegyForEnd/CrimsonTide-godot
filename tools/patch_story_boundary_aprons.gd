extends SceneTree
## Rebuild only unbaked scenery aprons; all manually placed props and GI survive.
const Surfaces=preload("res://scripts/story_surface_geometry.gd")
func own(node: Node, scene: Node) -> void:
	for child in node.get_children(): child.owner=scene; own(child,scene)
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
			var scene: Node3D=load(path+".tscn").instantiate()
			var previous: Node3D=scene.get_node_or_null("BoundaryApron")
			var gi: LightmapGI=scene.get_node("BakedIndirectLight")
			assert(gi.light_data!=null,"Bake the new land before patching aprons")
			if previous:
				for mesh in previous.find_children("*","MeshInstance3D",true,false):
					assert(mesh.gi_mode==GeometryInstance3D.GI_MODE_DISABLED)
					for i in gi.light_data.get_user_count(): assert(gi.light_data.get_user_path(i)!=gi.get_path_to(mesh))
				previous.free()
			w.scenery=scene
			var ground: Material
			for mesh in scene.get_children():
				if mesh is MeshInstance3D and mesh.material_override is ShaderMaterial and mesh.material_override.shader==w.environment_builder.GROUND: ground=mesh.material_override; break
			assert(ground!=null,"Authored ground material must survive")
			Surfaces.apron(w.environment_builder,r,ground)
			for water in scene.get_children():
				if not water is MeshInstance3D or not str(water.name).begins_with("MatchedWaterSurface"): continue
				assert(water.gi_mode==GeometryInstance3D.GI_MODE_DISABLED)
				for i in gi.light_data.get_user_count(): assert(gi.light_data.get_user_path(i)!=gi.get_path_to(water))
				if not water.get_meta("water_world_space",false):
					water.position=w.point(r.origin); water.set_meta("water_world_space",true)
			own(scene,scene)
			for cover in scene.find_children("*","MultiMeshInstance3D",true,false):
				if cover.has_method("prepare_capture"): cover.prepare_capture()
			var packed := PackedScene.new(); assert(packed.pack(scene)==OK)
			assert(ResourceSaver.save(packed,path+".tscn")==OK)
			assert(ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
			print("BOUNDARY_APRON_PATCH ",stem," GI_preserved=true"); scene.free(); w.scenery=null
	w.free(); quit()
