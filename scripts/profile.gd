class_name Profile
extends RefCounted

signal saved

var data: Dictionary = {"version":1,"name":"守夜人","coins":160,"xp":0,"runs":0,"extracts":0,"hero":0,"gear":-1,"talents":[0,0,0],"volume":0.65,"voice_volume":0.9,"music_volume":0.7,"fullscreen":false,"best":0,"pocket":{"key":"white","items":[],"gw":4,"gh":4,"next":1},"bag_key":"white","bags":[{"key":"white","items":[],"next":1}],"unlocks":{},"attributes":{},
	# Contracts §4: meta currency and growth tree. Both are top level keys on
	# purpose: server/app.py only whitelists `attributes`, and `apply_data` keeps
	# version 1 so an old save is never skipped (a skipped parse wipes the profile).
	# CHANGE-LOG v3-1 adds `daily`: the per-day daily-challenge record written by
	# `roguelike.record_daily()` through the session's `profile_data()` channel.
	"ashes":0,"growth":{},"daily":{}}
const Homestead = preload("res://scripts/homestead.gd")
# The daily record's key format (`daily:YYYY-MM-DD`) and record shape
# (`{"best":int,"plays":int}`) are owned by `RogueDaily`; the profile reuses that
# module instead of re-implementing the date rules a second time.
const Daily = preload("res://scripts/rogue_daily.gd")
# How many days of daily records are kept. `RogueDaily.MAX_LOOKBACK` (400) is the
# deepest history any read path scans for a streak, so entries older than the newest
# 400 can never be read again; the cap keeps a hand-edited or long-lived save bounded.
const MAX_DAILY_RECORDS := 400

var path := "user://profile.json"
# Recruits earned by reaching a hidden ending. A hero whose key is not listed
# here never appears in the camp roster, so the extra rows in Catalog.HEROES
# stay invisible until the profile has actually met them.
const RECRUIT_KEYS := ["muyu"]
const AMULET_ENDING := "amulet_ending"
# Which catalog index each recruit key unlocks. Spelled out rather than derived,
# because the save file keeps only the keys and a later reorder of the roster
# must not silently hand a player a different hero.
const RECRUIT_HEROES := {"muyu":3}

func _init() -> void:
	data["home"]=Homestead.clean({})
	# The vault is a real grid container (see sanitize_warehouse) with a spill list
	# behind it, and the worn kit is part of the save now (see empty_loadout).
	data["warehouse"]=make_vault()
	data["warehouse_spill"]=[]
	data["trade_history"]=[]
	data["loadout"]=empty_loadout()
	# Lifetime loot value: every item pays into it once, on the way into the vault.
	# Nothing reads it yet — it exists so a later achievement page has honest data
	# that a withdraw/store loop cannot inflate.
	data["loot_value"]=0

func load_profile() -> void:
	if not FileAccess.file_exists(path):
		sanitize_storage()
		return
	apply_data(JSON.parse_string(FileAccess.get_file_as_string(path)))

