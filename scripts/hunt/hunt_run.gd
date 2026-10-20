extends RefCounted
## 血潮深潜 · 一局运行状态与规则
##
## 纯逻辑：不建节点、不读 Profile、不碰 TideSession。UI 只调用这里的动作并读字段，
## 因此整局可以在 headless 里用固定种子跑完（见 tests/hunt_rules.gd）。
##
## 时间单位：秒。8 分钟 = 1 天；第 3 天结束自动通关。
## 地区切换、搜索、战斗、合成都在这里结算，画面层不允许自己改数值。

signal changed
signal logged(text: String)
signal finished(result: Dictionary)
signal floated(kind: String, anchor: String, amount: float, heavy: bool)

const Data = preload("res://scripts/hunt/hunt_data.gd")
const CatalogRef = preload("res://scripts/catalog.gd")

const BASE_STAMINA := 100.0
const START_CAPACITY := 20
const EXTRACT_AREAS := ["bell_square", "docks"]
const FIST := "fist"

## V2 形态：行动 / 隐藏。
const FORM_ACT := "act"
const FORM_HIDE := "hide"
const FORM_SWITCH_CD := 2.0
const HIDE_DAMAGE := 0.6          # 隐藏形态最终伤害倍率（向下取整）
const HIDE_ACTION := 1.2          # 隐藏形态行动时长/冷却倍率
const HIDE_STEALTH := 0.15        # 被发现的概率倍率（基础降低 85%）
const NOTICE_RATE := 0.05         # 每点攻击欲望每秒积累的"察觉"进度
const COUNTER_CD := 0.1           # 双向反击的统一冷却，无视普攻 CD
const SEARCH_SECONDS := 3.0       # 一次搜索的基准时长
const SEARCH_ENCOUNTER := 0.16    # 搜索把东西引出来的基础概率
const EVENTS_PER_DAY_MIN := 2     # 每区每天最少刷几个事件点
const EVENTS_PER_DAY_MAX := 3     # 每区每天最多刷几个
const EVENT_SPECIAL_CHANCE := 0.35 # 满足条件时，额外再挂一个时段/天数专属事件

var hero := 0
var hero_data: Dictionary = {}
var day := 1
var clock := 0.0
var area_id := Data.CAMP_AREA
var hp := 100.0
var max_hp := 100.0
var stamina := BASE_STAMINA
var max_stamina := BASE_STAMINA
var base_attack := 20.0
var base_defense := 0.0
var defense_bonus := 0.0
var attack_bonus := 0.0
var attack_buff_time := 0.0
var bag: Array = []
var capacity := START_CAPACITY
var equipment := {"weapon": FIST, "armor": ""}
var uses: Dictionary = {}
var area_enemies: Dictionary = {}
var search: Dictionary = {}
var combat: Dictionary = {}
var attack_cd := 0.0
var heavy_cd := 0.0
var smoke_guard := 0.0
var form := FORM_ACT
var form_cd := 0.0
var search_cd := 0.0
var counter_lock := 0.0
## 随机事件：每个地区每天的刷新结果 + 正在执行的事件状态（互动窗口）。
## `area_events` 的 uid 形如 `area:event_id:index`，UI 只认 uid。
var area_events: Dictionary = {}
var events_used: Dictionary = {}
var event_state: Dictionary = {}
var event_rng := RandomNumberGenerator.new()
## 随身物：从营地仓库带进深潜的 3 格普通物品，跨局保留，撤离/阵亡都会损耗。
var pocket: Array = []
var unlocked_spots: Dictionary = {}
var area_notified: Dictionary = {}
var flags := {"torch": false, "mask": false, "charcoal_filter": false, "map_revealed": false, "spirit_safe": false}
var expression := "neutral"
var expression_time := 0.0
var logs: Array = []
var kills := 0
var searched := 0
var ended_flag := false
var paused := false
var rng := RandomNumberGenerator.new()
var run_seed := 0
var last_phase := ""
var gear_index := -1
var counter_hits := 0

func setup(p_hero: int, p_seed: int = 0, p_gear: int = -1, talents: Array = [0, 0, 0], p_pocket: Array = []) -> void:
	hero = clampi(p_hero, 0, CatalogRef.HEROES.size() - 1)
	hero_data = CatalogRef.HEROES[hero]
	run_seed = p_seed if p_seed != 0 else randi_range(1, 9999999)
	rng.seed = run_seed
	gear_index = p_gear
	day = 1
	clock = 0.0
	area_id = Data.CAMP_AREA
	capacity = START_CAPACITY
	bag = []
	equipment = {"weapon": FIST, "armor": ""}
	uses = {}
	area_enemies = {}
	search = {}
	combat = {}
	attack_cd = 0.0
	heavy_cd = 0.0
	smoke_guard = 0.0
	defense_bonus = 0.0
	attack_bonus = 0.0
	attack_buff_time = 0.0
	form = FORM_ACT
	form_cd = 0.0
	search_cd = 0.0
	counter_lock = 0.0
	counter_hits = 0
	area_events = {}
	events_used = {}
	event_state = {}
	pocket = []
	for entry in p_pocket:
		if entry is Dictionary and not str(entry.get("kind", "")).is_empty():
			pocket.append({"kind": str(entry.get("kind", "")), "count": maxi(1, int(entry.get("count", 1)))})
	unlocked_spots = {}
	area_notified = {}
	kills = 0
	searched = 0
	ended_flag = false
	paused = false
	logs = []
	expression = "neutral"
	expression_time = 0.0
	flags = {"torch": false, "mask": false, "charcoal_filter": false, "map_revealed": false, "spirit_safe": false}
	var gear: Dictionary = CatalogRef.gear_of(p_gear)
	max_hp = float(hero_data.hp) + float(gear.get("hp", 0.0)) + float(talents[0]) * 12.0
	hp = max_hp
	max_stamina = BASE_STAMINA
	stamina = max_stamina
	base_attack = float(hero_data.damage) * (1.0 + float(gear.get("damage", 0.0)) + float(talents[1]) * 0.08)
	base_defense = float(gear.get("defense", 0.0))
	last_phase = phase_id()
	_reset_uses()
	_refresh_area_enemies()
	_roll_all_events()
	add_item("bandage", 1)
	add_item("dirty_water", 1)
	_notify_area_threat()
	note("第 1 天 · 白昼。深潜在等你。")
	changed.emit()

func note(text: String) -> void:
	logs.append(text)
	while logs.size() > Data.MAX_LOGS:
		logs.pop_front()
	logged.emit(text)

func phase_id() -> String:
	return str(Data.phase_at(clock).get("id", "day"))

func phase_name() -> String:
	return str(Data.phase_at(clock).get("name", "白昼"))

func is_night() -> bool:
	return phase_id() == "night"

func day_ratio() -> float:
	return clampf(clock / Data.DAY_SECONDS, 0.0, 1.0)

func time_left() -> float:
	return maxf(0.0, Data.DAY_SECONDS - clock)

func time_text() -> String:
	var left := int(ceil(time_left()))
	return "%02d:%02d" % [int(left / 60), left % 60]

func area() -> Dictionary:
	return Data.area(area_id)

func area_name() -> String:
	return Data.area_name(area_id)

func day_text() -> String:
	return "第 %d 天 / %d" % [day, Data.DAYS]

func weapon_kind() -> String:
	return str(equipment.get("weapon", FIST))

func weapon_data() -> Dictionary:
	return Data.weapon(weapon_kind())

