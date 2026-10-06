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
	var profile := Profile.new()
	profile.path="user://attributes-test.json"
	profile.apply_data({"version":1,"xp":360.0,"talents":[2,1,0]})
	check(profile.attribute_points()==7,"Old saves earn initial and level points, keeping talents")
	check(profile.raise_attribute("vigor") and profile.data.attributes.vigor==11,"Allocation succeeds and persists")
	var loaded := Profile.new()
	loaded.path=profile.path
	loaded.load_profile()
	check(loaded.data.attributes.vigor==11 and loaded.data.talents==[2,1,0],"Attributes and old talents survive JSON")
	check(not profile.raise_attribute("unknown"),"Unknown attributes are refused")
	profile.apply_data({"version":1,"xp":0.0,"attributes":{"vigor":99,"mind":"bad","strength":999}})
	check(WatcherAttributes.spent(profile.data.attributes)==5 and profile.data.attributes.mind==10,"Malformed or overspent save is repaired to its budget")
	for i in 6: profile.raise_attribute("arcane")
	check(profile.attribute_points()==0 and not profile.raise_attribute("vigor"),"No allocation beyond budget")
	DirAccess.remove_absolute(profile.path)
	check(WatcherAttributes.growth(41)-WatcherAttributes.growth(40)==0.5,"First soft cap halves marginal gains")
	check(is_equal_approx(WatcherAttributes.growth(71)-WatcherAttributes.growth(70),0.2),"Second soft cap reduces marginal gains")
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	# The camp issue gear has to be bought, so a spawn config names the piece it wants;
	# this test is about the attributes, and wears the armour that used to be the
	# default so its arithmetic keeps testing what it was written for.
	s.solo({"hero":0,"gear":0,"attributes":{"vigor":20,"mind":20,"endurance":20,"strength":30,"arcane":30}})
	s.launch(false,1729)
	s.map_id="city"
	s.ruins=RoyalCity.new()
	s.ruins.generate(1729)
	s.ruins.walls.clear()
	s.enemies.clear()
	s.spawn_timer=9999
	var p: Dictionary=s.players[1]
	p.p=Vector2(1300,1100)
	p.aim=Vector2.RIGHT
	check(p.attributes.strength==30 and p.max_hp==210 and p.max_mana==120,"Attributes survive launch and set both resource ceilings")
	check(not p.has("stamina"),"Endurance introduces no stamina resource")
	check(is_equal_approx(s.stat_resistance(p),0.05),"Endurance supplies resistance")
	check(is_equal_approx(s.incoming_damage(p,100),90.25),"Armour and endurance stack multiplicatively")
	check(s.stat_discovery(p)==140,"Arcane raises discovery")
	s.spawn_enemy(p.p+Vector2(70,0),0)
	var e: Dictionary=s.enemies.back()
	e.last=1
	check(is_equal_approx(s.enemy_drop_chance(e),minf(1.0,Ecology.drop_chance(e)*1.4)),"Actual kill drop chance uses the killer's discovery")
	e.last=99
	check(is_equal_approx(s.enemy_drop_chance(e),Ecology.drop_chance(e)),"Unattributed kill uses baseline discovery")
	p.weapon=14
	check(s.weapon_damage(p)>Catalog.weapon(14).damage,"Strength improves greatsword damage")
	p.weapon=8
	check(is_equal_approx(s.weapon_damage(p),Catalog.weapon(8).damage),"Strength does not improve pure intelligence staff")
	p.attributes.intelligence=30
	check(s.weapon_damage(p)>Catalog.weapon(8).damage,"Intelligence improves its matching staff")
	p.weapon=1
	check(is_equal_approx(s.weapon_damage(p,14,5),Catalog.weapon(14).damage*(1+s.weapon_scaling(p,14))*1.72),"Preview calculates the selected weapon quality and scaling")
	p.mana=0.0
	p.weapon=3
	s.attack(p)
	check(not p.pending_strike and p.attack==0,"No mana refuses ordinary spell without starting recovery")
	s.perform(1,"skill")
	check(p.skill==0 and not s.pending_ultimates.has(1),"No mana refuses Q without starting CG/cooldown")
	p.mana=35
	p.cast_time=0
	p.swing_time=0
	s.perform(1,"skill")
	check(p.mana==5 and s.pending_ultimates.has(1),"Q charges mana once at acceptance")
	s.perform(1,"skill")
	check(p.mana==5,"Repeated Q cannot charge twice")
	s.cancel_ultimate(1)
	p.mana=0
	p.mana_delay=1.5
	s.recover_mana(p,1.0)
	check(p.mana==0,"Regeneration waits for its delay")
	s.recover_mana(p,1.0)
	check(is_equal_approx(p.mana,3.6),"Long frame regenerates only the time after the delay")
	p.status="down"
	s.recover_mana(p,2.0)
	check(is_equal_approx(p.mana,3.6),"Downed characters do not regenerate mana")
	p.status="active"
	check(WeaponArts.MOVES.size()==Catalog.WEAPONS.size()+Catalog.STARTER_WEAPONS.size(),"Every field and starter weapon has a combat art")
	var names: Array[String] = []
	for index in WeaponArts.MOVES.size():
		var move := WeaponArts.of(index)
		check(str(move.name) not in names,"Weapon art %d has its own name" % index)
		names.append(str(move.name))
		check(Catalog.weapon(index).scaling.size()==4,"Weapon %d specifies all scaling grades" % index)
		p.weapon=index
		p.mana=0
		p.art_cd=0
		p.cast_time=0
		p.swing_time=0
		p.attack=0
		p.reload=0
		s.bullets.clear()
		s.enemies.clear()
		check(not s.release_weapon_art(p) and p.art_cd==0,"Art %d refuses insufficient mana" % index)
		s.spawn_enemy(p.p+Vector2(float(move.reach) if move.kind=="burst" else 65.0,0),2)
		e=s.enemies.back()
		e.hp=10000
		e.max_hp=10000
		p.mana=p.max_mana
		var ammo_before := int(p.ammo)
		check(s.release_weapon_art(p),"Art %d releases" % index)
		check(is_equal_approx(p.mana,p.max_mana-float(move.mana)),"Art %d charges its precise mana cost" % index)
		check(p.art_cd==float(move.cooldown) and not s.release_weapon_art(p),"Art %d cannot bypass cooldown" % index)
		check(p.ammo==ammo_before,"Art %d consumes blue mana, not ammunition" % index)
		if move.kind=="volley":
			check(s.bullets.size()==int(move.count),"Art %d has its specified projectile count" % index)
			for step in 100: s.update_bullets(0.01)
		check(e.hp<10000,"Art %d damages an in-range target" % index)
	# Ordinary melee remains usable at zero mana; walls block direct art damage.
	p.weapon=1
	p.mana=0
	p.cast_time=0
	p.swing_time=0
	p.attack=0
	s.attack(p)
	check(p.pending_strike,"Melee attacks still work with an empty blue bar")
	p.pending_strike=false
	p.swing_time=0
	p.weapon=12
	p.art_cd=0
	p.cast_time=0
	p.mana=p.max_mana
	s.enemies.clear()
	s.spawn_enemy(p.p+Vector2(140,0),2)
	e=s.enemies.back()
	e.hp=10000
	s.ruins.walls.append(Rect2(p.p+Vector2(70,-80),Vector2(30,160)))
	s.release_weapon_art(p)
	check(e.hp==10000,"Combat art cannot damage through a solid wall")
	s.queue_free()
	await process_frame
	print("ATTRIBUTES AND ARTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
