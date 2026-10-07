extends RefCounted

const RogueMap = preload("res://scripts/rogue_map.gd")
const Variants = preload("res://scripts/rogue_variants.gd")
# R5 (contract C1/C2): the fixed seven-slot route is replaced by a per-floor node graph.
# preloaded instead of the bare class name so headless runs never depend on the class cache.
const NodeGraph = preload("res://scripts/rogue_graph.gd")
const Equipment = preload("res://scripts/rogue_equipment.gd")
const Build = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")
# W1b: the dedicated-room / economy layers. Preloaded (never a bare class name) so headless
# runs and a stale class cache can never break the parse step.
const Curses = preload("res://scripts/rogue_curses.gd")
const Events = preload("res://scripts/rogue_events.gd")
const Rooms = preload("res://scripts/rogue_rooms.gd")
const Growth = preload("res://scripts/rogue_growth.gd")
const Daily = preload("res://scripts/rogue_daily.gd")
var combat = preload("res://scripts/rogue_combat.gd").new()
var loot_serial := 0 # Never reuse a selection id, even after restarting a run.

const FLOORS := ["幽光菌林", "魔焰铸炉", "星晶幻境", "风暴空港", "黑曜魔宫"]
const AREAS_PER_FLOOR := 7
# Contracts §7.1: the legal room names. The five new ones are produced by RogueGraph and
# must be listed here or the HUD (`main.gd:1560`) and the region art lookup would miss them.
const ROOM_NAMES := {"combat":"魔物围猎", "elite":"精英试炼", "shop":"游商营火", "treasure":"遗落宝藏",
	"talent":"灵契圣坛", "boss":"守层者", "curse":"诅咒回廊", "event":"幽暗异事",
	"forge":"熔炉工坊", "gamble":"赌徒帐幕", "mirror":"镜像试炼"}
const ROOM_DESCS := {"combat":"迎战魔物 · 通关奖励", "elite":"更强敌人 · 更高品质装备",
	"shop":"安全补给 · 消耗魔晶购买", "treasure":"安全宝藏 · 免费选择装备",
	"talent":"灵契圣坛 · 两轮天赋三选一", "curse":"诅咒回廊 · 以代价换取秘藏",
	"event":"幽暗异事 · 抉择各有后果", "forge":"熔炉工坊 · 强化手中武器",
	"gamble":"赌徒帐幕 · 押注魔晶博取翻倍", "mirror":"镜像试炼 · 直面自己的影子",
	"boss":"击败首领，进入下一层"}
# Contracts §7.2 ②: rooms that are NOT combat long-rooms. Missing one here silently turns a
# new room into a combat lane (`session.gd:1501` has the client-side copy of this list).
const SAFE_ROOMS := ["shop","treasure","talent","curse","event","forge","gamble","mirror"]
# Service rooms pay through their own actions, rather than a free combat chest.
const CHEST_ROOMS := ["combat","elite","boss","treasure"]
const BOONS := [
	{"name":"赤刃誓约", "desc":"伤害 +12%", "stat":"rogue_damage", "value":0.12},
	{"name":"不屈之心", "desc":"最大生命 +22，立即回复 22", "stat":"rogue_hp", "value":22.0},
	{"name":"巡夜轻步", "desc":"移动速度 +18", "stat":"rogue_speed", "value":18.0},
	{"name":"黑铁庇护", "desc":"受到伤害降低 6%（最高 40%）", "stat":"rogue_defense", "value":0.06},
	{"name":"晨钟甘露", "desc":"恢复 45% 生命与全部蓝量", "stat":"heal", "value":0.45}
]

func active(s) -> bool:
	return s.raid.get("mode","")=="roguelike"

# ---------------------------------------------------------------------------
# W1b · 数值钩子（变数 / 诅咒 / 房间 / 结算）
# ---------------------------------------------------------------------------
# `session.rogue_mods()` 是"变数 + 诅咒"数值的**唯一**实现；这里只是转发，避免经济钩子
# 与战斗钩子各算一套而漂移。会话没有该方法时（桩会话 / 旧版本）退化为"全队共享的变数"。
# 铁律：不消耗 s.rng、不重置种子、绝不产出命中判定几何键。

func run_mods(s, p: Dictionary = {}) -> Dictionary:
	if s == null: return {}
	if s.has_method("rogue_mods"):
		return s.rogue_mods(p)
	var ids: Array=[]
	var id := str(s.raid.get("variant",""))
	if id != "": ids.append(id)
	return Variants.modifiers_of(ids)

func mod_of(s, key: String, p: Dictionary = {}) -> float:
	return float(run_mods(s,p).get(key,0.0))

## 把基础数值乘上一个倍率并取整。倍率恰好 1.0 时**逐位返回原值**，
## 因此"本局没有变数"的路径与 W1b 之前的数字完全一致。
func scale_int(base: int, scale: float) -> int:
	if is_equal_approx(scale,1.0): return base
	return int(round(float(base)*scale))

## profile.data 的探测链与 `RogueGrowth._session_profile_data()` 保持一致（方法 → meta → 空）。
func profile_data_of(s) -> Dictionary:
	if s == null: return {}
	if s.has_method("profile_data"):
		var via_method: Variant=s.profile_data()
		if via_method is Dictionary: return via_method
	if s.has_meta("profile_data"):
		var via_meta: Variant=s.get_meta("profile_data")
		if via_meta is Dictionary: return via_meta
	return {}

func first_player(s) -> Dictionary:
	var fallback: Dictionary={}
	for p in s.players.values():
		if fallback.is_empty(): fallback=p
		if str(p.get("status",""))=="active": return p
	return fallback

func reset(s) -> void:
	s.raid={"mode":"roguelike", "day":1, "floor":1, "area":1, "phase":"rogue_combat", "time":0.0, "kind":0, "center":Ruins.CENTER, "hazards":[], "cleared":0, "offers":[], "revision":0, "route":[], "ended":false,
		# Contracts §2 (frozen): every new raid key must exist with its default here,
		# because the whole dict is shipped verbatim as snapshot element 11.
		"variant":"", "variant_serial":0, "curse_serial":0, "seed_shared":"", "daily":false,
		"node":"", "depth":1, "pending_event":{}, "pending_forge":{}, "pending_gamble":{},
		"mirror_state":{}, "graph_floor":0,
		# CHANGE-LOG v2 (R5, approved): the 13th raid key. Variants are rolled per floor and
		# `RogueVariants.roll()` reads this list to avoid repeating one inside a single run.
		"variants_seen":[]}
	# W1b (contract v3-2): the daily challenge is whichever run the host launched with the UTC
	# daily seed. Every client receives that seed through begin(), so the flag is *derived*
	# from it rather than each client computing its own local date. `seed_shared` stays at its
	# frozen default ("") — it is the display field R7's seed screen writes, not ours.
	var launched_seed := int(s.get("seed_value"))
	s.raid["daily"]=launched_seed==Daily.global_daily_seed()
	# W1b (R12 hook 3): the meta growth tree only pays into the *starting* purse. Without a
	# profile channel `power()` is all zeros, so the shipped numbers are bit-identical.
	var meta: Dictionary=Growth.power(profile_data_of(s))
	# The new mode is a fresh run; carried campaign storage is never risked.
	for p in s.players.values():
		p.pocket=Catalog.clean_container({},Catalog.POCKET_GRID)
		p.backpack=Catalog.make_bag("blue")
		p.bags=[]
		p.rogue_medicine=0 # Campaign medicine never enters this mode.
		p.rogue_boons={}
		p.rogue_stash=[]
		p.rogue_inventory_revision=0
		p.rogue_siphon_cd=0.0
		p.rogue_spell_heal_cd=0.0
		p.rogue_soul_cd=0.0
		p.rogue_gold=60+int(meta.get("start_coins",0))
		# Contracts §3 (frozen): curses are personal while the abyss variant is shared.
		p.rogue_curses=[]
		p.rogue_ash_run=0
		p.rogue_mirror_used=false
		p.rogue_rerolls=int(p.get("rogue_rerolls",0))+int(meta.get("start_rerolls",0))
		p.rogue_damage=0.0
		p.rogue_hp=0.0
		p.rogue_speed=0.0
		p.rogue_defense=0.0
		var weapon: int=int(p.get("rogue_weapon",-1))
		Build.reset(s,p)
		if weapon>=0 and weapon<Catalog.WEAPONS.size():
			for i in Content.data.weapons.size():
				if Content.data.weapons[i].name==Catalog.weapon(weapon).name: equip(s,p,Content.make_weapon(i,0)); break
		p.build_reward_queue.append("starter")
	Build.departure(s)
	new_floor(s)
	enter(s)
	s.raid.phase="rogue_prepare"
	for p in s.players.values(): next_personal(s,p)
	s.message.emit("选择开局武器 · 永久战力修正：敌人生命×%.2f / 伤害×%.2f" % [s.raid.build_enemy_hp,s.raid.build_enemy_damage])