func armor_kind() -> String:
	return str(equipment.get("armor", ""))

func armor_data() -> Dictionary:
	var kind := armor_kind()
	return Data.armor(kind) if not kind.is_empty() else {}

func attack_power() -> float:
	var bonus := 0.0
	if attack_buff_time > 0.0:
		bonus = 8.0
	return maxf(1.0, base_attack + float(weapon_data().get("damage", 0.0)) + attack_bonus + bonus)

func defense_value() -> float:
	var armor := armor_data()
	return clampf(base_defense + float(armor.get("defense", 0.0)) + defense_bonus * 0.02, 0.0, 0.65)

func armor_hp() -> float:
	return float(armor_data().get("hp", 0.0))

func total_max_hp() -> float:
	return max_hp + armor_hp()

func refresh_max_hp() -> void:
	var next := total_max_hp()
	hp = minf(hp, next)

func _reset_uses() -> void:
	uses.clear()
	for id in Data.AREAS:
		var area_data: Dictionary = Data.AREAS[id]
		for spot in area_data.get("hotspots", []):
			uses["%s:%s" % [id, str(spot.id)]] = int(spot.get("uses", 1))

func _refresh_area_enemies() -> void:
	area_enemies.clear()
	for id in Data.AREAS:
		var list: Array = []
		var area_data: Dictionary = Data.AREAS[id]
		for spec in area_data.get("enemies", []):
			if int(spec.get("day", 1)) > day:
				continue
			var wanted_phase := str(spec.get("phase", ""))
			if not wanted_phase.is_empty() and wanted_phase != phase_id():
				continue
			var kind := str(spec.get("kind", "scavenger"))
			var base: Dictionary = Data.enemy(kind)
			if base.is_empty():
				continue
			list.append(_make_enemy(id, kind, base, spec.get("at", Vector2(0.6, 0.6)), list.size()))
		area_enemies[id] = list

func _make_enemy(area: String, kind: String, base: Dictionary, at: Vector2, index: int) -> Dictionary:
	return {
		"uid": "%s:%s:%d" % [area, kind, index],
		"kind": kind,
		"hp": float(base.get("hp", 50.0)),
		"max_hp": float(base.get("hp", 50.0)),
		"damage": float(base.get("damage", 5.0)),
		"interval": float(base.get("interval", 2.0)),
		"aggression": float(base.get("aggression", 1.0)),
		"boss": bool(base.get("boss", false)),
		"at": at,
		"next": float(base.get("interval", 2.0)) * rng.randf_range(0.8, 1.2),
		"wake": 0.0,
		"alert": false,
		"name": str(base.get("name", kind)),
	}

func active_enemies() -> Array:
	return area_enemies.get(area_id, [])

func has_enemy() -> bool:
	return not active_enemies().is_empty()

func find_enemy(uid: String) -> Dictionary:
	for e in active_enemies():
		if str(e.uid) == uid:
			return e
	return {}

func _remove_enemy(uid: String) -> void:
	var list: Array = area_enemies.get(area_id, [])
	for i in range(list.size() - 1, -1, -1):
		if str(list[i].uid) == uid:
			list.remove_at(i)
	area_enemies[area_id] = list

func hotspot_uses(spot_id: String) -> int:
	return int(uses.get("%s:%s" % [area_id, spot_id], 0))

func hotspots() -> Array:
	return area().get("hotspots", [])

func hotspot(spot_id: String) -> Dictionary:
	for spot in hotspots():
		if str(spot.id) == spot_id:
			return spot
	return {}

func search_cost(spot: Dictionary) -> float:
	return 5.0 + float(spot.get("tier", 1)) * 3.0

func search_seconds(spot: Dictionary = {}) -> float:
	var seconds := SEARCH_SECONDS + float(spot.get("tier", 1)) * 0.2
	if is_night() and not flags.torch:
		seconds *= 1.25
	if form == FORM_HIDE:
		seconds *= HIDE_ACTION
	return seconds

func is_locked(spot_id: String) -> bool:
	return str(hotspot(spot_id).get("kind", "search")) == "locked"

## 搜索点前置条件：`torch` / `mask` 看 flags，其余按"身上有没有这件物品"。
func spot_requires_met(spot: Dictionary) -> bool:
	var req: Dictionary = spot.get("requires", {})
	for key in req:
		match str(key):
			"torch":
				if not flags.torch:
					return false
			"mask":
				if not flags.mask:
					return false
			_:
				if item_count(str(key)) <= 0:
					return false
	return true

func spot_lock_reason(spot: Dictionary) -> String:
	if not spot_requires_met(spot):
		var req: Dictionary = spot.get("requires", {})
		var names: Array = []
		for key in req:
			match str(key):
				"torch":
					names.append("火把")
				"mask":
					names.append("瘟疫面具")
				_:
					names.append(Data.item_name(str(key)))
		return "需要：" + "、".join(names)
	if is_locked(str(spot.get("id", ""))) and item_count("key") <= 0 and item_count("lockpick") <= 0:
		return "需要开锁针或铁钥匙。"
	return ""

## W 键能抽到的点：还有次数、条件满足、上锁的话身上有钥匙/开锁针。
func available_spots() -> Array:
	var out: Array = []
	for spot in hotspots():
		if hotspot_uses(str(spot.id)) <= 0:
			continue
		if not spot_requires_met(spot):
			continue
		if is_locked(str(spot.id)) and item_count("key") <= 0 and item_count("lockpick") <= 0:
			continue
		out.append(spot)
	return out

func can_search() -> Dictionary:
	if not combat.is_empty():
		return {"ok": false, "why": "先脱离战斗。"}
	if not search.is_empty():
		return {"ok": false, "why": "正在搜索。"}
	if search_cd > 0.0:
		return {"ok": false, "why": "还在缓手。"}
	if available_spots().is_empty():
		return {"ok": false, "why": "这个地区已经没有能翻的地方了。"}
	if bag.size() >= capacity and not _has_stack_room():
		return {"ok": false, "why": "背包已满。"}
	if stamina < 5.0:
		return {"ok": false, "why": "体力不足。"}
	return {"ok": true, "why": ""}

## 不给 spot_id 时从"可搜点"里随机抽一个；给 id 只用于测试与调试。
func start_search(spot_id: String = "") -> bool:
	var verdict := can_search()
	if not bool(verdict.ok):
		note(str(verdict.why))
		return false
	var spot: Dictionary = hotspot(spot_id) if not spot_id.is_empty() else {}
	if spot.is_empty():
		var pool := available_spots()
		if pool.is_empty():
			return false
		spot = pool[rng.randi_range(0, pool.size() - 1)]
	elif hotspot_uses(spot_id) <= 0:
		note("这里已经被搜空了。")
		return false
	elif not spot_requires_met(spot):
		note(spot_lock_reason(spot))
		return false
	elif is_locked(spot_id) and item_count("key") <= 0 and item_count("lockpick") <= 0:
		note("需要开锁针或铁钥匙。")
		return false
	var sid := str(spot.id)
	if is_locked(sid):
		if item_count("key") > 0:
			consume("key", 1)
		else:
			consume("lockpick", 1)
	stamina = maxf(0.0, stamina - search_cost(spot))
	var seconds := search_seconds(spot)
	search = {"id": sid, "left": seconds, "total": seconds}
	search_cd = seconds
	note("开始翻找：%s。" % str(spot.get("name", "角落")))
	changed.emit()
	return true

