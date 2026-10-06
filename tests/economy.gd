extends SceneTree
## Vault, carried storage, settlement and camp issue gear.
##
## The vault stopped being a flat array: it is a real 15x15 grid container with a
## spill list behind it, the worn kit is part of the save file, and the camp issue
## gear is bought. This file covers all of that, including the old-save upgrade.
var failures := 0
var checks := 0
var cleanup: Array = []

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func scratch(name: String) -> Profile:
	var profile := Profile.new()
	profile.path="user://economy-%s.json" % name
	cleanup.append(profile.path)
	return profile

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await carried_storage()
	await sell_products()
	await legacy_vault()
	await overflow()
	await lifetime_tally()
	await loadout_round_trip()
	await issue_gear()
	await settlement()
	for kind in Catalog.ITEMS:
		check(Catalog.item_value({"kind":kind})>0,"Every catalog item has positive value: "+kind)
	for path in cleanup:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
	print("ECONOMY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

# --- carried storage <-> vault ------------------------------------------------
func carried_storage() -> void:
	var profile := scratch("carried")
	profile.sanitize_storage()
	Catalog.add_item(profile.data.pocket,"relic")
	Catalog.place_item(profile.data.bags[0],Catalog.make_equipment("weapon",2,5))
	var outcome := profile.bank_carried_items()
	check(int(outcome.stored)==2,"Existing carried items bank without loss")
	check(profile.data.pocket.items.is_empty() and profile.data.bags[0].items.is_empty(),"Banking removes originals")
	check(profile.warehouse_count()==2,"The vault holds both entries")
	check(profile.data.warehouse is Dictionary and profile.data.warehouse.gw==15 and profile.data.warehouse.gh==15,"The vault is a 15x15 container")
	for item in profile.warehouse_items():
		var size := Catalog.item_size(item)
		check(int(item.x)>=0 and int(item.y)>=0 and int(item.x)+size.x<=15 and int(item.y)+size.y<=15,"A banked item sits inside the grid: "+str(item))
	outcome=profile.bank_carried_items()
	check(int(outcome.stored)==0 and profile.warehouse_count()==2,"Repeated banking cannot duplicate items")
	check(profile.withdraw_item(1),"A vault weapon can be prepared for the next expedition")
	check(profile.data.bags[0].items[0].tier==5 and profile.data.bags[0].items[0].weapon==2,"Withdrawal preserves equipment metadata")
	check(profile.warehouse_count()==1,"Withdrawal removes the entry from the vault")
	profile.bank_carried_items()
	var initial: int=profile.data.coins
	var value: int=profile.warehouse_value()
	check(profile.sell_items([0,1,1,-1,999])==value,"Sale pays valid selections exactly once")
	check(profile.data.coins==initial+value and profile.warehouse_count()==0,"Sale removes stock and adds exact currency")
	check(profile.sell_items([0])==0,"Empty stock cannot be resold")
	# Stacks pay per unit, and a camp-issued supply is worth nothing on the market.
	check(profile.bank_item({"kind":"scrap","count":6}),"A stack of scrap can be stored")
	check(profile.bank_item({"kind":"medicine","provision":true}),"A camp supply can be stored")
	check(profile.sell_items([0,1])==192 and profile.warehouse_count()==1,"Stacks pay each unit; camp-issued supplies cannot be sold for profit")

# --- the home shop sells real instances ---------------------------------------
# The "出售" page must delete the thing it sells: a sold copy leaves the storage it
# really sits in — the vault cell first, then the pocket and the bag — instead of
# being an abstract counter move.
func sell_products() -> void:
	var profile := scratch("sell_products")
	profile.sanitize_storage()
	profile.data.coins=0
	# One pile of six wheat seated at a known vault cell, plus a carried pile of two,
	# so the sale order between the storages is observable.
	var vault: Dictionary=profile.data.warehouse
	vault.items.append({"kind":"wheat","count":6,"x":3,"y":4,"rot":false,"valued":true})
	Catalog.place_loot(profile.data.bags[0],"wheat")
	Catalog.place_loot(profile.data.bags[0],"wheat")
	check(profile.product_count("wheat")==8,"The holding counts vault units and carried units together")
	var sold := profile.sell_product("wheat",1)
	check(int(sold.sold)==1 and int(sold.coins)==9,"Selling one copy pays the catalog unit price")
	check(profile.vault_items().size()==1,"A partial sale keeps the vault pile in its cell")
	check(int(profile.vault_items()[0].count)==5,"...and trims that stack's count in place")
	check(profile.data.bags[0].items.size()==1 and int(profile.data.bags[0].items[0].count)==2,"The vault drains before the carried bag")
	sold=profile.sell_product("wheat",5)
	check(int(sold.sold)==5 and profile.warehouse_count()==0,"Selling the rest deletes the vault entity")
	check(profile.data.bags[0].items.size()==1,"still leaving the carried pile untouched")
	check(int(profile.data.coins)==54,"The coins equal units sold times the unit price")
	sold=profile.sell_product("wheat",3)
	check(int(sold.sold)==2 and int(sold.missing)==1,"A sale larger than the holding sells only what exists")
	check(profile.data.bags[0].items.is_empty() and profile.product_count("wheat")==0,"...and deletes the carried copies it did sell")
	sold=profile.sell_product("wheat",1)
	check(int(sold.sold)==0 and int(profile.data.coins)==72,"Nothing to sell pays nothing")
	# A camp-issued supply is not the shop's to sell, same rule as the exchange.
	vault.items.append({"kind":"wheat","count":6,"x":0,"y":0,"rot":false,"valued":true,"provision":true})
	sold=profile.sell_product("wheat",6)
	check(int(sold.sold)==0 and profile.warehouse_count()==1,"Provision-marked produce cannot be sold")
	profile.warehouse_remove(0)
	# A spill entry shares the vault's index space, so it sells like grid stock.
	var spill = profile.data.warehouse_spill
	spill.append({"kind":"wheat","count":2,"x":0,"y":0,"rot":false,"valued":true})
	sold=profile.sell_product("wheat",2)
	check(int(sold.sold)==2 and profile.warehouse_count()==0,"Spilled stock sells and leaves the vault")
	check(profile.data.trade_history.size()==4,"Each accepted sale is recorded in the trade history")
	profile.save_profile()
	var loaded := Profile.new()
	loaded.path=profile.path
	loaded.load_profile()
	check(loaded.warehouse_count()==0 and loaded.product_count("wheat")==0,"The sold-out storage survives a save/load")
	check(int(loaded.data.coins)==90,"...with the money on disk")

# --- the old flat array -------------------------------------------------------
func legacy_vault() -> void:
	var profile := scratch("legacy")
	var raw: Dictionary=profile.data.duplicate(true)
	# What a pre-grid save looks like: a flat list, coordinates meaningless.
	raw["warehouse"]=[{"kind":"amulet","x":500,"y":500},{"kind":"scrap","count":6},{"kind":"relic"},{"kind":"not_a_kind"}]
	var file := FileAccess.open(profile.path,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var loaded := Profile.new()
	loaded.path=profile.path
	loaded.load_profile()
	check(loaded.data.warehouse is Dictionary and int(loaded.data.warehouse.gw)==15,"A pre-grid save upgrades to a 15x15 container")
	check(loaded.warehouse_count()==3,"Every valid entry survives the upgrade")
	check(loaded.data.loot_value==0,"Old vault contents are not counted as new loot")
	for item in loaded.warehouse_items():
		var size := Catalog.item_size(item)
		check(int(item.x)>=0 and int(item.x)+size.x<=15 and int(item.y)>=0 and int(item.y)+size.y<=15,"A migrated entry sits inside the grid: "+str(item))
	check(loaded.data.trade_history.size()==0,"The upgrade leaves an empty trade history")
	loaded.save_profile()
	var again := Profile.new()
	again.path=profile.path
	again.load_profile()
	check(again.warehouse_count()==3,"A migrated save survives a second round trip")
	again.apply_data({"version":1})
	check(again.warehouse_count()==0,"Older account saves cannot inherit another account's vault")

# --- a full grid --------------------------------------------------------------
func overflow() -> void:
	var profile := scratch("overflow")
	var cells := Catalog.WAREHOUSE_GRID.x*Catalog.WAREHOUSE_GRID.y
	# Fill the grid directly: 225 one-cell trinkets, one per cell. Going through the
	# deposit path would re-run the packing search 225 times for the same answer.
	var vault: Dictionary=profile.data.warehouse
	for y in Catalog.WAREHOUSE_GRID.y:
		for x in Catalog.WAREHOUSE_GRID.x:
			vault.items.append({"kind":"wind_chime","x":x,"y":y,"rot":false,"valued":true})
	check(profile.warehouse_count()==cells and Catalog.container_free(vault)==0,"A 15x15 grid holds 225 one-cell items")
	check(not profile.bank_item({"kind":"wind_chime"}),"A manual deposit is refused once the grid is full")
	check(not profile.bank_item({"kind":"scrap","count":6}),"A stack that only half fits is refused whole")
	check(profile.warehouse_count()==cells,"A refusal leaves the vault exactly as it was")
	# A settlement never refuses: what does not fit waits in the spill list.
	var blade := Catalog.make_equipment("weapon",2,5)
	var outcome := profile.bank_carried_items([blade,{"kind":"scrap","count":6}])
	# The counts are units, not entries: the weapon is one unit, the scrap stack six.
	check(int(outcome.spilled)==7 and int(outcome.stored)==0,"A full grid spills a settlement instead of destroying it")
	check(profile.warehouse_count()==cells+2,"Spilled entries stay part of the vault")
	check(profile.product_count("scrap")==6,"Spilled stacks are still counted")
	check(profile.warehouse_value()>=Catalog.market_value(blade),"The vault's live worth includes the spill")
	check(profile.withdraw_item(cells),"A spilled entry can still be taken out")
	check(profile.warehouse_count()==cells+1,"and leaves the vault once taken")

# --- the lifetime tally -------------------------------------------------------
func lifetime_tally() -> void:
	var profile := scratch("tally")
	var blade := Catalog.make_equipment("weapon",2,5)
	var worth := Catalog.market_value(blade)
	check(profile.data.loot_value==0,"A fresh profile has no loot tally")
	check(profile.bank_item(blade),"A weapon can be stored by hand")
	check(profile.data.loot_value==worth,"Storing a weapon counts its value once")
	check(profile.withdraw_item(0),"and can be taken back out")
	var back: Dictionary=profile.data.bags[0].items[0]
	check(bool(back.get("valued",false)),"The value stamp rides on the item itself")
	check(profile.bank_item(back),"and stored again")
	check(profile.data.loot_value==worth,"A withdraw/store loop cannot count one weapon twice")
	check(profile.warehouse_value()>=worth,"The live vault worth is a separate number from the tally")

# --- the worn kit in the save file --------------------------------------------
func loadout_round_trip() -> void:
	var profile := scratch("loadout")
	profile.data.loadout={"weapon":Catalog.make_equipment("weapon",2,5),"gear":[{},{},{"kind":"gear","gear":2,"tier":4}],"charm":[{"kind":"charm"},{}],"slots":[{"kind":"ammo","count":3},{},{}]}
	profile.save_profile()
	var loaded := Profile.new()
	loaded.path=profile.path
	loaded.load_profile()
	check(int(loaded.data.loadout.weapon.weapon)==2 and int(loaded.data.loadout.weapon.tier)==5,"The worn weapon survives a save/load")
	check(int(loaded.data.loadout.gear[2].gear)==2 and not loaded.data.loadout.gear[0],"Each gear socket keeps its own piece")
	check(int(loaded.data.loadout.charm[0].kind=="charm"),"A charm keeps its socket")
	check(int(loaded.data.loadout.slots[0].count)==3,"A quick socket keeps its stack")
	check(loaded.data.loadout.weapon.has("x")==false,"A worn socket carries no grid position")
	loaded.apply_data({"version":1,"loadout":{"weapon":{"kind":"relic"},"gear":"junk","charm":[{},{}],"slots":[{"kind":"not_a_kind"}]}})
	check(loaded.data.loadout.weapon.is_empty(),"A relic cannot be worn as a weapon")
	check(loaded.data.loadout.gear.size()==3 and loaded.data.loadout.gear[0].is_empty(),"A malformed gear list leaves the sockets empty")
	check(loaded.data.loadout.slots.size()==3 and loaded.data.loadout.slots[0].is_empty(),"An unknown kind is dropped from the quick bar")

# --- camp issue gear is bought ------------------------------------------------
func issue_gear() -> void:
	var profile := scratch("gear")
	check(profile.data.gear==-1,"A new Watcher owns no issue gear")
	check(Catalog.gear_of(-1).is_empty(),"An empty gear slot answers with an empty table")
	profile.data.coins=1000
	var buy := profile.buy_gear(0)
	check(bool(buy.ok) and profile.data.gear==0 and profile.data.coins==820,"The first piece costs its full price")
	buy=profile.buy_gear(1)
	check(bool(buy.ok) and profile.data.gear==1 and profile.data.coins==580,"A dearer piece settles the price difference")
	buy=profile.buy_gear(2)
	check(bool(buy.ok) and profile.data.gear==2 and profile.data.coins==700,"A cheaper piece refunds the difference")
	check(profile.warehouse_count()==0,"Exchanging issue gear never drops an item into the vault")
	profile.data.coins=100
	buy=profile.buy_gear(1)
	check(not bool(buy.ok) and profile.data.gear==2 and profile.data.coins==100,"A swap that cannot be paid for changes nothing at all")
	check(int(buy.get("short",0))==20,"The refusal reports how much was missing")
	check(not bool(profile.buy_gear(2).ok),"Buying the piece already worn is refused")

# --- settlement ---------------------------------------------------------------
func settlement() -> void:
	var session := TideSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({"hero":0,"loadout":{"weapon":Catalog.make_equipment("weapon",2,5),"slots":[{"kind":"ammo","count":2}]}})
	session.launch(false,1729)
	var p: Dictionary=session.players[1]
	check(int(p.weapon)==2 and int(session.kit_weapon(p).weapon)==2,"The saved weapon is in hand at spawn")
	check(session.issue_weapon_active(p)==false,"so the issue weapon is no longer in use")
	check(session.item_slot(p,0).kind=="ammo" and int(session.item_slot(p,0).count)==2,"The saved quick bar travels into the raid")
	Catalog.add_item(p.pocket,"amulet")
	p.status="extracted"
	session.objectives=1
	session.settle()
	var reward: Dictionary=session.results[1]
	check(reward.coins==reward.shared,"Extraction pays objectives only; loot requires sale")
	check(int(reward.loadout.weapon.weapon)==2 and not reward.loadout.slots[0].is_empty(),"Extraction keeps the worn kit in the loadout")
	check(reward.loot==Catalog.market_total(p.pocket.items),"Worn kit is not priced as fresh loot on top of being kept")
	session.solo({"hero":0,"loadout":{"weapon":Catalog.make_equipment("weapon",2,5)}})
	session.launch(false,1729)
	p=session.players[1]
	Catalog.add_item(p.pocket,"amulet")
	Catalog.add_item(p.backpack,"relic")
	session.spill_storage(p)
	p.status="dead"
	session.settle()
	reward=session.results[1]
	check(reward.pocket.items.size()==1 and reward.bags[0].items.is_empty(),"Death banks only the safe pocket, never the dropped loot")
	check(reward.loadout.weapon.is_empty() and reward.loadout.slots[0].is_empty(),"Death scatters the worn kit and leaves an empty loadout")
	check(reward.loot==Catalog.market_total(reward.pocket.items),"The report prices only what came home")
	session.queue_free()
