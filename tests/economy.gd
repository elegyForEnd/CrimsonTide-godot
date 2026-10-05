extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var profile := Profile.new()
	profile.path="user://economy-test.json"
	profile.sanitize_storage()
	Catalog.add_item(profile.data.pocket,"relic")
	Catalog.place_item(profile.data.bags[0],Catalog.make_equipment("weapon",2,5))
	check(profile.bank_carried_items()==2,"Existing carried items bank without loss")
	check(profile.data.pocket.items.is_empty() and profile.data.bags[0].items.is_empty(),"Banking removes originals")
	check(profile.bank_carried_items()==0 and profile.data.warehouse.size()==2,"Repeated banking cannot duplicate items")
	check(profile.withdraw_item(1),"Warehouse weapon can be prepared for the next expedition")
	check(profile.data.bags[0].items[0].tier==5 and profile.data.bags[0].items[0].weapon==2,"Withdrawal preserves equipment metadata")
	profile.bank_carried_items()
	var initial: int=profile.data.coins
	var value: int=Catalog.bag_value(profile.data.warehouse)
	check(profile.sell_items([0,1,1,-1,999])==value,"Sale pays valid selections exactly once")
	check(profile.data.coins==initial+value and profile.data.warehouse.is_empty(),"Sale removes stock and adds exact currency")
	check(profile.sell_items([0])==0,"Empty stock cannot be resold")
	profile.data.warehouse=[{"kind":"scrap","count":6,"x":0,"y":0},{"kind":"medicine","provision":true,"x":0,"y":0}]
	check(profile.sell_items([0,1])==192 and profile.data.warehouse.size()==1,"Stacks pay each unit; camp-issued supplies cannot be sold for profit")
	profile.data.warehouse=[{"kind":"amulet","x":500,"y":500}]
	profile.save_profile()
	var loaded := Profile.new()
	loaded.path=profile.path
	loaded.load_profile()
	check(loaded.data.warehouse.size()==1 and loaded.data.trade_history.size()==3,"Warehouse and transaction history survive a save/load")
	loaded.apply_data({"version":1})
	check(loaded.data.warehouse.is_empty(),"Older account saves cannot inherit another account's warehouse")
	for kind in Catalog.ITEMS:
		check(Catalog.item_value({"kind":kind})>0,"Every catalog item has positive value: "+kind)
	var session := TideSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({"hero":0})
	session.launch(false,1729)
	var p: Dictionary=session.players[1]
	Catalog.add_item(p.pocket,"amulet")
	p.equipped.weapon=Catalog.make_equipment("weapon",2,5)
	p.equipped.charm[0]={"kind":"charm","x":0,"y":0}
	p.slots[0]={"kind":"ammo","x":0,"y":0}
	p.status="extracted"
	session.objectives=1
	session.settle()
	var reward: Dictionary=session.results[1]
	check(reward.coins==reward.shared,"Extraction pays objectives only; loot requires sale")
	check(reward.equipment_loot.size()==3,"Extraction preserves weapon, charm and quick-slot loot")
	session.solo({"hero":0})
	session.launch(false,1729)
	p=session.players[1]
	Catalog.add_item(p.pocket,"amulet")
	Catalog.add_item(p.backpack,"relic")
	session.spill_storage(p)
	p.status="dead"
	session.settle()
	reward=session.results[1]
	check(reward.pocket.items.size()==1 and reward.bags[0].items.is_empty() and reward.equipment_loot.is_empty(),"Death banks only the safe pocket, never the dropped loot")
	session.queue_free()
	DirAccess.remove_absolute(profile.path)
	await process_frame
	print("ECONOMY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
