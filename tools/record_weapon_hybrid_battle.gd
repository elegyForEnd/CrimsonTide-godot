extends SceneTree
const Hold=preload("res://scripts/weapon_hold_attack.gd")
const Actions=preload("res://scripts/rogue_actions.gd")
const OUT="res://build/vfx-hybrid/"
const FFMPEG="D:/develop/ffmpeg-2024-11-21-git-f298507323-full_build/bin/ffmpeg.exe"
const REVISION="hybrid-v7-painted-bold-smoke-4"
func _initialize() -> void:
	root.unfocusable=true
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900); root.content_scale_size=root.size
	for folder in ["frames","battle","close","posters"]: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+folder))
	var selected: Array=range(600,648)+[17,18,19,20]
	var resume := "--resume" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapons="):
			selected=[]
			for item in arg.trim_prefix("--weapons=").split(","): selected.append(int(item))
	var report: Array=[]
	var report_path := OUT+"battle-capture.json"
	if FileAccess.file_exists(report_path):
		var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(report_path))
		if saved is Array: report=saved
	var app=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://hybrid-vfx-review.json"; root.add_child(app)
	var s=app.session; s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.set_physics_process(false); s.raid.phase="rogue_combat"
	var field=app.rogue_field; field.show()
	for frame in 12: await process_frame
	var p: Dictionary=s.players[1]; p.rogue_selection={}; app.update_hud(); app.page.hide(); app.set_process(false)
	app.set_process_input(false); app.set_process_unhandled_input(false)
	field.set_process(false); field.combat.set_process(false); field.enemy_fx.set_process(false)
	field.camera_x=120; field.camera_y=80
	var hits: Array=[]
	s.combat_event.connect(func(event):
		if str(event.get("kind",""))=="impact" and float(event.get("damage",0))>0: hits.append(event.duplicate(true)))
	for weapon in selected:
		for action in ["normal","heavy","art"]:
			var key := "%d-%s" % [weapon,action]
			if resume and FileAccess.file_exists(OUT+"battle/"+key+".mp4") and report.any(func(item): return int(item.weapon)==weapon and str(item.action)==action and int(item.real_hits)>0 and str(item.get("revision",""))==REVISION): continue
			p.erase("weapon_hold"); p.erase("build_pending_art"); p.erase("build_pending_art_tail"); p.erase("build_pending_action")
			p.weapon=weapon; p.hero=1 if weapon>=636 else 0; p.p=Vector2(700,690); p.motion="idle"
			for parameter in ["attack","cast_time","swing_time","dodge_time","reload","flask_time","height","art_cd","hitstop"]: p[parameter]=0.0
			p.mana=10000; p.aim=Vector2.RIGHT; p.strike_aim=p.aim; p.combo=0; p.air_art=false; p.pending_strike=false
			p.ammo=maxi(1,Actions.clip(p)); p.reserve=999
			field.combat.reset(); s.bullets.clear(); s.enemies.clear(); hits.clear()
			s.spawn_enemy(p.p+Vector2(180 if Catalog.weapon_family(weapon) in [0,3] else 85,0),0)
			if s.enemies.is_empty(): push_error("No real target for "+key); quit(1); return
			var target: Dictionary=s.enemies.back()
			s.roguelike.combat.setup_minion(target,0,0,false,s.rng,s)
			target.hp=1000000; target.max_hp=1000000
			var release_frame := ceili(float(Hold.parameters(s,p).hold_time)*30)+1
			if action=="normal": s.attack(p)
			elif action=="heavy": Hold.begin(s,p)
			else: Actions.start_art(s,p)
			var peak := -1.0; var peak_frame := 0
			for frame in 72:
				var dt := 1.0/30.0
				if action=="heavy" and frame<release_frame: Hold.tick(s,p,{},dt)
				if action=="heavy" and frame==release_frame:
					Hold.release(s,p)
				Actions.tick(s,p,dt); Actions.tail(s,p,dt)
				for parameter in ["attack","cast_time"]: p[parameter]=maxf(0,float(p[parameter])-dt)
				if p.hitstop>0: p.hitstop=maxf(0,float(p.hitstop)-dt)
				else: p.swing_time=maxf(0,float(p.swing_time)-dt)
				if p.pending_strike and p.swing_total-p.swing_time>=float(p.get("build_strike_windup",Catalog.weapon(p.weapon).windup)):
					p.pending_strike=false; s.release_strike(p)
				s.update_bullets(dt)
				for enemy in s.enemies: enemy.flash=maxf(0,float(enemy.get("flash",0))-dt)
				field.clock+=dt; field.combat._process(dt); field.queue_redraw(); field.backdrop.queue_redraw()
				await process_frame; RenderingServer.force_draw(false)
				var crop := Rect2i(0,300,1440,600) if Catalog.weapon_family(weapon) in [0,3] else Rect2i(300,400,900,450)
				var image := root.get_texture().get_image().get_region(crop)
				image.save_jpg(OUT+"frames/%03d.jpg" % frame,.94)
				# Choose a reproducible active frame, not a separate illustrated poster.
				var weight := 0.0
				for effect in field.combat.weapon_world.effects:
					if effect.kind in ["release","beam","burst"] and effect.ribbon.visible:
						var peak_time := .045 if effect.kind=="burst" else .035 if effect.kind=="beam" else float(effect.emission_time)
						weight+=minf(effect.age/maxf(.01,peak_time),1.0)*pow(1-clampf((effect.age-peak_time)/maxf(.01,effect.tail_time),0,1),1.2)
				if weight>peak and (action!="heavy" or frame>release_frame):
					peak=weight; peak_frame=frame; image.save_png(OUT+"posters/"+key+".png")
			var output: Array=[]
			var status := OS.execute(FFMPEG,PackedStringArray(["-hide_banner","-loglevel","error","-y","-framerate","30","-i",ProjectSettings.globalize_path(OUT+"frames/%03d.jpg"),"-frames:v","72","-an","-c:v","libx264","-threads","2","-crf","17","-pix_fmt","yuv420p","-movflags","+faststart",ProjectSettings.globalize_path(OUT+"battle/"+key+".mp4")]),output,true,false)
			if status!=0: push_error("Encoder failed: "+key+str(output)); quit(1); return
			var crop_filter := "crop=650:500:360:0" if Catalog.weapon_family(weapon) in [0,3] else "crop=650:440:80:0"
			status=OS.execute(FFMPEG,PackedStringArray(["-hide_banner","-loglevel","error","-y","-i",ProjectSettings.globalize_path(OUT+"battle/"+key+".mp4"),"-vf",crop_filter,"-an","-c:v","libx264","-threads","2","-crf","17","-pix_fmt","yuv420p","-movflags","+faststart",ProjectSettings.globalize_path(OUT+"close/"+key+".mp4")]),output,true,false)
			if status!=0: push_error("Close-view encoder failed: "+key+str(output)); quit(1); return
			var record := {"weapon":weapon,"action":action,"revision":REVISION,"real_hits":hits.size(),"damage":1000000-float(target.hp),"frames":72,"fps":30,"poster_frame":peak_frame}
			report=report.filter(func(item): return not (int(item.weapon)==weapon and str(item.action)==action))
			report.append(record)
			FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("HYBRID BATTLE ",key," hits=",hits.size()," damage=",record.damage)
			for frame in 72: DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT+"frames/%03d.jpg" % frame))
	app.queue_free(); await process_frame; await process_frame; quit()
