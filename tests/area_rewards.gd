extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for seed_value in range(1,31):
		var world := Ruins.new()
		world.generate(seed_value)
		check(world.chests.size()==6,"Six sparse wilderness caches per seed")
		var biomes := {}
		for chest in world.chests:
			biomes[world.biome_at(chest.p)]=true
			check(not world.blocked(chest.p,45),"Wilderness cache has room to approach")
			for site in world.sites:
				check(not site.rect.grow(220).has_point(chest.p),"No ambient caches inside habitats")
		check(biomes.size()==6,"Wilderness supplies spread over all six biomes")
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	s.spawn_timer=999
	var p: Dictionary=s.players[1]
	p.invuln=999
	var initial := s.ruins.chests.size()
	var residents: Array=s.enemies.filter(func(e): return e.habitat==0)
	check(residents.size()==2,"Easy site starts with two defenders")
	# An attack from outside the habitat also locks the encounter population.
	s.damage_enemy(residents[0],1,1,Vector2.ZERO,0)
	var before := s.enemies.size()
	s.spawn_enemy(s.ruins.sites[0].p)
	check(s.enemies.size()==before,"Engaged site rejects reinforcement")
	residents[0].hp=0
	s.simulate(0.01)
	check(s.ruins.chests.size()==initial and not s.ruins.sites[0].cleared,"Partial clear gives no reward")
	# A defender lured out still belongs to its original site.
	residents[1].p=Ruins.SPAWN
	residents[1].hp=0
	var drop := s.ground_drop(Ruins.SPAWN,"ammo")
	s.world_drops.append(drop)
	s.begin_search(p,s.ruins.chests.size()+s.world_drops.size()-1)
	s.simulate(0.01)
	check(s.container_at(s.search_reference(p))==drop,"Reward insertion preserves ground search reference")
	check(s.ruins.chests.size()==initial+1 and s.ruins.sites[0].cleared,"Final defender grants exactly one reward")
	check(s.ruins.chests.back().site_reward==0,"Out-of-area kill rewards original habitat")
	before=s.enemies.size()
	for i in 10: s.spawn_enemy(s.ruins.sites[0].p)
	check(s.enemies.size()==before,"Cleared site cannot respawn")
	for i in 10: s.simulate(0.01)
	check(s.ruins.chests.size()==initial+1,"Clear reward cannot repeat")
	# Kill all remaining defenders together, including elites. Each of the 18
	# habitats must produce a reachable cache with complete guaranteed contents.
	for e in s.enemies: e.hp=0
	s.simulate(0.01)
	check(s.ruins.chests.size()==initial+18,"One reward per habitat on simultaneous clear")
	var values := {}
	for chest in s.ruins.chests:
		if not chest.has("site_reward"): continue
		check(not s.ruins.blocked(chest.p,30),"Clear reward is reachable inside site")
		var quality: int=chest.reward_tier
		var kinds := {}
		for item in chest.items:
			kinds[item.kind]=true
			if item.kind in ["weapon","gear"]: check(item.tier==quality,"Equipment quality matches area difficulty")
			if item.kind=="backpack": check(Catalog.tier_index(item.quality)==quality,"Backpack quality matches difficulty")
		check(kinds.has("weapon") and kinds.has("gear") and kinds.has("backpack") and kinds.has("medicine") and kinds.has("ammo"),"Guaranteed equipment and supplies fit the chest")
		check(s.container_units(chest)==quality+4,"All difficulty-scaled relics fit")
		values[quality]=Catalog.container_value(chest)
	for quality in range(1,4): check(values[quality]<values[quality+1],"Harder areas have more valuable rewards")
	# All sites remain cleared across days and a round trip through the city.
	s.expedition.prepare_day(s,2)
	p.p=s.CITY_GATE
	check(s.travel_city(),"Enter city after clearing border")
	check(s.ruins.chests.is_empty(),"City has no ambient caches")
	s.enemies[0].hp=0
	s.simulate(0.01)
	check(s.ruins.chests.is_empty(),"City reward waits for surviving guards")
	for e in s.enemies: e.hp=0
	s.simulate(0.01)
	check(s.ruins.chests.size()==1,"City clear grants one royal reward")
	p.p=RoyalCity.GATE
	check(s.travel_city(),"Return to border")
	check(s.ruins.chests.size()==initial+18 and s.ruins.sites[0].cleared,"Day and map travel preserve rewards and clear state")
	for i in 30: s.spawn_enemy()
	check(s.enemies.is_empty(),"No refill when all sites are cleared")
	var client := TideSession.new()
	root.add_child(client)
	client.begin(1729,480,{})
	client.set_physics_process(false)
	var packet := var_to_bytes([s.players,s.enemies,s.bullets,s.world_drops,s.ruins.chests,s.ruins.shrines,s.elapsed,s.objectives,s.threat,s.results,s.map_id,s.raid,s.ruins.sites])
	client.snapshot(packet.compress(FileAccess.COMPRESSION_GZIP))
	check(client.ruins.sites[0].cleared and client.ruins.chests.size()==initial+18,"Snapshot replicates clear state and reward")
	# Emptying either kind of cache must not roll fresh loot on the next search.
	for index in [0,initial]:
		var chest: Dictionary=s.ruins.chests[index]
		s.begin_search(p,index)
		chest.items.clear()
		s.begin_search(p,index)
		check(chest.items.is_empty(),"Empty caches cannot be farmed by reopening")
	s.launch(false,1729)
	check(s.ruins.chests.size()==6 and not s.ruins.sites[0].cleared,"New run resets all clear progress")
	s.enemies.clear()
	s.simulate(0.01)
	check(s.ruins.chests.size()==6,"Removing enemies without deaths cannot grant rewards")
	s.queue_free()
	client.queue_free()
	await process_frame
	print("AREA REWARD CHECKS: ",checks," failures: ",failures)
	quit(1 if failures else 0)
