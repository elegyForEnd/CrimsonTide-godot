class_name TideSession
extends Node

signal changed
signal map_changed
signal started
signal finished
signal message(text: String)
signal effect(kind: String, pos: Vector2)
signal combat_event(data: Dictionary)

const PORT := 24872
const DODGE_DURATION := 0.24
const DODGE_DISTANCE := 145.0
const RUN_MULTIPLIER := 1.45
const ONLINE_ULTIMATE_DURATION := 0.85
var players: Dictionary = {}
var inputs: Dictionary = {}
var ruins := Ruins.new()
var map_id := "border"
var map_states: Dictionary = {}
const CITY_GATE := Vector2(3860,1880)
var enemies: Array = []
var bullets: Array = []
var world_drops: Array = []
var results: Dictionary = {}
var running := false
var online := false
var duration := 480.0
var elapsed := 0.0
var threat := 0.0
var objectives := 0
var seed_value := 0
var sync_timer := 0.0
var spawn_timer := 0.0
var input_timer := 0.0
var next_enemy := 0
var local_config: Dictionary = {}
var local_input := {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"fire":false,"interact":false}
var rng := RandomNumberGenerator.new()
var report_paid := false
var request_cooldowns: Dictionary = {}
var pending_ultimates: Dictionary = {}

const SEARCH_SECONDS := 1.2
const SEARCH_RANGE := 86.0

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): disconnect_room(); message.emit("连接失败：请检查地址、防火墙和 UDP 24872 端口。"))
	multiplayer.server_disconnected.connect(func(): disconnect_room(); message.emit("房主已断开连接。本局未结算的战利品不计入存档。"))

func my_id() -> int:
	return multiplayer.get_unique_id() if online else 1

func authority() -> bool:
	return not online or multiplayer.is_server()

func solo(config: Dictionary) -> void:
	disconnect_room()
	local_config=config
	players[1]=make_player(1,config)
	changed.emit()

func host(config: Dictionary) -> Error:
	disconnect_room()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT,3)
	if err != OK:
		return err
	multiplayer.multiplayer_peer=peer
	online=true
	local_config=config
	players[1]=make_player(1,config)
	changed.emit()
	return OK

func join(address: String, config: Dictionary) -> Error:
	disconnect_room()
	local_config=config
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(),PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer=peer
	online=true
	return OK

func disconnect_room() -> void:
	running=false
	pending_ultimates.clear()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	online=false
	players.clear()
	inputs.clear()
	results.clear()
	changed.emit()

func _connected() -> void:
	register.rpc_id(1,local_config)

@rpc("any_peer","call_remote","reliable")
func register(config: Dictionary) -> void:
	if not authority():
		return
	var id := multiplayer.get_remote_sender_id()
	if running or players.size()>=4:
		rejected.rpc_id(id,"房间已出发或已满，请等待下一局。")
		return
	players[id]=make_player(id,config)
	push_lobby()

@rpc("authority","call_remote","reliable")
func rejected(reason: String) -> void:
	disconnect_room()
	message.emit(reason)

func make_player(id: int, config: Dictionary) -> Dictionary:
	var h := clampi(int(config.get("hero",0)),0,2)
	var talents: Array = config.get("talents",[0,0,0])
	if talents.size()!=3:
		talents=[0,0,0]
	for i in 3:
		talents[i]=clampi(int(talents[i]),0,5)
	var gear := clampi(int(config.get("gear",0)),0,2)
	var hp: float=Catalog.HEROES[h].hp+talents[0]*12+Catalog.GEAR[gear].hp
	var storage := storage_from_config(config)
	# A raid starts with nothing but the hero issue weapon: the four field weapons
	# are loot, so the only way into a Watcher's hands is picking one up and
	# equipping it. make_player therefore never reads a weapon from the config.
	var player := {"id":id,"name":str(config.get("name","守夜人")).left(16),"hero":h,"weapon":Catalog.starter_index(h),"swing_time":0.0,"swing_total":0.0,"pending_strike":false,"strike_aim":Vector2.RIGHT,"combo":0,"combo_timeout":0.0,"hitstop":0.0,"cast_time":0.0,"gear":gear,"talents":talents,"equipped":empty_equipment(),"ready":id==1,"p":Ruins.SPAWN,"aim":Vector2.RIGHT,"hp":hp,"max_hp":hp,"sanity":100.0,"status":"active","pocket":storage.pocket,"backpack":storage.backpack,"bags":storage.bags,"ammo":Catalog.HEROES[h].clip,"reserve":96,"attack":0.0,"reload":0.0,"skill":0.0,"dash":0.0,"invuln":0.0,"channel":0.0,"search":0.0,"search_ref":-1,"target":"","bleed":40.0,"kills":0,"scent":0.0,"meds":clampi(int(config.get("meds",1)),1,3),"self_revive":true,"connected":true}
	player.merge({"motion":"idle","move_dir":Vector2.RIGHT,"move_speed":0.0,"dodge_time":0.0,"dodge_dir":Vector2.RIGHT})
	return player

# What the player wears on top of the camp loadout: one weapon plus the three
# gear slots. It is run-local loot, so it is deliberately never written to the
# save file: wear it now or carry it home, never both.
func empty_equipment() -> Dictionary:
	return {"weapon":{},"gear":[{},{},{}]}

func kit_weapon(p: Dictionary) -> Dictionary:
	var kit = p.get("equipped",{})
	if not kit is Dictionary:
		return {}
	var weapon = kit.get("weapon",{})
	return weapon if weapon is Dictionary else {}

func kit_gear(p: Dictionary) -> Array:
	var kit = p.get("equipped",{})
	if not kit is Dictionary:
		return []
	var gear = kit.get("gear",[])
	return gear if gear is Array else []

# A looted weapon only pays out while it is the weapon in hand.
func weapon_kit_active(p: Dictionary) -> bool:
	var item := kit_weapon(p)
	return not item.is_empty() and int(item.get("weapon",-1))==int(p.weapon)

# True while the player is still holding the temporary weapon they set out with.
# Issue weapons are never upgradable, which is what keeps them below every piece
# of field loot.
func issue_weapon_active(p: Dictionary) -> bool:
	return Catalog.is_starter(int(p.get("weapon",0)))

# Drops the field weapon and puts the hero issue weapon back in hand, so removing
# a weapon never leaves a Watcher swinging at nothing.
func restore_issue_weapon(p: Dictionary) -> void:
	p["weapon"]=Catalog.starter_index(int(p.get("hero",0)))
	p["reload"]=0.0
	p["combo"]=0
	p["pending_strike"]=false

func gear_bonus_of(p: Dictionary, slot: int) -> float:
	var total := 0.0
	for entry in kit_gear(p):
		if entry is Dictionary and not entry.is_empty() and Catalog.gear_slot(entry)==slot:
			total+=Catalog.gear_bonus(entry)
	return total

func equipment_hp(p: Dictionary) -> float:
	return gear_bonus_of(p,0)

func equipment_damage(p: Dictionary) -> float:
	var total := gear_bonus_of(p,1)
	if weapon_kit_active(p):
		total+=Catalog.weapon_bonus(kit_weapon(p))
	return total

func equipment_speed(p: Dictionary) -> float:
	return gear_bonus_of(p,2)

# Attack interval scale: an upgraded weapon swings faster.
func equipment_rate(p: Dictionary) -> float:
	if not weapon_kit_active(p):
		return 1.0
	return maxf(0.4,1.0-Catalog.weapon_rate_bonus(kit_weapon(p)))

func stat_max_hp(p: Dictionary) -> float:
	return Catalog.HEROES[p.hero].hp+p.talents[0]*12+Catalog.GEAR[p.gear].hp+equipment_hp(p)

# Recomputes the ceiling after gear changes: putting armour on grants the extra
# health immediately, taking it off only clamps.
func refresh_max_hp(p: Dictionary) -> void:
	var value := maxf(1.0,stat_max_hp(p))
	var gain := value-float(p.max_hp)
	p.max_hp=value
	p.hp=minf(value,float(p.hp)+maxf(0.0,gain))


# Every player carries two storages: a permanent 4x4 dimensional pocket that is
# written back into the save file, and an equipped backpack whose size follows
# its quality. "bags" holds only the spare backpacks, so the equipped one is
# never counted or spilled twice.
func storage_from_config(config: Dictionary) -> Dictionary:
	var pocket := Catalog.clean_container(config.get("pocket",{}),Catalog.POCKET_GRID)
	# "launch" hands the previous player dictionary back in, so the equipped
	# backpack quality can arrive either as bag_key or as that whole container.
	var equipped: Dictionary = config.get("backpack",{})
	var sent_key := str(equipped.get("key",config.get("bag_key",Catalog.DEFAULT_BAG_KEY)))
	var backpack := Catalog.make_bag(sent_key)
	backpack["gw"]=Catalog.bag_grid(backpack).x
	backpack["gh"]=Catalog.bag_grid(backpack).y
	var cabinet: Array = []
	var claimed := false
	for entry in config.get("bags",[]):
		if entry is Dictionary:
			var key := str(entry.get("key",Catalog.DEFAULT_BAG_KEY))
			if not claimed and key==sent_key:
				# The save file lists the equipped backpack first; adopt its loot.
				backpack=Catalog.clean_container(entry,Catalog.tier(key).grid)
				claimed=true
				continue
			cabinet.append(Catalog.clean_container(entry,Catalog.tier(key).grid))
	return {"pocket":pocket,"backpack":backpack,"bags":cabinet}

func storage_of(p: Dictionary) -> Dictionary:
	return {"pocket":p.pocket,"backpack":p.backpack,"bags":p.bags}

