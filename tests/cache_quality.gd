extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	var seen := {}
	for chest in s.ruins.chests:
		var biome := s.ruins.biome_at(chest.p)
		seen[biome]=true
		check(int(chest.cache_tier)==int(Ruins.CACHE_TIERS[biome]),"Cache grade belongs to its biome")
	check(seen.size()==6,"All biome cache grades appear")
	# Compare the same chest and random seed with two different worn backpacks.
	var p: Dictionary=s.players[1]
	p.backpack=Catalog.make_bag("red")
	s.rng.seed=90210
	s.begin_search(p,0)
	var red_bag_result: Array=s.ruins.chests[0].items.duplicate(true)
	s.launch(false,1729)
	p=s.players[1]
	s.rng.seed=90210
	s.begin_search(p,0)
	check(s.ruins.chests[0].items==red_bag_result,"Worn backpack cannot improve a cache")
	# A fixed seed verifies the actual sampler, not just the stated table.
	var expected := [
		[620,260,80,30,8,2],
		[245,480,210,50,12,3],
		[65,260,450,180,38,7],
		[15,75,260,450,175,25],
		[5,20,80,260,545,90],
	]
	var previous_mean := -1.0
	for grade in 5:
		s.rng.seed=24680+grade
		var counts := [0,0,0,0,0,0]
		var mean := 0.0
		for sample in 100000:
			var tier := s.roll_chest_quality(grade)
			counts[tier]+=1
			mean+=tier
		mean/=100000.0
		check(mean>previous_mean,"Expected cache quality rises with biome grade")
		previous_mean=mean
		for tier in 6:
			var target: float=float(expected[grade][tier])
			var sigma: float=sqrt(target*(1.0-target/1000.0)/100.0)
			check(absf(float(counts[tier])/100.0-target)<maxf(0.5,3.5*sigma),"Cache quality probability grade %d tier %d" % [grade,tier])
	# Actual loot-table rates also rise with risk, independent of the bag.
	for grade in 5:
		s.rng.seed=13579+grade
		var bags := 0
		var gear := 0
		var weapons := 0
		var placed_bags := 0
		var placed_gear := 0
		var placed_weapons := 0
		for sample in 10000:
			var chest := s.loot_container(Vector2.ZERO,Vector2i(4,4))
			for item in s.chest_loot(false,-1.0,grade):
				var fits: bool=s.place_entry(chest,item)
				if item is not Dictionary: continue
				var kind := str(item.kind)
				if kind=="backpack":
					bags+=1
					if fits: placed_bags+=1
					check(Catalog.tier_index(str(item.key))<=5,"Bag quality remains valid")
				elif kind=="gear":
					gear+=1
					if fits: placed_gear+=1
					check(int(item.tier)<=5,"Gear quality remains valid")
				elif kind=="weapon":
					weapons+=1
					if fits: placed_weapons+=1
					check(int(item.tier)<=5,"Weapon quality remains valid")
		check(absf(float(bags)/10000.0-float(s.CACHE_BACKPACK_CHANCE[grade]))<0.02,"Backpack chance follows cache grade")
		check(absf(float(gear)/10000.0-float(s.CACHE_GEAR_CHANCE[grade]))<0.02,"Gear chance follows cache grade")
		check(absf(float(weapons)/10000.0-float(s.CACHE_WEAPON_CHANCE[grade]))<0.02,"Weapon chance follows cache grade")
		check(placed_bags==bags and placed_gear==gear and placed_weapons==weapons,"Rolled equipment fits the cache before supplies")
		print("CACHE GRADE ",grade,": bags ",bags,"/",placed_bags," gear ",gear,"/",placed_gear," weapons ",weapons,"/",placed_weapons)
	# Verify the real F-search path uses the grade-specific rates too.
	for grade in 5:
		s.rng.seed=97531+grade
		var bags := 0
		for sample in 3000:
			var chest := s.loot_container(p.p,Vector2i(4,4))
			chest.cache_tier=grade
			s.ruins.chests=[chest]
			s.begin_search(p,0)
			for item in chest.items:
				if str(item.kind)=="backpack": bags+=1
		check(absf(float(bags)/3000.0-float(s.CACHE_BACKPACK_CHANCE[grade]))<0.035,"F-search applies this cache's backpack rate")
	s.queue_free()
	await process_frame
	print("CACHE QUALITY CHECKS: ",checks," failures: ",failures)
	quit(1 if failures else 0)
