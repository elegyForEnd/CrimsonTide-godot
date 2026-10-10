extends SceneTree
const Screen=preload("res://scripts/story_screen.gd")
var screen
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(text)
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	screen.world.sync_story(Vector2(1440,900),0)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size()==Vector2i(3840,2160),"real 4K output "+name)
	image.save_png("res://build/story-4k-"+name+".png")
func run() -> void:
	root.size=Vector2i(3840,2160); DisplayServer.window_set_size(root.size)
	var graphics=root.get_node("GraphicsQuality"); graphics.quality=0; graphics.upscale=0; graphics.apply()
	check(root.scaling_3d_mode==Viewport.SCALING_3D_MODE_FSR2,"FSR2 active")
	check(is_equal_approx(root.scaling_3d_scale,.67),"internal resolution recorded")
	screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false
	screen.start("user://render-upgrade-unused.json"); screen.campaign.state=screen.campaign.new_state()
	screen.set_physics_process(false); screen.photo_mode=true; screen.hud.hide()
	for stage in [0,1,7]:
		screen.campaign.enter(1,stage)
		var c=screen.campaign
		check(not c.map.regions[stage].terrain_samples.is_empty(),"authoritative sculpted terrain")
		for name in ["albedo","normal","orm"]:
			var tex: Texture2D=load("res://assets/story/environment/pbr/rock_"+name+".png")
			check(tex.get_width()==2048,"2K rock "+name)
		var authored=screen.world.scenery.find_child("Opening%d" % stage,true,false)
		check(authored!=null and authored.get_node("BakedIndirectLight").light_data!=null,"actual baked GI "+str(stage))
		var mist: Array=authored.find_children("*","FogVolume",true,false)
		check(not mist.is_empty() and mist[0].visible,"local mist really enabled "+str(stage))
		c.hero_at=c.map.regions[0].spawn if stage==0 else c.map.anchors[0]+Vector2(90,100)
		for i in 3: c.allies[i]=c.hero_at+Vector2(-90 if i==1 else 90,-95)
		await capture("camp" if stage==0 else "field" if stage==1 else "cave")
		if stage==0:
			for item in screen.world.environment_builder.roofs:
				c.hero_at=item.rect.get_center(); screen.world.sync_story(Vector2(1440,900),.03)
				check(item.amount>0 and item.amount<1,"roof uses progressive fade")
				for i in 10: screen.world.sync_story(Vector2(1440,900),.03)
				check(not item.roof.visible,"roof reveals interior")
				c.hero_at=Vector2(1100,850); screen.world.sync_story(Vector2(1440,900),0)
			c.hero_at=c.map.regions[0].buildings[3].rect.get_center(); await capture("interior")
		if stage==1:
			var updated_trees := 0
			for item in screen.world.environment_builder.occluders:
				if item.node.has_meta("licensed_tree"):
					var meshes: Array=item.node.find_children("*","MeshInstance3D",true,false)
					if not meshes.is_empty() and meshes[0].mesh==screen.world.environment_builder.kit.vendor_tree_mesh: updated_trees+=1
			check(updated_trees>20,"cached layout uses current editable vegetation meshes")
			c.hero_at=Vector2(1100,1790); await capture("south-gate")
			c.hero_at=c.map.regions[1].origin+Vector2(900,2350); await capture("cave-entrance")
			var poly: PackedVector2Array=c.map.regions[1].shorelines[0]
			check(not c.map.regions[1].walkable((poly[0]+poly[-1])*.5),"curved river rejects submerged movement")
			c.hero_at=c.map.regions[1].origin+Vector2(3380,1000); await capture("stairs")
	graphics.quality=1; graphics.apply(); check(not screen.world.get_node("WorldEnvironment").environment.volumetric_fog_enabled if screen.world.has_node("WorldEnvironment") else true,"standard profile applied")
	screen.queue_free(); await process_frame
	print("render upgrade: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
