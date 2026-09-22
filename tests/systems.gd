extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("FAIL: "+description)

func index_of(container: Dictionary, kind: String) -> int:
	var items: Array=Catalog.container_items(container)
	for i in items.size():
		if str(items[i].kind)==kind:
			return i
	return -1

func spare_index_in(p: Dictionary, key: String) -> int:
	for i in p.bags.size():
		if str(p.bags[i].key)==key:
			return i
	return -1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# --- grid rules ---------------------------------------------------------
	var bag: Array=[]
	for i in 24:
		check(Catalog.insert(bag,"crystal",Vector2i(6,4)),"fill 6x4 cell %d" % i)
	check(not Catalog.insert(bag,"crystal",Vector2i(6,4)),"reject full 6x4 grid")
	check(Catalog.bag_value(bag)==432,"bag value")
	check(Catalog.consume(bag,"crystal"),"consume exists")
	bag.clear()
	check(Catalog.insert(bag,"relic",Vector2i(6,4)),"insert relic")
	check(not Catalog.can_place(bag,{"kind":"medicine","rot":false},Vector2i(1,1),-1,Vector2i(6,4)),"reject overlapping item")
	check(Catalog.can_place(bag,{"kind":"medicine","rot":true},Vector2i(4,3),-1,Vector2i(6,4)),"rotated item at edge")
	check(not Catalog.can_place(bag,{"kind":"medicine","rot":false},Vector2i(4,3),-1,Vector2i(6,4)),"vertical item crosses edge")
	# --- backpack quality tiers --------------------------------------------
	check(Catalog.BAG_TIERS.size()==6,"six backpack qualities")
	check(Catalog.tier("white").grid==Vector2i(3,3),"white backpack is 3x3")
	check(Catalog.tier("green").grid==Vector2i(4,4),"green backpack is 4x4")
	check(Catalog.tier("blue").grid==Vector2i(5,5),"blue backpack is 5x5")
	check(Catalog.tier("purple").grid==Vector2i(6,6),"purple backpack is 6x6")
	check(Catalog.tier("gold").grid==Vector2i(7,7),"gold backpack is 7x7")
	check(Catalog.tier("red").grid==Vector2i(8,8),"red backpack is 8x8")
	for i in range(1,Catalog.BAG_TIERS.size()):
		check(Catalog.BAG_TIERS[i].grid.x>Catalog.BAG_TIERS[i-1].grid.x,"quality %d grows the grid" % i)
	check(Catalog.slot_count("red")==64 and Catalog.slot_count("white")==9,"slot counts follow quality")
	check(Catalog.POCKET_GRID==Vector2i(4,4),"dimensional pocket is 4x4")
	var white: Array=[]
	for i in 9:
		check(Catalog.insert(white,"crystal",Catalog.tier("white").grid),"white backpack holds 9 cells")
	check(not Catalog.insert(white,"crystal",Catalog.tier("white").grid),"white backpack rejects a 10th cell")
	var small: Array=[]
	check(Catalog.insert(small,"relic",Catalog.tier("white").grid),"a 3x3 backpack still holds one relic")
	check(not Catalog.can_place(small,{"kind":"relic","rot":false},Vector2i(2,2),-1,Catalog.tier("white").grid),"a second relic overflows a 3x3")
	check(Catalog.can_place(small,{"kind":"relic","rot":false},Vector2i(2,0),-1,Catalog.tier("green").grid),"two relics share a 4x4")
	# --- containers ---------------------------------------------------------
	var pocket := Catalog.make_container([],Catalog.POCKET_GRID)
	check(Catalog.container_free(pocket)==16,"4x4 pocket reports 16 free cells")
	check(Catalog.add_item(pocket,"crystal") and Catalog.container_free(pocket)==15,"pocket takes an item")
	check(Catalog.container_count(pocket,"crystal")==1,"pocket counts items")
	check(Catalog.consume_container(pocket,"crystal") and Catalog.container_count(pocket,"crystal")==0,"pocket consumes items")
	var mixed := Catalog.make_container([],Catalog.POCKET_GRID)
	Catalog.add_item(mixed,"relic")
	check(Catalog.container_free(mixed)==12,"relic costs four pocket cells")
	var packed := Catalog.make_container([],Catalog.POCKET_GRID)
	for i in 4:
		Catalog.add_item(packed,"relic")
	check(Catalog.container_free(packed)==0,"four relics tile a 4x4 pocket")
	check(not Catalog.can_hold(packed,"relic"),"a fifth relic does not fit in the pocket")
	check(mixed.get("gw")==4 and mixed.get("gh")==4,"container exposes its grid")
	check(Catalog.clean_container({"items":[{"kind":"ghost"}],"gw":9,"gh":9},Catalog.POCKET_GRID).items.is_empty(),"junk save data is dropped")
	var dirty := Catalog.clean_container({"items":[{"kind":"crystal","x":9,"y":0,"rot":false}],"gw":99,"gh":99},Catalog.POCKET_GRID)
	check(dirty.items.is_empty() and dirty.gw==4,"out-of-bounds save data is dropped")
	# --- backpack swap ------------------------------------------------------
	var carrier := {"backpack":Catalog.make_bag("white"),"bags":[]}
	Catalog.add_item(carrier.backpack,"crystal")
	check(not Catalog.swap_bags(carrier,0),"swap without a spare is rejected")
	carrier.bags.append(Catalog.make_bag("blue"))
	check(Catalog.swap_bags(carrier,0),"swap to the blue backpack")
	check(Catalog.bag_grid(carrier.backpack)==Vector2i(5,5),"equipped backpack becomes 5x5")
	check(Catalog.container_count(carrier.backpack,"crystal")==1,"swap keeps the carried loot")
	check(carrier.bags[0].key=="white","the old backpack moves into the cabinet")
	check(not Catalog.swap_bags(carrier,5),"missing cabinet slot is rejected")
	# A swap has to carry every field the save file knows about: rebuilding the
	# entries from kind/x/y/rot alone used to collapse stacks and strip looted
	# equipment, so swapping backpacks quietly destroyed part of the haul.
	var haul_bag: Dictionary = Catalog.make_bag("blue")
	haul_bag["gw"]=5
	haul_bag["gh"]=5
	var haul := {"backpack":haul_bag,"bags":[Catalog.make_bag("red")]}
	for i in 3:
		Catalog.place_loot(haul_bag,"crystal")
	Catalog.place_item(haul_bag,Catalog.make_equipment("weapon",2,4))
	Catalog.place_item(haul_bag,{"kind":"backpack","quality":"gold","x":0,"y":0,"rot":false})
	check(Catalog.swap_bags(haul,0),"swap to the red backpack")
	var stack: Dictionary={}
	var blade: Dictionary={}
	var spare: Dictionary={}
	for entry in Catalog.container_items(haul.backpack):
		match str(entry.kind):
			"crystal": stack=entry
			"weapon": blade=entry
			"backpack": spare=entry
	check(int(stack.get("count",0))==3,"a swap keeps the size of a crystal stack")
	check(int(blade.get("weapon",-1))==2 and int(blade.get("tier",-1))==4,"a swap keeps the looted weapon's index and quality")
	check(str(spare.get("quality",""))=="gold","a swap keeps the carried backpack's quality")
	check(Catalog.bag_grid(haul.backpack)==Vector2i(8,8),"the swapped-in blood-moon backpack is 8x8")
	check(haul.bags[0].key=="blue","the blue backpack moves into the cabinet")
	check(Catalog.container_items(haul.bags[0]).is_empty(),"the old backpack is emptied by the swap")
	# --- deterministic ruins ------------------------------------------------
	for seed_value in range(1,31):
		var map := Ruins.new()
		var twin := Ruins.new()
		map.generate(seed_value)
		twin.generate(seed_value)
		check(str(map.chests)==str(twin.chests),"deterministic loot seed %d" % seed_value)
		var visited: Dictionary={}
		var queue: Array[Vector2i]=[Vector2i(Ruins.SPAWN/40)]
		visited[queue[0]]=true
		var cursor := 0
		while cursor<queue.size():
			var cell := queue[cursor]
			cursor+=1
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i=cell+delta
				if next.x<1 or next.y<1 or next.x>int(Ruins.SIZE.x/40)-2 or next.y>int(Ruins.SIZE.y/40)-2 or visited.has(next):
					continue
				if not map.blocked(Vector2(next)*40):
					visited[next]=true
					queue.append(next)
		for shrine in map.shrines:
			check(visited.has(Vector2i((shrine.p/40).round())),"reachable objective %d" % seed_value)
		for exit_pos in map.exits:
			check(visited.has(Vector2i((exit_pos/40).round())),"reachable extraction %d" % seed_value)
	# --- session ------------------------------------------------------------
	var session := TideSession.new()
	session.name="Session"
	root.add_child(session)
	session.set_physics_process(false)
	var pocket_start := Catalog.make_container([],Catalog.POCKET_GRID)
	for i in 3:
		Catalog.add_item(pocket_start,"crystal")
	var carried := {"name":"Test","hero":0,"talents":[0,0,0],"bag_key":"green","bags":[],"pocket":pocket_start}
	session.solo(carried)
	check(session.launch(false,12345),"solo launches")
	check(session.duration==480,"standard duration")
	var p: Dictionary=session.players[1]
	check(Catalog.bag_grid(p.backpack)==Vector2i(4,4),"saved green backpack loads at 4x4")
	check(Catalog.container_count(p.pocket,"crystal")==3,"saved pocket loot loads")
	check(Catalog.container_value(p.pocket)==54,"pocket value survives the save")
	session.rng.seed=99
	# Free supplies ride in the backpack: losing them must not mint silver.
	for i in 30:
		Catalog.add_item(p.backpack,"medicine")
	var provision_value := Catalog.container_value(p.backpack)
	check(provision_value>0,"backpack took the free supplies")
	for item in p.backpack.items:
		item["provision"]=true
	check(Catalog.container_value(p.backpack)==0,"free supplies cannot generate silver")
	p.backpack.items.clear()
	session.enemies.clear()
	session.spawn_timer=999
	# --- searching a container reveals loot one unit at a time --------------
	check(Catalog.chest_grid(1)==Vector2i(4,4),"ordinary chests search a 4x4 grid")
	check(Catalog.chest_grid(2)==Vector2i(5,5),"the deep cathedral searches a 5x5 grid")
	check(session.ruins.chests[0].get("class",0)==1,"first chest is an ordinary one")
	var chest: Dictionary=session.ruins.chests[0]
	p.p=chest.p
	check(session.search_target(p)==0,"standing next to a chest targets it for searching")
	session.perform(1,"search",{"index":0})
	check(session.search_reference(p)==0,"pressing F starts a search on the container")
	check(session.container_units(chest)>0,"a search fills the container with loot")
	check(session.visible_units(chest)==0,"a fresh container reveals nothing yet")
	check(session.visible_items(chest).is_empty(),"nothing is visible before searching")
	session.advance_search(p,1.3)
	check(session.visible_units(chest)==1,"one unit surfaces after 1.2 seconds")
	session.advance_search(p,1.3)
	check(session.visible_units(chest)==2,"a second unit surfaces after another second")
	check(not session.visible_items(chest).is_empty(),"searched units are visible")
	var units_before: int=session.container_units(chest)
	var taken_before: int=p.backpack.items.size()
	check(session.take_loot(p,0,0),"taking a searched item succeeds")
	check(session.container_units(chest)==units_before-1,"taking removes exactly one unit")
	check(p.backpack.items.size()>=taken_before,"taken loot reaches the backpack")
	check(session.take_loot(p,0,5)==false,"unsearched slots cannot be taken")
	# Leaving the area stops the search progress.
	p.p=chest.p+Vector2(400,0)
	var frozen: int=session.searched_units(chest)
	session.advance_search(p,4.0)
	check(session.searched_units(chest)==frozen,"walking away pauses the search")
	p.p=chest.p
	while not session.container_searched(chest):
		session.advance_search(p,1.3)
	check(session.container_searched(chest),"a container can be fully searched")
	check(session.visible_items(chest).size()==Catalog.container_items(chest).size(),"everything shows once searched")
	# --- ground loot: single F, no search window ----------------------------
	check(session.store_loot(p,"medicine"),"carry a medkit to spend")
	check(session.store_loot(p,"crystal"),"carry a crystal to burn")
	# --- drag and drop between containers ----------------------------------
	var source_free: int=Catalog.container_free(p.backpack)
	Catalog.add_item(p.backpack,"scrap")
	var scrap_index: int=-1
	for i in p.backpack.items.size():
		if p.backpack.items[i].kind=="scrap":
			scrap_index=i
			break
	check(scrap_index>=0,"a scrap sits in the backpack")
	check(session.move_between(p,"backpack","pocket",scrap_index,Vector2i(3,3),false),"dragging backpack to pocket works")
	check(Catalog.container_count(p.pocket,"scrap")==1,"the dragged item arrived in the pocket")
	check(Catalog.container_count(p.backpack,"scrap")==0,"the dragged item left the backpack")
	var pocket_scrap: int=-1
	for i in p.pocket.items.size():
		if p.pocket.items[i].kind=="scrap":
			pocket_scrap=i
			break
	check(session.move_between(p,"pocket","backpack",pocket_scrap,Vector2i(0,0),false),"dragging pocket to backpack works")
	check(Catalog.container_count(p.backpack,"scrap")>=1,"the item came back to the backpack")
	var crystal_index: int=-1
	for i in p.backpack.items.size():
		if p.backpack.items[i].kind=="crystal":
			crystal_index=i
			break
	var pocket_free_before: int=Catalog.container_free(p.pocket)
	check(session.move_between(p,"backpack","backpack",crystal_index,Vector2i(99,99),false),"an out-of-range drop lands in the first free cell")
	check(Catalog.container_free(p.pocket)==pocket_free_before,"a rejected move never changes another container")
	check(Catalog.container_free(p.backpack)<=source_free,"moves never invent free space")
	p.hp=25
	session.perform(1,"heal")
	check(p.hp==70,"medkit restores 45")
	check(session.carried(p,"medicine")==0,"healing consumed the carried medkit")
	var crystals_before: int=session.carried(p,"crystal")
	p.scent=50
	session.perform(1,"burn")
	check(p.scent==25,"burn reduces scent")
	check(session.carried(p,"crystal")==crystals_before-1,"one burn spends exactly one crystal")
	var fought: Dictionary=session.make_player(4,{"name":"Fighter"})
	session.players[4]=fought
	Catalog.add_item(fought.backpack,"charm")
	check(session.charms_carried(fought)==1,"charms are counted in the backpack")
	Catalog.add_item(fought.pocket,"charm")
	check(session.charms_carried(fought)==2,"charms are also counted in the pocket")
	session.players.erase(4)
	# --- relics sink into the safe pocket ----------------------------------
	var free_before: int=Catalog.container_free(p.backpack)
	check(session.store_loot(p,"relic"),"relic loot is accepted")
	check(Catalog.container_count(p.pocket,"relic")==1,"a relic is stored in the dimensional pocket")
	check(Catalog.container_free(p.backpack)==free_before,"relics do not consume backpack space")
	# --- death scatters the backpack, never the pocket ----------------------
	var doomed: Dictionary=session.make_player(3,{"name":"Doomed"})
	session.players[3]=doomed
	Catalog.add_item(doomed.backpack,"scrap")
	doomed.bags.append(Catalog.make_bag("gold"))
	Catalog.add_item(doomed.bags[0],"crystal")
	Catalog.add_item(doomed.pocket,"relic")
	var drop_count: int=session.world_drops.size()
	session.down(doomed)
	check(doomed.status=="down","downing sets the downed state")
	check(doomed.backpack.items.is_empty(),"death empties the backpack")
	check(doomed.bags.is_empty(),"death also scatters the spare backpacks")
	check(Catalog.container_count(doomed.pocket,"relic")==1,"the pocket survives going down")
	check(session.world_drops.size()==drop_count+2,"each carried container lands as a lootable bag")
	var spilled_kinds: Array=[]
	for i in range(drop_count,session.world_drops.size()):
		for item in Catalog.container_items(session.world_drops[i]):
			spilled_kinds.append(str(item.kind))
	spilled_kinds.sort()
	check(spilled_kinds==["crystal","scrap"],"every carried item hits the ground: "+str(spilled_kinds))
	check(session.container_searched(session.world_drops[drop_count]),"a spilled bag can be read immediately")
	check(Catalog.bag_grid(doomed.backpack)==Vector2i(3,3),"the next run restarts from a white backpack")
	# --- ground loot is grabbed with a single F -----------------------------
	var walker: Dictionary=session.players[1]
	walker.p=Vector2(700,700)
	walker.backpack.items.clear()
	session.world_drops.append(session.ground_drop(walker.p,"backpack","gold"))
	var ground_index: int=session.world_drops.size()-1
	check(str(session.world_drops[ground_index].key)=="bag:gold","a dropped backpack remembers its quality")
	check(session.search_target(walker)==session.ruins.chests.size()+ground_index,"ground loot is the search target")
	check(session.pick_up_ground(walker),"pressing F grabs ground loot instantly")
	check(session.world_drops.size()==ground_index,"an emptied ground bag disappears")
	check(Catalog.container_count(walker.backpack,"backpack")==1,"the grabbed backpack sits in the backpack")
	check(session.pick_up_ground(walker)==false,"pressing F again finds nothing to grab")
	# --- the pocket always travels home ------------------------------------
	Catalog.insert(p.backpack.items,"scrap",Catalog.bag_grid(p.backpack))
	p.status="extracted"
	session.players.erase(3)
	session.players[2]=session.make_player(2,{"name":"Ally","hero":1})
	session.players[2].status="dead"
	session.settle()
	check(session.results[1].escaped,"extraction recorded")
	check(Catalog.container_count(session.results[1].pocket,"relic")==1,"the pocket is handed to the save file")
	check(session.results[1].bags[0].key=="green","an extracted player keeps the equipped backpack")
	check(session.results[1].loot>=Catalog.container_value(session.results[1].pocket),"extracted loot covers the pocket")
	check(session.results[1].loot>54,"extracted player also banks backpack value")
	check(session.results[1].has("worn"),"the report records what was worn")
	check(session.results[2].pocket.items.is_empty(),"a dead player settles no pocket loot")
	check(session.results[2].bags[0].key=="white","a dead player restarts from the white backpack")
	check(session.results[2].loot==0,"dead player loses backpack loot")
	# --- the pocket survives replay and timeout ----------------------------
	session.return_to_camp()
	session.solo({"name":"Test","hero":0,"talents":[0,0,0],"bag_key":"white","bags":[],
		"pocket":Catalog.make_container([{"kind":"relic","x":0,"y":0,"rot":false}],Catalog.POCKET_GRID)})
	check(session.launch(true,42),"replay long expedition")
	check(session.duration==900 and session.objectives==0,"new run resets objectives and timer")
	check(Catalog.container_count(session.players[1].pocket,"relic")==1,"the pocket follows the save file into the next run")
	check(Catalog.bag_grid(session.players[1].backpack)==Vector2i(3,3),"a fresh run starts from the white backpack")
	session.enemies.clear()
	session.elapsed=899.99
	session.simulate(0.1)
	check(not session.running and not session.results[1].escaped,"deadline kills unextracted player")
	check(session.results[1].pocket.items.size()==1,"even a timeout keeps the pocket")
	# --- save file round trip ----------------------------------------------
	var save := Profile.new()
	save.path="res://tests/_tmp-profile.json"
	save.data.coins=987
	save.data.talents=[2,3,1]
	save.data.bag_key="blue"
	save.data.pocket=Catalog.make_container([],Catalog.POCKET_GRID)
	Catalog.add_item(save.data.pocket,"relic")
	save.data.bags=[Catalog.make_bag("blue"),Catalog.make_bag("red")]
	save.save_profile()
	var restored := Profile.new()
	restored.path=save.path
	restored.load_profile()
	check(restored.data.coins==987 and restored.data.talents==[2,3,1],"save/load preserves progression")
	check(restored.data.pocket.items.size()==1 and restored.data.pocket.gw==4,"save/load preserves the 4x4 pocket")
	check(restored.storage_payload().bags.size()==2,"save/load preserves the backpack cabinet")
	restored.data.pocket={"items":[{"kind":"crystal","x":99,"y":9,"rot":false}],"gw":12,"gh":12}
	restored.sanitize_storage()
	check(restored.data.pocket.items.is_empty() and restored.data.pocket.gw==4,"loading repairs a broken pocket")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	# --- the temporary weapon every hero sets out with ------------------------
	# One int addresses every weapon in the game, so the issue weapons live in the
	# same table as the four field weapons and every consumer can stay unchanged.
	check(Catalog.STARTER_WEAPONS.size()==Catalog.HEROES.size(),"one issue weapon per hero")
	check(Catalog.STARTER_BASE==Catalog.WEAPONS.size(),"issue weapons sit after the four field weapons")
	for hero in Catalog.HEROES.size():
		var issue_index: int=Catalog.starter_index(hero)
		check(Catalog.is_starter(issue_index),"hero %d issues a temporary weapon" % hero)
		check(Catalog.weapon_name(issue_index)==str(Catalog.STARTER_WEAPONS[hero].name),"the issue weapon names itself")
		check(Catalog.weapon_family(issue_index)==int(Catalog.STARTER_WEAPONS[hero].family),"the issue weapon borrows a field family")
		check(Catalog.weapon_family(issue_index)<Catalog.WEAPONS.size(),"that family is a real field weapon")
	for index in Catalog.WEAPONS.size():
		check(Catalog.weapon_family(index)==index,"field weapon %d reports its own family" % index)
		check(not Catalog.is_starter(index),"field weapon %d is not an issue weapon" % index)
		check(Catalog.weapon(index).name==Catalog.WEAPONS[index].name,"weapon() reads the field half of the table")
	check(Catalog.weapon_name(Catalog.starter_index(0))=="黑铁短剑","绯月 issues the black iron shortsword")
	check(Catalog.weapon_name(Catalog.starter_index(1))=="祭祀短杖","雪璃 issues the sacrificial short staff")
	check(Catalog.weapon_name(Catalog.starter_index(2))=="破碎大剑","鸦羽 issues the broken greatsword")
	check(Catalog.weapon(99).name==str(Catalog.WEAPONS[Catalog.WEAPONS.size()-1].name),"an out-of-range weapon clamps to field loot")
	# Loot can never be an issue weapon, however the index is rolled.
	for junk in 24:
		var rolled := Catalog.make_equipment("weapon",junk,3)
		check(not Catalog.is_starter(int(rolled.weapon)),"loot never hands out a temporary weapon")
		check(int(rolled.weapon)<Catalog.WEAPONS.size(),"a looted weapon stays inside the field table")
	# Every issue weapon is deliberately weaker than the field weapon it imitates.
	for hero in Catalog.HEROES.size():
		var issue: Dictionary=Catalog.STARTER_WEAPONS[hero]
		var field: Dictionary=Catalog.WEAPONS[int(issue.family)]
		check(float(issue.damage)<float(field.damage),"%s hits softer than %s" % [issue.name,field.name])
		check(float(issue.reach)<=float(field.reach),"%s has no more reach than %s" % [issue.name,field.name])
	# --- weapon and gear found in the field ---------------------------------
	check(Catalog.ITEMS.has("weapon") and Catalog.ITEMS.has("gear"),"weapons and gear are loot kinds")
	check(Catalog.ITEMS["weapon"].size==Vector2i(2,2),"a weapon takes a 2x2 block")
	check(Catalog.ITEMS["gear"].size==Vector2i(1,2),"a gear piece takes a 1x2 block")
	var white_blade := Catalog.make_equipment("weapon",2,0)
	var red_blade := Catalog.make_equipment("weapon",2,5)
	check(int(white_blade.tier)==0 and int(red_blade.tier)==5,"equipment remembers its quality")
	check(Catalog.item_value(white_blade)==85,"a white weapon is worth its base value")
	check(Catalog.item_value(red_blade)>Catalog.item_value(white_blade)*2,"a red weapon is worth far more")
	check(Catalog.item_name(red_blade)==Catalog.quality_name(5)+" "+Catalog.WEAPONS[2].name,"red weapon names itself")
	check(Catalog.item_icon(red_blade)=="heavy" and Catalog.item_icon(Catalog.make_equipment("gear",1,2))=="sight","equipment resolves its own icon")
	check(Catalog.weapon_bonus(red_blade)>Catalog.weapon_bonus(white_blade),"a better weapon hits harder")
	check(Catalog.weapon_rate_bonus(red_blade)>0.0,"a better weapon also swings faster")
	check(Catalog.gear_bonus(Catalog.make_equipment("gear",0,5))==Catalog.GEAR_HP[5],"armour scales with quality")
	check(Catalog.gear_desc(Catalog.make_equipment("gear",1,2)).contains("%"),"the sight describes a damage bonus")
	# Equipment fields must survive the save file, together with stack counts.
	var saved_gun := Catalog.make_equipment("weapon",3,4)
	var saved_vest := Catalog.make_equipment("gear",2,1)
	saved_vest["x"]=2
	saved_vest["y"]=0
	var saved_pack := Catalog.clean_container({"items":[
		saved_gun,
		saved_vest,
		{"kind":"ammo","x":3,"y":0,"rot":true,"count":3},
		{"kind":"backpack","x":4,"y":0,"rot":false,"quality":"gold"},
		{"kind":"medicine","x":0,"y":2,"rot":false,"provision":true}],"gw":8,"gh":8},Vector2i(8,8))
	var saved_weapon := index_of(saved_pack,"weapon")
	var saved_gear := index_of(saved_pack,"gear")
	var saved_ammo := index_of(saved_pack,"ammo")
	check(saved_weapon>=0 and int(saved_pack.items[saved_weapon].weapon)==3 and int(saved_pack.items[saved_weapon].tier)==4,"a saved weapon keeps its weapon and quality")
	check(saved_gear>=0 and int(saved_pack.items[saved_gear].gear)==2 and int(saved_pack.items[saved_gear].tier)==1,"a saved gear piece keeps its slot and quality")
	check(saved_ammo>=0 and int(saved_pack.items[saved_ammo].count)==3,"a saved stack keeps its count")
	check(Catalog.container_count(saved_pack,"backpack")==1 and str(saved_pack.items[index_of(saved_pack,"backpack")].quality)=="gold","a saved loose backpack keeps its quality")
	check(bool(saved_pack.items[index_of(saved_pack,"medicine")].get("provision",false)),"a saved provision keeps its free flag")
	# Re-packing a looted container must not strip what an item is.
	var chest_pack := {"items":[],"gw":4,"gh":4,"next":1}
	Catalog.place_loot(chest_pack,"crystal")
	Catalog.place_loot(chest_pack,"crystal")
	Catalog.place_loot(chest_pack,"weapon")
	chest_pack.items[index_of(chest_pack,"weapon")]["weapon"]=2
	chest_pack.items[index_of(chest_pack,"weapon")]["tier"]=3
	Catalog.place_loot(chest_pack,"backpack")
	chest_pack.items[index_of(chest_pack,"backpack")]["quality"]="purple"
	Catalog.tidy(chest_pack)
	var tidied_weapon := index_of(chest_pack,"weapon")
	var tidied_bag := index_of(chest_pack,"backpack")
	check(tidied_weapon>=0 and int(chest_pack.items[tidied_weapon].weapon)==2 and int(chest_pack.items[tidied_weapon].tier)==3,"re-packing keeps a weapon's identity")
	check(tidied_bag>=0 and str(chest_pack.items[tidied_bag].quality)=="purple","re-packing keeps a loose backpack's quality")
	check(Catalog.container_count(chest_pack,"crystal")==1 and int(chest_pack.items[index_of(chest_pack,"crystal")].count)==2,"re-packing merges a stack back together")
	var kit_session := TideSession.new()
	kit_session.name="KitSession"
	root.add_child(kit_session)
	kit_session.set_physics_process(false)
	kit_session.solo({"name":"Kit","hero":0,"talents":[0,0,0],"bag_key":"red","bags":[],"pocket":Catalog.make_container([],Catalog.POCKET_GRID)})
	check(kit_session.launch(false,777),"the equipment run launches")
	var k: Dictionary=kit_session.players[1]
	var base_hp: float=k.max_hp
	var base_speed: float=Catalog.HEROES[0].speed
	# Loot a weapon, a full set of gear and some supplies, then wear them.
	check(kit_session.store_loot(k,"weapon",false,"",kit_session.loot_meta(Catalog.make_equipment("weapon",2,5))),"the weapon reaches the backpack")
	check(kit_session.store_loot(k,"gear",false,"",kit_session.loot_meta(Catalog.make_equipment("gear",0,5))),"armour reaches the backpack")
	check(kit_session.store_loot(k,"gear",false,"",kit_session.loot_meta(Catalog.make_equipment("gear",1,3))),"the sight reaches the backpack")
	check(kit_session.store_loot(k,"gear",false,"",kit_session.loot_meta(Catalog.make_equipment("gear",2,4))),"the boots reach the backpack")
	var weapon_index := index_of(k.backpack,"weapon")
	check(weapon_index>=0 and int(k.backpack.items[weapon_index].tier)==5,"the looted weapon kept its quality in the backpack")
	check(kit_session.equip_item(k,"backpack",weapon_index),"equipping the weapon succeeds")
	check(k.weapon==2 and not kit_session.kit_weapon(k).is_empty(),"equipping a weapon puts it in hand")
	check(kit_session.weapon_kit_active(k),"the worn weapon pays out while it is in hand")
	check(kit_session.equipment_damage(k)>=Catalog.WEAPON_DAMAGE_BONUS[5],"the worn weapon grants its damage bonus")
	check(kit_session.equipment_rate(k)<1.0,"the worn weapon swings faster")
	check(index_of(k.backpack,"weapon")<0,"the equipped weapon left the backpack")
	check(kit_session.equip_item(k,"backpack",index_of(k.backpack,"gear")),"equipping armour succeeds")
	check(abs(kit_session.equipment_hp(k)-Catalog.GEAR_HP[5])<0.01,"armour adds its health bonus")
	check(abs(k.max_hp-(base_hp+Catalog.GEAR_HP[5]))<0.01,"equipping armour raises the health ceiling")
	check(abs(k.hp-k.max_hp)<0.01,"the fresh health arrives immediately")
	check(kit_session.equip_item(k,"backpack",index_of(k.backpack,"gear")),"equipping the sight succeeds")
	check(kit_session.equipment_damage(k)>=Catalog.WEAPON_DAMAGE_BONUS[5]+Catalog.GEAR_DAMAGE[3]-0.001,"the sight stacks with the weapon")
	check(kit_session.equip_item(k,"backpack",index_of(k.backpack,"gear")),"equipping the boots succeeds")
	check(abs(kit_session.equipment_speed(k)-Catalog.GEAR_SPEED[4])<0.01,"the boots add movement speed")
	# A second weapon swaps the first one back into the backpack.
	check(kit_session.store_loot(k,"weapon",false,"",kit_session.loot_meta(Catalog.make_equipment("weapon",0,1))),"a second weapon reaches the backpack")
	check(kit_session.equip_item(k,"backpack",index_of(k.backpack,"weapon")),"the second weapon equips")
	check(k.weapon==0,"the weapon in hand follows the equip")
	check(int(kit_session.kit_weapon(k).get("tier",-1))==1,"the new weapon is the worn one")
	var returned := index_of(k.backpack,"weapon")
	check(returned>=0 and int(k.backpack.items[returned].tier)==5,"the replaced weapon goes back into the backpack")
	# Damage actually rises with the worn weapon: fire one shot and read it back.
	k.pending_strike=false
	kit_session.bullets.clear()
	kit_session.release_strike(k)
	check(kit_session.bullets.size()==1,"a ranged strike creates exactly one bullet")
	var shot: Dictionary=kit_session.bullets.back()
	var expected_hit: float=Catalog.weapon(0).damage*(1+kit_session.equipment_damage(k))
	check(float(shot.damage)>Catalog.weapon(0).damage,"a shot with worn gear hits harder than the base weapon")
	check(abs(float(shot.damage)-expected_hit)<0.01,"the shot damage matches the equipment bonus")
	kit_session.bullets.clear()
	# Taking gear off returns it to storage and gives the health back.
	check(kit_session.unequip_item(k,"gear",0),"armour can be taken off")
	check(kit_session.equipment_hp(k)<0.01,"the armour bonus is gone")
	check(abs(k.max_hp-base_hp)<0.01,"the health ceiling returns to the camp loadout")
	check(index_of(k.backpack,"gear")>=0,"the removed armour is back in the backpack")
	check(kit_session.unequip_item(k,"weapon"),"the weapon can be taken off")
	check(kit_session.kit_weapon(k).is_empty(),"the weapon slot is empty again")
	check(index_of(k.backpack,"weapon")>=0,"the removed weapon is back in the backpack")
	check(k.weapon==Catalog.starter_index(0),"taking the looted weapon off returns the issue weapon")
	check(kit_session.issue_weapon_active(k),"the temporary weapon is what is left in hand")
	check(kit_session.unequip_item(k,"gear",0)==false,"an empty gear slot cannot be removed")
	# --- using items straight out of the backpack ---------------------------
	k.backpack.items.clear()
	k.pocket.items.clear()
	k.hp=k.max_hp*0.2
	var low_hp: float=k.hp
	check(kit_session.store_loot(k,"medicine"),"a medkit sits in the backpack")
	check(kit_session.use_item(k,"backpack",index_of(k.backpack,"medicine")),"the inventory use action runs the medkit")
	check(abs(k.hp-(low_hp+45.0))<0.01,"using a medkit restores 45 health")
	check(kit_session.carried(k,"medicine")==0,"using a medkit consumes exactly one")
	check(kit_session.store_loot(k,"medicine"),"a second medkit sits in the backpack")
	k.hp=k.max_hp
	check(kit_session.use_item(k,"backpack",index_of(k.backpack,"medicine"))==false,"a medkit is refused at full health")
	check(kit_session.carried(k,"medicine")==1,"a refused medkit is not consumed")
	check(kit_session.store_loot(k,"crystal"),"a crystal sits in the backpack")
	k.scent=40
	check(kit_session.use_item(k,"backpack",index_of(k.backpack,"crystal")),"the inventory use action burns a crystal")
	check(int(k.scent)==15 and kit_session.carried(k,"crystal")==0,"burning a crystal spends it for scent")
	check(kit_session.store_loot(k,"ammo"),"an ammo box sits in the backpack")
	var reserve_before: int=k.reserve
	check(kit_session.use_item(k,"backpack",index_of(k.backpack,"ammo")),"the inventory use action opens an ammo box")
	check(k.reserve==reserve_before+48,"an ammo box adds 48 rounds")
	check(kit_session.store_loot(k,"scrap"),"scrap sits in the backpack")
	check(kit_session.use_item(k,"backpack",index_of(k.backpack,"scrap"))==false,"plain loot cannot be used")
	# The F hotkey heals when there is nothing left to loot through the session.
	k.pocket.items.clear()
	check(kit_session.store_loot(k,"medicine"),"a medkit waits in the backpack")
	k.hp=10
	kit_session.perform(1,"heal")
	check(int(k.hp)==55,"the heal action still restores 45 out of the backpack")
	check(kit_session.carried(k,"medicine")==0,"the heal action spends the medkit")
	# --- rotating keeps or slides the item ----------------------------------
	k.backpack.items.clear()
	Catalog.add_item(k.backpack,"medicine")
	var rotate_index := index_of(k.backpack,"medicine")
	var before_rot := bool(k.backpack.items[rotate_index].get("rot",false))
	check(kit_session.rotate_item(k,"backpack",rotate_index),"the rotate action turns an item")
	check(bool(k.backpack.items[rotate_index].get("rot",false))!=before_rot,"the item reports the opposite orientation")
	check(Catalog.can_place(k.backpack.items,k.backpack.items[rotate_index],Vector2i(int(k.backpack.items[rotate_index].x),int(k.backpack.items[rotate_index].y)),rotate_index,Catalog.container_grid(k.backpack)),"a rotated item still fits where it landed")
	# Moving between the two containers keeps what the item is: the one-click
	# button used to rebuild it from its kind, losing quality and stack counts.
	k.backpack.items.clear()
	k.pocket.items.clear()
	check(kit_session.store_loot(k,"weapon",false,"",kit_session.loot_meta(Catalog.make_equipment("weapon",3,2))),"a weapon waits in the backpack")
	check(kit_session.move_between(k,"backpack","pocket",index_of(k.backpack,"weapon"),Vector2i(0,0),false),"the weapon moves to the pocket")
	var pocket_weapon := index_of(k.pocket,"weapon")
	check(pocket_weapon>=0 and int(k.pocket.items[pocket_weapon].weapon)==3 and int(k.pocket.items[pocket_weapon].tier)==2,"the moved weapon keeps its identity")
	k.backpack.items.clear()
	k.pocket.items.clear()
	check(Catalog.add_item(k.pocket,"crystal"),"a stack sits in the pocket")
	var stacked := index_of(k.pocket,"crystal")
	k.pocket.items[stacked]["count"]=6
	var room := {"p":k.p,"key":"container","items":[],"grid":Vector2i(4,4),"searched":0,"open":false,"class":1,"bonus":false,"next":1}
	kit_session.world_drops.append(room)
	check(kit_session.move_between(k,"pocket","loot:"+str(kit_session.container_count()-1),stacked,Vector2i(0,0),false),"a stack can be handed to a chest")
	check(int(Catalog.container_items(room)[0].get("count",1))==6,"the whole stack arrives in the chest")
	check(index_of(k.pocket,"crystal")<0,"the moved stack left the pocket")
	# A chest with room for one more unit must not swallow the rest of the pile.
	var tight := {"p":k.p,"key":"container","items":[{"kind":"crystal","x":0,"y":0,"rot":false,"count":5}],"grid":Vector2i(1,1),"searched":1,"open":false,"class":1,"bonus":false,"next":2}
	kit_session.world_drops.append(tight)
	check(Catalog.add_item(k.pocket,"crystal"),"a fresh stack for a partial transfer")
	var fresh := index_of(k.pocket,"crystal")
	k.pocket.items[fresh]["count"]=6
	check(kit_session.move_between(k,"pocket","loot:"+str(kit_session.container_count()-1),fresh,Vector2i(0,0),false),"a stack hands over only what fits")
	check(int(Catalog.container_items(tight)[0].count)==6,"the chest stack tops out at six")
	check(int(k.pocket.items[index_of(k.pocket,"crystal")].count)==5,"the units that did not fit stay behind")
	check(not Catalog.can_hold({"items":[],"grid":Vector2i(1,1),"searched":0},"relic"),"a 1x1 loot container cannot take a 2x2 relic")
	check(Catalog.can_hold({"items":[],"grid":Vector2i(5,5),"searched":0},"relic"),"the 5x5 cathedral chest has room for a relic")
	# A backpack found in the field is worn through the session action.
	k.backpack.items.clear()
	k.bags=[Catalog.make_bag("white")]
	Catalog.add_item(k.backpack,"backpack")
	k.backpack.items[0]["quality"]="blue"
	check(kit_session.equip_bag(k,"backpack",0),"wearing a looted backpack succeeds")
	check(str(k.backpack.key)=="blue","the looted backpack becomes the worn one")
	check(spare_index_in(k,"white")>=0,"the old backpack waits in the cabinet")
	# Loot tables actually hand out field equipment.
	var equipment_seen := 0
	for i in 240:
		for entry in kit_session.chest_loot(false,0.3,0):
			if entry is Dictionary and Catalog.is_equipment(str(entry.kind)):
				equipment_seen+=1
	check(equipment_seen>0,"chests hand out weapons and gear over time")
	# Dying scatters the worn kit as well as the backpack.
	var doomed_kit: Dictionary=kit_session.make_player(7,{"name":"Worn"})
	kit_session.players[7]=doomed_kit
	Catalog.add_item(doomed_kit.backpack,"weapon")
	doomed_kit.backpack.items[0]["weapon"]=1
	doomed_kit.backpack.items[0]["tier"]=3
	check(kit_session.equip_item(doomed_kit,"backpack",0),"the doomed player wears a weapon")
	var kit_before: int=kit_session.world_drops.size()
	kit_session.down(doomed_kit)
	var spilled_gear := 0
	for i in range(kit_before,kit_session.world_drops.size()):
		for item in Catalog.container_items(kit_session.world_drops[i]):
			if str(item.kind)=="weapon" and int(item.get("tier",0))==3:
				spilled_gear+=1
	check(spilled_gear==1,"the worn weapon hits the ground on death")
	check(kit_session.kit_weapon(doomed_kit).is_empty(),"death clears the worn weapon")
	check(doomed_kit.weapon==Catalog.starter_index(0),"death hands the temporary weapon back")
	kit_session.queue_free()
	session.queue_free()
	print("SYSTEM TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
