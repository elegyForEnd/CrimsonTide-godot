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
	app.profile.path="user://all-weapon-mounts.json"
	for mode in ["campaign","roguelike"]:
		app.session.solo({"hero":0,"mode":"expedition" if mode=="campaign" else mode})
		app.session.launch(false,1729)
		app.session.set_physics_process(false)
		app.session.enemies.clear()
		var field=app.rogue_field if mode=="roguelike" else app.field
		var combat: CombatVisuals=field.combat
		combat.set_process(false)
		field.visible=true
		combat.visible=true
		var p: Dictionary=app.session.players[1]
		await create_timer(.2).timeout
		field.set_process(false)
		combat.transform=field.ground_transform()
		for hero in 4:
			p.hero=hero
			for weapon in 21:
				p.weapon=weapon
				var spec: Dictionary=Catalog.weapon(weapon)
				var family := Catalog.weapon_family(weapon)
				p.swing_total=maxf(1.0,float(spec.rate))
				for combo in 3:
					p.strike_aim=Vector2.LEFT if combo==1 else Vector2.RIGHT
					p.aim=p.strike_aim
					p.swing_time=p.swing_total-float(spec.windup)-.08
					var socket: Dictionary=field.weapon_effect_socket(1)
					check(not socket.is_empty() and socket.tip.is_finite(),"All hero/weapon combinations have a valid mount")
					combat.reset()
					combat.event({"kind":"strike","p":p.p,"aim":p.strike_aim,"weapon":family,"weapon_index":weapon,"id":1,"combo":combo,"reach":spec.reach,"pattern":spec.get("pattern","")})
					combat.transform=field.ground_transform()
					combat.stylized.advance(.08)
					field.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					var bound := 0
					for effect in combat.stylized.effects:
						if effect.has("socket_local"):
							bound+=1
							var mounted: Vector2=combat.stylized.get_global_transform()*effect.socket_local
							var live: Dictionary=field.weapon_effect_socket(1)
							check(mounted.distance_to(live.stroke_tip)<.05,"Rendered weapon effect uses directional release mount")
						check(bound>0,"Every weapon release binds a painted effect: %s hero%d weapon%d combo%d"%[mode,hero,weapon,combo])
						if combo==0 and weapon in [0,1,2,3,7,12,13,15,16,20]:
							root.get_texture().get_image().save_png("user://mount-%s-h%d-w%d.png"%[mode,hero,weapon])
					if float(spec.windup)>0:
						combat.reset()
						p.pending_strike=true
						p.swing_time=p.swing_total-float(spec.windup)*.5
						combat.event({"kind":"windup","p":p.p,"aim":p.strike_aim,"weapon":family,"weapon_index":weapon,"id":1,"windup":spec.windup})
						combat.stylized.advance(float(spec.windup)*.1)
						await process_frame
						await RenderingServer.frame_post_draw
						check(not combat.stylized.effects.is_empty() and combat.stylized.effects[0].has("socket_local"),"Charge follows the weapon focus")
						combat.stylized.cancel_charge(1)
						check(combat.stylized.effects.is_empty(),"Interrupted charge leaves no floating attachment")
		combat.reset()
	print("ALL WEAPON MOUNTS ",checks," checks, ",failures," failures; 4 heroes x 21 weapons x 2 modes x 3 combos")
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)
