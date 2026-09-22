extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := TideSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({"hero":0})
	session.launch(false,1729)
	session.enemies.clear()
	session.ruins.walls.clear()
	session.spawn_timer=9999
	var p: Dictionary=session.players[1]
	p.p=Vector2(1350,1100)
	p.aim=Vector2.RIGHT
	session.inputs[1]={"aim":Vector2.RIGHT}
	for weapon in [1,2,3,0]:
		p.attack=0.0
		p.swing_time=0.0
		p.cast_time=0.0
		p.ammo=16
		p.hitstop=0.0
		session.perform(1,"weapon",{"index":weapon})
		check(p.weapon==weapon,"Weapon switch accepted")
		session.enemies.clear()
		session.bullets.clear()
		session.spawn_enemy(p.p+Vector2(80,0),2)
		var enemy: Dictionary=session.enemies[0]
		enemy.p=p.p+Vector2(80,0)
		enemy.hp=500.0
		enemy.max_hp=500.0
		session.attack(p)
		session.perform(1,"weapon",{"index":(weapon+1)%4})
		check(p.weapon==weapon,"Cannot bypass recovery by switching weapon")
		if weapon>0:
			check(enemy.hp==500 and session.bullets.is_empty(),"Windup does not cause premature damage")
			for i in ceili(float(Catalog.WEAPONS[weapon].windup)/0.01)+1:
				session.simulate(0.01)
		if weapon in [1,2]:
			check(enemy.hp<500,"Melee connects on active frame")
			check(enemy.p.x>p.p.x+80,"Melee knocks enemy back")
			check(p.hitstop>0,"Hitstop applied only on contact")
		else:
			check(session.bullets.size()==1,"Ranged strike spawns one projectile")
			for i in 10:
				session.update_bullets(0.01)
			check(enemy.hp<500,"Swept projectile hits target")
		var hp_after: float=enemy.hp
		session.attack(p)
		check(enemy.hp==hp_after,"No repeat damage during recovery")
	p.attack=0.0
	p.swing_time=0.0
	p.hitstop=0.0
	session.perform(1,"weapon",{"index":1})
	session.enemies.clear()
	session.spawn_enemy(Vector2(2000,1100),2)
	var blocked_enemy: Dictionary=session.enemies[0]
	blocked_enemy.p=p.p+Vector2(75,0)
	blocked_enemy.hp=500.0
	session.ruins.walls.append(Rect2(p.p+Vector2(32,-35),Vector2(18,70)))
	session.attack(p)
	session.release_strike(p)
	check(blocked_enemy.hp==500,"Melee cannot hit through wall")
	session.ruins.walls.clear()
	blocked_enemy.p=p.p-Vector2(75,0)
	session.release_strike(p)
	check(blocked_enemy.hp==500,"Melee excludes enemy behind player")
	var old_weapon: int=p.weapon
	session.perform(1,"weapon",{"index":99})
	check(p.weapon==old_weapon,"Invalid weapon index rejected")
	session.perform(1,"skill")
	check(not p.pending_strike and p.swing_time==0,"Skill cancels pending basic attack")
	p.cast_time=0.0
	p.attack=0.0
	session.perform(1,"weapon",{"index":2})
	session.attack(p)
	session.down(p)
	check(not p.pending_strike and p.swing_time==0,"Downing cancels pending strike")
	print("COMBAT TESTS: %d checks, %d failures" % [checks,failures])
	session.queue_free()
	quit(1 if failures else 0)