# Containers survive JSON round trips (floats, stray keys), so every entry point
# that hands them back to the simulation re-derives the grid from the quality.
func refresh_storage(p: Dictionary) -> void:
	p["pocket"]=Catalog.clean_container(p.pocket,Catalog.POCKET_GRID)
	p["backpack"]=Catalog.clean_container(p.backpack,Catalog.bag_grid(p.backpack))
	var bags: Array = []
	for entry in p.bags:
		if entry is Dictionary:
			bags.append(Catalog.clean_container(entry,Catalog.bag_grid(entry)))
	p["bags"]=bags

func pocket_label(p: Dictionary) -> String:
	var grid := Catalog.container_grid(p.pocket)
	return "%s  %d×%d" % [Catalog.POCKET_NAME,grid.x,grid.y]

# Consumable and passive effects draw from both containers, so the pocket is a
# usable reserve rather than a dead display case.
func carried(p: Dictionary, kind: String) -> int:
	return Catalog.container_count(p.backpack,kind)+Catalog.container_count(p.pocket,kind)

func crystals_carried(p: Dictionary) -> int:
	return carried(p,"crystal")

func charms_carried(p: Dictionary) -> int:
	return carried(p,"charm")

# Consumables are deterministic: the backpack is spent first and exactly one
# item leaves the player, no matter how many containers hold the same kind.
func spend(p: Dictionary, kind: String) -> bool:
	if Catalog.container_count(p.backpack,kind)>0:
		return Catalog.consume_container(p.backpack,kind)
	if Catalog.container_count(p.pocket,kind)>0:
		return Catalog.consume_container(p.pocket,kind)
	return false

func backpack_label(p: Dictionary) -> String:
	var grid := Catalog.bag_grid(p.backpack)
	return "%s · %s  %d×%d" % [Catalog.bag_quality(p.backpack),Catalog.bag_name(p.backpack),grid.x,grid.y]

# Loot routing: relics are sunk into the safe pocket first, everything else fills
# the backpack the player is carrying. Returns false when both containers are full.
# "meta" carries the fields that make a piece of loot itself (quality, weapon
# index, gear index, tier, stack count) so nothing is lost on the way in.
func store_loot(p: Dictionary, kind: String, provision: bool = false, key: String = "", meta: Dictionary = {}) -> bool:
	var order: Array = ["pocket","backpack"] if Catalog.prefers_pocket(kind) else ["backpack","pocket"]
	for name in order:
		var container: Dictionary=p[name]
		if not Catalog.can_hold(container,kind):
			continue
		if not Catalog.add_item(container,kind):
			continue
		var placed: Dictionary=container.items.back()
		placed["provision"]=provision
		if kind=="backpack":
			# A loose backpack is stored as a 1x1 pack item carrying its quality.
			placed["quality"]=key if Catalog.has_tier(key) else Catalog.DEFAULT_BAG_KEY
		for field in meta:
			placed[field]=meta[field]
		return true
	return false

# The descriptive fields of a loot entry, used to keep weapons, gear and stacks
# intact when loot moves between a container, the ground and the player. Stack
# counts travel as whole units instead, so they are deliberately left out.
static func loot_meta(item: Dictionary) -> Dictionary:
	var meta: Dictionary = {}
	for field in Catalog.SAVED_ITEM_KEYS:
		if item.has(field) and field!="count" and field!="provision":
			meta[field]=item[field]
	return meta


# A carried backpack is itself loot: it remembers which quality it was, so it can
# be worn again by whoever picks it up (or by the player who finds a better one).
func spilled(container: Dictionary, item: Dictionary, spread: float) -> Dictionary:
	var entry := {"p":Vector2.ZERO,"kind":item.kind,"provision":item.get("provision",false)}
	if item.kind=="backpack":
		entry["key"]=str(item.get("quality",Catalog.bag_key(container)))
	if spread>0.0:
		entry["p"]=Vector2(rng.randf_range(-spread,spread),rng.randf_range(-spread*0.8,spread*0.8))
	return entry

# Loose ground loot is a 1x1 "container" holding a single item, so pressing F can
# grab it instantly through the same code path that feeds searched containers.
func ground_drop(at: Vector2, kind: String, key: String = "", provision: bool = false, meta: Dictionary = {}) -> Dictionary:
	var container := loot_container(at,Catalog.chest_grid(0))
	container.items.append({"kind":kind,"x":0,"y":0,"rot":false,"count":1})
	var item: Dictionary=container.items[0]
	if not key.is_empty():
		item["quality"]=key
	if provision:
		item["provision"]=true
	for field in meta:
		item[field]=meta[field]
	container["searched"]=1
	# A dropped backpack names itself so it can be worn again.
	if kind=="backpack":
		container["key"]="bag:"+(key if Catalog.has_tier(key) else Catalog.DEFAULT_BAG_KEY)
	return container

func drop_item(p: Dictionary, slot: String, index: int, key: String = "") -> bool:
	if slot!="backpack" and slot!="pocket":
		return false
	var container: Dictionary=p[slot]
	var list: Array=container.items
	if index<0 or index>=list.size():
		return false
	var bag := loot_container(p.p+Vector2(25,20),Catalog.chest_grid(0))
	bag.items.append(list[index])
	bag["searched"]=container_units(bag)
	# A backpack keeps its quality so whoever grabs it can wear it.
	var bag_key := key
	if bag_key.is_empty() and list[index].kind=="backpack":
		bag_key=str(list[index].get("quality",Catalog.DEFAULT_BAG_KEY))
	if not bag_key.is_empty():
		bag["key"]="bag:"+bag_key
	world_drops.append(bag)
	list.remove_at(index)
	return true

# Death scatters everything in carried storage. The pocket is untouched: sealing
# it against death is the whole point of the dimensional pocket. Worn weapons and
# gear are dropped as well, because wearing loot is a risk, not a bank.
func spill_storage(p: Dictionary) -> void:
	var carried_containers: Array = [p.backpack]
	for bag in p.bags:
		carried_containers.append(bag)
	for container in carried_containers:
		if Catalog.container_items(container).is_empty():
			continue
		var bag := loot_container(Vector2.ZERO,Catalog.chest_grid(0))
		for item in Catalog.container_items(container):
			bag.items.append(item.duplicate())
		bag["key"]="bag:"+Catalog.bag_key(container)
		bag["searched"]=container_units(bag)
		bag["p"]=p.p+Vector2(rng.randf_range(-42,42),rng.randf_range(-34,34))
		world_drops.append(bag)
		container.items.clear()
	# The equipped kit is worn, so it hits the ground as its own pile.
	var worn: Array = []
	var weapon := kit_weapon(p)
	if not weapon.is_empty():
		worn.append(weapon)
	for entry in kit_gear(p):
		if entry is Dictionary and not entry.is_empty():
			worn.append(entry)
	if not worn.is_empty():
		var kit := loot_container(p.p+Vector2(rng.randf_range(-30,30),rng.randf_range(-24,24)),Catalog.chest_grid(0))
		for entry in worn:
			var copy: Dictionary=entry.duplicate()
			copy["x"]=0
			copy["y"]=0
			copy["rot"]=false
			kit.items.append(copy)
		kit["searched"]=container_units(kit)
		world_drops.append(kit)
	p["equipped"]=empty_equipment()
	# The worn field weapon is on the ground now, so the temporary issue weapon is
	# back in hand the moment the Watcher goes down.
	restore_issue_weapon(p)
	var replacement := Catalog.make_bag(Catalog.DEFAULT_BAG_KEY)
	replacement["gw"]=Catalog.bag_grid(replacement).x
	replacement["gh"]=Catalog.bag_grid(replacement).y
	p["backpack"]=replacement
	p["bags"]=[]
	refresh_max_hp(p)

# Reading and writing world containers goes through one place so the search model
# stays identical for chests and for whatever a dead player left behind.
func container_count() -> int:
	return ruins.chests.size()+world_drops.size()

func container_at(index: int) -> Dictionary:
	if index<0:
		return {}
	if index<ruins.chests.size():
		return ruins.chests[index]
	var drop_index := index-ruins.chests.size()
	if drop_index<world_drops.size():
		return world_drops[drop_index]
	return {}

func container_title(container: Dictionary) -> String:
	if container.has("title"): return str(container.title)
	if container.is_empty():
		return "容器"
	var key := str(container.get("key","container"))
	if key.begins_with("bag:"):
		return Catalog.bag_quality({"key":key.substr(4)})+"背包"
	return "深处教堂物资箱" if int(container.get("class",1))>=2 else "物资箱"

func container_is_bag(container: Dictionary) -> bool:
	return str(container.get("key","")).begins_with("bag:")

# F on a container starts searching it; items surface one unit at a time. Searching
# keeps its own timer so the E-channel (revive, shrine, exit) cannot reset it.
func begin_search(p: Dictionary, index: int) -> void:
	var container := container_at(index)
	if container.is_empty():
		return
	if container.items.is_empty() and not container_is_bag(container) and not container.get("fixed_loot",false):
		for entry in chest_loot(bool(container.get("bonus",false)),0.3,loot_floor()):
			place_entry(container,entry)
	p["search"]=0.0
	p["search_ref"]=index

func search_reference(p: Dictionary) -> int:
	return int(p.get("search_ref",-1))

func stop_search(p: Dictionary) -> void:
	p["search"]=0.0
	p["search_ref"]=-1

func advance_search(p: Dictionary, dt: float) -> void:
	var index := search_reference(p)
	var container := container_at(index)
	if container.is_empty() or container_searched(container):
		return
	if p.p.distance_to(container.p)>SEARCH_RANGE:
		return
	p["search"]=float(p.get("search",0.0))+dt
	while float(p["search"])>=SEARCH_SECONDS and not container_searched(container):
		p["search"]=float(p["search"])-SEARCH_SECONDS
		container["searched"]=searched_units(container)+1

