extends RefCounted
## Camp-side storage editing: the远征行囊 panel behind TAB in the camp.
##
## In a raid the session is authoritative — every edit is a `session.action()` that
## only the host performs. The camp has no such authority: `session.running` is
## false, so `perform()` drops every action on the floor, and the camp edits the
## local save instead. This module is that editor.
##
## It owns no placement rules of its own. Moving something between the carried
## backpack, the dimensional pocket, the worn sockets, the item bar and the spare
## bags goes through the very same `TideSession` methods a raid uses
## (`move_between`, `equip_item`, `clear_worn_slot`, `slot_put`, `slot_take`,
## `resolve_drop`), so a piece of kit behaves identically in both places. What the
## module adds is the vault — the one storage that lives in the save file rather
## than in the player dictionary — plus a save after every accepted change, because
## the camp is local and there is no later settlement to write the edits home.
##
## The panel reads the *live player dictionary*, the same one the raid hands to the
## same drawing code; `persist()` is what keeps the save file in step with it.

const VAULT := "warehouse"

# --- profile <-> live player --------------------------------------------------

## Writes the worn kit and the carried containers back into the save file. Called
## after every accepted edit, so a crash, a quit or a raid that starts from the camp
## can only ever see the state the player is looking at.
static func persist(profile, session, p: Dictionary) -> void:
	if profile == null or p.is_empty(): return
	var bags: Array=session.saved_bags(p,true)
	if bags.is_empty(): return
	profile.data["pocket"]=p.get("pocket",{})
	profile.data["bags"]=bags
	profile.data["bag_key"]=str(bags[0].get("key",Catalog.DEFAULT_BAG_KEY))
	profile.data["loadout"]={"weapon":p.get("equipped",{}).get("weapon",{}),"gear":p.get("equipped",{}).get("gear",[{},{},{}]),"charm":p.get("equipped",{}).get("charm",[{},{}]),"slots":session.item_slots(p)}
	profile.save_profile()

# --- positional reads ---------------------------------------------------------

## The grid a drag slot maps to: the vault is in the save file, everything else is
## in the player dictionary. "cab" (the spare-bag cabinet) is a socket, not a grid.
static func grid_of(profile, p: Dictionary, slot: String) -> Vector2i:
	if slot==VAULT:
		return Catalog.WAREHOUSE_GRID
	var container := container_of(profile,p,slot)
	return Catalog.container_grid(container) if not container.is_empty() else Vector2i.ZERO

static func container_of(profile, p: Dictionary, slot: String) -> Dictionary:
	match slot:
		"backpack": return p.get("backpack",{})
		"pocket": return p.get("pocket",{})
		VAULT: return profile.data.get("warehouse",{}) if profile else {}
	return {}

static func items_of(profile, p: Dictionary, slot: String) -> Array:
	if slot==VAULT:
		return profile.warehouse_items() if profile else []
	return Catalog.container_items(container_of(profile,p,slot))

static func item_at(profile, p: Dictionary, slot: String, index: int) -> Dictionary:
	var list: Array=items_of(profile,p,slot)
	if index<0 or index>=list.size(): return {}
	return list[index]

## Which item covers a cell of a grid. The vault mixes two backing arrays (the grid
## and the spill list) behind one index space, so the same helper answers for both.
static func index_at(profile, p: Dictionary, slot: String, cell: Vector2i) -> int:
	var list: Array=items_of(profile,p,slot)
	for i in list.size():
		var item: Dictionary=list[i]
		var dims := Catalog.item_size(item)
		if Rect2i(Vector2i(int(item.get("x",0)),int(item.get("y",0))),dims).has_point(cell):
			return i
	return -1

# --- drops --------------------------------------------------------------------

## One released drag, from wherever the item came from to wherever it was dropped.
## `drag` is {"slot","index","rot"}; `target` is {"zone"} for a socket or
## {"slot","cell"} for a grid. Returns whether anything changed, and saves when it did.
static func drop(profile, session, p: Dictionary, drag: Dictionary, target: Dictionary) -> bool:
	var from := str(drag.get("slot",""))
	var index := int(drag.get("index",-1))
	var rot := bool(drag.get("rot",false))
	var changed := false
	if target.has("zone"):
		changed=drop_on_socket(profile,session,p,from,index,rot,str(target.zone))
	elif target.has("slot"):
		changed=drop_on_grid(profile,session,p,from,index,rot,str(target.slot),Vector2i(target.cell))
	if changed:
		persist(profile,session,p)
	return changed

## True for every drag source that is a single-item socket rather than a grid: the
## worn kit, the pack on the back, the quick bar and the spare-bag cabinet.
static func is_socket(source: String) -> bool:
	return source=="bag" or source=="weapon" or source.begins_with("gear") or source.begins_with("charm") or source.begins_with("slot")

static func drop_on_grid(profile, session, p: Dictionary, from: String, index: int, rot: bool, to: String, cell: Vector2i) -> bool:
	if to==VAULT:
		if from==VAULT:
			return vault_move(profile,session,p,index,cell,rot)
		if is_socket(from):
			return socket_to_vault(profile,session,p,from,index)
		if from=="cab":
			var pack := cabinet_entry(session,p,index)
			if pack.is_empty(): return false
			if not profile.bank_item(pack): return false
			cabinet_remove(session,p,index)
			return true
		return vault_in(profile,session,p,from,index,cell,rot)
	# The pack on the player's back is a container, not a piece: it only comes off into
	# the vault (or the floor). Dragging it onto the carried grids would mean wearing it
	# where it already is.
	if from=="bag":
		return false
	if from==VAULT:
		return vault_out(profile,session,p,index,to,cell,rot)
	if from=="cab":
		return cabinet_out(session,p,index,to,cell,rot)
	if is_socket(from):
		return socket_out(session,p,from,to,cell,rot)
	return session.move_between(p,from,to,index,cell,rot)

