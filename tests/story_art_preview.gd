extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var screen=preload("res://scripts/story_screen.gd").new(); root.add_child(screen)
	screen.start("user://story-art-preview-unused.json"); screen.set_physics_process(false)
	var c=screen.campaign
	var ok: bool=int(c.state.act)==5 and int(c.state.stage)==7 and not c.save_enabled and c.state.waypoints.size()==46 and not c.save_campaign()
	if not ok: push_error("Art preview must choose the requested region, enable travel and never write a campaign save")
	screen.queue_free(); await process_frame
	print("story art preview: ","PASS" if ok else "FAIL"); quit(0 if ok else 1)