func apply_data(parsed) -> void:
	# Contracts §4.1. `version` is never bumped, but a save whose version is
	# missing or unexpected must still be salvaged: skipping the import used to
	# leave the defaults in place, and the next `save_profile()` then overwrote
	# the file with them (silent data loss). Every known key is imported when its
	# type matches, and `version` is forced back to 1 below, so this profile can
	# neither read nor write another version.
	if parsed is Dictionary:
		if not parsed.has("home"): data["home"]=Homestead.clean({})
		if not parsed.has("trade_history"): data["trade_history"]=[]
		if not parsed.has("attributes"):
			data["attributes"]={}
		# An account that never banked anything must not inherit the vault of the
		# profile that was loaded before it — switching accounts reuses this object.
		if not parsed.has("warehouse"):
			data["warehouse"]=make_vault()
			data["warehouse_spill"]=[]
		# A save written before the vault became a grid holds a flat array. Hand it
		# straight to `sanitize_warehouse()`, because the type-matched import loop
		# below compares shapes: an array would never match the container dictionary
		# and the whole vault would be replaced by an empty one.
		if parsed.get("warehouse") is Array:
			data["warehouse"]=parsed["warehouse"]
		for key in data:
			# Deliberately not imported: whatever the file claims, the profile we
			# hold is version 1 (server/app.py:409 rejects anything else on upload).
			if key == "version": continue
			if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
				data[key] = parsed[key]
		# JSON numbers are floats, while defaults contain integers. `ashes` lands in
		# this list so a reloaded save never carries 17.0 instead of 17.
		for key in ["coins","xp","runs","extracts","hero","best","ashes","loot_value"]:
			if parsed.get(key) is float or parsed.get(key) is int:
				data[key] = maxi(0,int(parsed[key]))
		data.hero = clampi(data.hero,0,roster_size()-1)
		# -1 is "nothing bought yet": the camp issue gear has to be paid for, so it
		# cannot share the non-negative clamp every other counter uses. JSON hands
		# numbers back as floats, which never match the integer default above, so this
		# reads the parsed value rather than the imported one.
		var bought = parsed.get("gear",data.get("gear",-1))
		data["gear"] = clampi(int(bought),-1,Catalog.GEAR.size()-1) if (bought is int or bought is float) else -1
		if data.talents.size() != 3:
			data.talents = [0,0,0]
		for i in 3:
			data.talents[i] = clampi(int(data.talents[i]),0,5)
	data["version"]=1
	sanitize_storage()
	# One-time hand-off of legacy home counts to the vault (see migrate_home_stock).
	migrate_home_stock()

# --- hidden recruits ---------------------------------------------------------
# Which heroes this profile may pick. The base three are always available; a
# recruit only joins once the ending that unlocks them has been reached and
# written back to the save file.
func unlocks() -> Dictionary:
	var saved = data.get("unlocks",{})
	return saved if saved is Dictionary else {}

func unlock(key: String) -> bool:
	var earned := unlocks()
	if bool(earned.get(key,false)):
		return false
	earned[key]=true
	data["unlocks"]=earned
	return true

func has_recruit(index: int) -> bool:
	if index<Catalog.BASE_ROSTER:
		return true
	for key in RECRUIT_HEROES:
		if int(RECRUIT_HEROES[key])==index:
			return bool(unlocks().get(key,false))
	return false

func roster_size() -> int:
	var size := Catalog.BASE_ROSTER
	for key in RECRUIT_HEROES:
		if bool(unlocks().get(key,false)) and int(RECRUIT_HEROES[key])<Catalog.HEROES.size():
			size=maxi(size,int(RECRUIT_HEROES[key])+1)
	return mini(Catalog.HEROES.size(),size)

# The dimensional pocket always keeps its 4x4 grid; the backpack only changes
# quality, and both are repaired here so a hand-edited save cannot break a run.
func sanitize_storage() -> void:
	data["home"]=Homestead.clean(data.get("home",{}))
	sanitize_attributes()
	sanitize_growth()
	sanitize_daily()
	sanitize_warehouse()
	sanitize_loadout()
	data.pocket=Catalog.clean_container(data.get("pocket",{}),Catalog.POCKET_GRID)
	data.bag_key=data.bag_key if Catalog.has_tier(str(data.bag_key)) else Catalog.DEFAULT_BAG_KEY
	var bags: Array = data.get("bags",[])
	var result: Array = []
	for entry in bags:
		if not entry is Dictionary:
			continue
		var key := str(entry.get("key",Catalog.DEFAULT_BAG_KEY))
		result.append(Catalog.clean_container(entry,Catalog.tier(key).grid))
	if result.is_empty():
		result.append(Catalog.clean_container({"key":data.bag_key,"items":[]},Catalog.tier(data.bag_key).grid))
	data.bags=result