static func drop_on_socket(profile, session, p: Dictionary, from: String, index: int, rot: bool, zone: String) -> bool:
	if from==VAULT:
		return vault_equip(profile,session,p,index,zone)
	if from=="bag":
		# The pack is already worn, so no socket can take it.
		return false
	if from=="cab":
		# A spare pack dragged onto the pack socket is worn: the only socket that
		# accepts a cabinet entry, and the same swap the cabinet buttons perform.
		if zone!="bag": return false
		return Catalog.swap_bags(p,index)
	# Two sockets of any kind change places outright: the camp panel names the bar
	# "slot0" while a drag names it "slot:0", and both spellings are sockets. The
	# session holds that one rule, so a raid drag and a camp drag behave the same.
	if is_socket(from):
		if not session.socket_wants(zone,socket_entry(session,p,from)): return false
		return session.swap_sockets(p,from,zone)
	return equip_from(profile,session,p,from,index,zone)

# --- the pack comes off: the base pack chooses what to keep ---------------------

## The keep order when a pack comes off and the 3x3 issue pack has to choose what it
## can carry: **the most precious first, quality leads**. Inside one quality the piece's
## **value per cell** decides (a 1x2 piece counts half its price per cell), which is what
## "worth the space" means once a 3x3 has to pick. A pile counts its whole worth over
## its single cell. Everything this order rejects falls on the camp floor, so this is
## the single place that decides what the player keeps.
##
## Measured on a 42-item haul: 0.167ms a call, inside the 0.2ms budget agreed for this
## pass. It cost 0.46ms until the sort stopped using `sort_custom()` with a lambda —
## the per-comparison GDScript call was the whole bill, not the division. The plain
## "quality then price" key is kept in `keep_order_plain()` for the next measurement
## round; see `tests/camp_keep_order.gd`.
static func keep_order(items: Array) -> Array:
	return _keep_order(items,true)

## The fallback key: quality, then the piece's own price, with no per-cell weighting.
static func keep_order_plain(items: Array) -> Array:
	return _keep_order(items,false)

## Both orders share one implementation so a measurement compares like with like.
##
## One int64 per item, packed as `quality(7 bits) | worth | index(7 bits)`, sorted with
## the native `PackedInt64Array.sort()`. That replaces the first attempt, which built a
## small `Array` per item for `sort_custom()`/`Array.sort()`: the per-item allocation
## and GDScript's per-comparison callbacks were the entire cost, twenty times the key
## arithmetic they were meant to weigh. See `tests/camp_keep_order.gd` for the numbers.
static func _keep_order(items: Array, per_cell: bool) -> Array:
	var packed := PackedInt64Array()
	packed.resize(items.size())
	for i in items.size():
		var item: Dictionary=items[i]
		var units := maxi(1,int(item.get("count",1)))
		# `item_value()` is the per-unit price and deliberately ignores the
		# "provision" mark, so camp-bought supplies are not the first thing thrown
		# away just because the exchange will not buy them back.
		var worth := Catalog.item_value(item)*units
		if per_cell:
			var size := Catalog.item_size(item)
			worth=int(round(float(worth)/float(maxi(1,size.x*size.y))*1000.0))
		packed[i]=(Catalog.item_tier(item) << 56) | (mini(worth,(1 << 49)-1) << 7) | (i & 127)
	packed.sort()
	var out: Array = []
	# Ascending, walked backwards: the best piece has the biggest key.
	for at in range(packed.size()-1,-1,-1):
		out.append(items[int(packed[at] & 127)])
	return out

# --- N units of a pile at a time: the right-click hand --------------------------

## `units` of a pile from a carried container into the vault. `bank_item()` already
## merges same-kind piles and is all-or-nothing, which is exactly what "put three of
## these in" means; the source pile is trimmed only after the vault took them.
static func vault_units_in(profile, session, p: Dictionary, from: String, index: int, units: int, rot: bool = false) -> bool:
	# Banking a vault pile back into the vault is not a move, and treating it as one
	# used to destroy units: `bank_item()` merges the lifted units into that very pile
	# (it is the first same-kind pile with room) and the trim below then overwrites the
	# merged count. Refusing is the only honest answer — "back where it came from" is a
	# no-op, so nothing has to happen.
	if from==VAULT:
		return false
	var list: Array=Catalog.container_items(container_of(profile,p,from))
	if index<0 or index>=list.size(): return false
	var kind := str(list[index].kind)
	if not Catalog.stacks(kind): return false
	var have := int(list[index].get("count",1))
	units=mini(units,have)
	if units<=0 or have<=1: return false
	var pile: Dictionary=list[index].duplicate(true)
	pile["count"]=units
	pile["rot"]=rot
	if not profile.bank_item(pile): return false
	if units>=have: list.remove_at(index)
	else: list[index]["count"]=have-units
	return true

## `units` of a vault pile back into a carried container, aimed at a cell. The vault
## entry is trimmed in place rather than removed, so the pile the player is looking at
## does not jump to another cell when only part of it left.
static func vault_units_out(profile, session, p: Dictionary, index: int, units: int, to: String, cell: Vector2i) -> bool:
	var list: Array=profile.vault_items()
	if index<0 or index>=list.size(): return false
	if not Catalog.stacks(str(list[index].kind)): return false
	var have := int(list[index].get("count",1))
	units=mini(units,have)
	if units<=0 or have<=1: return false
	var target: Dictionary=container_of(profile,p,to)
	if target.is_empty(): return false
	var pile: Dictionary=list[index].duplicate(true)
	pile["count"]=units
	pile["rot"]=false
	var at: Vector2i=session.resolve_drop(Catalog.container_items(target),Catalog.container_grid(target),pile,cell)
	if at.x<0: return false
	pile["x"]=at.x
	pile["y"]=at.y
	Catalog.container_items(target).append(pile)
	Catalog.compact_arrivals(target)
	if units>=have: list.remove_at(index)
	else: list[index]["count"]=have-units
	return true

