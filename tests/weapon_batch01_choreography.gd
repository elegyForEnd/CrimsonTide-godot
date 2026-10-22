extends SceneTree
const Actions=preload("res://scripts/rogue_actions.gd")
const Choreo=preload("res://scripts/weapon_batch_choreography.gd")
const Art=preload("res://scripts/weapon_batch_art.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	var s=app.session; s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.set_physics_process(false); s.raid.phase="rogue_combat"
	var p: Dictionary=s.players[1]
	var runway := Vector2.ZERO
	for y in range(600,951,20):
		for x in range(500,1101,20):
			var at := Vector2(x,y)
			var valid: bool=s.ruins.clear_line(at,at+Vector2(420,0))
			for offset in range(-60,161,4):
				for depth in [-22,0,22]: valid=valid and not s.ruins.blocked(at+Vector2(offset,depth),18)
			valid=valid and not s.ruins.blocked(at+Vector2(190,0),25)
			if valid and runway==Vector2.ZERO: runway=at
	check(runway!=Vector2.ZERO,"Real map has a clear runway for movement test")
	if runway==Vector2.ZERO: quit(1); return
	var events: Array=[]
	s.combat_event.connect(func(e): events.append(e.duplicate(true)))
	for weapon in range(600,648):
		if not Choreo.enabled(weapon) or not Art.enabled(weapon): continue
		for rate in [30,60,120]:
			p.weapon=weapon; p.p=runway; p.status="active"; p.aim=Vector2.RIGHT
			for key in ["art_cd","swing_time","attack","cast_time","reload","dodge_time","flask_time","height","height_velocity"]: p[key]=0.0
			p.air_art=false; p.mana=p.max_mana; p.pending_strike=false
			s.enemies.clear(); s.bullets.clear(); app.rogue_field.combat.reset(); events.clear()
			s.spawn_enemy(p.p+Vector2(190,0),0)
			if s.enemies.is_empty(): push_error("No target at "+str(p.p)); quit(1); return
			var target: Dictionary=s.enemies.back(); target.hp=100000; target.max_hp=100000
			var start: Vector2=p.p
			check(Actions.start_art(s,p),"Sequence starts")
			var mana: float=p.mana; var cooldown: float=p.art_cd
			var lift := 0.0
			for frame in rate*2:
				var dt: float=1.0/rate
				Actions.tick(s,p,dt); Actions.tail(s,p,dt)
				s.update_bullets(dt)
				lift=maxf(lift,p.height)
				for key in ["cast_time","swing_time","attack"]: p[key]=maxf(0,float(p[key])-dt)
			var strikes: Array=events.filter(func(e): return e.kind=="strike")
			var impacts: Array=events.filter(func(e): return e.kind=="impact" and float(e.get("damage",0))>0)
			var spec: Dictionary=Choreo.of(weapon)
			check(strikes.size()==spec.steps.size(),"Authored release count: %d/%d" % [weapon,rate])
			check(not impacts.is_empty(),"Cast damages a real target: %d/%d" % [weapon,rate])
			var moving: bool=spec.steps.any(func(step): return absf(float(step[3]))>0 or (step.size()>10 and absf(float(step[10]))>0))
			check(p.p.distance_to(start)>.1 if moving else p.p.distance_to(start)<.1,"Authored stationary or moving cast "+str(weapon))
			check(is_zero_approx(p.height) and not p.has("build_art_sequence"),"Sequence lands and cleans up")
			check(is_equal_approx(p.mana,mana) and is_equal_approx(p.art_cd,cooldown),"Sequence spends mana and cooldown only once "+str([mana,p.mana,cooldown,p.art_cd]))
			if weapon in [612,617]: check(lift>50,"Leaping arts have a real visible arc")
			if not strikes.is_empty():
				check(strikes.back().sequence_final and strikes.filter(func(e): return e.sequence_final).size()==1,"Exactly the last authored release is final")
		# Cancel during travel; no late damage or stuck height ownership.
		p.p=Vector2(700,690)
		for key in ["art_cd","swing_time","attack","cast_time","dodge_time","height"]: p[key]=0.0
		p.air_art=false; events.clear(); Actions.start_art(s,p); Actions.tick(s,p,.1)
		p.dodge_time=.2; Actions.tick(s,p,.02); Actions.tick(s,p,1.0)
		check(not p.has("build_art_sequence") and not events.any(func(e): return e.kind=="strike"),"Dodge cancels upcoming hits")
	app.queue_free(); await process_frame
	print("BATCH01 CHOREOGRAPHY ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
