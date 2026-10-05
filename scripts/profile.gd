class_name Profile
extends RefCounted

signal saved

var data: Dictionary = {"version":1,"name":"守夜人","coins":160,"xp":0,"runs":0,"extracts":0,"hero":0,"gear":0,"talents":[0,0,0],"volume":0.65,"voice_volume":0.9,"music_volume":0.7,"fullscreen":false,"best":0,"pocket":{"key":"white","items":[],"gw":4,"gh":4,"next":1},"bag_key":"white","bags":[{"key":"white","items":[],"next":1}],"unlocks":{},"attributes":{}}
const Homestead = preload("res://scripts/homestead.gd")

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
	if parsed is Dictionary and parsed.get("version",0) == 1:
		for key in ["warehouse","trade_history","home"]:
			if not parsed.has(key): data[key]=Homestead.clean({}) if key=="home" else []
		if not parsed.has("attributes"):
			data["attributes"]={}
		for key in data:
			if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
				data[key] = parsed[key]
		# JSON numbers are floats, while defaults contain integers.
		for key in ["coins","xp","runs","extracts","hero","gear","best"]:
			if parsed.get(key) is float or parsed.get(key) is int:
				data[key] = maxi(0,int(parsed[key]))
		data.hero = clampi(data.hero,0,roster_size()-1)
		data.gear = clampi(data.gear,0,2)
		if data.talents.size() != 3:
			data.talents = [0,0,0]
		for i in 3:
			data.talents[i] = clampi(int(data.talents[i]),0,5)
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

# Only the pocket and the spare backpacks travel through the save file.
func storage_payload() -> Dictionary:
	sanitize_storage()
	return {"pocket":data.pocket.duplicate(true),"bags":data.bags.duplicate(true),"bag_key":str(data.bag_key)}

func save_profile() -> void:
	data["home"]=Homestead.clean(data.get("home",{}))
	sanitize_attributes()
	sanitize_warehouse()
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