# --- carried storage <-> vault ------------------------------------------------

## Takes `units` off a vault pile and hands them back as their own entry, trimming the
## vault in place. The ground drop of a handful uses this; a move into a container uses
## `vault_units_out()`.
static func vault_take_units(profile, index: int, units: int) -> Dictionary:
	var list: Array=profile.vault_items()
	if index<0 or index>=list.size(): return {}
	if not Catalog.stacks(str(list[index].kind)): return {}
	var have := int(list[index].get("count",1))
	units=mini(units,have)
	if units<=0: return {}
	var pile: Dictionary=list[index].duplicate(true)
	pile["count"]=units
	if units>=have: list.remove_at(index)
	else: list[index]["count"]=have-units
	return pile





## Lifts `units` (capped at what the pile holds) off a vault pile and hands them back as
## their own entry, trimming the vault in place. Accepts a non-stackable piece too,
## which `vault_take_units()` refuses because its only caller splits stacks.
##
## Goes through `warehouse_item()` / `warehouse_remove()` so one index space covers the
## grid *and* the spill shelf: the panel hands back whichever index it drew, and a pile
## parked in the spill must be liftable exactly like a grid pile.
static func vault_take_some(profile, index: int, units: int) -> Dictionary:
	var entry: Dictionary=profile.warehouse_item(index)
	if entry.is_empty(): return {}
	if not Catalog.stacks(str(entry.kind)): units=1
	var have := int(entry.get("count",1))
	units=mini(units,have)
	if units<=0: return {}
	var pile: Dictionary=entry.duplicate(true)
	pile["count"]=units
	if units>=have:
		profile.warehouse_remove(index)
	else:
		entry["count"]=have-units
	return pile

## The vault half of `Session.place_units()`: puts `units` of `kind` into the 15x15
## warehouse, aimed at `cell`, and asks the aimed cell first. Same order as the carried
## containers — the aimed cell, then the nearest hole, then any same-kind pile with room
## — and the same refusal to repack the grid, so the cell the hand aimed at is still
## where the player left it when the gesture ends.
##
## Returns {"placed":units_that_fit,"cell":first_cell_used(-1,-1 when nothing fit)}.
static func vault_place_units(profile, session, kind: String, units: int, cell: Vector2i, blank: Dictionary, rot: bool = false) -> Dictionary:
	var result := {"placed":0,"cell":Vector2i(-1,-1)}
	if profile==null or units<=0: return result
	var vault: Dictionary=profile.vault()
	if vault.is_empty(): return result
	# Same landing rule as a carried container: `Catalog.place_units_in()`.
	return Catalog.place_units_in(vault,kind,units,cell,blank,rot)

## One left click of the right-button hand in the camp, where the vault and the carried
## containers live in two different places behind one panel. Places what fits into `to` and
## lifts off the source **only** the units that really landed, so a refused click costs
## nothing. Returns {"placed":n,"cell":Vector2i(-1,-1 when nothing landed)}.
static func camp_carry_units(profile, session, p: Dictionary, from: String, index: int, to: String, units: int, cell: Vector2i, rot: bool = false) -> Dictionary:
	var out := {"placed":0,"cell":Vector2i(-1,-1)}
	var source: Array=items_of(profile,p,from)
	if index<0 or index>=source.size(): return out
	if not source[index] is Dictionary: return out
	var kind := str(source[index].kind)
	var blank: Dictionary=Catalog.clean_slot_entry(source[index])
	if blank.is_empty(): return out
	var wanted := mini(units,int(source[index].get("count",1)))
	if wanted<=0 or to.is_empty(): return out
	var placed := 0
	if to==VAULT:
		placed=int(vault_place_units(profile,session,kind,wanted,cell,blank,rot).placed)
	else:
		placed=int(session.place_units(p,to,kind,wanted,cell,blank,rot).placed)
	out["placed"]=placed
	if placed>0:
		if from==VAULT: vault_take_some(profile,index,placed)
		else: session.take_some(p,from,index,placed)
	return out

## The right button coming up in the camp: seat as much of the hand as the aimed container
## will take, and leave the rest where it is. The source is only trimmed by the units that
## already landed, so an unseated unit never left its pile — "put it back" is free and
## identical to doing nothing, and the camp floor is only ever reached by an explicit
## discard. Returns {"moved":n} where n counts the units that really changed container.
static func camp_carry_finish(profile, session, p: Dictionary, from: String, index: int, to: String, units: int, cell: Vector2i, rot: bool = false) -> Dictionary:
	var out := {"moved":0}
	var source: Array=items_of(profile,p,from)
	if index<0 or index>=source.size(): return out
	if not source[index] is Dictionary: return out
	var blank: Dictionary=Catalog.clean_slot_entry(source[index])
	if blank.is_empty(): return out
	var wanted := mini(units,int(source[index].get("count",1)))
	if wanted<=0 or to.is_empty() or to==from: return out
	out["moved"]=int(camp_carry_units(profile,session,p,from,index,to,wanted,cell,rot).placed)
	return out

