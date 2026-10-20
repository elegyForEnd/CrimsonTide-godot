extends SceneTree
const Hold=preload("res://scripts/weapon_hold_attack.gd")
const Actions=preload("res://scripts/rogue_actions.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	root.size=Vector2i(1440,900); root.content_scale_size=root.size
	var app=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://rogue-spatial-mount-test.json"; root.add_child(app)
	var s=app.session
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.set_physics_process(false); s.enemies.clear(); s.raid.phase="rogue_combat"
	var field=app.rogue_field; field.show()
	for i in 5: await process_frame
	field.set_process(false); field.combat.set_process(false)
	var p: Dictionary=s.players[1]
	p.rogue_selection={}; app.update_hud(); app.page.hide()
	p.p=Vector2(800,580); p.motion="idle"
	field.camera_x=120; field.camera_y=80
	var bridge=field.combat.weapon_view; var fx=field.combat.weapon_world
	check(is_equal_approx(field.combat.weapon_flights.body_gain,1.0),"Roguelike projectiles use the common presentation scale without stacking another multiplier")
	for factor in [1.0,1.5]:
		field.scale=Vector2.ONE*factor; bridge.sync()
		for weapon in range(600,648):
			for facing in [-1,1]:
				field.combat.reset(); p.erase("weapon_hold"); p.erase("build_pending_art")
				p.weapon=weapon; p.hero=1 if weapon>=636 else 0
				for key in ["attack","cast_time","swing_time","dodge_time","reload","flask_time","height"]: p[key]=0.0
				p.mana=10000; p.aim=Vector2(facing,0); p.strike_aim=p.aim
				Hold.begin(s,p); Hold.tick(s,p,{},1.2); fx.advance(.45)
				check(fx.charges.has(1),"Actual held weapon starts gathering %d" % weapon)
				if not fx.charges.has(1): continue
				var charge=fx.charges[1]
				var socket: Dictionary=bridge.socket(1)
				check(not charge.data.charge_paths.is_empty(),"Reviewed weapon retains independent contour tracks %d" % weapon)
				for site: Vector3 in charge.data.charge_sites:
					var projected: Vector2=bridge.view_camera.unproject_position(bridge.world.to_global(site))
					var nearest := INF
					for expected: Vector2 in socket.charge_points: nearest=minf(nearest,projected.distance_to(expected))
					check(nearest<.06,"Gathering stays on actual weapon at scale %s facing %d weapon %d" % [factor,facing,weapon])
				p.p+=Vector2(31,-12); fx.advance(.02)
				socket=bridge.socket(1)
				var projected: Vector2=bridge.view_camera.unproject_position(bridge.world.to_global(charge.data.charge_sites[0]))
				check(projected.distance_to(socket.charge_points[0])<.06,"Contour follows next movement %d" % weapon)
				p.p-=Vector2(31,-12)
				if factor==1.0 and facing==1 and weapon in [600,613,624,643]:
					fx.advance(.02); field.queue_redraw(); bridge.sync()
					await process_frame; RenderingServer.force_draw(false)
					root.get_texture().get_image().save_png("res://build/rogue-spatial-charge-%d.png" % weapon)
					Hold.release(s,p)
					if p.has("build_pending_art"): p.build_pending_art.remaining=0; Actions.tick(s,p,0)
					fx.advance(.08); field.queue_redraw(); bridge.sync()
					await process_frame; RenderingServer.force_draw(false)
					root.get_texture().get_image().save_png("res://build/rogue-spatial-release-%d.png" % weapon)
	field.combat.reset(); app.queue_free(); await process_frame; await process_frame
	print("ROGUE SPATIAL MOUNTS ",checks," checks, ",failures," failures; 48 weapons, both facings, two UI scales")
	quit(1 if failures else 0)
