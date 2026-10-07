class_name TideSession
extends Node
const BossChoreography = preload("res://scripts/boss_choreography.gd")
const BossTactics = preload("res://scripts/boss_tactics.gd")
const BossPresentation = preload("res://scripts/boss_presentation.gd")
var enemy_bodies = preload("res://scripts/enemy_body.gd").new()

signal changed
signal map_changed
signal started
signal finished
signal message(text: String)
signal effect(kind: String, pos: Vector2)
signal combat_event(data: Dictionary)
signal direct_connect_failed
signal p2p_connect_failed

var dedicated := false
var server_room := false
var room_code := ""
var leader_id := 1
var ticket_file := ""
var used_tickets: Dictionary = {}
var account_peers: Dictionary = {}
var connect_deadline := 0
var p2p_attempt := false
var p2p_room_code := ""
var p2p_tickets: Dictionary = {}
var p2p_ticket_peers: Dictionary = {}

const PORT := 24872
const AMBIENT_SPAWN_MIN := 360.0
const AMBIENT_SPAWN_MAX := 1050.0
const DODGE_DURATION := 0.24
const DODGE_DISTANCE := 145.0
const RUN_MULTIPLIER := 1.45
const ONLINE_ULTIMATE_DURATION := 0.85
var players: Dictionary = {}
var inputs: Dictionary = {}
var ruins := Ruins.new()
var map_id := "border"
var map_states: Dictionary = {}
const CITY_GATE := Vector2(3860,1880)*Ruins.MAP_SCALE
var enemies: Array = []
var bullets: Array = []
var world_drops: Array = []
var results: Dictionary = {}
var running := false
var online := false
const DAY_DURATION := 300.0
const SHRINK_START := 180.0
var duration := DAY_DURATION
var elapsed := 0.0
var threat := 0.0
var objectives := 0
var seed_value := 0
var sync_timer := 0.0
var spawn_timer := 0.0
var input_timer := 0.0
var next_enemy := 0
var selected_mode := "expedition"
var local_config: Dictionary = {}
var local_input := {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"fire":false,"interact":false}
var rng := RandomNumberGenerator.new()
var report_paid := false
var request_cooldowns: Dictionary = {}
var pending_ultimates: Dictionary = {}
# 墓煜's ultimate lives in two queues: the rune rain waiting to land, and the
# underworld fire it leaves behind. Both are host authoritative and replicated
# to clients as ordinary combat events.
var soul_reaps: Array = []
var fire_zones: Array = []
var raid: Dictionary = {}
# Contracts §C1: the authoritative node graph never enters the snapshot packet.
# Clients rebuild it from (seed_value, floor) so only the current node/depth ride
# inside `raid`; keeping it on a plain session var guarantees it stays offline.
var rogue_graph: Dictionary = {}
var roguelike = preload("res://scripts/roguelike.gd").new()
var expedition = preload("res://scripts/expedition.gd").new()
var mini_bosses = preload("res://scripts/mini_bosses.gd").new()
var wild_bosses = preload("res://scripts/wild_bosses.gd").new()
var dragon_boss = preload("res://scripts/dragon_boss.gd").new()

const SEARCH_SECONDS_BY_TIER := [0.55,0.8,1.1,1.45,1.9,2.4]
const SEARCH_RANGE := 86.0

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func():
		var p2p := p2p_attempt
		var direct := not server_room and not p2p
		disconnect_room()
		if p2p: p2p_connect_failed.emit()
		else:
			message.emit("连接失败：请检查地址、防火墙和 UDP 24872 端口。")
			if direct: direct_connect_failed.emit())
	multiplayer.server_disconnected.connect(func():
		var lobby_p2p := p2p_attempt and not running
		disconnect_room()
		message.emit("P2P 房主连接中断，正在检查服务器兜底…" if lobby_p2p else "联机连接已断开。本局未结算的战利品不计入存档。"))

func my_id() -> int:
	return multiplayer.get_unique_id() if online else 1

func authority() -> bool:
	return not online or multiplayer.is_server()

## The meta-progression channel (contracts v3-1/v3-3). `main.gd` attaches the live
## profile dictionary with `set_meta("profile_data", profile.data)` before a roguelike
## run so `RogueGrowth.grant()` can bank the run's ash and `RogueGrowth.power()` can pay
## the growth tree into the starting purse; tests attach a raw dictionary the same way.
## Returns `{}` while nothing is attached — which is exactly the pre-wiring behaviour,
## so `power()` stays all-zero and every shipped starting number is bit-identical.
func profile_data() -> Dictionary:
	if has_meta("profile_data"):
		var attached: Variant=get_meta("profile_data")
		if attached is Dictionary: return attached
	return {}

func solo(config: Dictionary) -> void:
	disconnect_room()
	local_config=config
	selected_mode="roguelike" if config.get("mode","")=="roguelike" else "expedition"
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
	selected_mode="roguelike" if config.get("mode","")=="roguelike" else "expedition"
	players[1]=make_player(1,config)
	changed.emit()
	return OK

func join(address: String, config: Dictionary, port: int = PORT, local_port: int = 0, p2p: bool = false) -> Error:
	disconnect_room()
	local_config=config
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(),port,0,0,0,local_port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer=peer
	online=true
	p2p_attempt=p2p
	connect_deadline=Time.get_ticks_msec()+8000
	return OK

func disconnect_room() -> void:
	dedicated=false
	server_room=false
	room_code=""
	leader_id=1
	used_tickets.clear()
	account_peers.clear()
	connect_deadline=0
	p2p_attempt=false
	p2p_room_code=""
	p2p_tickets.clear()
	p2p_ticket_peers.clear()
	running=false
	selected_mode="expedition"
	pending_ultimates.clear()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	online=false
	players.clear()
	inputs.clear()
	results.clear()
	changed.emit()

func host_dedicated(port: int) -> Error:
	disconnect_room()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port,4)
	if err!=OK: return err
	multiplayer.multiplayer_peer=peer
	online=true
	dedicated=true
	server_room=true
	leader_id=0
	return OK

func join_server(room: Dictionary, config: Dictionary) -> Error:
	var payload := config.duplicate(true)
	payload["_ticket"]=room.ticket
	var err := join(str(room.host),payload,int(room.port))
	if err==OK:
		server_room=true
		room_code=str(room.code)
		connect_deadline=Time.get_ticks_msec()+15000
	return err

func is_leader() -> bool:
	return my_id()==leader_id

func request_launch() -> void:
	if authority(): launch()
	elif server_room: room_command.rpc_id(1,"launch")

func select_mode(mode: String) -> void:
	if running or mode not in ["expedition","roguelike"]: return
	if authority(): apply_mode(my_id(),mode)
	else: mode_request.rpc_id(1,mode)

@rpc("any_peer","call_remote","reliable")
func mode_request(mode: String) -> void:
	if authority(): apply_mode(multiplayer.get_remote_sender_id(),mode)

func apply_mode(id: int, mode: String) -> void:
	if running or id!=leader_id or mode not in ["expedition","roguelike"]: return
	if selected_mode==mode: return
	selected_mode=mode
	for p in players.values(): p.ready=false
	push_lobby()

func request_camp() -> void:
	if authority(): return_to_camp()
	elif server_room: room_command.rpc_id(1,"camp")

@rpc("any_peer","call_remote","reliable")
func room_command(command: String) -> void:
	if not dedicated or multiplayer.get_remote_sender_id()!=leader_id or running: return
	if command=="launch" and not launch():
		room_notice.rpc_id(leader_id,"等待所有队友准备完毕。")
	elif command=="camp": return_to_camp()

@rpc("authority","call_remote","reliable")
func room_notice(text: String) -> void:
	message.emit(text)

func validate_ticket(id: int, config: Dictionary) -> bool:
	var digest := str(config.get("_ticket","")).sha256_text()
	var tickets = JSON.parse_string(FileAccess.get_file_as_string(ticket_file))
	if not tickets is Dictionary or not tickets.has(digest) or used_tickets.has(digest):
		print("Ticket denied: unknown or reused")
		return false
	var ticket: Dictionary=tickets[digest]
	if float(ticket.get("expires",0))<Time.get_unix_time_from_system():
		print("Ticket denied: expired")
		return false
	var user := str(ticket.get("user",""))
	if account_peers.has(user):
		print("Ticket denied: already connected")
		return false
	# Only the creator can claim an empty room before the first owner connects.
	if leader_id==0 and not bool(ticket.get("owner",false)):
		print("Ticket denied: creator not connected")
		return false
	used_tickets[digest]=true
	account_peers[user]=id
	if leader_id==0: leader_id=id
	return true

func _connected() -> void:
	connect_deadline=Time.get_ticks_msec()+15000
	register.rpc_id(1,local_config)

@rpc("any_peer","call_remote","reliable")
func register(config: Dictionary) -> void:
	if not authority():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id): return
	if running or players.size()>=4:
		rejected.rpc_id(id,"房间已出发或已满，请等待下一局。")
		return
	if dedicated and not validate_ticket(id,config):
		rejected.rpc_id(id,"房间凭证失效，请重新通过服务器加入。")
		return
	if not p2p_room_code.is_empty():
		var digest := str(config.get("_p2p_ticket","")).sha256_text()
		if not p2p_tickets.has(digest) or (p2p_ticket_peers.has(digest) and p2p_ticket_peers[digest]!=id):
			rejected.rpc_id(id,"P2P 房间凭证失效，请重新加入。")
			return
		p2p_ticket_peers[digest]=id
	players[id]=make_player(id,config)
	players[id].ready=id==leader_id
	push_lobby()

@rpc("authority","call_remote","reliable")
func rejected(reason: String) -> void:
	var p2p := p2p_attempt
	disconnect_room()
	message.emit(reason)
	if p2p: p2p_connect_failed.emit()

const Homestead = preload("res://scripts/homestead.gd")

func make_player(id: int, config: Dictionary) -> Dictionary:
	var h := clampi(int(config.get("hero",0)),0,Catalog.HEROES.size()-1)
	var talents: Array = config.get("talents",[0,0,0])
	if talents.size()!=3:
		talents=[0,0,0]
	for i in 3:
		talents[i]=clampi(int(talents[i]),0,5)
	var gear := clampi(int(config.get("gear",-1)),-1,Catalog.GEAR.size()-1)
	var attributes := WatcherAttributes.clean(config.get("attributes",{}))
	var meal := Homestead.meal_id(config.get("home_meal",""))
	var hp: float=Homestead.bonus({"home_meal":meal},"hp")+Catalog.HEROES[h].hp+talents[0]*12+float(Catalog.gear_of(gear).get("hp",0.0))+WatcherAttributes.hp_bonus(attributes)
	var storage := storage_from_config(config)
	# A raid starts with the kit the Watcher walked out with last time: the worn
	# weapon, gear, charms and quick sockets are part of the save file now, so the
	# issue weapon is only the fallback for a hero who owns nothing better. An empty
	# hand is impossible — `restore_issue_weapon()` guards the other direction.
	var weapon_index := Catalog.starter_index(h)
	var worn_weapon = storage.get("equipped",{}).get("weapon",{})
	if worn_weapon is Dictionary and not worn_weapon.is_empty():
		weapon_index=clampi(int(worn_weapon.get("weapon",weapon_index)),0,Catalog.WEAPONS.size()-1)
	# "slots" is the item bar: three quick sockets that carry one item each, so a
	# weapon, a spare pack or a medkit is one keypress away instead of a trip into
	# the backpack. The whole player dictionary travels through the ENet snapshot,
	# so clients see them too.
	var player := {"id":id,"name":str(config.get("name","守夜人")).left(16),"hero":h,"weapon":weapon_index,"swing_time":0.0,"swing_total":0.0,"pending_strike":false,"strike_aim":Vector2.RIGHT,"combo":0,"combo_timeout":0.0,"hitstop":0.0,"cast_time":0.0,"gear":gear,"talents":talents,"equipped":storage.get("equipped",empty_equipment()),"slots":storage.get("slots",empty_item_slots()),"ready":id==leader_id,"p":Ruins.SPAWN,"aim":Vector2.RIGHT,"hp":hp,"max_hp":hp,"sanity":100.0,"status":"active","pocket":storage.pocket,"backpack":storage.backpack,"bags":storage.bags,"ammo":Catalog.HEROES[h].clip,"reserve":96,"attack":0.0,"reload":0.0,"skill":0.0,"dash":0.0,"invuln":0.0,"channel":0.0,"search":0.0,"search_ref":-1,"target":"","bleed":40.0,"kills":0,"scent":0.0,"crystals":0,"meds":clampi(int(config.get("meds",1)),1,3),"self_revive":true,"connected":true}
	player["home_meal"]=meal
	player.merge({"attributes":attributes,"mana":WatcherAttributes.max_mana(attributes),"max_mana":WatcherAttributes.max_mana(attributes),"mana_delay":0.0,"art_cd":0.0})
	player.merge({"motion":"idle","move_dir":Vector2.RIGHT,"move_speed":0.0,"dodge_time":0.0,"dodge_dir":Vector2.RIGHT})
	player.merge({"mode":str(config.get("mode","expedition")),"rogue_rerolls":clampi(int(config.get("rogue_rerolls",0)),0,5),"rogue_weapon":clampi(int(config.get("rogue_weapon",-1)),-1,Catalog.WEAPONS.size()-1)})
	return player

# What the player wears on top of the camp loadout: one weapon plus the three
# gear slots. It is written into the save file on extraction and scattered on the
# ground on death (see `spill_storage()` and `saved_loadout()`), so a Watcher who
# walks home alive keeps wearing what they found.
func empty_equipment() -> Dictionary:
	return {"weapon":{},"gear":[{},{},{}],"charm":[{},{}]}

# The item bar is three independent sockets rather than a grid: a slot takes
# exactly one item, however many cells that item would need in a backpack. A 2x2
# weapon and a 1x1 blood crystal are equally at home in one, so the bar is about
# reach rather than storage.
const ITEM_SLOT_COUNT := 3

func empty_item_slots() -> Array:
	var slots: Array = []
	for i in ITEM_SLOT_COUNT:
		slots.append({})
	return slots

# Three sockets, rebuilt defensively because the whole player dictionary travels
# through ENet snapshots as plain data.
func item_slots(p: Dictionary) -> Array:
	var slots = p.get("slots",[])
	if not slots is Array:
		slots=[]
	while slots.size()<ITEM_SLOT_COUNT:
		slots.append({})
	p["slots"]=slots
	return slots

func item_slot(p: Dictionary, index: int) -> Dictionary:
	var slots := item_slots(p)
	var at := clampi(index,0,ITEM_SLOT_COUNT-1)
	var entry = slots[at]
	return entry if entry is Dictionary else {}

func set_item_slot(p: Dictionary, index: int, entry: Dictionary) -> void:
	var slots := item_slots(p)
	slots[clampi(index,0,ITEM_SLOT_COUNT-1)]=entry
	p["slots"]=slots

func item_slot_name(index: int) -> String:
	return "道具栏 %d" % (clampi(index,0,ITEM_SLOT_COUNT-1)+1)

func item_slot_kind(p: Dictionary, index: int) -> String:
	var entry := item_slot(p,index)
	return str(entry.get("kind","")) if not entry.is_empty() else ""

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

func charm_slots(equipped: Dictionary) -> Array:
	var slots = equipped.get("charm",[])
	if not slots is Array:
		slots=[]
	while slots.size()<2:
		slots.append({})
	return slots

func kit_charms(p: Dictionary) -> Array:
	var equipped = p.get("equipped",{})
	return charm_slots(equipped) if equipped is Dictionary else [{},{}]

func charms_equipped(p: Dictionary) -> int:
	var count := 0
	for entry in kit_charms(p):
		if entry is Dictionary and str(entry.get("kind",""))=="charm" and not entry.is_empty():
			count+=1
	return count

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
	return gear_bonus_of(p,0)+rogue_equipment_stat(p,"hp")

const RogueEquipment = preload("res://scripts/rogue_equipment.gd")
const RogueBuild = preload("res://scripts/rogue_build.gd")
const RogueActions = preload("res://scripts/rogue_actions.gd")
const RogueVariants = preload("res://scripts/rogue_variants.gd")
const RogueCurses = preload("res://scripts/rogue_curses.gd")
# A1: the meta growth tree (profile.data.growth) is the third source of `rogue_mods()`.
const RogueGrowth = preload("res://scripts/rogue_growth.gd")

func rogue_equipment_stat(p: Dictionary, stat: String) -> float:
	return RogueEquipment.total(p,stat) if roguelike.active(self) else 0.0

func stat_defense(p: Dictionary) -> float:
	if roguelike.active(self): return 1.0-(1.0-minf(.35,.05+rogue_equipment_stat(p,"defense")+RogueBuild.stat(self,p,"defense")))*(1.0-stat_resistance(p))
	var reduction: float=float(Catalog.gear_of(int(p.gear)).get("defense",0.0))
	reduction+=rogue_equipment_stat(p,"defense")
	for entry in kit_gear(p):
		if entry is Dictionary and not entry.is_empty() and Catalog.gear_slot(entry)==0:
			reduction+=Catalog.gear_defense(entry)
	return 1.0-(1.0-clampf(reduction,0.0,0.30))*(1.0-stat_resistance(p))

func attributes_of(p: Dictionary) -> Dictionary:
	if roguelike.active(self): return RogueBuild.attributes(p)
	var value: Variant=p.get("attributes",{})
	return value if value is Dictionary else {}

func stat_resistance(p: Dictionary) -> float:
	return WatcherAttributes.resistance(attributes_of(p))

func stat_discovery(p: Dictionary) -> float:
	return WatcherAttributes.discovery(attributes_of(p))

func enemy_drop_chance(e: Dictionary) -> float:
	var killer: Dictionary=players.get(int(e.get("last",0)),{})
	return clampf(Ecology.drop_chance(e)*stat_discovery(killer)/100.0,0.0,1.0)

func weapon_scaling(p: Dictionary, index: int = -1) -> float:
	var weapon_index := int(p.weapon) if index<0 else index
	return WatcherAttributes.scaling(attributes_of(p),RogueBuild.grades(p,weapon_index) if roguelike.active(self) else Catalog.weapon(weapon_index).get("scaling",{}))

func rogue_damage_pool(p: Dictionary) -> float:
	return minf(1.2,float(p.get("rogue_damage",0))+Homestead.bonus(p,"damage")+p.talents[1]*.08+rogue_equipment_stat(p,"damage")+RogueBuild.stat(self,p,"damage"))

## 魔境数值钩子的**唯一**集中入口：把「当前层的深渊变数」（全队共享）、
## 「该玩家身上的诅咒」（个人）与「局外永久成长树」（账号级）合成一张数值表，
## 供受击/输出/移速/弹幕/经济读取。
## 铁律：不消耗 s.rng、不重置种子；绝不产出任何命中判定几何键——弹幕只允许
## 改表现层 `bullet_visual` 与速度，命中半径永远沿用默认的 18.0。
## 非魔境模式返回空表（调用方换算恒等）。
## A1（成长树接线）：第三个来源是 `RogueGrowth.run_mods(profile_data())`——成长树有 14 个
## 节点，其中 11 个（`iron_constitution`/`monster_slaying`/`hunt_instinct`/`warden_plate`/
## `deep_pockets`/`scavenger`/`field_medic`/`swift_boots`/`scholar`/`midas_hand`/`hunter_luck`）
## 的效果键在别处本来就有消费点，但从来没人把成长树读进这张表，所以「买了不生效」。
## 合并是**加法**（与诅咒同义）：`move_speed` 是加性点数（诅咒 CU02 = -18，成长 = +12/级），
## `shop_price`/`chest_drop`/`heal_scale`/`gold` 是比例增量（诅咒 CU04 = +0.35，成长 = -0.05/级）。
## 成长表的符号约定与诅咒**相反**（正数＝对玩家有利），GDScript 加法天然正确处理。
## 两个来源的键集不相交（成长只产 canonical 键，诅咒只产 `EFFECT_KEYS`），
## 唯一交叠的 `move_speed`/`shop_price`/`chest_drop`/`heal_scale` 正是设计上要同池相加的。
## 无 profile 通道时 `run_mods({})` 全零，`4 玩家数` 与接线前逐位一致。
func rogue_mods(p: Dictionary = {}) -> Dictionary:
	var mods: Dictionary = {}
	if not roguelike.active(self):
		return mods
	var ids: Array = []
	var variant_id := str(raid.get("variant",""))
	if variant_id != "":
		ids.append(variant_id)
	mods = RogueVariants.modifiers_of(ids)
	# 成长树：账号级，与 p 无关（换人不换树）。先并入，再让诅咒叠在它上面。
	# 只算一次表，循环里不再重复算（`rogue_mods()` 在移速路径上每帧每人一次）。
	var growth: Dictionary = RogueGrowth.run_mods(profile_data())
	for key in growth:
		mods[key] = float(mods.get(key,0.0)) + float(growth[key])
	if not p.is_empty():
		var curse: Dictionary=RogueCurses.stat_delta(p)
		for key in curse.keys():
			mods[key]=float(mods.get(key,0.0))+float(curse[key])
		# 诅咒的「受伤加重」走减伤池**同池相减**（已冻结裁决），这里不出乘数。
		mods["defense_penalty"]=RogueCurses.defense_penalty(p)
		mods["curse_count"]=RogueCurses.count(p)
	return mods

## 敌人普通弹幕的深渊变数钩子：只改弹速与**表现层**尺寸。
## mods 中性时返回原字典（逐字不变），也绝不写 hit_radius。
func rogue_enemy_bolt(bolt: Dictionary) -> Dictionary:
	var mods := rogue_mods()
	var speed_scale := 1.0+clampf(float(mods.get("bullet_speed",0.0)),-0.5,0.5)
	var visual_scale := 1.0+clampf(float(mods.get("bullet_size",0.0)),0.0,1.0)
	if is_equal_approx(speed_scale,1.0) and is_equal_approx(visual_scale,1.0):
		return bolt
	var velocity: Vector2=bolt["v"]
	bolt["v"]=velocity*speed_scale
	bolt["bullet_visual"]=visual_scale
	return bolt

