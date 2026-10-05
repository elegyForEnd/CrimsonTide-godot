extends SceneTree
var app: Node
var s: TideSession
const KEYS := ["bell","thorn","queen","knight","hidden","mirror","ember","moon","earth","storm","abyss","dragon"]
func _initialize() -> void: call_deferred("run")
func spawn(key: String) -> Dictionary:
	s.enemies.clear(); s.bullets.clear(); s.raid.hazards=[]; s.raid.phase="explore"
	match key:
		"bell","thorn","queen": s.raid.kind=["bell","thorn","queen"].find(key); s.raid.day=2; s.expedition.spawn_boss(s)
		"knight": s.spawn_enemy(s.raid.center,4)
		"hidden","moon": s.expedition.spawn_boss(s,key=="moon")
		"mirror","ember": s.mini_bosses.spawn(s,1,0 if key=="mirror" else 1)
		"earth","storm": s.wild_bosses.spawn_mini(s,1,0 if key=="earth" else 1)
		"abyss": s.wild_bosses.spawn_final(s)
		"dragon": s.dragon_boss.spawn(s,1)
	var e: Dictionary=s.enemies.back()
	if key=="hidden": e.hidden_final=true; e.boss_kind=4; e.boss_name="冥火尸王 · 墓玥"
	s.raid.phase="boss"
	return e
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate(); app.profile.path="user://extraction-boss-effect-audit.json"; root.add_child(app)
	app.session.solo({"hero":0}); app.session.launch(false,1729); s=app.session; s.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/extraction-boss-audit"))
	var captures := 0
	for key in KEYS:
		for move_index in 4:
			var e := spawn(key)
			app.field.boss_fx.reset(); app.field.combat.reset()
			var p: Dictionary=s.players[1]; p.p=e.p+Vector2(190,0); p.invuln=999; p.status="active"; p.hp=p.max_hp
			app.field.camera=p.p; app.toast_time=0
			var name: String=s.BossChoreography.MOVES[key][move_index]
			s.BossChoreography.start(s,e,name,Vector2.RIGHT,p.p)
			var last: float=e.attack_marks.back()
			var elapsed := 0.0
			for stage in [maxf(.1,float(e.windup)-.20),float(e.windup)+.08,last+.08]:
				while elapsed<stage:
					var dt := minf(.04,stage-elapsed); elapsed+=dt; e.attack_time=maxf(0,e.attack_total-elapsed)
					s.BossChoreography.advance(s,dt); s.expedition.update_hazards(s,dt); s.update_bullets(dt)
				await create_timer(.08).timeout; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/extraction-boss-audit/%s-%d-%02d.png" % [key,move_index,captures%3])
				captures+=1
			print("AUDIT ",key," / ",name)
	app.queue_free(); await process_frame; await process_frame
	print("EXTRACTION BOSS EFFECT AUDIT: ",captures," captures / 48 moves / 12 identities")
	quit()
