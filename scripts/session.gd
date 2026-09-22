class_name TideSession
extends Node

signal changed
signal started
signal finished
signal message(text: String)
signal effect(kind: String, pos: Vector2)
signal combat_event(data: Dictionary)

const PORT := 24872
const DODGE_DURATION := 0.24
const DODGE_DISTANCE := 145.0
const RUN_MULTIPLIER := 1.45
var players: Dictionary = {}
var inputs: Dictionary = {}
var ruins := Ruins.new()
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
	var player := {"id":id,"name":str(config.get("name","守夜人")).left(16),"hero":h,"weapon":clampi(int(config.get("weapon",[1,3,2][h])),0,3),"swing_time":0.0,"swing_total":0.0,"pending_strike":false,"strike_aim":Vector2.RIGHT,"combo":0,"combo_timeout":0.0,"hitstop":0.0,"cast_time":0.0,"gear":gear,"talents":talents,"ready":id==1,"p":Vector2(300,1100),"aim":Vector2.RIGHT,"hp":hp,"max_hp":hp,"sanity":100.0,"status":"active","pocket":storage.pocket,"backpack":storage.backpack,"bags":storage.bags,"ammo":Catalog.HEROES[h].clip,"reserve":96,"attack":0.0,"reload":0.0,"skill":0.0,"dash":0.0,"invuln":0.0,"channel":0.0,"search":0.0,"search_ref":-1,"target":"","bleed":40.0,"kills":0,"scent":0.0,"meds":clampi(int(config.get("meds",1)),1,3),"self_revive":true,"connected":true}
	player.merge({"motion":"idle","move_dir":Vector2.RIGHT,"move_speed":0.0,"dodge_time":0.0,"dodge_dir":Vector2.RIGHT})
	return player

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
func store_loot(p: Dictionary, kind: String, provision: bool = false, key: String = "") -> bool:
	var order: Array = ["pocket","backpack"] if Catalog.prefers_pocket(kind) else ["backpack","pocket"]
	for name in order:
		var container: Dictionary=p[name]
		var fits := Catalog.can_hold(container,kind) if kind=="backpack" else Catalog.add_item(container,kind)
		if not fits:
			continue
		if kind=="backpack":
			# A loose backpack is stored as a 1x1 pack item carrying its quality.
			if not Catalog.add_item(container,"backpack"):
				continue
			container.items.back()["quality"]=key if Catalog.has_tier(key) else Catalog.DEFAULT_BAG_KEY
		container.items.back()["provision"]=provision
		return true
	return false

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
func ground_drop(at: Vector2, kind: String, key: String = "", provision: bool = false) -> Dictionary:
	var container := loot_container(at,Catalog.chest_grid(0))
	container.items.append({"kind":kind,"x":0,"y":0,"rot":false,"count":1})
	if not key.is_empty():
		container.items[0]["quality"]=key
	if provision:
		container.items[0]["provision"]=true
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
# it against death is the whole point of the dimensional pocket.
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
	var replacement := Catalog.make_bag(Catalog.DEFAULT_BAG_KEY)
	replacement["gw"]=Catalog.bag_grid(replacement).x
	replacement["gh"]=Catalog.bag_grid(replacement).y
	p["backpack"]=replacement
	p["bags"]=[]

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
	if container.items.is_empty() and not container_is_bag(container):
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
		if not store_loot(p,str(item.kind),bool(item.get("provision",false)),key):
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
	var moved := 0
	for i in count:
		if not store_loot(p,kind,provision,key):
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

# Chests hold supplies and valuables, and now and then a better backpack.
# Entries are either a kind string or {"kind":"backpack","key":<quality>}.
func chest_loot(bonus_relic: bool = false, backpack_chance: float = 0.3, floor_index: int = 0) -> Array:
	var kinds: Array = ["scrap","crystal","medicine","ammo","charm"]
	var loot: Array = []
	for i in rng.randi_range(2,4):
		loot.append(kinds[rng.randi_range(0,kinds.size()-1)])
	if bonus_relic or rng.randf()<0.2:
		loot.append("relic")
	if rng.randf()<backpack_chance:
		loot.append({"kind":"backpack","key":backpack_drop(floor_index)})
	return loot

# The single place that turns a loot-table entry into an item in a container.
func place_entry(container: Dictionary, entry) -> bool:
	var kind := str(entry.kind) if entry is Dictionary else str(entry)
	if not Catalog.ITEMS.has(kind):
		return false
	if not Catalog.place_loot(container,kind):
		return false
	if kind=="backpack":
		var key := str(entry.get("key",Catalog.DEFAULT_BAG_KEY)) if entry is Dictionary else Catalog.DEFAULT_BAG_KEY
		Catalog.container_items(container).back()["quality"]=key if Catalog.has_tier(key) else Catalog.DEFAULT_BAG_KEY
	return true