## Bag or pocket into the vault. All or nothing: `bank_item()` refuses a full grid
## rather than half-seating a stack, and it is also the one place the lifetime loot
## tally grows, so the camp must not place into the vault behind its back.
##
## A single item lands on the cell it was dropped on; a stack is merged into the pile
## it belongs to instead, because a shared pile has no single cell to aim at.
##
## **The whole pile moves**, both directions: a drag is the player saying "take this
## stack over there", and `bank_item()`'s all-or-nothing snapshot means a pile that
## will not fit is refused outright instead of being scattered. To move part of a pile,
## right-click it: that lifts one unit at a time into the hand (see `main.gd`).
static func vault_in(profile, session, p: Dictionary, from: String, index: int, cell: Vector2i = Vector2i(-1,-1), rot: bool = false) -> bool:
	var list: Array=Catalog.container_items(container_of(profile,p,from))
	if index<0 or index>=list.size(): return false
	var entry: Dictionary=list[index].duplicate(true)
	entry["rot"]=rot
	var stored := false
	if cell.x<0 or Catalog.stacks(str(entry.kind)):
		stored=profile.bank_item(entry)
	else:
		var landing: Vector2i = session.resolve_drop(profile.vault_items(),Catalog.WAREHOUSE_GRID,entry,cell)
		if landing.x<0: return false
		stored=profile.bank_item_at(entry,landing)
	if not stored: return false
	list.remove_at(index)
	return true

## Vault into the bag or the pocket, honouring the cell the player aimed at.
static func vault_out(profile, session, p: Dictionary, index: int, to: String, cell: Vector2i, rot: bool) -> bool:
	var entry := item_at(profile,p,VAULT,index)
	if entry.is_empty(): return false
	var target := container_of(profile,p,to)
	if target.is_empty(): return false
	var probe: Dictionary=entry.duplicate(true)
	probe["rot"]=rot
	var landing: Vector2i
	if Catalog.stacks(str(entry.kind)):
		# A pile merges into its own pile wherever the player aimed, so its landing
		# is the aimed cell — the one cell a pile can claim. `container_receive()`
		# would seat it at the first free cell instead and lose the aim.
		landing=cell
		if landing.x<0: landing=Vector2i(0,0)
	elif not session.container_accepts(target,probe,cell,rot):
		# The aimed cell will not take it; the container's own first-fit rule decides.
		if not session.container_receive(p,to,probe): return false
		profile.warehouse_remove(index)
		return true
	else:
		landing=session.resolve_drop(Catalog.container_items(target),Catalog.container_grid(target),probe,cell)
		if landing.x<0: return false
	profile.warehouse_remove(index)
	place_at(target,entry,landing,rot)
	return true

## Rearranging inside the vault itself: the grid is one container, the spill list is
## another, so a move between them is a remove plus a place. Both land in the grid —
## a piece only sits in the spill list because the grid had no room for it.
static func vault_move(profile, session, p: Dictionary, index: int, cell: Vector2i, rot: bool) -> bool:
	var entry := item_at(profile,p,VAULT,index)
	if entry.is_empty(): return false
	var probe: Dictionary=entry.duplicate(true)
	probe["rot"]=rot
	var skip := index if index<profile.vault_items().size() else -1
	var landing: Vector2i = session.resolve_drop(profile.vault_items(),Catalog.WAREHOUSE_GRID,probe,cell,skip)
	if landing.x<0: return false
	profile.warehouse_remove(index)
	place_vault(profile,entry,landing,rot)
	return true

# --- vault <-> sockets --------------------------------------------------------

static func vault_equip(profile, session, p: Dictionary, index: int, zone: String) -> bool:
	var entry := item_at(profile,p,VAULT,index)
	if entry.is_empty(): return false
	# The worn sockets are fed from a carried container, so the piece is parked in
	# the first container that can hold it and then equipped by the session's own
	# rule (which refuses a piece of the wrong kind for free). The park is rolled
	# back when the socket will not have it.
	for name in ["backpack","pocket"]:
		if not session.container_receive(p,name,entry): continue
		var list: Array=Catalog.container_items(p[name])
		if equip_from(profile,session,p,name,list.size()-1,zone):
			profile.warehouse_remove(index)
			return true
		list.remove_at(list.size()-1)
	return false

# --- sockets ------------------------------------------------------------------
# The rules live in `session.gd` (`socket_entry` / `set_socket_entry` / `clear_socket`
# / `swap_sockets`), because a camp drag and a raid drag mean exactly the same thing.
# These thin wrappers only add the one socket the session does not know: the pack on
# the player's back, which is a container rather than a stored piece.

static func socket_entry(session, p: Dictionary, zone: String) -> Dictionary:
	if zone=="bag":
		return session.bag_as_item(str(p.get("backpack",{}).get("key",Catalog.DEFAULT_BAG_KEY)))
	return session.socket_entry(p,zone)

## Empties a socket without putting its content anywhere: the caller has already
## worked out where the item is going, so a refusal from `stow_worn()` must not send
## it to the backpack instead.
static func socket_clear(session, p: Dictionary, zone: String) -> bool:
	if zone=="bag":
		return false	# see unwear_bag(): a pack is emptied before it comes off
	return session.clear_socket(p,zone)

## Carried item into a worn socket, the pack socket or a socket of the item bar.
## The session owns every one of those rules; this only routes the socket name. The
## save is written by `drop()`, once, after the whole gesture succeeded.
static func equip_from(profile, session, p: Dictionary, from: String, index: int, zone: String) -> bool:
	if zone=="bag":
		return session.equip_bag(p,from,index)
	if zone.begins_with("slot"):
		return session.slot_put(p,session.slot_number(zone),from,index)
	if zone.begins_with("charm"):
		return session.equip_item(p,from,index,zone.substr(5).to_int())
	if zone.begins_with("gear") or zone=="weapon":
		return session.equip_item(p,from,index)
	return false