# Contracts §4: `ashes` is the meta currency and `growth` maps a tree node id to
# its level. Neither may ever reach the tree code as a hand-edited value: a
# negative level, a non-numeric level or a non-dictionary `growth` is dropped
# here. The per-node level cap lives in the tree itself (RogueGrowth.tree()).
func sanitize_growth() -> void:
	var ashes = data.get("ashes",0)
	data["ashes"]=maxi(0,int(ashes)) if (ashes is int or ashes is float) else 0
	var raw = data.get("growth",{})
	var clean: Dictionary = {}
	if raw is Dictionary:
		for key in raw:
			var level = raw[key]
			if level is int or level is float:
				var value := int(level)
				if value > 0: clean[str(key)]=value
	data["growth"]=clean

# CHANGE-LOG v3-1: `daily` maps `daily:YYYY-MM-DD` to `{"best":int,"plays":int}`.
# Only the newest MAX_DAILY_RECORDS days survive; an out-of-range date, a key without
# the prefix, or a value that `RogueDaily.normalize_record()` cannot read is dropped.
# Nothing here throws:`record_daily()` writes through this same module.
func sanitize_daily() -> void:
	var raw = data.get("daily",{})
	var clean: Dictionary = {}
	if raw is Dictionary:
		for key in raw:
			var text := str(key)
			if not text.begins_with(Daily.RECORD_PREFIX): continue
			var date := text.substr(Daily.RECORD_PREFIX.length())
			if not Daily.is_date_string(date): continue
			var record := Daily.normalize_record(raw[key])
			if record.is_empty(): continue
			clean[Daily.RECORD_PREFIX+Daily.normalize_date(date)]=record
	if clean.size() > MAX_DAILY_RECORDS:
		# ISO date keys sort chronologically, so the tail is the most recent history.
		var keys: Array = clean.keys()
		keys.sort()
		var trimmed: Dictionary = {}
		for i in range(keys.size()-MAX_DAILY_RECORDS,keys.size()):
			trimmed[keys[i]]=clean[keys[i]]
		clean=trimmed
	data["daily"]=clean

# Everything that travels into a raid: the sealed pocket, the backpacks, and the kit
# the Watcher is wearing. Worn equipment used to be run-local ("wear it now or carry
# it home, never both"); it is part of the save now, so it is handed over here too.
func storage_payload() -> Dictionary:
	sanitize_storage()
	return {"pocket":data.pocket.duplicate(true),"bags":data.bags.duplicate(true),"bag_key":str(data.bag_key),"loadout":data.loadout.duplicate(true)}

func save_profile() -> void:
	# Contracts §4.1: the file on disk is always version 1, whatever the in-memory
	# dictionary was handed (a bumped version would make app.py:409 reject the
	# upload and a future load skip the whole import).
	data["version"]=1
	data["home"]=Homestead.clean(data.get("home",{}))
	sanitize_attributes()
	sanitize_warehouse()
	sanitize_loadout()
	sanitize_growth()
	sanitize_daily()
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data,"\t"))
		file.close()
		if DirAccess.rename_absolute(path+".tmp",path)==OK:
			saved.emit()

func sanitize_attributes() -> void:
	data["attributes"]=WatcherAttributes.clean(data.get("attributes",{}),WatcherAttributes.point_budget(int(data.xp)))

func attribute_points() -> int:
	sanitize_attributes()
	return maxi(0,WatcherAttributes.point_budget(int(data.xp))-WatcherAttributes.spent(data.attributes))

func raise_attribute(key: String) -> bool:
	if key not in WatcherAttributes.KEYS or attribute_points()<=0 or int(data.attributes[key])>=WatcherAttributes.CAP:
		return false
	data.attributes[key]+=1
	save_profile()
	return true

func level() -> int:
	return 1 + int(data.xp / 180)

func upgrade(index: int) -> bool:
	var cost := 80 + int(data.talents[index])*65
	if data.coins < cost or data.talents[index] >= 5:
		return false
	data.coins -= cost
	data.talents[index] += 1
	save_profile()
	return true