func weapon_damage(p: Dictionary, index: int = -1, quality: int = -1) -> float:
	if roguelike.active(self):
		var at := int(p.weapon) if index<0 else index
		var q: float=RogueBuild.quality(p) if quality<0 else RogueBuild.Content.QUALITY[clampi(quality,0,5)]
		return float(Catalog.weapon(at).damage)*q*(1.0+weapon_scaling(p,at))*(1.0+rogue_damage_pool(p))
	var weapon_index := int(p.weapon) if index<0 else index
	var kit_bonus := equipment_damage(p)
	if quality>=0:
		kit_bonus=gear_bonus_of(p,1)+Catalog.WEAPON_DAMAGE_BONUS[Catalog.tier_of(quality)]
	return float(Catalog.weapon(weapon_index).damage)*(1.0+weapon_scaling(p,weapon_index))*(1.0+float(p.get("rogue_damage",0))+Homestead.bonus(p,"damage")+p.talents[1]*0.08+charms_equipped(p)*0.12+float(Catalog.gear_of(int(p.gear)).get("damage",0.0))+kit_bonus)

const ULTIMATE_MANA := 30.0
const MANA_REGEN_DELAY := 1.5

func spend_mana(p: Dictionary, cost: float) -> bool:
	if cost<=0:
		return true
	if float(p.get("mana",0.0))<cost:
		return false
	p.mana=maxf(0.0,p.mana-cost)
	p.mana_delay=MANA_REGEN_DELAY
	if roguelike.active(self): RogueBuild.spend_event(self,p,cost)
	return true

func recover_mana(p: Dictionary, dt: float) -> void:
	if p.status!="active":
		return
	if roguelike.active(self):
		var waiting: float=float(p.get("mana_delay",0))
		p.mana_delay=maxf(0,waiting-dt)
		var delay: float=1.2 if RogueBuild.gear(p,65) else 1.5
		var idle: float=maxf(0,dt-maxf(0,waiting-(MANA_REGEN_DELAY-delay)))
		p.mana=minf(p.max_mana,p.mana+minf(180,p.max_mana)*(.025*dt+.025*idle)*(1+RogueBuild.stat(self,p,"regen")))
		return
	var waiting := maxf(0.0,float(p.get("mana_delay",0.0)))
	p.mana_delay=maxf(0.0,waiting-dt)
	var recovering := maxf(0.0,dt-waiting)
	var casting_attack: bool = p.swing_time>0 and float(Catalog.weapon(int(p.weapon)).get("mana_cost",0.0))>0
	if not casting_attack and p.cast_time<=0 and not pending_ultimates.has(int(p.id)):
		# 装备被动不在这一条路径上：本分支是搜打撤/战役（魔境在 recover_mana 顶部已经 return）。
		# E004「HP≥80% 回蓝 +25%」的唯一实现处是 RogueBuild.stat(...,"regen")，此处曾用一个
		# 永远为假的 roguelike.active(self) 条件把它写成 bonus=1.0，属死代码，已删除。
		p.mana=minf(p.max_mana,p.mana+recovering*p.max_mana*0.06)

func incoming_damage(p: Dictionary, damage: float) -> float:
	if roguelike.active(self):
		var mods := rogue_mods(p)
		# 诅咒与既有减伤池**同池相减**：不开新乘数。
		var pool := RogueBuild.conditional_defense(self,p)
		var penalty := float(mods.get("defense_penalty",0.0))
		if penalty>0.0: pool=clampf(pool-penalty,0.0,RogueCurses.MAX_POOL)
		var received := maxf(0,damage)*(1-stat_defense(p))*(1-pool)
		var taken := float(mods.get("player_damage_taken",0.0))
		if taken!=0.0: received*=1.0+taken
		return maxf(0.0,received)
	# 同上：本分支只服务搜打撤/战役（魔境在上面已经 return）。E002「HP<35% 条件减伤 +15%」
	# 的唯一实现处是 RogueBuild.conditional_defense；这里曾用永远为假的 roguelike.active(self)
	# 写成 bonus=1.0，属死代码，已删除。
	return maxf(0.0,damage)*(1.0-stat_defense(p))*(1.0-minf(0.4,float(p.get("rogue_defense",0))))

func equipment_damage(p: Dictionary) -> float:
	if roguelike.active(self): return rogue_equipment_stat(p,"damage")
	var total := gear_bonus_of(p,1)+rogue_equipment_stat(p,"damage")
	if weapon_kit_active(p):
		total+=Catalog.weapon_bonus(kit_weapon(p))
	return total

func equipment_speed(p: Dictionary) -> float:
	return gear_bonus_of(p,2)+rogue_equipment_stat(p,"speed")

# Attack interval scale: an upgraded weapon swings faster.
func equipment_rate(p: Dictionary) -> float:
	if roguelike.active(self): return RogueBuild.interval(self,p)
	if not weapon_kit_active(p):
		return 1.0
	return maxf(0.4,1.0-Catalog.weapon_rate_bonus(kit_weapon(p)))

func stat_max_hp(p: Dictionary) -> float:
	if roguelike.active(self): return (Homestead.bonus(p,"hp")+Catalog.HEROES[p.hero].hp+p.talents[0]*12+rogue_equipment_stat(p,"hp")+WatcherAttributes.hp_bonus(attributes_of(p))+RogueBuild.stat(self,p,"hp"))*RogueBuild.hp_multiplier(p)
	return Homestead.bonus(p,"hp")+float(p.get("rogue_hp",0))+Catalog.HEROES[p.hero].hp+p.talents[0]*12+float(Catalog.gear_of(int(p.gear)).get("hp",0.0))+equipment_hp(p)+WatcherAttributes.hp_bonus(attributes_of(p))

# Recomputes the ceiling after gear changes: putting armour on grants the extra
# health immediately, taking it off only clamps.
func refresh_max_hp(p: Dictionary) -> void:
	var value := maxf(1.0,stat_max_hp(p))
	var gain := value-float(p.max_hp)
	p.max_hp=value
	p.hp=minf(value,float(p.hp)+(0.0 if roguelike.active(self) else maxf(0.0,gain)))
	p.max_mana=WatcherAttributes.max_mana(attributes_of(p))+rogue_equipment_stat(p,"mana")+(RogueBuild.stat(self,p,"mana") if roguelike.active(self) else 0)
	p.mana=minf(float(p.get("mana",0)),p.max_mana)


# Every player carries two storages: a permanent 4x4 dimensional pocket that is
# written back into the save file, and an equipped backpack whose size follows
# its quality. "bags" holds only the spare backpacks, so the equipped one is
# never counted or spilled twice. The worn kit rides along in "equipped"/"slots".
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
	var loadout := Catalog.clean_loadout(config.get("loadout",{}))
	# A raid handed the previous player dictionary back through `launch()` may carry
	# its own live kit; that one wins over the saved loadout.
	var live = config.get("equipped",{})
	if live is Dictionary and not live.is_empty():
		loadout["weapon"]=live.get("weapon",loadout["weapon"])
		loadout["gear"]=live.get("gear",loadout["gear"])
		loadout["charm"]=live.get("charm",loadout["charm"])
	var live_slots = config.get("slots",null)
	if live_slots is Array and not live_slots.is_empty():
		loadout["slots"]=live_slots
	loadout=Catalog.clean_loadout(loadout)
	return {"pocket":pocket,"backpack":backpack,"bags":cabinet,"equipped":{"weapon":loadout.weapon,"gear":loadout.gear,"charm":loadout.charm},"slots":loadout.slots}

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
	if roguelike.active(self) and kind=="medicine": return int(p.get("flask",0))/25
	return Catalog.container_count(p.backpack,kind)+Catalog.container_count(p.pocket,kind)

# Blood crystals are a tally rather than a carried item: they occupy no cell and
# are picked up by walking over them, so the count lives on the player. "carried"
# still finds one that was already sitting in a container from an older save, so
# no crystal is ever lost to the change.
func crystals_carried(p: Dictionary) -> int:
	return int(p.get("crystals",0))+carried(p,"crystal")

func add_crystals(p: Dictionary, units: int) -> void:
	p["crystals"]=maxi(0,int(p.get("crystals",0))+units)

func charms_carried(p: Dictionary) -> int:
	return carried(p,"charm")

# Consumables are deterministic: the backpack is spent first and exactly one
# item leaves the player, no matter how many containers hold the same kind.
func spend(p: Dictionary, kind: String) -> bool:
	if roguelike.active(self) and kind=="medicine": return false
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
# index, gear index, tier, stack count) so nothing is lost on the way in. This is
# the routing for grabbing loot in the field; the double click in the search
# window routes by quality instead, because that is where a player parks loot for
# the trip home.
func store_loot(p: Dictionary, kind: String, provision: bool = false, key: String = "", meta: Dictionary = {}) -> bool:
	var order: Array = ["pocket","backpack"] if Catalog.prefers_pocket(kind) else ["backpack","pocket"]
	var entry: Dictionary={"kind":kind,"rot":false,"count":1,"provision":provision}
	if kind=="backpack":
		entry["quality"]=key if Catalog.has_tier(key) else Catalog.DEFAULT_BAG_KEY
	for field in meta:
		entry[field]=meta[field]
	for name in order:
		if container_receive(p,name,entry):
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
	container["loose"]=true
	container["dropped"]=true
	# A dropped backpack names itself so it can be worn again.
	if kind=="backpack":
		container["key"]="bag:"+(key if Catalog.has_tier(key) else Catalog.DEFAULT_BAG_KEY)
	return container

# A blood crystal on the ground: no item inside, just a tally waiting to be
# walked over. It keeps the container shape so every existing drop helper — the
# map marker, the search scan, the tidy — can keep treating it as a small object
# without ever offering it as loot.
func crystal_drop(at: Vector2, units: int) -> Dictionary:
	var container := loot_container(at,Catalog.chest_grid(0))
	container["crystals"]=maxi(1,units)
	return container

# Drops an item on the ground at the player's feet. "entry" hands in an item that
# is not in any container — the tidy uses it to evict loot — and the container
# lookup is skipped entirely in that case.
func drop_item(p: Dictionary, slot: String, index: int, key: String = "", entry: Dictionary = {}) -> bool:
	if slot!="backpack" and slot!="pocket":
		return false
	var container: Dictionary=p[slot]
	var list: Array=container.items
	var carried: Dictionary = {}
	if entry.is_empty():
		if index<0 or index>=list.size():
			return false
		carried=list[index]
	else:
		carried=entry
	carried=carried.duplicate()
	carried["x"]=0
	carried["y"]=0
	var bag := loot_container(p.p+Vector2(25,20),Catalog.chest_grid(0))
	bag.items.append(carried)
	bag["loose"]=container_units(bag)==1
	bag["searched"]=1 if bag.loose else 0
	bag["dropped"]=true
	# A backpack keeps its quality so whoever grabs it can wear it.
	var bag_key := key
	if bag_key.is_empty() and carried.kind=="backpack":
		bag_key=str(carried.get("quality",Catalog.DEFAULT_BAG_KEY))
	if not bag_key.is_empty():
		bag["key"]="bag:"+(bag_key if Catalog.has_tier(bag_key) else Catalog.DEFAULT_BAG_KEY)
	world_drops.append(bag)
	if entry.is_empty():
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
		var bag := loot_container(Vector2.ZERO,Catalog.container_grid(container))
		for item in Catalog.container_items(container):
			bag.items.append(item.duplicate())
		bag["key"]="bag:"+Catalog.bag_key(container)
		bag["loose"]=container_units(bag)==1
		bag["searched"]=1 if bag.loose else 0
		bag["dropped"]=true
		bag["p"]=p.p+Vector2(rng.randf_range(-42,42),rng.randf_range(-34,34))
		world_drops.append(bag)
		container.items.clear()
	# The equipped kit is worn, so it hits the ground as its own pile. The item bar
	# is worn the same way: whatever rides in a quick socket is on the Watcher, not
	# banked, so death scatters it too.
	var worn: Array = []
	var weapon := kit_weapon(p)
	if not weapon.is_empty():
		worn.append(weapon)
	for entry in kit_gear(p):
		if entry is Dictionary and not entry.is_empty():
			worn.append(entry)
	for entry in kit_charms(p):
		if entry is Dictionary and not entry.is_empty():
			worn.append(entry)
	for entry in item_slots(p):
		if entry is Dictionary and not entry.is_empty():
			worn.append(entry)
	p["slots"]=empty_item_slots()
	if not worn.is_empty():
		var kit := loot_container(p.p+Vector2(rng.randf_range(-30,30),rng.randf_range(-24,24)),Vector2i(8,8))
		for entry in worn:
			var copy: Dictionary=entry.duplicate()
			copy["x"]=0
			copy["y"]=0
			copy["rot"]=false
			kit.items.append(copy)
		Catalog.tidy(kit)
		kit["loose"]=container_units(kit)==1
		kit["searched"]=1 if kit.loose else 0
		kit["dropped"]=true
		kit["title"]="遗落装备"
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
	if container.get("dropped",false):
		return "掉落包" if container_units(container)>1 else "地面物品"
	return "深处教堂物资箱" if int(container.get("class",1))>=2 else "物资箱"

func container_is_bag(container: Dictionary) -> bool:
	return str(container.get("key","")).begins_with("bag:")

# F on a container starts searching it; items surface one unit at a time. Searching
# keeps its own timer so the E-channel (revive, shrine, exit) cannot reset it.
func begin_search(p: Dictionary, index: int) -> void:
	var container := container_at(index)
	if container.is_empty():
		return
	if container.items.is_empty() and not container.get("open",false) and not container_is_bag(container) and not container.get("fixed_loot",false):
		var biome := ruins.biome_at(container.p) if map_id=="border" else -1
		for entry in chest_loot(bool(container.get("bonus",false)),-1.0,int(container.get("cache_tier",0)),biome):
			place_entry(container,entry)
	container["open"]=true
	if search_reference(p)!=index:
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
	while not container_searched(container):
		var next: Dictionary=next_search_item(container)
		if next.is_empty():
			break
		var duration := search_seconds(next)
		if float(p["search"])<duration:
			break
		p["search"]=float(p["search"])-duration
		container["searched"]=searched_units(container)+1
		emit_effect("search-reveal-%d" % Catalog.item_tier(next),container.p)

func next_search_item(container: Dictionary) -> Dictionary:
	var remaining := searched_units(container)
	for item in Catalog.container_items(container):
		var units := int(item.get("count",1)) if Catalog.stacks(str(item.kind)) else 1
		if remaining<units:
			return item
		remaining-=units
	return {}

func search_seconds(item: Dictionary) -> float:
	return float(SEARCH_SECONDS_BY_TIER[Catalog.item_tier(item)])

func search_target(p: Dictionary) -> int:
	var nearest := -1
	var best := 80.0*80.0
	for i in ruins.chests.size():
		var distance: float=p.p.distance_squared_to(ruins.chests[i].p)
		if distance<best:
			best=distance
			nearest=i
	return nearest

func search_dropped_target(p: Dictionary) -> int:
	var nearest := -1
	var best := 70.0*70.0
	for i in world_drops.size():
		var drop: Dictionary=world_drops[i]
		if container_units(drop)<=1:
			continue
		var distance: float=p.p.distance_squared_to(drop.p)
		if distance<best:
			best=distance
			nearest=ruins.chests.size()+i
	return nearest

# F on loose ground loot: instant pickup, no search window needed.
func pick_up_ground(p: Dictionary) -> bool:
	var nearby: Array[int]=[]
	for i in world_drops.size():
		var bag: Dictionary=world_drops[i]
		if container_units(bag)!=1 or bag.p.distance_to(p.p)>=70:
			continue
		nearby.append(i)
	nearby.sort_custom(func(a: int,b: int) -> bool: return world_drops[a].p.distance_squared_to(p.p)<world_drops[b].p.distance_squared_to(p.p))
	for i in nearby:
		var bag: Dictionary=world_drops[i]
		var item: Dictionary=bag.items[0]
		var key := str(item.get("quality",Catalog.bag_key({"key":str(bag.get("key","")).substr(4)})))
		if not store_loot(p,str(item.kind),bool(item.get("provision",false)),key,loot_meta(item)):
			continue
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
	remove_units(container,slot,moved)
	emit_effect("loot",p.p)
	return true

func drop_searched_loot(p: Dictionary, index: int) -> bool:
	var container := container_at(search_reference(p))
	if container.is_empty():
		return false
	var visible := visible_items(container)
	if index<0 or index>=visible.size():
		return false
	var entry: Dictionary=visible[index]
	if not drop_item(p,"backpack",-1,"",entry):
		return false
	remove_units(container,index,int(entry.get("count",1)))
	return true

func drop_item_slot(p: Dictionary, index: int) -> bool:
	var entry := item_slot(p,index)
	if entry.is_empty() or not drop_item(p,"backpack",-1,"",entry):
		return false
	set_item_slot(p,index,{})
	return true

# The double click in the search window: one item, worked into the player's own
# storage in one go. Two orders are possible and quality picks between them:
# gold and red loot is worth the safe pocket, so it is tried there first, while
# everything else fills the backpack the player is carrying and only falls back
# to the pocket. Within a container the item is offered the cells that are
# already free, and only when that fails is the container tidied once — so
# "there was room after the tidy" always ends up seated, never rerouted. A haul
# that is full of lower quality loot gives one item up for high quality loot and
# nothing more. Returns false when even that leaves no room, which the caller
# answers with silence: no message, no error, no reaction at all.
func auto_store(p: Dictionary, index: int) -> bool:
	var container := container_at(search_reference(p))
	if container.is_empty():
		return false
	var visible := visible_items(container)
	if index<0 or index>=visible.size():
		return false
	var want: Dictionary=visible[index]
	var kind := str(want.kind)
	if not Catalog.ITEMS.has(kind):
		return false
	# A stack travels as one pile, exactly like the take button: the whole visible
	# unit count leaves the container, not just its first item.
	var units := int(want.get("count",1))
	var entry := {
		"kind":kind,
		"rot":bool(want.get("rot",false)),
		"count":units,
		"provision":bool(want.get("provision",false))
	}
	for field in loot_meta(want):
		entry[field]=want[field]
	if kind=="backpack":
		var key := str(want.get("quality",Catalog.DEFAULT_BAG_KEY))
		entry["quality"]=key if Catalog.has_tier(key) else Catalog.DEFAULT_BAG_KEY
	# The order is decided by the fresh loot's own quality, so a red rifle and a
	# red backpack are both steered into the pocket while supplies go to the bag.
	# A high quality item may only ever push out strictly lower quality loot, so
	# the pass that evicts is the same pass that respects the order.
	#
	# ⚠️ This is the **documented exception** to the rarity rule: an ordinary piece
	# of loot still falls back to the pocket when the backpack is full, because a
	# searched haul must never be refused over a pocket the player is standing next
	# to. The rule governs the take-off / double-click gestures, not the loot window.
	# See README「稀有度与自动收纳判定」.
	var evict := Catalog.high_quality(entry)
	var order := ["pocket","backpack"] if evict else ["backpack","pocket"]
	for name in order:
		if store_into(p,name,entry,evict):
			remove_units(container,index,units)
			emit_effect("loot",p.p)
			return true
	# The backpack is the last resort for high quality loot that the pocket could
	# not house, and the pocket for ordinary loot the backpack could not.
	var other := "backpack" if order[0]=="pocket" else "pocket"
	if store_into(p,other,entry,evict):
		remove_units(container,index,units)
		emit_effect("loot",p.p)
		return true
	return false

# One arrival into one container: free cells, then a single tidy, then — for high
# quality loot — one eviction of lower quality loot to open the room it needs.
func store_into(p: Dictionary, name: String, entry: Dictionary, may_evict: bool = false) -> bool:
	var target: Dictionary=p.get(name,{})
	if target.is_empty():
		return false
	var plan := Catalog.place_arrival(target,entry)
	if not bool(plan.ok):
		if may_evict:
			return demote(p,name,entry)
		return false
	var items: Array=Catalog.container_items(target)
	if not plan.items.is_empty():
		Catalog.commit_layout(items,plan.items)
	items.append(plan.seat)
	target["items"]=items
	target["next"]=maxi(int(target.get("next",1)),1)+1
	Catalog.compact_arrivals(target)
	return true

# Making room by hand. A container that is packed solid cannot be tidied into
# having room: items have to leave, and how many is a question only the geometry
# can answer — four single cells do not open a 2x2 hole, because a full 4x4 grid
# minus four cells is still a shape with no 2x2 room in it. So the lowest quality
# item steps out, the arrival is retried, and that repeats until it fits or the
# container runs out of items it is allowed to touch. The candidate list is taken
# once, up front, so an item that arrived during this tidy can never be evicted
# by it. Each departure is handed to the backpack, or to the floor when even the
# backpack is full; if it cannot be parked anywhere the whole attempt is rolled
# back, so a click that cannot be satisfied looks like it did nothing at all and
# never quietly destroys loot.
func demote(p: Dictionary, name: String, entry: Dictionary) -> bool:
	var container: Dictionary=p.get(name,{})
	if container.is_empty():
		return false
	var haul: Array=Catalog.container_items(container).duplicate(true)
	var bag: Dictionary=p.get("backpack",{})
	var bag_before: Array=Catalog.container_items(bag).duplicate(true)
	# The layout is worked out on a hypothetical copy, so the container itself is
	# only touched once an arrangement is known to hold and every item it displaced
	# has somewhere to go. Opening a 2x2 hole can take several departures, so the
	# hypothetical haul keeps what earlier steps already gave up and the arrival is
	# retried after each one.
	var left: Array=haul.duplicate(true)
	var taken: Array = []
	for candidate in Catalog.eviction_order(container,entry):
		var cut: Dictionary=take_from(left,candidate)
		if cut.is_empty():
			continue
		taken.append(cut)
		var trial := Catalog.make_container([],Catalog.container_grid(container))
		trial["items"]=left.duplicate()
		var plan := Catalog.place_arrival(trial,entry)
		if not bool(plan.ok):
			continue
		if not demote_park(p,taken):
			break
		# Apply the trial's packed layout before inserting the arrival; otherwise
		# the new seat can overlap an item still at its old coordinates.
		var seated: Array=Catalog.container_items(trial)
		if not plan.items.is_empty():
			Catalog.commit_layout(seated,plan.items)
		seated.append(plan.seat)
		container["items"]=seated
		Catalog.compact_arrivals(container)
		return true
	container["items"]=haul
	Catalog.restore_layout(bag,bag_before)
	return false

