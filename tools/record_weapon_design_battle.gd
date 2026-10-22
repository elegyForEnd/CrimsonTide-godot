extends SceneTree
const Hold=preload("res://scripts/weapon_hold_attack.gd")
const Actions=preload("res://scripts/rogue_actions.gd")
const OUT="res://build/vfx-v6/battle-frames/"
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
	var observed: Array=[]
	s.combat_event.connect(func(event):
		if str(event.get("kind",""))=="impact" and float(event.get("damage",0))>0: observed.append(event.duplicate(true)))
	var report: Array=[]
	var selected: Array=[600,613,615,624,636]
	var crystal_trial := "--crystal" in OS.get_cmdline_user_args()
	var output := "res://build/vfx-crystal/frames/" if crystal_trial else OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if crystal_trial: selected=[600]
	var capture_dt := 1.0/60.0 if crystal_trial else 1.0/30.0
	var frame_count := 132 if crystal_trial else 66
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="):
			var requested := int(arg.trim_prefix("--weapon="))
			if requested in selected: selected=[requested]
	var report_path := "res://build/vfx-v6/battle-capture.json"
	if not crystal_trial and FileAccess.file_exists(report_path):
		var previous: Variant=JSON.parse_string(FileAccess.get_file_as_string(report_path))
		if previous is Array: report=previous.filter(func(item): return int(item.weapon) not in selected)
	for weapon in selected:
		for action in (["art"] if crystal_trial else ["normal","heavy","art"]):
			p.erase("weapon_hold"); p.erase("build_pending_art"); p.erase("build_pending_art_tail")
			p.weapon=weapon; p.hero=1 if weapon>=636 else 0; p.p=Vector2(700,690); p.motion="idle"
			for key in ["attack","cast_time","swing_time","dodge_time","reload","flask_time","height","art_cd","hitstop"]: p[key]=0.0
			p.mana=10000; p.aim=Vector2.RIGHT; p.strike_aim=p.aim; p.combo=0; p.air_art=false; p.pending_strike=false
			field.combat.reset(); s.bullets.clear()
			s.enemies.clear(); observed.clear()
			s.spawn_enemy(p.p+Vector2(135 if crystal_trial else 240 if weapon>=624 else 85,0),0)
			var target: Dictionary=s.enemies.back()
			if crystal_trial: s.roguelike.combat.setup_minion(target,0,0,false,s.rng,s)
			target.hp=1000000; target.max_hp=1000000
			if action=="normal": s.attack(p)
			elif action=="heavy": Hold.begin(s,p)
			else: Actions.start_art(s,p)
			for frame in frame_count:
				if action=="heavy" and frame<30: Hold.tick(s,p,{},(1.0/30.0))
				if action=="heavy" and frame==30: Hold.release(s,p)
				Actions.tick(s,p,capture_dt); Actions.tail(s,p,capture_dt)
				for key in ["attack","cast_time"]: p[key]=maxf(0,float(p[key])-capture_dt)
				# Mirror the real session's on-contact attacker pause in the capture.
				if float(p.hitstop)>0: p.hitstop=maxf(0,float(p.hitstop)-capture_dt)
				else: p.swing_time=maxf(0,float(p.swing_time)-capture_dt)
				if p.pending_strike and p.swing_total-p.swing_time>=float(p.get("build_strike_windup",Catalog.weapon(p.weapon).windup)):
					p.pending_strike=false; s.release_strike(p)
				s.update_bullets(capture_dt)
				for enemy in s.enemies: enemy.flash=maxf(0,float(enemy.get("flash",0))-capture_dt)
				field.clock+=capture_dt; field.combat._process(capture_dt); field.queue_redraw(); field.backdrop.queue_redraw()
				await process_frame; RenderingServer.force_draw(false)
				root.get_texture().get_image().get_region(Rect2i(300,400,900,450)).save_png(output+"%d-%s-%03d.png" % [weapon,action,frame])
			print("ACTUAL ROGUE CLIP ",weapon," ",action," complete")
			report.append({"weapon":weapon,"action":action,"real_hits":observed.size(),"damage":1000000-float(target.hp),"frames":frame_count,"fps":60 if crystal_trial else 30})
	FileAccess.open("res://build/vfx-crystal/capture.json" if crystal_trial else "res://build/vfx-v6/battle-capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free(); await process_frame; await process_frame; quit()
