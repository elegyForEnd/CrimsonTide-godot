extends SceneTree
## Exercise imported mesh visibility and real movement, not just screenshot setup.
const Screen = preload("res://scripts/story_screen.gd")
var checks := 0
var failures := 0
var screen
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	screen.world.sync_story(Vector2(1440,900),0)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/story-polished-"+name+".png")
func run() -> void:
	root.size=Vector2i(1440,900)
	screen=Screen.new(); root.add_child(screen)
	screen.campaign.save_enabled=false
	screen.start("user://story-polish-visual-unused.json")
	screen.campaign.state=screen.campaign.new_state(); screen.campaign.enter(1,0)
	screen.set_physics_process(false)
	await process_frame
	var c=screen.campaign
	var kit=screen.world.environment_builder.kit
	for name in ["service_0","service_1","service_2","service_3","service_4","service_5","south_gate","wall_section","forest_tree","cave_portal","rock_formation","rubble","grass_tuft"]:
		check(ResourceLoader.exists(kit.BASE+"models/"+name+".glb"),"imported mesh "+name)
	for name in ["soil","paving","masonry","timber","slate"]:
		var mat: StandardMaterial3D=kit.pbr(name)
		check(mat.albedo_texture!=null and mat.normal_texture!=null and mat.roughness_texture!=null,"complete PBR "+name)
	for item in screen.world.environment_builder.roofs:
		check(is_instance_valid(item.roof) and is_instance_valid(item.front),"every roof/front binding resolves")
		c.hero_at=item.rect.get_center(); screen.world.sync_story(Vector2(1440,900),0)
		check(not item.roof.visible and not item.front.visible,"every building opens on entry")
		c.hero_at=Vector2(1100,850); screen.world.sync_story(Vector2(1440,900),0)
		check(item.roof.visible and item.front.visible,"every building restores after exit")
	c.hero_at=Vector2(1100,850)
	await capture("camp")
	c.hero_at=c.map.regions[0].buildings[3].rect.get_center()
	await capture("library-interior")
	# Actually walk down through the gate, with geometry and campaign active.
	c.hero_at=Vector2(1100,1690)
	for i in 170:
		c.update(.02,Vector2.DOWN)
		if i%15==0: await process_frame
	check(c.state.stage==1 and c.hero_at.y>2500,"new gate still permits continuous south crossing")
	await capture("south-road")
	c.hero_at=c.map.anchors[0]; await capture("field")
	var entrance: Vector2=c.map.regions[1].origin+Vector2(900,2200)
	c.hero_at=entrance+Vector2(0,150)
	await capture("cave-entrance")
	for door in c.map.entrances():
		if door.stage==7 and door.kind=="entrance": c.use_entrance(door); break
	check(c.state.stage==7,"cave portal enters optional floor")
	c.hero_at=c.map.anchors[0]; await capture("cave")
	check(screen.world.contact_shadows.size()>=3,"sprite contact shadows allocated")
	var start := Time.get_ticks_usec()
	for i in 90: await process_frame
	print("story polish render: mean frame %.2f ms, %d objects, %d primitives, %d draw calls" % [
		float(Time.get_ticks_usec()-start)/90000.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	screen.queue_free(); await process_frame
	print("story asset visual: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
