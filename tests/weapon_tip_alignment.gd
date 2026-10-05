extends SceneTree
const Library=preload("res://scripts/vfx_library.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://weapon-tip-alignment.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	var p: Dictionary=app.session.players[1]
	app.field.camera=p.p
	await create_timer(.15).timeout
	var projection: Transform2D=app.field.ground_transform()
	for hero in 3:
		p.hero=hero
		for weapon in [1,2,14,17,19]:
			p.weapon=weapon
			p.swing_total=1.0
			for frame in [2,3]:
				p.swing_time=1.0-float(Catalog.weapon(weapon).windup)-(.08 if frame==2 else .3)
				for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
					p.strike_aim=direction
					var socket: Dictionary=app.field.weapon_effect_socket(1)
					check(not socket.is_empty(),"Every melee pose provides a live blade socket")
					for combo in 3:
						var key := Library.weapon_key(weapon)
						var extent := Library.fitted_size(key,Vector2(224,224))
						var mirror := Vector2(Library.facing_scale(key),-1 if combo==1 else 1)
						var contact := Library.blade_contact(key)*extent
						var angle: float=socket.aim.angle()
						var screen := Transform2D(angle,mirror,0,socket.stroke_tip-(contact*mirror).rotated(angle))
						var local := projection.affine_inverse()*screen
						check((projection*(local*contact)).distance_to(socket.stroke_tip)<.001,"Painted stroke contact follows attack direction")
						var actual := projection*local
						check(absf(actual.x.length()-actual.y.length())<.00001 and absf(actual.x.dot(actual.y))<.00001,"Projection preserves original effect aspect")
	p.hero=0; p.weapon=1; p.strike_aim=Vector2.RIGHT
	p.swing_total=1; p.swing_time=1-float(Catalog.weapon(1).windup)-.08
	app.field.combat.reset()
	app.field.combat.event({"kind":"strike","p":p.p,"aim":p.strike_aim,"weapon":1,"weapon_index":1,"id":1,"combo":0,"reach":112})
	app.field.combat.set_process(false)
	app.field.combat.stylized.advance(.06)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://weapon-tip-alignment.png")
	print("WEAPON TIP ALIGNMENT ",checks," checks, ",failures," failures; screenshot user://weapon-tip-alignment.png")
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)