func search_target(p: Dictionary) -> int:
	for i in world_drops.size():
		if p.p.distance_to(world_drops[i].p)<70:
			return ruins.chests.size()+i
	for i in ruins.chests.size():
		if p.p.distance_to(ruins.chests[i].p)<80:
			return i
	return -1

# F on loose ground loot: instant pickup, no search window needed.
func pick_up_ground(p: Dictionary) -> bool:
	for i in world_drops.size():
		var bag: Dictionary=world_drops[i]
		if bag.items.is_empty() or bag.p.distance_to(p.p)>=70:
			continue
		var item: Dictionary=bag.items[0]
		var key := str(item.get("quality",Catalog.bag_key({"key":str(bag.get("key","")).substr(4)})))
		if not store_loot(p,str(item.kind),bool(item.get("provision",false)),key,loot_meta(item)):
			return false
		bag.items.remove_at(0)
		bag["searched"]=container_units(bag)
		if bag.items.is_empty():
			world_drops.remove_at(i)
		emit_effect("loot",p.p)
		return true
	return false

# Taking an item out of a searched container into the player's own storage.
func take_loot(p: Dictionary, container_index: int, slot: int) -> bool:
	var container := container_at(container_index)
	if container.is_empty() or slot<0:
		return false
	var visible := visible_items(container)
	if slot>=visible.size():
		return false
	var want: Dictionary=visible[slot]
	var kind := str(want.kind)
	var count := int(want.get("count",1)) if Catalog.stacks(kind) else 1
	var key := str(want.get("quality",""))
	var provision := bool(want.get("provision",false))
	var meta := loot_meta(want)
	var moved := 0
	for i in count:
		if not store_loot(p,kind,provision,key,meta):
			break
		moved+=1
	if moved<=0:
		return false
	remove_units(container,kind,moved)
	emit_effect("loot",p.p)
	return true

func remove_units(container: Dictionary, kind: String, units: int) -> void:
	var list: Array=Catalog.container_items(container)
	for i in list.size():
		if str(list[i].kind)!=kind:
			continue
		var have := int(list[i].get("count",1)) if Catalog.stacks(kind) else 1
		if have>units:
			list[i]["count"]=have-units
		else:
			list.remove_at(i)
		break
	container["searched"]=searched_units(container)-units
	Catalog.tidy(container)

# Chests hold supplies and valuables, and now and then a better backpack or a
# piece of field equipment. Entries are either a kind string or a dictionary
# carrying the fields that make the loot itself.
func chest_loot(bonus_relic: bool = false, backpack_chance: float = 0.3, floor_index: int = 0) -> Array:
	var kinds: Array = ["scrap","crystal","medicine","ammo","charm"]
	var loot: Array = []
	for i in rng.randi_range(2,4):
		loot.append(kinds[rng.randi_range(0,kinds.size()-1)])
	if bonus_relic or rng.randf()<0.2:
		loot.append("relic")
	if rng.randf()<backpack_chance:
		loot.append({"kind":"backpack","key":backpack_drop(floor_index)})
	# Field equipment: weapons are rarer than gear, and both scale with how deep
	# the raid has gone.
	if rng.randf()<0.24:
		loot.append(Catalog.make_equipment("gear",rng.randi_range(0,Catalog.GEAR.size()-1),roll_quality(floor_index)))
	if rng.randf()<0.16:
		loot.append(Catalog.make_equipment("weapon",rng.randi_range(0,Catalog.WEAPONS.size()-1),roll_quality(floor_index)))
	return loot

# The single place that turns a loot-table entry into an item in a container.
func place_entry(container: Dictionary, entry) -> bool:
	var kind := str(entry.kind) if entry is Dictionary else str(entry)
	if not Catalog.ITEMS.has(kind):
		return false
	if not Catalog.place_loot(container,kind):
		return false
	if not entry is Dictionary:
		return true
	var placed: Dictionary=Catalog.container_items(container).back()
	if kind=="backpack":
		var key := str(entry.get("key",Catalog.DEFAULT_BAG_KEY))
		placed["quality"]=key if Catalog.has_tier(key) else Catalog.DEFAULT_BAG_KEY
	elif kind=="weapon":
		placed["weapon"]=clampi(int(entry.get("weapon",0)),0,Catalog.WEAPONS.size()-1)
		placed["tier"]=Catalog.tier_of(int(entry.get("tier",0)))
	elif kind=="gear":
		placed["gear"]=clampi(int(entry.get("gear",0)),0,Catalog.GEAR.size()-1)
		placed["tier"]=Catalog.tier_of(int(entry.get("tier",0)))
	return true

# How good the loot is: the deeper the raid, the less likely a white item is.
func roll_quality(floor_index: int) -> int:
	var start := clampi(floor_index,0,Catalog.BAG_TIERS.size()-1)
	var weights := [0.42,0.27,0.15,0.09,0.05,0.02]
	var total := 0.0
	for i in range(start,Catalog.BAG_TIERS.size()):
		total+=weights[i]
	var roll := rng.randf()*maxf(0.001,total)
	for i in range(start,Catalog.BAG_TIERS.size()):
		roll-=weights[i]
		if roll<=0.0:
			return i
	return start

# Loot tables never hand out a backpack worse than the one already carried.
func backpack_drop(floor_index: int) -> String:
	return Catalog.BAG_TIERS[roll_quality(floor_index)].key

# Quality floor for the loot tables: chests follow whoever opens them, and the
# ruins generate their contents before anyone is standing there.
func loot_floor() -> int:
	for p in players.values():
		return clampi(Catalog.bag_grid(p.backpack).x-3,0,Catalog.BAG_TIERS.size()-1)
	return 0

func enemy_loot(e: Dictionary) -> Dictionary:
	var entry := {"kind":"ammo" if rng.randf()<0.35 else "crystal"}
	if e.type==3:
		# The blood-scented hunter always leaves its pack behind, and often the
		# weapon it was carrying.
		if rng.randf()<0.45:
			entry=Catalog.make_equipment("weapon",rng.randi_range(0,Catalog.WEAPONS.size()-1),roll_quality(loot_floor()+1))
		else:
			entry["kind"]="backpack"
			entry["key"]=Catalog.BAG_TIERS[rng.randi_range(1,Catalog.BAG_TIERS.size()-1)].key
	elif rng.randf()<0.55:
		entry["kind"]="relic"
	elif rng.randf()<0.18:
		entry=Catalog.make_equipment("gear",rng.randi_range(0,Catalog.GEAR.size()-1),roll_quality(loot_floor()))
	return entry


func configure(config: Dictionary) -> void:
	local_config=config
	if authority():
		apply_config(my_id(),config)
	else:
		config_request.rpc_id(1,config)

@rpc("any_peer","call_remote","reliable")
func config_request(config: Dictionary) -> void:
	if authority():
		apply_config(multiplayer.get_remote_sender_id(),config)

func apply_config(id: int, config: Dictionary) -> void:
	if running or not players.has(id):
		return
	players[id]=make_player(id,config)
	players[id].ready=config.get("ready",id==1)
	push_lobby()

func push_lobby() -> void:
	changed.emit()
	if online:
		lobby.rpc(players)

@rpc("authority","call_remote","reliable")
func lobby(value: Dictionary) -> void:
	players=value
	running=false
	changed.emit()

func _peer_left(id: int) -> void:
	if not authority():
		return
	inputs.erase(id)
	pending_ultimates.erase(id)
	if running and players.has(id):
		players[id].connected=false
		if players[id].status in ["active","down"]:
			players[id].status="dead"
		message.emit("一位守夜人断开连接。")
	else:
		players.erase(id)
		push_lobby()

func launch(long_run: bool = false, fixed_seed: int = 0) -> bool:
	if not authority() or players.is_empty():
		return false
	for p in players.values():
		if not p.ready:
			message.emit("等待所有队友准备完毕。")
			return false
	seed_value=fixed_seed if fixed_seed!=0 else randi_range(1,9999999)
	duration=900.0 if long_run else 480.0
	var i := 0
	for id in players:
		var old: Dictionary=players[id]
		players[id]=make_player(id,old)
		players[id].p=Ruins.SPAWN+Vector2(i*42,0)
		players[id].invuln=5.0
		for m in players[id].meds:
			# Bought medkits ride in the backpack, so losing them is a real risk.
			refresh_storage(players[id])
			Catalog.add_item(players[id].backpack,"medicine")
			players[id].backpack.items.back()["provision"]=true
		i+=1
	begin(seed_value,duration,players)
	if online:
		begin.rpc(seed_value,duration,players)
	for site in ruins.sites:
		for j in (4 if site.tier==2 else 2):
			spawn_enemy(site.p+Vector2(-120+j*80,-40),3 if site.tier==2 and j==0 else [0,2,1,0,1,2][site.biome])
	return true

@rpc("authority","call_remote","reliable")
func begin(value: int, seconds: float, roster: Dictionary) -> void:
	seed_value=value
	duration=seconds
	players=roster
	map_id="border"
	map_states.clear()
	ruins=Ruins.new()
	ruins.generate(value)
	rng.seed=value+71
	enemies.clear()
	bullets.clear()
	world_drops.clear()
	results.clear()
	inputs.clear()
	request_cooldowns.clear()
	pending_ultimates.clear()
	objectives=0
	elapsed=0.0
	threat=0.0
	spawn_timer=8.0
	next_enemy=0
	report_paid=false
	running=true
	started.emit()