func new_floor(s) -> void:
	# R5: the floor's rooms come from the deterministic node graph. `route` becomes the
	# per-floor room template (index = depth - 1) so slot-based callers keep working.
	s.rogue_graph=NodeGraph.build(int(s.seed_value),int(s.raid.floor))
	dress_floor(s)
	s.raid.node=str(s.rogue_graph.get("entry",""))
	fill_floor_route(s)

## The generator fixes the shape of the floor (depths, branches, guardian) but not its
## content. A room that only exists on the branch nobody walked is not a guarantee, so the
## run's per-floor needs are secured on rows whose branches all supply the same service:
## one supply row and one sanctuary row. Only `kind` strings change — depths, edges and the
## floor guardian never move, and the sanctuary count never exceeds the generator's cap of 2.
func dress_floor(s) -> void:
	var rows: Dictionary={}
	for id in s.rogue_graph.get("order",[]):
		var depth := int(NodeGraph.node(s.rogue_graph,str(id)).get("depth",0))
		if not rows.has(depth): rows[depth]=[]
		rows[depth].append(str(id))
	var supply_row := 0
	var sanctuary_row := 0
	for depth in range(2,depth_count(s)-1):
		var supply_ok := true
		var sanctuary_ok := true
		for id in rows.get(depth,[]):
			var kind := str(NodeGraph.node(s.rogue_graph,str(id)).kind)
			supply_ok=supply_ok and kind in ["shop","treasure"]
			sanctuary_ok=sanctuary_ok and kind=="talent"
		if supply_ok: supply_row=depth
		if sanctuary_ok: sanctuary_row=depth
	if supply_row==0:
		supply_row=3 if sanctuary_row==2 else 2
		var index := 0
		for id in rows[supply_row]:
			s.rogue_graph["nodes"][id]["kind"]="shop" if index==0 else "treasure"
			index+=1
	if sanctuary_row==0:
		sanctuary_row=3 if supply_row==2 else 2
		# Two alternative sanctuary nodes count as one visit on every route.
		for id in s.rogue_graph.get("order",[]):
			if str(NodeGraph.node(s.rogue_graph,str(id)).kind)=="talent":
				s.rogue_graph["nodes"][str(id)]["kind"]="combat"
		for id in rows[sanctuary_row]:
			s.rogue_graph["nodes"][id]["kind"]="talent"

## One default room kind per depth (the first node at that depth). Entries a caller already
## wrote are kept: they are the explicit per-room override used by tests and debug jumps.
func fill_floor_route(s) -> void:
	var defaults: Array=[]
	var total := depth_count(s)
	for depth in range(1,total+1):
		var id := node_at_depth(s.rogue_graph,depth)
		defaults.append(str(NodeGraph.node(s.rogue_graph,id).get("kind","combat")) if id!="" else "combat")
	if s.raid.route.size()!=defaults.size(): s.raid.route.resize(defaults.size())
	for i in defaults.size():
		var current=s.raid.route[i]
		if typeof(current)!=TYPE_STRING or not ROOM_NAMES.has(str(current)):
			s.raid.route[i]=defaults[i]

## Number of rooms on the current floor (= deepest node depth, 7..9).
func depth_count(s) -> int:
	var graph: Dictionary=s.rogue_graph
	if graph.is_empty(): return AREAS_PER_FLOOR
	var boss: Dictionary=NodeGraph.node(graph,str(graph.get("boss","")))
	return maxi(1,int(boss.get("depth",AREAS_PER_FLOOR)))

## First node id at a given depth ("" when the depth does not exist).
func node_at_depth(graph: Dictionary, depth: int) -> String:
	for id in graph.get("order",[]):
		if int(NodeGraph.node(graph,str(id)).get("depth",0))==depth: return str(id)
	return ""

## Resolve the node the players are entering; falls back to the entry node when stale.
func resolve_node(s) -> Dictionary:
	var graph: Dictionary=s.rogue_graph
	var info: Dictionary=NodeGraph.node(graph,str(s.raid.get("node","")))
	var wanted := clampi(int(s.raid.area),1,depth_count(s))
	# Compatibility path: a caller that jumps by writing `raid.area` (tests, debug views)
	# enters the first node of that depth. The shipped flow never has area > node depth.
	if info.is_empty() or wanted>int(info.get("depth",1)):
		var picked := node_at_depth(graph,wanted)
		if picked!="":
			s.raid.node=picked
			info=NodeGraph.node(graph,picked)
	if info.is_empty():
		s.raid.node=str(graph.get("entry",""))
		info=NodeGraph.node(graph,str(s.raid.node))
	return info

## Room kind for the entered node; an explicit `route[depth-1]` write wins (see fill_floor_route).
func room_for(s, info: Dictionary) -> String:
	var depth := int(info.get("depth",1))
	var fallback := str(info.get("kind","combat"))
	if s.raid.route.size()>=depth:
		var current=s.raid.route[depth-1]
		if typeof(current)==TYPE_STRING and ROOM_NAMES.has(str(current)) and (str(current)!="boss" or fallback=="boss"):
			return str(current)
	return fallback

