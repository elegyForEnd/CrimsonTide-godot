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

# Puts a field weapon in hand the only way the game allows: the loot goes into
# the backpack first and is then equipped through the authoritative session.
func equip_weapon(session: TideSession, p: Dictionary, index: int, tier: int = 0) -> bool:
	if not Catalog.place_item(p.backpack,Catalog.make_equipment("weapon",index,tier)):
		return false
	# place_item appends, so the newest entry is the one just laid down.
	return session.equip_item(p,"backpack",p.backpack.items.size()-1)

func run() -> void:
	var session := TideSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({"hero":0})
	session.launch(false,1729)
	session.enemies.clear()
	# Use an isolated sparring room: damage locks border habitats against respawn.
	session.map_id="city"
	session.ruins=RoyalCity.new()
	session.ruins.generate(1729)
	session.ruins.walls.clear()
	session.spawn_timer=9999
	var p: Dictionary=session.players[1]
	# A wide backpack keeps every swap in the loop below from filling up.
	var satchel := Catalog.make_bag("red")
	satchel["gw"]=Catalog.tier("red").grid.x
	satchel["gh"]=Catalog.tier("red").grid.y
	p["backpack"]=satchel
	p.p=Vector2(1350,1100)
	p.aim=Vector2.RIGHT
	session.inputs[1]={"aim":Vector2.RIGHT}
	# --- every hero sets out with its own temporary weapon -------------------
	for hero in 3:
		var fresh: Dictionary=session.make_player(2,{"hero":hero})
		check(int(fresh.weapon)==Catalog.starter_index(hero),"Hero %d starts with its own issue weapon" % hero)
		check(Catalog.is_starter(int(fresh.weapon)),"The starting weapon is an issue weapon, not field loot")
		check(not session.weapon_kit_active(fresh),"No looted weapon is worn at the start")
		check(session.issue_weapon_active(fresh),"The issue weapon is what is in hand")
	check(Catalog.weapon(Catalog.starter_index(0)).name=="黑铁短剑","绯月 issues the black iron shortsword")
	check(Catalog.weapon(Catalog.starter_index(1)).name=="祭祀短杖","雪璃 issues the sacrificial short staff")
	check(Catalog.weapon(Catalog.starter_index(2)).name=="破碎大剑","鸦羽 issues the broken greatsword")
	# An issue weapon imitates a field weapon without ever becoming one, and it is
	# strictly weaker than the field weapon whose art and effects it borrows.
	for hero in 3:
		var issue: Dictionary=Catalog.weapon(Catalog.starter_index(hero))
		var field: Dictionary=Catalog.WEAPONS[int(issue.family)]
		check(float(issue.damage)<float(field.damage),"Issue weapon %s hits softer than %s" % [issue.name,field.name])
		check(float(issue.reach)<=float(field.reach),"Issue weapon %s has no more reach than %s" % [issue.name,field.name])
		check(Catalog.weapon_family(Catalog.starter_index(hero))==int(issue.family),"An issue weapon reports its family")
	# --- the removed hotkey no longer chooses a weapon -----------------------
	p.attack=0.0
	p.swing_time=0.0
	p.cast_time=0.0
	p.hitstop=0.0
	session.enemies.clear()
	session.spawn_enemy(p.p+Vector2(60,0),2)
	var sparring: Dictionary=session.enemies[0]
	sparring.p=p.p+Vector2(60,0)
	sparring.hp=500.0
	sparring.max_hp=500.0
	session.attack(p)
	var issue_weapon: int=int(p.weapon)
	for index in Catalog.WEAPONS.size():
		session.perform(1,"weapon",{"index":index})
	check(int(p.weapon)==issue_weapon,"No weapon hotkey can change what is in hand")
	check(session.issue_weapon_active(p),"The temporary weapon is still the one in hand")
	if Catalog.weapon(issue_weapon).windup>0:
		for i in ceili(float(Catalog.weapon(issue_weapon).windup)/0.01)+1:
			session.simulate(0.01)
	check(sparring.hp<500.0,"The temporary weapon still connects")
	check(500.0-sparring.hp<Catalog.WEAPONS[1].damage,"The temporary weapon hits softer than the field sword")
	# --- a looted weapon is the only way to change what is in hand -----------
	p.attack=0.0
	p.swing_time=0.0
	p.cast_time=0.0
	p.hitstop=0.0
	session.enemies.clear()
	session.bullets.clear()
	check(equip_weapon(session,p,2),"A looted greatsword can be equipped")
	check(int(p.weapon)==2,"Equipping a looted weapon puts it in hand")
	check(session.weapon_kit_active(p),"The worn weapon is active")
	check(not session.issue_weapon_active(p),"The temporary weapon is set aside")
	check(equip_weapon(session,p,0),"A looted rifle can be equipped over it")
	check(int(p.weapon)==0 and session.weapon_kit_active(p),"The weapon in hand follows the equip")
	# --- attack behaviour of the four field weapons --------------------------
	for weapon in [1,2,3,0]:
		p.attack=0.0
		p.swing_time=0.0
		p.cast_time=0.0
		p.ammo=16
		p.hitstop=0.0
		p.combo_timeout=0.0
		p.combo=0
		check(equip_weapon(session,p,weapon),"Looted weapon %d reaches the weapon slot" % weapon)
		check(int(p.weapon)==weapon,"Weapon %d is in hand" % weapon)
		session.enemies.clear()
		session.bullets.clear()
		session.spawn_enemy(p.p+Vector2(80,0),2)
		var enemy: Dictionary=session.enemies[0]
		enemy.p=p.p+Vector2(80,0)
		enemy.hp=500.0
		enemy.max_hp=500.0
		session.attack(p)
		session.perform(1,"weapon",{"index":(weapon+1)%4})
		check(int(p.weapon)==weapon,"The removed hotkey cannot bypass recovery either")
		if Catalog.weapon(weapon).windup>0:
			check(enemy.hp==500 and session.bullets.is_empty(),"Windup does not cause premature damage")
			for i in ceili(float(Catalog.weapon(weapon).windup)/0.01)+1:
				session.simulate(0.01)
		if weapon in [1,2]:
			check(enemy.hp<500,"Melee connects on active frame")
			check(enemy.p.x>p.p.x+80,"Melee knocks enemy back")
			check(p.hitstop>0,"Hitstop applied only on contact")
		else:
			check(session.bullets.size()==1 or enemy.hp<500,"Ranged strike spawns a projectile or hits during windup simulation (weapon %d)" % weapon)
			for i in 10:
				session.update_bullets(0.01)
			check(enemy.hp<500,"Swept projectile hits target")
		var hp_after: float=enemy.hp
		session.attack(p)
		check(enemy.hp==hp_after,"No repeat damage during recovery")
	# The temporary staff is a ranged weapon with a chant before it releases.
	var caster: Dictionary=session.make_player(3,{"hero":1})
	session.players[3]=caster
	caster.p=p.p
	caster.aim=Vector2.RIGHT
	session.enemies.clear()
	session.bullets.clear()
	session.spawn_enemy(p.p+Vector2(100,0),2)
	var target: Dictionary=session.enemies[0]
	# Keep the body beyond the first projectile step, so this checks release
	# separately from contact with the new upright hurtbox.
	target.p=p.p+Vector2(180,0)
	target.stagger=2.0
	target.hp=500.0
	target.max_hp=500.0
	session.attack(caster)
	check(caster.pending_strike,"The issue staff chants before it releases")
	check(session.bullets.is_empty(),"Nothing leaves the staff during the chant")
	check(target.hp==500,"The chant itself deals no damage")
	for i in ceili(float(Catalog.weapon(caster.weapon).windup)/0.01)+1:
		session.simulate(0.01)
	check(session.bullets.size()==1,"The chant ends in one magic projectile")
	for i in 20:
		session.update_bullets(0.01)
	check(target.hp<500,"The magic projectile connects at range")
	session.players.erase(3)
	# --- walls, facing and cancellation --------------------------------------
	p.attack=0.0
	p.swing_time=0.0
	p.hitstop=0.0
	check(equip_weapon(session,p,1),"A looted sword is back in hand")
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
	check(int(p.weapon)==old_weapon,"An out-of-range weapon action is inert")
	# --- the report no longer advertises a weapon nobody looted --------------
	var bare: Dictionary=session.make_player(4,{"hero":2})
	check(session.worn_names(bare).is_empty(),"An unarmed run reports no worn loot")
	check(session.equipment_damage(bare)==0.0,"The issue weapon grants no quality bonus")
	session.perform(1,"skill")
	check(not p.pending_strike and p.swing_time==0,"Skill cancels pending basic attack")
	p.cast_time=0.0
	p.attack=0.0
	session.attack(p)
	session.down(p)
	check(not p.pending_strike and p.swing_time==0,"Downing cancels pending strike")
	check(session.issue_weapon_active(p),"Going down returns the temporary weapon to hand")
	check(session.kit_weapon(p).is_empty(),"Going down scatters the looted weapon")
	print("COMBAT TESTS: %d checks, %d failures" % [checks,failures])
	session.queue_free()
	quit(1 if failures else 0)