## A socket into a grid at the aimed cell.
static func socket_out(session, p: Dictionary, zone: String, to: String, cell: Vector2i, rot: bool) -> bool:
	var entry := socket_entry(session,p,zone)
	if entry.is_empty(): return false
	var target: Dictionary=p.get(to,{})
	if target.is_empty(): return false
	var probe: Dictionary=entry.duplicate(true)
	probe["rot"]=rot
	var landing: Vector2i = session.resolve_drop(Catalog.container_items(target),Catalog.container_grid(target),probe,cell)
	if landing.x<0: return false
	if not socket_clear(session,p,zone): return false
	place_at(target,entry,landing,rot)
	return true

static func socket_to_vault(profile, session, p: Dictionary, from: String, index: int) -> bool:
	if from=="cab":
		var pack := cabinet_entry(session,p,index)
		if pack.is_empty() or not profile.bank_item(pack): return false
		cabinet_remove(session,p,index)
		return true
	if from=="bag":
		return unwear_bag(profile,session,p,true)
	var entry := socket_entry(session,p,from)
	if entry.is_empty(): return false
	if not profile.bank_item(entry): return false
	return socket_clear(session,p,from)

## Socket onto socket: the session's own rule (a worn socket, a bar socket, or both).
static func socket_to_socket(session, p: Dictionary, from: String, zone: String) -> bool:
	return session.swap_sockets(p,from,zone)

# --- the worn backpack --------------------------------------------------------

## Takes the equipped pack off. It becomes an ordinary backpack item — the same thing
## a loose pack in a chest is — so it can be stored and sold like any other piece of
## loot.
##
## A pack is a container, so whatever it holds has to go somewhere, and the camp's rule
## is the blunt one the player asked for: the **3x3 issue pack it is replaced by keeps
## what it can, most precious first** (`keep_order()` decides that order), and **every
## piece that does not fit falls on the camp floor**. Nothing is refused and nothing is
## quietly banked: taking a big pack off with a full 8x8 inside it is a real loss, and
## it is meant to be.
static func unwear_bag(profile, session, p: Dictionary, to_vault: bool = true) -> bool:
	var pack: Dictionary=p.get("backpack",{})
	if pack.is_empty(): return false
	var key := str(pack.get("key",Catalog.DEFAULT_BAG_KEY))
	var loose: Dictionary = session.bag_as_item(key)
	var contents: Array=Catalog.container_items(pack).duplicate(true)
	retire_pack(session,p)
	for item in keep_order(contents):
		if session.container_receive(p,"backpack",item):
			continue
		to_floor(item)
	if not to_vault or not profile.bank_item(loose):
		# The old pack itself has nowhere to go, so it joins the overflow on the floor.
		to_floor(loose)
	persist(profile,session,p)
	return true

## Where a piece that nothing can hold ends up. `main.gd` points this at the camp
## floor, exactly like `camp_activities.item_receiver` points the other way.
static var spill_sink: Callable = Callable()

static func to_floor(item: Dictionary) -> void:
	if spill_sink.is_valid():
		spill_sink.call(item)

## The empty pack a Watcher is left with after taking one off: the same replacement
## `spill_storage()` hands out on death, so there is never a moment without a bag.
static func retire_pack(session, p: Dictionary) -> void:
	var replacement := Catalog.make_bag(Catalog.DEFAULT_BAG_KEY)
	replacement["gw"]=Catalog.bag_grid(replacement).x
	replacement["gh"]=Catalog.bag_grid(replacement).y
	p["backpack"]=replacement
	session.refresh_max_hp(p)

# Everything a rehouse can touch, so a refused gesture leaves nothing behind.
static func snapshot(profile, p: Dictionary) -> Dictionary:
	var spill = profile.data.get("warehouse_spill",[])
	return {"pocket":Catalog.container_items(p.get("pocket",{})).duplicate(true),
		"vault":profile.vault_items().duplicate(true),
		"spill":spill.duplicate(true) if spill is Array else [],
		"value":int(profile.data.get("loot_value",0))}

static func rollback(profile, p: Dictionary, restore: Dictionary) -> void:
	var pocket: Array=Catalog.container_items(p.get("pocket",{}))
	pocket.clear()
	for item in restore.pocket: pocket.append(item)
	profile.data["warehouse"]["items"]=restore.vault
	profile.data["warehouse_spill"]=restore.spill
	profile.data["loot_value"]=int(restore.value)

# --- spare packs (the cabinet) ------------------------------------------------

## A spare pack as a loose item. The cabinet holds *empty* packs only: `swap_bags()`
## empties the outgoing pack on the way in, so nothing is lost by moving one.
static func cabinet_entry(session, p: Dictionary, index: int) -> Dictionary:
	var cabinet: Array=p.get("bags",[])
	if index<0 or index>=cabinet.size(): return {}
	return session.bag_as_item(str(cabinet[index].get("key",Catalog.DEFAULT_BAG_KEY)))

static func cabinet_remove(session, p: Dictionary, index: int) -> void:
	var cabinet: Array=p.get("bags",[])
	if index>=0 and index<cabinet.size(): cabinet.remove_at(index)

static func cabinet_out(session, p: Dictionary, index: int, to: String, cell: Vector2i, rot: bool) -> bool:
	var loose := cabinet_entry(session,p,index)
	if loose.is_empty(): return false
	var target: Dictionary=p.get(to,{})
	if target.is_empty(): return false
	var probe: Dictionary=loose.duplicate(true)
	probe["rot"]=rot
	var landing: Vector2i = session.resolve_drop(Catalog.container_items(target),Catalog.container_grid(target),probe,cell)
	if landing.x<0: return false
	cabinet_remove(session,p,index)
	place_at(target,loose,landing,rot)
	return true

# --- one-click verbs ----------------------------------------------------------

