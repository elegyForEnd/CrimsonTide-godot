extends SceneTree
## Camp-side storage editing: the远征行囊 panel's rules.
##
## The camp has no session authority (`session.running` is false, so
## `session.action()` does nothing), which is why these edits go through
## `camp_storage.gd` and are written to the save file as they happen. This file
## drives that module directly, with no UI, so the rules are pinned down before the
## panel is drawn.
const CampStorage = preload("res://scripts/camp_storage.gd")

var failures := 0
var checks := 0
var profile
var session
var p: Dictionary

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func drop(from: String, index: int, to: String, cell: Vector2i, rot: bool = false) -> bool:
	return CampStorage.drop(profile,session,p,{"slot":from,"index":index,"rot":rot},{"slot":to,"cell":cell})

func onto(from: String, index: int, zone: String) -> bool:
	return CampStorage.drop(profile,session,p,{"slot":from,"index":index,"rot":false},{"zone":zone})

## A known starting point: an empty white pack, an empty pocket, an empty vault.
## Every section starts here, so one section's leftovers cannot explain another's
## result.
func reset_storage() -> void:
	p["backpack"]=Catalog.make_bag("white")
	p.backpack["gw"]=Catalog.BAG_TIERS[0].grid.x
	p.backpack["gh"]=Catalog.BAG_TIERS[0].grid.y
	p["bags"]=[]
	p["pocket"]=Catalog.make_container([],Catalog.POCKET_GRID)
	p["equipped"]=session.empty_equipment()
	p["slots"]=session.empty_item_slots()
	p["weapon"]=Catalog.starter_index(int(p.hero))
	profile.data["warehouse"]=profile.make_vault()
	profile.data["warehouse_spill"]=[]
	profile.data["loot_value"]=0
	CampStorage.persist(profile,session,p)