func _physics_process(delta: float) -> void:
	if not running:
		return
	input_timer-=delta
	if input_timer<=0:
		input_timer=1.0/30.0
		if authority():
			inputs[my_id()]=local_input.duplicate()
		else:
			input_packet.rpc_id(1,local_input)
	if not authority():
		return
	simulate(delta)
	sync_timer-=delta
	if online and sync_timer<=0:
		sync_timer=0.08
		var packet := var_to_bytes([players,enemies,bullets,world_drops,ruins.chests,ruins.shrines,elapsed,objectives,threat,results,map_id])
		snapshot.rpc(packet.compress(FileAccess.COMPRESSION_GZIP))

@rpc("any_peer","call_remote","unreliable_ordered",1)
func input_packet(packet: Dictionary) -> void:
	if not authority() or not running:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id) or not packet.get("move") is Vector2 or not packet.get("aim") is Vector2:
		return
	if not packet.move.is_finite() or not packet.aim.is_finite():
		return
	inputs[id]={"move":packet.move.limit_length(1),"aim":packet.aim.normalized(),"fire":bool(packet.get("fire",false)),"interact":bool(packet.get("interact",false)),"sprint":bool(packet.get("sprint",false))}

@rpc("authority","call_remote","reliable",2)
func snapshot(packet: PackedByteArray) -> void:
	if not running:
		return
	var data = bytes_to_var(packet.decompress_dynamic(2097152,FileAccess.COMPRESSION_GZIP))
	if not data is Array or data.size()!=11:
		return
	if map_id!=str(data[10]):
		map_id=str(data[10])
		ruins=RoyalCity.new() if map_id=="city" else Ruins.new()
		ruins.generate(seed_value)
		map_changed.emit()
	players=data[0]
	enemies=data[1]
	bullets=data[2]
	world_drops=data[3]
	ruins.chests=data[4]
	ruins.shrines=data[5]
	elapsed=data[6]
	objectives=data[7]
	threat=data[8]
	# Results only arrive with the authoritative settlement packet; a late snapshot
	# must never wipe a finished run's report.
	if results.is_empty():
		results=data[9]

func action(kind: String, payload: Dictionary = {}) -> void:
	if authority():
		perform(my_id(),kind,payload)
	else:
		action_request.rpc_id(1,kind,payload)

@rpc("any_peer","call_remote","reliable")
func action_request(kind: String, payload: Dictionary) -> void:
	if authority():
		perform(multiplayer.get_remote_sender_id(),kind,payload)

func perform(id: int, kind: String, payload: Dictionary = {}) -> void:
	if not running or not players.has(id):
		return
	var p: Dictionary=players[id]
	if pending_ultimates.has(id):
		return
	if p.status not in ["active","down"]:
		return
	if kind=="heal":
		if p.status=="down" and not p.self_revive:
			return
		if p.hp<p.max_hp and spend(p,"medicine"):
			apply_medkit(p)
			broadcast_audio("heal",p)
		return
	if p.status!="active":
		return
	if p.dodge_time>0 and kind in ["skill","reload"]:
		return
	match kind:
		"reload": reload_player(p)
		"dash":
			if p.dash<=0:
				var direction: Vector2=inputs.get(id,{}).get("move",p.aim)
				if direction.length()<0.1:
					direction=p.aim
				if direction.length()<0.1:
					direction=Vector2.RIGHT
				p.dodge_dir=direction.normalized()
				p.dodge_time=DODGE_DURATION
				p.motion="dodge"
				p.pending_strike=false
				p.swing_time=0.0
				p.cast_time=0.0
				p.channel=0.0
				p.dash=2.0
				p.invuln=maxf(p.invuln,0.4)
				broadcast_combat({"kind":"dodge","p":p.p,"aim":p.dodge_dir,"id":id})
				emit_effect("dash",p.p)
		"burn":
			if spend(p,"crystal"):
				p.scent=maxf(0,p.scent-25)
				p.sanity=minf(100,p.sanity+18)
				emit_effect("skill",p.p)
				broadcast_audio("burn",p)
		"skill":
			if p.skill<=0:
				p.skill=18.0
				p.pending_strike=false
				p.swing_time=0.0
				p.reload=0.0
				p.channel=0.0
				var seconds := ONLINE_ULTIMATE_DURATION
				if not online:
					var timing: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voices/voice-manifest.json")).heroes[p.hero]
					seconds=float(timing.charge_time)+float(timing.burst_time)
				p.cast_time=seconds
				pending_ultimates[id]={"remaining":seconds,"aim":p.aim}
				broadcast_combat({"kind":"ultimate-start","p":p.p,"aim":p.aim,"hero":p.hero,"weapon":Catalog.weapon_family(p.weapon),"id":p.id})
		"bag_move":
			var index := int(payload.get("index",-1))
			var slot := str(payload.get("slot","backpack"))
			var container: Dictionary=p.get(slot,p.backpack)
			var list: Array=container.items
			if index>=0 and index<list.size():
				var item: Dictionary=list[index].duplicate()
				item.rot=bool(payload.get("rot",false))
				var at := Vector2i(int(payload.get("x",0)),int(payload.get("y",0)))
				if Catalog.can_place(list,item,at,index,Catalog.container_grid(container)):
					item.x=at.x
					item.y=at.y
					list[index]=item
		"bag_rotate":
			rotate_item(p,str(payload.get("slot","backpack")),int(payload.get("index",-1)))
		"use":
			use_item(p,str(payload.get("slot","backpack")),int(payload.get("index",-1)))
		"equip":
			equip_item(p,str(payload.get("slot","backpack")),int(payload.get("index",-1)))
		"unequip":
			unequip_item(p,str(payload.get("type","weapon")),int(payload.get("index",0)))
		"equip_bag":
			equip_bag(p,str(payload.get("slot","backpack")),int(payload.get("index",-1)))
		"bag_swap":
			var selected := int(payload.get("index",-1))
			if selected>=0 and selected<p.bags.size():
				if not Catalog.swap_bags(p,selected):
					message.emit("背包空间不足：先腾空当前背包内的物资。")
		"search":
			begin_search(p,int(payload.get("index",-1)))
		"pickup":
			if not pick_up_ground(p):
				message.emit("背包空间不足，无法拾取。")
		"loot_take":
			take_loot(p,str(payload.get("ref","")).to_int(),int(payload.get("index",-1)))
		"drop":
			drop_item(p,str(payload.get("slot","backpack")),int(payload.get("index",-1)))
		"bag_drop":
			# Any container can hand an item to any other one: this is what the
			# mouse dragging in the inventory screen ultimately calls.
			move_between(p,str(payload.get("from","backpack")),str(payload.get("to","")),int(payload.get("index",-1)),Vector2i(int(payload.get("x",0)),int(payload.get("y",0))),bool(payload.get("rot",false)))
		"move_to":
			# The one-click "put it in the other container" button: it goes through
			# the same mover as a drag, so stacks, quality and equipment fields all
			# travel with the item instead of being rebuilt from the kind alone.
			var from := str(payload.get("from","backpack"))
			var to := "pocket" if from=="backpack" else "backpack"
			var move_index := int(payload.get("index",-1))
			var source: Dictionary=p.get(from,{})
			var source_items: Array=Catalog.container_items(source)
			if move_index<0 or move_index>=source_items.size():
				return
			var keep_rot := bool(source_items[move_index].get("rot",false))
			if not move_between(p,from,to,move_index,Vector2i(0,0),keep_rot):
				message.emit(Catalog.POCKET_NAME+"空间不足。" if to=="pocket" else "背包空间不足。")

# Quality of the backpack a dragged item would become, so a dropped pack keeps it.
func bag_key_of(p: Dictionary, slot: String, index: int) -> String:
	if slot!="backpack" and slot!="pocket":
		return ""
	var list: Array=Catalog.container_items(p[slot])
	if index<0 or index>=list.size() or list[index].kind!="backpack":
		return ""
	return str(list[index].get("quality",Catalog.DEFAULT_BAG_KEY))

# One entry point for every drag: container to container, container to ground.
func move_between(p: Dictionary, from: String, to: String, index: int, spot: Vector2i, rot: bool) -> bool:
	var to_index := to.substr(5).to_int() if to.begins_with("loot:") else -1
	if to=="world":
		return drop_item(p,from,index,bag_key_of(p,from,index))
	if to.begins_with("loot:"):
		var target := container_at(to.substr(5).to_int())
		if target.is_empty() or from=="loot":
			return false
		var source: Dictionary=p.get(from,{})
		var list: Array=source.get("items",[])
		if index<0 or index>=list.size():
			return false
		var kind := str(list[index].kind)
		if int(list[index].get("count",1))>1 and Catalog.stacks(kind):
			# Whole stacks travel together, one unit at a time, so a container that
			# only has room for part of the pile takes exactly that part.
			var units := int(list[index].get("count",1))
			var moved := 0
			for i in units:
				if not Catalog.place_loot(target,kind):
					break
				moved+=1
			if moved<=0:
				return false
			if moved>=units:
				list.remove_at(index)
			else:
				list[index]["count"]=units-moved
			return true
		var probe: Dictionary=list[index].duplicate()
		probe["rot"]=rot
		if not Catalog.can_place(target.items,probe,spot,-1,container_grid(target)):
			# Fall back to the first free cell so a drag anywhere still lands.
			probe["rot"]=false
			var placed := false
			for y in container_grid(target).y:
				for x in container_grid(target).x:
					if Catalog.can_place(target.items,probe,Vector2i(x,y),-1,container_grid(target)):
						spot=Vector2i(x,y)
						placed=true
						break
				if placed:
					break
			if not placed:
				return false
		probe["x"]=spot.x
		probe["y"]=spot.y
		if visible_units(target)<=0:
			target["searched"]=searched_units(target)+1
		list.remove_at(index)
		target.items.append(probe)
		return true
	if to!="backpack" and to!="pocket":
		return false
	# Dragging straight out of a searched container works the same way as pressing
	# the take button, so both paths share one implementation.
	if from=="loot":
		return take_loot(p,search_reference(p),index)
	var source: Dictionary=p.get(from,{})
	var from_list: Array=source.get("items",[])
	if index<0 or index>=from_list.size():
		return false
	var dest: Dictionary=p[to]
	var entry: Dictionary=from_list[index].duplicate()
	entry["rot"]=rot
	var skip := index if from==to else -1
	var dest_grid := Catalog.container_grid(dest)
	var at := resolve_drop(dest.items,dest_grid,entry,spot,skip)
	if at.x<0:
		return false
	entry["x"]=at.x
	entry["y"]=at.y
	if from==to:
		from_list[index]=entry
	else:
		from_list.remove_at(index)
		dest.items.append(entry)
	return true