# Loot tables never hand out a backpack worse than the one already carried.
func backpack_drop(floor_index: int) -> String:
	var start := clampi(floor_index,0,Catalog.BAG_TIERS.size()-1)
	var weights := [0.42,0.27,0.15,0.09,0.05,0.02]
	var total := 0.0
	for i in range(start,Catalog.BAG_TIERS.size()):
		total+=weights[i]
	var roll := rng.randf()*maxf(0.001,total)
	for i in range(start,Catalog.BAG_TIERS.size()):
		roll-=weights[i]
		if roll<=0.0:
			return Catalog.BAG_TIERS[i].key
	return Catalog.BAG_TIERS[start].key

# Quality floor for the loot tables: chests follow whoever opens them, and the
# ruins generate their contents before anyone is standing there.
func loot_floor() -> int:
	for p in players.values():
		return clampi(Catalog.bag_grid(p.backpack).x-3,0,Catalog.BAG_TIERS.size()-1)
	return 0

func enemy_loot(e: Dictionary) -> Dictionary:
	var entry := {"kind":"ammo" if rng.randf()<0.35 else "crystal"}
	if e.type==3:
		# The blood-scented hunter always leaves its pack behind.
		entry["kind"]="backpack"
		entry["key"]=Catalog.BAG_TIERS[rng.randi_range(1,Catalog.BAG_TIERS.size()-1)].key
	elif rng.randf()<0.55:
		entry["kind"]="relic"
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
		players[id].p=Vector2(280+i*42,1100)
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
	for j in 20:
		spawn_enemy()
	return true

@rpc("authority","call_remote","reliable")
func begin(value: int, seconds: float, roster: Dictionary) -> void:
	seed_value=value
	duration=seconds
	players=roster
	ruins.generate(value)
	rng.seed=value+71
	enemies.clear()
	bullets.clear()
	world_drops.clear()
	results.clear()
	inputs.clear()
	request_cooldowns.clear()
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
		var packet := var_to_bytes([players,enemies,bullets,world_drops,ruins.chests,ruins.shrines,elapsed,objectives,threat,results])
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
	if not data is Array or data.size()!=10:
		return
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
	if p.status not in ["active","down"]:
		return
	if kind=="heal":
		if p.status=="down" and not p.self_revive:
			return
		if p.hp<p.max_hp and spend(p,"medicine"):
			if p.status=="down":
				p.self_revive=false
				p.status="active"
				p.invuln=3.0
			p.hp=minf(p.max_hp,p.hp+45)
			p.sanity=minf(100,p.sanity+10)
			emit_effect("skill",p.p)
		return
	if p.status!="active":
		return
	if p.dodge_time>0 and kind in ["weapon","skill","reload"]:
		return
	match kind:
		"weapon":
			var selected := int(payload.get("index",-1))
			if selected>=0 and selected<Catalog.WEAPONS.size() and p.attack<=0 and p.swing_time<=0 and p.cast_time<=0:
				p.weapon=selected
				p.reload=0.0
				p.combo=0
				changed.emit()
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
		"skill":
			if p.skill<=0:
				p.skill=18.0
				p.pending_strike=false
				p.swing_time=0.0
				p.cast_time=0.75
				broadcast_combat({"kind":"skill","p":p.p,"aim":p.aim,"hero":p.hero,"weapon":p.weapon,"id":p.id})
				emit_effect("skill",p.p)
				if p.hero==1:
					for ally in players.values():
						if ally.status=="active" and ally.p.distance_to(p.p)<300:
							ally.hp=minf(ally.max_hp,ally.hp+45)
							ally.sanity=minf(100,ally.sanity+15)
				else:
					p.invuln=1.0
					for e in enemies:
						var offset: Vector2=e.p-p.p
						var reach := 210 if p.hero==2 else 460
						if offset.length()<reach and ruins.clear_line(p.p,e.p) and (p.hero==2 or offset.normalized().dot(p.aim)>0.35):
							damage_enemy(e,115.0,p.id,offset.normalized(),40.0)
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
			var from := str(payload.get("from","backpack"))
			var to := "pocket" if from=="backpack" else "backpack"
			var source: Dictionary=p[from]
			var move_index := int(payload.get("index",-1))
			if move_index>=0 and move_index<source.items.size():
				var moved_kind := str(source.items[move_index].kind)
				if Catalog.can_hold(p[to],moved_kind):
					source.items.remove_at(move_index)
					Catalog.add_item(p[to],moved_kind)
				else:
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
			# Whole stacks travel together when there is room for them.
			if not Catalog.can_hold(target,kind):
				return false
			Catalog.place_loot(target,kind)
			list.remove_at(index)
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