# Lifts the lowest-quality matching unit chosen by eviction_order, rather than
# another weapon or pack of the same kind that happens to appear first.
func take_from(left: Array, candidate: Dictionary) -> Dictionary:
	for i in left.size():
		var victim: Dictionary=left[i]
		var kind := str(victim.kind)
		if kind!=str(candidate.kind) or Catalog.item_tier(victim)!=int(candidate.tier) or Catalog.item_value(victim)!=int(candidate.value):
			continue
		var move: Dictionary=victim.duplicate()
		if int(victim.get("count",1))>1 and Catalog.stacks(kind):
			victim["count"]=int(victim.get("count",1))-1
			move["count"]=1
		else:
			left.remove_at(i)
		return move
	return {}

# Hands every item a tidy displaced to the backpack, or to the floor when the bag
# is full. The bag is put back when any one of them cannot be parked, so a tidy
# that is abandoned never cost the player an item.
func demote_park(p: Dictionary, moves: Array) -> bool:
	var bag: Dictionary=p.get("backpack",{})
	var bag_before: Array=Catalog.container_items(bag).duplicate(true)
	for move in moves:
		if not demote_move(p,move):
			Catalog.restore_layout(bag,bag_before)
			return false
	return true

# Lifts one unit of the named kind out of a container and returns it as a
# standalone item. A stack gives up a single unit rather than the whole pile, so
# a tidy never throws away more than the room it actually needs.
func take_one(container: Dictionary, kind: String) -> Dictionary:
	var list: Array=Catalog.container_items(container)
	for i in list.size():
		if str(list[i].kind)!=kind:
			continue
		var victim: Dictionary=list[i]
		var move: Dictionary=victim.duplicate()
		if int(victim.get("count",1))>1 and Catalog.stacks(kind):
			victim["count"]=int(victim.get("count",1))-1
			move["count"]=1
		else:
			list.remove_at(i)
		return move
	return {}

# Where an evicted item ends up: the backpack first, because losing loot on the
# floor is the last thing a tidy should ever do.
func demote_move(p: Dictionary, move: Dictionary) -> bool:
	var bag: Dictionary=p.get("backpack",{})
	if not bag.is_empty():
		var plan := Catalog.place_arrival(bag,move)
		if bool(plan.ok):
			var items: Array=Catalog.container_items(bag)
			if not plan.items.is_empty():
				Catalog.commit_layout(items,plan.items)
			items.append(plan.seat)
			bag["items"]=items
			bag["next"]=maxi(int(bag.get("next",1)),1)+1
			Catalog.compact_arrivals(bag)
			return true
	# Nowhere to put it but the ground.
	if str(move.kind)=="backpack":
		return drop_item(p,"backpack",-1,str(move.get("quality",Catalog.DEFAULT_BAG_KEY)),move)
	return drop_item(p,"backpack",-1,"",move)

func remove_units(container: Dictionary, index: int, units: int) -> void:
	var list: Array=Catalog.container_items(container)
	if index<0 or index>=list.size():
		return
	var kind := str(list[index].kind)
	var have := int(list[index].get("count",1)) if Catalog.stacks(kind) else 1
	if have>units:
		list[index]["count"]=have-units
	else:
		list.remove_at(index)
	container["searched"]=searched_units(container)-units
	Catalog.tidy(container)

# White, green, blue, purple, gold and red weights per 1,000 quality rolls.
# Every cache can surprise with a high tier; danger raises its likelihood.
const CACHE_QUALITY_WEIGHTS := [
	[620,260,80,30,8,2],
	[245,480,210,50,12,3],
	[65,260,450,180,38,7],
	[15,75,260,450,175,25],
	[5,20,80,260,545,90],
]
const CACHE_BACKPACK_CHANCE := [0.18,0.23,0.28,0.32,0.36]
const CACHE_GEAR_CHANCE := [0.20,0.22,0.24,0.26,0.28]
const CACHE_WEAPON_CHANCE := [0.12,0.15,0.18,0.21,0.24]

# Chests hold supplies and valuables, and now and then a better backpack or a
# piece of field equipment. The optional backpack override is kept for callers
# that explicitly construct a loot table; map caches use the grade table.
func chest_loot(bonus_relic: bool = false, backpack_chance: float = -1.0, cache_tier: int = 0, biome: int = -1) -> Array:
	var grade := clampi(cache_tier,0,CACHE_QUALITY_WEIGHTS.size()-1)
	var kinds: Array = ["scrap","medicine","ammo","charm"]
	var loot: Array = []
	for i in rng.randi_range(2,4):
		loot.append(kinds[rng.randi_range(0,kinds.size()-1)])
	if bonus_relic or rng.randf()<0.2:
		loot.append("relic")
	if biome>=0 and biome<Catalog.BIOME_COLLECTIBLES.size():
		var local_collectibles: Array=Catalog.biome_collectible_set(biome)
		loot.append(local_collectibles[rng.randi_range(0,local_collectibles.size()-1)])
	# Insert rolled equipment first so a full 4x4 cache never silently discards
	# a rare weapon after filling its cells with ordinary supplies.
	var bag_chance: float = float(CACHE_BACKPACK_CHANCE[grade]) if backpack_chance<0 else backpack_chance
	if rng.randf()<bag_chance:
		loot.push_front({"kind":"backpack","key":Catalog.BAG_TIERS[roll_chest_quality(grade)].key})
	if rng.randf()<CACHE_GEAR_CHANCE[grade]:
		loot.push_front(Catalog.make_equipment("gear",rng.randi_range(0,Catalog.GEAR.size()-1),roll_chest_quality(grade)))
	if rng.randf()<CACHE_WEAPON_CHANCE[grade]:
		loot.push_front(Catalog.make_equipment("weapon",Catalog.roll_weapon(rng),roll_chest_quality(grade)))
	return loot

func roll_chest_quality(cache_tier: int) -> int:
	var weights: Array=CACHE_QUALITY_WEIGHTS[clampi(cache_tier,0,CACHE_QUALITY_WEIGHTS.size()-1)]
	var roll := rng.randi_range(0,999)
	for tier in weights.size():
		roll-=int(weights[tier])
		if roll<0: return tier
	return weights.size()-1

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

# What a defeated enemy leaves. A blood crystal is not an item any more: it is a
# tally the player collects by walking over it, so it is handed back as its own
# kind and never reaches a container or a search window.
const CRYSTAL_DROP := "crystals"
# The banished knight always carries the hidden ending's key. It is a trinket,
# not equipment: it rolls no quality, it has no slot, and it is worth exactly
# what the description says.
const AMULET_DROP := "amulet"

func enemy_loot(e: Dictionary) -> Dictionary:
	# The defeated monster owns its reward tier, even after leaving its habitat.
	var difficulty := clampi(int(e.get("difficulty",1)),1,4)
	var floor_index := difficulty-1
	if int(e.type)>=14: floor_index=mini(4,difficulty)
	if int(e.type)==4 and not e.get("amulet_dropped",false):
		e["amulet_dropped"]=true
		return {"kind":AMULET_DROP}
	# Blood crystals are a walk-over tally now, not an item: a drop of them is
	# handed back as its own kind and never reaches a container or a search window.
	var entry := {"kind":"ammo" if rng.randf()<0.35 else CRYSTAL_DROP}
	if e.type==3:
		# The blood-scented hunter always leaves its pack behind, and often the
		# weapon it was carrying.
		if rng.randf()<0.45:
			entry=Catalog.make_equipment("weapon",Catalog.roll_weapon(rng),roll_quality(maxi(1,floor_index)))
		else:
			entry["kind"]="backpack"
			entry["key"]=backpack_drop(maxi(1,floor_index))
	else:
		var roll := rng.randf()
		var weapon_chance := 0.08+0.04*(difficulty-1)
		var gear_chance := 0.12+0.03*(difficulty-1)
		if int(e.type)>=14:
			weapon_chance=0.40
			gear_chance=0.35
		if roll<weapon_chance:
			entry=Catalog.make_equipment("weapon",Catalog.roll_weapon(rng),roll_quality(floor_index))
		elif roll<weapon_chance+gear_chance:
			entry=Catalog.make_equipment("gear",rng.randi_range(0,Catalog.GEAR.size()-1),roll_quality(floor_index))
		elif roll<weapon_chance+gear_chance+0.30:
			entry["kind"]="relic"
		elif roll<weapon_chance+gear_chance+0.47 and map_id=="border":
			var habitat := int(e.get("habitat",-1))
			var biome := int(ruins.sites[habitat].biome) if habitat>=0 and habitat<ruins.sites.size() else ruins.biome_at(e.get("p",Ruins.SPAWN))
			var local_collectibles: Array=Catalog.biome_collectible_set(biome)
			entry["kind"]=local_collectibles[rng.randi_range(0,local_collectibles.size()-1)]
	return entry

# A crystal the player is standing on is simply absorbed: no key, no container and
# no cell. The walk-over radius is deliberately small so it never races the F key
# for a chest, and it only ever affects drops that hold nothing but crystals, so a
# player who wants to keep them uncollected can still step around them.
const CRYSTAL_REACH := 46.0

func auto_pickup_crystals(p: Dictionary) -> int:
	if p.get("status","")!="active":
		return 0
	var gathered := 0
	for i in range(world_drops.size()-1,-1,-1):
		var bag: Dictionary=world_drops[i]
		var units := int(bag.get("crystals",0))
		if units<=0 or not Catalog.container_items(bag).is_empty():
			continue
		if p.p.distance_to(bag.p)>=CRYSTAL_REACH:
			continue
		add_crystals(p,units)
		gathered+=units
		world_drops.remove_at(i)
	if gathered>0:
		emit_effect("loot",p.p)
	return gathered


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
	players[id].ready=true if id==leader_id else bool(config.get("ready",false))
	push_lobby()

func push_lobby() -> void:
	changed.emit()
	if online:
		lobby.rpc(players,leader_id,selected_mode)

@rpc("authority","call_remote","reliable")
func lobby(value: Dictionary, leader: int = 1, mode: String = "expedition") -> void:
	connect_deadline=0
	leader_id=leader
	selected_mode=mode
	players=value
	running=false
	changed.emit()

func _peer_left(id: int) -> void:
	if not authority():
		return
	inputs.erase(id)
	for digest in p2p_ticket_peers.keys():
		if p2p_ticket_peers[digest]==id: p2p_ticket_peers.erase(digest)
	for user in account_peers.keys():
		if account_peers[user]==id: account_peers.erase(user)
	if dedicated and id==leader_id:
		leader_id=0
		for candidate in players:
			if candidate!=id and players[candidate].connected:
				leader_id=candidate
				players[candidate].ready=true
				break
	pending_ultimates.erase(id)
	if running and players.has(id):
		players[id].connected=false
		if players[id].status in ["active","down"]:
			players[id].status="dead"
		message.emit("一位守夜人断开连接。")
		if dedicated: leader_changed.rpc(leader_id)
	else:
		players.erase(id)
		push_lobby()

@rpc("authority","call_remote","reliable")
func leader_changed(value: int) -> void:
	leader_id=value

func launch(_long_run: bool = false, fixed_seed: int = 0) -> bool:
	if running or not authority() or players.is_empty():
		return false
	var mode: String=selected_mode
	for p in players.values():
		if not p.ready or str(p.get("mode","expedition"))!=mode:
			message.emit("等待所有队友准备完毕。")
			return false
	seed_value=fixed_seed if fixed_seed!=0 else randi_range(1,9999999)
	# Retain the legacy argument for callers; every exploration day is five minutes.
	duration=DAY_DURATION
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
	begin(seed_value,duration,players,mode)
	if online:
		begin.rpc(seed_value,duration,players,mode)
	if roguelike.active(self): return true
	for site in ruins.sites:
		for j in (4 if site.tier==2 else 2):
			spawn_enemy(site.p+Vector2(-120+j*80,-40),Ecology.POOLS[int(site.biome)][j%Ecology.POOLS[int(site.biome)].size()])
	return true

@rpc("authority","call_remote","reliable")
func begin(value: int, seconds: float, roster: Dictionary, mode: String = "expedition") -> void:
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
	soul_reaps.clear()
	fire_zones.clear()
	objectives=0
	elapsed=0.0
	threat=0.0
	spawn_timer=8.0
	sync_timer=0.0
	next_enemy=0
	report_paid=false
	running=true
	selected_mode=mode
	if mode=="roguelike":
		roguelike.reset(self)
	else:
		expedition.reset(self)
	started.emit()

func _physics_process(delta: float) -> void:
	if connect_deadline>0 and Time.get_ticks_msec()>connect_deadline:
		var p2p := p2p_attempt
		var direct := not server_room and not p2p
		disconnect_room()
		if p2p: p2p_connect_failed.emit()
		else:
			message.emit("连接房间超时，请检查地址和 UDP 端口。")
			if direct: direct_connect_failed.emit()
	if not running:
		return
	input_timer-=delta
	if input_timer<=0:
		input_timer=1.0/30.0
		if authority() and not dedicated:
			inputs[my_id()]=local_input.duplicate()
		elif not authority():
			input_packet.rpc_id(1,local_input)
	if not authority():
		return
	simulate(delta)
	sync_timer-=delta
	if online and sync_timer<=0:
		sync_timer+=0.1
		if roguelike.active(self):
			raid["visual_effects"]=roguelike.combat.effects
			raid["visual_missiles"]=roguelike.combat.missiles
		var packet := var_to_bytes([players,enemies,bullets,world_drops,ruins.chests,ruins.shrines,elapsed,objectives,threat,results,map_id,raid,ruins.sites])
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
	inputs[id]={"move":packet.move.limit_length(1),"aim":packet.aim.normalized(),"fire":bool(packet.get("fire",false)),"interact":bool(packet.get("interact",false)),"sprint":bool(packet.get("sprint",false)),"flask_held":bool(packet.get("flask_held",false))}
	if packet.get("aim_point") is Vector2 and packet.aim_point.is_finite(): inputs[id]["aim_point"]=packet.aim_point

@rpc("authority","call_remote","reliable",2)
func snapshot(packet: PackedByteArray) -> void:
	if not running:
		return
	var data = bytes_to_var(packet.decompress_dynamic(2097152,FileAccess.COMPRESSION_GZIP))
	if not data is Array or data.size() not in [12,13]:
		return
	var next_raid: Dictionary=data[11]
	var rogue: bool=next_raid.get("mode","")=="roguelike"
	var rebuild: bool=map_id!=str(data[10]) or (rogue and (raid.get("floor",0)!=next_raid.get("floor",0) or raid.get("area",0)!=next_raid.get("area",0)))
	if rebuild:
		map_id=str(data[10])
		if rogue:
			ruins=preload("res://scripts/rogue_map.gd").new()
			ruins.generate(seed_value+int(next_raid.floor)*100+int(next_raid.area))
			ruins.configure(int(next_raid.floor)-1,int(next_raid.area),next_raid.room not in ["shop","treasure","talent","curse","event","forge","gamble","mirror"],str(next_raid.room))
		else:
			ruins=RoyalCity.new() if map_id=="city" else Ruins.new()
			ruins.generate(seed_value)
		map_changed.emit()
	if rogue:
		roguelike.combat.effects=next_raid.get("visual_effects",[])
		roguelike.combat.missiles=next_raid.get("visual_missiles",[])
	players=data[0]
	enemies=data[1]
	bullets=data[2]
	world_drops=data[3]
	ruins.chests=data[4]
	ruins.shrines=data[5]
	if data.size()==13: ruins.sites=data[12]
	elapsed=data[6]
	objectives=data[7]
	threat=data[8]
	raid=data[11]
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
	if roguelike.active(self) and kind.begins_with("rogue_"):
		roguelike.choose(self,p,kind,payload)
		return
	# Run equipment is managed by rewards; campaign storage actions do not apply.
	if roguelike.active(self) and kind in ["bag_move","bag_rotate","use","equip","unequip","unequip_stow","unwear_bag","equip_bag","bag_swap","slot_put","slot_take","slot_drop","slot_apply","search","pickup","loot_take","loot_drop","auto_store","drop","bag_drop","move_to"]: return
	if kind=="raid_choice":
		expedition.choose(self,id,str(payload.get("choice","")))
		return
	if roguelike.active(self):
		if kind=="break_combo": p.build_inputs=[]; return
		if kind=="heal":
			RogueBuild.drink(self,p)
			return
		if kind=="jump":
			RogueBuild.jump(self,p)
			return
		if kind=="attack":
			p["build_attack_edge"]=true
			p["build_attack_edge_until"]=elapsed+.20
			attack(p)
			return
		if p.flask_time>0:
			if kind=="dash": p.flask_time=0.0; p["flask_pending_commit"]=false
			else: return
		if kind=="skill" and p.height>0:
			if p.height_velocity<0 and p.height<=35: p["build_pending_action"]={"kind":kind,"expires":elapsed+.15}
			return
		if kind in ["skill","weapon_art"] and p.cast_time>0:
			if not p.has("build_pending_art") and p.cast_time<=.2: p["build_pending_action"]={"kind":kind,"expires":elapsed+.2}
			return
		if kind in ["skill","weapon_art"] and p.swing_time>0:
			if not p.pending_strike and maxf(p.swing_time,p.attack)<=.2: p["build_pending_action"]={"kind":kind,"expires":elapsed+.2}
			return
	if pending_ultimates.has(id):
		if roguelike.active(self) and kind=="dash": cancel_ultimate(id); p.cast_time=0.0
		else: return
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
	if p.dodge_time>0 and kind in ["skill","weapon_art","reload"]:
		return
	match kind:
		"weapon_art": release_weapon_art(p)
		"reload": reload_player(p)
		"dash":
			if p.dash<=0 and (not roguelike.active(self) or p.height<=0 or not p.air_dodge):
				var direction: Vector2=inputs.get(id,{}).get("move",p.aim)
				if direction.length()<0.1:
					direction=p.aim
				if direction.length()<0.1:
					direction=Vector2.RIGHT
				p.dodge_dir=direction.normalized()
				p["attack_buffer"]=0.0
				if not roguelike.active(self) or p.pending_strike: p.combo_timeout=0.0
				p.dodge_time=DODGE_DURATION
				p.motion="dodge"
				p.pending_strike=false
				p.swing_time=0.0
				p.cast_time=0.0
				p.channel=0.0
				p.dash=2.0
				p.invuln=maxf(p.invuln,.18 if roguelike.active(self) else .4)
				if roguelike.active(self):
					if p.height>0:
						p.air_dodge=true; p.dodge_time=.18; p.invuln=.08
					p.dash=2.0*(1.0-RogueBuild.stat(self,p,"dodge_cdr"))
					RogueBuild.action_event(self,p,"D")
				broadcast_combat({"kind":"dodge","p":p.p,"aim":p.dodge_dir,"id":id})
				emit_effect("dash",p.p)
		"skill":
			if p.skill<=0:
				if not spend_mana(p,RogueBuild.mana_cost(self,p,ULTIMATE_MANA,"skill") if roguelike.active(self) else ULTIMATE_MANA):
					if id==my_id(): message.emit("蓝量不足：奥义需要 30 蓝量。")
					return
				p["attack_buffer"]=0.0
				p.combo_timeout=0.0
				p.skill=18.0
				# A2 (R9 hook 8): CU09「迟滞」的 `cooldown` 同样作用在奥义冷却上（与武器技的
				# `p.art_cd`、连招技的 `p.build_hero_cd` 是同一份诅咒的三个消费点）。
				# 非魔境路径不读该键，保持 18.0 原值。
				if roguelike.active(self): p.skill*=1.0+maxf(0.0,RogueBuild.hook_mod(self,p,"cooldown"))
				if roguelike.active(self):
					RogueBuild.action_event(self,p,"U")
					p["build_skill_context"]=RogueBuild.context(self,p,"skill")
				p.pending_strike=false
				p.swing_time=0.0
				p.reload=0.0
				p.channel=0.0
				var seconds := ONLINE_ULTIMATE_DURATION
				if not online:
					seconds=ultimate_seconds(p)
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
			equip_item(p,str(payload.get("slot","backpack")),int(payload.get("index",-1)),int(payload.get("charm_slot",-1)))
		"unequip":
			unequip_item(p,str(payload.get("type","weapon")),int(payload.get("index",0)))
		"unequip_stow":
			# The take-off gestures (double tap on a socket, Ctrl+left, F): the item
			# goes to the backpack, and the pocket only for gold and above.
			unequip_stow(p,str(payload.get("type","weapon")),int(payload.get("index",0)))
		"worn_equip":
			# A worn piece dragged onto another socket: the two change places.
			swap_sockets(p,worn_zone_name(str(payload.get("wtype","weapon")),int(payload.get("windex",0))),str(payload.get("zone","")))
		"worn_drop":
			# A worn piece dragged into the backpack, the pocket or a searched chest.
			move_worn_to(p,str(payload.get("wtype","weapon")),int(payload.get("windex",0)),str(payload.get("to","backpack")),Vector2i(int(payload.get("x",0)),int(payload.get("y",0))),bool(payload.get("rot",false)))
		"worn_to_world":
			# A worn piece dragged out of the panel: the player asked for it to go.
			drop_worn(p,str(payload.get("wtype","weapon")),int(payload.get("windex",0)))
		"carry_drop":
			# Part of a pile into another carried container: the right-click hand's
			# landing. The camp's vault has its own pair in `camp_storage.gd`.
			move_units(p,str(payload.get("from","backpack")),str(payload.get("to","backpack")),int(payload.get("index",-1)),int(payload.get("units",1)),Vector2i(int(payload.get("x",0)),int(payload.get("y",0))),bool(payload.get("rot",false)))
		"carry_unit":
			# One left click of the right-button hand: a single aimed unit into another
			# carried container, the source trimmed only by what actually landed.
			carry_unit(p,str(payload.get("from","backpack")),int(payload.get("index",-1)),str(payload.get("to","backpack")),int(payload.get("units",1)),Vector2i(int(payload.get("x",0)),int(payload.get("y",0))),bool(payload.get("rot",false)))
		"carry_finish":
			# The right button coming up: whatever is left in the hand, into the aimed
			# container first, then back where it came from, then onto the ground.
			carry_finish_units(p,str(payload.get("from","backpack")),int(payload.get("index",-1)),str(payload.get("to","")),int(payload.get("units",1)),Vector2i(int(payload.get("x",0)),int(payload.get("y",0))),bool(payload.get("rot",false)))
		"carry_ground":
			# Part of a pile dropped on the ground.
			var handful := take_units(p,str(payload.get("from","backpack")),int(payload.get("index",-1)),int(payload.get("units",1)))
			if not handful.is_empty():
				ground_place(p,handful)
		"unwear_bag":
			wear_spare(p)
		"equip_bag":
			equip_bag(p,str(payload.get("slot","backpack")),int(payload.get("index",-1)))
		"bag_swap":
			var selected := int(payload.get("index",-1))
			if selected>=0 and selected<p.bags.size():
				if not Catalog.swap_bags(p,selected):
					message.emit("背包空间不足：先腾空当前背包内的物资。")
		"slot_put":
			# A drag from a container into one of the three item sockets.
			slot_put(p,int(payload.get("slot",0)),str(payload.get("from","backpack")),int(payload.get("index",-1)))
		"slot_take":
			# The way back out: the socket's item returns to the backpack, or to
			# the pocket when the bag has no room for it.
			slot_take(p,int(payload.get("slot",0)))
		"slot_drop":
			drop_item_slot(p,int(payload.get("slot",0)))
		"slot_apply":
			# The item bar's one key: spend a supply, or swap a weapon, a piece of
			# gear or a backpack with what the Watcher is using right now.
			slot_use(p,int(payload.get("slot",0)))
		"search":
			begin_search(p,int(payload.get("index",-1)))
		"pickup":
			pick_up_ground(p)
		"loot_take":
			take_loot(p,str(payload.get("ref","")).to_int(),int(payload.get("index",-1)))
		"loot_drop":
			drop_searched_loot(p,int(payload.get("index",-1)))
		"auto_store":
			# The silent twin of loot_take: a refusal says nothing at all.
			auto_store(p,int(payload.get("index",-1)))
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
		if Catalog.stacks(kind):
			# Keep the chest's stack cap and allow a partial handoff when only a
			# partly filled stack can accept this pile.
			var units := int(list[index].get("count",1))
			var moved := 0
			for i in units:
				var before_size: int=target.items.size()
				if not Catalog.place_loot(target,kind):
					break
				if target.items.size()>before_size:
					# A fresh returned stack belongs at the revealed front of a
					# partly searched chest, ahead of its still hidden contents.
					target.items.push_front(target.items.pop_back())
				moved+=1
			if moved<=0:
				return false
			if moved>=units:
				list.remove_at(index)
			else:
				list[index]["count"]=units-moved
			target["searched"]=searched_units(target)+moved
			return true
		var probe: Dictionary=list[index].duplicate()
		probe["rot"]=rot
		var plan := Catalog.place_arrival(target,probe)
		if not bool(plan.ok):
			return false
		if not plan.items.is_empty():
			Catalog.commit_layout(target.items,plan.items)
		# A returned item stays visible even while the rest of the chest is still
		# sealed, without revealing any of those hidden items for free.
		target.items.insert(0,plan.seat)
		target["searched"]=searched_units(target)+(int(probe.get("count",1)) if Catalog.stacks(str(probe.kind)) else 1)
		list.remove_at(index)
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
		Catalog.compact_arrivals(dest)
	return true

