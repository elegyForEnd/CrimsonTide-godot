extends SceneTree
const Hold := preload("res://scripts/weapon_hold_attack.gd")
const Actions := preload("res://scripts/rogue_actions.gd")
var app: Node
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func button(code: int, down: bool) -> void:
	var event := InputEventJoypadButton.new(); event.device=0; event.button_index=code; event.pressed=down
	root.push_input(event)
func trigger(value: float) -> void:
	var event := InputEventJoypadMotion.new(); event.device=0; event.axis=JOY_AXIS_TRIGGER_RIGHT; event.axis_value=value
	root.push_input(event)
func clear_player(p: Dictionary) -> void:
	for key in ["attack","swing_time","cast_time","reload","dodge_time","hitstop","attack_buffer","dash","jump_cd","height","height_velocity"]: p[key]=0.0
	p.pending_strike=false; p.ammo=100; p.mana=1000; p.art_cd=0.0
	p.erase("build_pending_art"); p.erase("weapon_hold")
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app); await process_frame
	app.set_process(false)
	var pad=app.controller
	for rogue in [false,true]:
		app.session.solo({"hero":0,"mode":"roguelike" if rogue else "expedition"}); app.session.launch(false,1729)
		app.session.set_physics_process(false); app.session.enemies.clear()
		app.page_name="game"; app.modal=false; app.inventory_open=false; app.field.map_open=false; app.rogue_panel_open=false
		var p: Dictionary=app.session.players[1]
		if rogue: p.rogue_selection={}; app.session.raid.phase="rogue_combat"
		p.weapon=602; clear_player(p)
		var events: Array=[]
		var collect: Callable=func(data): events.append(data.duplicate(true))
		app.session.combat_event.connect(collect)
		button(JOY_BUTTON_RIGHT_SHOULDER,true)
		check(p.pending_strike or events.any(func(e): return e.kind=="strike"),"RB starts ordinary attack immediately")
		check(not p.has("weapon_hold"),"RB never enters charge hold")
		button(JOY_BUTTON_RIGHT_SHOULDER,false)
		clear_player(p); events.clear()
		trigger(1.0)
		check(p.weapon_hold.get("heavy",false),"RT reserves authoritative heavy attack")
		trigger(0.0)
		if rogue: Actions.tick(app.session,p,.15)
		var heavy := events.filter(func(e): return e.kind=="strike")
		check(heavy.size()==1 and heavy[0].get("charged",false),"RT tap emits exactly one heavy strike in both modes")
		check(not p.has("weapon_hold"),"RT release clears hold")
		clear_player(p); events.clear()
		trigger(1.0); Hold.tick(app.session,p,{"fire":true},1.5)
		check(p.weapon_hold.ready,"Holding RT still reaches full charge")
		trigger(0.0)
		clear_player(p)
		button(JOY_BUTTON_B,true)
		check(p.dodge_time==0,"B press does not preemptively dodge")
		pad.advance_gestures(app,.1)
		check(not pad.sprinting(),"Short B hold does not run")
		button(JOY_BUTTON_B,false)
		check(p.dodge_time>0,"B tap release actually dodges")
		clear_player(p)
		button(JOY_BUTTON_B,true); pad.advance_gestures(app,.30)
		check(pad.sprinting() and p.dodge_time==0,"Long B hold runs without dodging")
		app.session.ruins.walls.clear()
		var old: Vector2=p.p
		app.session.move_player(p,Vector2.RIGHT,pad.sprinting(),.1,220)
		check(p.motion=="run" and p.p.distance_to(old)>22,"B hold drives actual sprint movement")
		button(JOY_BUTTON_B,false)
		check(not pad.sprinting() and p.dodge_time==0,"Releasing long B hold never dodges")
		button(JOY_BUTTON_B,true); app.inventory_open=true
		pad.advance_gestures(app,.1); button(JOY_BUTTON_B,false)
		check(not pad.sprinting() and p.dodge_time==0,"Opening UI cancels B gesture without a dodge")
		app.inventory_open=false; clear_player(p)
		if rogue:
			button(JOY_BUTTON_A,true); button(JOY_BUTTON_A,false)
			check(p.height_velocity>0,"A triggers actual existing rogue jump")
		clear_player(p); trigger(1.0)
		pad.release_pointer(app)
		check(not p.has("weapon_hold") and not pad.sprinting(),"Focus loss cancels held heavy attack and running")
		app.session.combat_event.disconnect(collect)
	var keyboard := InputEventKey.new(); keyboard.physical_keycode=KEY_SPACE; keyboard.pressed=true
	check(InputMap.event_is_action(keyboard,"dash"),"Keyboard Space dodge remains bound")
	app.queue_free(); await process_frame
	print("CONTROLLER LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