func cancel_search(reason: String = "") -> void:
	if search.is_empty():
		return
	search = {}
	if not reason.is_empty():
		note(reason)
	changed.emit()

func _has_stack_room() -> bool:
	for entry in bag:
		if CatalogRef.stacks(str(entry.kind)) and int(entry.count) < CatalogRef.max_stack(str(entry.kind)):
			return true
	return false

func _advance_search(dt: float) -> void:
	if search.is_empty():
		return
	search["left"] = float(search.left) - dt
	if float(search.left) > 0.0:
		return
	var spot_id := str(search.id)
	search = {}
	_complete_search(spot_id)

func _complete_search(spot_id: String) -> void:
	var spot := hotspot(spot_id)
	if spot.is_empty():
		return
	var key := "%s:%s" % [area_id, spot_id]
	uses[key] = maxi(0, int(uses.get(key, 1)) - 1)
	searched += 1
	var loot: Dictionary = spot.get("loot", {})
	var got: Array = []
	# 搜到的东西带白/绿/蓝品质：越深的点位越容易出好东西。
	var loot_tier := clampi(int(spot.get("tier", 1)) - 1, 0, 2)
	if is_night():
		loot_tier = mini(2, loot_tier + 1)
	for i in 2:
		var kind := _roll_table(loot)
		if kind.is_empty():
			break
		if add_item(kind, 1, loot_tier):
			got.append("%s%s" % [Data.tier_name(loot_tier), Data.item_name(kind)])
		else:
			note("背包满了，%s 留在了原地。" % Data.item_name(kind))
	if got.is_empty():
		note("%s 里只剩下灰。" % str(spot.get("name", "容器")))
	else:
		note("找到：%s。" % "、".join(got))
		set_expression("joy", 2.0)
	# 翻找的动静会让附近的怪物更快察觉（攻击欲望高的更快）。
	for enemy in active_enemies():
		enemy.wake = minf(1.0, float(enemy.wake) + 0.30 * float(enemy.aggression))
	# 只有搜索会把怪物引出来并打开战斗面板；隐藏形态把概率再压低。
	var chance := SEARCH_ENCOUNTER + float(spot.get("tier", 1)) * 0.02 + (0.06 if is_night() else 0.0)
	if form == FORM_HIDE:
		chance *= 0.7
	if combat.is_empty() and not ended_flag and rng.randf() < chance:
		_spawn_encounter()
	if hotspot_uses(spot_id) <= 0:
		note("%s 已经搜空了。" % str(spot.get("name", "容器")))
	changed.emit()

func _roll_table(table: Dictionary) -> String:
	if table.is_empty():
		return ""
	var total := 0.0
	for kind in table:
		total += float(table[kind])
	var roll := rng.randf() * total
	for kind in table:
		roll -= float(table[kind])
		if roll <= 0.0:
			return str(kind)
	return str(table.keys().back())

## 搜索主动遭遇：生成一个本地区的敌人并立刻进入战斗面板。
func _spawn_encounter() -> void:
	var pool: Array = []
	for spec in area().get("enemies", []):
		if int(spec.get("day", 1)) > day:
			continue
		if not str(spec.get("phase", "")).is_empty() and str(spec.phase) != phase_id():
			continue
		pool.append(str(spec.kind))
	if pool.is_empty():
		pool = ["scavenger"]
	var kind := str(pool[rng.randi_range(0, pool.size() - 1)])
	var base: Dictionary = Data.enemy(kind)
	var enemies: Array = active_enemies()
	var enemy := _make_enemy(area_id, kind, base, Vector2(0.56, 0.62), 90 + enemies.size())
	enemy.alert = true
	enemies.append(enemy)
	area_enemies[area_id] = enemies
	note("搜索声惊动了什么：%s。" % str(base.get("name", kind)))
	start_combat(str(enemy.uid))

func add_item(kind: String, count: int = 1, tier: int = -1) -> bool:
	if count <= 0 or not CatalogRef.ITEMS.has(kind):
		return false
	var left := count
	if CatalogRef.stacks(kind):
		for entry in bag:
			if str(entry.kind) != kind:
				continue
			# 有品质的堆叠只并进同品质的堆：白/绿/蓝不能混在一格里。
			if tier >= 0 and int(entry.get("tier", -1)) != tier:
				continue
			var room := CatalogRef.max_stack(kind) - int(entry.count)
			if room <= 0:
				continue
			var take := mini(room, left)
			entry.count = int(entry.count) + take
			left -= take
			if left <= 0:
				return true
	while left > 0:
		if bag.size() >= capacity:
			return left < count
		var take := 1
		if CatalogRef.stacks(kind):
			take = mini(left, CatalogRef.max_stack(kind))
		var entry := {"kind": kind, "count": take}
		if tier >= 0:
			entry["tier"] = tier
		bag.append(entry)
		left -= take
	return left < count

func item_count(kind: String) -> int:
	var total := 0
	for entry in bag:
		if str(entry.kind) == kind:
			total += int(entry.count)
	return total

func consume(kind: String, count: int = 1) -> bool:
	if item_count(kind) < count:
		return false
	var left := count
	for i in range(bag.size() - 1, -1, -1):
		var entry: Dictionary = bag[i]
		if str(entry.kind) != kind:
			continue
		var take := mini(int(entry.count), left)
		entry.count = int(entry.count) - take
		left -= take
		if int(entry.count) <= 0:
			bag.remove_at(i)
		if left <= 0:
			return true
	return true

func bag_space() -> int:
	return maxi(0, capacity - bag.size())

func bag_value() -> int:
	var total := 0
	for entry in bag:
		var item := {"kind": str(entry.kind), "count": int(entry.count)}
		if entry.has("tier"):
			item["tier"] = int(entry.tier)
		total += CatalogRef.item_value(item) * int(entry.count)
	return total

func can_craft(recipe: Dictionary) -> bool:
	if recipe.is_empty():
		return false
	for kind in recipe.get("inputs", {}):
		if item_count(str(kind)) < int(recipe.inputs[kind]):
			return false
	var out := str(recipe.get("out", ""))
	if not CatalogRef.ITEMS.has(out):
		return false
	if CatalogRef.stacks(out):
		for entry in bag:
			if str(entry.kind) == out and int(entry.count) + int(recipe.get("count", 1)) <= CatalogRef.max_stack(out):
				return true
	return bag.size() < capacity

func craft(recipe_id: String) -> bool:
	var recipe := Data.recipe(recipe_id)
	if not can_craft(recipe):
		note("材料不够，或者背包没有空位。")
		return false
	for kind in recipe.get("inputs", {}):
		consume(str(kind), int(recipe.inputs[kind]))
	var out := str(recipe.get("out", ""))
	var count := int(recipe.get("count", 1))
	if not add_item(out, count):
		# Refund: a craft that cannot fit must not eat the inputs.
		for kind in recipe.get("inputs", {}):
			add_item(str(kind), int(recipe.inputs[kind]))
		note("背包放不下 %s。" % Data.item_name(out))
		return false
	note("合成了 %s ×%d。" % [Data.item_name(out), count])
	set_expression("smile", 2.0)
	changed.emit()
	return true

