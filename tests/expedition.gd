extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void:
	call_deferred("run")
func boss(s: TideSession) -> Dictionary:
	for e in s.enemies:
		if e.get("raid_boss",false): return e
	return {}
func kill_boss(s: TideSession) -> void:
	boss(s).hp=0
	s.simulate(0.01)
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.spawn_timer=9999
	var p: Dictionary=s.players[1]
	check(s.raid.day==1 and s.raid.phase=="explore","First day starts in exploration")
	check(s.raid.kind==0,"Day one always fields the bishop")
	check(not s.can_extract(),"Day one extraction locked")
	p.p=s.ruins.exits[0]
	s.interact(p,true,5)
	check(p.status=="active","Cannot bypass day one extraction by standing in the exit")
	var first: Vector2=s.safe_center()
	for corner in [Vector2.ZERO,Ruins.SIZE,Vector2(6400,0),Vector2(0,4800)]:
		check(corner.distance_to(first)<s.safe_radius(),"Reset circle covers whole map")
	check(not s.ruins.blocked(first,30),"Random arena walkable")
	s.raid.time=s.SHRINK_START
	var radius := s.safe_radius()
	s.raid.time=s.duration-0.1
	check(s.safe_radius()<radius and boss(s).is_empty(),"Shrinks before boss appears")
	p.p=first+Vector2(130,0)
	p.invuln=100
	s.simulate(0.11)
	check(s.raid.phase=="boss" and not boss(s).is_empty(),"Dawn spawns boss instead of killing player")
	check(is_equal_approx(s.safe_radius(),540) and boss(s).p.distance_to(first)<1,"Boss spawns exactly at completed circle centre")
	var health: float=boss(s).max_hp
	var first_kind: int=int(s.raid.kind)
	check(int(boss(s).boss_kind)==first_kind,"The day one boss is the one the marker announced")
	s.simulate(0.1)
	var count := 0
	for e in s.enemies:
		if e.get("raid_boss",false): count+=1
	check(count==1,"Boss spawns once")
	kill_boss(s)
	check(s.raid.day==2 and s.raid.phase=="explore" and s.raid.time==0,"First boss starts day two and resets time")
	check(first_kind==0 and s.raid.kind==1,"Day two always follows the bishop with the hunter")
	check(s.safe_center().distance_to(first)>700 and s.safe_radius()>4000,"New centre and reset circle")
	check(s.can_extract(),"Day two extraction enabled")
	check(int(p.get("boss_reward",0))==150,"First reward awarded once")
	# Optional city must not be a way to bypass the closing circle.
	p.p=s.CITY_GATE
	check(s.travel_city(),"City available in early exploration")
	s.raid.time=s.SHRINK_START-0.01
	s.simulate(0.02)
	check(s.map_id=="border" and not s.can_travel(),"City returns party when shrinking starts")
	p.p=s.safe_center()+Vector2(130,0)
	s.raid.time=s.duration
	s.simulate(0.01)
	check(boss(s).max_hp>health,"Second boss is stronger")
	kill_boss(s)
	check(s.raid.phase=="choice" and s.raid.day==2,"Second victory waits for explicit choice")
	p.sanity=0
	var hp: float=p.hp
	s.simulate(10)
	check(p.hp==hp and s.raid.phase=="choice","Intermission is safe and does not auto advance")
	p.p=s.ruins.shrines[0].p
	s.interact(p,true,4)
	check(s.enemies.is_empty() and not s.ruins.shrines[0].done,"Intermission shrine cannot summon enemies")
	var ally := s.make_player(2,{"hero":1})
	s.players[2]=ally
	s.perform(1,"raid_choice",{"choice":"continue"})
	s.simulate(0.01)
	check(s.raid.phase=="choice","One player cannot force party into final day")
	s.perform(1,"raid_choice",{"choice":"wait"})
	check(not s.raid.choices.has(1),"Ready can be cancelled")
	s.perform(2,"raid_choice",{"choice":"extract"})
	check(ally.status=="extracted","Players can leave independently after second boss")
	s.perform(1,"raid_choice",{"choice":"continue"})
	s.simulate(0.01)
	check(s.raid.day==3 and s.raid.phase=="boss","Third day immediately starts final boss")
	check(ally.status=="extracted" and not s.can_extract(),"Extracted ally stays out and final battle locks exits")
	check(boss(s).max_hp==5500,"Boss scales with remaining participants")
	var queen := boss(s)
	for fraction in [1.0,0.55,0.25]:
		queen.hp=queen.max_hp*fraction
		queen.cd=0
		s.expedition.update_boss(s,queen,0.01)
	check(queen.phase==3 and s.raid.hazards.size()>0,"Queen has three phases and telegraphed attacks")
	# Test the exact shape used for both damage and drawing.
	var ring := {"shape":"ring","p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":300.0,"inner":100.0}
	check(not s.expedition.hazard_contains(ring,Vector2(50,0)) and s.expedition.hazard_contains(ring,Vector2(200,0)),"Ring leaves a safe centre")
	s.raid.hazards=[]
	p.p=s.safe_center()+Vector2(140,0)
	p.invuln=0
	s.expedition.hazard(s,"circle",p.p,Vector2.RIGHT,80,1.0,20)
	hp=p.hp
	s.expedition.update_hazards(s,0.9)
	check(p.hp==hp,"Telegraph deals no early damage")
	p.invuln=1
	s.expedition.update_hazards(s,0.11)
	check(p.hp==hp,"Dodge invulnerability counters boss damage")
	kill_boss(s)
	check(boss(s).get("final_form",false) and boss(s).max_hp==7600,"Queen defeat begins the final form")
	kill_boss(s)
	check(s.raid.phase=="complete" and s.can_extract(),"Final victory unlocks safe extraction")
	var final_reward: Dictionary=s.ruins.chests.back()
	check(final_reward.items.any(func(item): return str(item.kind)=="bloodmoon_nightwomb"),"Final reward contains its red 3x3 relic")
	check(final_reward.items.filter(func(item): return str(item.kind)=="relic").size()==4,"Final reward keeps four ordinary relics")
	check(final_reward.items.any(func(item): return str(item.kind)=="weapon") and final_reward.items.any(func(item): return str(item.kind)=="gear") and final_reward.items.any(func(item): return str(item.kind)=="backpack"),"Final reward keeps equipment and backpack")
	s.perform(1,"raid_choice",{"choice":"extract"})
	s.simulate(0.01)
	check(not s.running and s.results[1].escaped and s.results[2].escaped,"Party settles after independent extraction")
	check(s.results[1].shared==1100 and s.results[2].shared==0,"Boss rewards belong only to participants")
	var centres: Dictionary={}
	var kinds: Dictionary={}
	for seed in range(1,13):
		s.solo({"hero":0})
		s.launch(false,seed)
		centres[s.safe_center()]=true
		kinds[s.raid.kind]=true
		check(not s.ruins.blocked(s.safe_center(),30),"Seed %d arena clear" % seed)
		# Drive the run to day two and confirm the roster never repeats a dawn boss.
		var day_one: int=int(s.raid.kind)
		s.raid.time=s.duration
		s.simulate(0.01)
		var first_spawn: int=int(boss(s).boss_kind)
		p.p=s.safe_center()+Vector2(130,0)
		p.invuln=100
		kill_boss(s)
		check(int(s.raid.kind)!=day_one,"Seed %d day two fields the other dawn boss" % seed)
		s.raid.time=s.duration
		s.simulate(0.01)
		check(int(boss(s).boss_kind)!=first_spawn and int(boss(s).boss_kind)==int(s.raid.kind),"Seed %d day two spawns the boss its marker announced" % seed)
	check(centres.size()>1 and kinds.keys()==[0],"Seeds vary arena locations while day one always fields the bishop")
	print("EXPEDITION %d checks, %d failures" % [checks,failures])
	s.queue_free()
	quit(1 if failures else 0)
