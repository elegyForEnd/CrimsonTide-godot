extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func target(s: TideSession, pos: Vector2) -> Dictionary:
	s.spawn_enemy(pos,2)
	var e: Dictionary=s.enemies.back()
	e.p=pos
	e.hp=1000.0
	e.max_hp=1000.0
	return e

func ready(p: Dictionary, index: int) -> void:
	p.weapon=index
	p.attack=0.0
	p.swing_time=0.0
	p.cast_time=0.0
	p.pending_strike=false
	p.hitstop=0.0
	p.reload=0.0
	p.aim=Vector2.RIGHT
	p.status="active"

func fire(s: TideSession, p: Dictionary) -> void:
	s.attack(p)
	check(p.pending_strike,"Spell waits for its contact frame")
	for step in ceili(float(Catalog.weapon(p.weapon).windup)/0.01)+1:
		s.simulate(0.01)
	check(not p.pending_strike,"Spell releases after its windup")

func travel(s: TideSession, seconds: float = 1.0) -> void:
	for step in ceili(seconds/0.01):
		s.update_bullets(0.01)

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":1})
	s.launch(false,31877)
	s.map_id="city"
	s.ruins=RoyalCity.new()
	s.ruins.generate(31877)
	s.ruins.walls.clear()
	s.spawn_timer=9999
	var p: Dictionary=s.players[1]
	p.p=Vector2(1350,1100)
	s.inputs[1]={"aim":Vector2.RIGHT}
	check(Catalog.WEAPONS.size()==17 and Catalog.STARTER_BASE==17,"Five new weapons follow the eight new staffs")
	for index in range(4,12):
		check(Catalog.weapon_family(index)==3,"New staff uses the casting animation family")
		check(Catalog.item_icon(Catalog.make_equipment("weapon",index,0)).begins_with("staff_"),"New staff has a distinct icon")
		check(Catalog.weapon(index).windup<Catalog.weapon(index).rate,"Windup ends inside its attack cycle")
	for index in range(12,17):
		check(Catalog.weapon(index).windup<Catalog.weapon(index).rate,"New weapon releases inside its attack cycle")
		check(Catalog.item_icon(Catalog.make_equipment("weapon",index,0))!="staff","New weapon has its own icon")
	for index in range(12,16):
		ready(p,index)
		s.enemies.clear()
		s.bullets.clear()
		var front := target(s,p.p+Vector2(90,0))
		var flank := target(s,p.p+Vector2(0,95))
		var behind := target(s,p.p+Vector2(-85,0))
		fire(s,p)
		check(front.hp<1000,"Sword %d hits in front" % index)
		check((behind.hp<1000)==(index in [13,15]),"Only circular sword attacks hit behind")
		check((flank.hp<1000)!=(index==12),"Thrust excludes flanking enemies")
	ready(p,16)
	s.enemies.clear()
	s.bullets.clear()
	var first_arrow := target(s,p.p+Vector2(170,0))
	var second_arrow := target(s,p.p+Vector2(310,0))
	var ammo_before: int=p.ammo
	fire(s,p)
	check(s.bullets.size()==1 and p.ammo==ammo_before-1,"Bow draws one arrow and consumes one ammo")
	travel(s,0.45)
	check(first_arrow.hp<1000 and second_arrow.hp<1000,"Arrow pierces two aligned enemies")
	# Speed, delayed release and distinct projectile counts.
	for index in range(4,12):
		ready(p,index)
		s.enemies.clear()
		s.bullets.clear()
		fire(s,p)
		var expected := 0 if index==8 else 5 if index==9 else 1
		check(s.bullets.size()==expected,"Staff %d releases the intended projectile count" % index)
	check(Catalog.weapon(4).windup>0.7 and Catalog.weapon(11).windup>0.9 and Catalog.weapon(11).damage>Catalog.weapon(4).damage,"Heavy spells have long windup and high damage")
	check(Catalog.weapon(5).windup<0.06 and Catalog.weapon(5).rate<=0.20,"Frost needles fire rapidly")
	# Area impact reaches a second enemy near the projectile's first target.
	ready(p,4)
	s.enemies.clear()
	s.bullets.clear()
	var direct := target(s,p.p+Vector2(180,0))
	var nearby := target(s,p.p+Vector2(210,65))
	fire(s,p)
	travel(s,0.6)
	check(direct.hp<1000 and nearby.hp<1000,"Meteor blast damages a nearby second enemy")
	# Lightning jumps beyond the projectile's own collision.
	ready(p,6)
	s.enemies.clear()
	s.bullets.clear()
	direct=target(s,p.p+Vector2(150,0))
	nearby=target(s,p.p+Vector2(290,35))
	fire(s,p)
	travel(s,0.4)
	check(direct.hp<1000 and nearby.hp<1000,"Chain lightning jumps to a second enemy")
	# The moon blade and eclipse lance can pass through enemies.
	for index in [7,11]:
		ready(p,index)
		s.enemies.clear()
		s.bullets.clear()
		direct=target(s,p.p+Vector2(140,0))
		nearby=target(s,p.p+Vector2(300,0))
		fire(s,p)
		travel(s,0.55)
		check(direct.hp<1000 and nearby.hp<1000,"Piercing staff %d hits two aligned enemies" % index)
	# The prism hits immediately after release and excludes off-axis targets.
	ready(p,8)
	s.enemies.clear()
	s.bullets.clear()
	direct=target(s,p.p+Vector2(250,0))
	nearby=target(s,p.p+Vector2(250,90))
	fire(s,p)
	check(direct.hp<1000 and nearby.hp==1000 and s.bullets.is_empty(),"Prism beam is an aimed instant line")
	# A point-blank scatter burst may land all five feathers, but one target only
	# takes one full hit and four 12% follow-up hits from that attack.
	ready(p,9)
	s.enemies.clear()
	s.bullets.clear()
	direct=target(s,p.p+Vector2(75,0))
	fire(s,p)
	travel(s,0.25)
	var scatter_loss: float=1000.0-direct.hp
	check(scatter_loss>=Catalog.weapon(9).damage and scatter_loss<=Catalog.weapon(9).damage*1.48+0.01,"Scatter follow-up feathers cannot multiply point-blank damage fivefold")
	# Vortex pulls its victims towards impact after damaging them.
	ready(p,10)
	s.enemies.clear()
	s.bullets.clear()
	direct=target(s,p.p+Vector2(175,0))
	nearby=target(s,p.p+Vector2(225,55))
	var previous: Vector2=nearby.p
	fire(s,p)
	travel(s,0.7)
	check(direct.hp<1000 and nearby.hp<1000 and nearby.p.distance_to(direct.p)<previous.distance_to(direct.p),"Vortex damages and draws in nearby enemies")
	print("SPELL TESTS: %d checks, %d failures" % [checks,failures])
	s.queue_free()
	quit(1 if failures else 0)
