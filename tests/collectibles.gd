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
	var kinds: Array=[]
	for biome in Catalog.BIOME_COLLECTIBLES:
		for kind in biome: kinds.append(kind)
	kinds.append_array(Catalog.BOSS_COLLECTIBLES)
	kinds.append_array(Catalog.ROYAL_COLLECTIBLES)
	check(kinds.size()==27 and kinds.size()==kinds.duplicate().reduce(func(a,b): return a if b in a else a+[b],[]).size(),"Twenty-seven unique collectibles")
	for index in kinds.size():
		var kind: String=kinds[index]
		check(Catalog.ITEMS.has(kind),"Catalog entry: "+kind)
		var entry: Dictionary={"kind":kind,"rot":false}
		check(Catalog.item_value(entry)>0 and not Catalog.item_desc(entry).is_empty(),"Value and lore: "+kind)
		check(Catalog.item_size(entry).x>0 and Catalog.item_size(entry).y>0,"Inventory footprint: "+kind)
		check(not Catalog.slot_operable(kind),"Treasure cannot consume the item key: "+kind)
		var sheet := floori(float(index)/9.0)+1
		check(Catalog.collectible_index(kind)==index,"Atlas index: "+kind)
		check(ResourceLoader.exists("res://assets/icons/collectibles-%02d.png" % sheet) and TideUIArt.icon(kind)!=null,"Imported atlas icon: "+kind)
		var pocket := Catalog.make_container([],Vector2i(4,4))
		check(Catalog.place_item(pocket,entry),"Fits pocket: "+kind)
		var saved: Dictionary=JSON.parse_string(JSON.stringify(pocket))
		Catalog.clean_container(saved,Vector2i(4,4))
		check(saved.items.size()==1 and saved.items[0].kind==kind,"Save round trip: "+kind)
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	for chest in s.ruins.chests:
		var biome: int=s.ruins.biome_at(chest.p)
		var p: Dictionary=s.players[1]
		s.begin_search(p,s.ruins.chests.find(chest))
		var found := false
		for item in chest.items:
			if str(item.kind) in Catalog.BIOME_COLLECTIBLES[biome]: found=true
		check(found,"Wilderness cache contains local collectible: "+str(biome))
	s.knight_reward(Vector2(100,100))
	var royal: Dictionary=s.ruins.chests.back()
	for kind in Catalog.ROYAL_COLLECTIBLES:
		check(royal.items.any(func(item): return str(item.kind)==kind),"Royal reward fits "+kind)
	s.queue_free()
	await process_frame
	print("COLLECTIBLE CHECKS: ",checks," failures: ",failures)
	quit(1 if failures>0 else 0)
