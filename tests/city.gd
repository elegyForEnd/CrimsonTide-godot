extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	var border: Ruins=s.ruins
	check(not s.travel_city(),"Cannot teleport remotely")
	p.p=s.CITY_GATE
	check(not border.blocked(p.p),"World gate accessible")
	s.update_zone_channels(p,1.6)
	check(s.map_id=="border","The gate only opens for a full 4 second wait")
	s.update_zone_channels(p,4.0)
	check(s.map_id=="city" and s.ruins is RoyalCity,"Standing in the gate opens the independent map")
	check(not s.ruins.blocked(p.p),"Arrival is walkable")
	check(s.ruins.clear_line(RoyalCity.GATE,RoyalCity.BOSS),"Gate to throne route traversable")
	check(s.ruins.blocked(Vector2(640,700)),"Pillars collide")
	check(s.enemies.size()==5,"Knight and four guards")
	var e: Dictionary=s.enemies[0]
	check(e.type==4 and e.hp==1800,"Unique knight stats")
	s.enemies=[e]
	e.p=RoyalCity.BOSS
	p.p=e.p+Vector2(100,0)
	p.invuln=0
	s.update_enemies(0.01)
	check(e.move_name=="combo" and p.hp==p.max_hp,"Combo starts with harmless anticipation")
	s.update_enemies(0.64)
	check(p.hp==p.max_hp,"No early contact")
	s.update_enemies(0.02)
	check(p.hp<p.max_hp,"First slash hits at contact")
	var hp: float=p.hp
	p.p=e.p-Vector2(100,0)
	p.invuln=0
	s.update_enemies(0.45)
	check(p.hp==hp,"Locked cone allows rear dodge")
	s.damage_enemy(e,20,1,Vector2.RIGHT,16)
	check(e.attack_time>0,"Light hit does not stunlock knight")
	s.damage_enemy(e,220,1,Vector2.RIGHT,58)
	check(e.attack_time==0 and e.stagger>1,"Poise break interrupts knight")
	e.stagger=0
	e.cd=0
	e.sequence=1
	p.p=e.p+Vector2(320,0)
	s.update_enemies(0.01)
	check(e.move_name=="thrust","Distance triggers thrust")
	var start: Vector2=e.p
	s.update_enemies(1.2)
	check(e.p.distance_to(start)>250,"Thrust advances after windup")
	e.attack_time=0
	e.cd=0
	e.sequence=2
	e.hp=800
	p.p=e.p+Vector2(150,0)
	p.invuln=0
	s.update_enemies(0.01)
	check(e.move_name=="storm","Half health unlocks storm")
	hp=p.hp
	p.invuln=1
	s.update_enemies(1.16)
	check(p.hp==hp,"Dodge invulnerability defeats storm")
	e.hp=0
	s.simulate(0.01)
	check(s.enemies.is_empty(),"Knight removed after defeat")
	var chest: Dictionary=s.ruins.chests.back()
	check(chest.get("fixed_loot",false),"Boss reward is fixed")
	check(chest.items.size()==11,"Eleven guaranteed valuables")
	var red := 0
	var gold := 0
	for item in chest.items:
		if item.kind=="weapon" and item.tier==5: red+=1
		if item.kind=="gear" and item.tier==4: gold+=1
	check(red==1 and gold==3,"Red weapon and three gold equipment pieces")
	check(Catalog.container_value(chest)>=1500,"Boss cache has substantial sale value")
	p.p=chest.p
	s.begin_search(p,s.ruins.chests.size()-1)
	s.advance_search(p,20)
	check(s.container_searched(chest),"Boss cache can be fully searched")
	p.backpack=Catalog.make_bag("red")
	var weapon_slot := -1
	for i in s.visible_items(chest).size():
		if s.visible_items(chest)[i].kind=="weapon": weapon_slot=i
	check(weapon_slot>=0 and s.take_loot(p,s.ruins.chests.size()-1,weapon_slot),"Legendary reward can be collected")
	var preserved := false
	for item in p.backpack.items:
		if item.kind=="weapon" and item.weapon==2 and item.tier==5: preserved=true
	check(preserved,"Reward quality survives inventory transfer")
	var city: Ruins=s.ruins
	p.p=RoyalCity.GATE
	check(s.travel_city() and s.ruins==border,"Return restores same world")
	p.p=s.CITY_GATE
	check(s.travel_city() and s.ruins==city and s.enemies.is_empty(),"Reentry keeps boss dead")
	check(s.ruins.chests.back()==chest,"Reward persists through return")
	chest.items.clear()
	s.begin_search(p,s.ruins.chests.size()-1)
	check(chest.items.is_empty(),"Empty reward cannot reroll")
	s.players[2]=s.make_player(2,{"hero":1})
	p.p=RoyalCity.GATE
	check(not s.travel_city(),"Distant teammate prevents forced travel")
	s.players[2].p=RoyalCity.GATE
	s.players[2].status="down"
	check(not s.travel_city(),"Downed ally must be rescued first")
	s.players[2].status="active"
	check(s.travel_city(),"Gathered party travels")
	check(s.players[2].p.distance_to(p.p)<100,"Party arrives together")
	# Consume the real replication packet in a separate receiver.
	var client := TideSession.new()
	root.add_child(client)
	client.begin(1729,480,{})
	client.set_physics_process(false)
	p.p=s.CITY_GATE
	s.players[2].p=s.CITY_GATE
	s.travel_city()
	var packet := var_to_bytes([s.players,s.enemies,s.bullets,s.world_drops,s.ruins.chests,s.ruins.shrines,s.elapsed,s.objectives,s.threat,s.results,s.map_id,s.raid])
	client.snapshot(packet.compress(FileAccess.COMPRESSION_GZIP))
	check(client.map_id=="city" and client.ruins is RoyalCity,"Snapshot selects correct geometry")
	check(client.ruins.chests.size()==1 and client.enemies.is_empty(),"Snapshot keeps clear reward and defeat without ambient city chests")
	s.raid.time=s.duration-0.001
	s.simulate(0.01)
	check(s.map_id=="border" and s.raid.phase=="boss" and p.status=="active","Interior cannot bypass dawn boss battle")
	print("CITY TESTS: %d/%d" % [checks-failures,checks])
	s.queue_free()
	client.queue_free()
	await process_frame
	quit(1 if failures else 0)
