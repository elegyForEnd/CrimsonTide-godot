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

func guardians(s: TideSession) -> Array:
	return s.enemies.filter(func(e: Dictionary): return e.get("mini_boss",false))

func raid_boss(s: TideSession) -> Dictionary:
	for e in s.enemies:
		if e.get("raid_boss",false): return e
	return {}

func reward_matches(s: TideSession, e: Dictionary) -> bool:
	var expected := 3 if str(e.boss_name) in [s.mini_bosses.NAMES[0],s.wild_bosses.NAMES[0]] else 4
	for chest in s.ruins.chests:
		if not str(chest.get("title","")).begins_with(str(e.boss_name)): continue
		if int(chest.get("reward_tier",-1))!=expected: return false
		for item in chest.items:
			if str(item.kind)=="weapon": return int(item.tier)==expected
	return false

func run() -> void:
	var seeds: Array=[]
	for n in 64: seeds.append(n+1)
	seeds.append(1729)
	var appeared: Dictionary={}
	for seed in seeds:
		var s := TideSession.new()
		root.add_child(s)
		s.solo({"hero":0})
		s.launch(false,seed)
		s.set_physics_process(false)
		s.spawn_timer=9999
		var roster: Array=guardians(s)
		check(roster.size()==3,"Seed %d selects exactly three map bosses" % seed)
		var weak := 0
		var strong := 0
		var habitats: Dictionary={}
		var identities: Dictionary={}
		for e in roster:
			check(not s.ruins.blocked(e.p,58),"Boss lair remains walkable after map expansion")
			check(e.p.distance_to(s.raid.center)>=1000,"World boss keeps clear of the dawn arena")
			for other in roster:
				if int(other.id)>int(e.id):
					check(e.p.distance_to(other.p)>=s.expedition.GUARDIAN_SPACING,"Seed %d separates world boss lairs" % seed)
			var name: String=str(e.boss_name)
			appeared[name]=true
			identities[name]=true
			habitats[int(e.habitat)]=true
			if name in [s.mini_bosses.NAMES[0],s.wild_bosses.NAMES[0]]:
				weak+=1
			else:
				strong+=1
			var expected: float=s.dragon_boss.HEALTH if e.get("dragon_boss",false) else s.wild_bosses.HEALTH[int(e.wild_kind)] if e.get("wild_boss",false) else s.mini_bosses.HEALTH[int(e.mini_kind)]
			check(is_equal_approx(float(e.max_hp),expected),"%s retains its individual health" % name)
		check(weak==1 and strong==2,"Seed %d selects one weak and two strong bosses" % seed)
		check(identities.size()==3 and habitats.size()==3,"Seed %d has distinct bosses and lairs" % seed)
		if seed==1729:
			var survivor: Dictionary=roster[2]
			var survivor_id: int=survivor.id
			var survivor_hp: float=survivor.max_hp
			for e in roster.slice(0,2): e.hp=0
			s.simulate(0.01)
			for e in roster.slice(0,2): check(reward_matches(s,e),"Day-one map boss reward follows its strength")
			check(s.raid.map_boss_defeats.size()==2,"Any two chosen map bosses count toward the hidden finale")
			s.expedition.prepare_day(s,2)
			var next_day: Array=guardians(s)
			check(next_day.size()==1 and int(next_day[0].id)==survivor_id and is_equal_approx(float(next_day[0].max_hp),survivor_hp),"The surviving boss persists into day two without scaling or replacement")
			if next_day.size()==1:
				check(next_day[0].p.distance_to(s.raid.center)>=1000,"Day-two dawn arena avoids the surviving world boss")
				next_day[0].hp=0
				s.simulate(0.01)
				check(reward_matches(s,next_day[0]),"Day-two map boss reward keeps its own fixed quality")
			s.expedition.prepare_day(s,3)
			check(guardians(s).is_empty(),"Map bosses leave before the third-day arena")
			var queen: Dictionary=raid_boss(s)
			if not queen.is_empty():
				queen.hp=0
				s.simulate(0.01)
			var moon: Dictionary=raid_boss(s)
			if not moon.is_empty():
				moon.hp=0
				s.simulate(0.01)
			check(raid_boss(s).get("abyss_final",false),"Two selected map bosses can unlock the hidden final encounter")
		s.free()
	check(appeared.size()==5,"All five map bosses can appear across different seeds")
	print("MAP BOSS ROSTER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