# --- the vault ---------------------------------------------------------------
# The vault used to be a flat array with no coordinates: everything the player ever
# banked was appended and drawn as one card list. It is a real 15x15 grid container
# now, laid out exactly like the pocket and the backpacks, so a deposit can be
# refused for want of room and the panel can show it as a cabinet.
#
# Two rules keep it honest:
#   * `sanitize_warehouse()` upgrades an old save once, in place;
#   * `warehouse_deposit()` is the only way in, and it reports what did not fit.
# Anything the grid cannot take waits in `warehouse_spill` rather than being
# destroyed — a full vault must never eat loot the player already earned.

func make_vault() -> Dictionary:
	return {"items":[],"gw":Catalog.WAREHOUSE_GRID.x,"gh":Catalog.WAREHOUSE_GRID.y,"next":1}

# The vault dictionary itself, created on first use. A save written before the vault
# existed (or a fresh profile that only ran `load_profile()` against a missing file)
# has no "warehouse" key at all; without this the camp panel would silently bank
# nothing instead of opening an empty vault.
func vault() -> Dictionary:
	var vault = data.get("warehouse",null)
	if not vault is Dictionary or vault.is_empty():
		vault=make_vault()
		data["warehouse"]=vault
	if not (vault.get("items",[]) is Array): vault["items"]=[]
	vault["gw"]=Catalog.WAREHOUSE_GRID.x
	vault["gh"]=Catalog.WAREHOUSE_GRID.y
	return vault

# The grid half of the vault, defensively: a hand-edited save can put anything in
# "items", and every reader below walks this list.
func vault_items() -> Array:
	var vault = data.get("warehouse",{})
	if not vault is Dictionary: return []
	var list = vault.get("items",[])
	return list if list is Array else []

# The vault's contents as one list: the grid first, then whatever is parked in the
# spill list. Read-only — mutating a copy would not reach the save file — so the
# writers below go through `warehouse_item()` / `warehouse_remove()`.
func warehouse_items() -> Array:
	var list: Array = vault_items()
	var spill = data.get("warehouse_spill",[])
	if spill is Array and not spill.is_empty():
		list=list.duplicate()
		for item in spill: list.append(item)
	return list

func warehouse_count() -> int:
	var spill = data.get("warehouse_spill",[])
	return vault_items().size() + (spill.size() if spill is Array else 0)

# The live entry at that index, so a caller may still adjust a stack's count.
func warehouse_item(index: int) -> Dictionary:
	var list: Array = vault_items()
	if index>=0 and index<list.size():
		return list[index]
	var spill = data.get("warehouse_spill",[])
	var at := index-list.size()
	if spill is Array and at>=0 and at<spill.size():
		return spill[at]
	return {}

func warehouse_remove(index: int) -> bool:
	var list: Array = vault_items()
	if index>=0 and index<list.size():
		list.remove_at(index)
		return true
	var spill = data.get("warehouse_spill",[])
	var at := index-list.size()
	if spill is Array and at>=0 and at<spill.size():
		spill.remove_at(at)
		return true
	return false

# The vault's live worth: what the exchange would pay for everything in it right
# now, spill included. This is a running total, not the lifetime tally below.
func warehouse_value() -> int:
	return Catalog.market_total(warehouse_items())

func warehouse_units_of(item: Dictionary) -> int:
	var kind := str(item.get("kind",""))
	if not Catalog.ITEMS.has(kind): return 0
	return clampi(int(item.get("count",1)),1,Catalog.max_stack(kind)) if Catalog.stacks(kind) else 1

# Adds the value of one newly banked item to the lifetime tally, once per instance.
# The `valued` stamp rides on the item through every container and the save file, so
# a withdraw/store loop pays nothing the second time.
func credit_loot_value(item: Dictionary) -> void:
	data["loot_value"]=int(data.get("loot_value",0))+Catalog.market_value(item)