func enter(s) -> void:
	combat.reset()
	s.raid["rogue_corpses"]=[]
	s.enemies.clear()
	s.bullets.clear()
	s.world_drops.clear()
	s.pending_ultimates.clear()
	s.soul_reaps.clear()
	s.fire_zones.clear()
	s.ruins.chests.clear()
	s.ruins.shrines.clear()
	s.ruins.exits.clear()
	s.ruins=RogueMap.new()
	# Contracts C1/C2/§6.2: a new floor builds its node graph once (graph RNG is local) and
	# rolls the abyss variant exactly once — both strictly before exit_choices().
	var fresh: bool = int(s.raid.get("graph_floor",-1))!=int(s.raid.floor) or s.rogue_graph.is_empty()
	if fresh:
		new_floor(s)
		s.raid["graph_floor"]=int(s.raid.floor)
		Variants.roll(s)
		var rolled := str(s.raid.get("variant",""))
		if rolled!="" and rolled not in s.raid["variants_seen"]: s.raid["variants_seen"].append(rolled)
	var info: Dictionary=resolve_node(s)
	var room: String=room_for(s,info)
	s.raid.depth=int(info.get("depth",1))
	s.raid.area=int(info.get("depth",1))
	s.ruins.generate(s.seed_value+int(s.raid.floor)*100+int(s.raid.area))
	s.ruins.configure(int(s.raid.floor)-1,int(s.raid.area),room not in SAFE_ROOMS,room)
	s.map_id="rogue"
	s.raid.center=Vector2(720,575)
	s.raid.day=1 # The campaign dawn/finale hooks must never run here.
	s.raid.time=0.0
	s.raid.room=room
	if int(s.raid.area)==1: s.raid["rooms_seen"]=[]
	s.raid.rooms_seen.append(room)
	if s.raid.route.size()<int(s.raid.depth): s.raid.route.resize(int(s.raid.depth))
	s.raid.route[int(s.raid.depth)-1]=room
	s.raid["exits"]=exit_choices(s)
	s.raid.revision+=1
	s.raid.offers=[]
	s.raid["reward_claims"]=[]
	s.raid["reward_chest"]={}
	s.raid["room_rewarded"]=false
	s.raid["reward_drops"]=[]
	var spawn_index := 0
	for p in s.players.values():
		p.rogue_selection={}
		p.rogue_interact_held=false
		s.stop_search(p)
		p.p=Vector2(330+spawn_index*45,s.ruins.lane_center(330+spawn_index*45))
		spawn_index+=1
		p.invuln=2.0
		p.pending_strike=false
		p.swing_time=0.0
		p.sanity=100.0
		p.reserve=96
		p["rogue_rescued_room"]=false
		p.height=0.0; p.height_velocity=0.0; p.build_summons=[]; p.build_fields=[]; p.build_inputs=[]
	if s.raid.room=="shop":
		s.raid.phase="rogue_shop"
		roll_offers(s,true)
	elif s.raid.room in SAFE_ROOMS:
		# Contracts §7.2 ②: every dedicated (non-combat) room, including the new ones,
		# resolves through clear_room() and never spawns a wave. W1b: the dedicated rooms roll
		# their own payoff once first, so their pending state carries *this* room's revision.
		open_room(s)
		clear_room(s)
		# The service rooms must quote the revision that `clear_room()` just produced, otherwise
		# the player's very first click would look stale to the revision guard. No-op elsewhere.
		refresh_dedicated(s)
	else:
		s.raid.phase="rogue_combat"
		s.raid.wave=1
		spawn_wave(s)
	s.message.emit("第 %d 层 · 第 %d 区：%s" % [s.raid.floor,s.raid.area,ROOM_NAMES.get(s.raid.room,s.raid.room)])

func spawn_wave(s) -> void:
	var boss_wave: bool=s.raid.room=="boss" and int(s.raid.wave)==3
	var floor_index: int=int(s.raid.floor)-1
	var count: int=1 if boss_wave else 6+floor_index+(2 if s.raid.room=="elite" else 0)
	# W1b: `elite_chance` (R8 hook j) widens the elite prefix. Zero when no variant is active,
	# which keeps the pre-W1b selection exactly as it was.
	var extra_elite := int(round(maxf(0.0,mod_of(s,"elite_chance"))/0.12))
	var center: float=[760.0,1530.0,2360.0][int(s.raid.wave)-1]
	var variants: Array=[]
	var pool: Array=[0,1,2,3,4,5,6,7]
	var support_count := 0
	var summon_count := 0
	for i in count:
		var choices: Array=[]
		for v in pool:
			var role: String=combat.minions.ROLES[floor_index][v]
			if i<2 and role not in ["front","melee","ambush"]: continue
			if role in ["heal","buff"] and support_count>=2: continue
			if role=="summon" and summon_count>=1: continue
			choices.append(v)
		if choices.is_empty(): choices=[0,1,2,3]
		var selected: int=choices[s.rng.randi_range(0,choices.size()-1)]
		variants.append(selected)
		pool.erase(selected)
		var role: String=combat.minions.ROLES[floor_index][selected]
		if role in ["heal","buff"]: support_count+=1
		if role=="summon": summon_count+=1
		if pool.is_empty(): pool=[0,1,2,3]
	# Shuffle with the run RNG so species do not occupy fixed spawn slots.
	for i in range(variants.size()-1,0,-1):
		var j: int=s.rng.randi_range(0,i)
		var previous: int=variants[i]
		variants[i]=variants[j]
		variants[j]=previous
	for i in count:
		var at: Vector2=spawn_point(s,Vector2(center,s.ruins.lane_center(center))) if boss_wave else dispersed_spawn_point(s,center)
		if boss_wave:
			s.spawn_enemy(at,4)
			# R14: hand the session over so the floor guardian comes from the expanded pool;
			# the pool is derived from `(seed_value, floor)` with a local shuffle, never s.rng.
			combat.setup_boss(s.enemies.back(),floor_index,s)
			s.enemies.back()["build_xp_reward"]=maxi(1,scale_int(20,1.0+mod_of(s,"xp_gain")))
			Build.enemy_budget(s,s.enemies.back())
			if s.raid.get("challenge",false):
				s.enemies.back().max_hp*=1.25
				s.enemies.back().hp=s.enemies.back().max_hp
			s.message.emit(str(s.enemies.back().get("boss_name",combat.NAMES[floor_index]))+"降临！")
		else:
			# Draw a varied local roster with capped support and summoning pressure.
			# W1b: `elite_chance` widens the elite prefix deterministically (no extra rng draw),
			# so a variant can raise elite pressure without perturbing the seeded stream.
			spawn_minion(s,at,floor_index,int(variants[i]),s.raid.room=="elite" and i<2+extra_elite)

func dispersed_spawn_point(s, center: float) -> Vector2:
	var left := maxf(180.0,center-230.0)
	var right := minf(s.ruins.width-180.0,center+650.0)
	var best := Vector2.ZERO
	var best_clearance := -1.0
	# Sample the whole encounter section, choosing open space rather than a grid.
	# Random candidates preserve seeded runs while maximin spacing prevents clumps.
	var candidates: Array[Vector2]=[]
	for i in 96:
		candidates.append(Vector2(s.rng.randf_range(left,right),s.rng.randf_range(s.ruins.ground_y(s.ruins.ground_top.min())+35,s.ruins.ground_y(s.ruins.ground_lower.max())-35)))
	# Narrow necks and lava can invalidate many random samples; include safe fallbacks.
	for x in range(int(left),int(right),35):
		for y in range(int(s.ruins.ground_y(s.ruins.ground_top.min()))+35,int(s.ruins.ground_y(s.ruins.ground_lower.max()))-34,30): candidates.append(Vector2(x,y))
	for candidate in candidates:
		if s.ruins.blocked(candidate,31) or s.ruins.on_lava(candidate): continue
		var clearance := INF
		for e in s.enemies: clearance=minf(clearance,candidate.distance_to(e.p))
		for p in s.players.values():
			if p.status=="active": clearance=minf(clearance,candidate.distance_to(p.p)*0.55)
		if clearance>best_clearance:
			best=candidate
			best_clearance=clearance
		# Prefer random positions with ample breathing room; grid is fallback only.
		if best_clearance>=150.0: return best
	# Dense elite waves may fill their first section. Expand slightly rather than
	# stacking another monster on an occupied spawn or putting it near a player.
	if best_clearance<100.0:
		for x in range(int(180.0),int(s.ruins.fork_start-80.0),25):
			for y in range(int(s.ruins.ground_y(s.ruins.ground_top.min()))+35,int(s.ruins.ground_y(s.ruins.ground_lower.max()))-34,30):
				var candidate := Vector2(x,y)
				if s.ruins.blocked(candidate,31) or s.ruins.on_lava(candidate): continue
				var clearance := INF
				for e in s.enemies: clearance=minf(clearance,candidate.distance_to(e.p))
				for p in s.players.values():
					if p.status=="active": clearance=minf(clearance,candidate.distance_to(p.p)*.55)
				if clearance>best_clearance:
					best=candidate
					best_clearance=clearance
	if best_clearance>=0.0: return best
	return spawn_point(s,Vector2(center,s.ruins.lane_center(center)))

