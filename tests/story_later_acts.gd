extends SceneTree
const Campaign=preload("res://scripts/story_campaign.gd")
const Screen=preload("res://scripts/story_screen.gd")
const Art=preload("res://scripts/story_act_art.gd")
const Floors=preload("res://scripts/story_floor_palette.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	var all_models: Dictionary={}; var outlines: Dictionary={}
	for act in range(2,7):
		c.enter(act,0)
		c.hero_at=c.map.waypoint; c.activate_waypoint()
		check(c.map.regions.size()==9,"preserve old campaign map identities")
		var p := Art.palette(act)
		for role in ["ground","wall","floor"]:
			for channel in ["albedo","normal","orm"]: check(ResourceLoader.exists("res://assets/story/environment/pbr/"+p[role]+"_"+channel+".png"),"new regional PBR "+role+channel)
		for r in c.map.regions.values():
			check(not r.art_theme.is_empty(),"named art identity %d:%d" % [act,r.stage])
			if r.indoor:
				check(r.floor_polygon.size()>12,"authored dungeon silhouette")
				outlines[str(r.floor_polygon)]=true
				check(Floors.architectural(r),"new buildings have indoor floor pipeline")
				check("a%d_" % act in Floors.material(r).get_shader_parameter("base_albedo").resource_path,"floor belongs to this act")
				c.map.activate(r.stage)
				for target in r.anchors+r.side_anchors+r.chests+[r.waypoint]:
					check(r.walkable(target),"targets remain walkable")
					var route: PackedVector2Array=c.map.route(c.map.spawn,target)
					check(not route.is_empty(),"actual branch route exists")
					var at: Vector2=c.map.spawn
					for point in route:
						for step_index in 90:
							if at.distance_to(point)<8: break
							at=c.map.move(at,(point-at).limit_length(9))
					check(at.distance_to(target)<100,"walk actual new route with height and footprints %d:%d target %s stopped %s height %s" % [act,r.stage,target,at,c.map.height_at(at)])
			for item in r.dressing:
				all_models[item.model]=true
				check(item.model.begins_with("a%d_" % act) or item.model.begins_with("d%d_" % act) or item.model.begins_with("dungeon_"),"regional or original dungeon kit visual")
				check(ResourceLoader.exists("res://assets/story/environment/models/"+item.model+".glb"),"real model exists")
				if item.model.ends_with("_tree"): check(not item.has("footprint"),"small trees stay nonblocking")
		c.map.activate(7); c.state.stage=7; c.hero_at=c.map.waypoint; c.activate_waypoint()
		check(c.travel(act,0) and c.travel(act,7),"new dungeon travel returns from camp")
		var door: Dictionary=c.map.return_door(7); c.hero_at=c.map.spawn; c.use_entrance(c.map.entrances()[0])
		check(c.state.stage==door.source,"new dungeon returns to original entrance")
	check(outlines.size()>=15,"regional/stage floor plans are visibly distinct")
	check(all_models.size()>=25,"five separate module families are in actual region data")
	if "--packed" in OS.get_cmdline_user_args():
		for act in range(2,7):
			c.enter(act,0)
			for stage in range(9):
				var region=c.map.regions[stage]
				var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
				var node: Node3D=load("res://scenes/story/act%d-%d%s.scn" % [act,stage,suffix]).instantiate()
				var gi: LightmapGI=node.get_node("BakedIndirectLight")
				check(gi.light_data!=null,"actual regional bake resource exists")
				gi.light_data=null; gi.free()
				var group: Node=node.get_node("CraftedSetDressing")
				for item in region.dressing: check(group.has_node(item.id),"packed visual matches logical dressing "+item.id)
				for mesh in node.find_children("*","MeshInstance3D",true,false):
					var mat: Material=mesh.material_override
					if region.indoor: check(not (mat is ShaderMaterial and mat.shader==preload("res://resources/story_ground.gdshader")),"packed interior has no outdoor ground")
				node.free()
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(3840,2160); DisplayServer.window_set_size(root.size)
		var screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false
		screen.start("user://later-acts-photo-unused.json"); screen.set_physics_process(false); screen.photo_mode=true; screen.hud.hide()
		for act in range(2,7):
			var selected := 0
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--act="): selected=int(arg.trim_prefix("--act="))
			if selected>0 and selected!=act: continue
			for stage in range(9):
				print("LATER_PHOTO_BEGIN ",act,":",stage)
				screen.campaign.enter(act,stage)
				var r=screen.campaign.map.regions[stage]
				var point := Vector2(1100,1000) if stage==0 else Vector2(1450,1900) if r.indoor else Vector2(1700,1550)
				screen.campaign.hero_at=r.origin+point; screen.campaign.enemies=[]; screen.world.zoom=19
				for i in 3: screen.campaign.allies[i]=screen.campaign.hero_at+Vector2(0,650+i*80)
				for i in 22: screen.world.build_story(screen.campaign); screen.world.sync_story(Vector2(3840,2160),.016); await process_frame
				var models := 0
				for node in screen.world.scenery.find_children("*","Node3D",true,false):
					if str(node.get_meta("story_model","")).begins_with("a%d_" % act): models+=1
				check(models>5,"actual playable region contains new original modules")
				await RenderingServer.frame_post_draw
				var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
				root.get_texture().get_image().save_png("res://build/story-act%d-%d%s.png" % [act,stage,suffix])
				if stage==0:
					for b in r.buildings:
						screen.campaign.hero_at=b.rect.get_center()
						for frame in 20: screen.world.sync_story(Vector2(3840,2160),.016); await process_frame
						var current: Dictionary=screen.world.environment_builder.roofs.filter(func(item): return item.rect==b.rect)[0]
						check(not current.roof.visible and not current.front.visible and not current.side.visible,"actual new service roof/front/side reveal on entry")
						screen.campaign.hero_at=b.door+Vector2(0,150)
						for frame in 20: screen.world.sync_story(Vector2(3840,2160),.016); await process_frame
						check(current.roof.visible and current.front.visible and current.side.visible,"actual new service exterior returns on exit")
		screen.queue_free(); await process_frame
	print("story later acts: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
