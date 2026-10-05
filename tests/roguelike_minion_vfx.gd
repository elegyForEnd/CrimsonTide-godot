extends SceneTree
var checks := 0
var failures := 0
var events: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-minion-vfx.json"
	root.add_child(app)
	await process_frame
	var s=app.session
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.set_physics_process(false)
	s.combat_event.connect(func(data): events.append(data))
	var p: Dictionary=s.players[1]
	var field=app.rogue_field
	var fx=field.enemy_fx
	var c=s.roguelike.combat
	for floor_index in 5:
		s.raid.floor=floor_index+1; s.roguelike.enter(s)
		field.camera_x=0; field._process(0)
		for variant in 8:
			for index in 2:
				s.enemies.clear(); s.bullets.clear(); c.reset(); fx.reset(); events.clear()
				s.roguelike.spawn_minion(s,Vector2(600,575),floor_index,variant,false)
				var e: Dictionary=s.enemies[0]
				e.hp=e.max_hp*.4
				s.roguelike.spawn_minion(s,Vector2(720,575),floor_index,0,false)
				var recipient: Dictionary=s.enemies[1]
				recipient.hp=recipient.max_hp*.5; recipient["summon_owner"]=e.id
				# Keep the fixture in a clear corridor: later floors have a pillar to the right.
				for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
					var point: Vector2=e.p+direction*45
					if s.ruins.clear_line(e.p,point): p.p=point; break
				p.invuln=100
				e.cd=0; e.in_attack_range=true; e.skill_cds=[0.0,0.0]; e.skill_cds[1-index]=100.0
				c.update(s,e,.01)
				check(e.minion_skill==index and e.attack_time>0,"Actual AI selects requested available move")
				check(fx.charge_seen.has(e.id),"All 80 attacks emit real charge VFX")
				s.damage_enemy(e,1,1,Vector2.ZERO,0)
				check(not fx.charge_seen.has(e.id),"Damage clears cancellable charge")
				e.stagger=0; e.cd=0; e.skill_cds[index]=0; c.minion_start_gap=0
				c.update(s,e,.01); c.update(s,e,e.minion_windup+.01); c.tick(s,.01)
				check(events.any(func(data): return data.kind=="rogue-minion" and data.action=="release"),"Release emits actual event")
				check(not fx.charge_seen.has(e.id),"Release clears charge")
				c.tick(s,.8); fx._process(.02)
				check(not fx.energy.bursts.is_empty() or not fx.energy.emitters.is_empty() or not c.missiles.is_empty() or not s.bullets.is_empty(),"Every move has real particles, shaders or projectile textures")
				check(fx.energy.emitters.all(func(node): return node.texture!=null and node.local_coords),"Particles own real textures and follow camera")
				var releases := 0
				for data in events:
					if data.kind=="rogue-minion" and data.action=="release": releases+=1
				c.update(s,e,.05)
				var later := 0
				for data in events:
					if data.kind=="rogue-minion" and data.action=="release": later+=1
				check(releases==1 and later==1,"Attack releases VFX exactly once")
	s.enemies.clear(); c.reset(); fx.reset()
	s.roguelike.spawn_minion(s,Vector2(600,575),0,4,false)
	var healer: Dictionary=s.enemies[0]
	s.roguelike.spawn_minion(s,Vector2(720,575),0,0,false)
	var recipient: Dictionary=s.enemies[1]
	recipient.hp=recipient.max_hp*.5
	healer.cd=0; healer.in_attack_range=true; p.p=Vector2(645,575)
	c.update(s,healer,.01)
	recipient.p+=Vector2(45,20)
	fx._process(.01)
	check(fx.support_links.size()==1 and fx.support_links[0].b==recipient.p,"Healing beam follows actual moving recipient")
	s.damage_enemy(healer,1,1,Vector2.ZERO,0); fx._process(.01)
	check(fx.support_links.is_empty(),"Interrupted healing leaves no target beam")
	field.reset_effects()
	check(fx.support_links.is_empty() and fx.trails.is_empty() and fx.energy.emitters.is_empty(),"Room cleanup clears all effect types")
	app.queue_free()
	await process_frame
	await process_frame
	print("ROGUE MINION VFX ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