# Where an item actually lands when dropped at a cell. The cursor is only a
# pointer: the item goes to the cell under it when that fits, otherwise to the
# nearest free cell, and only gives up when nothing is free. The drag preview
# calls this too, so the shown slot is always the slot that gets used.
func resolve_drop(items: Array, grid: Vector2i, entry: Dictionary, at: Vector2i, skip: int = -1) -> Vector2i:
	if Catalog.can_place(items,entry,at,skip,grid):
		return at
	var origin := at
	if at.x>=grid.x:
		origin=Vector2i(grid.x-1,at.y)
	if origin.y>=grid.y:
		origin=Vector2i(origin.x,grid.y-1)
	origin=Vector2i(maxi(0,origin.x),maxi(0,origin.y))
	var best := Vector2i(-1,-1)
	var best_distance := 1.0e12
	for y in grid.y:
		for x in grid.x:
			var cell := Vector2i(x,y)
			if not Catalog.can_place(items,entry,cell,skip,grid):
				continue
			var distance := Vector2(cell-origin).length()
			if distance<best_distance:
				best_distance=distance
				best=cell
	return best

# --- using and equipping what is in the backpack ----------------------------
# Rotating keeps the item where it is when the turned footprint still fits, and
# otherwise slides it to the nearest legal cell, exactly like a drop would. It
# only refuses when the container has no room for the turned shape at all.
func rotate_item(p: Dictionary, slot: String, index: int) -> bool:
	if slot!="backpack" and slot!="pocket":
		return false
	var list: Array=Catalog.container_items(p[slot])
	if index<0 or index>=list.size():
		return false
	var item: Dictionary=list[index]
	if not move_between(p,slot,slot,index,Vector2i(int(item.x),int(item.y)),not bool(item.get("rot",false))):
		message.emit("空间不足，无法旋转这件物品。")
		return false
	return true

func apply_medkit(p: Dictionary) -> bool:
	if p.status=="down":
		if not p.self_revive:
			return false
		p.self_revive=false
		p.status="active"
		p.invuln=3.0
	p.hp=minf(p.max_hp,p.hp+45)
	p.sanity=minf(100,p.sanity+10)
	emit_effect("skill",p.p)
	return true

# One entry point for using a selected inventory item. The medkit and the blood
# crystal run the same effects as the F and B hotkeys; a backpack, weapon or gear
# piece goes to its own equip path. Consuming removes exactly the clicked entry,
# so a stack of supplies never eats the wrong slot.
func use_item(p: Dictionary, slot: String, index: int) -> bool:
	if slot!="backpack" and slot!="pocket":
		return false
	var list: Array=Catalog.container_items(p[slot])
	if index<0 or index>=list.size():
		return false
	var kind := str(list[index].kind)
	if kind=="backpack":
		return equip_bag(p,slot,index)
	if Catalog.is_equipment(kind):
		return equip_item(p,slot,index)
	if kind=="medicine":
		if p.status=="down" and not p.self_revive:
			message.emit("本局的自救机会已经用过了。")
			return false
		if p.hp>=p.max_hp:
			message.emit("生命已满，急救针留着。")
			return false
		list.remove_at(index)
		apply_medkit(p)
		return true
	if kind=="crystal":
		list.remove_at(index)
		p.scent=maxf(0,p.scent-25)
		p.sanity=minf(100,p.sanity+18)
		emit_effect("skill",p.p)
		return true
	if kind=="ammo":
		list.remove_at(index)
		p.reserve+=48
		emit_effect("loot",p.p)
		return true
	message.emit(Catalog.item_name(list[index])+"无法直接使用。")
	return false

# Equipping is the point of the field equipment: the weapon in hand changes at
# once and gear lands in its own slot. Whatever was worn before goes back into
# storage (or onto the ground when everything is full), so a swap never destroys
# an item.
func equip_item(p: Dictionary, slot: String, index: int) -> bool:
	if slot!="backpack" and slot!="pocket":
		return false
	var list: Array=Catalog.container_items(p[slot])
	if index<0 or index>=list.size():
		return false
	var kind := str(list[index].kind)
	if not Catalog.is_equipment(kind):
		message.emit(Catalog.item_name(list[index])+"不能装备。")
		return false
	var entry: Dictionary=list[index].duplicate()
	for field in ["x","y","rot","count"]:
		entry.erase(field)
	var equipped: Dictionary=p.get("equipped",empty_equipment())
	if not equipped is Dictionary:
		equipped=empty_equipment()
	var old: Dictionary={}
	if kind=="weapon":
		var previous = equipped.get("weapon",{})
		if previous is Dictionary:
			old=previous
		equipped["weapon"]=entry
		p["weapon"]=clampi(int(entry.get("weapon",p.weapon)),0,Catalog.WEAPONS.size()-1)
		p["reload"]=0.0
		p["combo"]=0
		p["pending_strike"]=false
	else:
		equipped["gear"]=gear_slots(equipped)
		var slots: Array=equipped["gear"]
		var gear_index: int=Catalog.gear_slot(entry)
		var previous = slots[gear_index]
		if previous is Dictionary:
			old=previous
		slots[gear_index]=entry
	p["equipped"]=equipped
	list.remove_at(index)
	if not old.is_empty():
		stow_equipment(p,old)
	refresh_max_hp(p)
	if kind=="weapon":
		# Equipping is the one moment a field weapon changes hands, so it is also
		# the cue that replaced the old free weapon switch.
		broadcast_audio("equip",p)
		message.emit("已装备 %s：伤害 +%d%%、攻速 +%d%%。临时武器收起了。" % [Catalog.item_name(entry),int(round(Catalog.weapon_bonus(entry)*100.0)),int(round(Catalog.weapon_rate_bonus(entry)*100.0))])
	else:
		message.emit("已装备 %s（%s槽）：%s。" % [Catalog.item_name(entry),Catalog.gear_slot_name(entry),Catalog.gear_desc(entry)])
	return true

func unequip_item(p: Dictionary, type: String, index: int = 0) -> bool:
	var equipped: Dictionary=p.get("equipped",empty_equipment())
	if not equipped is Dictionary:
		return false
	var entry: Dictionary={}
	var dropped_weapon := false
	if type=="weapon":
		var worn = equipped.get("weapon",{})
		if not worn is Dictionary or worn.is_empty():
			return false
		entry=worn
		equipped["weapon"]={}
		# Taking the looted weapon off puts the temporary issue weapon back in
		# hand; a Watcher never ends up empty handed.
		restore_issue_weapon(p)
		dropped_weapon=true
	else:
		equipped["gear"]=gear_slots(equipped)
		var slots: Array=equipped["gear"]
		var gear_index: int=clampi(index,0,Catalog.GEAR.size()-1)
		var worn = slots[gear_index]
		if not worn is Dictionary or worn.is_empty():
			return false
		entry=worn
		slots[gear_index]={}
	p["equipped"]=equipped
	stow_equipment(p,entry)
	refresh_max_hp(p)
	var tail := "，换回 %s。" % Catalog.weapon_name(p.weapon) if dropped_weapon else "。"
	message.emit("已卸下 "+Catalog.item_name(entry)+tail)
	return true

# Three ordered gear slots, rebuilt defensively because the whole player
# dictionary travels through ENet snapshots.
func gear_slots(equipped: Dictionary) -> Array:
	var slots = equipped.get("gear",[])
	if not slots is Array:
		slots=[]
	while slots.size()<Catalog.GEAR.size():
		slots.append({})
	return slots

# Returns a piece of equipment to the player's own storage; when both containers
# are full it lands on the ground instead of vanishing.
func stow_equipment(p: Dictionary, item: Dictionary, prefer: String = "backpack") -> bool:
	var order: Array = ["backpack","pocket"] if prefer!="pocket" else ["pocket","backpack"]
	for slot in order:
		var container: Dictionary=p[slot]
		if not Catalog.can_hold(container,str(item.kind)):
			continue
		if not Catalog.add_item(container,str(item.kind)):
			continue
		var placed: Dictionary=container.items.back()
		for field in Catalog.SAVED_ITEM_KEYS:
			if item.has(field):
				placed[field]=item[field]
		return true
	var bag := loot_container(p.p+Vector2(28,18),Catalog.chest_grid(0))
	var copy: Dictionary=item.duplicate()
	copy["x"]=0
	copy["y"]=0
	copy["rot"]=false
	bag.items.append(copy)
	bag["searched"]=container_units(bag)
	world_drops.append(bag)
	return false

