extends SceneTree
const Campaign=preload("res://scripts/story_campaign.gd")
const Screen=preload("res://scripts/story_screen.gd")
const Builder=preload("res://scripts/story_environment.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state(); c.enter(1,7)
	var cave=c.map.regions[7]
	check(cave.floor_polygon.size()>100,"authored irregular cave boundary")
	check(cave.floor_contains(cave.side_anchors[-1],24),"exploration objective sits in new deep branch")
	check(not cave.walkable(Vector2(1600,400),1),"solid rock outside the visible cave footprint")
	# Actually follow navigation through the branches using movement and heights.
	for goal in cave.anchors+cave.side_anchors+cave.chests:
		c.hero_at=c.map.spawn
		var route: PackedVector2Array=c.map.route(c.hero_at,goal)
		check(not route.is_empty(),"cave branch navigation available")
		for target in route:
			for i in 100:
				if c.hero_at.distance_to(target)<10: break
				c.hero_at=c.map.move(c.hero_at,(target-c.hero_at).limit_length(10))
		check(c.hero_at.distance_to(goal)<100,"walk cave branch with height/collision")
	c.enter(1,2)
	var door: Dictionary=c.map.return_door(9); c.hero_at=door.p; c.use_entrance(door)
	check(c.state.stage==9 and c.map.layer==9,"real roadside gate enters castle")
	check(c.map.regions[9].exploration_plan.layout_family=="castle" and c.map.regions[9].extent==Vector2(12400,12200),"castle has courtyard, wings and halls in its own footprint")
	check(c.enemies.any(func(e): return e.quest=="exploration-guardian"),"castle has actual guardian encounter")
	var castle=c.map.regions[9]
	check(not c.map.walkable(castle.spawn+Vector2(-140,-90),1),"gateway masonry blocks walking")
	check(c.map.walkable(castle.spawn+Vector2(0,-90)),"gateway centre is open")
	var seat: Dictionary=castle.dressing.filter(func(item): return item.model=="castle_throne")[0]
	check(not c.map.walkable(seat.position,1),"throne occupies its visible footprint")
	c.hero_at=c.map.waypoint; c.activate_waypoint()
	check("1:9" in c.state.waypoints,"castle waypoint activates")
	var cache: Dictionary=c.nearby_chests()[0]; c.hero_at=cache.p
	check(c.open_cache(cache) and not c.open_cache(cache),"castle exploration reward only awarded once")
	c.save_enabled=true; c.path="user://story-castle-roundtrip-test.json"
	check(c.save_campaign(),"castle save succeeds")
	var loaded=Campaign.new(); loaded.load_campaign(c.path); loaded.save_enabled=false
	check(loaded.state.stage==9 and loaded.map.layer==9,"castle stage survives reload without old stage clamp")
	check(loaded.state.opened_chests==c.state.opened_chests,"castle reward state persists")
	c.hero_at=c.map.waypoint
	check(c.travel(1,0) and c.travel(1,9),"castle waypoint returns from camp")
	c.hero_at=c.map.spawn; c.use_entrance(c.map.entrances()[0])
	check(c.state.stage==2 and c.hero_at.distance_to(door.p)<180,"castle returns to same roadside doorway")
	var b=Builder.new()
	for stage in [0,1,2,7,9]:
		var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
		var scene: Node3D=load("res://scenes/story/opening-%d%s.scn" % [stage,suffix]).instantiate()
		# GPU LightmapGI needs a valid scenario, even in a resource inspection.
		if DisplayServer.get_name()!="headless": root.add_child(scene); await process_frame
		check(scene.has_node("CraftedSetDressing"),"real packed scene contains authored clusters")
		for item in c.map.regions[stage].dressing:
			check(scene.get_node("CraftedSetDressing").has_node(item.id),"packed asset matches logical placement: "+item.id)
		if stage==7:
			check(scene.has_node("CaveRockShell"),"packed cave uses continuous geological shell")
			var outside := 0; var triangles := 0
			for mesh in scene.find_children("*","MeshInstance3D",true,false):
				if not mesh.material_override is ShaderMaterial or mesh.material_override.shader!=b.GROUND: continue
				for surface in mesh.mesh.get_surface_count():
					var arrays: Array=mesh.mesh.surface_get_arrays(surface)
					var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var idx: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
					if idx.is_empty():
						for i in verts.size(): idx.append(i)
					for i in range(0,idx.size(),3):
						var p: Vector3=(verts[idx[i]]+verts[idx[i+1]]+verts[idx[i+2]])/3
						triangles+=1
						if not cave.floor_contains(Vector2(p.x,p.z)*100): outside+=1
			check(triangles>1000 and outside==0,"rendered ground triangles match authoritative cave footprint: %d outside / %d total" % [outside,triangles])
		if stage==9:
			check(scene.has_node("CastleArchitecture"),"castle uses architecture rather than cave dressing")
			for node in scene.get_node("CastleArchitecture").get_children():
				if not node is Node3D: continue
				var at := Vector2(node.position.x,node.position.z)
				if at.distance_to(Vector2(28,61))<.01 or at.distance_to(Vector2(36,61))<.01:
					var floor_y: float=c.map.regions[9].height_at(at*100)*.01
					check(is_equal_approx(node.position.y,floor_y+(1.5 if node is OmniLight3D else 0.0)),"lord's lamp and light sit on actual raised floor")
		if DisplayServer.get_name()!="headless": scene.queue_free(); await process_frame
		else: scene.free()
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(3840,2160); DisplayServer.window_set_size(root.size)
		var screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false
		screen.start("user://story-expansion-photo-unused.json"); screen.set_physics_process(false); screen.photo_mode=true; screen.hud.hide()
		var shots: Array=[[0,Vector2(980,1750),16.0,"south-gate"],[1,Vector2(1450,1050),15.0,"convoy"],[1,Vector2(650,3150),15.0,"logging"],[7,Vector2(2400,1050),17.0,"cave-entry"],[7,Vector2(2950,2750),18.0,"cave-chamber"],[2,Vector2(1050,2110),24.0,"castle-exterior"],[9,Vector2(3200,1750),25.0,"castle-court"],[9,Vector2(3200,3800),21.0,"castle-hall"],[9,Vector2(3200,5730),23.0,"castle-throne"]]
		for shot in shots:
			screen.campaign.enter(1,shot[0]); screen.campaign.hero_at=screen.campaign.map.regions[shot[0]].origin+shot[1]
			screen.campaign.enemies=[]; screen.world.zoom=shot[2]
			for i in 3: screen.campaign.allies[i]=screen.campaign.hero_at+Vector2(0,500+i*80)
			for i in 30: screen.world.sync_story(Vector2(1440,900),.03); await process_frame
			if shot[0]==7 and RenderingServer.get_current_rendering_method()!="gl_compatibility":
				var shell: Node3D=screen.world.scenery.find_child("CaveRockShell",true,false)
				check(shell!=null,"runtime geological shell loaded")
				if shell:
					var mesh: MeshInstance3D=shell.find_children("*","MeshInstance3D",true,false)[0]
					check(mesh.material_override==null and mesh.get_active_material(0) is ShaderMaterial,"node override cannot mask real cave fade material")
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image(); check(picture.get_size()==Vector2i(3840,2160),"actual 4K output")
			var label := "compat-" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
			picture.save_png("res://build/story-expansion-%s%s.png" % [label,shot[3]])
		screen.queue_free(); await process_frame
	print("outdoor castle: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