## Moves `units` of a pile between two carried containers, aimed at a cell: the same
## arrival rule as `move_between()`, but the hand holds **part of a pile** rather than a
## whole entry. All or nothing: the destination is asked first and the source pile is
## only trimmed once the arrival is known to work, so a refusal cannot eat units.
func move_units(p: Dictionary, from: String, to: String, index: int, units: int, spot: Vector2i, rot: bool) -> bool:
	if from==to or from=="loot":
		return false
	if to!="backpack" and to!="pocket":
		return false
	var source: Dictionary=p.get(from,{})
	var dest: Dictionary=p.get(to,{})
	if source.is_empty() or dest.is_empty():
		return false
	var from_list: Array=Catalog.container_items(source)
	if index<0 or index>=from_list.size():
		return false
	var have := int(from_list[index].get("count",1))
	if units<=0 or have<=1 or not Catalog.stacks(str(from_list[index].kind)):
		return false
	units=mini(units,have)
	var pile: Dictionary=from_list[index].duplicate(true)
	pile["count"]=units
	pile["rot"]=rot
	var at := resolve_drop(Catalog.container_items(dest),Catalog.container_grid(dest),pile,spot)
	if at.x<0:
		return false
	pile["x"]=at.x
	pile["y"]=at.y
	Catalog.container_items(dest).append(pile)
	Catalog.compact_arrivals(dest)
	if units>=have:
		from_list.remove_at(index)
	else:
		from_list[index]["count"]=have-units
	return true

## Takes `units` off a pile in a carried container and hands them back as their own
## entry, trimming the source in place. The ground drop of a handful uses this.
func take_units(p: Dictionary, slot: String, index: int, units: int) -> Dictionary:
	if slot!="backpack" and slot!="pocket":
		return {}
	var list: Array=Catalog.container_items(p.get(slot,{}))
	if index<0 or index>=list.size():
		return {}
	if not Catalog.stacks(str(list[index].kind)):
		return {}
	var have := int(list[index].get("count",1))
	units=mini(units,have)
	if units<=0:
		return {}
	var pile: Dictionary=list[index].duplicate(true)
	pile["count"]=units
	if units>=have:
		list.remove_at(index)
	else:
		list[index]["count"]=have-units
	return pile

## Lifts `units` (capped at what the pile holds) off a carried pile and hands them back
## as their own entry, trimming the source in place. Unlike `take_units()` this also
## accepts a non-stackable piece — a single item is just a pile whose ceiling is 1 —
## because the right-button hand carries whole pieces as well as stacks.
func take_some(p: Dictionary, slot: String, index: int, units: int) -> Dictionary:
	if slot!="backpack" and slot!="pocket":
		return {}
	var list: Array=Catalog.container_items(p.get(slot,{}))
	if index<0 or index>=list.size():
		return {}
	if not list[index] is Dictionary:
		return {}
	if not Catalog.stacks(str(list[index].kind)):
		units=1
	var have := int(list[index].get("count",1))
	units=mini(units,have)
	if units<=0:
		return {}
	var pile: Dictionary=list[index].duplicate(true)
	pile["count"]=units
	if units>=have:
		list.remove_at(index)
	else:
		list[index]["count"]=have-units
	return pile

## Puts `units` of `kind` into a carried container, aimed at `cell`.
##
## The aimed cell is asked first and answered exactly: a same-kind pile with room
## standing on that cell grows, an empty cell starts a new pile there. Only when the
## aim cannot take the unit does the search widen — nearest free cell first, then any
## same-kind pile with room — which is what makes one left-click of the right-button
## hand land somewhere sensible instead of doing nothing.
##
## Deliberately **no** `compact_arrivals()`: repacking the grid straight after an aimed
## unit would move the very cell the player just aimed at. That is the whole promise of
## the hand's "locked" cell — what it placed stays put until the gesture ends.
##
## Returns {"placed":units_that_fit,"cell":first_cell_used(-1,-1 when nothing fit)}.
func place_units(p: Dictionary, slot: String, kind: String, units: int, cell: Vector2i, blank: Dictionary, rot: bool) -> Dictionary:
	var result := {"placed":0,"cell":Vector2i(-1,-1)}
	if (slot!="backpack" and slot!="pocket") or units<=0:
		return result
	var container: Dictionary=p.get(slot,{})
	if container.is_empty() or not Catalog.can_hold(container,kind):
		return result
	# The landing rule itself is `Catalog.place_units_in()`: a carried container and
	# the camp's vault have to drop a single aimed unit in exactly the same way.
	return Catalog.place_units_in(container,kind,units,cell,blank,rot)

## One left click of the right-button hand in a raid: `units` of a pile into `to`, aimed at
## `spot`. The source is trimmed only by the units that really landed, so a refused click is
## a free no-op instead of a lost unit. Returns how many units moved.
func carry_unit(p: Dictionary, from: String, index: int, to: String, units: int, spot: Vector2i, rot: bool) -> int:
	var list: Array=Catalog.container_items(p.get(from,{}))
	if index<0 or index>=list.size(): return 0
	if not list[index] is Dictionary: return 0
	var kind := str(list[index].kind)
	var blank: Dictionary=Catalog.clean_slot_entry(list[index])
	if blank.is_empty(): return 0
	var wanted := mini(units,int(list[index].get("count",1)))
	if wanted<=0: return 0
	var placed := int(place_units(p,to,kind,wanted,spot,blank,rot).placed)
	if placed>0:
		take_some(p,from,index,placed)
	return placed

## The right button coming up in a raid: seat as much of the hand as the aimed container
## will take, and leave the rest exactly where it is. Because the source is only trimmed by
## the units that already landed, an unseated unit never left its pile — so "put it back" is
## free, identical to doing nothing, and no unit can be destroyed here. Returns how many
## units really moved to a different container (0 = the pile is back where it started).
func carry_finish_units(p: Dictionary, from: String, index: int, to: String, units: int, spot: Vector2i, rot: bool) -> int:
	var list: Array=Catalog.container_items(p.get(from,{}))
	if index<0 or index>=list.size(): return 0
	if not list[index] is Dictionary: return 0
	var kind := str(list[index].kind)
	var blank: Dictionary=Catalog.clean_slot_entry(list[index])
	if blank.is_empty(): return 0
	var wanted := mini(units,int(list[index].get("count",1)))
	if wanted<=0: return 0
	if to.is_empty() or to==from:
		return 0
	var placed := int(place_units(p,to,kind,wanted,spot,blank,rot).placed)
	if placed>0:
		take_some(p,from,index,placed)
	return placed

# Where an item actually lands when dropped at a cell. The cursor is only a
# pointer: the item goes to the cell under it when that fits, otherwise to the
# nearest free cell, and only gives up when nothing is free. The drag preview
# calls this too, so the shown slot is always the slot that gets used. The search
# itself lives in `Catalog.nearest_fit()` so the single-unit placement shares it.
func resolve_drop(items: Array, grid: Vector2i, entry: Dictionary, at: Vector2i, skip: int = -1) -> Vector2i:
	return Catalog.nearest_fit(items,grid,entry,at,skip)

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
	# The plain flip first: while the turned piece still fits where it stands, nothing
	# else on the grid moves.
	if move_between(p,slot,slot,index,Vector2i(int(item.x),int(item.y)),not bool(item.get("rot",false))):
		return true
	return rotate_with_displacement(p,slot,index)

## A flip that no longer fits: the grid is repacked around the turned piece and what is
## in its way is pushed out — the other carried container first, then a free bar socket,
## then the ground — because a rotation the player asked for has to land. The turned
## piece is seated first by `tidy_around()`, so it is never the one pushed out; the
## ground takes whatever the containers cannot, so nothing is lost on either side.
func rotate_with_displacement(p: Dictionary, slot: String, index: int) -> bool:
	var list: Array=Catalog.container_items(p.get(slot,{}))
	if index<0 or index>=list.size():
		return false
	var focus: Dictionary=list[index].duplicate(true)
	focus["rot"]=not bool(focus.get("rot",false))
	var other := "pocket" if slot=="backpack" else "backpack"
	list.remove_at(index)
	var spill: Array=Catalog.tidy_around(p[slot],focus)
	for entry in spill:
		if container_receive(p,other,entry):
			continue
		if slot_receive(p,entry):
			continue
		ground_place(p,entry)
	message.emit(Catalog.item_name(focus)+" 已转向，挡住的东西让开了位置。")
	return true

## Puts an entry into the first free bar socket. The bar takes any kind, which is what
## makes it the middle stop between a container and the ground.
func slot_receive(p: Dictionary, entry: Dictionary) -> bool:
	for i in ITEM_SLOT_COUNT:
		if item_slot(p,i).is_empty():
			set_item_slot(p,i,entry)
			return true
	return false

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

# One entry point for using a selected inventory item. The medkit runs the same
# effect as the heal path; a backpack, weapon or gear piece goes to its own equip
# path. A blood crystal cannot be used — it is a tally, not an item — so one that
# is still sitting in an older save stays exactly where it is. Consuming removes
# exactly the clicked entry, so a stack of supplies never eats the wrong slot.
func use_item(p: Dictionary, slot: String, index: int) -> bool:
	if slot!="backpack" and slot!="pocket":
		return false
	var list: Array=Catalog.container_items(p[slot])
	if index<0 or index>=list.size():
		return false
	var kind := str(list[index].kind)
	if kind=="backpack":
		return equip_bag(p,slot,index)
	if Catalog.is_wearable(kind):
		return equip_item(p,slot,index)
	if not consume_kind(kind):
		message.emit(Catalog.item_name(list[index])+"无法直接使用。")
		return false
	if not can_consume(p,kind):
		return false
	list.remove_at(index)
	return apply_consumable(p,kind)

# The two kinds that are spent rather than worn or carried home.
func consume_kind(kind: String) -> bool:
	return kind=="medicine" or kind=="ammo"

# Whether spending one of these would actually do anything. A refusal explains
# itself, because the player pressed a key and deserves to know why nothing
# happened; the item stays where it is.
func can_consume(p: Dictionary, kind: String) -> bool:
	if kind=="medicine":
		if p.status=="down" and not p.self_revive:
			message.emit("本局的自救机会已经用过了。")
			return false
		if p.hp>=p.max_hp:
			message.emit("生命已满，急救针留着。")
			return false
		return true
	if kind=="ammo":
		return true
	return false

# The effect of one consumed supply, shared by the backpack, the pocket and the
# item bar so all three spend a medkit exactly the same way.
func apply_consumable(p: Dictionary, kind: String) -> bool:
	if kind=="medicine":
		apply_medkit(p)
		broadcast_audio("heal",p)
		return true
	if kind=="ammo":
		p.reserve+=48
		emit_effect("loot",p.p)
		return true
	return false

# --- the item bar -----------------------------------------------------------
# Three sockets that hold anything at all, however many cells it would need in a
# backpack, and operate on one key: a medkit is spent, a weapon or a backpack
# changes places with whatever the Watcher is using right now. A refusal is
# silent and returns false, which is what lets the same key fall through to the
# other jobs it has.
func slot_use(p: Dictionary, index: int) -> bool:
	var entry := item_slot(p,index)
	if entry.is_empty():
		return false
	if not Catalog.slot_operable(str(entry.kind)):
		return false
	var kind := str(entry.kind)
	if consume_kind(kind):
		if not can_consume(p,kind):
			return false
		set_item_slot(p,index,{})
		return apply_consumable(p,kind)
	if kind=="backpack":
		return slot_wear_bag(p,index)
	return slot_wear_gear(p,index)

# The pure item movement behind every socket interaction: put the item in slot
# "index", hand whatever was there to the "from" container, and answer true only
# when both halves worked out. The socket is only rewritten once the arrival is
# known to fit, so a refusal leaves the bar exactly as it was.
func place_in_slot(p: Dictionary, index: int, from: String, from_index: int, arrived: Dictionary) -> bool:
	if from!="backpack" and from!="pocket":
		return false
	if from_index<0:
		return false
	var at := clampi(index,0,ITEM_SLOT_COUNT-1)
	# A socket is not a grid: the coordinates the item was found with would only be
	# stale data here, and the bar reads the footprint from the kind instead.
	var seating := arrival_of(arrived)
	var displaced := item_slot(p,at)
	if not displaced.is_empty():
		if not container_receive(p,from,displaced):
			message.emit("背包与"+Catalog.POCKET_NAME+"都放不下换下来的物品。")
			return false
	set_item_slot(p,at,seating)
	return true

# Wears the weapon in a socket. Whatever was in hand travels into that socket:
# the looted weapon if one is worn, otherwise the hero's temporary issue weapon,
# so the swap is always a real trade rather than a free upgrade.
func slot_wear_gear(p: Dictionary, index: int) -> bool:
	var at := clampi(index,0,ITEM_SLOT_COUNT-1)
	var entry := item_slot(p,at)
	var equipped: Dictionary=p.get("equipped",empty_equipment())
	if not equipped is Dictionary:
		equipped=empty_equipment()
	var kind := str(entry.kind)
	var outgoing: Dictionary={}
	var place := 0
	if kind=="weapon":
		var previous = equipped.get("weapon",{})
		outgoing=previous.duplicate() if previous is Dictionary and not previous.is_empty() else {}
		equipped["weapon"]=arrival_of(entry)
		p["weapon"]=clampi(int(entry.get("weapon",p.weapon)),0,Catalog.WEAPONS.size()-1)
		p["reload"]=0.0
		p["combo"]=0
		p["pending_strike"]=false
	elif kind=="charm":
		equipped["charm"]=charm_slots(equipped)
		var charms: Array=equipped["charm"]
		place=0 if (charms[0] as Dictionary).is_empty() else 1
		var previous_charm = charms[place]
		outgoing=previous_charm.duplicate() if previous_charm is Dictionary and not previous_charm.is_empty() else {}
		charms[place]=arrival_of(entry)
	else:
		equipped["gear"]=gear_slots(equipped)
		place=Catalog.gear_slot(entry)
		var slots: Array=equipped["gear"]
		var previous_gear = slots[place]
		outgoing=previous_gear.duplicate() if previous_gear is Dictionary and not previous_gear.is_empty() else {}
		slots[place]=arrival_of(entry)
	# The socket keeps the item's own fields, including the cells it would take up
	# in a backpack, so the two sides of a swap are always the same kind of object.
	set_item_slot(p,at,outgoing)
	p["equipped"]=equipped
	refresh_max_hp(p)
	if kind=="weapon":
		broadcast_audio("equip",p)
		message.emit("%s 已换上 %s%s。" % [item_slot_name(at),Catalog.item_name(entry),"（临时武器）" if outgoing.is_empty() else "，换下的武器留在道具栏"])
	elif kind=="charm":
		message.emit("%s 已装备 %s（饰品栏 %d）。" % [item_slot_name(at),Catalog.item_name(entry),place+1])
	else:
		message.emit("%s 已换上 %s（%s槽），换下的留在道具栏。" % [item_slot_name(at),Catalog.item_name(entry),Catalog.gear_slot_name(entry)])
	return true

# A spare pack travelling as loot: the same shape store_loot() gives a backpack
# found in a chest, so a socket, a cabinet entry and a container item are three
# representations of one pack rather than three kinds of object.
func bag_as_item(key: String) -> Dictionary:
	return {"kind":"backpack","quality":key,"x":0,"y":0,"rot":false}

# Wears the backpack in a socket. The one on the back becomes a spare in the
# cabinet, exactly like the cabinet's own "equip" button, and the socket then
# holds whatever was worn before — which is the spare pack itself.
func slot_wear_bag(p: Dictionary, index: int) -> bool:
	var at := clampi(index,0,ITEM_SLOT_COUNT-1)
	var entry := item_slot(p,at)
	var key := Catalog.bag_key_of_item(entry)
	var worn := Catalog.bag_key(p.get("backpack",{}))
	var candidate := Catalog.make_bag(key)
	candidate["gw"]=Catalog.bag_grid(candidate).x
	candidate["gh"]=Catalog.bag_grid(candidate).y
	p.bags.append(candidate)
	if not Catalog.swap_bags(p,p.bags.size()-1):
		p.bags.remove_at(p.bags.size()-1)
		message.emit("背包空间不足：先腾空当前背包内的物资。")
		return false
	# The pack that was just swapped out waits in the cabinet: the socket takes it
	# as a loose pack item, which is why the two representations have to match.
	var outgoing := bag_as_item(worn)
	for i in range(p.bags.size()-1,-1,-1):
		if str(p.bags[i].get("key",""))==worn:
			outgoing=bag_as_item(str(p.bags[i].get("key","")))
			p.bags.remove_at(i)
			break
	set_item_slot(p,at,outgoing)
	var tier: Dictionary=Catalog.tier(key)
	message.emit("%s 已换上 %s%s，换下的背包留在道具栏。" % [item_slot_name(at),tier.quality,tier.name])
	return true

# The same item stripped of the grid coordinates it had where it came from: a
# socket is not a grid, so the coordinates would only be stale data.
func arrival_of(entry: Dictionary) -> Dictionary:
	var copy: Dictionary=entry.duplicate()
	for field in ["x","y","rot"]:
		copy.erase(field)
	return copy

# Takes one item out of a socket and into the backpack, or the pocket when the bag
# is full. Returns false when both are full, leaving the bar untouched.
func slot_take(p: Dictionary, index: int) -> bool:
	var entry := item_slot(p,index)
	if entry.is_empty():
		return false
	for name in ["backpack","pocket"]:
		if container_receive(p,name,entry):
			set_item_slot(p,index,{})
			return true
	message.emit("背包与"+Catalog.POCKET_NAME+"都放不下"+Catalog.item_name(entry)+"。")
	return false

# Puts a container item into a socket. One item in, one item out: whatever the
# socket held goes back to the container the new item came from.
func slot_put(p: Dictionary, index: int, from: String, from_index: int) -> bool:
	if from!="backpack" and from!="pocket":
		return false
	var list: Array=Catalog.container_items(p[from])
	if from_index<0 or from_index>=list.size():
		return false
	var entry: Dictionary=list[from_index]
	# A stack leaves one unit behind rather than the whole pile: the bar holds a
	# single item, so a box of five medkits gives up exactly one.
	var units := int(entry.get("count",1))
	var moved: Dictionary=entry.duplicate()
	if units>1 and Catalog.stacks(str(entry.kind)):
		moved["count"]=1
	if not place_in_slot(p,index,from,from_index,moved):
		return false
	if units>1 and Catalog.stacks(str(entry.kind)):
		entry["count"]=units-1
	else:
		list.remove_at(from_index)
	return true

