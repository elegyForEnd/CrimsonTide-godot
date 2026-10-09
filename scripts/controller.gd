extends RefCounted

# Client-only input and two-motor envelopes; never changes simulation state.
const DEADZONE := 0.22
const RUN_HOLD_TIME := 0.25
var device := -1
var active := false
var ui = preload("res://scripts/controller_ui.gd").new()
var cursor_position := Vector2.ZERO
var cursor_valid := false
var virtual_mouse_ready := false
var direction := Vector2.RIGHT
var b_down := false
var b_time := 0.0
var heavy_down := false
var pulses: Array[Dictionary] = []
var output := Vector2.ZERO
var mouse_buttons := 0
var last_hp := -1.0
var last_dodge := 0.0
var scroll_time := 0.0
var warp_point := Vector2(-1,-1)
var warp_until := 0
var preview_time := 0.0
var enabled := true
var strength := 1.0

static func stick(value: Vector2) -> Vector2:
	var length := minf(value.length(),1.0)
	return Vector2.ZERO if length<=DEADZONE else value.normalized()*(length-DEADZONE)/(1.0-DEADZONE)

static func bind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action,DEADZONE)
	if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)

static func setup() -> void:
	# Replace our previous joypad layout while preserving every keyboard/mouse event.
	for action in ["interact","dash","reload","jump","skill","loot","heal","search_drop","bag","map","pause","sprint","smart_click","left","right","up","down","fire","weapon_art","pad_light","pad_heavy"]:
		if not InputMap.has_action(action): continue
		for old in InputMap.action_get_events(action):
			if old is InputEventJoypadButton or old is InputEventJoypadMotion: InputMap.action_erase_event(action,old)
	var buttons := {"interact":JOY_BUTTON_Y,"pad_light":JOY_BUTTON_RIGHT_SHOULDER,"reload":JOY_BUTTON_X,"jump":JOY_BUTTON_A,"skill":JOY_BUTTON_LEFT_SHOULDER,"loot":JOY_BUTTON_DPAD_DOWN,"heal":JOY_BUTTON_DPAD_DOWN,"search_drop":JOY_BUTTON_DPAD_UP,"bag":JOY_BUTTON_BACK,"map":JOY_BUTTON_RIGHT_STICK,"pause":JOY_BUTTON_START,"smart_click":JOY_BUTTON_RIGHT_SHOULDER}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.device=-1
		event.button_index=buttons[action]
		bind(action,event)
	var axes := {"left":[JOY_AXIS_LEFT_X,-1.0],"right":[JOY_AXIS_LEFT_X,1.0],"up":[JOY_AXIS_LEFT_Y,-1.0],"down":[JOY_AXIS_LEFT_Y,1.0],"pad_heavy":[JOY_AXIS_TRIGGER_RIGHT,1.0],"weapon_art":[JOY_AXIS_TRIGGER_LEFT,1.0]}
	for action in axes:
		var event := InputEventJoypadMotion.new()
		event.device=-1
		event.axis=axes[action][0]
		event.axis_value=axes[action][1]
		bind(action,event)
		InputMap.action_set_deadzone(action,DEADZONE)

func pointer_mode(app) -> bool:
	return app.page_name!="game" or app.modal or app.inventory_open or app.field.map_open or app.rogue_panel_open or not app.session.players.get(app.session.my_id(),{}).get("rogue_selection",{}).is_empty()

func prepare_pointer(app) -> void:
	# Native windows enter through warp_mouse; headless test viewports need one notification.
	if DisplayServer.get_name()=="headless" and not virtual_mouse_ready:
		app.get_viewport().notify_mouse_entered()
		virtual_mouse_ready=true

func mouse_button(app, button: int, pressed: bool) -> void:
	var mask := 1 << (button-1)
	mouse_buttons=(mouse_buttons | mask) if pressed else (mouse_buttons & ~mask)
	var click := InputEventMouseButton.new()
	click.device=-2
	click.button_index=button
	click.pressed=pressed
	click.position=cursor_position if cursor_valid else app.get_viewport().get_mouse_position()
	click.global_position=click.position
	click.button_mask=mouse_buttons
	prepare_pointer(app)
	app.get_viewport().call_deferred("push_input",click,true)