func spawn_point(s, at: Vector2) -> Vector2:
	for ring in range(0,16):
		for n in 16:
			var candidate: Vector2=at+Vector2.from_angle(n*TAU/16)*ring*18
			if not s.ruins.blocked(candidate,31): return candidate
	return Vector2(330,s.ruins.lane_center(330))

func spawn_minion(s, at: Vector2, floor_index: int, variant: int, elite: bool) -> void:
	s.spawn_enemy(spawn_point(s,at),0 if combat.minions.ROLES[floor_index][variant] in ["front","melee","ambush"] else 1)
	combat.setup_minion(s.enemies.back(),floor_index,variant,elite,s.rng)
	s.enemies.back()["build_elite"]=elite
	s.enemies.back()["build_xp_reward"]=maxi(1,scale_int(6 if elite else 2,1.0+mod_of(s,"xp_gain")))
	Build.enemy_budget(s,s.enemies.back())

func tick(s, dt: float) -> void:
	if s.raid.phase=="rogue_prepare":
		var waiting := false
		for p in s.players.values():
			if p.connected and p.status=="active" and (not p.rogue_selection.is_empty() or not p.build_reward_queue.is_empty()): waiting=true
		if not waiting: s.raid.phase="rogue_combat"; s.raid.revision+=1
		return
	combat.tick(s,dt)
	for corpse in s.raid.get("rogue_corpses",[]): corpse.time=maxf(0,corpse.time-dt)
	for p in s.players.values():
		if (p.status!="active" or not p.connected) and not p.get("rogue_selection",{}).is_empty():
			var selection: Dictionary=p.rogue_selection
			add_reward_drop(s,p.p,int(selection.tier),{},0.0,-1,str(selection.get("category","gear")))
			s.raid.reward_drops.back()["offers"]=selection.offers.duplicate(true)
			p.rogue_selection={}
		if p.status!="active": continue
		for drop in s.raid.get("reward_drops",[]):
			var owner: Dictionary=s.players.get(int(drop.owner),{})
			if drop.get("personal",false) and (owner.is_empty() or not owner.connected): drop.personal=false; drop.owner=-1
		if s.raid.phase=="rogue_combat" and s.ruins.on_lava(p.p) and p.height<=12:
			var resist := minf(.3,Build.r(p,28,[.1,.15,.2])+(.2 if Build.gear(p,7) else 0)+(.2 if Build.gear(p,59) else 0))
			p.hp=maxf(0.0,p.hp-Build.incoming(s,p,s.incoming_damage(p,14.0*dt*(1.0-resist)),{},"lava"))
			p.flask_time=0.0; p.build_last_hurt=s.elapsed
			p.rogue_lava=true
			if p.hp<=0: s.down(p)
		else: p.rogue_lava=false
	if s.raid.phase=="rogue_reward": finish_rewards(s)
	if s.raid.phase!="rogue_combat" or not s.enemies.is_empty(): return
	if int(s.raid.wave)<3:
		var gate: float=[0.0,1120.0,1990.0][int(s.raid.wave)]
		for p in s.players.values():
			if p.status=="active" and p.p.x>=gate:
				s.raid.wave+=1
				spawn_wave(s)
				break
	else: clear_room(s)

func clear_room(s) -> void:
	if s.raid.get("room_rewarded",false): return
	s.raid["room_rewarded"]=true
	combat.reset()
	s.raid.cleared+=1
	for p in s.players.values():
		# W1b (R8 hook h + R9 hook 2): the team-wide variant income and this player's own curse
		# compensation scale one payout. Both factors are exactly 1.0 when unused, so a clean
		# run keeps the shipped numbers to the digit.
		var gold_scale := (1.0+mod_of(s,"gold"))*Curses.personal_reward_scale(p)
		p.rogue_gold+=maxi(0,scale_int(25+int(s.raid.floor)*10+(50 if s.raid.get("challenge",false) else 0),gold_scale))
		Build.award(s,p)
	s.bullets.clear()
	s.pending_ultimates.clear()
	s.soul_reaps.clear()
	s.fire_zones.clear()
	s.raid.phase="rogue_reward"
	s.raid.offers=[]
	if s.raid.room not in CHEST_ROOMS:
		s.raid.reward_chest={}
		s.raid.revision+=1
		if s.raid.room=="talent":
			s.message.emit("灵契圣坛 · 每人两轮天赋三选一 · 可打开构筑配置")
		for p in s.players.values(): next_personal(s,p)
		finish_rewards(s)
		return
	var tier := mini(5,int(s.raid.floor)+(1 if s.raid.room in ["elite","boss","treasure"] else 0))
	var at := Vector2(480,s.ruins.lane_center(480))
	for p in s.players.values():
		if p.status=="active": at=p.p; break
	s.raid.reward_chest={"p":spawn_point(s,at+Vector2(100,0)),"tier":tier,"opened":false}
	s.raid.revision+=1
	s.message.emit("宝箱已出现 · 靠近按 E 开启")
	for p in s.players.values(): next_personal(s,p)

# All loot and pending choices live in the authoritative snapshot. A pickup
# removes its world packet before granting a personal, versioned selection.
func roll_tier(s) -> int:
	var weights: Array=[[45,45,9,1,0,0],[10,40,42,8,0,0],[0,10,45,38,7,0],[0,0,20,50,28,2],[0,0,5,35,52,8]][clampi(int(s.raid.floor)-1,0,4)]
	var roll: int=s.rng.randi_range(1,100)
	var tier := 0
	for i in weights.size():
		roll-=int(weights[i])
		if roll<=0: tier=i; break
	# W1b (R8 hook f): the abyss variant shifts every drop's quality band. The single rng draw
	# above is untouched, so the seeded stream is identical with or without a variant.
	return clampi(tier+int(round(mod_of(s,"loot_tier"))),0,5)

func reward_offers(s, tier: int, category: String = "gear", p: Dictionary = {}) -> Array:
	var offers: Array=[]
	if category in ["talent","core","boon"]:
		var pool: Array=[]
		for def in Content.data.talents:
			if (category=="core")!=(def.category=="K"): continue
			if not p.is_empty() and int(p.build_talents.get(def.id,0))>=int(def.max_rank): continue
			pool.append(def)
		for i in mini(3,pool.size()):
			var at: int=s.rng.randi_range(0,pool.size()-1)
			if not p.is_empty():
				var directions: Array=build_directions(p)
				if category=="core" and i<2:
					var preferred: int=directions[mini(i,directions.size()-1)]
					for j in pool.size():
						if int(pool[j].school)==preferred: at=j; break
				elif i==2 and category!="core":
					var upgrades: Array=[]
					for j in pool.size():
						if p.build_talents.has(pool[j].id): upgrades.append(j)
					if not upgrades.is_empty(): at=int(upgrades[s.rng.randi_range(0,upgrades.size()-1)])
				elif s.rng.randf()<.65:
					var suited: Array=[]
					for j in pool.size():
						if int(pool[j].school) in directions.slice(0,2): suited.append(j)
					if not suited.is_empty(): at=int(suited[s.rng.randi_range(0,suited.size()-1)])
			if i==0 and not p.is_empty() and int(p.build_cultivation)<=3:
				var school: int={1:0,2:1,0:2,3:6}.get(Catalog.weapon_family(int(p.weapon)),0)
				for j in pool.size():
					if pool[j].school==school and pool[j].category=="N": at=j; break
			if category!="core" and i<2 and not p.is_empty() and pool[at].id in p.build_library:
				var fresh: Array=[]
				for j in pool.size():
					if pool[j].id not in p.build_library: fresh.append(j)
				if not fresh.is_empty(): at=int(fresh[s.rng.randi_range(0,fresh.size()-1)])
			var def: Dictionary=pool.pop_at(at)
			offers.append({"name":def.name,"desc":def.text,"talent_id":def.id,"tier":tier,"price":50,"school":def.school})
		return offers
	var pool: Array=range(48 if category in ["weapon","starter"] else Equipment.GEAR.size())
	for i in 3:
		var choice: int=pool.pop_at(s.rng.randi_range(0,pool.size()-1))
		var item: Dictionary=Content.make_weapon(choice,tier) if category in ["weapon","starter"] else Equipment.make_gear(choice,tier)
		if category=="weapon" and s.rng.randf()<.25: item=Equipment.engrave(item,s.rng.randi_range(0,23))
		offers.append({"name":Catalog.item_name(item),"desc":Equipment.description(item),"item":item,"tier":tier,"price":0})
	return offers