# The one way anything arrives in a container from outside its own grid: a
# seat worked out on a copy first, so "no room" costs nothing.
func container_receive(p: Dictionary, name: String, entry: Dictionary) -> bool:
	if name!="backpack" and name!="pocket":
		return false
	var kind := str(entry.get("kind",""))
	if kind.is_empty() or not Catalog.can_hold(p[name],kind):
		return false
	var container: Dictionary=p[name]
	var trial := Catalog.make_container([],Catalog.container_grid(container))
	trial["items"]=Catalog.container_items(container).duplicate()
	var plan := Catalog.place_arrival(trial,entry)
	if not bool(plan.ok):
		return false
	var items: Array=Catalog.container_items(container)
	if not plan.items.is_empty():
		Catalog.commit_layout(items,plan.items)
	items.append(plan.seat)
	container["items"]=items
	container["next"]=maxi(int(container.get("next",1)),1)+1
	Catalog.compact_arrivals(container)
	return true

## Whether the container could hold the entry *at that cell*: the question a drop
## preview and a vault extraction both need, asked as "would this land here". The
## cell is passed in because a piece still sitting in the vault carries the vault's
## own coordinates, which mean nothing inside a backpack.
func container_accepts(container: Dictionary, entry: Dictionary, cell: Vector2i, rot: bool = false) -> bool:
	var kind := str(entry.get("kind",""))
	if kind.is_empty() or not Catalog.can_hold(container,kind):
		return false
	# A stack merges into its own pile rather than taking the aimed cell, so the
	# only question it asks is whether the container takes that kind at all.
	if Catalog.stacks(kind): return true
	var probe: Dictionary=entry.duplicate(true)
	probe["rot"]=rot
	return Catalog.can_place(Catalog.container_items(container),probe,cell,-1,Catalog.container_grid(container))

# Equipping is the point of the field equipment: the weapon in hand changes at
# once and gear lands in its own slot. Whatever was worn before goes back into
# storage (or onto the ground when everything is full), so a swap never destroys
# an item.
func equip_item(p: Dictionary, slot: String, index: int, charm_slot: int = -1) -> bool:
	if slot!="backpack" and slot!="pocket":
		return false
	var list: Array=Catalog.container_items(p[slot])
	if index<0 or index>=list.size():
		return false
	var kind := str(list[index].kind)
	if not Catalog.is_wearable(kind):
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
	elif kind=="charm":
		equipped["charm"]=charm_slots(equipped)
		var charms: Array=equipped["charm"]
		var charm_index := charm_slot if charm_slot>=0 and charm_slot<2 else (0 if (charms[0] as Dictionary).is_empty() else 1)
		var previous = charms[charm_index]
		if previous is Dictionary:
			old=previous
		charms[charm_index]=entry
	else:
		equipped["gear"]=gear_slots(equipped)
		var slots: Array=equipped["gear"]
		var gear_index: int=Catalog.gear_slot(entry)
		var previous = slots[gear_index]
		if previous is Dictionary:
			old=previous
		slots[gear_index]=entry
	p["equipped"]=equipped
	if kind=="charm" and int(list[index].get("count",1))>1:
		list[index]["count"]=int(list[index].get("count",1))-1
	else:
		list.remove_at(index)
	if not old.is_empty():
		stow_equipment(p,old)
	refresh_max_hp(p)
	if kind=="weapon":
		# Equipping is the one moment a field weapon changes hands, so it is also
		# the cue that replaced the old free weapon switch.
		broadcast_audio("equip",p)
		message.emit("已装备 %s：伤害 +%d%%、攻速 +%d%%。临时武器收起了。" % [Catalog.item_name(entry),int(round(Catalog.weapon_bonus(entry)*100.0)),int(round(Catalog.weapon_rate_bonus(entry)*100.0))])
	elif kind=="charm":
		message.emit("已装备 %s：本局伤害 +12%%。" % Catalog.item_name(entry))
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
	elif type=="charm":
		equipped["charm"]=charm_slots(equipped)
		var charms: Array=equipped["charm"]
		if index<0 or index>=charms.size() or not charms[index] is Dictionary or charms[index].is_empty():
			return false
		entry=charms[index]
		charms[index]={}
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
	# The panel's own take-off keeps its original bargain: the piece comes off and
	# `stow_equipment()` finds it a home — and when there is none it lies on the
	# ground as itself rather than being refused. The *gesture* take-off (double tap
	# / Ctrl+left / F) is the strict one; see README「稀有度与自动收纳判定」.
	stow_equipment(p,entry)
	refresh_max_hp(p)
	var tail := "，换回 %s。" % Catalog.weapon_name(p.weapon) if dropped_weapon else "。"
	message.emit("已卸下 "+Catalog.item_name(entry)+tail)
	return true

# The Ctrl+left take-off. The backpack is tried first because that is where loot
# belongs; when it has no room the pocket is asked to tidy itself once, and when
# even that fails nothing happens at all — the item stays worn rather than being
# thrown on the ground. The socket is only emptied after the item is known to be
# safe in a container, so a refusal can never leave the player half dressed.
# Returns false for that silent refusal.
func unequip_stow(p: Dictionary, type: String, index: int = 0) -> bool:
	var worn := worn_entry(p,type,index)
	if worn.is_empty():
		return false
	if not stow_worn(p,worn):
		return false
	return clear_worn_slot(p,type,index)

# The item currently in a kit slot, or an empty dictionary when the slot is bare.
# The temporary issue weapon is deliberately not a piece of worn loot: it lives in
# p.weapon rather than in the socket, so an empty socket really is empty.
func worn_entry(p: Dictionary, type: String, index: int = 0) -> Dictionary:
	var equipped: Dictionary=p.get("equipped",empty_equipment())
	if not equipped is Dictionary:
		return {}
	if type=="weapon":
		var worn = equipped.get("weapon",{})
		return worn.duplicate() if worn is Dictionary and not worn.is_empty() else {}
	if type=="charm":
		var charms := charm_slots(equipped)
		if index<0 or index>=charms.size():
			return {}
		var worn = charms[index]
		return worn.duplicate() if worn is Dictionary and not worn.is_empty() else {}
	var gear: Array=gear_slots(equipped)
	var piece = gear[clampi(index,0,Catalog.GEAR.size()-1)]
	return piece.duplicate() if piece is Dictionary and not piece.is_empty() else {}

# Empties a kit slot, putting the temporary issue weapon back in hand when the
# looted weapon it replaced comes off.
func clear_worn_slot(p: Dictionary, type: String, index: int = 0) -> bool:
	var equipped: Dictionary=p.get("equipped",empty_equipment())
	if not equipped is Dictionary:
		return false
	if type=="weapon":
		equipped["weapon"]={}
		p["equipped"]=equipped
		restore_issue_weapon(p)
	elif type=="charm":
		equipped["charm"]=charm_slots(equipped)
		if index<0 or index>=equipped["charm"].size():
			return false
		equipped["charm"][index]={}
		p["equipped"]=equipped
	else:
		equipped["gear"]=gear_slots(equipped)
		equipped["gear"][clampi(index,0,Catalog.GEAR.size()-1)]={}
		p["equipped"]=equipped
	refresh_max_hp(p)
	return true

# --- worn sockets as drag sources -------------------------------------------------
# The equipment bar is a drag source now, not just a row of buttons, so a piece can be
# carried to the backpack, the pocket, the item bar or another socket. Two sockets
# changing places need a setter, because neither piece may pass through a container.

## The socket name a (type, index) pair means. The camp panel and a drag both spell the
## item bar differently ("slot0" / "slot:0"), so every socket name is normalised here
## before it is compared or split.
func worn_zone_name(type: String, index: int) -> String:
	if type=="weapon": return "weapon"
	if type=="charm": return "charm%d" % index
	return "gear%d" % index

func slot_number(zone: String) -> int:
	return zone.substr(5).to_int() if zone.begins_with("slot:") else zone.substr(4).to_int()

func same_socket(a: String, b: String) -> bool:
	if a.begins_with("slot") and b.begins_with("slot"):
		return slot_number(a)==slot_number(b)
	return a==b

## Does this socket hold a piece of that kind? The item bar takes anything at all; an
## equipment socket only its own kind.
func socket_wants(zone: String, entry: Dictionary) -> bool:
	var kind := str(entry.get("kind",""))
	if zone.begins_with("slot"): return true
	if zone=="weapon": return kind=="weapon"
	if zone.begins_with("gear"): return kind=="gear" and Catalog.gear_slot(entry)==zone.substr(4).to_int()
	if zone.begins_with("charm"): return kind=="charm"
	return false

## Writes a piece straight into a worn socket, or empties it with {}: the setter half
## of `worn_entry()`.
func set_worn_slot(p: Dictionary, type: String, index: int, entry: Dictionary) -> void:
	var equipped: Dictionary=p.get("equipped",empty_equipment())
	if not equipped is Dictionary:
		equipped=empty_equipment()
	if type=="weapon":
		equipped["weapon"]=entry
		if entry.is_empty():
			restore_issue_weapon(p)
		else:
			p["weapon"]=clampi(int(entry.get("weapon",p.get("weapon",0))),0,Catalog.WEAPONS.size()-1)
			p["reload"]=0.0
			p["combo"]=0
			p["pending_strike"]=false
	elif type=="charm":
		var charms: Array=charm_slots(equipped)
		charms[clampi(index,0,charms.size()-1)]=entry
		equipped["charm"]=charms
	else:
		var gear: Array=gear_slots(equipped)
		gear[clampi(index,0,Catalog.GEAR.size()-1)]=entry
		equipped["gear"]=gear
	p["equipped"]=equipped
	refresh_max_hp(p)

## The piece in a socket — a worn socket or one of the bar's three. One reader for
## both spellings ("slot0" from the panel, "slot:0" from a drag).
func socket_entry(p: Dictionary, zone: String) -> Dictionary:
	if zone.begins_with("slot"): return item_slot(p,slot_number(zone))
	if zone=="weapon": return worn_entry(p,"weapon",0)
	if zone.begins_with("gear"): return worn_entry(p,"gear",zone.substr(4).to_int())
	if zone.begins_with("charm"): return worn_entry(p,"charm",zone.substr(5).to_int())
	return {}

## Writes a piece straight into a socket, or empties it with {}: the setter half of
## `socket_entry()`. A drag between two sockets needs it, because neither piece may
## pass through a container on the way.
func set_socket_entry(p: Dictionary, zone: String, entry: Dictionary) -> void:
	if zone.begins_with("slot"):
		set_item_slot(p,slot_number(zone),entry)
		return
	if zone=="weapon":
		set_worn_slot(p,"weapon",0,entry)
	elif zone.begins_with("gear"):
		set_worn_slot(p,"gear",zone.substr(4).to_int(),entry)
	elif zone.begins_with("charm"):
		set_worn_slot(p,"charm",zone.substr(5).to_int(),entry)

## Empties a socket, reporting whether anything was in it.
func clear_socket(p: Dictionary, zone: String) -> bool:
	if zone.begins_with("slot"):
		if item_slot(p,slot_number(zone)).is_empty(): return false
		set_item_slot(p,slot_number(zone),{})
		return true
	if zone=="weapon": return clear_worn_slot(p,"weapon",0)
	if zone.begins_with("gear"): return clear_worn_slot(p,"gear",zone.substr(4).to_int())
	if zone.begins_with("charm"): return clear_worn_slot(p,"charm",zone.substr(5).to_int())
	return false

## Socket onto socket: the two pieces change places when the target will have the
## incoming one, and a bare socket is simply filled. Either side may be a worn socket
## or a bar socket. Returns false, changing nothing, when the target will not have it
## — that is the one rule for "drag kit between sockets", camps and raids alike.
func swap_sockets(p: Dictionary, from: String, zone: String) -> bool:
	if from.is_empty() or zone.is_empty() or same_socket(from,zone):
		return false
	var incoming := socket_entry(p,from)
	if incoming.is_empty():
		return false
	if not socket_wants(zone,incoming):
		return false
	var outgoing := socket_entry(p,zone)
	set_socket_entry(p,zone,incoming)
	set_socket_entry(p,from,outgoing)
	refresh_max_hp(p)
	return true

## A worn piece dragged into a carried container, or into a searched chest when `to`
## is "loot:<ref>". It is seated where the drag previewed, and the body socket is
## emptied only once that seat exists — so "no room" costs nothing and the Watcher is
## never left half dressed.
func move_worn_to(p: Dictionary, type: String, index: int, to: String, cell: Vector2i, rot: bool) -> bool:
	if to.begins_with("loot:"):
		return move_worn_to_loot(p,type,index,to.substr(5).to_int(),rot)
	if to!="backpack" and to!="pocket":
		return false
	var worn := worn_entry(p,type,index)
	if worn.is_empty():
		return false
	var target: Dictionary=p.get(to,{})
	if target.is_empty():
		return false
	var probe: Dictionary=worn.duplicate(true)
	probe["rot"]=rot
	var landing: Vector2i=resolve_drop(Catalog.container_items(target),Catalog.container_grid(target),probe,cell)
	if landing.x<0:
		return false
	var entry: Dictionary=worn.duplicate(true)
	entry["x"]=landing.x
	entry["y"]=landing.y
	entry["rot"]=rot
	if not Catalog.can_place(Catalog.container_items(target),entry,landing,-1,Catalog.container_grid(target)):
		return false
	var items: Array=Catalog.container_items(target)
	items.append(entry)
	target["items"]=items
	target["next"]=maxi(int(target.get("next",1)),1)+1
	Catalog.compact_arrivals(target)
	clear_worn_slot(p,type,index)
	message.emit("已收进"+("背包" if to=="backpack" else Catalog.POCKET_NAME)+"："+Catalog.item_name(worn)+"。")
	return true

## A worn piece dragged into a searched chest. The whole pile rule is the chest's own
## (`place_arrival`), and the piece leaves the body only after the chest took it — a
## full chest refuses and the equipment stays worn.
func move_worn_to_loot(p: Dictionary, type: String, index: int, ref: int, rot: bool) -> bool:
	var target := container_at(ref)
	if target.is_empty():
		return false
	var worn := worn_entry(p,type,index)
	if worn.is_empty():
		return false
	var probe: Dictionary=worn.duplicate(true)
	probe["rot"]=rot
	var plan := Catalog.place_arrival(target,probe)
	if not bool(plan.ok):
		return false
	if not plan.items.is_empty():
		Catalog.commit_layout(target.items,plan.items)
	# A handed-over item stays visible even while the rest of the chest is still sealed.
	target.items.insert(0,plan.seat)
	target["searched"]=searched_units(target)+1
	clear_worn_slot(p,type,index)
	message.emit("把 %s 放进了%s。" % [Catalog.item_name(worn),container_title(target)])
	return true

# Places an item taken off the player: the backpack first, then the pocket — but the
# pocket only counts for gold and above. **紫及以下不自动进次元口袋** is the rarity
# rule (see README「稀有度与自动收纳判定」), so a low-quality piece has no seat in
# the pocket and the take-off simply refuses instead of quietly banking it safely.
# The layout is worked out on a copy first, so "no room anywhere" costs the player
# nothing, and the copy's answer is what gets committed — the item is seated with
# its own fields, not rebuilt from its kind.
func stow_worn(p: Dictionary, item: Dictionary) -> bool:
	var order: Array = ["backpack"]
	if Catalog.high_quality(item):
		order.append("pocket")
	for name in order:
		var container: Dictionary=p[name]
		var trial := Catalog.make_container([],Catalog.container_grid(container))
		trial["items"]=Catalog.container_items(container).duplicate()
		var plan := Catalog.place_arrival(trial,item)
		if not bool(plan.ok):
			continue
		var items: Array=Catalog.container_items(container)
		if not plan.items.is_empty():
			Catalog.commit_layout(items,plan.items)
		items.append(plan.seat)
		container["items"]=items
		container["next"]=maxi(int(container.get("next",1)),1)+1
		Catalog.compact_arrivals(container)
		return true
	return false

## Whether a take-off would fit, asked without touching anything. The panel asks
## this *before* the gesture so a refusal can say why instead of silently doing
## nothing, and so the piece never leaves the body without a seat to land on.
func take_off_fits(p: Dictionary, type: String, index: int = 0) -> bool:
	var worn := worn_entry(p,type,index)
	if worn.is_empty():
		return false
	if container_would_receive(p.get("backpack",{}),worn):
		return true
	return Catalog.high_quality(worn) and container_would_receive(p.get("pocket",{}),worn)

## "Could this container take this item", answered on a copy so nothing is touched:
## `container_receive()` is the same question asked by mutating.
func container_would_receive(container: Dictionary, entry: Dictionary) -> bool:
	if container.is_empty() or entry.is_empty():
		return false
	var kind := str(entry.get("kind",""))
	if kind.is_empty() or not Catalog.can_hold(container,kind):
		return false
	var trial := Catalog.make_container([],Catalog.container_grid(container))
	trial["items"]=Catalog.container_items(container).duplicate()
	return bool(Catalog.place_arrival(trial,entry).get("ok",false))

# Ctrl+left on the backpack socket takes the worn pack off in order to wear a
# spare, which is the same swap the cabinet buttons already perform: the old pack
# becomes a spare and the chosen one goes on the player's back. Silent when there
# is no other pack to wear, or when the new pack could not hold the carried loot.
func wear_spare(p: Dictionary) -> bool:
	var cabinet: Array=p.get("bags",[])
	var worn := str(p.get("backpack",{}).get("key",""))
	for i in cabinet.size():
		if str(cabinet[i].get("key",""))!=worn:
			return Catalog.swap_bags(p,i)
	return false

# Three ordered gear slots, rebuilt defensively because the whole player
# dictionary travels through ENet snapshots.
func gear_slots(equipped: Dictionary) -> Array:
	var slots = equipped.get("gear",[])
	if not slots is Array:
		slots=[]
	while slots.size()<Catalog.GEAR.size():
		slots.append({})
	return slots

# Returns a piece of equipment to the player's own storage. The backpack comes
# first; the **pocket only for gold and above**, because the pocket is not "room"
# for purple and below (README「稀有度与自动收纳判定」). When neither can hold it
# the piece falls to the ground as itself.
func stow_equipment(p: Dictionary, item: Dictionary, prefer: String = "backpack") -> bool:
	var order: Array = ["backpack","pocket"] if prefer!="pocket" else ["pocket","backpack"]
	for slot in order:
		if slot=="pocket" and not Catalog.high_quality(item):
			continue
		if container_receive(p,slot,item):
			return true
	return drop_loose(p,item)

# The last resort for a piece nothing can hold: it lies on the ground as *itself*.
# This is the same single-item drop shape loose enemy loot uses, so the world draws
# the item's own icon inside its quality ring and F picks it up in one press — never
# a searchable 掉落包, which would dress a single sword up as a container.
func drop_loose(p: Dictionary, item: Dictionary) -> bool:
	ground_place(p,item)
	message.emit(Catalog.item_name(item)+" 放不下了，已掉在脚边。")
	return false

## The ground shape on its own, for the callers that already have their own thing to
## say: one loose drop, drawn as the item itself, picked up with F in one press.
func ground_place(p: Dictionary, item: Dictionary) -> void:
	var kind := str(item.get("kind",""))
	var key := ""
	if kind=="backpack":
		key=str(item.get("quality",item.get("key",Catalog.DEFAULT_BAG_KEY)))
	world_drops.append(ground_drop(p.p+Vector2(28,18),kind,key,bool(item.get("provision",false)),loot_meta(item)))

## A worn piece the player deliberately dragged out of the panel: it leaves the body
## and lies there as itself, and F puts it back in a bag.
func drop_worn(p: Dictionary, type: String, index: int) -> bool:
	var worn := worn_entry(p,type,index)
	if worn.is_empty():
		return false
	ground_place(p,worn)
	clear_worn_slot(p,type,index)
	message.emit("已丢下："+Catalog.item_name(worn)+"。")
	return true

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

# How long the offline cut-in holds for this hero. The manifest carries the
# recorded line lengths; a hero whose lines are not recorded yet — a placeholder
# bank, or none at all — falls back to the same short cut-in the online path
# uses, so the windup is never zero and the ultimate still works.
func ultimate_seconds(p: Dictionary) -> float:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voices/voice-manifest.json"))
	var heroes: Array=manifest.get("heroes",[]) if manifest is Dictionary else []
	if p.hero<0 or p.hero>=heroes.size():
		return ONLINE_ULTIMATE_DURATION
	var timing: Dictionary=heroes[p.hero] if heroes[p.hero] is Dictionary else {}
	if not bool(timing.get("voice_ready",true)):
		return ONLINE_ULTIMATE_DURATION
	var seconds := float(timing.get("charge_time",0.0))+float(timing.get("burst_time",0.0))
	return seconds if seconds>0.05 else ONLINE_ULTIMATE_DURATION

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
	# The necromancer's rectangle is placed at release, not where the key was
	# pressed, so her windup ends in a swing the player can still steer.
	if roguelike.active(self):
		RogueBuild.hero_skill(self,p,aim)
		return
	if p.hero==NECROMANCER:
		cast_soul_reap(p,aim)
		return
	broadcast_combat({"kind":"skill","p":p.p,"aim":aim,"hero":p.hero,"weapon":Catalog.weapon_family(p.weapon),"id":p.id})
	emit_effect("skill",p.p)
	if p.hero==1:
		for ally in players.values():
			if ally.status=="active" and ally.p.distance_to(p.p)<300:
				var healing := clampf(45.0+0.15*(ally.max_hp-100.0),45.0,70.0)
				ally.hp=minf(ally.max_hp,ally.hp+healing)
				ally.sanity=minf(100,ally.sanity+15)
	else:
		p.invuln=maxf(p.invuln,1.0)
		var quality_bonus := Catalog.weapon_bonus(kit_weapon(p)) if weapon_kit_active(p) else 0.0
		var ultimate_damage := 115.0*(1.0+0.5*quality_bonus)*(1.0+weapon_scaling(p,Catalog.starter_index(int(p.hero))))
		for e in enemies:
			var offset: Vector2=e.p-p.p
			var reach := 210 if p.hero==2 else 460
			if offset.length()<reach and ruins.clear_line(p.p,e.p) and (p.hero==2 or offset.normalized().dot(aim)>0.35):
				damage_enemy(e,ultimate_damage,p.id,offset.normalized(),40.0,4)

