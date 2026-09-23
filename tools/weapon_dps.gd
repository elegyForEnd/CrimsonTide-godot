extends SceneTree

# Run with: Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/weapon_dps.gd
# A stationary, high-health dummy measures the actual attack, reload, projectile,
# combo and hitstop paths. Ranged weapons fire at 350 units, melee at 75 units.
const SECONDS := 60.0
const STEP := 1.0 / 120.0
const DPS_MIN := [80.0,93.0,107.0,126.0,150.0,180.0]
const DPS_MAX := [106.0,120.0,140.0,164.0,197.0,242.0]

func _initialize() -> void:
	call_deferred("run")

func measure(index: int, tier: int, distance: float, group: bool = false, build: Dictionary = {}) -> float:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,31877)
	s.set_physics_process(false)
	s.map_id="city"
	s.ruins=RoyalCity.new()
	s.ruins.generate(31877)
	s.ruins.walls.clear()
	var p: Dictionary=s.players[1]
	p.p=Vector2(1350,1100)
	p.aim=Vector2.RIGHT
	p.weapon=index
	p.equipped={"weapon":{} if Catalog.is_starter(index) else Catalog.make_equipment("weapon",index,tier),"gear":[{},{},{}],"charm":[{},{}]}
	p.gear=int(build.get("camp",0))
	p.talents=[0,int(build.get("fire",0)),0]
	var sight_tier := int(build.get("sight",-1))
	if sight_tier>=0: p.equipped.gear[1]=Catalog.make_equipment("gear",1,sight_tier)
	for i in mini(2,int(build.get("charms",0))): p.equipped.charm[i]={"kind":"charm"}
	p.ammo=16
	p.reserve=10000
	p.attack=0.0
	p.swing_time=0.0
	p.hitstop=0.0
	p.combo=0
	p.combo_timeout=0.0
	p.reload=0.0
	var positions: Array[Vector2]=[p.p+Vector2(distance,0)]
	if group:
		if Catalog.weapon_family(index) in [1,2]:
			positions=[p.p+Vector2(75,0),p.p+Vector2(85,20),p.p+Vector2(85,-20)]
		elif str(Catalog.weapon(index).get("spell",""))=="scatter":
			positions=[p.p+Vector2(220,0),p.p+Vector2(220,33),p.p+Vector2(220,-33)]
		else:
			positions=[p.p+Vector2(220,0),p.p+Vector2(270,0),p.p+Vector2(320,0)]
	s.enemies=[]
	for i in positions.size():
		s.enemies.append({"id":999+i,"p":positions[i],"type":2,"hp":100000000.0,"max_hp":100000000.0,"last":1,"flash":0.0,"attack_time":0.0,"stagger":0.0})
	var steps := roundi(SECONDS/STEP)
	for n in steps:
		for key in ["attack","combo_timeout"]:
			p[key]=maxf(0.0,float(p[key])-STEP)
		if p.hitstop>0:
			p.hitstop=maxf(0.0,p.hitstop-STEP)
		else:
			p.swing_time=maxf(0.0,p.swing_time-STEP)
			if p.pending_strike and p.swing_total-p.swing_time>=Catalog.weapon(p.weapon).windup:
				p.pending_strike=false
				s.release_strike(p)
		if p.reload>0:
			p.reload-=STEP
			if p.reload<=0:
				var count: int=mini(16-p.ammo,p.reserve)
				p.ammo+=count
				p.reserve-=count
		if p.attack<=0 and p.swing_time<=0 and p.reload<=0:
			s.attack(p)
		s.update_bullets(STEP)
		for i in s.enemies.size(): s.enemies[i].p=positions[i]
	var dealt := 0.0
	for dummy in s.enemies: dealt+=100000000.0-float(dummy.hp)
	s.queue_free()
	return dealt/SECONDS

func run() -> void:
	print("weapon\twhite\tgreen\tblue\tpurple\tgold\tred\tclose_white\tclose_red\tgroup_white\tgroup_red")
	var failures := 0
	for index in Catalog.WEAPONS.size():
		var family := Catalog.weapon_family(index)
		var standard := 75.0 if family in [1,2] else 350.0
		var values: Array=[]
		for tier in 6:
			var value := measure(index,tier,standard)
			values.append("%.1f" % value)
			if value<DPS_MIN[tier]-0.5 or value>DPS_MAX[tier]+0.5:
				push_error("%s tier %d is outside its standard single-target DPS band: %.1f" % [Catalog.weapon_name(index),tier,value])
				failures+=1
		var close_white := measure(index,0,75.0)
		var close_red := measure(index,5,75.0)
		var group_white := measure(index,0,standard,true)
		var group_red := measure(index,5,standard,true)
		print("%s\t%s\t%.1f\t%.1f\t%.1f\t%.1f" % [Catalog.weapon_name(index),"\t".join(values),close_white,close_red,group_white,group_red])
	for hero in Catalog.STARTER_WEAPONS.size():
		var index := Catalog.starter_index(hero)
		print("starter\t%s\t%.1f" % [Catalog.weapon_name(index),measure(index,0,75.0 if Catalog.weapon_family(index) in [1,2] else 350.0)])
	print("build\tday1_green\tday2_purple\tday3_red_attack\tday3_red_defense")
	for index in Catalog.WEAPONS.size():
		var standard := 75.0 if Catalog.weapon_family(index) in [1,2] else 350.0
		var day1 := measure(index,1,standard,false,{"fire":2,"charms":1,"camp":1})
		var day2 := measure(index,3,standard,false,{"fire":3,"charms":1,"camp":1,"sight":2})
		var day3 := measure(index,5,standard,false,{"fire":5,"charms":2,"camp":1,"sight":5})
		var defense := measure(index,5,standard,false,{"fire":5,"charms":2,"camp":0})
		print("%s\t%.1f\t%.1f\t%.1f\t%.1f" % [Catalog.weapon_name(index),day1,day2,day3,defense])
	print("DPS BANDS: %d failures" % failures)
	quit(1 if failures else 0)