func key_event(code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.device=-2
	key.physical_keycode=code
	key.keycode=code
	key.pressed=pressed
	Input.call_deferred("parse_input_event",key)

func handle(app, event: InputEvent) -> bool:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value)<DEADZONE and event.axis!=JOY_AXIS_TRIGGER_RIGHT:
			return ui.handle(app,event) if active else false
		if device!=event.device:
			release_pointer(app)
			device=event.device
		active=true
	elif event is InputEventMouseMotion and event.device!=-2 and event.relative.length()>2.0:
		if Time.get_ticks_msec()>warp_until or event.position.distance_to(warp_point)>3.0:
			active=false; cursor_valid=false
	elif event is InputEventKey and event.device!=-2:
		active=false; cursor_valid=false
	if handle_combat(app,event): return true
	if ui.handle(app,event): return true
	if event is InputEventJoypadButton:
		if (app.inventory_open or app.camp_pack_open) and event.button_index==JOY_BUTTON_Y:
			if event.pressed and (app.camp_pack_open or not app.session.roguelike.active(app.session)): app.rotate_selected()
			return true
		if app.page_name=="ground":
			var camp_keys := {JOY_BUTTON_DPAD_DOWN:KEY_F,JOY_BUTTON_BACK:KEY_TAB,JOY_BUTTON_START:KEY_ESCAPE,JOY_BUTTON_B:KEY_ESCAPE,JOY_BUTTON_Y:KEY_SPACE,JOY_BUTTON_LEFT_SHOULDER:KEY_Q,JOY_BUTTON_RIGHT_STICK:KEY_M}
			if event.button_index in camp_keys:
				key_event(camp_keys[event.button_index],event.pressed)
				return true
			if event.button_index==JOY_BUTTON_A and not app.modal and not app.camp_pack_open and app.camp and not app.camp.home_ui.visible and not app.camp.home_map.visible:
				key_event(KEY_E,event.pressed)
				return true
		if pointer_mode(app) and event.button_index in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]: return true
		if not pointer_mode(app) and event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT] and event.pressed:
			app.select_item_slot((app.selected_item_slot+(1 if event.button_index==JOY_BUTTON_DPAD_RIGHT else 2))%3)
			return true
		if event.button_index in [JOY_BUTTON_A,JOY_BUTTON_X]:
			var button := MOUSE_BUTTON_LEFT if event.button_index==JOY_BUTTON_A else MOUSE_BUTTON_RIGHT
			if pointer_mode(app) or (not event.pressed and mouse_buttons & (1 << (button-1))):
				mouse_button(app,button,event.pressed)
				return true
		if event.button_index==JOY_BUTTON_B and pointer_mode(app) and event.pressed:
			key_event(KEY_ESCAPE,true)
			key_event(KEY_ESCAPE,false)
			return true
	if event is InputEventJoypadMotion and pointer_mode(app): return true
	if event is InputEventJoypadButton and pointer_mode(app) and event.button_index not in [JOY_BUTTON_BACK,JOY_BUTTON_START,JOY_BUTTON_RIGHT_STICK,JOY_BUTTON_RIGHT_SHOULDER]: return true
	return false

func combat_allowed(app) -> bool:
	return app.page_name=="game" and app.session.running and not pointer_mode(app) and not app.get_tree().paused