# --- 墓煜 / 冥火剑雨 -----------------------------------------------------------
# The necromancer's ultimate is one rectangle in front of her: a rune sword rain
# that lands a single heavy hit, then leaves a patch of purple underworld fire.
# The patch pulses on a fixed cadence regardless of frame rate, and every enemy
# it touches keeps a burning debuff that outlives the patch. Re-entering the fire
# refreshes that debuff rather than stacking a second one.
const NECROMANCER := 3
const SOUL_REAP_DAMAGE := 150.0
const FIRE_HALF_WIDTH := 175.0
const FIRE_LENGTH := 480.0
# The patch is anchored on the caster but starts a little behind her feet, so an
# enemy standing on top of her still burns. The drawn outline reads this same
# constant, which is what keeps the purple box and the damage rectangle equal.
const FIRE_BACK := 20.0
const FIRE_TICK := 0.5
const FIRE_TICK_DAMAGE := 66.0
const FIRE_DURATION := 6.0
const BURN_TICK := 0.6
const BURN_TICK_DAMAGE := 6.0
const BURN_DURATION := 6.0
# The rain falls a beat after the cut-in, so the rectangle reads as the attack
# rather than as the moment the key was pressed.
const SOUL_REAP_DELAY := 0.32
const SOUL_REAP_FX := 1.9

func cast_soul_reap(p: Dictionary, aim: Vector2) -> void:
	var direction := aim.normalized()
	if direction.length_squared()<0.1:
		direction=Vector2.RIGHT
	broadcast_combat({"kind":"skill","p":p.p,"aim":direction,"hero":p.hero,"weapon":Catalog.weapon_family(p.weapon),"id":p.id})
	emit_effect("skill",p.p)
	p.invuln=maxf(p.invuln,1.0)
	soul_reaps.append({"owner":p.id,"at":p.p,"aim":direction,"time":SOUL_REAP_DELAY,
		"total":SOUL_REAP_DELAY+SOUL_REAP_FX,"damage":ultimate_damage(p,SOUL_REAP_DAMAGE)})

# Every ultimate in the game pays the same multipliers: talents, charms, camp
# gear and whatever the Watcher is actually holding.
func ultimate_damage(p: Dictionary, base: float) -> float:
	if roguelike.active(self): return base/90.0*RogueBuild.unit(self,p,true)
	return base*(1.0+weapon_scaling(p,Catalog.starter_index(int(p.hero))))*(1.0+float(p.get("rogue_damage",0))+Homestead.bonus(p,"damage")+p.talents[1]*0.08+mini(3,charms_carried(p))*0.12+float(Catalog.gear_of(int(p.gear)).get("damage",0.0))+equipment_damage(p))

# The rectangle the rain covers, as a plain geometric test so aiming, damage and
# the drawn patch all agree on exactly which ground is on fire.
static func inside_reap(at: Vector2, origin: Vector2, aim: Vector2, forward: float) -> bool:
	var v: Vector2=at-origin
	var along := v.dot(aim)
	return along>=-FIRE_BACK and along<=forward and absf(v.dot(aim.orthogonal()))<=FIRE_HALF_WIDTH

func update_soul_reaps(dt: float) -> void:
	for i in range(soul_reaps.size()-1,-1,-1):
		var reap: Dictionary=soul_reaps[i]
		reap.time-=dt
		if reap.time<=0.0 and not reap.get("landed",false):
			reap["landed"]=true
			for e in enemies:
				if e.hp<=0 or not inside_reap(e.p,reap.at,reap.aim,FIRE_LENGTH):
					continue
				damage_enemy(e,float(reap.damage),int(reap.owner),reap.aim,46.0,4)
			fire_zones.append({"owner":int(reap.owner),"at":reap.at,"aim":reap.aim,
				"time":FIRE_DURATION,"next":0.0,"pulses":0})
			broadcast_combat({"kind":"necromancer-fire","p":reap.at,"aim":reap.aim,
				"forward":FIRE_LENGTH,"half":FIRE_HALF_WIDTH,"duration":FIRE_DURATION,"total":reap.total})
		if reap.time<=-SOUL_REAP_FX:
			soul_reaps.remove_at(i)

func update_fire_zones(dt: float) -> void:
	for i in range(fire_zones.size()-1,-1,-1):
		var zone: Dictionary=fire_zones[i]
		zone.time-=dt
		zone.next-=dt
		# The first pulse lands the moment the patch appears, so six seconds of
		# fire really is twelve ticks rather than eleven.
		if zone.next<=0.0 and float(zone.time)>=0.0:
			# The cadence belongs to the patch, not to the frame: a long frame
			# settles every pulse it swallowed instead of losing them.
			zone.next+=FIRE_TICK
			zone["pulses"]=int(zone.get("pulses",0))+1
			for e in enemies:
				if e.hp<=0 or not inside_reap(e.p,zone.at,zone.aim,FIRE_LENGTH):
					continue
				burn_enemy(e,int(zone.owner),FIRE_TICK_DAMAGE,true)
		if zone.time<0.0:
			fire_zones.remove_at(i)

# One tick of underworld fire. Arriving from the patch refreshes the debuff's
# whole duration; the debuff's own pulses only take what is left of it. The
# pulse schedule is deliberately left alone by a refresh, so standing in the
# fire never starves the burn of the ticks it was already owed.
func burn_enemy(e: Dictionary, owner: int, damage: float, refresh: bool = false) -> void:
	if refresh:
		e["burn_time"]=BURN_DURATION
		if not e.has("burn_next"):
			e["burn_next"]=BURN_TICK
	e.hp-=damage
	e.last=owner
	e["burn_hit"]=0.4
	# Only the burn's own pulses are counted; a pulse of the patch that lit it
	# also damages, but it is the patch's tick rather than the debuff's.
	if not refresh:
		e["burn_pulses"]=int(e.get("burn_pulses",0))+1
	broadcast_combat({"kind":"burn","p":e.p,"damage":damage,"owner":owner,"enemy_type":e.type})

func update_burns(dt: float) -> void:
	for e in enemies:
		if not e.has("burn_time"):
			continue
		e["burn_time"]=maxf(0.0,float(e.burn_time)-dt)
		e["burn_hit"]=maxf(0.0,float(e.get("burn_hit",0.0))-dt)
		var next := float(e.get("burn_next",BURN_TICK))-dt
		while next<=0.0 and float(e.burn_time)>0.0:
			next+=BURN_TICK
			if e.hp>0:
				burn_enemy(e,int(e.get("last",0)),BURN_TICK_DAMAGE)
		e["burn_next"]=next
		if float(e.burn_time)<=0.0 and float(e.get("burn_hit",0.0))<=0.0:
			e.erase("burn_time")
			e.erase("burn_next")
			e.erase("burn_hit")
			e.erase("burn_pulses")

func reload_player(p: Dictionary) -> void:
	var clip: int=RogueActions.clip(p) if roguelike.active(self) else 16
	# Only the rifle family consumes ammunition; the issue weapons never do, so
	# R on a sword, greatsword or staff is simply ignored.
	if Catalog.weapon_family(p.weapon)!=0:
		return
	if clip==0 or p.reload>0 or p.ammo>=clip:
		return
	if p.reserve<=0 and spend(p,"ammo"):
		p.reserve+=48
	if p.reserve>0:
		p.reload=1.3*(1-minf(.25,RogueBuild.r(p,19,[.08,.12,.16])+RogueBuild.buff(p,"reload_haste",elapsed))) if roguelike.active(self) else 1.3
		broadcast_audio("reload",p)

func simulate(dt: float) -> void:
	elapsed+=dt
	for actor in players.values(): actor["boss_slow"]=0.0
	if roguelike.active(self):
		for zone_data in roguelike.combat.effects:
			if zone_data.get("choreographed",false): BossChoreography.modifiers(self,zone_data,0.0)
	BossChoreography.advance(self,dt)
	if not roguelike.active(self): expedition.tick(self,dt)
	# Entering a habitat commits its current defenders. Refill and scent spawns
	# cannot prolong an encounter after the party has started clearing it.
	if map_id=="border" and not roguelike.active(self):
		for p in players.values():
			if p.status!="active": continue
			var block := Ecology.block_at(ruins,p.p)
			if block>=0 and Ecology.remaining(self,block)>0: ruins.sites[block].engaged=true
	threat=clampf(float(raid.day-1)*0.35+float(raid.time)/duration,0,1.6)
	spawn_timer-=dt
	# Opening the map already places about 52 site defenders. Keep only a small
	# refill margin rather than growing the live population toward the old 65 cap.
	var ambient_limit := 52+mini(players.size(),4)*2
	if raid.phase=="explore" and map_id=="border" and spawn_timer<=0 and enemies.size()<ambient_limit:
		spawn_timer=maxf(2.0,9.0-threat*6.0)
		for i in mini(2,ambient_limit-enemies.size()):
			spawn_enemy(Vector2.ZERO,-1,true)
	for id in players:
		var p: Dictionary=players[id]
		if roguelike.active(self):
			RogueBuild.tick(self,p,dt)
			RogueActions.tick(self,p,dt)
			RogueActions.tail(self,p,dt)
		for key in ["attack","skill","dash","invuln","combo_timeout","cast_time","art_cd"]:
			p[key]=maxf(0,p[key]-dt)
		if p.status=="down":
			p.bleed-=dt
			if p.bleed<=0:
				p.status="dead"
			continue
		if p.status!="active":
			continue
		recover_mana(p,dt)
		if pending_ultimates.has(id):
			pending_ultimates[id].remaining-=dt
			if pending_ultimates[id].remaining<=0:
				release_ultimate(id)
		if p.hitstop>0:
			p.hitstop=maxf(0,p.hitstop-dt)
		else:
			p.swing_time=maxf(0,p.swing_time-dt)
			if p.pending_strike and p.swing_total-p.swing_time>=float(p.get("build_strike_windup",Catalog.weapon(p.weapon).windup)):
				p.pending_strike=false
				release_strike(p)
		if p.reload>0:
			p.reload-=dt
			if p.reload<=0:
				var count: int=mini((RogueActions.clip(p) if roguelike.active(self) else 16)-p.ammo,p.reserve)
				p.ammo+=count
				p.reserve-=count
				if roguelike.active(self): RogueBuild.reload_event(self,p)
				broadcast_audio("reload-end",p)
		var cmd: Dictionary=inputs.get(id,{})
		if roguelike.active(self) and not p.get("rogue_selection",{}).is_empty(): cmd={}
		var direction: Vector2=cmd.get("move",Vector2.ZERO)
		if pending_ultimates.has(id):
			direction=Vector2.ZERO
		else:
			p.aim=cmd.get("aim",Vector2.RIGHT)
		var speed: float=Homestead.bonus(p,"speed")+Catalog.HEROES[p.hero].speed+p.talents[2]*9+float(Catalog.gear_of(int(p.gear)).get("speed",0.0))+equipment_speed(p)
		speed+=float(p.get("rogue_speed",0))
		speed*=1.0-float(p.get("boss_slow",0))
		if roguelike.active(self):
			var move_bonus := float(rogue_mods(p).get("move_speed",0.0))
			speed=minf(Catalog.HEROES[p.hero].speed+70,speed+RogueBuild.stat(self,p,"speed")+move_bonus)
			speed*=1.0-float(p.get("rogue_slow",0))*(.75 if RogueBuild.gear(p,64) else 1.0)
			if p.height>0: speed*=.7
			if p.flask_time>0: speed*=.5
		move_player(p,direction,bool(cmd.get("sprint",false)),dt,speed)
		if roguelike.active(self):
			p.sanity=100.0
		auto_pickup_crystals(p)
		p.scent=move_toward(p.scent,float(crystals_carried(p)*8),dt*0.5)
		if raid.phase not in ["choice","complete"]:
			p.sanity=maxf(0,p.sanity-dt*(0.035+threat*0.055+p.scent*0.002)*(1.0-stat_resistance(p)))
		if map_id=="border" and p.p.distance_to(safe_center())>safe_radius():
			p.hp-=incoming_damage(p,dt*(4+threat*5))
			p.sanity=maxf(0,p.sanity-dt*1.4*(1.0-stat_resistance(p)))
		if p.sanity<=0 and raid.phase not in ["choice","complete"]:
			p.hp-=incoming_damage(p,dt*3)
		if raid.phase=="explore" and map_id=="border" and p.scent>38 and rng.randf()<dt*0.04 and enemies.size()<70:
			spawn_enemy(p.p+Vector2(300,0))
			p.scent-=10
		if roguelike.active(self) and p.has("build_pending_action"):
			var buffered: Dictionary=p.build_pending_action
			if elapsed>float(buffered.expires): p.erase("build_pending_action")
			elif p.swing_time<=0 and p.attack<=0 and p.cast_time<=0 and (buffered.kind!="skill" or p.height<=0):
				p.erase("build_pending_action"); perform(id,str(buffered.kind))
		p["attack_buffer"]=maxf(0,float(p.get("attack_buffer",0))-dt)
		if bool(cmd.get("fire",false)):
			attack(p)
		elif float(p.get("attack_buffer",0))>0 and int(p.get("buffer_weapon",-1))==int(p.weapon) and p.attack<=0 and p.swing_time<=0:
			attack(p)

		interact(p,bool(cmd.get("interact",false)) and p.dodge_time<=0 and not pending_ultimates.has(id),dt)
		advance_search(p,dt)
		if p.hp<=0:
			down(p)
	if roguelike.active(self): RogueBuild.tick_enemies(self,dt)
	update_enemies(dt)
	update_soul_reaps(dt)
	update_fire_zones(dt)
	update_burns(dt)
	update_bullets(dt)
	if roguelike.active(self):
		for player in players.values(): RogueBuild.commit_flask(self,player)
	var defeated_boss := false
	# A death is settled after the sweep rather than during it: a boss's own
	# reward path may raise the next encounter, and that rewrites the enemy list
	# out from under the loop. Walking the live dictionaries and removing them by
	# identity afterwards keeps every drop and every reward event intact.
	var fallen: Array = []
	for e in enemies:
		if e.hp>0:
			continue
		fallen.append(e)
		if roguelike.active(self): RogueBuild.enemy_experience(self,e)
		if roguelike.active(self) and players.has(int(e.last)): RogueBuild.killed(self,players[int(e.last)],e)
		if e.get("boss_construct",false):
			broadcast_combat({"kind":"boss-construct-break","p":e.p,"art_key":e.art_key,"vfx_role":e.vfx_role,"id":e.id})
			continue
		if e.get("rogue_guardian",false): roguelike.combat.defeated(self,e)
		elif e.get("raid_boss",false) or e.get("mini_boss",false) or int(e.type)==4: BossPresentation.send(self,e,"fall")
		resolve_site_defeat(e)
		if e.get("dragon_boss",false): dragon_boss.defeated(self,e)
		elif e.get("hidden_final",false): expedition.hidden_victory(self)
		elif e.get("wild_boss",false): wild_bosses.defeated(self,e)
		elif e.get("mini_boss",false): mini_bosses.defeated(self,e)
		if players.has(e.last) and not e.get("rogue_summoned",false):
			players[e.last].kills+=1
		if e.get("raid_boss",false):
			defeated_boss=true
		elif e.type==4 and not e.get("mini_boss",false):
			if map_id=="city": ruins.sites[0]["boss_defeated"]=true
		elif not roguelike.active(self) and not e.get("rogue_summoned",false) and rng.randf()<enemy_drop_chance(e):
			var loot := enemy_loot(e)
			if str(loot.kind)==CRYSTAL_DROP:
				world_drops.append(crystal_drop(e.p,rng.randi_range(1,3)))
			else:
				world_drops.append(ground_drop(e.p,str(loot.kind),str(loot.get("key","")),false,loot_meta(loot)))
		emit_effect("hit",e.p)
		broadcast_combat({"kind":"enemy_defeated","p":e.p,"type":e.type,"facing":e.get("facing",1.0),"boss_kind":e.get("boss_kind",-1),"mini_boss":e.get("mini_boss",false),"mini_kind":e.get("mini_kind",-1),"final_form":e.get("final_form",false),"wild_boss":e.get("wild_boss",false),"wild_kind":e.get("wild_kind",-1),"abyss_final":e.get("abyss_final",false),"dragon_boss":e.get("dragon_boss",false),"hidden_final":e.get("hidden_final",false),"rogue_floor":e.get("rogue_skin",-1),"rogue_minion":e.get("rogue_minion",false),"rogue_guardian":e.get("rogue_guardian",false),"id":e.id})
	for e in fallen:
		enemies.erase(e)
	if map_id=="city" and ruins.sites[0].get("boss_defeated",false) and not ruins.sites[0].get("cleared",false) and enemies.is_empty():
		ruins.sites[0]["cleared"]=true
		knight_reward(RoyalCity.BOSS)
	if roguelike.active(self): roguelike.tick(self,dt)
	if defeated_boss:
		if int(raid.day)==3 and not raid.get("final_spawned",false): expedition.spawn_boss(self,true)
		elif int(raid.day)==3 and raid.get("final_spawned",false) and not raid.get("abyss_spawned",false) and raid.get("map_boss_defeats",{}).size()>=2: wild_bosses.spawn_final(self)
		else: expedition.victory(self)
	# The hidden encounter unlocks on the frame the four conditions below first
	# hold together, whatever order they were satisfied in: every sunrise bell
	# lit, the knight's amulet still carried, the queen already down, and the
	# secret abyss finale not already running in her place.
	if not raid.is_empty() and not raid.get("ended",false) and not raid.get("hidden_slain",false) \
			and not raid.get("abyss_spawned",false) and raid.get("final_spawned",false) \
			and hidden_ending_ready(): expedition.spawn_hidden(self)
	var alive := false
	for p in players.values():
		if p.status in ["active","down"]:
			alive=true
	if roguelike.active(self):
		var standing := false
		for p in players.values():
			if p.status=="active" and p.connected: standing=true
		raid["party_down_time"]=0.0 if standing else float(raid.get("party_down_time",0))+dt
		if float(raid.party_down_time)>=3: roguelike.settle(self)
	elif not alive:
		settle()

func safe_center() -> Vector2:
	return raid.get("center",Ruins.CENTER)

func safe_radius() -> float:
	if roguelike.active(self): return 10000.0
	if map_id=="city": return 10000.0
	if raid.is_empty(): return Ruins.SIZE.length()
	if raid.phase in ["choice","complete"]: return Ruins.SIZE.length()
	var final_radius := 620.0 if raid.day==3 else 540.0
	if raid.phase=="boss": return final_radius
	# Start large enough to cover every corner even for an off-centre arena.
	var center := safe_center()
	var full := maxf(center.distance_to(Vector2.ZERO),center.distance_to(Ruins.SIZE))
	full=maxf(full,maxf(center.distance_to(Vector2(Ruins.SIZE.x,0)),center.distance_to(Vector2(0,Ruins.SIZE.y))))+100
	return lerpf(full,final_radius,clampf((float(raid.time)-SHRINK_START)/maxf(1.0,duration-SHRINK_START),0,1))

func can_extract() -> bool:
	if roguelike.active(self): return false
	return not raid.is_empty() and (raid.day==2 or raid.phase=="complete")

# --- the hidden ending -------------------------------------------------------
# Lighting all three sunrise bells costs a whole raid: the shrines only exist on
# the border map, and day three strands the party in the queen's arena. Carrying
# the banished knight's amulet that far is the second half of the bargain, so
# the check is deliberately about the backpack the player actually walks in
# with — dropping the trinket to make room for loot really does forfeit it.
const BELL_SEALS := 3

# The lit bells are recorded on the raid rather than read back off ruins.shrines:
# crossing into the royal city rebuilds the border map, and a rebuilt map has
# three cold bells again. What the party has sealed this run is run state.
func bells_lit() -> int:
	return raid.get("sealed_bells",{}).size()

func seal_bell(index: int) -> void:
	var sealed: Dictionary=raid.get("sealed_bells",{})
	sealed[index]=true
	raid["sealed_bells"]=sealed

func carries_amulet(p: Dictionary) -> bool:
	return Catalog.container_count(p.get("backpack",{}),AMULET_DROP)>0

func amulet_carrier() -> Dictionary:
	for p in players.values():
		if p.status in ["active","down"] and carries_amulet(p):
			return p
	return {}

func hidden_ending_ready() -> bool:
	return bells_lit()>=BELL_SEALS and not amulet_carrier().is_empty()

func can_travel() -> bool:
	if roguelike.active(self): return false
	return raid.is_empty() or (raid.phase=="explore" and float(raid.time)<SHRINK_START)

func move_player(p: Dictionary, direction: Vector2, sprint: bool, dt: float, speed: float) -> void:
	var before: Vector2=p.p
	if p.dodge_time>0:
		var step := minf(dt,p.dodge_time)
		p.p=ruins.move(p.p,p.dodge_dir*((80.0/.18 if p.get("height",0)>0 else DODGE_DISTANCE/DODGE_DURATION)*(1.12 if roguelike.active(self) and RogueBuild.gear(p,61) else 1.0))*step)
		p.dodge_time=maxf(0,p.dodge_time-dt)
		p.move_dir=p.dodge_dir
		p.motion="dodge" if p.dodge_time>0 else "idle"
	else:
		var active_attack: bool=p.swing_time>0 or p.cast_time>0
		var running_now := sprint and not active_attack and direction.length()>0.1
		var multiplier := RUN_MULTIPLIER if running_now else 1.0
		if p.swing_time>0 and Catalog.weapon_family(p.weapon)==2:
			multiplier*=(.6 if RogueBuild.weapon_id(p)==20 else .7)+(.15 if RogueBuild.gear(p,55) else 0)+(.05 if RogueBuild.core(p,4)==1 else .1 if RogueBuild.core(p,4)==2 else 0) if roguelike.active(self) else .48
		if roguelike.active(self):
			if p.reload>0: multiplier*=.9 if RogueBuild.gear(p,57) else .6
			elif active_attack and Catalog.weapon_family(p.weapon)!=2: multiplier*=.65 if RogueBuild.weapon_id(p)==45 else .9 if RogueBuild.weapon_id(p)==33 else 1.0 if RogueBuild.gear(p,18) and Catalog.weapon_family(p.weapon)==1 else .8
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
	p["attack_buffer"]=0.0
	p.combo_timeout=0.0
	p.bleed=35
	p.pending_strike=false
	p.swing_time=0.0
	p.dodge_time=0.0
	p.motion="idle"
	p.channel=0
	# Going down scatters the droppable storage only; the pocket stays sealed.
	if roguelike.active(self):
		p.flask_time=0.0; p.height=0.0; p.height_velocity=0.0
		p["flask_pending_commit"]=false
		p.build_inputs=[]; p.build_summons=[]; p.build_fields=[]
		p.erase("build_pending_art"); p.erase("build_pending_art_tail"); p.erase("build_pending_action")
	else: spill_storage(p)
	emit_effect("hurt",p.p)
	broadcast_audio("down",p)