func build_directions(p: Dictionary) -> Array:
	var family := Catalog.weapon_family(int(p.weapon))
	var default: Array={1:[0,9],2:[1,8],0:[2,7],3:[6,7]}[family]
	var weights: Dictionary={int(default[0]):3,int(default[1]):2}
	var weapon: int=Build.weapon_id(p)
	var thematic: int=3 if weapon in [6,16,28,38,43] else 4 if weapon in [7,17,29,39] else 5 if weapon in [8,18,30,40] else 10 if weapon in [23,47] else 11 if weapon in [36,48] else -1
	if thematic>=0: weights[thematic]=float(weights.get(thematic,0))+4
	for id in p.build_talents:
		var school: int=int(Content.entry(id).school)
		weights[school]=float(weights.get(school,0))+int(p.build_talents[id])*2
	var result: Array=weights.keys()
	result.sort_custom(func(a,b): return float(weights[a])>float(weights[b]) or (weights[a]==weights[b] and int(a)<int(b)))
	return result

func next_personal(s, p: Dictionary) -> void:
	if p.status!="active" or not p.rogue_selection.is_empty() or p.build_reward_queue.is_empty(): return
	var category: String=p.build_reward_queue.pop_front()
	loot_serial+=1
	p.rogue_selection={"id":loot_serial,"version":0,"tier":0,"category":category,"personal":true,"offers":reward_offers(s,0,category,p)}

func add_reward_drop(s, at: Vector2, tier: int, offer: Dictionary = {}, delay: float = 0.0, owner: int = -1, category: String = "gear") -> void:
	loot_serial+=1
	s.raid.reward_drops.append({"id":loot_serial,"p":spawn_point(s,at),"tier":tier,"offer":offer.duplicate(true),"born":s.elapsed,"delay":delay,"owner":owner,"category":category})

func loot_interact(s, p: Dictionary) -> void:
	if p.status!="active" or not p.get("rogue_selection",{}).is_empty(): return
	var chest: Dictionary=s.raid.get("reward_chest",{})
	if s.raid.room in CHEST_ROOMS and not chest.is_empty() and not chest.opened and p.p.distance_to(chest.p)<=85:
		chest.opened=true
		chest["opened_at"]=s.elapsed
		var categories: Array=["weapon","gear"]
		var index := 0
		for ally in s.players.values():
			if not ally.connected: continue
			for category in categories:
				add_reward_drop(s,chest.p+Vector2((index%4-1)*70,45+floori(index/4.0)*50),roll_tier(s),{},.65+index*.04,int(ally.id),category)
				s.raid.reward_drops.back()["personal"]=true
				index+=1
			# Personal, bound attribute shards use one roll per opened chest/player.
			# W1b (R9 hook 4): the shard rate answers to *this ally's* curses — the chest is
			# shared but the roll is personal. Still exactly one rng draw either way.
			var chance := (.5 if s.raid.room=="boss" else .2)*(1.0+mod_of(s,"chest_drop",ally))
			chance=clampf(chance,0.0,1.0)
			if ally.build_chest_attribute_drops<2 and s.rng.randf()<chance:
				add_reward_drop(s,chest.p+Vector2((index%4-1)*70,45+floori(index/4.0)*50),0,{"name":"属性灵晶 +1","desc":"拾取获得1点局内属性，可在构筑页分配。","attribute_points":1},.65+index*.04,int(ally.id),"attribute")
				s.raid.reward_drops.back()["personal"]=true
				ally.build_chest_attribute_drops+=1
				index+=1
		s.effect.emit("seal",chest.p)
		s.broadcast_audio("chest",p)
		s.raid.revision+=1
		return
	var nearest := -1
	var distance := 80.0
	for i in s.raid.get("reward_drops",[]).size():
		var drop: Dictionary=s.raid.reward_drops[i]
		if s.elapsed<float(drop.born)+float(drop.delay): continue
		if drop.get("personal",false) and int(drop.owner)!=int(p.id): continue
		if not drop.get("personal",false) and drop.owner==p.id and s.elapsed<float(drop.born)+1.0: continue
		var d: float=p.p.distance_to(drop.p)
		if d<distance: nearest=i; distance=d
	if nearest<0: return
	var drop: Dictionary=s.raid.reward_drops[nearest]
	s.raid.reward_drops.remove_at(nearest)
	s.broadcast_audio("loot",p)
	if not drop.offer.is_empty():
		if not apply_offer(s,p,drop.offer): s.raid.reward_drops.append(drop)
	else:
		p.rogue_selection={"id":drop.id,"version":0,"tier":drop.tier,"category":drop.get("category","gear"),"offers":drop.offers if drop.has("offers") else reward_offers(s,int(drop.tier),str(drop.get("category","gear")),p)}
	s.raid.revision+=1

func apply_offer(s, p: Dictionary, offer: Dictionary) -> bool:
	if offer.has("attribute_points"):
		p.build_attribute_points+=int(offer.attribute_points)
		p.rogue_inventory_revision+=1
		s.message.emit("拾取属性灵晶 · 属性点 +%d · Tab → 构筑 → 七属性" % int(offer.attribute_points))
		return true
	if offer.has("talent_id"):
		var id := str(offer.talent_id)
		if id not in p.build_library:
			if p.build_library.size()-p.build_talents.size()>=12:
				s.message.emit("未激活收藏已满：行囊中遗忘一项，或暂存修为")
				return false
			p.build_library.append(id)
			if Content.entry(id).category=="K":
				var school: int=int(Content.entry(id).school)
				var basic: String="T%03d" % (school*8+1)
				var has_basic := false
				for known in p.build_library:
					var def := Content.entry(known)
					if int(def.school)==school and def.category=="N": has_basic=true; break
				if not has_basic and p.build_library.size()-p.build_talents.size()<12: p.build_library.append(basic)
		Build.activate(s,p,id,1)
	elif offer.has("flask_refill"):
		if p.flask>50 or p.flask_shop_floor==int(s.raid.floor): return false
		p.flask=minf(100,p.flask+50); p.flask_shop_floor=int(s.raid.floor)
	elif offer.has("item"):
		if offer.item.kind=="medicine": p.flask=minf(100,p.flask+50)
		elif not equip(s,p,offer.item): return false
	else: return false
	p.rogue_inventory_revision+=1
	return true