func handle_combat(app, event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return false
	var allowed := combat_allowed(app)
	if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_B:
		if event.pressed and allowed:
			b_down=true; b_time=0.0
			return true
		if not event.pressed and b_down:
			var dodge := b_time<RUN_HOLD_TIME and allowed
			b_down=false; b_time=0.0
			if dodge: app.session.action("dash")
			return true
	if event.is_action_pressed("pad_light"):
		if allowed:
			heavy_down=false
			app.session.action("attack_cancel")
			var payload := {"aim":direction}
			app.session.action("attack_press",payload)
			app.session.action("attack_release",payload)
		return allowed
	if event is InputEventJoypadMotion and event.axis==JOY_AXIS_TRIGGER_RIGHT:
		if event.axis_value>DEADZONE and not heavy_down and allowed:
			heavy_down=true
			app.session.action("attack_press",{"aim":direction,"heavy":true})
		elif event.axis_value<=DEADZONE and heavy_down:
			heavy_down=false
			if allowed: app.session.action("attack_release",{"aim":direction})
			else: app.session.action("attack_cancel")
		return true
	return false

func advance_gestures(app, dt: float) -> void:
	if not combat_allowed(app):
		b_down=false; b_time=0.0
		if heavy_down:
			heavy_down=false
			app.session.action("attack_cancel")
	elif b_down:
		b_time+=dt

func sprinting() -> bool:
	return active and b_down and b_time>=RUN_HOLD_TIME

func aim(fallback: Vector2) -> Vector2:
	return direction if active and device>=0 else fallback

func tick(app, dt: float) -> void:
	ui.call_deferred("tick",app,dt)
	enabled=bool(app.profile.data.get("controller_rumble",true))
	strength=clampf(float(app.profile.data.get("controller_rumble_strength",1.0)),0.0,1.0)
	if device not in Input.get_connected_joypads() or not app.get_window().has_focus():
		release_pointer(app)
		device=-1
		active=false
		return
	advance_gestures(app,dt)
	var right := stick(Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y)))
	var left := stick(Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y)))
	if not right.is_zero_approx(): direction=right.normalized()
	elif not left.is_zero_approx(): direction=left.normalized()
	if active and pointer_mode(app):
		var velocity := right
		velocity=velocity.limit_length()
		if not velocity.is_zero_approx():
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			var viewport: Viewport=app.get_viewport()
			var old := cursor_position if cursor_valid else viewport.get_mouse_position()
			var point := (old+velocity*850.0*dt).clamp(Vector2.ONE,viewport.get_visible_rect().size-Vector2.ONE)
			cursor_position=point; cursor_valid=true
			warp_point=point
			warp_until=Time.get_ticks_msec()+80
			viewport.warp_mouse(point)
			var motion := InputEventMouseMotion.new()
			motion.position=point
			motion.global_position=point
			motion.relative=point-old
			motion.button_mask=mouse_buttons
			# Device -2 identifies our virtual pointer, so it cannot switch input mode.
			motion.device=-2
			prepare_pointer(app)
			viewport.call_deferred("push_input",motion,true)
		scroll_time-=dt
		if scroll_time<=0 and ui.pointer:
			for pair in [[JOY_BUTTON_DPAD_UP,MOUSE_BUTTON_WHEEL_UP],[JOY_BUTTON_DPAD_DOWN,MOUSE_BUTTON_WHEEL_DOWN]]:
				if Input.is_joy_button_pressed(device,pair[0]):
					mouse_button(app,pair[1],true)
					mouse_button(app,pair[1],false)
					scroll_time=0.12
	var playing: bool=app.page_name=="game" and app.session.running and (not app.get_tree().paused or (app.ultimate and app.ultimate.active)) and not pointer_mode(app)
	var player: Dictionary=app.session.players.get(app.session.my_id(),{})
	if not playing:
		preview_time=maxf(0.0,preview_time-dt)
		if preview_time<=0.0: stop()
		last_hp=-1.0
		last_dodge=0.0
		return
	var hp := float(player.get("hp",0.0))
	if last_hp>=0 and hp<last_hp: pulse(0.75,0.95,0.32)
	last_hp=hp
	var dodge := float(player.get("dodge_time",0.0))
	if dodge>0 and last_dodge<=0: pulse(0.55,0.3,0.12)
	last_dodge=dodge
	var mix := advance_pulses(dt)
	var hold: Dictionary=player.get("weapon_hold",{})
	if hold.get("shown",false):
		var progress := clampf(float(hold.get("time",0.0))/maxf(0.1,float(hold.get("full_time",1.0))),0.0,1.0)
		mix=mix.max(Vector2(0.10+progress*0.25,progress*0.28)*(0.75+0.25*sin(Time.get_ticks_msec()*0.04)))
	mix*=strength if enabled and active else 0.0
	if mix.distance_to(output)>0.025 or not mix.is_zero_approx():
		if mix.is_zero_approx(): Input.stop_joy_vibration(device)
		else: Input.start_joy_vibration(device,mix.x,mix.y,0.1)
		output=mix

func advance_pulses(dt: float) -> Vector2:
	var mix := Vector2.ZERO
	for i in range(pulses.size()-1,-1,-1):
		var pulse_data: Dictionary=pulses[i]
		pulse_data.time-=dt
		if pulse_data.time<=0:
			pulses.remove_at(i)
			continue
		var envelope := minf(1.0,float(pulse_data.time)/minf(0.09,float(pulse_data.total)))
		mix=mix.max(Vector2(pulse_data.motors)*envelope)
	return mix

func pulse(weak: float, strong: float, duration: float) -> void:
	if pulses.size()>=24: pulses.pop_front()
	pulses.append({"motors":Vector2(weak,strong),"time":duration,"total":duration})

func combat(data: Dictionary, local_id: int) -> void:
	if int(data.get("id",-1))!=local_id: return
	match str(data.get("kind","")):
		"strike":
			if data.get("charged",false): pulse(0.95,1.0,0.30)
			elif int(data.get("weapon",0))==2: pulse(0.65,0.8,0.17)
			else: pulse(0.48,0.30,0.075)
		"impact": pulse(0.85,0.90,0.19) if data.get("heavy",false) else pulse(0.65,0.45,0.095)
		"hold_ready": pulse(0.8,0.6,0.14)
		"ultimate-start": pulse(0.55,0.8,0.4)
		"skill": pulse(1.0,1.0,0.65)
		"spell_burst", "spell_beam": pulse(0.8,0.85,0.24)
		"audio":
			match str(data.get("cue","")):
				"reload-end": pulse(0.55,0.25,0.08)
				"heal": pulse(0.35,0.45,0.20)
				"down": pulse(1.0,1.0,0.55)

func stop() -> void:
	pulses.clear()
	if device>=0: Input.stop_joy_vibration(device)
	output=Vector2.ZERO

func release_pointer(app) -> void:
	b_down=false; b_time=0.0
	if heavy_down and is_instance_valid(app.session): app.session.action("attack_cancel")
	heavy_down=false
	ui.pressed=null
	ui.repeat_direction=Vector2.ZERO
	preview_time=0.0
	for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		if mouse_buttons & (1 << (button-1)): mouse_button(app,button,false)
	stop()