func reload_player(p: Dictionary) -> void:
	var clip: int=16
	if p.weapon!=0:
		return
	if clip==0 or p.reload>0 or p.ammo>=clip:
		return
	if p.reserve<=0 and spend(p,"ammo"):
		p.reserve+=48
	if p.reserve>0:
		p.reload=1.3

func simulate(dt: float) -> void:
	elapsed+=dt
	threat=elapsed/duration
	spawn_timer-=dt
	if spawn_timer<=0 and enemies.size()<65:
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
		if p.hitstop>0:
			p.hitstop=maxf(0,p.hitstop-dt)
		else:
			p.swing_time=maxf(0,p.swing_time-dt)
			if p.pending_strike and p.swing_total-p.swing_time>=Catalog.WEAPONS[p.weapon].windup:
				p.pending_strike=false
				release_strike(p)
		if p.reload>0:
			p.reload-=dt
			if p.reload<=0:
				var count: int=mini(16-p.ammo,p.reserve)
				p.ammo+=count
				p.reserve-=count
		var cmd: Dictionary=inputs.get(id,{})
		var direction: Vector2=cmd.get("move",Vector2.ZERO)
		p.aim=cmd.get("aim",Vector2.RIGHT)
		var speed: float=Catalog.HEROES[p.hero].speed+p.talents[2]*9+Catalog.GEAR[p.gear].speed
		move_player(p,direction,bool(cmd.get("sprint",false)),dt,speed)
		p.scent=move_toward(p.scent,float(crystals_carried(p)*8),dt*0.5)
		p.sanity=maxf(0,p.sanity-dt*(0.035+threat*0.055+p.scent*0.002))
		if p.p.distance_to(Ruins.CENTER)>safe_radius():
			p.hp-=dt*(4+threat*5)
			p.sanity=maxf(0,p.sanity-dt*1.4)
		if p.sanity<=0:
			p.hp-=dt*3
		if p.scent>38 and rng.randf()<dt*0.04 and enemies.size()<70:
			spawn_enemy(p.p+Vector2(300,0),3)
			p.scent-=10
		if bool(cmd.get("fire",false)):
			attack(p)
		interact(p,bool(cmd.get("interact",false)) and p.dodge_time<=0,dt)
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
			if rng.randf()<0.42 or e.type==3:
				var loot := enemy_loot(e)
				world_drops.append(ground_drop(e.p,str(loot.kind),str(loot.get("key","")),false))
			emit_effect("hit",e.p)
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
	return lerpf(1800,290,clampf((elapsed/duration-0.45)/0.55,0,1))

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
		if p.swing_time>0 and p.weapon==2:
			multiplier*=0.48
		p.p=ruins.move(p.p,direction.limit_length(1)*speed*dt*multiplier)
		if direction.length()>0.1:
			p.move_dir=direction.normalized()
		p.motion="run" if running_now else "walk"
		if before.distance_to(p.p)<0.01:
			p.motion="idle"
	p.move_speed=before.distance_to(p.p)/maxf(dt,0.001)

func down(p: Dictionary) -> void:
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

func attack(p: Dictionary) -> void:
	if p.attack>0 or p.reload>0 or p.swing_time>0 or p.cast_time>0 or p.dodge_time>0 or p.status!="active":
		return
	var weapon: Dictionary=Catalog.WEAPONS[p.weapon]
	if p.weapon==0 and p.ammo<=0:
		reload_player(p)
		return
	p.combo=(int(p.combo)+1)%3 if p.combo_timeout>0 else 0
	p.combo_timeout=1.2
	p.attack=weapon.rate
	p.swing_total=weapon.rate
	p.swing_time=weapon.rate
	p.strike_aim=p.aim.normalized()
	p.pending_strike=true
	broadcast_combat({"kind":"windup","p":p.p,"aim":p.strike_aim,"weapon":p.weapon,"id":p.id,"combo":p.combo})
	if weapon.windup==0:
		p.pending_strike=false
		release_strike(p)

func release_strike(p: Dictionary) -> void:
	var w: Dictionary=Catalog.WEAPONS[p.weapon]
	var direction: Vector2=p.strike_aim
	var damage: float=w.damage*(1+p.talents[1]*0.08+mini(3,charms_carried(p))*0.12+Catalog.GEAR[p.gear].damage)
	if p.weapon==1 and p.combo==2:
		damage*=1.4
	broadcast_combat({"kind":"strike","p":p.p,"aim":direction,"weapon":p.weapon,"id":p.id,"combo":p.combo})
	if p.weapon in [1,2]:
		for e in enemies:
			var v: Vector2=e.p-p.p
			if e.hp>0 and v.length()<w.reach and v.normalized().dot(direction)>-0.1 and ruins.clear_line(p.p,e.p):
				damage_enemy(e,damage,p.id,direction,w.knock)
	else:
		if p.weapon==0:
			p.ammo-=1
			emit_effect("shot",p.p)
		bullets.append({"p":p.p+direction*23,"v":direction*(850 if p.weapon==0 else 620),"life":1.1,"damage":damage,"owner":p.id,"weapon":p.weapon})