func equip(kind: String) -> bool:
	if not CatalogRef.ITEMS.has(kind):
		return false
	if Data.is_weapon(kind):
		var old := weapon_kind()
		if old != FIST and bag.size() >= capacity and not CatalogRef.stacks(old):
			note("背包满了，换不下手里的武器。")
			return false
		if item_count(kind) <= 0:
			return false
		consume(kind, 1)
		if old != FIST:
			add_item(old, 1)
		equipment["weapon"] = kind
		note("装备了 %s。" % Data.item_name(kind))
		set_expression("determined", 1.5)
		refresh_max_hp()
		changed.emit()
		return true
	if Data.is_armor(kind):
		var old_armor := armor_kind()
		if not old_armor.is_empty() and bag.size() >= capacity:
			note("背包满了，换不下身上的防具。")
			return false
		if item_count(kind) <= 0:
			return false
		consume(kind, 1)
		if not old_armor.is_empty():
			add_item(old_armor, 1)
		equipment["armor"] = kind
		note("穿上了 %s。" % Data.item_name(kind))
		refresh_max_hp()
		changed.emit()
		return true
	return false

func use_item(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var entry: Dictionary = bag[index]
	var kind := str(entry.kind)
	if Data.is_weapon(kind):
		return equip(kind)
	if Data.is_armor(kind):
		return equip(kind)
	if kind in ["snare", "alchemist_flare", "smoke_pouch"]:
		return use_combat_item(kind)
	var used := _apply_consumable(kind)
	if used:
		if not search.is_empty():
			cancel_search("你停下手里的活，用了一件东西。")
		consume(kind, 1)
		refresh_max_hp()
		set_expression("smile", 1.5)
		changed.emit()
	return used

## 消耗品/工具的共用效果：背包与随身物各走各的扣除，效果只在这里写一次。
func _apply_consumable(kind: String) -> bool:
	var info: Dictionary = Data.item(kind)
	var used := false
	if info.has("heal"):
		var before := hp
		hp = minf(total_max_hp(), hp + float(info.heal))
		used = hp > before
		if hp > before:
			floated.emit("heal", "player", hp - before, false)
		note("使用 %s，恢复 %d 生命。" % [Data.item_name(kind), int(hp - before)])
	if info.has("stamina"):
		var before_sp := stamina
		stamina = minf(max_stamina, stamina + float(info.stamina))
		used = used or stamina > before_sp
		note("使用 %s，恢复 %d 体力。" % [Data.item_name(kind), int(stamina - before_sp)])
	match kind:
		"frenzy_phial":
			attack_buff_time = 30.0
			stamina = maxf(0.0, stamina - 20.0)
			used = true
			note("狂血药剂起效：攻击提高，持续 30 秒。")
		"pack_straps":
			capacity += 4
			used = true
			note("背带收紧，背包容量 +4。")
		"armor_patch":
			defense_bonus = minf(5.0, defense_bonus + 1.0)
			used = true
			note("甲片补丁生效：防御 +1。")
		"armor_kit":
			var before_kit := hp
			hp = minf(total_max_hp(), hp + 20.0)
			if hp > before_kit:
				floated.emit("heal", "player", hp - before_kit, false)
			defense_bonus = minf(5.0, defense_bonus + 1.0)
			used = true
			note("修甲工具：恢复 20 生命，防御 +1。")
		"spirit_horn":
			flags.map_revealed = true
			flags.spirit_safe = true
			used = true
			note("骨笛响了一声：所有地区已标记，下一次换区不会被跟。")
		"hunt_bait":
			if has_enemy():
				area_enemies[area_id] = []
				if not combat.is_empty():
					combat = {}
				used = true
				note("血饵被叼走，附近的敌人散开了。")
			else:
				note("这里没有需要引开的敌人。")
		"torch":
			flags.torch = true
			used = true
			note("火把点起来了。夜晚搜索不再摸黑。")
		"plague_mask":
			flags.mask = true
			used = true
			note("戴上瘟疫面具，毒气与陷阱的伤害降低了。")
		"charcoal_filter":
			flags.charcoal_filter = true
			used = true
			note("炭滤器装好了，之后每份污水能多滤一份净水。")
		"lockpick", "key":
			note("这类工具在搜索上锁容器时会自动使用。")
			return false
	return used

## 随身物：深潜自己的 3 格口袋。效果与背包一致，但绝不进背包、也绝不被带出深潜。
func pocket_of(kind: String) -> int:
	if pocket.is_empty():
		return 0
	var total := 0
	for entry in pocket:
		if str(entry.get("kind", "")) == kind:
			total += int(entry.get("count", 1))
	return total

func pocket_use(index: int) -> bool:
	if index < 0 or index >= pocket.size():
		return false
	var entry: Dictionary = pocket[index]
	var kind := str(entry.get("kind", ""))
	if Data.is_weapon(kind) or Data.is_armor(kind):
		note("这件东西不该在随身物里。")
		return false
	if kind in ["snare", "alchemist_flare", "smoke_pouch"]:
		return use_combat_item(kind)
	var used := _apply_consumable(kind)
	if not used:
		return false
	entry["count"] = int(entry.get("count", 1)) - 1
	if int(entry.get("count", 1)) <= 0:
		pocket.remove_at(index)
	note("%s 从随身物里用掉了。" % Data.item_name(kind))
	refresh_max_hp()
	set_expression("smile", 1.2)
	changed.emit()
	return true

func pocket_names() -> Array:
	var names: Array = []
	for entry in pocket:
		names.append("%s ×%d" % [Data.item_name(str(entry.get("kind", ""))), int(entry.get("count", 1))])
	return names

func use_combat_item(kind: String) -> bool:
	if combat.is_empty():
		note("只能在战斗中使用。")
		return false
	if item_count(kind) <= 0:
		return false
	match kind:
		"snare":
			combat.hp = maxf(0.0, float(combat.hp) - 40.0)
			combat.next = float(combat.next) + 1.5
			floated.emit("damage", "enemy", 40.0, false)
			note("捕兽夹咬合：%s 受到 40 伤害并停顿。" % str(combat.name))
		"alchemist_flare":
			consume(kind, 1)
			_remove_enemy(str(combat.uid))
			combat = {}
			note("炼金焰筒炸开，你脱离了战斗。")
			changed.emit()
			return true
		"smoke_pouch":
			smoke_guard = 0.55
			note("烟囊散开，下一次受击伤害降低。")
		_:
			return false
	consume(kind, 1)
	if not combat.is_empty() and float(combat.hp) <= 0.0:
		_win_combat()
	changed.emit()
	return true

func start_combat(uid: String) -> bool:
	if not combat.is_empty():
		return false
	var enemy := find_enemy(uid)
	if enemy.is_empty():
		return false
	if not search.is_empty():
		cancel_search("翻找被战斗打断了。")
	combat = enemy.duplicate(true)
	combat["next"] = float(combat.get("interval", 2.0)) * rng.randf_range(0.8, 1.2)
	attack_cd = 0.0
	note("%s 挡住了去路。" % str(combat.get("name", "敌人")))
	set_expression("angry", 1.5)
	changed.emit()
	return true

## 角色的普攻伤害：形态惩罚在最后统一取整（隐藏形态 ×0.6 向下取整）。
func _player_damage(mult: float = 1.0) -> float:
	var damage := attack_power() * rng.randf_range(0.9, 1.1) * mult
	if form == FORM_HIDE:
		damage = floorf(damage * HIDE_DAMAGE)
	return damage

func attack_rate() -> float:
	var rate := float(weapon_data().get("rate", 0.9))
	if form == FORM_HIDE:
		rate *= HIDE_ACTION
	return rate

func _tick_combat(dt: float) -> void:
	if combat.is_empty():
		return
	attack_cd = maxf(0.0, attack_cd - dt)
	heavy_cd = maxf(0.0, heavy_cd - dt)
	combat.next = float(combat.next) - dt
	if float(combat.next) > 0.0:
		return
	combat.next = float(combat.interval) * rng.randf_range(0.8, 1.2)
	_enemy_hits_player(float(combat.damage), true)

## 敌人命中：烟雾 → 护甲 → 扣血；`allow_counter` 决定角色是否反击。
func _enemy_hits_player(raw: float, allow_counter: bool) -> void:
	if hp <= 0.0 or ended_flag:
		return
	if smoke_guard > 0.0:
		raw *= (1.0 - smoke_guard)
		smoke_guard = 0.0
	var dealt := raw * (1.0 - defense_value())
	hp = maxf(0.0, hp - dealt)
	if dealt > 0.0:
		floated.emit("hurt", "player", dealt, false)
	var source := str(combat.get("name", "暗处的东西"))
	note("%s 击中你，受到 %d 伤害。" % [source, int(dealt)])
	set_expression("sad" if form == FORM_ACT else "afraid", 1.2)
	if hp <= 0.0:
		finish(false, "伤重倒下")
		return
	if allow_counter:
		_counter_from_player()

## 角色反击：算一次普攻（吃形态惩罚与攻击加成），统一 0.1 秒反击 CD，不再触发反击。
func _counter_from_player() -> void:
	if combat.is_empty() or counter_lock > 0.0 or hp <= 0.0:
		return
	counter_lock = COUNTER_CD
	var damage := _player_damage(1.0)
	combat.hp = maxf(0.0, float(combat.hp) - damage)
	counter_hits += 1
	floated.emit("damage", "enemy", damage, false)
	note("你反手还了一下：%s 受到 %d 伤害。" % [str(combat.get("name", "敌人")), int(damage)])
	if float(combat.hp) <= 0.0:
		_win_combat()

## 怪物反击：角色主动打它、它没死就还手；同样受 0.1 秒统一 CD 限制。
func _counter_from_enemy() -> void:
	if combat.is_empty() or counter_lock > 0.0 or hp <= 0.0:
		return
	counter_lock = COUNTER_CD
	_enemy_hits_player(float(combat.damage), false)
	counter_hits += 1

func attack() -> bool:
	if combat.is_empty() or attack_cd > 0.0:
		return false
	attack_cd = attack_rate()
	stamina = maxf(0.0, stamina - 1.5)
	var damage := _player_damage(1.0)
	combat.hp = maxf(0.0, float(combat.hp) - damage)
	floated.emit("damage", "enemy", damage, false)
	note("你击中 %s，造成 %d 伤害。" % [str(combat.name), int(damage)])
	set_expression("determined", 1.0)
	if float(combat.hp) <= 0.0:
		_win_combat()
	else:
		_counter_from_enemy()
	changed.emit()
	return true

func heavy_attack() -> bool:
	if combat.is_empty() or heavy_cd > 0.0:
		return false
	if stamina < 12.0:
		note("体力不足，挥不动重击。")
		return false
	stamina -= 12.0
	heavy_cd = 8.0 * (HIDE_ACTION if form == FORM_HIDE else 1.0)
	attack_cd = maxf(attack_cd, 0.45)
	var damage := _player_damage(2.1)
	combat.hp = maxf(0.0, float(combat.hp) - damage)
	floated.emit("damage", "enemy", damage, true)
	note("重击命中 %s，造成 %d 伤害。" % [str(combat.name), int(damage)])
	set_expression("angry", 1.0)
	if float(combat.hp) <= 0.0:
		_win_combat()
	else:
		_counter_from_enemy()
	changed.emit()
	return true

func flee() -> bool:
	if combat.is_empty():
		return false
	if stamina < 6.0:
		note("体力不足，跑不动。")
		return false
	stamina -= 6.0
	if rng.randf() < 0.65:
		_remove_enemy(str(combat.uid))
		note("你甩开了 %s。" % str(combat.name))
		combat = {}
		set_expression("worried", 1.2)
		changed.emit()
		return true
	note("没能甩开 %s。" % str(combat.name))
	combat.next = 0.5
	changed.emit()
	return false

func _win_combat() -> void:
	if combat.is_empty():
		return
	var enemy_name := str(combat.name)
	var boss := bool(combat.get("boss", false))
	_loot_enemy(combat)
	_remove_enemy(str(combat.uid))
	combat = {}
	kills += 1
	set_expression("joy", 2.0)
	changed.emit()
	if boss:
		finish(true, "击败血月使徒")

## 从敌人掉落表里摸两件东西（背包满就留在原地）。
func _loot_enemy(enemy: Dictionary) -> void:
	var loot: Dictionary = Data.enemy(str(enemy.get("kind", ""))).get("loot", {})
	var got: Array = []
	var loot_tier := 2 if bool(enemy.get("boss", false)) else (1 if is_night() else 0)
	for i in 2:
		var kind := _roll_table(loot)
		if kind.is_empty():
			break
		if add_item(kind, 1, loot_tier):
			got.append("%s%s" % [Data.tier_name(loot_tier), Data.item_name(kind)])
		else:
			note("背包满了，%s 掉在了地上。" % Data.item_name(kind))
	if not got.is_empty():
		note("战利品：%s。" % "、".join(got))

func travel(target_id: String) -> bool:
	if ended_flag:
		return false
	if not combat.is_empty():
		note("先脱离战斗，再换地区。")
		return false
	if target_id == area_id:
		return false
	if not target_id in area().get("neighbors", []):
		note("这里和那里不相邻。")
		return false
	var target := Data.area(target_id)
	if target.is_empty():
		return false
	if int(target.get("unlock_day", 1)) > day:
		note("第 %d 天才会出现：%s。" % [int(target.unlock_day), str(target.name)])
		return false
	var need := str(target.get("unlock_item", ""))
	if not need.is_empty() and item_count(need) <= 0:
		note("还差一件东西才能进去：%s。" % Data.item_name(need))
		return false
	if not search.is_empty():
		cancel_search("你中断了翻找，动身换区。")
	stamina = maxf(0.0, stamina - 3.0)
	clock += 6.0
	area_id = target_id
	_refresh_area_enemies()
	note("抵达 %s。" % area_name())
	if bool(flags.get("spirit_safe", false)):
		flags.spirit_safe = false
		for enemy in active_enemies():
			enemy.wake = 0.0
			enemy.alert = false
	if clock >= Data.DAY_SECONDS:
		clock = Data.DAY_SECONDS
		advance_day()
		return true
	_notify_area_threat()
	changed.emit()
	return true

func _notify_area_threat() -> void:
	if not has_enemy():
		return
	if bool(area_notified.get(area_id, false)):
		return
	area_notified[area_id] = true
	note("这一带有东西在动，别弄出太大声音。")

func advance_day() -> void:
	if ended_flag:
		return
	if day >= Data.DAYS:
		finish(true, "活过第三夜")
		return
	day += 1
	clock = 0.0
	var before_day := hp
	hp = minf(total_max_hp(), hp + total_max_hp() * 0.3)
	if hp > before_day:
		floated.emit("heal", "player", hp - before_day, false)
	stamina = max_stamina
	search = {}
	combat = {}
	event_state = {}
	paused = false
	events_used.clear()
	area_notified.clear()
	_reset_uses()
	area_enemies.clear()
	_refresh_area_enemies()
	_roll_all_events()
	note("第 %d 天。天色变了。" % day)
	_notify_area_threat()
	set_expression("determined", 2.0)
	changed.emit()

func can_extract() -> bool:
	return not ended_flag and combat.is_empty() and area_id in EXTRACT_AREAS and clock >= Data.EXTRACT_AFTER

func extract() -> bool:
	if not can_extract():
		note("现在还不能撤离。")
		return false
	finish(true, "撤离成功")
	return true

func can_rest() -> bool:
	return not ended_flag and combat.is_empty() and search.is_empty() and stamina >= 8.0

func rest() -> bool:
	if not can_rest():
		return false
	stamina = maxf(0.0, stamina - 8.0)
	var before_rest := hp
	hp = minf(total_max_hp(), hp + 6.0)
	if hp > before_rest:
		floated.emit("heal", "player", hp - before_rest, false)
	clock += 20.0
	note("你靠着墙喘了一会儿。")
	if clock >= Data.DAY_SECONDS:
		clock = Data.DAY_SECONDS
		advance_day()
	changed.emit()
	return true

## ------------------------------------------------------------------ 形态

func form_name() -> String:
	return "行动" if form == FORM_ACT else "隐藏"

## Z 键：行动 ⇄ 隐藏。切换后 2 秒内不能再切；隐藏会打断翻找。
func toggle_form() -> bool:
	if ended_flag or paused:
		return false
	if form_cd > 0.0:
		note("姿态还没缓过来。")
		return false
	if not search.is_empty():
		cancel_search("你换了姿态，翻找停下。")
	form = FORM_HIDE if form == FORM_ACT else FORM_ACT
	form_cd = FORM_SWITCH_CD
	if form == FORM_HIDE:
		note("你压低身形，藏进阴影。")
		set_expression("worried", 1.2)
	else:
		note("你直起身，重新行动。")
		set_expression("neutral", 1.0)
	changed.emit()
	return true

## ------------------------------------------------------------------ 随机事件
##
## 事件点由 `run_seed + day + phase + area` 决定（同一局可复现，不同局不一样）。
## 地图上只显示带问号的圆环；名字与描述在被点开时才揭示。
## 互动本身是一串 steps：每个选项花的是**局内时间**，失败会受伤/惊动怪物。
## `live` 事件在窗口打开时**不暂停**——怪物照常积累察觉、照常出手。

func events_here() -> Array:
	return area_events.get(area_id, [])

func find_event(uid: String) -> Dictionary:
	for marker in events_here():
		if str(marker.get("uid", "")) == uid:
			return marker
	return {}

func event_marker_used(uid: String) -> bool:
	var marker := find_event(uid)
	return marker.is_empty() or bool(marker.get("used", false))

func can_begin_event(uid: String) -> Dictionary:
	if ended_flag:
		return {"ok": false, "why": "这一局已经结束了。"}
	if not combat.is_empty():
		return {"ok": false, "why": "先脱离战斗。"}
	if not search.is_empty():
		return {"ok": false, "why": "正在翻找。"}
	if not event_state.is_empty():
		return {"ok": false, "why": "你已经在做别的事了。"}
	if event_marker_used(uid):
		return {"ok": false, "why": "这里已经没有别的了。"}
	return {"ok": true, "why": ""}

## 点开一个事件点：进入互动窗口。默认暂停；`live` 事件继续走时间。
func begin_event(uid: String) -> bool:
	var verdict := can_begin_event(uid)
	if not bool(verdict.ok):
		note(str(verdict.why))
		return false
	var marker := find_event(uid)
	var ev := Data.event(str(marker.get("id", "")))
	if ev.is_empty():
		return false
	event_rng.seed = int(run_seed) * 977 + absi(uid.hash()) + day * 31
	event_state = {
		"uid": uid,
		"id": str(marker.get("id", "")),
		"name": str(ev.get("name", "未命名")),
		"art": str(ev.get("art", "reliquary")),
		"live": bool(ev.get("live", false)),
		"log": [str(ev.get("reveal", ""))],
		"step": "",
		"options": [],
		"finished": false,
		"granted": {},
	}
	paused = not bool(event_state.get("live", false))
	if bool(event_state.get("live", false)):
		note("这里的时间没有停。你的手得快一点。")
	_enter_step(str(ev.get("start", "start")))
	changed.emit()
	return true

func event_options() -> Array:
	return event_state.get("options", [])

func event_choose(index: int) -> bool:
	if event_state.is_empty() or bool(event_state.get("finished", false)):
		return false
	var shown: Array = event_options()
	if index < 0 or index >= shown.size():
		return false
	var pick: Dictionary = shown[index]
	var step: Dictionary = Data.event(str(event_state.get("id", ""))).get("steps", {}).get(str(event_state.get("step", "")), {})
	var raw: Array = step.get("options", [])
	if raw.is_empty():
		_close_event_state(true)
		changed.emit()
		return true
	var opt: Dictionary = raw[int(pick.get("index", index))]
	var verdict := _option_verdict(opt)
	if not bool(verdict.ok):
		event_state.log.append(str(verdict.why))
		changed.emit()
		return false
	var cost := float(opt.get("time", 0))
	if cost > 0.0:
		_spend_event_time(cost)
		if event_state.is_empty():
			return true
	if opt.has("log"):
		event_state.log.append(str(opt.log))
	if opt.has("hp"):
		_event_hp(float(opt.hp))
	if opt.has("stamina"):
		_event_stamina(float(opt.stamina))
	if opt.has("noise"):
		_event_noise(float(opt.noise))
	var next := str(opt.get("next", ""))
	if opt.has("check"):
		var check: Dictionary = opt.check
		var chance := float(check.get("chance", 0.6))
		if event_rng.randf() < chance:
			next = str(check.get("success", next))
			if not str(check.get("success_log", "")).is_empty():
				event_state.log.append(str(check.success_log))
		else:
			next = str(check.get("fail", next))
			if not str(check.get("fail_log", "")).is_empty():
				event_state.log.append(str(check.fail_log))
	if hp <= 0.0:
		_close_event_state(false)
		finish(false, "死在了不该碰的东西上")
		return true
	if not search.is_empty():
		cancel_search("你被别的事分了神。")
	if next.is_empty():
		_close_event_state(true)
	else:
		_enter_step(next)
	changed.emit()
	return true

## 玩家主动关掉窗口（相当于放弃这次调查，事件点保留）。
func close_event() -> void:
	if event_state.is_empty():
		return
	event_state = {}
	paused = false
	changed.emit()

func _enter_step(step_id: String) -> void:
	var ev := Data.event(str(event_state.get("id", "")))
	var steps: Dictionary = ev.get("steps", {})
	var step: Dictionary = steps.get(step_id, {})
	if step.is_empty():
		_close_event_state(true)
		return
	event_state["step"] = step_id
	if not str(step.get("text", "")).is_empty():
		event_state.log.append(str(step.text))
	var granted: Dictionary = event_state.get("granted", {})
	var stamp := "step:" + step_id
	if not granted.has(stamp):
		granted[stamp] = true
		event_state["granted"] = granted
		if step.has("hp"):
			_event_hp(float(step.hp))
		if step.has("stamina"):
			_event_stamina(float(step.stamina))
		if step.has("noise"):
			_event_noise(float(step.noise))
		if step.has("reward"):
			_apply_event_reward(step.reward)
	var options: Array = []
	var raw: Array = step.get("options", [])
	for i in raw.size():
		var opt: Dictionary = raw[i]
		var verdict := _option_verdict(opt)
		options.append({
			"index": i,
			"label": str(opt.get("label", "继续")),
			"ok": bool(verdict.get("ok", false)),
			"why": str(verdict.get("why", "")),
			"time": int(opt.get("time", 0)),
		})
	if options.is_empty():
		options.append({"index": 0, "label": "离开", "ok": true, "why": "", "time": 0})
	event_state["options"] = options
	changed.emit()

## 分支条件只用"模糊回应"表达：需要道具时不报物品名，只说人话。
func _option_verdict(opt: Dictionary) -> Dictionary:
	var items: Array = opt.get("items", [])
	if not items.is_empty():
		var has := false
		for kind in items:
			if item_count(str(kind)) > 0 or pocket_of(str(kind)) > 0:
				has = true
		if not has:
			return {"ok": false, "why": "你摸了摸身上，没有能派上用场的东西。"}
	var flag_list: Array = opt.get("flags", [])
	if not flag_list.is_empty():
		var lit := false
		for flag in flag_list:
			if bool(flags.get(str(flag), false)):
				lit = true
		if not lit:
			return {"ok": false, "why": "这里太暗了，你得先弄出一点亮。"}
	if opt.has("hp") and hp + float(opt.hp) <= 0.0:
		return {"ok": false, "why": "这一下会要了你的命。你不敢。"}
	if opt.has("stamina") and stamina + float(opt.stamina) < 0.0:
		return {"ok": false, "why": "你累得抬不起手。"}
	return {"ok": true, "why": ""}

func _apply_event_reward(reward: Dictionary) -> void:
	var table := str(reward.get("table", ""))
	var tier := int(reward.get("tier", 0))
	var rolls: Array = reward.get("rolls", [1, 1])
	var count := event_rng.randi_range(int(rolls[0]), int(rolls[1]))
	var got: Array = []
	for i in count:
		var kind := Data.roll_event_loot(table, event_rng)
		if kind.is_empty():
			break
		if add_item(kind, 1, tier):
			got.append("%s%s" % [Data.tier_name(tier), Data.item_name(kind)])
		else:
			event_state.log.append("背包塞满了，%s 只能留在原地。" % Data.item_name(kind))
	if not got.is_empty():
		event_state.log.append("你拿到了：%s。" % "、".join(got))

func _event_hp(amount: float) -> void:
	if amount <= 0.0:
		var dealt := -amount
		hp = maxf(0.0, hp - dealt)
		floated.emit("hurt", "player", dealt, false)
		event_state.log.append("你受了 %d 点伤。" % int(dealt))
	else:
		var before := hp
		hp = minf(total_max_hp(), hp + amount)
		if hp > before:
			floated.emit("heal", "player", hp - before, false)
			event_state.log.append("你缓过来 %d 点。" % int(hp - before))

func _event_stamina(amount: float) -> void:
	var before := stamina
	stamina = clampf(stamina + amount, 0.0, max_stamina)
	if amount < 0.0:
		event_state.log.append("这一下耗掉了 %d 点体力。" % int(before - stamina))
	elif stamina > before:
		event_state.log.append("你喘匀了气，回复 %d 点体力。" % int(stamina - before))

func _event_noise(amount: float) -> void:
	if amount <= 0.0:
		return
	var stirred := false
	for enemy in active_enemies():
		enemy.wake = minf(1.0, float(enemy.wake) + amount * float(enemy.aggression))
		stirred = true
	if stirred:
		event_state.log.append("你弄出的动静传了出去。附近有什么被惊动了。")

func _spend_event_time(seconds: float) -> void:
	if seconds <= 0.0:
		return
	clock += seconds
	event_state.log.append("（时间过去了 %d 秒。）" % int(seconds))
	if clock >= Data.DAY_SECONDS:
		clock = Data.DAY_SECONDS
		event_state = {}
		paused = false
		advance_day()

func _close_event_state(done: bool) -> void:
	if event_state.is_empty():
		return
	var uid := str(event_state.get("uid", ""))
	if done and not uid.is_empty():
		events_used["%s:%s:%d" % [area_id, str(event_state.get("id", "")), day]] = true
		var list: Array = area_events.get(area_id, [])
		for marker in list:
			if str(marker.get("uid", "")) == uid:
				marker["used"] = true
		area_events[area_id] = list
		note("你离开了那处地方。")
	event_state["finished"] = true
	paused = false

## 每天/每时段重刷：权重抽 2~3 个，再按条件追加专属事件；always 事件必出。
func _roll_all_events() -> void:
	if ended_flag:
		return
	area_events.clear()
	for area in Data.AREAS:
		area_events[area] = _roll_events(str(area))

func _roll_events(area: String) -> Array:
	var grng := RandomNumberGenerator.new()
	grng.seed = int(run_seed) * 7919 + day * 131 + absi(area.hash()) + absi(phase_id().hash()) * 17
	var anchors: Array = Data.event_spawns(area).duplicate()
	for i in range(anchors.size() - 1, 0, -1):
		var j := grng.randi_range(0, i)
		var swap = anchors[i]
		anchors[i] = anchors[j]
		anchors[j] = swap
	var chosen: Array = []
	for id in Data.EVENTS:
		var ev: Dictionary = Data.EVENTS[id]
		if bool(ev.get("always", false)) and Data.event_matches(ev, area, day, phase_id()):
			if not events_used.has("%s:%s:%d" % [area, str(id), day]):
				chosen.append(str(id))
	var pool: Array = []
	for id in Data.EVENTS:
		var ev: Dictionary = Data.EVENTS[id]
		if str(id) in chosen:
			continue
		if not Data.event_matches(ev, area, day, phase_id()):
			continue
		if events_used.has("%s:%s:%d" % [area, str(id), day]):
			continue
		pool.append(str(id))
	var count := grng.randi_range(EVENTS_PER_DAY_MIN, EVENTS_PER_DAY_MAX)
	while chosen.size() < count and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += float(Data.EVENTS[id].get("weight", 1))
		var roll := grng.randf() * total
		var picked: String = str(pool[0])
		for i in pool.size():
			roll -= float(Data.EVENTS[pool[i]].get("weight", 1))
			if roll <= 0.0:
				picked = str(pool[i])
				break
		chosen.append(picked)
		pool.erase(picked)
	if grng.randf() < EVENT_SPECIAL_CHANCE:
		var specials: Array = []
		for id in Data.EVENTS:
			var ev: Dictionary = Data.EVENTS[id]
			if not Data.event_matches(ev, area, day, phase_id()):
				continue
			var special := not str(ev.get("phase", "")).is_empty() or int(ev.get("min_day", 1)) > 1
			if not special or str(id) in chosen:
				continue
			if events_used.has("%s:%s:%d" % [area, str(id), day]):
				continue
			specials.append(str(id))
		if not specials.is_empty():
			chosen.append(str(specials[grng.randi_range(0, specials.size() - 1)]))
	var out: Array = []
	var fixed_anchors: Array = Data.event_spawns(area)
	for i in chosen.size():
		var id := str(chosen[i])
		var ev: Dictionary = Data.EVENTS[id]
		var fixed := int(ev.get("anchor", -1))
		var at: Vector2 = anchors[i % anchors.size()]
		if fixed >= 0 and fixed < fixed_anchors.size():
			at = fixed_anchors[fixed]
		out.append({"uid": "%s:%s:%d" % [area, id, i], "id": id, "at": at, "used": false})
	return out

## 测试/调试用：在当前地区强制摆一个事件点。
func debug_spawn_event(event_id: String, anchor: int = -1) -> String:
	var ev := Data.event(event_id)
	if ev.is_empty():
		return ""
	var anchors: Array = Data.event_spawns(area_id)
	var at: Vector2 = anchors[clampi(anchor, 0, anchors.size() - 1)]
	var uid := "%s:%s:debug" % [area_id, event_id]
	var list: Array = area_events.get(area_id, [])
	for i in range(list.size() - 1, -1, -1):
		if str(list[i].get("uid", "")) == uid:
			list.remove_at(i)
	list.append({"uid": uid, "id": event_id, "at": at, "used": false})
	area_events[area_id] = list
	changed.emit()
	return uid

func debug_clear_events() -> void:
	area_events[area_id] = []
	changed.emit()

func finish(victory: bool, reason: String) -> void:
	if ended_flag:
		return
	ended_flag = true
	paused = true
	event_state = {}
	combat = {}
	search = {}
	expression = "joy" if victory else "sad"
	expression_time = 999.0
	var result := {
		"victory": victory,
		"extracted": victory,
		"day": day,
		"clock": clock,
		"kills": kills,
		"searched": searched,
		"loot": bag.duplicate(true),
		"value": bag_value(),
		"reason": reason,
		"hero": hero,
		"seed": run_seed,
	}
	note("本局结束：%s。" % reason)
	finished.emit(result)
	changed.emit()

func set_paused(value: bool) -> void:
	if ended_flag:
		paused = false
		return
	paused = value

func set_expression(value: String, seconds: float = 2.0) -> void:
	expression = value
	expression_time = seconds

func tick(dt: float) -> void:
	if ended_flag or paused:
		return
	clock += dt
	form_cd = maxf(0.0, form_cd - dt)
	search_cd = maxf(0.0, search_cd - dt)
	counter_lock = maxf(0.0, counter_lock - dt)
	var now_phase := phase_id()
	if now_phase != last_phase:
		last_phase = now_phase
		note("天色转为%s。" % phase_name())
		_refresh_area_enemies()
		# 时段专属事件在这一刻才可能出现：整片区域的问号点重新洗一遍。
		_roll_all_events()
	if not combat.is_empty():
		_tick_combat(dt)
		if ended_flag:
			return
	else:
		if not search.is_empty():
			_advance_search(dt)
			if ended_flag:
				return
		else:
			stamina = minf(max_stamina, stamina + dt * 1.0)
		_tick_area_enemies(dt)
		if ended_flag:
			return
	attack_buff_time = maxf(0.0, attack_buff_time - dt)
	heavy_cd = maxf(0.0, heavy_cd - dt)
	smoke_guard = maxf(0.0, smoke_guard - dt * 0.2)
	expression_time = maxf(0.0, expression_time - dt)
	if expression_time <= 0.0 and expression != "neutral":
		expression = "neutral"
	if clock >= Data.DAY_SECONDS:
		clock = Data.DAY_SECONDS
		advance_day()
		if ended_flag:
			return
	changed.emit()

## 没进战斗面板的怪物：按"攻击欲望 × 隐藏系数"积累察觉，满了才进入攻击循环。
## 攻击循环里每个怪有自己的 CD（带 ±20% 抖动），CD 没到怎么随机都不会打。
func _tick_area_enemies(dt: float) -> void:
	if combat.is_empty() == false:
		return
	var stealth := HIDE_STEALTH if form == FORM_HIDE else 1.0
	for enemy in active_enemies():
		var aggression := float(enemy.get("aggression", 1.0))
		var gain := dt * NOTICE_RATE * aggression * stealth
		var decay := dt * 0.18 if form == FORM_HIDE else 0.0
		enemy.wake = clampf(float(enemy.get("wake", 0.0)) + gain - decay, 0.0, 1.0)
		if float(enemy.wake) >= 1.0 and not bool(enemy.get("alert", false)):
			enemy.alert = true
			note("%s 注意到你了。" % str(enemy.get("name", "暗处的东西")))
		if bool(enemy.get("alert", false)) and form == FORM_HIDE and float(enemy.wake) < 0.35:
			enemy.alert = false
			note("它跟丢了你。")
		if not bool(enemy.get("alert", false)):
			continue
		enemy.next = float(enemy.get("next", 2.0)) - dt
		if float(enemy.next) > 0.0:
			continue
		enemy.next = float(enemy.get("interval", 2.0)) * rng.randf_range(0.8, 1.2)
		if not search.is_empty():
			cancel_search("你被从背后抓了一下，翻找中断了。")
		_enemy_hits_player(float(enemy.get("damage", 5.0)), false)
		if ended_flag:
			return
		_counter_from_passive(enemy)

## 被偷袭时的反击：目标不是 combat 里的敌人，而是那个怪本身。
func _counter_from_passive(enemy: Dictionary) -> void:
	if counter_lock > 0.0 or hp <= 0.0 or ended_flag:
		return
	counter_lock = COUNTER_CD
	var damage := _player_damage(1.0)
	enemy.hp = maxf(0.0, float(enemy.get("hp", 1.0)) - damage)
	counter_hits += 1
	note("你反手还了一下：%s 受到 %d 伤害。" % [str(enemy.get("name", "敌人")), int(damage)])
	if float(enemy.hp) <= 0.0:
		var enemy_name := str(enemy.get("name", "敌人"))
		var boss := bool(enemy.get("boss", false))
		_remove_enemy(str(enemy.get("uid", "")))
		kills += 1
		note("你反手打死了 %s。" % enemy_name)
		_loot_enemy(enemy)
		set_expression("joy", 1.5)
		if boss:
			finish(true, "击败血月使徒")

func status_lines() -> Array:
	var lines: Array = []
	lines.append("第 %d 天 · %s · %s" % [day, phase_name(), area_name()])
	lines.append("生命 %d/%d   体力 %d/%d" % [int(hp), int(total_max_hp()), int(stamina), int(max_stamina)])
	lines.append("攻击 %d   防御 %d%%   背包 %d/%d" % [int(attack_power()), int(defense_value() * 100.0), bag.size(), capacity])
	return lines

## 测试用的最小钩子：不经过 UI 直接给材料/拨时间。
func debug_give(kind: String, count: int = 1) -> void:
	add_item(kind, count)
	changed.emit()

func debug_set_clock(value: float) -> void:
	clock = clampf(value, 0.0, Data.DAY_SECONDS - 0.01)
	changed.emit()

func debug_kill_enemies() -> void:
	area_enemies[area_id] = []
	combat = {}
	changed.emit()

func debug_spawn_enemy(kind: String = "scavenger") -> void:
	var base: Dictionary = Data.enemy(kind)
	if base.is_empty():
		return
	var enemies: Array = active_enemies()
	enemies.append(_make_enemy(area_id, kind, base, Vector2(0.58, 0.62), 80 + enemies.size()))
	area_enemies[area_id] = enemies
	changed.emit()

## 测试用：直接把一个怪的察觉拉满，省得等两分钟。
func debug_alert_enemy() -> void:
	for enemy in active_enemies():
		enemy.wake = 1.0
		enemy.alert = true
		enemy.next = 0.0
