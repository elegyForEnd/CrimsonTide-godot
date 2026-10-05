extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-vfx.json"
	root.add_child(app)
	await process_frame
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var s=app.session
	var field=app.rogue_field
	s.players[1].p=Vector2(2500,575)
	field._process(0) # Initialize the new-area signature before placing the test camera.
	field.camera_x=1800
	field.camera=Vector2(2520,575)
	check(field.HERO_SCALE<1.65,"Hero is smaller in horizontal mode")
	check(field.ground_transform().origin==Vector2(-1800,-field.camera_y),"Effects follow both axes of the long-map camera")
	var strike := {"kind":"strike","p":s.players[1].p,"id":1,"weapon":1,"aim":Vector2.RIGHT}
	s.combat_event.emit(strike)
	check(not field.combat.stylized.effects.is_empty(),"Weapon textures receive events far along the map")
	s.combat_event.emit({"kind":"skill","p":s.players[1].p,"id":1,"hero":3,"aim":Vector2.RIGHT})
	check(field.combat.sigil_art!=null and field.combat.blade_art!=null,"Necromancer retains original ultimate art")
	app.sound.dialogue.next_allowed.clear()
	app.sound.dialogue.stop_all()
	s.combat_event.emit({"kind":"dodge","p":s.players[1].p,"id":1})
	var voice_played := false
	for voice in app.sound.dialogue.speakers:
		if voice.playing and voice.get_meta("cue","")=="dash": voice_played=true
	check(voice_played,"Original voice plays beyond the old map camera's 720px limit")
	check(app.sound.charges[3]!=null and app.sound.short_bursts[3]!=null,"Missing jingle safely uses an available recording")
	var hp: float=s.players[1].hp
	for floor_index in 5:
		for shape in ["line","cone","ring","cyclone","aura","circle"]:
			field.enemy_fx.burst({"floor":floor_index,"p":s.players[1].p,"end":s.players[1].p+Vector2(400,0),"radius":100.0,"inner":60.0,"direction":Vector2.RIGHT,"shape":shape,"life":.5})
			check(not field.enemy_fx.energy.bursts.is_empty(),"Each enemy attack shape owns a live shader")
			check(not field.enemy_fx.energy.emitters.is_empty(),"Each theme emits actual textured particles")
			for emitter in field.enemy_fx.energy.emitters:
				check(emitter.local_coords and emitter.texture!=null,"Particles follow horizontal camera and contain a real texture")
			field.enemy_fx.reset()
	check(s.players[1].hp==hp,"Presentation never applies extra damage")
	for n in 40: field.enemy_fx.energy.particles(Vector2.ZERO,Color.WHITE)
	check(field.enemy_fx.energy.emitters.size()<=24,"Crowded fights keep particle emitter count bounded")
	field.reset_effects()
	check(field.enemy_fx.energy.emitters.is_empty() and field.combat.motes.is_empty() and field.combat.stylized.effects.is_empty(),"Area transition clears all transient effects")
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(.2).timeout
	print("ROGUE VFX: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