# One more unit of a stackable item joins an existing stack when there is room, and
# otherwise starts a fresh one. The fresh entry is copied from `blank` — a validated
# single item — so a stack never loses the fields that are not about quantity, such
# as "provision" (a camp-issued supply is unsellable, and must stay that way).
#
# A stack only accepts more of its own kind *and* its own provenance: merging a
# camp-issued medkit into a looted pile of them would launder it into something the
# exchange pays for.
func place_vault_unit(kind: String, blank: Dictionary) -> bool:
	var vault: Dictionary=data["warehouse"]
	var issued := bool(blank.get("provision",false))
	for existing in Catalog.container_items(vault):
		if str(existing.get("kind",""))!=kind: continue
		if bool(existing.get("provision",false))!=issued: continue
		if int(existing.get("count",1))>=Catalog.max_stack(kind): continue
		existing["count"]=int(existing.get("count",1))+1
		if bool(blank.get("valued",false)): existing["valued"]=true
		return true
	var one: Dictionary=blank.duplicate(true)
	one["count"]=1
	return Catalog.place_item(vault,one)

# Lays one item into the vault grid, growing stacks where it can. Returns how many
# units the grid could not take (0 = everything went in).
func warehouse_deposit(item: Dictionary) -> int:
	var kind := str(item.get("kind",""))
	if not Catalog.ITEMS.has(kind): return 0
	var blank := Catalog.clean_slot_entry(item)
	if blank.is_empty(): return 0
	blank["valued"]=bool(item.get("valued",false))
	if Catalog.stacks(kind):
		var units := clampi(int(item.get("count",1)),1,Catalog.max_stack(kind))
		while units>0:
			if not place_vault_unit(kind,blank): break
			units-=1
		return units
	if Catalog.place_item(data["warehouse"],blank): return 0
	return 1

# A deposit made by hand from the bag panel: all or nothing. The grid snapshot is
# what makes that possible — a stack that only half fits is rolled back, because a
# refusal must leave the vault exactly as it was.
func bank_item(item: Dictionary) -> bool:
	var kind := str(item.get("kind",""))
	if not Catalog.ITEMS.has(kind): return false
	var vault: Dictionary=vault()
	var snapshot: Array=vault.items.duplicate(true)
	var credited := not bool(item.get("valued",false))
	var probe: Dictionary=item.duplicate(true)
	if credited: probe["valued"]=true
	if warehouse_deposit(probe)>0:
		vault["items"]=snapshot
		return false
	if credited: credit_loot_value(item)
	return true

# A deposit aimed at one cell rather than the first free one: what a drag into the
# vault means. All or nothing, and it pays the lifetime tally through the very same
# `valued` stamp `bank_item()` uses.
func bank_item_at(item: Dictionary, cell: Vector2i) -> bool:
	var kind := str(item.get("kind",""))
	if not Catalog.ITEMS.has(kind): return false
	var credited := not bool(item.get("valued",false))
	var probe: Dictionary=item.duplicate(true)
	if credited: probe["valued"]=true
	var list: Array = vault_items()
	if not Catalog.can_place(list,probe,cell,-1,Catalog.WAREHOUSE_GRID): return false
	var vault: Dictionary=vault()
	probe["x"]=cell.x
	probe["y"]=cell.y
	probe["id"]=int(vault.get("next",1))
	list.append(probe)
	vault["next"]=int(vault.get("next",1))+1
	if credited: credit_loot_value(item)
	return true