## A worn piece comes off into the carried backpack (the pocket when the bag is
## full): the Ctrl+left take-off, and the "卸" button. Nothing happens when both
## containers are full — the piece stays worn rather than being thrown away.
static func stow_worn(profile, session, p: Dictionary, type: String, index: int = 0) -> bool:
	var ok: bool = session.unequip_stow(p,type,index)
	if ok: persist(profile,session,p)
	return ok

## A socket hands its content back to the carried storage: the bar's "收回" and the
## take-off gestures (double tap / Ctrl+left / the "卸" button). In the camp the
## landing order is **背包 → 仓库**: the vault is the camp's own storage and far safer
## than a pocket, so the pocket is not a camp landing spot at all.
static func stow_socket(profile, session, p: Dictionary, zone: String) -> bool:
	if zone=="bag":
		return unwear_bag(profile,session,p,true)
	var ok := take_off(profile,session,p,zone)
	if ok: persist(profile,session,p)
	return ok

## Takes one piece off the body and seats it: the carried backpack first, the vault
## when the backpack has no room, and a flat refusal when neither does — the piece
## stays worn rather than being thrown on the ground. Nothing is mutated until the
## seat is known to exist, so a refusal cannot leave the Watcher half undressed.
static func take_off(profile, session, p: Dictionary, zone: String) -> bool:
	var entry := socket_entry(session,p,zone)
	if entry.is_empty(): return false
	if session.container_would_receive(p.get("backpack",{}),entry):
		if not session.container_receive(p,"backpack",entry): return false
	elif can_vault_receive(profile,session,entry,Vector2i(-1,-1),bool(entry.get("rot",false))):
		if not profile.bank_item(entry): return false
	else:
		return false
	return socket_clear(session,p,zone)

## The double-click / Ctrl+left shortcut. In the camp the gesture is a *storage*
## verb, never a battle one:
##
## - a wearable takes its own socket; when that socket is already filled the two
##   pieces swap, and the displaced one lands in the vault where the other came
##   from (the backpack when the vault cannot take it);
## - everything else goes into the carried backpack, the vault only when the
##   backpack cannot hold it.
##
## The item bar is deliberately out of reach here: a socket is filled by dragging
## something onto it, never by double-clicking, because the camp has no battle to
## put a consumable in the hand for. Returns false when there is no room anywhere,
## so the click can fall through to a plain selection.
static func quick_equip(profile, session, p: Dictionary, slot: String, index: int) -> bool:
	var entry := item_at(profile,p,slot,index)
	if entry.is_empty(): return false
	var zone := socket_for(session,p,entry)
	if not zone.is_empty():
		if socket_entry(session,p,zone).is_empty():
			return drop(profile,session,p,{"slot":slot,"index":index,"rot":bool(entry.get("rot",false))},{"zone":zone})
		return swap_worn(profile,session,p,slot,index,zone)
	return auto_store(profile,session,p,slot,index)

## From a chosen slot into the carried backpack, the vault only when the backpack
## cannot hold it. A stack gives up one unit, so a pile of medkits is moved one
## click at a time instead of disappearing into storage all at once.
static func auto_store(profile, session, p: Dictionary, slot: String, index: int) -> bool:
	var list: Array=items_of(profile,p,slot)
	if index<0 or index>=list.size(): return false
	var entry: Dictionary=list[index]
	if slot=="backpack":
		# Already where the gesture would put it: the double-click is a no-op rather
		# than a "stash it again", which used to copy the item into a second cell.
		return true
	if can_stash(profile,session,p,entry,"backpack"):
		return drop(profile,session,p,{"slot":slot,"index":index,"rot":bool(entry.get("rot",false))},{"slot":"backpack","cell":Vector2i(-1,-1)})
	if can_stash(profile,session,p,entry,"vault"):
		return drop(profile,session,p,{"slot":slot,"index":index,"rot":bool(entry.get("rot",false))},{"slot":VAULT,"cell":Vector2i(-1,-1)})
	return false

## Which worn socket the piece belongs in, or "" when it has no socket at all. The
## pack socket is named "bag" while a loose pack's kind is "backpack"; the charm
## pair picks the free half first so a double-click never swaps a charm out while
## there is a bare socket beside it.
static func socket_for(session, p: Dictionary, entry: Dictionary) -> String:
	var kind := str(entry.get("kind",""))
	if kind=="backpack": return "bag"
	if kind=="weapon": return "weapon"
	if kind=="gear": return "gear%d" % Catalog.gear_slot(entry)
	if kind=="charm":
		if session.kit_charms(p)[0].is_empty(): return "charm0"
		if session.kit_charms(p)[1].is_empty(): return "charm1"
		return "charm0"
	return ""