func damage_enemy(e: Dictionary, damage: float, owner: int, direction: Vector2, knock: float) -> void:
	e.hp-=damage
	e.last=owner
	e["flash"]=0.14
	e["stagger"]=0.12 if knock<40 else 0.26
	var impact: Vector2=e.p
	e.p=ruins.move(e.p,direction*knock)
	if players.has(owner):
		players[owner].hitstop=0.045 if knock<40 else 0.085
	broadcast_combat({"kind":"impact","p":impact,"aim":direction,"damage":damage,"heavy":knock>=40,"id":owner})

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
		"exit":
			p.status="extracted"
			emit_effect("bell",p.p)
		"revive":
			players[index].status="active"
			players[index].hp=players[index].max_hp*0.4
			players[index].invuln=2
			emit_effect("skill",p.p)
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

func spawn_enemy(at: Vector2 = Vector2.ZERO, type: int = -1) -> void:
	var pos := at
	if pos==Vector2.ZERO:
		pos=Vector2(rng.randf_range(400,2680),rng.randf_range(230,1970))
	for i in 24:
		var near := false
		for p in players.values():
			if p.status=="active" and p.p.distance_to(pos)<260:
				near=true
		if not ruins.blocked(pos,25) and not near:
			break
		pos=Vector2(rng.randf_range(380,2680),rng.randf_range(230,1970))
	if ruins.blocked(pos,25):
		return
	var kind := type if type>=0 else rng.randi_range(0,2)
	var health: float = [58.0,42.0,125.0,310.0][kind]*(1+0.3*(players.size()-1))
	enemies.append({"id":next_enemy,"p":pos,"type":kind,"hp":health,"max_hp":health,"cd":0.0,"last":1,"wander":Vector2.from_angle(rng.randf()*TAU)})
	next_enemy+=1

func update_enemies(dt: float) -> void:
	for e in enemies:
		if e.hp<=0:
			continue
		e["flash"]=maxf(0,float(e.get("flash",0))-dt)
		e["stagger"]=maxf(0,float(e.get("stagger",0))-dt)
		if e.stagger>0:
			continue
		e.cd=maxf(0,e.cd-dt)
		var target: Dictionary={}
		var best := 440.0+threat*300
		for p in players.values():
			if p.status!="active":
				continue
			var dist: float=e.p.distance_to(p.p)
			if dist<best+p.scent*4:
				best=dist
				target=p
		if target.is_empty():
			e.p=ruins.move(e.p,e.wander*18*dt)
			continue
		var direction: Vector2=(target.p-e.p).normalized()
		var speed: float=[110,95,68,140][e.type]*(1+threat*0.3)
		var ranged: bool=e.type==1 and best<330 and ruins.clear_line(e.p,target.p)
		if not ranged and best>32:
			var before: Vector2=e.p
			e.p=ruins.move(e.p,direction*speed*dt)
			if e.p.distance_to(before)<speed*dt*0.2:
				e.p=ruins.move(e.p,direction.orthogonal()*speed*dt)
		if e.cd<=0:
			if ranged:
				e.cd=2.0
				bullets.append({"p":e.p,"v":direction*245,"life":2.0,"damage":13.0,"owner":0})
			elif best<45 and ruins.clear_line(e.p,target.p):
				e.cd=0.85
				hurt(target,[12,8,20,25][e.type])

func hurt(p: Dictionary, damage: float) -> void:
	if p.invuln>0 or p.status!="active":
		return
	p.hp-=damage
	p.invuln=0.3
	p.channel=0
	emit_effect("hurt",p.p)
	if p.hp<=0:
		down(p)

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
						damage_enemy(e,b.damage,b.owner,b.v.normalized(),16.0)
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
		results[id]={"name":p.name,"escaped":extracted,"loot":loot,"shared":shared,"kills":p.kills,"coins":loot+shared,"xp":35+p.kills*8+objectives*25+(60 if extracted else 0),"pocket":Catalog.clean_container(p.pocket,Catalog.POCKET_GRID),"bags":saved_bags(p,extracted)}
	running=false
	finished.emit()
	if online:
		receive_results.rpc(results,players)

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