func attack(p: Dictionary) -> void:
	if roguelike.active(self) and elapsed>float(p.get("build_attack_edge_until",-1)): p.build_attack_edge=false
	if roguelike.active(self) and (p.flask_time>0 or (p.height>0 and p.air_attacks>=2)): return
	if roguelike.active(self) and raid.phase!="rogue_combat": return
	if p.attack>0 or p.reload>0 or p.swing_time>0 or p.cast_time>0 or p.dodge_time>0 or p.status!="active":
		if roguelike.active(self) and p.status=="active" and p.dodge_time>0 and p.dodge_time<=.08:
			p.attack_buffer=.20; p.buffer_weapon=int(p.weapon)
		if p.status=="active" and p.reload<=0 and p.cast_time<=0 and p.dodge_time<=0 and p.hitstop<=0 and not p.pending_strike and maxf(p.attack,p.swing_time)<=.18:
			p["attack_buffer"]=.22
			p["buffer_weapon"]=int(p.weapon)
		return
	p["attack_buffer"]=0.0
	var family := Catalog.weapon_family(p.weapon)
	var weapon: Dictionary=Catalog.weapon(p.weapon)
	if family==0 and p.ammo<=0:
		reload_player(p)
		return
	if not spend_mana(p,RogueBuild.mana_cost(self,p,float(weapon.get("mana_cost",0)),"attack") if roguelike.active(self) else float(weapon.get("mana_cost",0.0))):
		return
	p.combo=(int(p.combo)+1)%3 if p.combo_timeout>0 else 0
	p.combo_timeout=maxf(1.2,float(weapon.rate)*equipment_rate(p)+.65)
	# A looted weapon of matching quality swings faster than the issue weapon.
	var rate: float=weapon.rate*equipment_rate(p)
	p.attack=rate
	p.swing_total=rate
	p.swing_time=rate
	p.strike_aim=p.aim.normalized()
	p.pending_strike=true
	if roguelike.active(self):
		if p.get("build_attack_edge",false): RogueBuild.action_event(self,p,"A"); p.build_attack_edge=false
		if p.height>0: p.air_attacks+=1
		p["build_strike_context"]=RogueBuild.context(self,p,"attack")
		p["build_strike_windup"]=float(weapon.windup)/(1.0+minf(.25,RogueBuild.stat(self,p,"rate")))
		if p.height>0 and family==3 and RogueBuild.core(p,10)>0: p.build_strike_windup=maxf(.25,float(p.build_strike_windup)*(.95 if RogueBuild.core(p,10)==1 else .92))
		if p.height>0 and family==2: p.build_strike_windup=maxf(.45,float(p.build_strike_windup)); p.air_attacks=2
	# Animation consumers use the family; broadcast_combat also adds the exact
	# weapon index so presentation and projectiles keep their individual artwork.
	# The necromancer also fires a caster cue, because her issue weapon imitates
	# the one-handed family and would otherwise read as a plain sword swing.
	broadcast_combat({"kind":"windup","p":p.p,"aim":p.strike_aim,"weapon":family,"spell":str(weapon.get("spell","star")),"windup":float(weapon.windup),"id":p.id,"combo":p.combo})
	if p.hero==NECROMANCER and Catalog.is_starter(int(p.weapon)):
		broadcast_combat({"kind":"necromancer-cast","p":p.p,"aim":p.strike_aim,"windup":float(weapon.windup),"hero":p.hero,"id":p.id})
	if weapon.windup==0:
		p.pending_strike=false
		release_strike(p)

func release_weapon_art(p: Dictionary) -> bool:
	if roguelike.active(self): return RogueActions.start_art(self,p)
	if not authority() or p.status!="active" or p.art_cd>0 or p.reload>0 or p.swing_time>0 or p.cast_time>0 or p.dodge_time>0 or pending_ultimates.has(int(p.id)):
		return false
	var move := WeaponArts.of(int(p.weapon))
	if roguelike.active(self) and (p.flask_time>0 or (p.height>0 and p.air_art)): return false
	if not spend_mana(p,RogueBuild.mana_cost(self,p,float(move.mana),"art") if roguelike.active(self) else float(move.mana)):
		if int(p.id)==my_id(): message.emit("蓝量不足：%s需要 %d 蓝量。" % [move.name,move.mana])
		return false
	p.art_cd=float(move.cooldown)
	# T1-c (2026-06 死代码清理)：这里原本还重复了一份「roguelike 技能冷却公式」，但函数开头
	# （:2963）已经 `if roguelike.active(self): return RogueActions.start_art(self,p)`，所以下面的
	# `if roguelike.active(self):` 分支**永远不可达**（`p.art_cd` 的重复赋值、`build_art_base`、
	# `air_art`、`action_event("S")`、`context("art")` 全部在内）。可到达的那一份在
	# `scripts/rogue_actions.gd:21-24`（且已带上 CU09「迟滞」的 `cooldown` 钩子）—— 今后改技能冷却、
	# `build_art_base`、`air_art` 或动作事件请改那边，不要在这里再补一份拷贝。
	# 删掉后本函数的非 roguelike 路径逐字不变：`build_ctx` 仍为 `{}`（与原先不可达块执行时一致）。
	var build_ctx: Dictionary={}
	build_ctx["vfx"]=weapon_visual_state(p)
	p.cast_time=0.35
	p.attack=maxf(p.attack,0.35)
	p.channel=0.0
	var aim: Vector2=p.aim.normalized()
	if aim.length_squared()<0.1: aim=Vector2.RIGHT
	var family := Catalog.weapon_family(int(p.weapon))
	var damage := weapon_damage(p)*float(move.damage)
	var reach := float(move.reach)
	var kind := str(move.kind)
	var spell := str(move.get("spell",Catalog.weapon(int(p.weapon)).get("spell","star")))
	broadcast_combat({"kind":"strike","p":p.p,"aim":aim,"weapon":family,"spell":spell,"pattern":"thrust" if kind=="thrust" else "spin" if kind=="circle" else "cleave","reach":reach,"id":p.id,"combo":2,"art":move.name})
	if kind=="volley":
		var count := int(move.get("count",3))
		var speed := float(Catalog.weapon(int(p.weapon)).get("speed",850.0))
		var pellet_hits: Dictionary = {}
		for i in count:
			var direction := aim.rotated((i-(count-1)*0.5)*0.12)
			var shot := {"p":p.p+direction*23,"v":direction*speed,"life":reach/speed,"damage":damage,"build_context":build_ctx,"owner":p.id,"weapon":family,"weapon_index":int(p.weapon),"spell":spell,"knock":20.0,"remaining":int(move.get("pierce",1)),"hit_ids":[]}
			if spell=="scatter": shot["pellet_hits"]=pellet_hits
			shot["ground_origin"]=p.p
			bullets.append(shot)
		return true
	var center: Vector2=p.p
	if kind=="burst":
		# Keep the impact on the caster's side of walls.
		center=ruins.move(p.p,aim*reach)
		broadcast_combat({"kind":"spell_burst","p":center,"aim":aim,"spell":spell,"id":p.id,"weapon_index":int(p.weapon)})
	elif kind=="beam":
		broadcast_combat({"kind":"spell_beam","p":p.p,"aim":aim,"reach":reach,"spell":spell,"id":p.id,"weapon_index":int(p.weapon)})
	for e in enemies:
		if e.hp<=0 or not ruins.clear_line(p.p,e.p): continue
		var delta: Vector2=e.p-p.p
		var hit := false
		match kind:
			"thrust", "beam", "circle", "cone": hit=enemy_bodies.attack_hit(e,p.p,aim,reach,elapsed,false,kind,float(move.get("width",35.0)),-0.35)
			"burst": hit=enemy_bodies.attack_hit(e,center,aim,float(move.get("radius",180.0)),elapsed,false,"circle") and ruins.clear_line(center,e.p)
		if hit:
			var push: Vector2=(e.p-center).normalized()
			var force := 55.0 if family in [1,2] else 25.0
			if move.has("pull"):
				push=(center-e.p).normalized()
				force=minf(float(move.pull),e.p.distance_to(center))
			damage_enemy(e,damage,int(p.id),push,force,family,-1,build_ctx)
	return true

func release_strike(p: Dictionary) -> void:
	if roguelike.active(self): RogueActions.normal(self,p); return
	var family := Catalog.weapon_family(p.weapon)
	var w: Dictionary=Catalog.weapon(p.weapon)
	var direction: Vector2=p.strike_aim
	var damage: float=weapon_damage(p)
	var build_ctx: Dictionary=p.get("build_strike_context",{}) if roguelike.active(self) else {}
	if not build_ctx.has("vfx"): build_ctx["vfx"]=weapon_visual_state(p)
	if family==1 and p.combo==2:
		damage*=1.2 if roguelike.active(self) and RogueBuild.weapon_id(p)==4 else 1.0 if roguelike.active(self) and RogueBuild.weapon_id(p)==12 else 1.4
	var spell := str(w.get("spell","star"))
	var pattern := str(w.get("pattern",""))
	broadcast_combat({"kind":"strike","p":p.p,"aim":direction,"weapon":family,"spell":spell,"pattern":pattern,"reach":float(w.reach),"id":p.id,"combo":p.combo})
	if family in [1,2]:
		for e in enemies:
			var v: Vector2=e.p-p.p
			if e.hp<=0 or not ruins.clear_line(p.p,e.p):
				continue
			var hits: bool=enemy_bodies.attack_hit(e,p.p,direction,float(w.reach),elapsed,false,pattern,26.0,-0.35 if pattern=="cleave" else -0.1)
			if hits:
				damage_enemy(e,damage,p.id,v.normalized() if pattern in ["spin","quake"] else direction,w.knock,family,-1,build_ctx)
	else:
		if family==0:
			p.ammo-=1
			if spell!="arrow":
				emit_effect("shot",p.p)
		if spell=="prism":
			# The beam is settled by the host at release, using the same line of
			# sight rule as melee, then its full path is drawn on every client.
			for e in enemies:
				var delta: Vector2=e.p-p.p
				if e.hp>0 and enemy_bodies.attack_hit(e,p.p,direction,float(w.reach),elapsed,false,"beam",30.0) and ruins.clear_line(p.p,e.p):
					damage_enemy(e,damage,p.id,direction,w.knock,3,-1,build_ctx)
			broadcast_combat({"kind":"spell_beam","p":p.p,"aim":direction,"reach":w.reach,"spell":spell,"id":p.id,"weapon_index":int(p.weapon)})
		else:
			var count := 5 if spell=="scatter" else 1
			var pellet_hits: Dictionary = {}
			for shot in count:
				var shot_dir: Vector2=direction.rotated((float(shot)-2.0)*0.15) if count==5 else direction
				var projectile := {"p":p.p+shot_dir*23,"v":shot_dir*float(w.get("speed",850.0 if family==0 else 620.0)),"life":float(w.reach)/float(w.get("speed",850.0 if family==0 else 620.0)),"damage":damage,"build_context":build_ctx,"owner":p.id,"weapon":family,"weapon_index":int(p.weapon),"spell":spell,"knock":float(w.knock),"remaining":5 if spell=="eclipse" else 4 if spell=="moon" else 2 if spell=="arrow" else 1,"hit_ids":[]}
				if spell=="scatter": projectile["pellet_hits"]=pellet_hits
				projectile["ground_origin"]=p.p
				bullets.append(projectile)

func damage_enemy(e: Dictionary, damage: float, owner: int, direction: Vector2, knock: float, weapon: int = -1, weapon_index: int = -1, build_context: Dictionary = {}) -> void:
	if e.get("boss_construct",false):
		e.hp-=damage
		e.last=owner
		e.flash=.12
		broadcast_combat({"kind":"impact","p":e.p,"aim":direction,"damage":damage,"id":owner,"enemy_id":e.id,"heavy":false})
		return
	var hp_before: float=maxf(0,float(e.hp))
	if roguelike.active(self) and players.has(owner) and hp_before>0:
		var attack_mods := rogue_mods(players[owner])
		var rogue_output := float(attack_mods.get("player_damage",0.0))
		if rogue_output!=0.0: damage*=1.0+rogue_output
		damage*=RogueBuild.hit_multiplier(self,players[owner],e,build_context)
		e["build_shield_bonus"]=minf(.6,RogueBuild.r(players[owner],12,[.15,.25,.35])+(.30 if RogueBuild.weapon_id(players[owner])==34 else 0))
	if e.get("rogue_minion",false): damage=roguelike.combat.minions.absorb(self,roguelike.combat,e,damage,direction)
	var block := int(e.get("habitat",-1))
	if map_id=="border" and block>=0 and damage>0: ruins.sites[block].engaged=true
	var blocked := BossTactics.blocks(e,direction,weapon)
	if blocked:
		damage=BossTactics.absorb(self,e,damage,weapon)
		knock=0.0
	e.hp-=damage
	if roguelike.active(self): e["build_last_kind"]=str(build_context.get("kind","proc"))
	if roguelike.active(self) and players.has(owner) and hp_before>0:
		RogueBuild.hit_event(self,players[owner],e,minf(hp_before,maxf(0,damage)),e.hp<=0,build_context)
	e.last=owner
	e["flash"]=0.14
	if blocked:
		pass # Guard pressure replaces ordinary poise; a guard break keeps its stagger.
	elif e.get("rogue_guardian",false):
		knock=0.0
	elif e.get("raid_boss",false):
		knock=0.0
	elif e.type==4:
		e["poise"]=float(e.get("poise",0))+damage
		if e.poise>=220:
			e.poise=0.0
			e["attack_time"]=0.0
			e["stagger"]=1.1
			e.cd=1.5
		knock*=0.12
	elif e.type>=14:
		e["poise"]=float(e.get("poise",0))+damage
		if e.poise>=150:
			e.poise=0.0
			e["attack_time"]=0.0
			e["stagger"]=0.65
			e.cd=1.0
		knock*=0.08
	else:
		if e.get("rogue_minion",false) and e.attack_time>0:
			roguelike.combat.minion_event(self,e,"interrupt")
		e["attack_time"]=0.0
		e["stagger"]=0.12 if knock<40 else 0.26
	var impact: Vector2=e.p
	e.p=ruins.move(e.p,direction*knock)
	if players.has(owner):
		players[owner].hitstop=0.045 if knock<40 else 0.085
	var impact_data := {"kind":"impact","p":impact,"aim":direction,"damage":damage,"heavy":knock>=40,"id":owner,"weapon":weapon,"weapon_index":weapon_index if weapon_index>=0 else int(players.get(owner,{}).get("weapon",maxi(weapon,0))),"enemy_type":e.type,"rogue_floor":e.get("rogue_skin",-1),"enemy_id":e.id}
	if build_context.has("vfx"): impact_data["vfx"]=build_context.vfx
	broadcast_combat(impact_data)

func broadcast_audio(cue: String, p: Dictionary, variant: int = -1) -> void:
	broadcast_combat({"kind":"audio","cue":cue,"p":p.p,"id":p.get("id",0),"variant":variant})

func broadcast_combat(data: Dictionary) -> void:
	# Include the exact item, not just its animation family, for every client.
	var source: Dictionary=players.get(int(data.get("id",-1)),{})
	if not source.is_empty():
		if not data.has("weapon_index"): data["weapon_index"]=int(source.weapon)
		if not data.has("hero"): data["hero"]=int(source.hero)
		if not data.has("vfx"):
			data["vfx"]=weapon_visual_state(source)
	combat_event.emit(data)
	if online and authority():
		remote_combat.rpc(data)

func weapon_visual_state(p: Dictionary) -> Dictionary:
	if roguelike.active(self): return RogueBuild.visual_state(p)
	var tier := clampi(int(p.equipped.get("weapon",{}).get("tier",0)),0,5)
	if Catalog.is_starter(int(p.weapon)): tier=0
	return {"forge":0,"quality":tier,"quality_factor":1.0+Catalog.WEAPON_DAMAGE_BONUS[tier],"core":"","core_rank":0,"temper":""}

@rpc("authority","call_remote","reliable")
func remote_combat(data: Dictionary) -> void:
	combat_event.emit(data)

# Dropping the key, or walking away from the thing it was held on, ends a channel
# without anything happening. The HUD reads the same two fields, so the ring goes
# away with it.
func channel_cancel(p: Dictionary) -> void:
	p.channel=0
	p.target=""

func interact(p: Dictionary, held: bool, dt: float) -> void:
	if roguelike.active(self):
		if p.flask_time>0 or p.height>0: p.channel=0.0; p.target=""; return
		if roguelike.rescue(self,p,held,dt): return
		var pressed: bool=held and not p.get("rogue_interact_held",false)
		p.rogue_interact_held=held
		if pressed: roguelike.loot_interact(self,p)
		if held and p.p.x>ruins.fork_start and raid.phase in ["rogue_shop","rogue_exit"]:
			for index in raid.get("exits",[]).size():
				if p.p.distance_to(ruins.exit_position(index))<=64:
					roguelike.choose(self,p,"rogue_next",{"revision":raid.revision,"index":index})
					break
		return
	if not held:
		channel_cancel(p)
		return
	var target := ""
	var seconds := 0.25
	# E is the world's key: everything it does is held down, because everything it
	# does takes seconds and is worth interrupting. The gate comes first so a party
	# standing on it travels together rather than one Watcher lighting a shrine.
	if can_travel() and p.p.distance_to(portal_position())<85 and party_at_gate():
		target="portal:0"
		seconds=1.5
	for other in players.values():
		if other.id!=p.id and other.status=="down" and p.p.distance_to(other.p)<75:
			target="revive:%d" % other.id
			seconds=3.0
			break
	if target.is_empty():
		for i in ruins.exits.size():
			if can_extract() and p.p.distance_to(ruins.exits[i])<83:
				target="exit:%d" % i
				seconds=4.0
				break
	if target.is_empty():
		for i in ruins.shrines.size():
			if raid.phase not in ["choice","complete"] and not ruins.shrines[i].done and p.p.distance_to(ruins.shrines[i].p)<72:
				target="shrine:%d" % i
				seconds=3.0
				break
	if target.is_empty():
		channel_cancel(p)
		return
	# The countdown the HUD draws needs to know what the ring is counting to.
	p["channel_total"]=seconds
	p["channel_key"]=str(p.get("hits_taken",0))
	if p.target!=target:
		p.channel=0
		p.target=target
	else:
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
			emit_effect("extract",p.p)
		"revive":
			players[index].status="active"
			players[index].hp=players[index].max_hp*0.4
			players[index].invuln=2
			emit_effect("skill",p.p)
			broadcast_audio("heal",p)
		"shrine":
			ruins.shrines[index].done=true
			seal_bell(index)
			objectives+=1
			p.sanity=minf(100,p.sanity+20)
			emit_effect("bell",p.p)
			spawn_enemy(ruins.shrines[index].p+Vector2(0,240))

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

func spawn_enemy(at: Vector2 = Vector2.ZERO, type: int = -1, ambient: bool = false) -> void:
	if type < -1 or type>=Ecology.HEALTH.size(): return
	var pos := at
	var kind := type
	var block := -1
	if map_id=="border" and type!=4:
		# Retries remain within an eligible habitat, never on arbitrary map terrain.
		var candidates: Array[int]=[]
		for i in ruins.sites.size():
			if ruins.sites[i].get("cleared",false) or ruins.sites[i].get("engaged",false): continue
			if ambient:
				var nearby := false
				for player in players.values():
					if player.status=="active" and player.p.distance_squared_to(ruins.sites[i].p)<1400.0*1400.0:
						nearby=true
						break
				if not nearby: continue
			if type<0 or type in Ecology.POOLS[int(ruins.sites[i].biome)]: candidates.append(i)
		if candidates.is_empty(): return
		if at!=Vector2.ZERO:
			var requested := Ecology.block_at(ruins,at)
			if requested>=0 and (ruins.sites[requested].get("cleared",false) or ruins.sites[requested].get("engaged",false)): return
			if requested in candidates:
				candidates=[requested]
			else:
				var closest: int=candidates[0]
				for index in candidates:
					if ruins.sites[index].p.distance_squared_to(at)<ruins.sites[closest].p.distance_squared_to(at): closest=index
				candidates=[closest]
		var found := false
		var residents := {}
		for resident in enemies:
			if resident.hp>0:
				var habitat := int(resident.get("habitat",-1))
				residents[habitat]=int(residents.get(habitat,0))+1
		for attempt in (40 if ambient else 80):
			if attempt==0 and at!=Vector2.ZERO:
				block=Ecology.block_at(ruins,pos)
			else:
				block=candidates[rng.randi_range(0,candidates.size()-1)]
				var area: Rect2=ruins.sites[block].rect.grow(145)
				pos=area.position+Vector2(rng.randf(),rng.randf())*area.size
			if block<0 or not block in candidates or Ecology.block_at(ruins,pos)!=block: continue
			if int(residents.get(block,0))>=5: continue
			var near := false
			var in_ambient_range := false
			for p in players.values():
				if p.status!="active": continue
				var distance_sq: float=p.p.distance_squared_to(pos)
				if distance_sq<260.0*260.0: near=true
				if distance_sq>=AMBIENT_SPAWN_MIN*AMBIENT_SPAWN_MIN and distance_sq<=AMBIENT_SPAWN_MAX*AMBIENT_SPAWN_MAX:
					in_ambient_range=true
			if ambient and not in_ambient_range: continue
			var pool: Array=Ecology.POOLS[int(ruins.sites[block].biome)]
			kind=type if type>=0 else Ecology.random_kind(pool,rng)
			# Keep the same minimum terrain clearance guaranteed by the original
			# ecology contract, while still reserving extra room for large elites.
			if near or ruins.blocked(pos,maxf(25.0,Ecology.RADIUS[kind])): continue
			found=true
			break
		if not found: return
	else:
		if kind<0: kind=2
		if ruins.blocked(pos,25): return
	var difficulty := Ecology.difficulty(ruins.sites[block]) if block>=0 else (4 if map_id=="city" else 1)
	var participants := 0
	for p in players.values():
		if p.status in ["active","down"]: participants+=1
	var party_scale := 0.55 if kind>=14 else 0.30
	var health: float=Ecology.HEALTH[kind]*Ecology.HEALTH_SCALE[difficulty-1]*(1+party_scale*maxi(0,participants-1))
	if kind==4: health=Ecology.HEALTH[kind]*(1+0.55*maxi(0,participants-1))
	enemies.append({"id":next_enemy,"p":pos,"home":pos,"habitat":block,"type":kind,"hp":health,"max_hp":health,"cd":0.0,"last":1,"wander":Vector2.from_angle(rng.randf()*TAU),"facing":1.0,"motion_phase":0.0,"moving":false,"flash":0.0,"poise":0.0,"attack_time":0.0,"attack_total":0.0,"attack_released":false,"attack_target":0,"attack_aim":Vector2.RIGHT})
	enemies.back().merge({"difficulty":difficulty,"damage_scale":1.2 if kind==4 else Ecology.DAMAGE_SCALE[difficulty-1],"speed_scale":Ecology.SPEED_SCALE[difficulty-1]})
	next_enemy+=1

