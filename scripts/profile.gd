class_name Profile
extends RefCounted

signal saved

var data: Dictionary = {"version":1,"name":"守夜人","coins":160,"xp":0,"runs":0,"extracts":0,"hero":0,"gear":0,"talents":[0,0,0],"volume":0.65,"voice_volume":0.9,"music_volume":0.7,"fullscreen":false,"best":0,"pocket":{"key":"white","items":[],"gw":4,"gh":4,"next":1},"bag_key":"white","bags":[{"key":"white","items":[],"next":1}],"unlocks":{},"attributes":{},
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
	data["warehouse"]=[]
	data["trade_history"]=[]

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
		for key in ["warehouse","trade_history","home"]:
			if not parsed.has(key): data[key]=Homestead.clean({}) if key=="home" else []
		if not parsed.has("attributes"):
			data["attributes"]={}
		for key in data:
			# Deliberately not imported: whatever the file claims, the profile we
			# hold is version 1 (server/app.py:409 rejects anything else on upload).
			if key == "version": continue
			if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
				data[key] = parsed[key]
		# JSON numbers are floats, while defaults contain integers. `ashes` lands in
		# this list so a reloaded save never carries 17.0 instead of 17.
		for key in ["coins","xp","runs","extracts","hero","gear","best","ashes"]:
			if parsed.get(key) is float or parsed.get(key) is int:
				data[key] = maxi(0,int(parsed[key]))
		data.hero = clampi(data.hero,0,roster_size()-1)
		data.gear = clampi(data.gear,0,2)
		if data.talents.size() != 3:
			data.talents = [0,0,0]
		for i in 3:
			data.talents[i] = clampi(int(data.talents[i]),0,5)
	data["version"]=1
	sanitize_storage()

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

# Only the pocket and the spare backpacks travel through the save file.
func storage_payload() -> Dictionary:
	sanitize_storage()
	return {"pocket":data.pocket.duplicate(true),"bags":data.bags.duplicate(true),"bag_key":str(data.bag_key)}

func save_profile() -> void:
	# Contracts §4.1: the file on disk is always version 1, whatever the in-memory
	# dictionary was handed (a bumped version would make app.py:409 reject the
	# upload and a future load skip the whole import).
	data["version"]=1
	data["home"]=Homestead.clean(data.get("home",{}))
	sanitize_attributes()
	sanitize_warehouse()
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

# Separate from carried storage: warehouse items never enter a raid implicitly.
func sanitize_warehouse() -> void:
	var clean: Array = []
	var entries = data.get("warehouse",[])
	if entries is Array:
		for entry in entries:
			if entry is Dictionary and Catalog.ITEMS.has(str(entry.get("kind",""))):
				var container := Catalog.clean_container({"items":[entry.duplicate(true)]},Vector2i(16,16))
				# Warehouse has no grid; discard carried coordinates before validation.
				if container.items.is_empty():
					var copy: Dictionary=entry.duplicate(true)
					copy.x=0; copy.y=0
					container=Catalog.clean_container({"items":[copy]},Vector2i(16,16))
				if not container.items.is_empty():
					var item: Dictionary=container.items[0]
					item["count"]=clampi(int(item.get("count",1)),1,Catalog.max_stack(str(item.kind)))
					clean.append(item)
	data["warehouse"]=clean
	if not data.get("trade_history",[]) is Array: data["trade_history"]=[]
	if not data.has("trade_history"): data["trade_history"]=[]

func bank_carried_items(extra: Array = []) -> int:
	sanitize_storage()
	var count := 0
	var containers: Array = [data.pocket]+data.bags
	for container in containers:
		for item in container.items:
			data.warehouse.append(item.duplicate(true))
			count+=1
		container.items=[]
	for item in extra:
		if item is Dictionary and Catalog.ITEMS.has(str(item.get("kind",""))):
			data.warehouse.append(item.duplicate(true))
			count+=1
	sanitize_warehouse()
	return count

func withdraw_item(index: int, pocket: bool = false) -> bool:
	if index<0 or index>=data.warehouse.size(): return false
	var target: Dictionary=data.pocket if pocket else data.bags[0]
	var item: Dictionary=data.warehouse[index].duplicate(true)
	item["id"]=int(target.get("next",1))
	if not Catalog.place_item(target,item): return false
	data.warehouse.remove_at(index)
	save_profile()
	return true

func sell_items(indices: Array) -> int:
	var unique: Array = []
	for index in indices:
		if index is int and index>=0 and index<data.warehouse.size() and index not in unique and Catalog.market_value(data.warehouse[index])>0:
			unique.append(index)
	unique.sort()
	unique.reverse()
	var total := 0
	for index in unique:
		var item: Dictionary=data.warehouse[index]
		var value := Catalog.market_value(item)
		total+=value
		data.trade_history.push_front({"name":Catalog.item_name(item),"value":value,"time":Time.get_unix_time_from_system()})
		data.warehouse.remove_at(index)
	data.trade_history=data.trade_history.slice(0,30)
	data.coins+=total
	if not unique.is_empty(): save_profile()
	return total