func run() -> void:
	profile=Profile.new()
	profile.path="user://camp-storage.json"
	profile.data.coins=1000
	profile.sanitize_storage()
	session=TideSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({"hero":0})
	p=session.players[1]

	await travelling()
	await equip_and_unequip()
	await item_bar()
	await pack_off()
	await pack_swap()
	await take_off_rules()
	await worn_drag()
	await double_click_rules()
	await pile_units()
	await bulk_and_reload()

	session.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.path))
	await process_frame
	print("CAMP STORAGE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

# --- carried <-> vault --------------------------------------------------------
func travelling() -> void:
	reset_storage()
	Catalog.add_item(p.backpack,"scrap")
	check(drop("backpack",0,"warehouse",Vector2i(3,4)),"The bag hands an item to the vault")
	check(profile.warehouse_count()==1 and p.backpack.items.is_empty(),"and the item really leaves the bag")
	var stored: Dictionary=profile.warehouse_item(0)
	check(int(stored.x)>=0 and int(stored.y)>=0,"A deposited item is seated in the grid")
	check(drop("warehouse",0,"pocket",Vector2i(2,2)),"The vault hands an item back to the pocket")
	check(p.pocket.items.size()==1 and int(p.pocket.items[0].x)==2 and int(p.pocket.items[0].y)==2,"and honours the cell it was dropped on")
	check(profile.warehouse_count()==0,"The vault is empty again")
	# A stack gives up one unit, like the item bar does.
	Catalog.add_item(p.backpack,"scrap")
	Catalog.add_item(p.backpack,"scrap")
	check(drop("backpack",0,"warehouse",Vector2i(0,0)),"One unit of a stack can be stored")
	check(int(p.backpack.items[0].get("count",1))==1,"and exactly one unit leaves the pile")

# --- worn sockets -------------------------------------------------------------
func equip_and_unequip() -> void:
	reset_storage()
	Catalog.place_item(p.backpack,Catalog.make_equipment("weapon",2,5))
	var at: int = p.backpack.items.size()-1
	check(onto("backpack",at,"weapon"),"A field weapon can be worn from the camp panel")
	check(int(p.weapon)==2 and int(session.kit_weapon(p).weapon)==2,"and it is the weapon in hand")
	check(int(profile.data.loadout.weapon.weapon)==2,"and the save file says so immediately")
	Catalog.place_item(p.backpack,Catalog.make_equipment("gear",2,4))
	check(onto("backpack",p.backpack.items.size()-1,"gear2"),"Boots land in their own gear socket")
	check(int(session.kit_gear(p)[2].gear)==2,"and not in the armour socket")
	check(int(profile.data.loadout.gear[2].gear)==2,"and the save file follows")
	# Taking the weapon off puts the issue weapon back in hand.
	check(drop("weapon",0,"warehouse",Vector2i(0,0)),"Worn gear can go straight into the vault")
	check(session.kit_weapon(p).is_empty() and int(p.weapon)==Catalog.starter_index(0),"and the issue weapon is back in hand")

# --- the item bar -------------------------------------------------------------
func item_bar() -> void:
	reset_storage()
	Catalog.add_item(p.backpack,"crystal")
	check(onto("backpack",0,"slot1"),"A carried item can be parked in the quick bar")
	check(session.item_slot(p,1).kind=="crystal","and it is in the socket that was aimed at")
	check(int(profile.data.loadout.slots[1].get("count",1))>=1 and not profile.data.loadout.slots[1].is_empty(),"and the save file holds the bar")
	check(drop("slot:1",0,"backpack",Vector2i(0,0)),"and taken back out")
	check(session.item_slot(p,1).is_empty() and p.backpack.items.size()==1,"with the socket left empty")
	# Worn gear can also go into a quick socket.
	Catalog.place_item(p.backpack,Catalog.make_equipment("weapon",1,3))
	check(onto("backpack",p.backpack.items.size()-1,"slot0"),"The bar takes even a 2x2 weapon")
	check(session.item_slot(p,0).kind=="weapon","and holds it in one socket")

# --- the worn backpack --------------------------------------------------------
func pack_off() -> void:
	reset_storage()
	check(CampStorage.unwear_bag(profile,session,p,true),"An empty pack can be taken off")
	check(str(p.backpack.key)=="white","and a plain pack is what is left on the back")
	check(profile.warehouse_count()==1,"the old pack is in the vault as a loose item")
	var packs := 0
	for item in profile.warehouse_items():
		if str(item.kind)=="backpack": packs+=1
	check(packs==1,"exactly one loose pack was stored")
	check(profile.sell_items([0])>0,"A loose pack can be sold at the exchange")
	# A pack with loot in it: the loot is rehoused, then the pack comes off.
	reset_storage()
	p.backpack=Catalog.make_bag("purple")
	p.backpack["gw"]=6
	p.backpack["gh"]=6
	Catalog.add_item(p.backpack,"scrap")
	CampStorage.persist(profile,session,p)
	var before: int=profile.product_count("scrap")
	check(CampStorage.unwear_bag(profile,session,p,true),"A loaded pack can be taken off when its loot has a home")
	check(profile.product_count("scrap")==before,"its contents are kept")
	check(str(p.backpack.key)=="white","and the pack left on the back is a plain one")
	# A pack whose loot cannot go anywhere still comes off: the 3x3 issue pack keeps what
	# it can, most precious first, and the rest falls on the camp floor.
	reset_storage()
	p.backpack=Catalog.make_bag("red")
	p.backpack["gw"]=8
	p.backpack["gh"]=8
	Catalog.add_item(p.backpack,"scrap")
	# Every entry needs a real seat: the save round-trip in `persist()` drops items
	# that do not look like placed loot.
	var gear: Dictionary=Catalog.make_equipment("gear",1,4)
	gear["x"]=2
	gear["y"]=0
	gear["rot"]=false
	p.backpack.items.append(gear)
	p.backpack.items.append({"kind":"relic","x":4,"y":0,"rot":false})
	for i in 4:
		Catalog.add_item(p.pocket,"relic")
	CampStorage.persist(profile,session,p)
	check(Catalog.container_count(p.backpack,"gear")==1,"the pack holds the armour before the swap")
	var vault: Dictionary=profile.data.warehouse
	for y in Catalog.WAREHOUSE_GRID.y:
		for x in Catalog.WAREHOUSE_GRID.x:
			vault.items.append({"kind":"wind_chime","x":x,"y":y,"rot":false,"valued":true})
	var floored: Array = []
	CampStorage.spill_sink=func(item: Dictionary) -> void:
		floored.append(item)
	check(CampStorage.unwear_bag(profile,session,p,true),"a pack comes off even when its loot has nowhere to go")
	check(str(p.backpack.key)=="white","and the pack left on the back is the 3x3 issue pack")
	check(Catalog.container_count(p.backpack,"scrap")==1,"the issue pack took what it could hold")
	check(Catalog.container_count(p.backpack,"gear")==1,"most precious first: the gold armour is kept")
	check(floored.size()>0,"and everything that did not fit fell on the floor")
	var packs_on_floor := 0
	for item in floored:
		if str(item.kind)=="backpack": packs_on_floor+=1
	check(packs_on_floor==1,"the old pack itself was floored too, since the vault was full")
	check(profile.warehouse_count()==Catalog.WAREHOUSE_GRID.x*Catalog.WAREHOUSE_GRID.y,"the full vault was left alone")
	CampStorage.spill_sink=Callable()

# --- N units of a pile at a time: the right-click hand ------------------------

## A whole pile moves on a plain drag, so taking part of one is what the right-click
## hand is for: one unit a click, aimed where the player lets go.
func pile_units() -> void:
	reset_storage()
	p.backpack=Catalog.make_bag("green")
	p.backpack["gw"]=5
	p.backpack["gh"]=5
	Catalog.add_item(p.backpack,"crystal")
	p.backpack.items[0]["count"]=5
	check(Catalog.container_count(p.backpack,"crystal")==1,"a pile of five sits in the bag")
	# The whole pile goes to the vault on a plain drag.
	check(drop("backpack",0,"warehouse",Vector2i(2,2)),"a plain drag takes the whole pile to the vault")
	check(Catalog.container_count(p.backpack,"crystal")==0,"leaving nothing behind in the bag")
	check(profile.warehouse_count()==1 and int(profile.vault_items()[0].get("count",1))==5,"and the vault holds all five in one pile")
	# Part of a pile back out: three units, aimed at a cell.
	check(CampStorage.vault_units_out(profile,session,p,0,3,"backpack",Vector2i(0,0)),"three units come back out of the vault")
	check(int(profile.vault_items()[0].get("count",1))==2,"the vault pile is trimmed in place, not moved")
	check(Catalog.container_count(p.backpack,"crystal")==1 and int(p.backpack.items[0].get("count",1))==3,"and three units are in the bag")
	# And part of a pile in: two units.
	check(CampStorage.vault_units_in(profile,session,p,"backpack",0,2),"two units go back in")
	check(int(p.backpack.items[0].get("count",1))==1,"leaving one unit in the bag")
	check(int(profile.vault_items()[0].get("count",1))==4,"and four in the vault's pile")
	# A pile the destination cannot take changes nothing at all.
	var vault: Dictionary=profile.data.warehouse
	for y in Catalog.WAREHOUSE_GRID.y:
		for x in Catalog.WAREHOUSE_GRID.x:
			vault.items.append({"kind":"wind_chime","x":x,"y":y,"rot":false,"valued":true})
	check(CampStorage.vault_units_in(profile,session,p,"backpack",0,1)==false,"a full vault refuses the handful")
	check(int(p.backpack.items[0].get("count",1))==1,"and the source pile is untouched by the refusal")
	# Taking a handful to the ground hands back its own entry.
	var handful: Dictionary=CampStorage.vault_take_units(profile,0,2)
	check(not handful.is_empty() and int(handful.get("count",1))==2,"a handful can be taken out of a vault pile")
	check(int(profile.vault_items()[0].get("count",1))==2,"trimming the vault pile for it")
	# Session-side movers for the carried containers.
	reset_storage()
	p.backpack=Catalog.make_bag("green")
	p.backpack["gw"]=5
	p.backpack["gh"]=5
	Catalog.add_item(p.backpack,"crystal")
	p.backpack.items[0]["count"]=4
	check(session.move_units(p,"backpack","pocket",0,2,Vector2i(0,0),false),"the same hand moves part of a pile bag to pocket")
	check(int(p.backpack.items[0].get("count",1))==2,"splitting the source pile")
	check(Catalog.container_count(p.pocket,"crystal")==1 and int(p.pocket.items[0].get("count",1))==2,"and seating two units in the pocket")
	check(session.move_units(p,"backpack","pocket",0,9,Vector2i(0,0),false),"asking for more than the pile holds is clamped")
	check(Catalog.container_count(p.backpack,"crystal")==0,"taking the rest of the pile")
	var taken: Dictionary=session.take_units(p,"pocket",0,1)
	var left := 0
	for item in p.pocket.items:
		if str(item.kind)=="crystal": left+=int(item.get("count",1))
	check(int(taken.get("count",1))==1 and left==3,"a handful can be taken off a carried pile")

# --- spare packs --------------------------------------------------------------

func pack_swap() -> void:
	reset_storage()
	var spare := Catalog.make_bag("gold")
	spare["gw"]=7
	spare["gh"]=7
	check(drop("cab",0,"warehouse",Vector2i(1,1))==false,"with no spare there is nothing to move")
	p["bags"]=[spare]
	check(Catalog.swap_bags(p,0),"A spare pack can be worn")
	check(str(p.backpack.key)=="gold" and str(p.bags[0].key)=="white","and the old one becomes the spare")
	check(drop("cab",0,"warehouse",Vector2i(1,1)),"A spare pack can be moved into the vault")
	check(p.bags.is_empty() and profile.warehouse_count()==1,"and it leaves the cabinet")
	check(profile.sell_items([0])>0,"A loose pack can be sold at the exchange")

# --- taking a piece off the body ------------------------------------------------
## The camp take-off (double tap on a socket, Ctrl+left, F, and the panel's "卸"
## button all share it): the carried backpack first, then the vault. The pocket is
## not a camp landing spot at all, and a refusal never drops the piece.
func take_off_rules() -> void:
	reset_storage()
	Catalog.place_item(p.backpack,Catalog.make_equipment("weapon",2,3))
	check(onto("backpack",0,"weapon"),"a blade is worn for the take-off test")
	check(CampStorage.stow_socket(profile,session,p,"weapon"),"the camp take-off goes through")
	check(Catalog.container_count(p.backpack,"weapon")==1,"the piece lands back in the carried backpack")
	check(profile.warehouse_count()==0,"and the vault is untouched while the bag has room")
	check(Catalog.container_count(p.pocket,"weapon")==0,"the pocket is never a camp landing spot")
	# A packed bag: the vault is the camp's second seat.
	check(onto("backpack",0,"weapon"),"the blade is worn again")
	for i in 9:
		Catalog.add_item(p.backpack,"crystal")
	check(Catalog.container_free(p.backpack)==0,"the carried bag is packed solid")
	check(CampStorage.stow_socket(profile,session,p,"weapon"),"the take-off still goes through")
	check(profile.warehouse_count()==1,"and the piece landed in the vault instead")
	check(Catalog.container_count(p.pocket,"weapon")==0,"still not in the pocket")
	# Both full: a flat refusal that keeps the piece on the body.
	reset_storage()
	Catalog.place_item(p.backpack,Catalog.make_equipment("gear",0,4))
	check(onto("backpack",0,"gear0"),"gold armour is worn for the refusal test")
	for i in 9:
		Catalog.add_item(p.backpack,"crystal")
	var vault: Dictionary=profile.data.warehouse
	for y in Catalog.WAREHOUSE_GRID.y:
		for x in Catalog.WAREHOUSE_GRID.x:
			vault.items.append({"kind":"wind_chime","x":x,"y":y,"rot":false,"valued":true})
	check(Catalog.container_free(p.backpack)==0 and profile.warehouse_value()>0,"bag and vault are both solid")
	check(CampStorage.stow_socket(profile,session,p,"gear0")==false,"a full bag and a full vault refuse the take-off")
	check(not session.kit_gear(p)[0].is_empty(),"and the piece stays on the body")

# --- dragging a worn piece ------------------------------------------------------
## The sockets are drag sources as well: a worn piece can be carried to the quick
## bar, to another socket, or straight into the vault.
func worn_drag() -> void:
	reset_storage()
	Catalog.place_item(p.backpack,Catalog.make_equipment("gear",0,3))
	check(onto("backpack",0,"gear0"),"armour is worn for the socket drag")
	check(CampStorage.drop(profile,session,p,{"slot":"gear0","index":0,"rot":false},{"zone":"slot0"}),"a worn piece can be dragged into the quick bar")
	check(session.item_slot(p,0).kind=="gear","and it is in the socket that was aimed at")
	check(session.kit_gear(p)[0].is_empty(),"with the body slot left empty")
	check(CampStorage.drop(profile,session,p,{"slot":"slot0","index":0,"rot":false},{"zone":"gear0"}),"and dragged back onto its own socket")
	check(int(session.kit_gear(p)[0].gear)==0,"which wears it again")
	check(session.item_slot(p,0).is_empty(),"and empties the bar socket it came from")
	# A socket only takes its own kind: a sight does not fit the weapon slot.
	Catalog.place_item(p.backpack,Catalog.make_equipment("weapon",1,3))
	check(int(session.kit_weapon(p).get("weapon",-1))!=1,"no field weapon is in hand yet")
	check(CampStorage.drop(profile,session,p,{"slot":"backpack","index":0,"rot":false},{"zone":"weapon"}),"a field weapon can be worn")
	check(CampStorage.drop(profile,session,p,{"slot":"gear0","index":0,"rot":false},{"zone":"weapon"})==false,"but armour cannot be dragged into the weapon socket")
	check(int(session.kit_weapon(p).get("weapon",-1))==1,"so the weapon slot still holds the weapon")
	# And into the vault: the piece leaves the body for storage.
	check(CampStorage.drop(profile,session,p,{"slot":"gear0","index":0,"rot":false},{"slot":"warehouse","cell":Vector2i(2,2)}),"a worn piece can be dragged into the vault")
	check(session.kit_gear(p)[0].is_empty(),"and it leaves the body")
	check(profile.warehouse_count()==1,"the vault has it")

# --- the double-click verb ----------------------------------------------------
## In the camp a double-click is a storage verb and never a battle one: a wearable
## takes its socket (swapping with what is worn, the displaced piece landing in the
## vault cell the other came from), and everything else goes into the carried
## backpack. The item bar is deliberately out of reach — it can only be filled by
## dragging something onto it.
func double_click_rules() -> void:
	reset_storage()
	profile.bank_item({"kind":"scrap"})
	check(CampStorage.quick_equip(profile,session,p,"warehouse",profile.warehouse_count()-1),"A vault item can be collected by double-clicking")
	check(Catalog.container_count(p.backpack,"scrap")==1,"a plain vault item lands in the carried backpack")
	check(profile.warehouse_count()==0,"and it leaves the vault")
	check(session.item_slot(p,0).is_empty() and session.item_slot(p,1).is_empty() and session.item_slot(p,2).is_empty(),"and a double-click never fills the quick bar")

	# An empty socket means wear it.
	profile.bank_item(Catalog.make_equipment("gear",1,4))
	check(CampStorage.quick_equip(profile,session,p,"warehouse",profile.warehouse_count()-1),"A vault gear piece can be worn by double-clicking")
	check(int(session.kit_gear(p)[1].gear)==1,"and it is in its own gear socket")

	# A filled socket means swap: the piece coming off takes the vault cell the other
	# one came out of, which is what makes the gesture read as "these two changed
	# places" instead of "my gear went into storage somewhere".
	profile.bank_item(Catalog.make_equipment("gear",1,5))
	var at: int = profile.warehouse_count()-1
	var seat := Vector2i(int(profile.warehouse_item(at).x),int(profile.warehouse_item(at).y))
	var displaced := int(session.kit_gear(p)[1].tier)
	check(CampStorage.quick_equip(profile,session,p,"warehouse",at),"A vault piece swaps with the worn one")
	check(int(session.kit_gear(p)[1].tier)==5,"the vault piece is worn")
	check(int(profile.warehouse_item(0).tier)==displaced,"the worn piece is the one that left the body")
	check(Vector2i(int(profile.warehouse_item(0).x),int(profile.warehouse_item(0).y))==seat,"and it lands in the cell the other one came from")

	# Consumables are not a special case in the camp: they are cargo like any other.
	reset_storage()
	profile.bank_item({"kind":"medicine"})
	CampStorage.quick_equip(profile,session,p,"warehouse",0)
	check(Catalog.container_count(p.backpack,"medicine")==1,"A consumable from the vault goes to the backpack in the camp")
	check(session.item_slot(p,0).is_empty(),"and still never reaches the quick bar")

	# A carried item is treated the same way; the vault still takes what the bag
	# cannot, so the item is never simply refused.
	reset_storage()
	Catalog.add_item(p.backpack,"medicine")
	check(CampStorage.quick_equip(profile,session,p,"backpack",0),"A carried item can be double-clicked too")
	check(Catalog.container_count(p.backpack,"medicine")==1 or profile.product_count("medicine")==1,"and it stays carried or moves to the vault, never lost")

	check(CampStorage.quick_equip(profile,session,p,"backpack",9999)==false,"A stale index is refused rather than guessed")

# --- bulk + persistence -------------------------------------------------------
func bulk_and_reload() -> void:
	reset_storage()
	Catalog.add_item(p.backpack,"scrap")
	Catalog.add_item(p.pocket,"amulet")
	Catalog.add_item(p.backpack,"medicine")
	var outcome: Dictionary=CampStorage.bank_all(profile,session,p)
	check(int(outcome.get("stored",0))==3,"Everything carried is banked at once")
	check(p.backpack.items.is_empty() and p.pocket.items.is_empty(),"and the carried storage is empty afterwards")
	check(profile.warehouse_count()==3,"the vault holds all three")
	# The save file has to agree with the live player, because a raid launched from
	# the camp re-reads it.
	profile.save_profile()
	var reloaded := Profile.new()
	reloaded.path=profile.path
	reloaded.load_profile()
	check(reloaded.warehouse_count()==3,"The vault survives a save/load round trip")
	check(reloaded.product_count("scrap")==1 and reloaded.product_count("amulet")==1 and reloaded.product_count("medicine")==1,"and so does every entry in it")
	check(reloaded.data.loot_value>0,"banking through the camp still pays the lifetime tally")
	# Now wear something, save, and check the next raid is configured with it.
	reset_storage()
	Catalog.place_item(p.backpack,Catalog.make_equipment("gear",2,4))
	check(onto("backpack",0,"gear2"),"A gear piece can be worn")
	profile.save_profile()
	var with_kit := Profile.new()
	with_kit.path=profile.path
	with_kit.load_profile()
	check(int(with_kit.data.loadout.gear[2].gear)==2,"The worn kit is in the save file")
	var player: Dictionary=session.make_player(1,{"hero":0,"gear":profile.data.gear,"pocket":with_kit.data.pocket,"bags":with_kit.data.bags,"bag_key":with_kit.data.bag_key,"loadout":with_kit.data.loadout})
	check(int(session.kit_gear(player)[2].gear)==2,"and is worn again when the next raid is configured")
	check(int(player.weapon)==Catalog.starter_index(0),"with the issue weapon when no field weapon is saved")
