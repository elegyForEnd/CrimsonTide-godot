extends SceneTree
const Equipment = preload("res://scripts/rogue_equipment.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func wear(s, p: Dictionary, index: int) -> void:
	p.equipped={"weapon":{},"gear":[{},{},{}]}
	p.rogue_stash=[]
	s.roguelike.equip(s,p,Equipment.make_gear(index,0))
	p.hp=p.max_hp; p.mana=p.max_mana
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	var p: Dictionary=s.players[1]
	var base_hp: float=p.max_hp
	var base_mana: float=p.max_mana
	var base_damage: float=s.weapon_damage(p)
	var seen := {}
	for i in Equipment.GEAR.size():
		var item := Equipment.make_gear(i,0)
		var red := Equipment.make_gear(i,5)
		check(Catalog.gear_slot(item)==Equipment.GEAR[i].slot,"Correct slot for "+Catalog.item_name(item))
		check(not seen.has(Equipment.GEAR[i].passive),"Unique passive")
		seen[Equipment.GEAR[i].passive]=true
		check(Catalog.item_desc(item).contains("独特被动") and Equipment.value(red,"mana")>=Equipment.value(item,"mana"),"Description and quality scaling")
	wear(s,p,4)
	check(is_equal_approx(p.max_hp,base_hp+8) and is_equal_approx(p.max_mana,base_mana+28),"HP and mana attributes")
	check(s.weapon_damage(p)>base_damage,"Attack attribute applies")
	var e: Dictionary=s.enemies[0]
	e.hp=1000; e.max_hp=1000; e.p=p.p+Vector2(200,0)
	check(is_equal_approx(Equipment.damage_multiplier(p,e),1.18),"High mana damage")
	p.mana=0
	check(is_equal_approx(Equipment.damage_multiplier(p,e),1),"High mana condition ends")
	p.hp=30; p.mana=25
	s.roguelike.inventory_action(s,p,{"source":"equipped","index":2,"verb":"stow","version":p.rogue_inventory_revision})
	s.roguelike.inventory_action(s,p,{"source":"reserve","index":0,"verb":"equip","version":p.rogue_inventory_revision})
	check(p.hp==30 and p.mana==25,"Re-equipping cannot refill HP or mana")
	p.mana=p.max_mana
	s.roguelike.inventory_action(s,p,{"source":"equipped","index":2,"verb":"stow","version":p.rogue_inventory_revision})
	check(p.max_mana==base_mana and p.mana==base_mana,"Removing mana item clamps current mana")
	wear(s,p,0); p.hp=30
	e.hp=1000
	s.damage_enemy(e,100,1,Vector2.RIGHT,0)
	check(p.hp==36 and e.hp==900,"Actual damage heals with cap")
	s.damage_enemy(e,100,1,Vector2.RIGHT,0)
	check(p.hp==36,"Siphon cooldown")
	Equipment.tick(p,1); e.hp=2
	s.damage_enemy(e,100,1,Vector2.RIGHT,0)
	check(is_equal_approx(p.hp,36.16),"Overkill cannot inflate lifesteal")
	s.damage_enemy(e,100,1,Vector2.RIGHT,0)
	check(is_equal_approx(p.hp,36.16),"Dead target grants no healing")
	wear(s,p,1)
	var full_damage: float=s.incoming_damage(p,100)
	p.hp=p.max_hp*0.34
	check(is_equal_approx(s.incoming_damage(p,100),full_damage*0.75),"Low health reduction")
	wear(s,p,2); p.invuln=0
	var health_before: float=p.hp
	var mana_before: float=p.mana
	var received: float=s.incoming_damage(p,20)
	s.hurt(p,20)
	check(is_equal_approx(p.hp,health_before-received*0.7) and is_equal_approx(p.mana,mana_before-received*0.3),"Mana shield absorbs after defense")
	p.invuln=0; p.mana=1; health_before=p.hp
	s.hurt(p,20)
	check(p.mana==0 and is_equal_approx(p.hp,health_before-received+1),"Mana shield handles insufficient mana")
	wear(s,p,3); p.mana=0; p.mana_delay=0
	s.recover_mana(p,1)
	check(is_equal_approx(p.mana,p.max_mana*0.09),"Healthy mana recovery")
	p.hp=30; p.mana=0
	s.recover_mana(p,1)
	check(is_equal_approx(p.mana,p.max_mana*0.06),"Normal recovery when wounded")
	wear(s,p,5); p.hp=30
	check(s.spend_mana(p,8) and p.hp==35,"Mana spending heals")
	s.spend_mana(p,8)
	check(p.hp==35,"Prayer cooldown")
	Equipment.tick(p,3); p.mana=0
	check(not s.spend_mana(p,8) and p.hp==35,"Failed casting cannot heal")
	for data in [[6,"rogue_guardian",true,1.22],[7,"hp",29.0,1.25],[8,"distance",180.0,1.18],[9,"distance",95.0,1.16],[11,"player_hp",0.49,1.20]]:
		wear(s,p,data[0]); e.hp=100; e.max_hp=100; e.rogue_guardian=false; e.p=p.p+Vector2(130,0)
		match data[1]:
			"distance": e.p=p.p+Vector2(data[2],0)
			"player_hp": p.hp=p.max_hp*data[2]
			_: e[data[1]]=data[2]
		check(is_equal_approx(Equipment.damage_multiplier(p,e),data[3]),"Passive condition "+str(data[0]))
	wear(s,p,10); p.mana=0; e.hp=2; e.rogue_guardian=false
	s.damage_enemy(e,10,1,Vector2.RIGHT,0)
	check(p.mana==8,"Kill restores mana")
	e.hp=2; s.damage_enemy(e,10,1,Vector2.RIGHT,0)
	check(p.mana==8,"Kill restoration cooldown")
	for i in Equipment.ENGRAVINGS.size():
		p.equipped={"weapon":{},"gear":[{},{},{}]}
		var item := Equipment.engrave(Catalog.make_equipment("weapon",1,0),i)
		s.roguelike.equip(s,p,item)
		check(not seen.has(Equipment.definition(item).passive),"Weapon has distinct passive")
		seen[Equipment.definition(item).passive]=true
		e.hp=100; e.max_hp=100; e.rogue_guardian=false; p.hp=p.max_hp; p.mana=p.max_mana
		if i==1: e.hp=59
		if i==3: p.mana=0
		check(is_equal_approx(Equipment.damage_multiplier(p,e),1.20 if i in [0,3] else 1.15),"Weapon engraving triggers")
		check(s.equipment_rate(p)<1 and s.equipment_damage(p)>0,"Weapon engraving attributes")
	for i in 40:
		s.roguelike.roll_offers(s,false)
		check(s.raid.offers[0].item.has("rogue_id") and s.raid.offers[0].desc.contains("独特被动"),"Rewards include attributes and passive")
	s.raid.mode="expedition"
	check(s.rogue_equipment_stat(p,"mana")==0,"Run equipment bonuses do not affect expedition")
	s.queue_free()
	await process_frame
	print("ROGUE EQUIPMENT %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
