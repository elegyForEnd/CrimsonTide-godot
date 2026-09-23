extends SceneTree
const T = preload("res://scripts/boss_tactics.gd")
var checks := 0
var failures := 0
var s: TideSession
var p: Dictionary

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func actor(kind: int) -> Dictionary:
	s.enemies.clear()
	s.raid.hazards=[]
	s.raid.center=Vector2(1400,610)
	p.p=Vector2(1540,610)
	p.status="active"
	p.hp=p.max_hp
	p.invuln=0
	p.swing_time=0
	p.reload=0
	p.dodge_time=0
	if kind<0:
		s.spawn_enemy(s.raid.center,4)
	else:
		s.raid.phase="explore"
		s.raid.kind=kind
		s.raid.day=3 if kind==2 else 2
		s.expedition.spawn_boss(s)
	var e: Dictionary=s.enemies.back()
	e.cd=0
	return e

func run() -> void:
	s=TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	s.map_id="city"
	s.ruins=RoyalCity.new()
	s.ruins.generate(1729)
	s.ruins.walls.clear()
	p=s.players[1]
	for kind in [-1,0,1,2]:
		var e := actor(kind)
		check(T.start_guard(e,Vector2.RIGHT)==(kind in [-1,1]),"Only armed defensive bosses can guard")
		if kind not in [-1,1]: continue
		var hp: float=e.hp
		s.damage_enemy(e,20,1,Vector2.LEFT,0,1)
		check(is_equal_approx(hp-e.hp,20),"Guard startup can be punished")
		T.update_guard(e,0.33)
		hp=e.hp
		s.damage_enemy(e,20,1,Vector2.LEFT,0,1)
		check(is_equal_approx(hp-e.hp,3) and e.counter_ready,"Frontal guard chips and queues counter")
		hp=e.hp
		s.damage_enemy(e,20,1,Vector2.RIGHT,0,1)
		check(is_equal_approx(hp-e.hp,20),"Rear attacks bypass guard")
		hp=e.hp
		s.damage_enemy(e,20,1,Vector2.LEFT,0,4)
		check(is_equal_approx(hp-e.hp,20),"Ultimate bypasses weapon guard")
		T.update_guard(e,1)
		check(T.response(s,e).get("kind","")=="counter","Blocked attack earns counter only after guard ends")
		e=actor(kind)
		T.start_guard(e,Vector2.RIGHT)
		T.update_guard(e,0.33)
		s.damage_enemy(e,88,1,Vector2.LEFT,58,2)
		check(e.guard_time==0 and e.stagger>=1.25 and not e.counter_ready,"Heavy attack breaks guard and cancels riposte")
		e=actor(kind)
		T.start_guard(e,Vector2.RIGHT)
		T.update_guard(e,2)
		check(T.response(s,e).is_empty(),"Baited guard does not automatically counter")
		check(not T.start_guard(e,Vector2.RIGHT),"Guard has a cooldown")
		e.guard_cd=0
		check(T.start_guard(e,Vector2.LEFT) and e.guard_time==T.GUARD_DURATION and e.guard_aim==Vector2.LEFT and e.guard_cd==7,"Repeated guard resets expired state and locks the new direction")
	# End-to-end observation: a visible windup gets a delayed guard, raw input does not.
	for kind in [-1,0,1,2]:
		var e := actor(kind)
		s.inputs[1]={"fire":true,"interact":true}
		T.tick(s,e,0.01)
		check(e.get("reaction",{}).is_empty(),"Raw buttons do not trigger reads")
		p.reload=1.3
		T.tick(s,e,0.01)
		check(T.response(s,e).is_empty(),"Observed reload has no instant reaction")
		T.tick(s,e,0.27)
		check(T.response(s,e).is_empty(),"Reaction waits the full delay")
		T.tick(s,e,0.02)
		var response := T.response(s,e)
		check(response.get("kind","")=="reload","Reload observation matures into pressure")
		p.reload=0
		T.tick(s,e,0.01)
		p.dodge_time=0.2
		T.tick(s,e,0.01)
		check(e.get("reaction",{}).is_empty(),"Read cooldown prevents every-action punishment")
		e=actor(kind)
		e.attack_time=1
		p.reload=1
		T.tick(s,e,0.3)
		check(e.get("reaction",{}).is_empty(),"Boss cannot cancel committed attacks to read")
		e=actor(kind)
		p.reload=1
		s.ruins.walls=[Rect2(1460,400,30,400)]
		T.tick(s,e,0.3)
		check(e.get("reaction",{}).is_empty(),"Boss cannot read through walls")
		s.ruins.walls.clear()
	for kind in [-1,1]:
		var e := actor(kind)
		p.swing_time=0.8
		p.strike_aim=Vector2.LEFT
		s.update_enemies(0.01)
		check(e.attack_time==0 and e.get("guard_time",0)==0,"Visible attack starts observation instead of instant block")
		s.update_enemies(0.29)
		check(e.get("guard_time",0)>0,"Observed attack triggers defensive stance")
		check(e.get("reaction",{}).is_empty() and e.guard_cd==7,"Reactive guard consumes pending reaction and starts cooldown")
		check(not T.blocks(e,Vector2.LEFT,1),"Reactive stance still has startup")
	# Every move uses the same locked hazards for graphics and authoritative damage.
	var pools := [["bell","marks","quick_bell","slow_bell","cross"],["spear","cleave","feint","fan","reap","counter"],["crown","lances","coronation","execution","eclipse"]]
	for kind in 3:
		for move in pools[kind]+["dodge","reload"]:
			var e := actor(kind)
			s.expedition.cast_boss(s,e,p,move,Vector2.RIGHT,p.p)
			check(not s.raid.hazards.is_empty() and e.attack_marks.front()>=0.5,"Every attack has a readable warning")
			check(e.attack_total>e.attack_marks.back() and e.cd>e.attack_total,"Final delayed hit leaves recovery")
			var saved: Array=s.raid.hazards.duplicate(true)
			p.p+=Vector2(0,180)
			s.expedition.update_boss(s,e,0.2)
			check(saved==s.raid.hazards,"Changing player position cannot retarget committed telegraphs")
			var h: Dictionary=s.raid.hazards[0].duplicate(true)
			s.raid.hazards=[h]
			p.p=h.p+(h.aim*100 if h.shape in ["cone","line"] else Vector2.RIGHT*(h.inner+20))
			var hp: float=p.hp
			s.expedition.update_hazards(s,h.total-0.01)
			check(p.hp==hp,"Move deals no early damage")
			s.expedition.update_hazards(s,0.02)
			check(p.hp<hp,"Move deals damage at advertised contact time")
	for move in T.KNIGHT_MOVES:
		var e := actor(-1)
		p.p=e.p+Vector2(100,0)
		s.start_knight_attack(e,move,Vector2.RIGHT)
		var mark: float=T.KNIGHT_MOVES[move].marks[0]
		s.update_knight(e,mark-0.01)
		check(p.hp==p.max_hp,"Knight move waits for contact")
		s.update_knight(e,0.02)
		check(p.hp<p.max_hp,"Knight new move contacts on time")
	var e := actor(-1)
	p.p=e.p+Vector2(100,0)
	s.start_knight_attack(e,"combo",Vector2.RIGHT)
	s.update_knight(e,1.2)
	p.invuln=0
	var hp: float=p.hp
	s.update_knight(e,0.7)
	check(p.hp==hp,"Third combo strike holds through the old contact time")
	s.update_knight(e,0.16)
	check(p.hp<hp,"Delayed third strike releases at 2.05 seconds")
	e=actor(1)
	p.dodge_time=0.2
	p.dodge_dir=Vector2.DOWN
	T.tick(s,e,0.01)
	var point: Vector2=e.reaction.point
	check(point.y>p.p.y,"Dodge response predicts the already-started dodge endpoint")
	p.p+=Vector2(200,0)
	p.dodge_time=0
	T.tick(s,e,0.3)
	check(T.response(s,e).point==point,"Observed dodge endpoint does not follow later movement")
	e=actor(1)
	p.reload=1
	T.tick(s,e,0.01)
	p.status="extracted"
	T.tick(s,e,0.3)
	check(e.reaction.is_empty(),"Leaving players cannot trigger stale reads")
	e=actor(1)
	T.start_guard(e,Vector2.RIGHT)
	T.update_guard(e,0.4)
	hp=e.hp
	s.bullets=[{"p":e.p+Vector2(60,0),"v":Vector2(-850,0),"damage":20.0,"owner":1,"weapon":0,"life":1.0}]
	s.update_bullets(0.05)
	check(is_equal_approx(hp-e.hp,3) and s.bullets.is_empty(),"Real projectile collision uses frontal guard once")
	s.queue_free()
	print("BOSS TACTICS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
