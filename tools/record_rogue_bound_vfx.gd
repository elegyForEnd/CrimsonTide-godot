extends SceneTree
const Hold=preload("res://scripts/weapon_hold_attack.gd")
const Actions=preload("res://scripts/rogue_actions.gd")
const OUT="res://build/vfx-3d/rogue-bound/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900); root.content_scale_size=root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var app=load("res://scenes/main.tscn").instantiate(); app.profile.path="user://rogue-bound-capture.json"; root.add_child(app)
	var s=app.session; s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.set_physics_process(false); s.enemies.clear(); s.raid.phase="rogue_combat"
	var field=app.rogue_field; field.show()
	for i in 6: await process_frame
	var p: Dictionary=s.players[1]; p.rogue_selection={}; app.update_hud(); app.page.hide(); app.set_process(false)
	field.set_process(false); field.combat.set_process(false); field.enemy_fx.set_process(false)
	field.camera_x=120; field.camera_y=80
	for weapon in [600,613,615,643]:
		for action in ["normal","heavy","art"]:
			p.erase("weapon_hold"); p.erase("build_pending_art"); p.erase("build_pending_art_tail")
			p.weapon=weapon; p.hero=1 if weapon>=636 else 0; p.p=Vector2(800,580); p.motion="idle"
			for key in ["attack","cast_time","swing_time","dodge_time","reload","flask_time","height","art_cd","hitstop"]: p[key]=0.0
			p.mana=10000; p.aim=Vector2.RIGHT; p.strike_aim=p.aim; p.combo=0; p.air_art=false; p.pending_strike=false
			field.combat.reset(); s.bullets.clear()
			if action=="normal": s.attack(p)
			elif action=="heavy": Hold.begin(s,p)
			else: Actions.start_art(s,p)
			for frame in 66:
				if action=="heavy" and frame<30: Hold.tick(s,p,{},(1.0/30.0))
				if action=="heavy" and frame==30: Hold.release(s,p)
				Actions.tick(s,p,(1.0/30.0)); Actions.tail(s,p,(1.0/30.0))
				for key in ["attack","cast_time","swing_time"]: p[key]=maxf(0,float(p[key])-(1.0/30.0))
				if p.pending_strike and p.swing_total-p.swing_time>=float(p.get("build_strike_windup",Catalog.weapon(p.weapon).windup)):
					p.pending_strike=false; s.release_strike(p)
				for bullet in s.bullets: bullet.p+=Vector2(bullet.v)*(1.0/30.0); bullet.life-=(1.0/30.0)
				s.bullets=s.bullets.filter(func(b): return b.life>0)
				field.clock+=(1.0/30.0); field.combat._process((1.0/30.0)); field.queue_redraw(); field.backdrop.queue_redraw()
				await process_frame; RenderingServer.force_draw(false)
				root.get_texture().get_image().get_region(Rect2i(400,260,640,420)).save_png(OUT+"aimed-%d-%s-%03d.png" % [weapon,action,frame])
			print("ACTUAL ROGUE CLIP ",weapon," ",action," complete")
	app.queue_free(); await process_frame; await process_frame; quit()