## Double-click on a piece whose socket is already taken: the two swap, and the
## piece coming off lands in the vault cell the other one came out of — the obvious
## picture of "these two changed places". The spell is refused outright when that
## cell cannot take the piece, because `equip_item()` would otherwise hand the
## outgoing piece to the pocket and then to the ground, which is how loot is lost.
static func swap_worn(profile, session, p: Dictionary, slot: String, index: int, zone: String) -> bool:
	var pack := item_at(profile,p,slot,index)
	if pack.is_empty(): return false
	var old := socket_entry(session,p,zone)
	if old.is_empty(): return false
	var from_vault := slot==VAULT
	var vault_cell := Vector2i(-1,-1)
	var vault_free := false
	if from_vault:
		vault_cell=Vector2i(int(pack.get("x",-1)),int(pack.get("y",-1)))
		vault_free=can_vault_receive(profile,session,old,vault_cell,bool(pack.get("rot",false)))
	# A pack comes off with loot inside it, so the pack swap is its own path.
	if zone=="bag":
		return swap_pack(profile,session,p,slot,index,from_vault)
	if not vault_free and not can_stash(profile,session,p,old,"backpack"): return false
	remove_source(profile,p,slot,index)
	if from_vault:
		# The socket is fed from a carried container, so the piece is parked first
		# and handed to the session's own rule by position.
		if not session.container_receive(p,"backpack",pack): return false
		var parked: Array=Catalog.container_items(p["backpack"])
		if not clear_zone(session,p,zone): return false
		if not equip_from(profile,session,p,"backpack",parked.size()-1,zone):
			restore_zone(session,p,zone,old)
			return false
	else:
		if not clear_zone(session,p,zone): return false
		# Removing the piece shifted every index after it, so the carrying slot is
		# asked again rather than reusing the index the drag started with.
		var carried: Array=Catalog.container_items(p[slot])
		var at := carried.size()-1
		if not equip_from(profile,session,p,slot,at,zone):
			restore_zone(session,p,zone,old)
			return false
	stash(profile,session,p,old,vault_cell,false)
	persist(profile,session,p)
	return true

## The pack swap. The pack coming off the back is emptied first (the pocket takes
## what it can, the vault the rest) and then lands in the vault cell the new pack
## came out of, so a double-click on a spare pack reads as "these two changed
## places"; `equip_bag()` is what actually wears the new one. Refused whole when the
## carried loot would not fit inside the new pack, or when there is nowhere for the
## outgoing one to land.
static func swap_pack(profile, session, p: Dictionary, slot: String, index: int, from_vault: bool) -> bool:
	var spare := item_at(profile,p,slot,index)
	if spare.is_empty() or str(spare.get("kind",""))!="backpack": return false
	var worn: Dictionary=p.get("backpack",{})
	if worn.is_empty(): return false
	if not can_rehouse(profile,session,p): return false
	var landing := Vector2i(-1,-1)
	if from_vault:
		landing=Vector2i(int(spare.get("x",-1)),int(spare.get("y",-1)))
		if landing.x<0 or not can_vault_receive(profile,session,worn,landing,false): return false
	elif not can_vault_receive(profile,session,worn,Vector2i(-1,-1),false): return false
	remove_source(profile,p,slot,index)
	if from_vault: profile.warehouse_remove(index)
	if landing.x>=0:
		profile.bank_item_at(worn,landing)
	else:
		profile.bank_item(worn)
	var spare_slot := slot if slot=="backpack" or slot=="pocket" else "backpack"
	if not session.container_receive(p,spare_slot,spare): return false
	var carried: Array=Catalog.container_items(p[spare_slot])
	if not session.equip_bag(p,spare_slot,carried.size()-1): return false
	persist(profile,session,p)
	return true

## Puts `entry` where the player can see it: the vault at the aimed cell first, then
## the carried backpack, and the pocket only for gold and above (README
## 「稀有度与自动收纳判定」). Returns false when nothing can hold it, leaving the
## item untouched — the caller keeps the old piece exactly where it was.
static func stash(profile, session, p: Dictionary, entry: Dictionary, cell: Vector2i, rot: bool) -> bool:
	if can_vault_receive(profile,session,entry,cell,rot):
		if cell.x>=0 and not Catalog.stacks(str(entry.get("kind",""))):
			return profile.bank_item_at(entry,cell)
		return profile.bank_item(entry)
	if session.container_receive(p,"backpack",entry): return true
	if Catalog.high_quality(entry) and session.container_receive(p,"pocket",entry): return true
	return false

## Room for one more piece, asked without touching it: the carried backpack, or the
## vault at the cell the piece came out of (anywhere when it did not come from the
## vault). A stack is only ever asked about its own cell, because a pile has no
## second cell to aim at.
static func can_stash(profile, session, p: Dictionary, entry: Dictionary, where: String) -> bool:
	if where=="backpack": return session.container_receive(p,"backpack",entry)
	if where!="vault": return false
	var cell := Vector2i(int(entry.get("x",-1)),int(entry.get("y",-1)))
	return can_vault_receive(profile,session,entry,cell,bool(entry.get("rot",false)))

## Whether the vault could hold the piece at the aimed cell; -1 for "anywhere".
static func can_vault_receive(profile, session, entry: Dictionary, cell: Vector2i, rot: bool) -> bool:
	if profile==null or entry.is_empty(): return false
	var probe: Dictionary=entry.duplicate(true)
	probe["rot"]=rot
	return session.resolve_drop(profile.vault_items(),Catalog.WAREHOUSE_GRID,probe,cell).x>=0

## Empties a socket, and puts its content back when the step after it failed. The
## session owns what a socket is; only the pack socket is the camp's own exception.
static func clear_zone(session, p: Dictionary, zone: String) -> bool:
	if zone=="bag": return false
	return session.clear_socket(p,zone)

## Puts a socket's content back where it was, after a step that followed it failed.
## The session owns what a socket is, so this is only the pack-socket exception.
static func restore_zone(session, p: Dictionary, zone: String, entry: Dictionary) -> void:
	if zone=="bag": return
	session.set_socket_entry(p,zone,entry)

## Takes the piece out of where the gesture lifted it from, before the same piece is
## placed somewhere else. The vault is a save-file list, everything else a container.
static func remove_source(profile, p: Dictionary, slot: String, index: int) -> void:
	if slot==VAULT:
		profile.warehouse_remove(index)
		return
	var container := container_of(profile,p,slot)
	var items: Array=Catalog.container_items(container)
	if index>=0 and index<items.size(): items.remove_at(index)