# The vault as it stands when a save is loaded or written: the grid is re-validated
# against 15x15, and a pre-grid save is laid out once, in place.
func sanitize_warehouse() -> void:
	var stored = data.get("warehouse",null)
	data["warehouse"]=make_vault()
	var spill: Array = []
	if stored is Dictionary:
		if not stored.get("items",[]) is Array: stored["items"]=[]
		data["warehouse"]=Catalog.clean_container(stored,Catalog.WAREHOUSE_GRID)
	elif stored is Array:
		# The old flat list. Coordinates were always discarded, so the entries are
		# laid out row-major here; they are stamped as already counted, because they
		# were earned before the lifetime tally existed.
		for entry in stored:
			var item := Catalog.clean_slot_entry(entry)
			if item.is_empty(): continue
			item["valued"]=true
			var left := warehouse_deposit(item)
			if left>0:
				var rest: Dictionary=item.duplicate(true)
				rest["count"]=left
				spill.append(rest)
	var raw_spill = data.get("warehouse_spill",[])
	var clean_spill: Array = []
	if raw_spill is Array:
		for entry in raw_spill:
			var item := Catalog.clean_slot_entry(entry)
			if not item.is_empty(): clean_spill.append(item)
	for item in spill: clean_spill.append(item)
	data["warehouse_spill"]=clean_spill
	if not data.get("trade_history",[]) is Array: data["trade_history"]=[]

# Parks whatever the grid could not take, so nothing earned is ever destroyed.
func spill_item(item: Dictionary, units: int) -> void:
	if units<=0: return
	var rest: Dictionary=item.duplicate(true)
	rest["count"]=units
	rest["valued"]=true
	var spill = data.get("warehouse_spill",[])
	if not spill is Array:
		spill=[]
		data["warehouse_spill"]=spill
	spill.append(rest)

# What one settlement hands to the vault: the carried containers are emptied into
# the grid, and the lifetime tally grows by whatever has never been counted before.
# Returns {"stored":units,"spilled":units} — the spill is the vault being full, not
# loot going missing.
func bank_carried_items(extra: Array = []) -> Dictionary:
	sanitize_storage()
	var stored := 0
	var spilled := 0
	var containers: Array = [data.pocket]+data.bags
	for container in containers:
		for item in Catalog.container_items(container):
			var outcome := bank_one(item)
			stored+=int(outcome.stored)
			spilled+=int(outcome.spilled)
		container["items"]=[]
	for item in extra:
		if item is Dictionary:
			var outcome := bank_one(item)
			stored+=int(outcome.stored)
			spilled+=int(outcome.spilled)
	return {"stored":stored,"spilled":spilled}

func bank_one(item: Dictionary) -> Dictionary:
	var kind := str(item.get("kind",""))
	if not Catalog.ITEMS.has(kind): return {"stored":0,"spilled":0}
	var units := warehouse_units_of(item)
	var credited := not bool(item.get("valued",false))
	var probe: Dictionary=item.duplicate(true)
	if credited: probe["valued"]=true
	var left := warehouse_deposit(probe)
	if left>0: spill_item(item,left)
	# The whole item ends up in the vault one way or another, so it is counted once
	# here whatever the split between grid and spill.
	if credited: credit_loot_value(item)
	return {"stored":units-left,"spilled":left}

func withdraw_item(index: int, pocket: bool = false) -> bool:
	var item := warehouse_item(index)
	if item.is_empty(): return false
	var target: Dictionary=data.pocket if pocket else data.bags[0]
	var copy: Dictionary=item.duplicate(true)
	copy["id"]=int(target.get("next",1))
	if not Catalog.place_item(target,copy): return false
	warehouse_remove(index)
	save_profile()
	return true

# --- worn kit ----------------------------------------------------------------
# One weapon, three gear pieces, two charms and the three quick sockets. The shape
# and its validation live in `Catalog.clean_loadout()`, which the session reads the
# same loadout back through when a raid is configured.
func empty_loadout() -> Dictionary:
	return Catalog.empty_loadout()

func sanitize_loadout() -> void:
	data["loadout"]=Catalog.clean_loadout(data.get("loadout",{}))

