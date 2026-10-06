extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var session := TideSession.new()
	root.add_child(session)
	session.solo({"hero":0})
	session.launch(false,1729)
	session.set_physics_process(false)
	session.ruins.walls.clear()
	var p: Dictionary=session.players[1]
	p.p=Vector2(1300,1100)
	for kind in 4:
		session.enemies.clear()
		session.bullets.clear()
		# Every round needs its arena free again: the launch scattered ambient
		# residents, and the previous round marked the habitat as held. `spawn_enemy()`
		# refuses a held habitat by returning nothing, which used to leave this test
		# crashing on an empty `enemies` list instead of testing enemy attacks.
		for site in session.ruins.sites:
			site["engaged"]=false
			site["cleared"]=false
		p.hp=p.max_hp
		p.invuln=0.0
		session.spawn_enemy(Vector2(1800,1100),kind)
		var e: Dictionary=session.enemies[0]
		e.p=p.p+Vector2(36 if kind!=1 else 180,0)
		session.update_enemies(0.01)
		check(e.attack_time>0,"Attack enters windup")
		check(p.hp==p.max_hp and session.bullets.is_empty(),"No damage before contact")
		for i in 60:
			session.update_enemies(0.01)
		check(session.bullets.size()==1 if kind==1 else p.hp<p.max_hp,"Contact releases damage or projectile")
		check(EnemyFrames.pose({"hp":1,"id":0,"type":kind,"stagger":0.1},0)==10,"Hurt pose takes precedence")
		# Windup can be interrupted without a delayed invisible hit.
		e.attack_time=0.0
		e.cd=0.0
		session.bullets.clear()
		p.hp=p.max_hp
		p.invuln=0.0
		session.update_enemies(0.01)
		session.damage_enemy(e,1,1,Vector2.ZERO,0)
		session.update_enemies(0.02)
		check(e.attack_time==0 and session.bullets.is_empty() and p.hp==p.max_hp,"Stagger cancels windup")
		# A melee target that dodges out is not hit at the old location.
		if kind!=1:
			e.stagger=0.0
			e.cd=0.0
			session.update_enemies(0.01)
			p.p+=Vector2(150,0)
			for i in 60:
				session.update_enemies(0.01)
			check(p.hp==p.max_hp,"Melee respects dodged range at contact")
			p.p=Vector2(1300,1100)
	print("ENEMY CHECKS: ",checks," failures: ",failures)
	quit(1 if failures else 0)