func selection_action(s, p: Dictionary, kind: String, payload: Dictionary) -> void:
	var selection: Dictionary=p.get("rogue_selection",{})
	if selection.is_empty() or int(payload.get("id",-1))!=selection.id or int(payload.get("version",-1))!=selection.version: return
	if kind=="rogue_selection_reroll":
		if p.rogue_rerolls<=0: return
		p.rogue_rerolls-=1
		selection.offers=reward_offers(s,int(selection.tier),str(selection.get("category","gear")),p)
		selection.version+=1
		return
	if kind=="rogue_selection_bank" and selection.get("category","") in ["talent","core"]:
		p.rogue_selection={}; next_personal(s,p); finish_rewards(s); s.raid.revision+=1
		return
	if kind=="rogue_selection_return" and selection.get("personal",false): return
	if kind=="rogue_selection_return":
		add_reward_drop(s,p.p+Vector2(45,0),int(selection.tier),{},0.0,p.id,str(selection.get("category","gear")))
		s.raid.reward_drops.back()["offers"]=selection.offers.duplicate(true)
		p.rogue_selection={}
		return
	var index := int(payload.get("index",-1))
	if index<0 or index>=selection.offers.size() or kind not in ["rogue_selection_take","rogue_selection_drop"]: return
	var offer: Dictionary=selection.offers[index]
	if kind=="rogue_selection_drop" and not offer.has("item"): return
	if kind=="rogue_selection_drop": add_reward_drop(s,p.p+Vector2(45,0),int(selection.tier),offer,0.0,p.id)
	else:
		if not apply_offer(s,p,offer): return
	p.rogue_selection={}
	next_personal(s,p)
	if p.id not in s.raid.reward_claims: s.raid.reward_claims.append(p.id)
	if s.raid.phase in ["rogue_reward","rogue_shop_reward"]: finish_rewards(s)
	s.raid.revision+=1

func roll_offers(s, _shop: bool, target: Dictionary = {}) -> void:
	var players: Array=s.players.values() if target.is_empty() else [target]
	# W1b (R8 hook g + R9 hook 3): shop prices follow the variant's `shop_price`. A price is
	# never allowed below 1, and a scale of exactly 1.0 reproduces the old numbers bit for bit.
	var price_scale := 1.0+clampf(mod_of(s,"shop_price"),-0.9,3.0)
	for p in players:
		var offers: Array=[]
		for category in ["weapon","weapon","gear","gear","gear"]:
			var offer: Dictionary=reward_offers(s,roll_tier(s),category,p)[0]
			offer.price=50 if category=="talent" else maxi(1,scale_int(65+int(s.raid.floor)*10,price_scale))
			offers.append(offer)
		offers.append({"name":"血瓶补充 50%","desc":"容量不高于50%时可买，每层一次；不会立即治疗。","flask_refill":50,"price":maxi(1,scale_int(45,price_scale)),"tier":0,"sold":p.flask_shop_floor==int(s.raid.floor)})
		p["rogue_shop_offers"]=offers
	s.raid.offers=s.players.values()[0].get("rogue_shop_offers",[]).duplicate(true)
	s.raid.revision+=1

func equip(s,p: Dictionary,item: Dictionary) -> bool:
	# Replaced equipment stays in the run's slot-free reserve, never campaign storage.
	var old: Dictionary=p.equipped.weapon if item.kind=="weapon" else p.equipped.gear[Catalog.gear_slot(item)]
	if not old.is_empty():
		if p.rogue_stash.size()>=12:
			s.message.emit("备用行囊已满：先分享或丢弃一件装备")
			return false
		p.rogue_stash.append(old.duplicate(true))
	if not item.has("instance_id"):
		loot_serial+=1; item=item.duplicate(true); item["instance_id"]="%d:%d" % [s.seed_value,loot_serial]
	if item.kind=="weapon":
		p.equipped.weapon=item.duplicate(true)
		p.weapon=int(item.weapon)
		var clip: int=s.RogueActions.clip(p)
		var rounds: int=int(p.ammo)
		p.ammo=mini(rounds,clip)
		p.reserve=int(p.reserve)+maxi(0,rounds-clip) # Moving rounds out of a smaller magazine never creates ammunition.
		p.reload=0.0
		p.combo=0
		p.pending_strike=false
		if Build.safe(s,p): Build.bind_forge(p)
	else: p.equipped.gear[Catalog.gear_slot(item)]=item.duplicate(true)
	s.refresh_max_hp(p)
	p.rogue_inventory_revision+=1
	return true

func inventory_action(s, p: Dictionary, payload: Dictionary) -> void:
	if int(payload.get("version",-1))!=int(p.get("rogue_inventory_revision",0)): return
	if s.pending_ultimates.has(p.id) or p.pending_strike or p.swing_time>0 or p.cast_time>0 or p.dodge_time>0:
		s.message.emit("当前动作结束后可管理行囊")
		return
	var source := str(payload.get("source",""))
	var index := int(payload.get("index",-1))
	var verb := str(payload.get("verb",""))
	var item: Dictionary={}
	if source=="reserve":
		if index<0 or index>=p.rogue_stash.size() or verb not in ["equip","discard"]: return
		item=p.rogue_stash.pop_at(index)
		if verb=="equip":
			var hp: float=p.hp
			equip(s,p,item)
			p.hp=minf(hp,p.max_hp) # Repeated armour swaps cannot generate health.
	elif source=="equipped":
		if index<0 or index>3 or verb not in ["stow","discard"]: return
		item=p.equipped.weapon if index==0 else p.equipped.gear[index-1]
		if item.is_empty(): return
		if verb=="stow":
			if p.rogue_stash.size()>=12: return
			p.rogue_stash.append(item.duplicate(true))
		if index==0:
			p.equipped.weapon={}
			s.restore_issue_weapon(p)
		else: p.equipped.gear[index-1]={}
		s.refresh_max_hp(p)
	elif source=="supply":
		if verb=="use":
			s.perform(p.id,"heal")
			return
		return # The bound flask cannot be dropped.
		item={"kind":"medicine"}
	else: return
	p.rogue_inventory_revision+=1
	if verb=="discard":
		var tier := int(item.get("tier",1))
		add_reward_drop(s,p.p+Vector2(45,0),tier,{"name":Catalog.item_name(item),"item":item,"tier":tier},0.0,p.id)
	s.message.emit("已丢弃 "+Catalog.item_name(item) if verb=="discard" else "已更新本局装备")

func choose(s,p: Dictionary,kind: String,payload: Dictionary) -> void:
	if p.status!="active" or not s.running or s.raid.ended: return
	if kind=="rogue_build":
		Build.management(s,p,payload)
		return
	if kind=="rogue_inventory":
		inventory_action(s,p,payload)
		return
	if kind=="rogue_loot":
		loot_interact(s,p)
		return
	if kind.begins_with("rogue_selection_"):
		selection_action(s,p,kind,payload)
		return
	# Reject clicks from an earlier room or an earlier offer roll.
	if int(payload.get("revision",-1))!=int(s.raid.revision): return
	# W1b: the event / dedicated-room actions. All of them sit *behind* the revision guard
	# above, so a stale click can neither move currency nor resolve the same offer twice.
	if kind=="rogue_event":
		if not Events.matches_revision(s,int(payload.get("revision",-1))): return
		if not Events.apply(s,p,int(payload.get("index",-1))): return
		s.message.emit("幽暗异事 · 抉择已生效")
		return
	if kind=="rogue_forge" and str(s.raid.room)=="forge":
		room_action(s,p,"forge",int(payload.get("index",-1)))
		return
	if kind=="rogue_gamble" and str(s.raid.room)=="gamble":
		room_action(s,p,"gamble",int(payload.get("index",-1)))
		return
	if kind=="rogue_mirror" and str(s.raid.room)=="mirror":
		mirror_action(s,p)
		return
	if kind=="rogue_reroll" and s.raid.phase=="rogue_shop" and p.rogue_rerolls>0:
		p.rogue_rerolls-=1
		roll_offers(s,true,p)
	elif kind=="rogue_take" and s.raid.phase=="rogue_shop":
		var index: int=int(payload.get("index",-1))
		if index<0 or index>=p.rogue_shop_offers.size(): return
		var offer: Dictionary=p.rogue_shop_offers[index]
		if offer.get("sold",false) or p.rogue_gold<int(offer.price): return
		if not apply_offer(s,p,offer): return
		p.rogue_gold-=int(offer.price)
		offer.sold=true
		s.raid.revision+=1
	elif kind=="rogue_next" and s.raid.phase in ["rogue_shop","rogue_exit"]:
		var index := int(payload.get("index",-1))
		if index<0 or index>=s.raid.exits.size(): return
		if p.p.distance_to(s.ruins.exit_position(index))>64: return
		for ally in s.players.values():
			if ally.connected and (ally.status=="down" or not ally.get("rogue_selection",{}).is_empty() or (ally.status=="active" and ally.p.x<s.ruins.fork_start)): return
		var destination: Dictionary=s.raid.exits[index]
		s.raid["challenge"]=destination.get("challenge",false)
		# R5: the door carries the node it leads to; the chosen kind is written into the
		# floor template so `enter()` reproduces exactly the advertised room.
		if destination.has("node"): s.raid.node=str(destination["node"])
		if int(s.raid.area)<s.raid.route.size(): s.raid.route[int(s.raid.area)]=str(destination.room)
		if s.raid.phase=="rogue_shop":
			s.raid.cleared+=1
			for ally in s.players.values(): Build.award(s,ally)
			s.raid["pending_destination"]=str(destination.room)
			var waiting := false
			for ally in s.players.values(): next_personal(s,ally); waiting=waiting or not ally.rogue_selection.is_empty()
			if waiting: s.raid.phase="rogue_shop_reward"; s.raid.revision+=1; return
		advance(s,str(destination.room))

