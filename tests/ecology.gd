extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	for seed_value in [1,1729,9899]:
		s.launch(false,seed_value)
		s.set_physics_process(false)
		for e in s.enemies:
			if not e.has("difficulty"): continue
			check(Ecology.allowed(s.ruins,e.p,e.type),"Initial resident belongs to its habitat")
		for attempt in 140: s.spawn_enemy()
		var counts := {}
		for e in s.enemies:
			if not e.has("difficulty"): continue
			check(Ecology.allowed(s.ruins,e.p,e.type),"Refill stays in species habitat")
			check(not s.ruins.blocked(e.p,25),"No habitat resident in walls or water")
			check(e.p.distance_to(s.players[1].p)>=260,"No spawning on player")
			counts[e.habitat]=int(counts.get(e.habitat,0))+1
		for count in counts.values(): check(count<=5,"Per-block population limit")
		s.enemies.clear()
		var observer: Dictionary=s.players[1]
		observer.p=s.ruins.sites[0].p
		for attempt in 40: s.spawn_enemy(Vector2.ZERO,-1,true)
		check(not s.enemies.is_empty(),"Ambient refill finds a nearby habitat")
		for e in s.enemies:
			var distance: float=e.p.distance_to(observer.p)
			check(distance>=s.AMBIENT_SPAWN_MIN and distance<=s.AMBIENT_SPAWN_MAX,"Ambient refill stays near the player without spawning on them")
		var sleeper: Dictionary=s.enemies[0]
		observer.p=sleeper.p+Vector2(1800,0)
		sleeper.cd=10.0
		sleeper.moving=true
		s.update_enemies(0.1)
		check(sleeper.cd==10.0 and not sleeper.moving,"Distant ordinary enemies skip simulation")
		observer.p=sleeper.p+Vector2(180,0)
		s.update_enemies(0.1)
		check(sleeper.cd<10.0,"Approaching player wakes ordinary enemies")
		for kind in [0,1,2,3,5,6,7,8,9,10,11,12,13,14,15,16]:
			s.enemies.clear()
			s.spawn_enemy(Vector2(10,10),kind)
			check(s.enemies.size()==1,"Invalid requested point finds legal habitat")
			if not s.enemies.is_empty(): check(Ecology.allowed(s.ruins,s.enemies[0].p,kind),"Fallback preserves species region")
	var p: Dictionary=s.players[1]
	s.ruins.walls.clear()
	p.p=Vector2(1300,1100)
	for kind in range(5,11):
		s.enemies.clear()
		s.spawn_enemy(Vector2.ZERO,kind)
		var e: Dictionary=s.enemies[0]
		e.p=p.p-Vector2(180,0)
		e.home=e.p
		s.bullets.clear()
		p.hp=p.max_hp
		p.invuln=0
		s.update_enemies(0.01)
		check(e.attack_time>0,"New enemy starts readable windup")
		check(p.hp==p.max_hp and s.bullets.is_empty(),"No instant damage")
		for i in 150: s.update_enemies(0.01)
		if kind in [5,6,9]:
			check(s.bullets.size()==(8 if kind==9 else 3),"Expected distinct projectile pattern")
		else: check(p.hp<p.max_hp,"Charge or ground strike hits stationary target")
		# Move during windup: aimed attacks retain the original direction/point.
		e.p=Vector2(1120,1100)
		e.attack_time=0.0
		e.cd=0.0
		p.p=Vector2(1300,1100)
		p.hp=p.max_hp
		p.invuln=0
		s.bullets.clear()
		s.update_enemies(0.01)
		p.p+=Vector2(0,200)
		for i in 150: s.update_enemies(0.01)
		check(p.hp==p.max_hp,"Dodging telegraph avoids damage")
		e.attack_time=0.0
		e.cd=0.0
		p.p=Vector2(1300,1100)
		e.p=Vector2(1120,1100)
		s.bullets.clear()
		s.update_enemies(0.01)
		s.damage_enemy(e,1,1,Vector2.ZERO,0)
		for i in 120: s.update_enemies(0.01)
		check(s.bullets.is_empty() and p.hp==p.max_hp,"Hit interrupts pending attack")
		check(EnemyFrames.pose({"hp":1,"id":0,"type":kind,"attack_total":2.0,"attack_time":1.9},0)==4,"New atlas windup frame")
	var frames := EnemyFrames.new()
	for texture in frames.sheets:
		check(texture!=null and texture.get_size()==Vector2(1024,768),"Atlas loads with standard frame dimensions")
	s.queue_free()
	await process_frame
	print("ECOLOGY CHECKS: ",checks," failures: ",failures)
	quit(1 if failures else 0)
