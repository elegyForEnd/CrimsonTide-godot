extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("FAIL: "+description)

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
	# --- deterministic ruins ------------------------------------------------
	for seed_value in range(1,31):
		var map := Ruins.new()
		var twin := Ruins.new()
		map.generate(seed_value)
		twin.generate(seed_value)
		check(str(map.chests)==str(twin.chests),"deterministic loot seed %d" % seed_value)
		var visited: Dictionary={}
		var queue: Array[Vector2i]=[Vector2i(6,27)]
		visited[queue[0]]=true
		var cursor := 0
		while cursor<queue.size():
			var cell := queue[cursor]
			cursor+=1
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i=cell+delta
				if next.x<1 or next.y<1 or next.x>68 or next.y>53 or visited.has(next):
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
	session.queue_free()
	print("SYSTEM TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
