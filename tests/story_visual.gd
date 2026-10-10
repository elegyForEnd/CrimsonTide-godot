extends SceneTree
const Screen = preload("res://scripts/story_screen.gd")
var checks := 0
var failures := 0
var screen_ref
func check(value: bool, text: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(text)
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	for i in 3: screen_ref.campaign.allies[i]=screen_ref.campaign.hero_at+Vector2((i-1)*75,-75)
	# Allow the authored 0.25 second roof reveal to complete before capture.
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/story-"+name+".png")
func run() -> void:
	root.size=Vector2i(1440,900)
	var screen = Screen.new(); root.add_child(screen)
	screen_ref=screen
	screen.campaign.save_enabled=false
	screen.start("user://story-visual-unused.json")
	screen.campaign.state=screen.campaign.new_state(); screen.campaign.enter(1,0)
	screen.set_physics_process(false)
	await process_frame
	check(screen.world.view_camera.current,"story camera active")
	var south: Vector2=screen.world.project(screen.campaign.hero_at+Vector2(0,300))
	var middle: Vector2=screen.world.project(screen.campaign.hero_at)
	check(south.y>middle.y,"south movement projects toward bottom of screen")
	check(screen.heading.text.contains("雷霆要塞"),"opening camp HUD")
	await capture("camp")
	screen.campaign.hero_at=screen.campaign.map.npc_at[0]
	screen.interact()
	check(screen.modal,"NPC opens actual dialogue panel")
	await capture("npc")
	screen.close_panel()
	screen.campaign.south_gate()
	check(screen.campaign.state.stage==1,"walking transition first field")
	screen.campaign.hero_at=screen.campaign.map.regions[1].origin+Vector2(2100,1500)
	screen.world.focus=screen.campaign.hero_at
	await capture("field")
	screen.campaign.enter(1,4)
	screen.campaign.hero_at=screen.campaign.map.regions[4].origin+Vector2(2400,2750); screen.world.focus=screen.campaign.hero_at
	await capture("bridge")
	screen.campaign.enter(1,1)
	screen.campaign.hero_at=screen.campaign.map.regions[1].origin+Vector2(3380,1550); screen.world.focus=screen.campaign.hero_at
	await capture("stairs")
	check(absf(screen.world.sprites[0].position.y-(screen.campaign.map.height_at(screen.campaign.hero_at)+2)*.01)<.01,"sprite stands at the stair height")
	screen.campaign.enter(1,0)
	screen.campaign.hero_at=screen.campaign.map.regions[0].buildings[0].rect.get_center(); screen.world.focus=screen.campaign.hero_at
	await capture("interior")
	var roof_hidden := false
	for item in screen.world.environment_builder.roofs:
		if item.rect.has_point(screen.campaign.hero_at): roof_hidden=not item.roof.visible
	check(roof_hidden,"entering a house hides its roof")
	screen.campaign.hero_at=Vector2(1100,850); screen.world.focus=screen.campaign.hero_at
	await capture("camp-restored")
	check(screen.world.environment_builder.roofs[0].roof.visible,"leaving house restores roof")
	screen.campaign.enter(1,5)
	screen.campaign.hero_at=screen.campaign.map.anchors[0]; screen.world.focus=screen.campaign.hero_at
	await capture("dungeon")
	for a in [2,3,4,5,6]:
		screen.campaign.enter(a,0); screen.world.focus=screen.campaign.hero_at
		await capture("camp-act%d" % a)
		screen.campaign.enter(a,1); screen.campaign.hero_at=screen.campaign.map.anchors[0]; screen.world.focus=screen.campaign.hero_at
		await capture("field-act%d" % a)
	screen.campaign.enter(3,3); screen.campaign.hero_at=screen.campaign.map.anchors[0]; screen.world.focus=screen.campaign.hero_at
	await capture("mine")
	screen.campaign.enter(4,5); screen.campaign.hero_at=screen.campaign.map.anchors[0]; screen.world.focus=screen.campaign.hero_at
	await capture("crypt")
	screen.campaign.enter(2,4); screen.campaign.hero_at=screen.campaign.map.anchors[0]; screen.world.focus=screen.campaign.hero_at
	await capture("library")
	screen.campaign.enter(1,7); screen.campaign.hero_at=screen.campaign.map.anchors[0]; screen.world.focus=screen.campaign.hero_at
	await capture("optional-cave")
	screen.campaign.enter(1,1); screen.campaign.hero_at=screen.campaign.map.regions[1].origin+Vector2(900,2200); screen.world.focus=screen.campaign.hero_at
	await capture("cave-entrance")
	screen.campaign.update(.02,Vector2.ZERO); screen.show_atlas(); await capture("exploration-atlas"); screen.close_panel()
	screen.campaign.enter(6,6)
	screen.campaign.hero_at=screen.campaign.map.anchors[-1]+Vector2(0,-350); screen.world.focus=screen.campaign.hero_at
	screen.campaign.spawn_enemy(screen.campaign.map.anchors[-1],4,"boss",true)
	var boss: Dictionary=screen.campaign.enemies.back()
	boss.windup=1.0; boss.target=boss.p; boss.radius=380; boss.shape="ring"
	await capture("queen")
	screen.show_journal()
	await capture("journal")
	screen.close_panel()
	screen.show_bag()
	await capture("bag")
	screen.close_panel()
	screen.show_atlas(); check(screen.modal,"exploration atlas opens"); await capture("atlas")
	screen.close_panel()
	screen.set_active(false)
	check(not screen.world.visible and not screen.active,"leaving story hides 3D world")
	screen.queue_free()
	await process_frame
	print("story visual: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
