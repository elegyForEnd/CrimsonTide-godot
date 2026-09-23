extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(reason)
func _initialize() -> void:
	call_deferred("run")
func reset_actor(s, kind: int) -> Dictionary:
	s.enemies.clear()
	s.bullets.clear()
	s.ruins.walls.clear()
	s.spawn_enemy(Vector2.ZERO,kind)
	var e: Dictionary=s.enemies[0]
	e.p=Vector2(1120,1100)
	var p: Dictionary=s.players[1]
	p.p=Vector2(1300,1100)
	p.hp=p.max_hp
	p.invuln=0.0
	s.update_enemies(0.01)
	return e
func advance(s, seconds: float, step: float=0.01) -> void:
	for i in roundi(seconds/step): s.update_enemies(step)
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	for kind in range(11,14):
		for sample in 20:
			s.enemies.clear()
			s.spawn_enemy(Vector2.ZERO,kind)
			check(s.enemies.size()==1 and Ecology.allowed(s.ruins,s.enemies[0].p,kind),"New species only spawns in its biome block")
		var e := reset_actor(s,kind)
		check(e.attack_time>0 and p.hp==p.max_hp and s.bullets.is_empty(),"Attack starts with harmless windup")
		advance(s,0.8)
		check(p.hp==p.max_hp and s.bullets.is_empty(),"No early hit or bolt")
		advance(s,0.7)
		check(s.bullets.size()==5 if kind==12 else p.hp<p.max_hp,"Dive, five returning waves, or cleaver sweep releases")
		e=reset_actor(s,kind)
		p.p+=Vector2(0,250)
		advance(s,1.5)
		check(p.hp==p.max_hp,"Locked attack can be dodged sideways")
		e=reset_actor(s,kind)
		s.damage_enemy(e,1,1,Vector2.ZERO,0)
		advance(s,1.5)
		check(p.hp==p.max_hp and s.bullets.is_empty(),"Stagger cancels pending new attack")
		e=reset_actor(s,kind)
		s.ruins.walls.append(Rect2(1200,1000,24,220))
		advance(s,1.5)
		check(p.hp==p.max_hp,"Late wall prevents melee or landing damage")
		if kind==11: check(e.p.x<1200,"Dive stops before wall")
		if kind==12:
			for i in 80: s.update_bullets(0.01)
			check(s.bullets.is_empty(),"Returning waves are consumed by walls")
	# The sweep is a sector, not a full circle around the executioner.
	var e := reset_actor(s,13)
	p.p=e.p-Vector2(50,0)
	advance(s,1.5)
	check(p.hp==p.max_hp,"Executioner leaves safe space behind")
	e=reset_actor(s,13)
	p.p=e.p+Vector2.RIGHT.rotated(1.15)*180
	advance(s,1.5)
	check(p.hp==p.max_hp,"Outside telegraphed cone is safe")
	e=reset_actor(s,13)
	p.p=e.p+Vector2.RIGHT.rotated(0.8)*180
	advance(s,1.5)
	check(is_equal_approx(p.hp,p.max_hp-Ecology.damage(e,32)),"Inside cone receives habitat-scaled sweep damage")
	# Flight displacement does not depend on the render/physics step size.
	e=reset_actor(s,11)
	advance(s,1.4)
	var fine: Vector2=e.p
	e=reset_actor(s,11)
	advance(s,1.4,0.05)
	check(e.p.distance_to(fine)<0.1,"Dive distance is stable at different frame rates")
	# Isolate one wave away from players to observe its outward and return legs.
	e=reset_actor(s,12)
	advance(s,1.1)
	var wave: Dictionary=s.bullets[2]
	s.bullets=[wave]
	p.p=Vector2(1300,1450)
	for i in 74: s.update_bullets(0.01)
	check(wave.v.x>0 and not wave.reversed,"Wave travels outward first")
	for i in 3: s.update_bullets(0.01)
	check(wave.v.x<0 and wave.reversed,"Wave reverses after readable outward leg")
	for i in 85: s.update_bullets(0.01)
	check(s.bullets.is_empty(),"Returning wave expires without accumulating")
	# Large elites occupy more space, resist light stagger and use oversized attacks.
	for kind in range(14,17):
		for sample in 12:
			s.enemies.clear()
			s.spawn_enemy(Vector2.ZERO,kind)
			check(s.enemies.size()==1 and Ecology.allowed(s.ruins,s.enemies[0].p,kind),"Large elite remains in its regional habitat")
		e=reset_actor(s,kind)
		if kind==14:
			p.p=e.p+Vector2(120,0)
			e.cd=0.0
			s.update_enemies(0.01)
		check(e.attack_time>0,"Large elite starts long telegraph")
		var pending: float=e.attack_time
		s.damage_enemy(e,1,1,Vector2.ZERO,16)
		check(e.attack_time>0 and e.attack_time<=pending,"Light hit does not stagger massive monster")
		advance(s,2.5)
		if kind==14: check(is_equal_approx(p.hp,p.max_hp-Ecology.damage(e,34)) and s.bullets.size()==12,"Colossus slam creates crystal ring")
		elif kind==15: check(s.bullets.size()==16,"Bell carcass creates sixteen-wave pulse")
		else: check(is_equal_approx(p.hp,p.max_hp-Ecology.damage(e,40)),"Coffin warden lands locked heavy smash")
		e=reset_actor(s,kind)
		if kind==14:
			p.p=e.p+Vector2(120,0)
			e.cd=0.0
			s.update_enemies(0.01)
		s.damage_enemy(e,150,1,Vector2.ZERO,16)
		check(e.attack_time==0 and e.stagger>0,"Breaking elite poise interrupts attack")
	s.queue_free()
	await process_frame
	print("NOCTURNE CHECKS: ",checks," failures: ",failures)
	quit(1 if failures else 0)
