extends SceneTree
var screen
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	screen=preload("res://scripts/story_screen.gd").new(); root.add_child(screen)
	var c=screen.campaign
	c.state=c.new_state(); c.save_enabled=false; c.inventory.initialize(); c.state.started=true
	c.hero_at=c.spawn_at(); screen.set_active(true); screen.world.build(); screen.refresh()
	screen.set_physics_process(false)
	for i in 20: await process_frame
	if screen.map_capture.texture==null: push_error("No actual scene photograph rendered"); quit(1); return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/rpg-minimap.png")
	var click := InputEventMouseButton.new(); click.position=Vector2(1270,450); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
	Input.parse_input_event(click); await process_frame
	click=InputEventMouseButton.new(); click.position=Vector2(1270,450); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=false; Input.parse_input_event(click)
	if not screen.modal: push_error("Clicking minimap did not open atlas"); quit(1); return
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/rpg-actual-map.png")
	screen.close_panel()
	c.state.pending={}; c.state.unlocked.append("1:1"); c.enter_zone("1:1"); c.state.pending={}
	for i in 20: await process_frame
	if screen.map_capture.zone_key!="1:1" or screen.map_capture.texture==null: push_error("Zone switch did not refresh photograph"); quit(1); return
	screen.show_map()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/rpg-field-map.png")
	print("SCARLET_MAP_VISUAL actual scene, minimap, atlas and zone refresh verified")
	screen.queue_free()
	for i in 5: await process_frame
	quit()