## Whether the worn pack's whole content could be rehoused into the pocket and the
## vault: the question `unwear_bag()` answers by mutating, asked without touching.
static func can_rehouse(profile, session, p: Dictionary) -> bool:
	var contents: Array=Catalog.container_items(p.get("backpack",{})).duplicate(true)
	for item in contents:
		var copy: Dictionary=item.duplicate(true)
		if can_container_receive(session,p,"pocket",copy): continue
		if can_vault_receive(profile,session,copy,Vector2i(-1,-1),bool(copy.get("rot",false))): return false
		return false
	return true

## Whether a carried container would take one more piece, asked without touching it.
static func can_container_receive(session, p: Dictionary, name: String, entry: Dictionary) -> bool:
	return session.container_receive(p,name,entry)

## Wears a spare pack from the cabinet. The pack coming off becomes the new spare, so
## swapping never destroys one; a pack too small for the carried loot is refused.
static func wear_spare(profile, session, p: Dictionary, index: int) -> bool:
	var ok: bool = Catalog.swap_bags(p,index)
	if ok: persist(profile,session,p)
	return ok

## R / middle click on a grid item: turn it where it stands. While the turned piece
## still fits, nothing else on the grid moves; when it no longer does, the pieces in
## its way are pushed out (see `rotate_with_displacement()`).
static func rotate(profile, session, p: Dictionary, drag: Dictionary) -> bool:
	var slot := str(drag.get("slot",""))
	if slot!="backpack" and slot!="pocket" and slot!=VAULT:
		return false
	var index := int(drag.get("index",-1))
	var entry := item_at(profile,p,slot,index)
	if entry.is_empty(): return false
	var cell := Vector2i(int(entry.get("x",0)),int(entry.get("y",0)))
	if drop(profile,session,p,{"slot":slot,"index":index,"rot":not bool(entry.get("rot",false))},{"slot":slot,"cell":cell}):
		return true
	return rotate_with_displacement(profile,session,p,slot,index)

## A flip that no longer fits: the grid is repacked around the turned piece, and what is
## in its way is pushed out — **the vault first**, then a free bar socket, then the camp
## floor. The turned piece is seated first by `Catalog.tidy_around()`, so it is never
## the one pushed out, and the floor takes whatever nothing else can, so no rotation can
## lose anything.
static func rotate_with_displacement(profile, session, p: Dictionary, slot: String, index: int) -> bool:
	var entry := item_at(profile,p,slot,index)
	if entry.is_empty(): return false
	var focus: Dictionary=entry.duplicate(true)
	focus["rot"]=not bool(focus.get("rot",false))
	items_of(profile,p,slot).remove_at(index)
	var spill: Array=Catalog.tidy_around(container_of(profile,p,slot),focus)
	for piece in spill:
		if profile.bank_item(piece):
			continue
		if session.slot_receive(p,piece):
			continue
		to_floor(piece)
	persist(profile,session,p)
	return true

# --- selling what the Watcher carries -----------------------------------------

## Sells the carried pieces the exchange was asked for: the counterpart of
## `Profile.sell_items()` for the pack on the player's back. The exchange window draws
## the pack as a second shelf and hands the chosen indices here, because a panel must
## never edit a container itself.
##
## A pile gives up every unit it has, and a camp supply is refused rather than taken for
## nothing: `Catalog.item_value()` is what the exchange pays, and a provision is worth
## zero there. Indices are removed back to front so one removal cannot shift the next
## index still owed. Returns what left and what it earned.
static func sell_backpack(profile, session, p: Dictionary, indices: Array) -> Dictionary:
	var coins := 0
	var count := 0
	var order: Array=indices.duplicate()
	order.sort()
	order.reverse()
	for raw in order:
		var index := int(raw)
		var list: Array=Catalog.container_items(p.get("backpack",{}))
		if index<0 or index>=list.size(): continue
		var entry: Dictionary=list[index]
		var kind := str(entry.get("kind",""))
		if bool(entry.get("provision",false)) or not Catalog.ITEMS.has(kind): continue
		var units := maxi(1,int(entry.get("count",1)))
		coins+=Catalog.item_value(entry)*units
		count+=1
		list.remove_at(index)
	if count>0:
		profile.data["coins"]=int(profile.data.get("coins",0))+coins
		persist(profile,session,p)
	return {"coins":coins,"count":count}

# --- bulk ---------------------------------------------------------------------

## The "everything into the vault" button. The live player dictionary is the source
## of truth in the camp, and `bank_carried_items()` works on the save file, so the
## two are synchronised around it: save the edits first, bank, then read the emptied
## containers back into the player.
static func bank_all(profile, session, p: Dictionary) -> Dictionary:
	persist(profile,session,p)
	var outcome: Dictionary=profile.bank_carried_items()
	var bags: Array=profile.data.get("bags",[])
	if not bags.is_empty():
		p["backpack"]=bags[0]
		p["bags"]=bags.slice(1)
	p["pocket"]=profile.data.get("pocket",{})
	session.refresh_storage(p)
	persist(profile,session,p)
	return outcome

# --- shared placement ---------------------------------------------------------

static func place_at(target: Dictionary, entry: Dictionary, cell: Vector2i, rot: bool) -> void:
	var copy: Dictionary=entry.duplicate(true)
	copy["rot"]=rot
	copy["x"]=cell.x
	copy["y"]=cell.y
	copy["id"]=int(target.get("next",1))
	target["next"]=int(target.get("next",1))+1
	Catalog.container_items(target).append(copy)

## Seats an item in the vault grid at a chosen cell (the vault's own deposit path
## places row-major instead, for the automatic settlement).
static func place_vault(profile, entry: Dictionary, cell: Vector2i, rot: bool) -> void:
	var vault: Dictionary=profile.data.get("warehouse",{})
	if vault.is_empty(): return
	place_at(vault,entry,cell,rot)
