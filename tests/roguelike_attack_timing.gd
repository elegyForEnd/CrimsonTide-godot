extends SceneTree
var checks := 0
var failures := 0
var now := 0.0
var starts: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func pack(seed_value: int, arrival: bool) -> Array:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,seed_value)
	s.enemies.clear()
	s.roguelike.combat.reset()
	var p: Dictionary=s.players[1]
	p.p=Vector2(650,575)
	p.invuln=1000
	for i in 8:
		s.roguelike.spawn_minion(s,Vector2(550,575),0,2,false)
		if arrival: s.enemies.back().cd=0.0
	var ids: Array=[]
	var opening: Array=[]
	var tempos: Array=[]
	for e in s.enemies:
		ids.append(e.id)
		opening.append(e.cd)
		tempos.append(e.attack_tempo)
	check(tempos.max()-tempos.min()>.08,"Same-species monsters have independent attack cadence")
	if not arrival: check(opening.max()-opening.min()>.3,"Opening cooldowns are individually staggered")
	starts=[]
	s.combat_event.connect(func(data):
		if data.kind=="rogue-minion" and data.action=="charge":
			starts.append({"index":ids.find(data.id),"time":now}))
	var same_step := false
	var last_count := 0
	for step in 1000:
		now=step*.02
		for e in s.enemies: s.roguelike.combat.update(s,e,.02)
		s.roguelike.combat.tick(s,.02)
		s.bullets.clear()
		if starts.size()-last_count>1: same_step=true
		last_count=starts.size()
	check(not same_step,"A whole pack cannot begin charging on the same tick")
	var first: Array=[]
	var second: Array=[]
	var counts: Array=[]
	counts.resize(8)
	counts.fill(0)
	for entry in starts:
		counts[entry.index]+=1
		if counts[entry.index]==1: first.append(entry.time)
		if counts[entry.index]==2: second.append(entry.time)
	check(counts.min()>=4,"Every monster keeps attacking; the start gap does not starve late actors")
	check(first.size()==8 and first.max()-first.min()>.7,"First attacks remain staggered after all approach cooldowns expire")
	check(second.size()==8 and second.max()-second.min()>.7,"The second round does not re-synchronize")
	var result: Array=starts.duplicate(true)
	s.queue_free()
	return result
func run() -> void:
	for seed_value in [1729,42,777,90210]:
		for arrival in [false,true]: pack(seed_value,arrival)
	var first := pack(1729,true)
	var repeated := pack(1729,true)
	check(first==repeated,"The same run seed reproduces the independent attack schedule")
	await process_frame
	await process_frame
	print("ROGUE ATTACK TIMING: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
