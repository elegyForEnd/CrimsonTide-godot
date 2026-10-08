extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://stroke-directions.json"
	for mode in ["expedition","roguelike"]:
		app.session.solo({"hero":0,"mode":mode})
		app.session.launch(false,1729)
		app.session.set_physics_process(false)
		app.session.enemies.clear()
		var field=app.field if mode=="expedition" else app.rogue_field
		field.visible=true
		await create_timer(.15).timeout
		field.set_process(false)
		field.combat.set_process(false)
		var p: Dictionary=app.session.players[1]
		for hero in 4:
			p.hero=hero
			var weapons := range(21)+range(600,648)
			for weapon in weapons:
				if Catalog.weapon_family(weapon) not in [1,2]: continue
				p.weapon=weapon
				p.swing_total=1.5
				p.swing_time=1.5-float(Catalog.weapon(weapon).windup)-.08
				for direction in 8:
					p.strike_aim=Vector2.from_angle(direction*PI/4)
					p.aim=p.strike_aim
					var socket: Dictionary=field.weapon_effect_socket(1)
					check(socket.stroke_tip.distance_to(socket.tip)<.001,"Release attaches to visible blade rather than a virtual directional endpoint")
					var delta: Vector2=socket.stroke_tip-socket.stroke_pivot
					check(absf(delta.cross(socket.aim))<.001,"Stroke origin lies along attack direction")
					check(delta.dot(socket.aim)>0,"Stroke origin lies ahead of swing pivot")
					if direction in [2,6]:
						check(absf(delta.x)<.001,"Vertical attacks have no sideways offset")
					if hero==0 and weapon==17 and direction%2==0:
						field.combat.reset()
						field.combat.event({"kind":"strike","p":p.p,"aim":p.strike_aim,"weapon":1,"weapon_index":17,"combo":0,"reach":84,"id":1})
						field.combat.stylized.advance(.06)
						field.queue_redraw()
						await process_frame
						await RenderingServer.frame_post_draw
						var effect: Dictionary=field.combat.stylized.effects[0]
						var emitted: Vector2=field.combat.stylized.get_global_transform()*effect.socket_local
						check(emitted.distance_to(socket.stroke_tip)<.01,"Actual rendered release uses the directional stroke point")
						root.get_texture().get_image().save_png("user://stroke-%s-%d.png"%[mode,direction])
		field.combat.reset()
	print("STROKE DIRECTIONS ",checks," checks, ",failures," failures; four heroes, all campaign/run melee weapons, eight directions, two modes")
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)