# The camp issue gear is bought, one piece at a time. Swapping settles the
# difference between the two price tags: a dearer piece is paid for, a cheaper one
# refunds, and the piece being taken off is destroyed — it was never an item, only
# the standing issue. A swap that cannot be paid for changes nothing at all.
# Returns {"ok","name","paid","refunded","short","reason"} for the caller to report.
func buy_gear(index: int) -> Dictionary:
	if index<0 or index>=Catalog.GEAR.size():
		return {"ok":false,"reason":"未知的装备。"}
	var current := int(data.get("gear",-1))
	if current==index:
		return {"ok":false,"reason":"已经装备着 %s。" % str(Catalog.GEAR[index].name)}
	var delta := Catalog.gear_price(index)-Catalog.gear_price(current)
	if delta>0 and int(data.coins)<delta:
		return {"ok":false,"reason":"银币不足","short":delta-int(data.coins),"price":delta,"name":str(Catalog.GEAR[index].name)}
	data["coins"]=int(data.coins)-delta
	data["gear"]=index
	save_profile()
	return {"ok":true,"name":str(Catalog.GEAR[index].name),"paid":maxi(0,delta),"refunded":maxi(0,-delta)}

# --- homestead produce as real loot ---------------------------------------
# Crops and fish are carried backpack items now, not a counter on the homestead.
# These three helpers are the only bridge the camp and the kitchen use: what a
# harvest or a catch puts away, and what a recipe takes back out.

# The carried backpack is the first bag in the save file; the pocket is the safe
# one. A single 1x1 product joins the bag (growing a stack where one fits), then
# the pocket, and reports how many units had nowhere to go — that overflow is what
# drops on the ground for the player to pick up by hand.
func receive_product(kind: String, units: int) -> int:
	if not Catalog.ITEMS.has(kind) or units<=0: return units
	var left := units
	for container in [data.bags[0], data.pocket]:
		while left>0:
			if not Catalog.place_loot(container,kind): break
			left-=1
	save_profile()
	return left

# Total product units across every storage the kitchen draws from: the carried
# backpack, the safe pocket and the permanent warehouse. A stack counts its units,
# not its slot, so six wheat is six — which is how the kitchen and the harvest
# message read a holding.
func product_count(kind: String) -> int:
	var total := 0
	for container in [data.bags[0], data.pocket]:
		for item in Catalog.container_items(container):
			if str(item.get("kind",""))==kind:
				total+=clampi(int(item.get("count",1)),1,Catalog.max_stack(kind))
	for item in warehouse_items():
		if str(item.get("kind",""))==kind: total+=clampi(int(item.get("count",1)),1,Catalog.max_stack(kind))
	return total

# Spend `units` of a product, one instance at a time (a stack of six counts as
# six). Consumes the backpack and pocket first, then the warehouse, so a cooked
# meal eats what the Watcher is actually carrying before raiding the vault.
func spend_product(kind: String, units: int) -> bool:
	if product_count(kind)<units: return false
	var left := units
	for container in [data.bags[0], data.pocket]:
		var list: Array=container.get("items",[])
		for i in range(list.size()-1,-1,-1):
			if left<=0: break
			if str(list[i].get("kind",""))!=kind: continue
			var held := clampi(int(list[i].get("count",1)),1,Catalog.max_stack(kind))
			if held<=left:
				left-=held
				list.remove_at(i)
			else:
				list[i]["count"]=held-left
				left=0
	var i: int = warehouse_count()-1
	while left>0 and i>=0:
		var entry := warehouse_item(i)
		if str(entry.get("kind",""))==kind:
			var held := clampi(int(entry.get("count",1)),1,Catalog.max_stack(kind))
			if held<=left:
				left-=held
				warehouse_remove(i)
			else:
				entry["count"]=held-left
				left=0
		i-=1
	save_profile()
	return true