# Rewards are driven by actual defender deaths, never by an empty list during
# travel or boss transitions. Habitat ownership survives chasing out of a site.
func resolve_site_defeat(e: Dictionary) -> void:
	if roguelike.active(self): return
	if not authority() or map_id!="border" or e.get("raid_boss",false): return
	var block := int(e.get("habitat",-1))
	if block<0 or block>=ruins.sites.size(): return
	var site: Dictionary=ruins.sites[block]
	if site.get("cleared",false): return
	site.engaged=true
	site.defeated=int(site.get("defeated",0))+1
	if Ecology.remaining(self,block)>0: return
	site.cleared=true
	var quality := Ecology.difficulty(site)
	var size := 4 if quality==1 else (5 if quality==2 else 6)
	var chest := loot_container(site.p+Vector2(0,40),Vector2i(size,size),quality,true)
	chest.merge({"fixed_loot":true,"site_reward":block,"reward_tier":quality,"title":str(site.name)+" · "+Ecology.reward_label(site)})
	# Guaranteed equipment matches the site's danger, independent of the first
	# player's backpack. Place the valuable items before optional supplies.
	place_entry(chest,Catalog.make_equipment("weapon",Catalog.roll_weapon(rng),quality))
	place_entry(chest,Catalog.make_equipment("gear",rng.randi_range(0,Catalog.GEAR.size()-1),quality))
	place_entry(chest,{"kind":"backpack","key":Catalog.BAG_TIERS[quality].key})
	for i in quality-1: place_entry(chest,"relic")
	place_entry(chest,Catalog.biome_collectible(int(site.biome),block%3))
	for i in 1+quality/2:
		place_entry(chest,"medicine")
		place_entry(chest,"ammo")
	append_chest(chest)
	emit_effect("bell",chest.p)

func append_chest(chest: Dictionary) -> void:
	# Ground containers are indexed after chests; keep ongoing searches attached
	# to the same dropped bag when a new reward is inserted in front of them.
	for p in players.values():
		if search_reference(p)>=ruins.chests.size(): p.search_ref+=1
	ruins.chests.append(chest)

func update_enemies(dt: float) -> void:
	if roguelike.active(self) and raid.phase!="rogue_combat": return
	for e in enemies:
		if e.hp<=0:
			continue
		if e.get("boss_construct",false):
			e["flash"]=maxf(0,float(e.get("flash",0))-dt)
			continue
		if e.get("rogue_guardian",false) or e.get("rogue_minion",false):
			roguelike.combat.update(self,e,dt)
			continue
		if e.get("raid_boss",false):
			if e.get("wild_boss",false): wild_bosses.update(self,e,dt)
			else: expedition.update_boss(self,e,dt)
			continue
		if e.get("mini_boss",false):
			if e.get("dragon_boss",false): dragon_boss.update(self,e,dt)
			elif e.get("wild_boss",false): wild_bosses.update(self,e,dt)
			else: mini_bosses.update(self,e,dt)
			continue
		# Distant ordinary residents do not need pathfinding or collision checks.
		# Check every active player so a split party still wakes both regions.
		if e.type!=4:
			var awake := false
			for player in players.values():
				if player.status=="active" and e.p.distance_squared_to(player.p)<1600.0*1600.0:
					awake=true
					break
			if not awake:
				e["moving"]=false
				continue
		if e.type>=5:
			Ecology.update(self,e,dt)
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
					bullets.append(rogue_enemy_bolt({"p":e.p,"v":e.attack_aim*245,"life":2.0,"damage":Ecology.damage(e,Ecology.ATTACK_DAMAGE[e.type]),"owner":0}))
				elif not victim.is_empty() and victim.status=="active" and e.p.distance_to(victim.p)<58 and ruins.clear_line(e.p,victim.p):
					hurt(victim,Ecology.damage(e,Ecology.ATTACK_DAMAGE[e.type]))
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
			var speed: float=[120,105,82,150][e.type]*(1+threat*0.3)*float(e.get("speed_scale",1.0))
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

func hurt(p: Dictionary, damage: float, source: Dictionary = {}, height_tag: String = "normal", damage_tag: String = "direct", element: String = "physical") -> void:
	if roguelike.active(self):
		if not RogueActions.height_hit(float(p.height),height_tag): return
		if p.invuln>0 and p.dodge_time>0: RogueBuild.perfect(self,p)
	if p.invuln>0 or p.status!="active":
		return
	var received := incoming_damage(p,damage)
	if roguelike.active(self): received=RogueBuild.incoming(self,p,received,source,damage_tag,element)
	if roguelike.active(self): p.build_inputs=[]
	# E003「星纱法袍 / 法力吸收 20%」已经由上面这一行的 RogueBuild.incoming() 施加
	# （rogue_build.gd 里 `absorb_ratio := .20 if gear(p,3)`，并且按设计是「先耗法力再耗临时盾」）。
	# 这里曾再挂一个 RogueEquipment.has(p,"mana_guard") 的 30% 吸收：它长期是死代码（没有任何
	# 条目带 passive 字段），一旦有人给条目补上该字段就会**重复扣蓝**。已删除，避免双重结算。
	p.hp-=received
	p.invuln=0.3
	p.channel=0
	# Taking a hit is what a channel counts against: the key-held ring restarts
	# because channel is cleared here, and the standing ring restarts because this
	# tally no longer matches the one it recorded. Every source of damage goes
	# through this one function, so nothing can interrupt one and not the other.
	p["hits_taken"]=int(p.get("hits_taken",0))+1
	emit_effect("hurt",p.p)
	if p.hp<=0:
		down(p)
	else:
		broadcast_audio("hurt",p)

func update_bullets(dt: float) -> void:
	for i in range(bullets.size()-1,-1,-1):
		var b: Dictionary=bullets[i]
		var old: Vector2=b.p
		var old_height := float(b.get("height",0))
		if roguelike.active(self) and b.has("height"): b.height=maxf(0,float(b.height)+float(b.get("height_velocity",0))*dt)
		if b.get("boss_projectile",false): b["boss_previous"]=old
		var spell := str(b.get("spell","star"))
		if b.has("return_after"):
			b.age+=dt
			if not b.reversed and b.age>=b.return_after:
				b.v=-b.v
				b.reversed=true
		b.p+=b.v*dt
		b.life-=dt
		var wall_hit: bool=not (enemy_bodies.projectile_clear_line(ruins,old,b.p,roguelike.active(self)) if int(b.owner)>0 else ruins.clear_line(old,b.p))
		if wall_hit:
			b.life=0
		if b.life>0:
			if b.owner==0:
				for p in players.values():
					if p.status=="active" and Geometry2D.get_closest_point_to_segment(p.p,old,b.p).distance_to(p.p)<float(b.get("hit_radius",18.0)):
						var source: Dictionary={}
						for enemy in enemies:
							if enemy.id==int(b.get("boss_source",-1)): source=enemy; break
						hurt(p,b.damage,source)
						b.life=0
						break
			else:
				for e in enemies:
					if e.hp<=0 or (e.id in b.get("hit_ids",[])):
						continue
					var rogue: bool=roguelike.active(self)
					var projection: float=1.0 if rogue else enemy_bodies.GROUND_Y
					var from := old-Vector2(0,old_height/projection)
					var to: Vector2=b.p-Vector2(0,float(b.get("height",0))/projection)
					var ground_origin: Vector2=b.get("ground_origin",players.get(b.owner,{}).get("p",old))
					if enemy_bodies.segment_hit(e,from,to,elapsed,rogue,18.0 if spell in ["moon","eclipse"] else 0.0) and ruins.clear_line(ground_origin,e.p):
						if spell in ["meteor","vortex"]:
							spell_burst(b,e.p)
						else:
							var dealt: float=b.damage
							var attenuation: Array=b.get("build_attenuation",[])
							var pierce_count: int=b.get("hit_ids",[]).size()
							if not attenuation.is_empty(): dealt*=float(attenuation[mini(pierce_count,attenuation.size()-1)])
							if spell=="scatter":
								var pellet_hits: Dictionary=b.pellet_hits
								var previous := int(pellet_hits.get(e.id,0))
								if previous>0: dealt*=0.12
								pellet_hits[e.id]=previous+1
							damage_enemy(e,dealt,b.owner,b.v.normalized(),float(b.get("knock",16.0)),int(b.get("weapon",0)),int(b.get("weapon_index",-1)),b.get("build_context",{}))
							if spell=="chain":
								spell_chain(b,e)
						if not b.has("hit_ids"):
							b["hit_ids"]=[]
						b.hit_ids.append(e.id)
						b.remaining=int(b.get("remaining",1))-1
						if b.remaining<=0 or spell in ["meteor","vortex"]:
							b.life=0
							break
		if b.life<=0:
			if b.get("boss_projectile",false): BossChoreography.projectile_end(self,b)
			if b.has("rogue_tone"):
				broadcast_combat({"kind":"rogue-projectile-impact","p":old if wall_hit else b.p,"floor":b.rogue_tone})
			if spell in ["meteor","vortex"] and b.get("hit_ids",[]).is_empty():
				spell_burst(b,old if wall_hit else b.p)
			bullets.remove_at(i)

func spell_burst(b: Dictionary, at: Vector2) -> void:
	var spell := str(b.get("spell",""))
	var radius := (100.0 if spell=="meteor" else 90.0) if roguelike.active(self) else 115.0 if spell=="meteor" else 135.0
	var build_hits := 0
	var direction: Vector2=b.v.normalized()
	for e in enemies:
		if e.hp<=0 or not enemy_bodies.attack_hit(e,at,direction,radius,elapsed,roguelike.active(self),"circle") or not ruins.clear_line(at,e.p):
			continue
		var pull: Vector2=(at-e.p).normalized()
		damage_enemy(e,float(b.damage)*((1.0 if build_hits==0 else .60) if roguelike.active(self) else (1.0-minf(1.0,e.p.distance_to(at)/radius)*0.35)),int(b.owner),direction,float(b.get("knock",0.0)) if spell=="meteor" else 0.0,3,int(b.get("weapon_index",-1)),b.get("build_context",{}))
		build_hits+=1
		if spell=="vortex" and e.hp>0 and not e.get("rogue_guardian",false):
			e.p=ruins.move(e.p,pull*(35 if roguelike.active(self) else 42))
	var burst_data := {"kind":"spell_burst","p":at,"spell":spell,"id":int(b.owner),"weapon_index":int(b.get("weapon_index",players.get(b.owner,{}).get("weapon",3)))}
	if b.get("build_context",{}).has("vfx"): burst_data["vfx"]=b.build_context.vfx
	broadcast_combat(burst_data)

func spell_chain(b: Dictionary, first: Dictionary) -> void:
	var visited: Array=[first.id]
	var from: Dictionary=first
	for hop in (2 if roguelike.active(self) else 3):
		var nearest: Dictionary={}
		var best: float=160.0+RogueBuild.r(players.get(b.owner,{}),43,[15,25,35]) if roguelike.active(self) else 175.0
		for e in enemies:
			var distance: float=e.p.distance_to(from.p)
			if e.hp>0 and not (e.id in visited) and distance<best and ruins.clear_line(from.p,e.p):
				nearest=e
				best=distance
		if nearest.is_empty():
			break
		var arc_data := {"kind":"spell_arc","p":from.p,"target":nearest.p,"spell":"chain","id":int(b.owner),"weapon_index":int(b.get("weapon_index",6))}
		if b.get("build_context",{}).has("vfx"): arc_data["vfx"]=b.build_context.vfx
		broadcast_combat(arc_data)
		var direction: Vector2=(nearest.p-from.p).normalized()
		damage_enemy(nearest,float(b.damage)*([.45,.30][hop] if roguelike.active(self) else pow(.68,hop+1)),int(b.owner),direction,8.0,3,int(b.get("weapon_index",-1)),b.get("build_context",{}))
		visited.append(nearest.id)
		from=nearest

func emit_effect(kind: String, pos: Vector2) -> void:
	effect.emit(kind,pos)
	if online:
		remote_effect.rpc(kind,pos)

@rpc("authority","call_remote","unreliable")
func remote_effect(kind: String, pos: Vector2) -> void:
	effect.emit(kind,pos)

func settle() -> void:
	if roguelike.active(self):
		roguelike.settle(self)
		return
	if not running:
		return
	results.clear()
	for id in players:
		var p: Dictionary=players[id]
		var extracted: bool=p.status=="extracted"
		# Extraction banks both containers; death already scattered the backpack
		# in down(), so only the sealed pocket survives it.
		var loot := Catalog.market_total(p.backpack.items)+Catalog.market_total(p.pocket.items) if extracted else Catalog.market_total(p.pocket.items)
		var shared := objectives*55+(100 if objectives==3 else 0)+int(p.get("boss_reward",0))
		var hidden := bool(p.get("hidden_ending",false))
		if hidden:
			shared+=expedition.HIDDEN_REWARD
		results[id]={"name":p.name,"escaped":extracted,"loot":loot,"shared":shared,"kills":p.kills,"coins":shared,"hidden":hidden,"xp":35+p.kills*8+objectives*25+(60 if extracted else 0)+(240 if hidden else 0),"pocket":Catalog.clean_container(p.pocket,Catalog.POCKET_GRID),"bags":saved_bags(p,extracted),"worn":worn_names(p),"loadout":saved_loadout(p,extracted)}
	running=false
	finished.emit()
	if online:
		receive_results.rpc(results,players)

# What the player was wearing when the run ended, for the report screen.
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

# What the save file keeps of the worn kit. Walking out alive keeps it on the
# Watcher: it is written straight back into the loadout, so the next raid starts
# dressed in it. Dying scatters it in `spill_storage()`, which leaves nothing to
# keep. Either way its value stays out of the loot total — the piece is still owned,
# so pricing it as fresh loot would pay for the same item twice.
func saved_loadout(p: Dictionary, extracted: bool) -> Dictionary:
	var loadout := Catalog.empty_loadout()
	if not extracted:
		return loadout
	var equipped = p.get("equipped",{})
	if equipped is Dictionary:
		loadout["weapon"]=equipped.get("weapon",{})
		loadout["gear"]=equipped.get("gear",loadout["gear"])
		loadout["charm"]=equipped.get("charm",loadout["charm"])
	loadout["slots"]=item_slots(p)
	return Catalog.clean_loadout(loadout)

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
			players[id].ready=id==leader_id
	push_lobby()

func portal_position() -> Vector2:
	return RoyalCity.GATE if map_id=="city" else CITY_GATE

func party_at_gate() -> bool:
	for p in players.values():
		if p.status=="down": return false
		if p.status=="active" and p.p.distance_to(portal_position())>240: return false
	return true

func travel_city(forced: bool = false) -> bool:
	if not authority() or not running: return false
	if not forced and (not can_travel() or not party_at_gate()): return false
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
		if p.status in ["active","down"]:
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
	var chest := loot_container(at,Vector2i(7,7),3,true)
	chest["fixed_loot"]=true
	chest["title"]="失乡骑士的王庭珍藏"
	for kind in Catalog.ROYAL_COLLECTIBLES: place_entry(chest,kind)
	place_entry(chest,"eternal_night_thronecore")
	place_entry(chest,Catalog.make_equipment("weapon",2,5))
	for i in 3: place_entry(chest,Catalog.make_equipment("gear",i,4))
	place_entry(chest,{"kind":"backpack","key":"gold"})
	for i in 3: place_entry(chest,{"kind":"relic"})
	chest["open"]=true
	append_chest(chest)
	emit_effect("bell",at)

func update_knight(e: Dictionary, dt: float) -> void:
	e["flash"]=maxf(0,float(e.get("flash",0))-dt)
	e["stagger"]=maxf(0,float(e.get("stagger",0))-dt)
	e["moving"]=false
	e.cd=maxf(0,e.cd-dt)
	var phase := 2 if e.hp<=e.max_hp*0.5 else 1
	if phase!=int(e.get("phase",1)):
		e["phase"]=phase
		BossPresentation.send(self,e,"phase")
	if not e.get("presentation_seen",false):
		for observer in players.values():
			if observer.status=="active" and observer.p.distance_to(e.p)<650 and ruins.clear_line(e.p,observer.p):
				e["presentation_seen"]=true
				BossPresentation.send(self,e,"entrance")
				break
	BossTactics.tick(self,e,dt)
	if e.stagger>0 or BossTactics.update_guard(e,dt): return
	if e.attack_time>0 and e.get("choreo_cast",false):
		e.attack_time=maxf(0,e.attack_time-dt)
		return
	if e.attack_time>0:
		var before: float=e.attack_total-e.attack_time
		e.attack_time=maxf(0,e.attack_time-dt)
		var passed: float=e.attack_total-e.attack_time
		var move_name: String=e.get("move_name","combo")
		var spec: Dictionary=BossTactics.KNIGHT_MOVES.get(move_name,BossTactics.KNIGHT_MOVES.combo)
		var marks: Array=spec.marks
		# Locked aim is never retargeted after anticipation begins.
		if move_name=="thrust" and passed>0.85 and before<1.20:
			var step: float=maxf(0,minf(passed,1.20)-maxf(before,0.85))
			e.p=ruins.move(e.p,e.attack_aim*800*step)
			e["moving"]=true
			e.motion_phase+=step*20
			for p in players.values():
				if not e.get("hit_ids",[]).has(p.id) and p.p.distance_to(e.p)<75 and ruins.clear_line(e.p,p.p):
					hurt(p,Ecology.damage(e,32))
					e.hit_ids.append(p.id)
		for strike in marks.size():
			if before<marks[strike] and passed>=marks[strike]:
				e["attack_released"]=true
				var shape := "line" if move_name=="thrust" else "ring" if move_name=="storm" else "cone"
				BossPresentation.send(self,e,"release",{"move":move_name,"shape":shape,"radius":340.0 if shape=="line" else spec.reach,"inner":0.0,"total":marks[strike],"part":strike})
				for p in players.values():
					var delta: Vector2=p.p-e.p
					var reach: float=spec.reach
					var arc: float=spec.arc
					if delta.length()<reach and absf(e.attack_aim.angle_to(delta))<arc and ruins.clear_line(e.p,p.p):
						hurt(p,Ecology.damage(e,float(spec.damage[strike])))
		return
	var target: Dictionary={}
	var best := 780.0
	for p in players.values():
		if p.status=="active" and p.p.distance_to(e.p)<best:
			best=p.p.distance_to(e.p)
			target=p
	if target.is_empty(): return
	var aim: Vector2=(target.p-e.p).normalized()
	var response := BossTactics.response(self,e)
	if not response.is_empty():
		if response.kind=="attack" and BossTactics.start_guard(e,response.aim,self): return
		if response.kind!="attack":
			var move: String=BossChoreography.names(e)[2 if response.kind=="counter" else 1 if response.kind=="dodge" else 0]
			start_knight_attack(e,move,response.aim)
			return
	if not e.get("reaction",{}).is_empty(): return
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	if e.cd<=0 and best<360 and ruins.clear_line(e.p,target.p):
		var sequence := int(e.get("sequence",0))
		var move_name: String=BossChoreography.choose(e)
		if best>240 and move_name in ["combo","quick","delayed"]: move_name="thrust"
		e["sequence"]=sequence+1
		if move_name=="guard":
			if BossTactics.start_guard(e,aim,self): return
			move_name="delayed"
		start_knight_attack(e,move_name,aim)
	elif best>115:
		var previous: Vector2=e.p
		var speed := 190.0 if e.hp<=e.max_hp*0.5 else 165.0
		e.p=ruins.move(e.p,aim*speed*dt)
		if e.p.distance_to(previous)<1: e.p=ruins.move(e.p,aim.orthogonal()*speed*dt)
		e.moving=e.p.distance_to(previous)>0.01
		e.motion_phase+=e.p.distance_to(previous)/12

func start_knight_attack(e: Dictionary, move: String, aim: Vector2) -> void:
	if BossChoreography.start(self,e,move,aim,e.p+aim*180): return
	var spec: Dictionary=BossTactics.KNIGHT_MOVES[move]
	e["move_name"]=move
	e["hit_ids"]=[]
	e["attack_marks"]=spec.marks.duplicate()
	e.attack_aim=aim
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	e.attack_total=spec.total
	e.attack_time=e.attack_total
	e.attack_released=false
	e.cd=e.attack_total+(0.25 if e.hp<=e.max_hp*0.5 else 0.4)
	BossPresentation.send(self,e,"charge",{"move":move,"total":spec.marks[0]})
