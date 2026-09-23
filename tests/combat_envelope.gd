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

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0,"gear":0,"talents":[3,0,0]})
	s.launch(false,1234)
	s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	p.equipped.gear[0]=Catalog.make_equipment("gear",0,3)
	s.refresh_max_hp(p)
	check(is_equal_approx(p.max_hp,208.0),"A purple defensive build has 208 health")
	check(is_equal_approx(s.stat_defense(p),0.14),"Camp armour and purple field armour reduce hits by 14 percent")
	p.invuln=0
	var before: float=p.hp
	s.hurt(p,42.0*Ecology.DAMAGE_SCALE[3])
	check(is_equal_approx(before-p.hp,57.0696),"Difficulty-four coffin strike uses one area multiplier and armour mitigation")
	check(ceili(p.max_hp/s.incoming_damage(p,42.0*Ecology.DAMAGE_SCALE[3]))==4,"Purple armour survives three coffin strikes")
	check(ceili(p.max_hp/s.incoming_damage(p,Ecology.ATTACK_DAMAGE[0]*Ecology.DAMAGE_SCALE[3]))>=10,"A small monster cannot burst down a defensive build")
	check(ceili(p.max_hp/s.incoming_damage(p,Ecology.ATTACK_DAMAGE[13]*Ecology.DAMAGE_SCALE[3]))==5,"An executioner remains dangerous below the largest elite")
	for tier in 6:
		p.equipped.gear[0]=Catalog.make_equipment("gear",0,tier)
		s.refresh_max_hp(p)
		check(is_equal_approx(s.stat_defense(p),0.05+Catalog.GEAR_DEFENSE[tier]),"Each armour quality has its declared reduction")
	p.equipped.gear[0]={}
	p.gear=1
	s.refresh_max_hp(p)
	check(is_zero_approx(s.stat_defense(p)),"An offensive camp build has no hidden defence")
	check(is_equal_approx(s.incoming_damage(p,40),40),"Unarmoured combat damage is unchanged")
	# Monster health and contact damage move through the four danger bands, while
	# large elites get their own multiplayer survival budget.
	for kind in 17:
		if kind==4: continue
		check(Ecology.HEALTH[kind]>0 and Ecology.ATTACK_DAMAGE[kind]>0,"Each resident has positive health and attack damage")
		for tier in 3:
			check(Ecology.HEALTH_SCALE[tier+1]>Ecology.HEALTH_SCALE[tier] and Ecology.DAMAGE_SCALE[tier+1]>Ecology.DAMAGE_SCALE[tier],"Danger bands grow monotonically")
	check(is_equal_approx(Ecology.HEALTH[16]*Ecology.HEALTH_SCALE[3],1870),"The final-zone coffin guard lasts several high-tier attacks")
	for kind in [14,15,16]:
		var standstill_ttk: float=Ecology.HEALTH[kind]*Ecology.HEALTH_SCALE[3]/220.0
		check(standstill_ttk>=6.0 and standstill_ttk<=9.0,"Each large elite occupies a six-to-nine-second solo damage budget")
	check(is_equal_approx(Ecology.HEALTH[16]*Ecology.HEALTH_SCALE[3]*(1+0.55*3),4955.5),"Four-player elite health uses the elite coefficient")
	check(is_equal_approx(s.expedition.HEALTH[2]*(1+s.expedition.PARTY_HEALTH_BONUS*3),18700),"Four-player queen has the planned phase budget")
	var day_one_ttk: float=s.expedition.HEALTH[0]/(130.0*0.5)
	var day_two_ttk: float=s.expedition.HEALTH[1]/(185.0*0.5)
	var queen_ttk: float=s.expedition.HEALTH[2]/(294.0*0.5)
	check(day_one_ttk>=20.0 and day_one_ttk<=26.0,"First boss gives both phases room at green-weapon damage")
	check(day_two_ttk>=26.0 and day_two_ttk<=34.0,"Second boss gives both phases room at purple-weapon damage")
	check(queen_ttk>=28.0 and queen_ttk<=38.0,"Queen gives three phases room at red-weapon damage")
	# Skills grow at a slower rate than weapons: the offensive ultimate gains half
	# of quality's damage bonus; healing responds to the ally's max health.
	s.solo({"hero":1,"gear":0,"talents":[5,0,0]})
	s.launch(false,1234)
	p=s.players[1]
	p.equipped.gear[0]=Catalog.make_equipment("gear",0,5)
	s.refresh_max_hp(p)
	p.hp=p.max_hp-100
	s.pending_ultimates[1]={"remaining":0.0,"aim":Vector2.RIGHT}
	s.release_ultimate(1)
	check(is_equal_approx(p.hp,p.max_hp-32.05),"Fully grown healer restores 67.95 health")
	s.solo({"hero":0,"gear":1,"talents":[0,0,0]})
	s.launch(false,1234)
	p=s.players[1]
	p.weapon=1
	p.equipped.weapon=Catalog.make_equipment("weapon",1,5)
	s.enemies.clear()
	s.spawn_enemy(p.p+Vector2(80,0),2)
	var target: Dictionary=s.enemies.back()
	target.p=p.p+Vector2(80,0)
	target.hp=1000
	target.max_hp=1000
	s.pending_ultimates[1]={"remaining":0.0,"aim":Vector2.RIGHT}
	s.release_ultimate(1)
	check(is_equal_approx(1000.0-target.hp,156.4),"Red weapon grants half its quality bonus to offensive ultimate")
	s.queue_free()
	print("COMBAT ENVELOPE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