# A loose backpack found in the field is worn on the spot: the pack it replaces
# becomes a spare, and the swap is refused (never forced) when the carried loot
# would not fit inside the new one.
func equip_bag(p: Dictionary, slot: String, index: int) -> bool:
	if slot!="backpack" and slot!="pocket":
		return false
	var list: Array=Catalog.container_items(p[slot])
	if index<0 or index>=list.size() or str(list[index].kind)!="backpack":
		return false
	var entry: Dictionary=list[index].duplicate()
	var key := str(entry.get("quality",Catalog.DEFAULT_BAG_KEY))
	list.remove_at(index)
	var candidate := Catalog.make_bag(key)
	candidate["gw"]=Catalog.bag_grid(candidate).x
	candidate["gh"]=Catalog.bag_grid(candidate).y
	p.bags.append(candidate)
	if not Catalog.swap_bags(p,p.bags.size()-1):
		p.bags.remove_at(p.bags.size()-1)
		if Catalog.can_hold(p[slot],"backpack"):
			Catalog.add_item(p[slot],"backpack")
			p[slot].items.back()["quality"]=Catalog.tier(key).key
		else:
			stow_equipment(p,entry,slot)
		message.emit("背包空间不足：先腾空当前背包内的物资。")
		return false
	var tier: Dictionary=Catalog.tier(key)
	message.emit("已装备 %s%s。" % [tier.quality,tier.name])
	return true

func cancel_ultimate(id: int) -> void:
	pending_ultimates.erase(id)
	if players.has(id):
		players[id].cast_time=0.0

func release_ultimate(id: int) -> void:
	# Only the host settles damage; clients cannot shorten the online windup.
	if not authority() or not pending_ultimates.has(id):
		return
	var cast: Dictionary=pending_ultimates[id]
	pending_ultimates.erase(id)
	if not running or not players.has(id):
		return
	var p: Dictionary=players[id]
	if p.status!="active" or not p.connected:
		return
	p.cast_time=0.75
	var aim: Vector2=cast.aim
	broadcast_combat({"kind":"skill","p":p.p,"aim":aim,"hero":p.hero,"weapon":Catalog.weapon_family(p.weapon),"id":p.id})
	emit_effect("skill",p.p)
	if p.hero==1:
		for ally in players.values():
			if ally.status=="active" and ally.p.distance_to(p.p)<300:
				ally.hp=minf(ally.max_hp,ally.hp+45)
				ally.sanity=minf(100,ally.sanity+15)
	else:
		p.invuln=maxf(p.invuln,1.0)
		for e in enemies:
			var offset: Vector2=e.p-p.p
			var reach := 210 if p.hero==2 else 460
			if offset.length()<reach and ruins.clear_line(p.p,e.p) and (p.hero==2 or offset.normalized().dot(aim)>0.35):
				damage_enemy(e,115.0,p.id,offset.normalized(),40.0,4)

func reload_player(p: Dictionary) -> void:
	var clip: int=16
	# Only the rifle family consumes ammunition; the issue weapons never do, so
	# R on a sword, greatsword or staff is simply ignored.
	if Catalog.weapon_family(p.weapon)!=0:
		return
	if clip==0 or p.reload>0 or p.ammo>=clip:
		return
	if p.reserve<=0 and spend(p,"ammo"):
		p.reserve+=48
	if p.reserve>0:
		p.reload=1.3
		broadcast_audio("reload",p)

func simulate(dt: float) -> void:
	elapsed+=dt
	threat=elapsed/duration
	spawn_timer-=dt
	if map_id=="border" and spawn_timer<=0 and enemies.size()<65:
		spawn_timer=maxf(2.0,9.0-threat*6.0)
		for i in players.size():
			spawn_enemy()
	for id in players:
		var p: Dictionary=players[id]
		for key in ["attack","skill","dash","invuln","combo_timeout","cast_time"]:
			p[key]=maxf(0,p[key]-dt)
		if p.status=="down":
			p.bleed-=dt
			if p.bleed<=0:
				p.status="dead"
			continue
		if p.status!="active":
			continue
		if pending_ultimates.has(id):
			pending_ultimates[id].remaining-=dt
			if pending_ultimates[id].remaining<=0:
				release_ultimate(id)
		if p.hitstop>0:
			p.hitstop=maxf(0,p.hitstop-dt)
		else:
			p.swing_time=maxf(0,p.swing_time-dt)
			if p.pending_strike and p.swing_total-p.swing_time>=Catalog.weapon(p.weapon).windup:
				p.pending_strike=false
				release_strike(p)
		if p.reload>0:
			p.reload-=dt
			if p.reload<=0:
				var count: int=mini(16-p.ammo,p.reserve)
				p.ammo+=count
				p.reserve-=count
				broadcast_audio("reload-end",p)
		var cmd: Dictionary=inputs.get(id,{})
		var direction: Vector2=cmd.get("move",Vector2.ZERO)
		if pending_ultimates.has(id):
			direction=Vector2.ZERO
		else:
			p.aim=cmd.get("aim",Vector2.RIGHT)
		var speed: float=Catalog.HEROES[p.hero].speed+p.talents[2]*9+Catalog.GEAR[p.gear].speed+equipment_speed(p)
		move_player(p,direction,bool(cmd.get("sprint",false)),dt,speed)
		p.scent=move_toward(p.scent,float(crystals_carried(p)*8),dt*0.5)
		p.sanity=maxf(0,p.sanity-dt*(0.035+threat*0.055+p.scent*0.002))
		if map_id=="border" and p.p.distance_to(Ruins.CENTER)>safe_radius():
			p.hp-=dt*(4+threat*5)
			p.sanity=maxf(0,p.sanity-dt*1.4)
		if p.sanity<=0:
			p.hp-=dt*3
		if map_id=="border" and p.scent>38 and rng.randf()<dt*0.04 and enemies.size()<70:
			spawn_enemy(p.p+Vector2(300,0),3)
			p.scent-=10
		if bool(cmd.get("fire",false)):
			attack(p)
		interact(p,bool(cmd.get("interact",false)) and p.dodge_time<=0 and not pending_ultimates.has(id),dt)
		advance_search(p,dt)
		if p.hp<=0:
			down(p)
	update_enemies(dt)
	update_bullets(dt)
	for i in range(enemies.size()-1,-1,-1):
		var e: Dictionary=enemies[i]
		if e.hp<=0:
			if players.has(e.last):
				players[e.last].kills+=1
			if e.type==4:
				knight_reward(e.p)
			elif rng.randf()<0.42 or e.type==3:
				var loot := enemy_loot(e)
				world_drops.append(ground_drop(e.p,str(loot.kind),str(loot.get("key","")),false,loot_meta(loot)))
			emit_effect("hit",e.p)
			broadcast_combat({"kind":"enemy_defeated","p":e.p,"type":e.type,"facing":e.get("facing",1.0)})
			enemies.remove_at(i)
	if elapsed>=duration:
		for p in players.values():
			if p.status in ["active","down"]:
				p.status="dead"
	var alive := false
	for p in players.values():
		if p.status in ["active","down"]:
			alive=true
	if not alive:
		settle()

func safe_radius() -> float:
	if map_id=="city": return 10000.0
	return lerpf(Ruins.SIZE.length()/2+100,650,clampf((elapsed/duration-0.45)/0.55,0,1))

func move_player(p: Dictionary, direction: Vector2, sprint: bool, dt: float, speed: float) -> void:
	var before: Vector2=p.p
	if p.dodge_time>0:
		var step := minf(dt,p.dodge_time)
		p.p=ruins.move(p.p,p.dodge_dir*(DODGE_DISTANCE/DODGE_DURATION)*step)
		p.dodge_time=maxf(0,p.dodge_time-dt)
		p.move_dir=p.dodge_dir
		p.motion="dodge" if p.dodge_time>0 else "idle"
	else:
		var active_attack: bool=p.swing_time>0 or p.cast_time>0
		var running_now := sprint and not active_attack and direction.length()>0.1
		var multiplier := RUN_MULTIPLIER if running_now else 1.0
		if p.swing_time>0 and Catalog.weapon_family(p.weapon)==2:
			multiplier*=0.48
		p.p=ruins.move(p.p,direction.limit_length(1)*speed*dt*multiplier)
		if direction.length()>0.1:
			p.move_dir=direction.normalized()
		p.motion="run" if running_now else "walk"
		if before.distance_to(p.p)<0.01:
			p.motion="idle"
	p.move_speed=before.distance_to(p.p)/maxf(dt,0.001)

func down(p: Dictionary) -> void:
	cancel_ultimate(p.id)
	p.hp=0
	p.status="down"
	p.bleed=35
	p.pending_strike=false
	p.swing_time=0.0
	p.dodge_time=0.0
	p.motion="idle"
	p.channel=0
	# Going down scatters the droppable storage only; the pocket stays sealed.
	spill_storage(p)
	emit_effect("hurt",p.p)
	broadcast_audio("down",p)

func attack(p: Dictionary) -> void:
	if p.attack>0 or p.reload>0 or p.swing_time>0 or p.cast_time>0 or p.dodge_time>0 or p.status!="active":
		return
	var family := Catalog.weapon_family(p.weapon)
	var weapon: Dictionary=Catalog.weapon(p.weapon)
	if family==0 and p.ammo<=0:
		reload_player(p)
		return
	p.combo=(int(p.combo)+1)%3 if p.combo_timeout>0 else 0
	p.combo_timeout=1.2
	# A looted weapon of matching quality swings faster than the issue weapon.
	var rate: float=weapon.rate*equipment_rate(p)
	p.attack=rate
	p.swing_total=rate
	p.swing_time=rate
	p.strike_aim=p.aim.normalized()
	p.pending_strike=true
	# Every consumer of a combat event wants the four-way art/effect family, not
	# the index of the exact weapon; a hero issue weapon borrows its family's.
	broadcast_combat({"kind":"windup","p":p.p,"aim":p.strike_aim,"weapon":family,"id":p.id,"combo":p.combo})
	if weapon.windup==0:
		p.pending_strike=false
		release_strike(p)

