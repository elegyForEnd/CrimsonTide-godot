extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	if not ok:
		failures+=1
		push_error(title)
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.session.solo(app.config())
	app.session.launch(false,1729)
	await process_frame
	var cg: UltimateCinematic=app.ultimate
	app.session.action("skill")
	check(cg.active and paused,"accepted local Q starts and pauses solo battle")
	var elapsed: float=app.session.elapsed
	await create_timer(0.12).timeout
	check(app.session.elapsed==elapsed,"simulation stays frozen during solo CG")
	cg.stop()
	check(not paused,"stop resumes battle")
	app.session.action("skill")
	check(not cg.active,"cooldown cannot replay CG")
	for hero in 3:
		cg.play(hero,false)
		cg.set_process(false)
		cg.age=cg.impact_time*.65
		cg.queue_redraw()
		cg.light.queue_redraw()
		cg.captions.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/ultimate-"+str(hero)+".png")
		cg.age=cg.impact_time+.20
		cg.fired=true
		cg.queue_redraw()
		cg.light.queue_redraw()
		cg.captions.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/ultimate-burst-"+str(hero)+".png")
		cg.stop()
		cg.set_process(true)
	cg.play(1,true)
	check(not paused,"online CG does not pause simulation")
	await create_timer(1.0).timeout
	check(not cg.active,"online short version automatically finishes")
	cg.play(2,false)
	var event := InputEventKey.new()
	event.physical_keycode=KEY_ESCAPE
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	check(not cg.active and not paused,"skip restores simulation")
	check(not app.modal,"skip key does not also open pause menu")
	cg.play(0,false)
	await create_timer(cg.duration+.2).timeout
	check(not cg.active and not paused,"full version automatically restores simulation")
	app.show_title()
	app.show_settings()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/voice-settings.png")
	app.show_credits()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/voice-credits.png")
	app.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("ULTIMATE CG: ",failures," failures")
	quit(1 if failures else 0)