# Sell `units` of a product from the home shop. Unlike the kitchen's `spend_product`
# (which eats what the Watcher carries first), a sale works the vault over *before*
# the bags: the shop promised to delete "the entity that occupies a grid cell", and
# the vault cells are exactly where those entities sit. A full stack that goes leaves
# its cell; a partial sale trims the stack's count in place. Whatever the grid cannot
# cover comes out of the pocket and the carried bag the same way, so the deleted
# copies always come from wherever they really are. Provision-marked entries are
# skipped: they are camp-issued supplies the exchange refuses too (see market_value).
# Pays the catalog unit price per copy sold — never more than the holding — records
# the sale in the trade history, and saves.
func sell_product(kind: String, units: int) -> Dictionary:
	if not Catalog.ITEMS.has(kind) or units<=0:
		return {"sold":0,"coins":0,"missing":maxi(0,units)}
	var left := units
	var sold := 0
	var i: int = warehouse_count()-1
	while left>0 and i>=0:
		var entry := warehouse_item(i)
		if str(entry.get("kind",""))==kind and not bool(entry.get("provision",false)):
			var held := warehouse_units_of(entry)
			if held>0:
				if held<=left:
					left-=held
					sold+=held
					warehouse_remove(i)
				else:
					entry["count"]=held-left
					sold+=left
					left=0
		i-=1
	for container in [data.bags[0], data.pocket]:
		var list: Array = container.get("items",[])
		for j in range(list.size()-1,-1,-1):
			if left<=0: break
			if str(list[j].get("kind",""))!=kind or bool(list[j].get("provision",false)): continue
			var held := clampi(int(list[j].get("count",1)),1,Catalog.max_stack(kind))
			if held<=left:
				left-=held
				sold+=held
				list.remove_at(j)
			else:
				list[j]["count"]=held-left
				sold+=left
				left=0
	var price := int(Catalog.item_value({"kind":kind}))
	var earned := sold*price
	if sold>0:
		data.coins=int(data.coins)+earned
		data.trade_history.push_front({"name":str(Catalog.ITEMS[kind].name),"value":earned,"time":Time.get_unix_time_from_system()})
		data.trade_history=data.trade_history.slice(0,30)
		save_profile()
	return {"sold":sold,"coins":earned,"missing":left}

# CHANGE-LOG: home.stock used to hold crop and fish counts. Now that produce is
# carried as real loot, any count still sitting in an old save has to be handed to
# the vault or it would vanish — the harvests a Watcher already paid for. Runs once
# and leaves the stock empty; the carried bag is left for the player to sort.
func migrate_home_stock() -> void:
	var home: Dictionary = data.get("home",{})
	var stock: Dictionary = home.get("stock",{})
	if not stock is Dictionary: return
	for kind in stock.keys():
		var units := clampi(int(stock.get(kind,0)),0,9999)
		if units<=0 or not Catalog.ITEMS.has(str(kind)):
			continue
		var remaining := units
		while remaining>0:
			var batch := mini(6,remaining)
			# Stamp these as already counted: they were earned before the lifetime
			# tally existed, and the vault must not report them as new loot.
			var item := {"kind":str(kind),"count":batch,"x":0,"y":0,"rot":false,"valued":true}
			var left := warehouse_deposit(item)
			if left>0: spill_item(item,left)
			remaining-=batch
	for key in stock.keys():
		stock[key]=0

func sell_items(indices: Array) -> int:
	var unique: Array = []
	for index in indices:
		if index is int and index>=0 and index<warehouse_count() and index not in unique and Catalog.market_value(warehouse_item(index))>0:
			unique.append(index)
	unique.sort()
	unique.reverse()
	var total := 0
	for index in unique:
		var item: Dictionary=warehouse_item(index)
		var value := Catalog.market_value(item)
		total+=value
		data.trade_history.push_front({"name":Catalog.item_name(item),"value":value,"time":Time.get_unix_time_from_system()})
		warehouse_remove(index)
	data.trade_history=data.trade_history.slice(0,30)
	data.coins+=total
	if not unique.is_empty(): save_profile()
	return total
