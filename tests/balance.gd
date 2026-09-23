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

func attack_output(s: TideSession, kind: int, scale: float) -> float:
	s.enemies.clear()
	s.bullets.clear()
	var p: Dictionary=s.players[1]
	p.hp=10000
	p.invuln=0
	p.status="active"
	s.spawn_enemy(Vector2(1400,610),kind)
	var e: Dictionary=s.enemies[0]
	e.damage_scale=scale
	p.p=e.p+Vector2(35 if kind in [0,2,3] else 120,0)
	for frame in 160: s.update_enemies(0.01)
	var result: float=10000-p.hp
	for b in s.bullets: result+=float(b.damage)
	return result

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	check(s.duration==300,"Every exploration day lasts five minutes")
	var full := s.safe_radius()
	s.raid.time=179.99
	check(s.can_travel() and is_equal_approx(s.safe_radius(),full),"No shrink before minute three")
	s.raid.time=180
	check(not s.can_travel() and is_equal_approx(s.safe_radius(),full),"Travel closes exactly at minute three")
	s.raid.time=240
	check(is_equal_approx(s.safe_radius(),(full+540)/2),"Circle reaches halfway at minute four")
	s.raid.time=299.99
	check(s.raid.phase=="explore","Exploration remains open before minute five")
	s.expedition.tick(s,0.01)
	check(s.raid.phase=="boss" and is_equal_approx(s.safe_radius(),540),"Minute five finishes shrinking and starts boss")
	s.launch(true,1729)
	check(s.duration==300,"Legacy long-run callers also use five minutes")
	var tiers := {}
	for e in s.enemies:
		# Bosses can survive the preceding phase or occupy a habitat, but do not
		# use the ordinary resident difficulty multiplier.
		if not e.has("difficulty") or not e.has("habitat"): continue
		var q := Ecology.difficulty(s.ruins.sites[e.habitat])
		tiers[q]=true
		check(e.difficulty==q and e.max_hp>=Ecology.HEALTH[e.type],"Resident receives its home difficulty")
		if q>1: check(e.max_hp>Ecology.HEALTH[e.type] and e.damage_scale>1,"Harder habitat strengthens both health and damage")
	check(tiers.size()==4,"Map contains all four difficulty bands")
	# The same seed and loot rolls must improve with difficulty, independent of bags.
	var previous_value := 0.0
	var previous_equipment := 0
	for q in range(1,5):
		s.rng.seed=24680
		var value := 0.0
		var equipment := 0
		var valid_quality := true
		for sample in 2000:
			var e := {"type":0,"difficulty":q}
			if s.rng.randf()>=Ecology.drop_chance(e): continue
			var item := s.enemy_loot(e)
			var bag := Catalog.make_bag("red")
			s.place_entry(bag,item)
			value+=Catalog.container_value(bag)
			if item.kind in ["weapon","gear"]:
				equipment+=1
				valid_quality=valid_quality and item.tier>=q-1
		check(valid_quality,"Equipment drops respect habitat quality floor")
		check(value>previous_value and equipment>previous_equipment,"Harder habitats improve expected loot and equipment frequency")
		previous_value=value
		previous_equipment=equipment
		print("BALANCE LOOT tier ",q,": value/kill ",value/2000.0," equipment/2000 ",equipment)
	# Exercise all actual melee, charge, ground, volley and returning-wave paths.
	s.ruins=RoyalCity.new()
	s.ruins.generate(1729)
	s.map_id="city"
	for kind in 17:
		var normal := attack_output(s,kind,1.0)
		var harder := attack_output(s,kind,1.5)
		check(normal>0 and is_equal_approx(harder,normal*1.5),"Attack delivery scales once for species %d" % kind)
	var p: Dictionary=s.players[1]
	s.ruins.walls.clear()
	s.raid.center=Vector2(1400,610)
	for kind in 3:
		for phase in (3 if kind==2 else 2):
			s.enemies.clear()
			s.raid.phase="explore"
			s.raid.day=3 if kind==2 else 2
			s.raid.kind=kind
			s.raid.hazards=[]
			s.expedition.spawn_boss(s)
			var e: Dictionary=s.enemies.back()
			e.hp=e.max_hp*[1.0,0.55,0.25][phase]
			e.cd=0
			p.p=s.raid.center+Vector2(220,0)
			p.invuln=999
			var walked := 0.0
			var stayed_inside := true
			for frame in 1800:
				var before: Vector2=e.p
				s.expedition.update_hazards(s,1.0/60)
				s.expedition.update_boss(s,e,1.0/60)
				walked+=e.p.distance_to(before)
				stayed_inside=stayed_inside and e.p.distance_to(s.raid.center)<=390.01 and not s.ruins.blocked(e.p,31)
			check(e.sequence>=11,"Boss attacks at least eleven times in thirty seconds")
			check(walked>150 and stayed_inside,"Boss repositions within arena collision boundaries")
			# Changing targets during a cast must not move its promised impact areas.
			e.attack_time=0
			e.cd=0
			s.raid.hazards=[]
			s.expedition.update_boss(s,e,0.01)
			var locked: Array=s.raid.hazards.duplicate(true)
			var origin: Vector2=e.p
			p.p+=Vector2(0,150)
			s.expedition.update_boss(s,e,0.2)
			check(e.p==origin and s.raid.hazards==locked,"Boss windup keeps advertised origin and direction")
			print("BALANCE BOSS kind ",kind," phase ",phase+1,": casts/30s ",e.sequence-1," movement ",roundi(walked))
	# Swept movement cannot tunnel through a pillar or escape the arena.
	var e: Dictionary=s.enemies.back()
	e.p=s.raid.center
	s.ruins.walls=[Rect2(1480,300,40,800)]
	s.expedition.move_boss(s,e,Vector2.RIGHT,234,1.0)
	check(e.p.x<1450 and not s.ruins.blocked(e.p,31),"Boss slide stops at wall even with a long frame")
	s.ruins.walls.clear()
	e.p=s.raid.center+Vector2(389,0)
	s.expedition.move_boss(s,e,Vector2.RIGHT,234,1.0)
	check(e.p.distance_to(s.raid.center)<=390.01,"Edge pursuit cannot leave boss arena")
	# Boss caches retain every guaranteed item, including the enlarged final reward.
	for day in range(1,4):
		s.raid.day=day
		s.raid.phase="boss"
		s.raid.kind=mini(2,day-1)
		s.expedition.victory(s)
		var chest: Dictionary=s.ruins.chests.back()
		check(s.container_units(chest)==day+8,"All boss supplies, relics, weapon, gear and bag fit")
		for item in chest.items:
			if item.kind in ["weapon","gear"]: check(item.tier==day+2,"Boss equipment improves each day")
	s.queue_free()
	print("BALANCE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