func release_strike(p: Dictionary) -> void:
	var family := Catalog.weapon_family(p.weapon)
	var w: Dictionary=Catalog.weapon(p.weapon)
	var direction: Vector2=p.strike_aim
	var damage: float=w.damage*(1+p.talents[1]*0.08+mini(3,charms_carried(p))*0.12+Catalog.GEAR[p.gear].damage+equipment_damage(p))
	if family==1 and p.combo==2:
		damage*=1.4
	broadcast_combat({"kind":"strike","p":p.p,"aim":direction,"weapon":family,"id":p.id,"combo":p.combo})
	if family in [1,2]:
		for e in enemies:
			var v: Vector2=e.p-p.p
			if e.hp>0 and v.length()<w.reach and v.normalized().dot(direction)>-0.1 and ruins.clear_line(p.p,e.p):
				damage_enemy(e,damage,p.id,direction,w.knock,family)
	else:
		if family==0:
			p.ammo-=1
			emit_effect("shot",p.p)
		bullets.append({"p":p.p+direction*23,"v":direction*(850 if family==0 else 620),"life":1.1,"damage":damage,"owner":p.id,"weapon":family})

func damage_enemy(e: Dictionary, damage: float, owner: int, direction: Vector2, knock: float, weapon: int = -1) -> void:
	e.hp-=damage
	e.last=owner
	e["flash"]=0.14
	if e.type==4:
		e["poise"]=float(e.get("poise",0))+damage
		if e.poise>=220:
			e.poise=0.0
			e["attack_time"]=0.0
			e["stagger"]=1.1
			e.cd=1.5
		knock*=0.12
	else:
		e["attack_time"]=0.0
		e["stagger"]=0.12 if knock<40 else 0.26
	var impact: Vector2=e.p
	e.p=ruins.move(e.p,direction*knock)
	if players.has(owner):
		players[owner].hitstop=0.045 if knock<40 else 0.085
	broadcast_combat({"kind":"impact","p":impact,"aim":direction,"damage":damage,"heavy":knock>=40,"id":owner,"weapon":weapon,"enemy_type":e.type})

func broadcast_audio(cue: String, p: Dictionary, variant: int = -1) -> void:
	broadcast_combat({"kind":"audio","cue":cue,"p":p.p,"id":p.get("id",0),"variant":variant})

func broadcast_combat(data: Dictionary) -> void:
	combat_event.emit(data)
	if online:
		remote_combat.rpc(data)

@rpc("authority","call_remote","reliable")
func remote_combat(data: Dictionary) -> void:
	combat_event.emit(data)

func interact(p: Dictionary, held: bool, dt: float) -> void:
	if not held:
		p.channel=0
		p.target=""
		return
	var target := ""
	var seconds := 0.25
	if p.p.distance_to(portal_position())<85 and party_at_gate():
		target="portal:0"
		seconds=1.5
	for other in players.values():
		if other.id!=p.id and other.status=="down" and p.p.distance_to(other.p)<75:
			target="revive:%d" % other.id
			seconds=3.0
			break
	if target.is_empty():
		for i in ruins.exits.size():
			if p.p.distance_to(ruins.exits[i])<83:
				target="exit:%d" % i
				seconds=4.0
				break
	if target.is_empty():
		for i in ruins.shrines.size():
			if not ruins.shrines[i].done and p.p.distance_to(ruins.shrines[i].p)<72:
				target="shrine:%d" % i
				seconds=3.0
				break
	if target.is_empty():
		p.channel=0
		p.target=""
		return
	if p.target!=target:
		p.channel=0
		p.target=target
	p.channel+=dt
	if p.channel<seconds:
		return
	p.channel=0
	var parts := target.split(":")
	var index := int(parts[1])
	match parts[0]:
		"portal":
			travel_city()
		"exit":
			p.status="extracted"
			emit_effect("bell",p.p)
		"revive":
			players[index].status="active"
			players[index].hp=players[index].max_hp*0.4
			players[index].invuln=2
			emit_effect("skill",p.p)
			broadcast_audio("heal",p)
		"shrine":
			ruins.shrines[index].done=true
			objectives+=1
			p.sanity=minf(100,p.sanity+20)
			emit_effect("bell",p.p)
			spawn_enemy(ruins.shrines[index].p+Vector2(0,240),3)

# A loot container is a grid plus a search counter: items become visible one at
# a time while somebody searches it.
func loot_container(at: Vector2, grid: Vector2i, class_index: int = 1, bonus: bool = false) -> Dictionary:
	return {"p":at,"key":"container","items":[],"grid":grid,"searched":0,"open":false,"class":class_index,"bonus":bonus,"next":1}

func container_units(container: Dictionary) -> int:
	var total := 0
	for item in Catalog.container_items(container):
		total+=int(item.get("count",1)) if Catalog.stacks(str(item.kind)) else 1
	return total

func container_grid(container: Dictionary) -> Vector2i:
	var grid = container.get("grid",null)
	if grid is Vector2i:
		return grid
	return Catalog.chest_grid(int(container.get("class",1)))

func visible_units(container: Dictionary) -> int:
	return mini(int(container.get("searched",0)),container_units(container))

func searched_units(container: Dictionary) -> int:
	return int(container.get("searched",0))

func container_searched(container: Dictionary) -> bool:
	return searched_units(container)>=container_units(container)

# Loot is laid out row-major with stacks, so revealing the first N units is the
# same as revealing the first N cells of the grid.
func visible_items(container: Dictionary) -> Array:
	var out: Array = []
	var budget := visible_units(container)
	for item in Catalog.container_items(container):
		if budget<=0:
			break
		var units := int(item.get("count",1)) if Catalog.stacks(str(item.kind)) else 1
		var shown := mini(units,budget)
		var entry: Dictionary = item.duplicate()
		entry["count"]=shown if Catalog.stacks(str(item.kind)) else 1
		out.append(entry)
		budget-=shown
	return out

func peek_items(container: Dictionary) -> Array:
	return Catalog.container_items(container)

func random_patrol_position() -> Vector2:
	# Reinforcements stay relevant on the larger map and never spawn on players.
	var active: Array=[]
	for p in players.values():
		if p.status=="active": active.append(p)
	if not active.is_empty():
		var p: Dictionary=active[rng.randi_range(0,active.size()-1)]
		return (p.p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(600,1050)).clamp(Vector2(100,100),Ruins.SIZE-Vector2(100,100))
	return ruins.sites[rng.randi_range(0,ruins.sites.size()-1)].p

func spawn_enemy(at: Vector2 = Vector2.ZERO, type: int = -1) -> void:
	var pos := at
	var near := false
	if pos==Vector2.ZERO:
		pos=random_patrol_position()
	for i in 24:
		near=false
		for p in players.values():
			if p.status=="active" and p.p.distance_to(pos)<260:
				near=true
		if not ruins.blocked(pos,25) and not near:
			break
		pos=random_patrol_position()
	if ruins.blocked(pos,25) or near:
		return
	var kind := type if type>=0 else rng.randi_range(0,2)
	var health: float = [58.0,42.0,125.0,310.0,1800.0][kind]*(1+0.3*(players.size()-1))
	enemies.append({"id":next_enemy,"p":pos,"type":kind,"hp":health,"max_hp":health,"cd":0.0,"last":1,"wander":Vector2.from_angle(rng.randf()*TAU),"facing":1.0,"motion_phase":0.0,"moving":false,"attack_time":0.0,"attack_total":0.0,"attack_released":false,"attack_target":0,"attack_aim":Vector2.RIGHT})
	next_enemy+=1

func update_enemies(dt: float) -> void:
	for e in enemies:
		if e.hp<=0:
			continue
		if e.type==4:
			update_knight(e,dt)
			continue
		e["flash"]=maxf(0,float(e.get("flash",0))-dt)
		e["stagger"]=maxf(0,float(e.get("stagger",0))-dt)
		e["moving"]=false
		e.cd=maxf(0,e.cd-dt)
		if e.stagger>0:
			# A stagger interrupts the windup before its contact frame.
			e["attack_time"]=0.0
			continue
		if float(e.get("attack_time",0))>0:
			e.attack_time=maxf(0,e.attack_time-dt)
			var passed: float=e.attack_total-e.attack_time
			var windup: float=[0.26,0.42,0.56,0.32][e.type]
			if not e.attack_released and passed>=windup:
				e.attack_released=true
				var victim: Dictionary=players.get(e.attack_target,{})
				if e.type==1:
					broadcast_audio("enemy-cast",e)
					bullets.append({"p":e.p,"v":e.attack_aim*245,"life":2.0,"damage":13.0,"owner":0})
				elif not victim.is_empty() and victim.status=="active" and e.p.distance_to(victim.p)<58 and ruins.clear_line(e.p,victim.p):
					hurt(victim,[12,8,20,25][e.type])
			continue
		var target: Dictionary={}
		var best := 440.0+threat*300
		for p in players.values():
			if p.status!="active":
				continue
			var dist: float=e.p.distance_to(p.p)
			if dist<best+p.scent*4:
				best=dist
				target=p
		var before: Vector2=e.p
		if target.is_empty():
			e.p=ruins.move(e.p,e.wander*18*dt)
		else:
			var direction: Vector2=(target.p-e.p).normalized()
			if absf(direction.x)>0.05:
				e["facing"]=signf(direction.x)
			var speed: float=[110,95,68,140][e.type]*(1+threat*0.3)
			var ranged: bool=e.type==1 and best<330 and ruins.clear_line(e.p,target.p)
			if e.cd<=0 and (ranged or (best<45 and ruins.clear_line(e.p,target.p))):
				e["attack_total"]=[0.62,0.84,1.0,0.72][e.type]
				e["attack_time"]=e.attack_total
				e["attack_released"]=false
				e["attack_target"]=target.id
				e["attack_aim"]=direction
				e.cd=2.0 if ranged else e.attack_total+0.35
			elif not ranged and best>32:
				e.p=ruins.move(e.p,direction*speed*dt)
				if e.p.distance_to(before)<speed*dt*0.2:
					e.p=ruins.move(e.p,direction.orthogonal()*speed*dt)
		var travelled: float=e.p.distance_to(before)
		e["moving"]=travelled>0.01
		e["motion_phase"]=float(e.get("motion_phase",0))+travelled/12.0
		if travelled>0.01 and absf(e.p.x-before.x)>0.01:
			e["facing"]=signf(e.p.x-before.x)

