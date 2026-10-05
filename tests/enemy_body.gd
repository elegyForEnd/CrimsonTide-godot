extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func body_checks(s: TideSession, e: Dictionary, rogue: bool) -> void:
	var body: Rect2=s.enemy_bodies.bounds(e,s.elapsed,rogue)
	check(body.size.x>0 and body.size.y>35,"Entity has an upright body, not just a foot circle")
	for fraction in [.05,.5,.95]:
		var point := Vector2(body.get_center().x,body.position.y+body.size.y*fraction)
		check(s.enemy_bodies.segment_hit(e,point-Vector2(200,0),point+Vector2(200,0),s.elapsed,rogue),"Swept projectile hits head, torso and feet")
		check(s.enemy_bodies.attack_hit(e,point-Vector2(80,0),Vector2.RIGHT,100,s.elapsed,rogue,"thrust",5),"Thrust hits head, torso and feet")
	check(not s.enemy_bodies.segment_hit(e,body.position-Vector2(100,20),Vector2(body.end.x+100,body.position.y-20),s.elapsed,rogue),"Projectile above the entity misses")
	check(not s.enemy_bodies.attack_hit(e,body.position-Vector2(200,20),Vector2.RIGHT,80,s.elapsed,rogue,"beam",5),"Out-of-range beam misses")
	var before := body
	e.height=40.0
	var lifted: Rect2=s.enemy_bodies.bounds(e,s.elapsed,rogue)
	check(is_equal_approx(lifted.position.y,before.position.y-40/(1.0 if rogue else s.enemy_bodies.GROUND_Y)),"Airborne body follows its visual height")
	e.height=0.0

func damage_check(s: TideSession, e: Dictionary, rogue: bool) -> void:
	var p: Dictionary=s.players[1]
	var body: Rect2=s.enemy_bodies.bounds(e,s.elapsed,rogue)
	var chest := body.get_center()
	p.p=s.ruins.move(e.p,Vector2(-180,0))
	var hp: float=e.hp
	s.bullets.clear()
	s.bullets.append({"p":chest-Vector2(80,0),"v":Vector2(1000,0),"life":1.0,"damage":10.0,"owner":1,"knock":0.0,"spell":"star","weapon":3,"hit_ids":[]})
	s.update_bullets(.16)
	check(e.hp<hp and s.bullets.is_empty(),"Authoritative bullet damages torso and is consumed")
	hp=e.hp
	s.bullets.append({"p":body.position-Vector2(80,30),"v":Vector2(1000,0),"life":1.0,"damage":10.0,"owner":1,"knock":0.0,"spell":"star","weapon":3,"hit_ids":[]})
	s.update_bullets(.16)
	check(e.hp==hp,"Authoritative projectile outside the body deals no damage")
	s.bullets.clear()
	# A high projectile's ground path misses, but the visible path crosses the body.
	hp=e.hp
	s.bullets.append({"p":chest+Vector2(-80,100),"height":100.0,"height_velocity":0.0,"v":Vector2(1000,0),"life":1.0,"damage":10.0,"owner":1,"knock":0.0,"spell":"star","weapon":3,"hit_ids":[]})
	if rogue:
		s.update_bullets(.16)
		check(e.hp<hp,"Elevated projectile uses its visible trajectory")
	s.bullets.clear()
	hp=e.hp
	p.p=s.ruins.move(e.p,Vector2(-60,0))
	p.weapon=Catalog.starter_index(0)
	p.strike_aim=(chest-p.p).normalized()
	p.combo=0
	s.release_strike(p)
	check(e.hp<hp,"Authoritative melee aimed at the torso damages the entity")
	# The entity may protrude visually past a wall, but damage cannot cross it.
	hp=e.hp
	s.ruins.walls.append(Rect2(chest-Vector2(40,300),Vector2(10,600)))
	s.bullets.append({"p":chest-Vector2(80,0),"v":Vector2(1000,0),"life":1.0,"damage":10.0,"owner":1,"knock":0.0,"spell":"star","weapon":3,"hit_ids":[]})
	s.update_bullets(.16)
	check(e.hp==hp,"Body hurtboxes preserve wall occlusion")
	s.ruins.walls.clear()

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.map_id="city"; s.ruins=RoyalCity.new(); s.ruins.generate(1729); s.ruins.walls.clear()
	s.enemies.clear()
	for kind in EnemyFrames.HEIGHTS.size():
		s.spawn_enemy(Vector2(1600,1100),kind)
		var e: Dictionary=s.enemies.back()
		e.stagger=999; e.hp=10000; e.max_hp=e.hp
		body_checks(s,e,false)
		if kind==2: damage_check(s,e,false)
		s.enemies.clear()
	for index in 10:
		s.spawn_enemy(Vector2(1600,1100),4)
		var e: Dictionary=s.enemies.back()
		if index<3:
			e.raid_boss=true; e.boss_kind=index
		else:
			e.mini_boss=true; e.mini_kind=index-3
			if index==5: e.final_form=true
			elif index in [6,7,8]: e.wild_boss=true; e.wild_kind=index-6
			elif index==9: e.dragon_boss=true
		body_checks(s,e,false)
		s.enemies.clear()
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.raid.phase="rogue_combat"; s.enemies.clear(); s.ruins.walls.clear()
	for floor_index in 5:
		for big in [false,true]:
			s.roguelike.spawn_minion(s,s.players[1].p+Vector2(100,0),floor_index,0,false)
			var e: Dictionary=s.enemies.back()
			if big: s.roguelike.combat.setup_boss(e,floor_index)
			else: s.roguelike.combat.setup_minion(e,floor_index,0,false,s.rng)
			e.stagger=999; e.hp=10000; e.max_hp=e.hp
			body_checks(s,e,true)
			if floor_index==0 and not big: damage_check(s,e,true)
			s.enemies.clear()
	s.queue_free()
	await process_frame
	print("ENEMY BODY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