func exit_choices(s) -> Array:
	var graph: Dictionary=s.rogue_graph
	var successors: Array=NodeGraph.neighbors(graph,str(s.raid.node))
	if successors.is_empty():
		# The floor guardian is the only dead end in the graph: past it comes the next floor.
		if int(s.raid.floor)>=FLOORS.size(): return [{"room":"finish","name":"凯旋归城","desc":"完成本次闯关"}]
		var next_exits := random_destinations(s)
		for destination in next_exits: destination.name="下一层 · "+destination.name
		return next_exits
	if successors.size()==1 and str(NodeGraph.node(graph,str(successors[0])).get("kind",""))=="boss":
		# Guardian gate: normal descent or the harder challenge descent, both required.
		return [{"room":"boss","name":"守层者","desc":ROOM_DESCS["boss"],"node":str(successors[0])},
			{"room":"boss","name":"守层者 · 挑战","desc":"首领生命 +25% · 额外 50 魔晶","node":str(successors[0]),"challenge":true}]
	var choices: Array=[]
	for id in successors:
		var kind := str(NodeGraph.node(graph,str(id)).get("kind","combat"))
		choices.append({"room":kind,"name":ROOM_NAMES.get(kind,kind),"desc":ROOM_DESCS.get(kind,""),"node":str(id)})
	return choices

func random_destinations(s) -> Array:
	var pool := ["combat","elite","shop","treasure","talent"]
	var descriptions := {"combat":"迎战魔物 · 通关奖励","shop":"安全补给 · 消耗魔晶购买","elite":"更强敌人 · 更高品质装备","treasure":"安全宝藏 · 免费选择装备","talent":"灵契圣坛 · 两轮天赋三选一"}
	var choices: Array=[]
	for i in 2:
		var index: int=s.rng.randi_range(0,pool.size()-1)
		var room: String=pool.pop_at(index)
		choices.append({"room":room,"name":ROOM_NAMES[room],"desc":descriptions[room]})
	return choices

func finish_rewards(s) -> void:
	if s.raid.phase=="rogue_prepare": return
	if s.raid.phase=="rogue_shop_reward":
		for ally in s.players.values():
			if ally.connected and (not ally.rogue_selection.is_empty() or not ally.build_reward_queue.is_empty()): return
		advance(s,str(s.raid.get("pending_destination","combat")))
		return
	if s.raid.phase!="rogue_reward": return
	if not s.raid.get("reward_chest",{}).is_empty() and not s.raid.reward_chest.opened: return
	# Three shared category packets cannot require four independent player claims.
	# Only unresolved choices block the exit; already chosen ground items do not.
	for drop in s.raid.get("reward_drops",[]):
		if drop.offer.is_empty(): return
	for ally in s.players.values():
		if not ally.get("rogue_selection",{}).is_empty(): return
	s.raid.phase="rogue_exit"
	s.raid.offers=[]
	s.raid.revision+=1

func advance(s, first_room: String = "combat") -> void:
	# R5: the graph's deepest node is the guardian; reaching it ends the floor.
	if int(s.raid.depth)>=depth_count(s):
		if int(s.raid.floor)>=FLOORS.size():
			for p in s.players.values(): p.status="extracted"
			settle(s)
			return
		s.raid.floor+=1
		s.raid.area=1
		for p in s.players.values(): Build.floor_enter(p)
		# A genuine floor transition drops the previous path; the chosen door only picks
		# which room the deterministic entry node is turned into.
		s.raid.route=[]
		new_floor(s)
		if ROOM_NAMES.has(first_room) and first_room!="boss": s.raid.route[0]=first_room
	enter(s)

func settle(s) -> void:
	if s.raid.ended: return
	s.raid.ended=true
	# W1b (R8 hooks h/i): the run's abyss variant scales the end-of-run payout the same way it
	# scales the floor payouts. Both factors are 1.0 when unused and `scale_int` is bit-exact
	# identity at 1.0, so a variant-free run reproduces the shipped report exactly.
	var gold_scale := 1.0+mod_of(s,"gold")
	var xp_scale := 1.0+mod_of(s,"xp_gain")
	for id in s.players:
		var p: Dictionary=s.players[id]
		var won: bool=p.status=="extracted"
		var coins: int=scale_int(int(s.raid.cleared)*12+(250 if won else 0),gold_scale)
		var xp: int=scale_int(35+int(s.raid.cleared)*15,xp_scale)
		s.results[id]={"name":p.name,"escaped":won,"loot":0,"shared":coins+int(p.get("build_souvenirs",0))*2,"kills":p.kills,"coins":coins+int(p.get("build_souvenirs",0))*2,"xp":xp,"equipment_loot":[],"hidden":false,"worn":s.worn_names(p),"roguelike":true,"cleared":s.raid.cleared,"floor":s.raid.floor}
		# Contracts §9.3 / v3-3: ash and the daily record leave through settle() only and exactly
		# once — the `ended` latch above is the single guard, and it is already set at this point.
		Growth.grant(s,p)
		record_daily(s,p,coins)
	s.running=false
	s.finished.emit()
	if s.online: s.receive_results.rpc(s.results,s.players)

func rescue(s, p: Dictionary, held: bool, dt: float) -> bool:
	if not held: p.channel=0.0; p.target=""; return false
	for ally in s.players.values():
		if ally.status=="down" and not ally.get("rogue_rescued_room",false) and ally.p.distance_to(p.p)<=75:
			var key := "revive:%s" % ally.id
			if p.target!=key: p.channel=0.0; p.target=key
			var seconds: float=2.5*(1-Build.r(p,92,[.08,.12,.16]))
			p["channel_total"]=seconds
			p.channel+=dt
			if p.channel>=seconds:
				ally.status="active"; ally.hp=ally.max_hp*.25; ally.invuln=1.5; ally.rogue_rescued_room=true
				p.channel=0.0; p.target=""
			return true
	return false

# ---------------------------------------------------------------------------
# W1b · 专属房间（诅咒回廊 / 幽暗异事 / 游方锻炉 / 赌徒营帐 / 镜像试炼）
# ---------------------------------------------------------------------------

