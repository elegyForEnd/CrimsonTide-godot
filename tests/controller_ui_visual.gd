extends SceneTree
var app: Node
func _initialize() -> void: call_deferred("run")
func input_button(code: int, down: bool) -> void:
	var event := InputEventJoypadButton.new(); event.device=0; event.button_index=code; event.pressed=down; root.push_input(event)
func capture(name: String) -> void:
	await process_frame; await process_frame
	app.controller.active=true
	app.controller.ui.call_deferred("tick",app,0.12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/controller-ui-"+name+".png")
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); await process_frame
	app.set_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1440,900)
	app.fit_ui(); app.show_title(); app.controller.active=true
	app.controller.ui.ensure_focus(app)
	await capture("title")
	input_button(JOY_BUTTON_DPAD_DOWN,true); input_button(JOY_BUTTON_DPAD_DOWN,false)
	input_button(JOY_BUTTON_DPAD_DOWN,true); input_button(JOY_BUTTON_DPAD_DOWN,false)
	input_button(JOY_BUTTON_A,true); input_button(JOY_BUTTON_A,false)
	await capture("settings")
	app.close_modal(); app.go_camp(); await capture("camp")
	app.session.solo({"hero":0,"mode":"roguelike"}); app.session.launch(false,1729); app.session.set_physics_process(false)
	app.session.players[1].rogue_selection={}; app.rogue_panel_open=false
	await capture("combat")
	app.queue_free(); await process_frame; quit()