func hurt(p: Dictionary, damage: float) -> void:
	if p.invuln>0 or p.status!="active":
		return
	p.hp-=damage
	p.invuln=0.3
	p.channel=0
	emit_effect("hurt",p.p)
	if p.hp<=0:
		down(p)
	else:
		broadcast_audio("hurt",p)

func update_bullets(dt: float) -> void:
	for i in range(bullets.size()-1,-1,-1):
		var b: Dictionary=bullets[i]
		var old: Vector2=b.p
		b.p+=b.v*dt
		b.life-=dt
		if not ruins.clear_line(old,b.p):
			b.life=0
		if b.life>0:
			if b.owner==0:
				for p in players.values():
					if p.status=="active" and Geometry2D.get_closest_point_to_segment(p.p,old,b.p).distance_to(p.p)<18:
						hurt(p,b.damage)
						b.life=0
						break
			else:
				for e in enemies:
					if Geometry2D.get_closest_point_to_segment(e.p,old,b.p).distance_to(e.p)<(27 if e.type==3 else 19):
						damage_enemy(e,b.damage,b.owner,b.v.normalized(),16.0,int(b.get("weapon",0)))
						b.life=0
						break
		if b.life<=0:
			bullets.remove_at(i)

func emit_effect(kind: String, pos: Vector2) -> void:
	effect.emit(kind,pos)
	if online:
		remote_effect.rpc(kind,pos)

@rpc("authority","call_remote","unreliable")
func remote_effect(kind: String, pos: Vector2) -> void:
	effect.emit(kind,pos)

func settle() -> void:
	if not running:
		return
	results.clear()
	for id in players:
		var p: Dictionary=players[id]
		var extracted: bool=p.status=="extracted"
		# Extraction banks both containers; death already scattered the backpack
		# in down(), so only the sealed pocket survives it.
		var loot := (Catalog.container_value(p.backpack)+Catalog.container_value(p.pocket)) if extracted else 0
		var shared := objectives*55+(100 if objectives==3 else 0)
		results[id]={"name":p.name,"escaped":extracted,"loot":loot,"shared":shared,"kills":p.kills,"coins":loot+shared,"xp":35+p.kills*8+objectives*25+(60 if extracted else 0),"pocket":Catalog.clean_container(p.pocket,Catalog.POCKET_GRID),"bags":saved_bags(p,extracted),"worn":worn_names(p)}
	running=false
	finished.emit()
	if online:
		receive_results.rpc(results,players)

# What the player was wearing when the run ended, for the report screen: worn
# equipment never travels home, so the report is where it is accounted for.
func worn_names(p: Dictionary) -> Array:
	var names: Array = []
	var weapon := kit_weapon(p)
	if not weapon.is_empty():
		names.append(Catalog.item_name(weapon))
	for entry in kit_gear(p):
		if entry is Dictionary and not entry.is_empty():
			names.append(Catalog.item_name(entry))
	return names

# What the save file keeps after the expedition: the pocket is always preserved,
# the equipped backpack and every spare only when the player walked out alive.
func saved_bags(p: Dictionary, extracted: bool) -> Array:
	var saved: Array = []
	if extracted:
		saved.append(Catalog.clean_container(p.backpack,Catalog.bag_grid(p.backpack)))
		for entry in p.bags:
			if entry is Dictionary:
				saved.append(Catalog.clean_container(entry,Catalog.bag_grid(entry)))
	if saved.is_empty():
		var fallback := Catalog.make_bag(Catalog.DEFAULT_BAG_KEY)
		fallback["gw"]=Catalog.bag_grid(fallback).x
		fallback["gh"]=Catalog.bag_grid(fallback).y
		saved.append(fallback)
	return saved

@rpc("authority","call_remote","reliable")
func receive_results(value: Dictionary, roster: Dictionary) -> void:
	results=value
	players=roster
	running=false
	finished.emit()

func return_to_camp() -> void:
	if not authority():
		return
	for id in players.keys():
		if not players[id].connected:
			players.erase(id)
		else:
			players[id].ready=id==1
	push_lobby()

func portal_position() -> Vector2:
	return RoyalCity.GATE if map_id=="city" else CITY_GATE

func party_at_gate() -> bool:
	for p in players.values():
		if p.status=="down": return false
		if p.status=="active" and p.p.distance_to(portal_position())>240: return false
	return true

func travel_city() -> bool:
	if not authority() or not running or not party_at_gate(): return false
	map_states[map_id]={"ruins":ruins,"enemies":enemies,"drops":world_drops}
	map_id="city" if map_id=="border" else "border"
	var fresh := not map_states.has(map_id)
	if fresh:
		ruins=RoyalCity.new() if map_id=="city" else Ruins.new()
		ruins.generate(seed_value)
		enemies=[]
		world_drops=[]
	else:
		var saved: Dictionary=map_states[map_id]
		ruins=saved.ruins
		enemies=saved.enemies
		world_drops=saved.drops
	bullets.clear()
	pending_ultimates.clear()
	var index := 0
	for p in players.values():
		stop_search(p)
		p.channel=0.0
		p.target=""
		p.pending_strike=false
		p.swing_time=0.0
		p.dodge_time=0.0
		p.cast_time=0.0
		if p.status=="active":
			p.p=portal_position()+Vector2((index-1)*42,-140 if map_id=="city" else 140)
			p.invuln=2.0
			index+=1
	if fresh and map_id=="city":
		spawn_enemy(RoyalCity.BOSS,4)
		for pos in [Vector2(950,1300),Vector2(1850,1300),Vector2(1050,900),Vector2(1750,900)]:
			spawn_enemy(pos,2)
	map_changed.emit()
	return true

func knight_reward(at: Vector2) -> void:
	var chest := loot_container(at,Vector2i(6,6),3,true)
	chest["fixed_loot"]=true
	chest["title"]="失乡骑士的王庭珍藏"
	for i in 6: place_entry(chest,{"kind":"relic"})
	place_entry(chest,Catalog.make_equipment("weapon",2,5))
	for i in 3: place_entry(chest,Catalog.make_equipment("gear",i,4))
	place_entry(chest,{"kind":"backpack","key":"gold"})
	chest["open"]=true
	ruins.chests.append(chest)
	emit_effect("bell",at)

func update_knight(e: Dictionary, dt: float) -> void:
	e["flash"]=maxf(0,float(e.get("flash",0))-dt)
	e["stagger"]=maxf(0,float(e.get("stagger",0))-dt)
	e["moving"]=false
	e.cd=maxf(0,e.cd-dt)
	if e.stagger>0: return
	if e.attack_time>0:
		var before: float=e.attack_total-e.attack_time
		e.attack_time=maxf(0,e.attack_time-dt)
		var passed: float=e.attack_total-e.attack_time
		var move_name: String=e.get("move_name","combo")
		var marks: Array=[0.65,1.10,1.65] if move_name=="combo" else ([0.85] if move_name=="thrust" else [1.15])
		# Locked aim is never retargeted after anticipation begins.
		if move_name=="thrust" and passed>0.85 and before<1.20:
			var step: float=maxf(0,minf(passed,1.20)-maxf(before,0.85))
			e.p=ruins.move(e.p,e.attack_aim*800*step)
			e["moving"]=true
			e.motion_phase+=step*20
			for p in players.values():
				if not e.get("hit_ids",[]).has(p.id) and p.p.distance_to(e.p)<75 and ruins.clear_line(e.p,p.p):
					hurt(p,32)
					e.hit_ids.append(p.id)
		for strike in marks.size():
			if before<marks[strike] and passed>=marks[strike]:
				e["attack_released"]=true
				broadcast_audio("enemy-cast",e)
				for p in players.values():
					var delta: Vector2=p.p-e.p
					var reach := 225.0 if move_name=="storm" else (110.0 if move_name=="thrust" else 155.0)
					var arc := PI if move_name=="storm" else 1.35
					if delta.length()<reach and absf(e.attack_aim.angle_to(delta))<arc and ruins.clear_line(e.p,p.p):
						hurt(p,36 if move_name=="storm" else (32 if move_name=="thrust" else 18+strike*3))
		return
	var target: Dictionary={}
	var best := 780.0
	for p in players.values():
		if p.status=="active" and p.p.distance_to(e.p)<best:
			best=p.p.distance_to(e.p)
			target=p
	if target.is_empty(): return
	var aim: Vector2=(target.p-e.p).normalized()
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	if e.cd<=0 and best<360 and ruins.clear_line(e.p,target.p):
		var sequence := int(e.get("sequence",0))
		var move_name := "storm" if e.hp<=e.max_hp*0.5 and sequence%3==2 else ("thrust" if best>190 or sequence%3==1 else "combo")
		e["sequence"]=sequence+1
		e["move_name"]=move_name
		e["hit_ids"]=[]
		e.attack_aim=aim
		e.attack_total=2.65 if move_name=="combo" else (2.35 if move_name=="thrust" else 2.75)
		e.attack_time=e.attack_total
		e.attack_released=false
		e.cd=e.attack_total+0.65
	elif best>115:
		var previous: Vector2=e.p
		e.p=ruins.move(e.p,aim*115*dt)
		if e.p.distance_to(previous)<1: e.p=ruins.move(e.p,aim.orthogonal()*115*dt)
		e.moving=e.p.distance_to(previous)>0.01
		e.motion_phase+=e.p.distance_to(previous)/12