## 进入专属房间时把该房的报酬**恰好结算一次**。调用点在 `enter()` 内、`raid.revision` 自增
## 之后，所以写进 `pending_*` 的 revision 正是客户端该回传的那个（契约 §9.2）。
## 新增的 s.rng 消耗点只有两个、都已在 CHANGE-LOG v2-7 登记：`RogueCurses.roll`（每人 1 次）
## 与 `RogueEvents.roll_offer`（全队 1 次）；铁匠铺 / 赌徒 / 镜像在**进房**时 0 次随机。
func open_room(s) -> void:
	match str(s.raid.room):
		"curse":
			for p in s.players.values():
				var curse_id := Curses.roll(s,p.get("rogue_curses",[]))
				var outcome: Dictionary=Curses.apply_pair(s,p,curse_id)
				if bool(outcome.get("applied",false)):
					var row: Dictionary=Curses.find(curse_id)
					s.message.emit("诅咒回廊 · %s 承受「%s」" % [str(p.get("name","")),str(row.get("name",curse_id))])
			s.raid.revision+=1
		"event":
			Events.roll_offer(s)
			s.message.emit("幽暗异事 · 在面板里做出抉择")

## 服务型房间（铁匠铺 / 赌徒）的待选状态：每次成交后重算，保证报价与 revision 同步。
func refresh_dedicated(s, p: Dictionary = {}) -> void:
	var who: Dictionary=p if not p.is_empty() else first_player(s)
	if who.is_empty(): return
	var ctx: Dictionary=Rooms.context_of(s,who)
	match str(s.raid.room):
		"event":
			if not s.raid.get("pending_event",{}).is_empty():
				s.raid.pending_event.revision=int(s.raid.revision)
		"forge":
			s.raid["pending_forge"]={"offers":Rooms.offers("forge",ctx),"revision":int(s.raid.revision)}
		"gamble":
			s.raid["pending_gamble"]={"stake":Rooms.gamble_stake(int(s.raid.floor)),"revision":int(s.raid.revision)}

## 铁匠铺 / 赌徒的统一结算：先扣报价里的 `cost`，再落 `delta`；任何一步失败都不改状态。
func room_action(s, p: Dictionary, kind: String, index: int) -> void:
	var result: Dictionary=Rooms.resolve(kind,index,Rooms.context_of(s,p),s.rng)
	if not bool(result.get("ok",false)):
		s.message.emit("这里暂时无法这么做")
		return
	var cost := maxi(0,int(result.get("cost",0)))
	if cost>0:
		if int(p.get("rogue_gold",0))<cost: return
		p["rogue_gold"]=int(p.rogue_gold)-cost
	apply_room_delta(s,p,result.get("delta",{}))
	if kind=="gamble":
		s.message.emit("赌徒营帐 · %s（押 %d）" % ["赢" if bool(result.get("win",false)) else "输",int(result.get("stake",0))])
	else:
		s.message.emit("游方锻炉 · %s" % str(result.get("desc","")))
	s.raid.revision+=1
	refresh_dedicated(s,p)

## 镜像试炼（契约 §2 的 `mirror_state` 形状）：第一次点击"应战"把状态置为 active，
## 第二次点击才结算胜负，并置 `p.rogue_mirror_used`（本局一次性，契约 §3）。
func mirror_action(s, p: Dictionary) -> void:
	var state: Dictionary=s.raid.get("mirror_state",{})
	if not bool(state.get("active",false)):
		var accepted: Dictionary=Rooms.mirror_accept(Rooms.context_of(s,p))
		if not bool(accepted.get("ok",false)):
			s.message.emit("镜像试炼 · 本局已经挑战过了")
			return
		var opened: Dictionary=accepted.get("state",{})
		if opened.is_empty(): opened={"active":true,"owner":int(p.get("id",0)),"round":1,"settled":false}
		s.raid["mirror_state"]=opened
		s.raid.revision+=1
		s.message.emit("镜像试炼 · 影子已经站起，再次确认即开始结算")
		return
	var resolved: Dictionary=Rooms.mirror_resolve(s.rng,Rooms.context_of(s,p))
	if not bool(resolved.get("ok",false)): return
	apply_room_delta(s,p,resolved.get("delta",{}))
	var settled: Dictionary=resolved.get("state",{})
	s.raid["mirror_state"]=settled if not settled.is_empty() else {"active":false,"owner":int(p.get("id",0)),"round":2,"settled":true}
	p["rogue_mirror_used"]=true
	s.raid.revision+=1
	s.message.emit("镜像试炼 · %s" % ["胜" if bool(resolved.get("win",false)) else "败"])

## 落地 R10 的房间增量（`DELTA_KEYS`）。所有货币夹在 0 以上，任何房间都造不出负余额；
## `forge_level` / `weapon_tier` 会同步 `Build.bind_forge` 与 `refresh_max_hp` +
## `rogue_inventory_revision`，因为换阶会牵动装备命名、属性与最大生命（R10 标注的高风险项）。
func apply_room_delta(s, p: Dictionary, delta) -> Dictionary:
	var paid := {"gold":0,"forge_points":0,"forge_level":0,"weapon_tier":0,"ash":0,"gear_reward":0}
	if not (delta is Dictionary) or (delta as Dictionary).is_empty(): return paid
	var d: Dictionary=delta
	if int(d.get("gold",0))!=0:
		var gold_before := int(p.get("rogue_gold",0))
		p["rogue_gold"]=maxi(0,gold_before+int(d.gold))
		paid["gold"]=int(p.rogue_gold)-gold_before
	if int(d.get("forge_points",0))!=0:
		p["build_forge_points"]=maxi(0,int(p.get("build_forge_points",0))+int(d.forge_points))
		paid["forge_points"]=int(d.forge_points)
	if int(d.get("forge_level",0))>0:
		var level_before := int(p.get("build_forge_level",0))
		var cap := mini(5,maxi(1,int(s.raid.floor)))
		p["build_forge_level"]=mini(cap,level_before+int(d.forge_level))
		if not p.equipped.weapon.is_empty(): Build.bind_forge(p)
		paid["forge_level"]=int(p.build_forge_level)-level_before
	if bool(d.get("bind",false)):
		Build.bind_forge(p)
	if int(d.get("weapon_tier",0))>0:
		var tier := clampi(int(d.weapon_tier),1,5)
		if not p.equipped.weapon.is_empty():
			p.equipped.weapon["tier"]=tier
			p.rogue_inventory_revision+=1
			s.refresh_max_hp(p)
			paid["weapon_tier"]=tier
	if int(d.get("ash",0))!=0:
		var ash_before := int(p.get("rogue_ash_run",0))
		p["rogue_ash_run"]=maxi(0,ash_before+int(d.ash))
		paid["ash"]=int(p.rogue_ash_run)-ash_before
	if int(d.get("gear_reward",0))>0:
		if not p.has("build_reward_queue"): p["build_reward_queue"]=[]
		for i in int(d.gear_reward): p["build_reward_queue"].append("gear")
		paid["gear_reward"]=int(d.gear_reward)
		next_personal(s,p)
	return paid

## W1b (contract v3-1/v3-3)：每日挑战打卡。`profile.data["daily"]` 这个第三键目前仍属
## profile.gd 的接线面，所以这里**只在键已存在时**写入——绝不凭空造一个会被
## `apply_data()` 的 typeof 匹配静默丢弃的键（那只会让"打卡成功"变成假象）。
func record_daily(s, p: Dictionary, score: int) -> void:
	if not bool(s.raid.get("daily",false)): return
	var data := profile_data_of(s)
	if data.is_empty() or not data.has("daily"): return
	data["daily"]=Daily.apply_result(data.get("daily",{}),Daily.utc_today(),maxi(0,int(score)))
