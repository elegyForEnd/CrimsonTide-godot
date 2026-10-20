extends SceneTree
## Capture a real offline battle with authoritative weapon actions. Never saves.
const Actions=preload("res://scripts/rogue_actions.gd")
const Build=preload("res://scripts/rogue_build.gd")
const OUT="res://build/vfx-3d/battle-frames/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=Vector2i(1440,900); root.content_scale_size=root.size
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.profile.path="user://world-vfx-capture.json"
	app.session.solo({"hero":0,"mode":"roguelike"}); app.session.launch(false,1729)
	var s=app.session; s.set_physics_process(false); s.enemies.clear()
	var p: Dictionary=s.players[1]
	p.rogue_selection={}; s.raid.phase="rogue_combat"
	var field=app.rogue_field; field.show()
	for frame in 8: await process_frame
	field.set_process(false); field.combat.set_process(false); field.enemy_fx.set_process(false)
	var weapons := [613,622,638,643]
	for frame in 180:
		var t := frame%45
		if t==0:
			p.weapon=weapons[frame/45]; p.hero=1 if p.weapon>=636 else 0
			p.attack=0; p.cast_time=0; p.swing_time=0; p.dodge_time=0; p.art_cd=0; p.reload=0; p.flask_time=0; p.height=0; p.mana=10000; p.air_art=false
			p.aim=Vector2.RIGHT; p.strike_aim=Vector2.RIGHT; p.combo=2
			s.bullets.clear(); field.combat.reset()
			p.swing_total=float(Catalog.weapon(p.weapon).rate); p.swing_time=p.swing_total-float(Catalog.weapon(p.weapon).windup)-.02
			p["build_strike_context"]=Build.context(s,p,"attack")
			Actions.normal(s,p)
		if t==20:
			p.attack=0; p.cast_time=0; p.swing_time=0; p.art_cd=0
			Actions.start_art(s,p)
			if p.has("build_pending_art"):
				p.build_pending_art.remaining=0; Actions.tick(s,p,0)
		if t in [9,30]:
			s.broadcast_combat({"kind":"impact","p":p.p+Vector2(170,0),"aim":Vector2.RIGHT,"weapon_index":p.weapon,"damage":40,"enemy_id":frame,"id":1})
		for bullet in s.bullets: bullet.p+=Vector2(bullet.v)/30.0; bullet.life-=1.0/30
		s.bullets=s.bullets.filter(func(b): return b.life>0)
		p.swing_time=maxf(0,p.swing_time-1.0/30); p.cast_time=maxf(0,p.cast_time-1.0/30)
		field.clock+=1.0/30; field.combat._process(1.0/30)
		field.queue_redraw(); field.backdrop.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"%03d.png" % frame)
	app.queue_free(); await process_frame; await process_frame
	print("WORLD BATTLE MOTION 180 frames, four authoritative weapon sequences")
	quit()
