extends SceneTree
const Pad := preload("res://scripts/controller.gd")
const Hold := preload("res://scripts/weapon_hold_attack.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func button(code: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device=0; event.button_index=code; event.pressed=true
	return event
func trigger(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device=0; event.axis=JOY_AXIS_TRIGGER_RIGHT; event.axis_value=value
	return event
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var pad=app.controller
	for action in ["interact","pad_light","reload","jump","skill","loot","bag","map","pause"]:
		check(InputMap.event_is_action(button({"interact":JOY_BUTTON_Y,"pad_light":JOY_BUTTON_RIGHT_SHOULDER,"reload":JOY_BUTTON_X,"jump":JOY_BUTTON_A,"skill":JOY_BUTTON_LEFT_SHOULDER,"loot":JOY_BUTTON_DPAD_DOWN,"bag":JOY_BUTTON_BACK,"map":JOY_BUTTON_RIGHT_STICK,"pause":JOY_BUTTON_START}[action]),action),"Mapping "+action)
	check(InputMap.event_is_action(trigger(1.0),"pad_heavy"),"Right trigger attacks")
	var count := InputMap.action_get_events("fire").size()
	pad.setup()
	check(count==InputMap.action_get_events("fire").size(),"Setup does not duplicate bindings")
	check(Pad.stick(Vector2(.15,.1))==Vector2.ZERO,"Stick drift stays in deadzone")
	check(Pad.stick(Vector2(1,1)).length()<=1.001,"Diagonal stick bounded")
	check(Pad.stick(Vector2(.6,0)).x>0 and Pad.stick(Vector2(.6,0)).x<1,"Analog speed preserved")
	for rogue in [false,true]:
		app.session.solo({"hero":0,"mode":"roguelike" if rogue else "expedition"})
		app.session.launch(false,1729)
		app.session.set_physics_process(false)
		app.session.enemies.clear()
		app.page_name="game"
		app.modal=false; app.inventory_open=false; app.field.map_open=false
		var player: Dictionary=app.session.players[1]
		if rogue: player.rogue_selection={}; app.session.raid.phase="rogue_combat"
		pad.active=true; pad.device=0; pad.direction=Vector2.UP
		app._input(trigger(1.0))
		check(player.has("weapon_hold"),"Trigger press begins real weapon hold")
		Hold.tick(app.session,player,{"fire":true},1.5)
		check(player.weapon_hold.get("ready",false),"Held trigger can reach full charge")
		app._input(trigger(0.0))
		check(not player.has("weapon_hold"),"Trigger release reaches real attack release")
	check(pad.aim(Vector2.LEFT)==Vector2.UP,"Stick overrides mouse aim")
	pad.active=false
	check(pad.aim(Vector2.LEFT)==Vector2.LEFT,"Mouse aim restored")
	app.inventory_open=true
	check(pad.pointer_mode(app),"Inventory gets pointer")
	check(pad.handle(app,trigger(1.0)),"Inventory swallows trigger combat event")
	app.inventory_open=false
	pad.stop(); pad.device=-1
	pad.combat({"kind":"impact","id":2},1)
	check(pad.pulses.is_empty(),"Other players cannot rumble local controller")
	pad.combat({"kind":"strike","id":1,"charged":true},1)
	pad.combat({"kind":"impact","id":1},1)
	var motors: Vector2=pad.advance_pulses(.01)
	check(motors.y>.95,"Small impact cannot overwrite charged heavy pulse")
	check(pad.advance_pulses(1.0)==Vector2.ZERO and pad.pulses.is_empty(),"Envelopes end without stuck vibration")
	pad.combat({"kind":"skill","id":1},1)
	check(pad.advance_pulses(.05)==Vector2.ONE,"Ultimate drives both motors at full strength")
	pad.stop()
	check(pad.pulses.is_empty(),"Stopping clears feedback")
	for i in 100: pad.pulse(.1,.2,.3)
	check(pad.pulses.size()==24,"Feedback queue bounded")
	var motion := InputEventMouseMotion.new()
	motion.position=Vector2(100,100); motion.relative=Vector2(50,50)
	pad.active=true; pad.warp_point=motion.position; pad.warp_until=Time.get_ticks_msec()+80
	pad.handle(app,motion)
	check(pad.active,"OS pointer warp cannot disable controller mode")
	motion.position=Vector2(200,200)
	pad.handle(app,motion)
	check(not pad.active,"Real mouse movement restores mouse mode")
	app.inventory_open=true
	pad.mouse_buttons=0
	pad.ui.pointer=true
	pad.handle(app,button(JOY_BUTTON_A))
	check(pad.mouse_buttons & MOUSE_BUTTON_MASK_LEFT,"A holds virtual mouse button for dragging")
	app.inventory_open=false
	var release := button(JOY_BUTTON_A); release.pressed=false
	pad.handle(app,release)
	check(pad.mouse_buttons==0,"Release finishes pointer drag even after panel closed")
	await process_frame
	var move := InputEventJoypadMotion.new()
	move.device=0; move.axis=JOY_AXIS_LEFT_X; move.axis_value=0.6
	Input.parse_input_event(move)
	await process_frame
	var movement := Input.get_vector("left","right","up","down")
	check(movement.x>0.1 and movement.x<0.9,"Actual action mapping preserves analog movement")
	move.axis_value=0.0
	Input.parse_input_event(move)
	await process_frame
	check(Input.get_vector("left","right","up","down")==Vector2.ZERO,"Neutral stick releases movement")
	app.queue_free()
	await process_frame
	print("CONTROLLER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
