class_name RogueGrowth
extends RefCounted

## R12 轮：局外永久成长树（「灰烬」）数据层。
## 契约：`output/ROGUE-CONTRACTS.md` §4（`profile.data` 的 `ashes`/`growth`）、
## §5（冻结签名）、§6.2（禁止全局随机）、§9（通用纪律）。
##
## 本模块是**纯逻辑 + 局外存档读写**，不碰战斗状态真相：
##   * `tree()/power()/can_buy()/buy()/effects()/cost_for()/...` 只处理 `profile.data` 一份字典，
##     不读会话、不消耗 `s.rng`、不使用全局 `randi()/randf()`；
##   * `ashes_on_settle()` 只**读** `s.raid` 与 `p` 里的既成事实；
##   * `grant()` 的写入面只有两个：`p.rogue_ash_run`（本局计数，进快照）与
##     **局外** `profile.data.ashes`（不进快照）。`settle()` 的 `ended` 守卫负责"只发一次"。
##
## 灰烬与成长树是**局外**进度：`s.raid` 里只有本局计数 `rogue_ash_run`（契约 §2/§3），
## 所以本模块的任何返回值都不需要进快照。
##
## profile 通道（契约未冻结，属 W1 接线项，见 `output/R12-GROWTH-DATA.md` 待接线清单）：
##   `grant()` 需要拿到 `profile.data`。本模块按顺序**安全探测**，绝不访问不存在的属性：
##     1. `s.has_method("profile_data")` → 取其返回的 Dictionary（推荐的正式接线）；
##     2. `s.get_meta("profile_data", null)` 是 Dictionary → 用它（测试与过渡期）；
##     3. 都没有 → `{}`：`grant()` 仍把本局灰烬累加进 `p.rogue_ash_run`，
##        只是"不入账"，接线前不会崩。
##
## 花费曲线（追加，冻结签名只给了每节点 `cost` 基数）：
##   `cost_for(id, level) = cost * (level + 1)`，即第 1 级花 `cost`、第 2 级 `2*cost`……
##   单调不降，max 级后 `cost_for()` 返回 `-1`（= 不可再买）。

# ---------------------------------------------------------------- 常量：花费与结算

## 每清一间房的灰烬基础值。
const BASE_PER_ROOM := 12
## 每推进一层的灰烬基础值。
const BASE_PER_FLOOR := 30
## 成功撤离（`p.status == "extracted"`）的额外灰烬。
const WIN_BONUS := 150
## 灰烬加成上限（`ash_bonus` 是乘性增量：+100% 封顶）。
const MAX_ASH_BONUS := 1.0
## `power()` 里敌人侧倍率的下限（玩家通过成长最多把敌人压到 70%）。
const MIN_ENEMY_SCALE := 0.70
## 重置成长树的返还比例（取整后返还）。
const RESET_REFUND_RATIO := 0.5

# ---------------------------------------------------------------- 常量：成长树节点
#
# `effect` 的键**全部**取自仓库里既有词汇，不另造名字：
#   * `enemy_hp`/`enemy_damage`/`player_damage`/`player_damage_taken`/`gold`/`xp_gain`/
#     `shop_price`/`chest_drop`/`heal_scale` —— `scripts/rogue_variants.gd` 的 canonical 键
#     （同为"乘性增量、加法合成"语义）；
#   * `start_coins`/`start_rerolls`/`loot_tier` —— 整数加法；
#   * `move_speed` —— 浮点加法（`rogue_curses.gd` 的 `move_speed` 同义）；
#   * `ash_bonus` —— 本轮新增（灰烬是本契约 §4 新引入的局外货币，无既有同义词；
#     仅影响**结算产出**，不影响战斗），已在交付文档里登记为追加项。
const NODES := {
	"coin_purse": {
		"name": "沉甸钱囊", "desc": "每级开局多带 25 魔晶",
		"cost": 30, "max": 4, "requires": [],
		"effect": {"start_coins": 25},
	},
	"ash_vein": {
		"name": "灰烬矿脉", "desc": "每级本局结算灰烬 +10%",
		"cost": 40, "max": 5, "requires": [],
		"effect": {"ash_bonus": 0.10},
	},
	"reroll_charm": {
		"name": "运势护符", "desc": "每级开局多 1 次商店刷新",
		"cost": 45, "max": 3, "requires": [],
		"effect": {"start_rerolls": 1},
	},
	"iron_constitution": {
		"name": "铁躯", "desc": "每级敌人伤害 -3%",
		"cost": 50, "max": 5, "requires": [],
		"effect": {"enemy_damage": -0.03},
	},
	"hunt_instinct": {
		"name": "猎杀本能", "desc": "每级我方伤害 +4%",
		"cost": 50, "max": 5, "requires": [],
		"effect": {"player_damage": 0.04},
	},
	"warden_plate": {
		"name": "守望重甲", "desc": "每级受到伤害 -3%",
		"cost": 55, "max": 5, "requires": ["iron_constitution"],
		"effect": {"player_damage_taken": -0.03},
	},
	"deep_pockets": {
		"name": "深袋", "desc": "每级商店价格 -5%",
		"cost": 40, "max": 4, "requires": ["coin_purse"],
		"effect": {"shop_price": -0.05},
	},
	"scavenger": {
		"name": "拾荒者", "desc": "每级宝箱掉落率 +8%",
		"cost": 45, "max": 4, "requires": [],
		"effect": {"chest_drop": 0.08},
	},
	"field_medic": {
		"name": "战地医者", "desc": "每级治疗效果 +8%",
		"cost": 40, "max": 4, "requires": [],
		"effect": {"heal_scale": 0.08},
	},
	"swift_boots": {
		"name": "疾行长靴", "desc": "每级移动速度 +12",
		"cost": 40, "max": 4, "requires": [],
		"effect": {"move_speed": 12.0},
	},
	"scholar": {
		"name": "博识", "desc": "每级经验获取 +10%",
		"cost": 45, "max": 4, "requires": [],
		"effect": {"xp_gain": 0.10},
	},
	"midas_hand": {
		"name": "点金之手", "desc": "每级魔晶收入 +10%",
		"cost": 45, "max": 4, "requires": ["deep_pockets"],
		"effect": {"gold": 0.10},
	},
	"hunter_luck": {
		"name": "猎运", "desc": "每级掉落品质 +1 档",
		"cost": 60, "max": 3, "requires": [],
		"effect": {"loot_tier": 1},
	},
	"monster_slaying": {
		"name": "屠戮研习", "desc": "每级敌人生命 -4%",
		"cost": 60, "max": 5, "requires": ["hunt_instinct", "warden_plate"],
		"effect": {"enemy_hp": -0.04},
	},
}

## 乘性增量键（加法合成，再按 `_BOUNDS` 上下限 clamp）。
const SCALE_KEYS := [
	"enemy_hp", "enemy_damage", "player_damage", "player_damage_taken",
	"gold", "xp_gain", "shop_price", "chest_drop", "heal_scale", "ash_bonus",
]
## 整数加法键。
const INT_KEYS := ["start_coins", "start_rerolls", "loot_tier"]
## 浮点加法键。
const FLOAT_KEYS := ["move_speed"]

## 每个键的 `[下限, 上限]`（成长树只允许玩家受益的方向，例外见注释）。
const BOUNDS := {
	"enemy_hp": [-0.30, 0.00],
	"enemy_damage": [-0.30, 0.00],
	"player_damage": [0.00, 0.40],
	"player_damage_taken": [-0.40, 0.00],
	"gold": [0.00, 0.50],
	"xp_gain": [0.00, 0.50],
	"shop_price": [-0.40, 0.00],
	"chest_drop": [0.00, 0.40],
	"heal_scale": [0.00, 0.40],
	"ash_bonus": [0.00, 1.00],
	"move_speed": [0.00, 90.0],
	"start_coins": [0, 400],
	"start_rerolls": [0, 6],
	"loot_tier": [0, 3],
}

## 命中判定几何字段：成长树**永不**产出这些键（用户硬要求：判定不变）。
const FORBIDDEN_KEYS := [
	"hit_radius", "collision_radius", "hurt_radius", "radius", "zone", "hitbox",
]

# ---------------------------------------------------------------- 冻结签名（契约 §5）

## {id -> {"cost":int,"max":int,"requires":Array[String],"effect":Dictionary}}
## 返回**深拷贝**，调用方改不动常量表。节点名/描述见追加的 `label()`/`describe()`。
static func tree() -> Dictionary:
	var out: Dictionary = {}
	for id in NODES:
		var row: Dictionary = NODES[id]
		out[id] = {
			"cost": int(row["cost"]),
			"max": int(row["max"]),
			"requires": (row["requires"] as Array).duplicate(),
			"effect": (row["effect"] as Dictionary).duplicate(true),
		}
	return out

## 只读；把成长树等级合成成战力修正。
## 语义：`enemy_hp`/`enemy_damage` 是**乘性缩放**（1.0 = 不修正，<1.0 = 对玩家有利），
## `start_coins`/`start_rerolls` 是**整数加成**（加到 `p.rogue_gold` / `p.rogue_rerolls`）。
## 返回**恰好**这 4 个键（契约冻结形状）。
static func power(profile_data: Dictionary) -> Dictionary:
	var mods := effects(profile_data)
	return {
		"enemy_hp": clampf(1.0 + float(mods.get("enemy_hp", 0.0)), MIN_ENEMY_SCALE, 1.0),
		"enemy_damage": clampf(1.0 + float(mods.get("enemy_damage", 0.0)), MIN_ENEMY_SCALE, 1.0),
		"start_coins": int(mods.get("start_coins", 0)),
		"start_rerolls": int(mods.get("start_rerolls", 0)),
	}

## 能否买下一级（未知 id、已满级、前置未满足、灰烬不足 → false）。
static func can_buy(profile_data: Dictionary, id: String) -> bool:
	return can_buy_reason(profile_data, id) == ""

## 副作用：扣 `profile_data.ashes` 并把 `growth[id] +1`（**不落盘**，由调用方 `save_profile()`）。
## 失败时 `profile_data` **零变化**（所有校验都在写入之前完成）。
static func buy(profile_data: Dictionary, id: String) -> bool:
	if not (profile_data is Dictionary):
		return false
	if can_buy_reason(profile_data, id) != "":
		return false
	var growth := _growth_of(profile_data)
	var level := int(growth.get(id, 0))
	var cost := cost_for(id, level)
	if cost < 0:
		return false
	profile_data["ashes"] = _ashes_of(profile_data) - cost
	growth[id] = level + 1
	profile_data["growth"] = growth
	return true

## 只读；本局应得灰烬（`RogueGrowth.grant()` 的数值来源）。
static func ashes_on_settle(s, p: Dictionary) -> int:
	var stats: Dictionary = {
		"cleared": 0,
		"floor": 0,
		"won": false,
		"ash_bonus": 0.0,
	}
	if s != null and s.get("raid") is Dictionary:
		var raid: Dictionary = s.get("raid")
		stats["cleared"] = int(raid.get("cleared", 0))
		stats["floor"] = int(raid.get("floor", 0))
	if p is Dictionary:
		stats["won"] = str(p.get("status", "")) == "extracted"
	var data := _session_profile_data(s)
	if not data.is_empty():
		stats["ash_bonus"] = ash_bonus(data)
	return earn_for_run(stats)

## 副作用：`p.rogue_ash_run += 值`，并把同一数值累加进**局外** `profile.data.ashes`。
## 幂等性由 `settle()` 的 `ended` 守卫负责（契约 §9.3：结算只有一个出口），本函数不自带守卫。
## 返回本次发放的灰烬（0 表示无产出，此时不写任何字段）。
static func grant(s, p: Dictionary) -> int:
	var value := ashes_on_settle(s, p)
	if value <= 0:
		return 0
	if p is Dictionary:
		p["rogue_ash_run"] = int(p.get("rogue_ash_run", 0)) + value
	var data := _session_profile_data(s)
	if not data.is_empty():
		data["ashes"] = _ashes_of(data) + value
	return value

# ---------------------------------------------------------------- 追加：查询与规则

## 全部节点 id（`NODES` 的键序）。
static func ids() -> Array:
	var out: Array = []
	for id in NODES:
		out.append(str(id))
	return out

## 节点是否在表内。
static func has(id: String) -> bool:
	return NODES.has(id)

## 节点中文名；未知 id → `""`。
static func label(id: String) -> String:
	return str((NODES[id] as Dictionary)["name"]) if NODES.has(id) else ""

## 节点描述；未知 id → `""`。
static func describe(id: String) -> String:
	return str((NODES[id] as Dictionary)["desc"]) if NODES.has(id) else ""

## 节点等级上限；未知 id → `0`。
static func max_level(id: String) -> int:
	return int((NODES[id] as Dictionary)["max"]) if NODES.has(id) else 0

## 该节点**下一级**的花费；未知 id / 已满级 / 非法等级 → `-1`。
static func cost_for(id: String, level: int) -> int:
	if not NODES.has(id) or level < 0 or level >= max_level(id):
		return -1
	return int((NODES[id] as Dictionary)["cost"]) * (level + 1)

## 把某个节点从当前等级练到满级的总花费（用于"死节点"检测）；未知 id → `-1`。
static func cost_to_max(id: String) -> int:
	if not NODES.has(id):
		return -1
	var total := 0
	for level in max_level(id):
		var step := cost_for(id, level)
		if step < 0:
			return -1
		total += step
	return total

## 全树满级所需灰烬总量。
static func total_cost() -> int:
	var total := 0
	for id in ids():
		total += maxi(0, cost_to_max(id))
	return total

## 当前等级（负数/非数值/未知 id → 0；超过上限时按上限截断）。
static func level_of(profile_data: Dictionary, id: String) -> int:
	if not NODES.has(id):
		return 0
	var growth := _growth_of(profile_data)
	if not growth.has(id):
		return 0
	var raw: Variant = growth[id]
	if not (raw is int or raw is float):
		return 0
	return clampi(int(raw), 0, max_level(id))

## 为什么买不了：`""`＝能买；否则 `"unknown"`/`"maxed"`/`"requires"`/`"ashes"`。
static func can_buy_reason(profile_data: Dictionary, id: String) -> String:
	if not NODES.has(id):
		return "unknown"
	var level := level_of(profile_data, id)
	if level >= max_level(id):
		return "maxed"
	for need in (NODES[id] as Dictionary)["requires"]:
		if level_of(profile_data, str(need)) <= 0:
			return "requires"
	var cost := cost_for(id, level)
	if cost < 0 or _ashes_of(profile_data) < cost:
		return "ashes"
	return ""

## 已在该节点上花掉的灰烬（含卖回前的全部投入）。
static func spent_on(profile_data: Dictionary, id: String) -> int:
	var level := level_of(profile_data, id)
	var total := 0
	for step in level:
		var cost := cost_for(id, step)
		if cost < 0:
			break
		total += cost
	return total

## 全树已花掉的灰烬总量。
static func total_spent(profile_data: Dictionary) -> int:
	var total := 0
	for id in ids():
		total += spent_on(profile_data, id)
	return total

## 重置全树可返还的灰烬（按下限取整，永不导致负值）。
static func reset_cost(profile_data: Dictionary) -> int:
	return int(floor(float(total_spent(profile_data)) * RESET_REFUND_RATIO))

## 副作用：清空成长树并把 `reset_cost()` 返还进 `ashes`；没有任何投入时返回 `false` 且不写入。
static func reset(profile_data: Dictionary) -> bool:
	if not (profile_data is Dictionary):
		return false
	var refund := reset_cost(profile_data)
	if refund <= 0 and _growth_of(profile_data).is_empty():
		return false
	profile_data["ashes"] = _ashes_of(profile_data) + refund
	profile_data["growth"] = {}
	return true

## 把成长树合成成一张完整数值表：**总是**含 `SCALE_KEYS + INT_KEYS + FLOAT_KEYS`
## （缺省 0 / 0.0），并按 `BOUNDS` clamp。未知节点 id 被忽略。
static func effects(profile_data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in SCALE_KEYS:
		out[key] = 0.0
	for key in INT_KEYS:
		out[key] = 0
	for key in FLOAT_KEYS:
		out[key] = 0.0
	var growth := _growth_of(profile_data)
	for id in growth:
		var node_id := str(id)
		if not NODES.has(node_id):
			continue
		var level := level_of(profile_data, node_id)
		if level <= 0:
			continue
		var row_effect: Dictionary = (NODES[node_id] as Dictionary)["effect"]
		for key in row_effect:
			var stat := str(key)
			var total := float(out.get(stat, 0.0)) + float(row_effect[key]) * float(level)
			out[stat] = total
	return _clamp(out)

## 本局结算的灰烬加成系数（`0.0`～`MAX_ASH_BONUS`）。
static func ash_bonus(profile_data: Dictionary) -> float:
	return clampf(float(effects(profile_data).get("ash_bonus", 0.0)), 0.0, MAX_ASH_BONUS)

## 纯函数版结算公式：`stats` = `{"cleared":int,"floor":int,"won":bool,"ash_bonus":float}`。
## 非负、对三个自变量分别单调不减。
static func earn_for_run(stats: Dictionary) -> int:
	var cleared := 0
	var floor_index := 0
	var won := false
	var bonus := 0.0
	if stats is Dictionary:
		cleared = maxi(0, int(stats.get("cleared", 0)))
		floor_index = maxi(0, int(stats.get("floor", 0)))
		won = bool(stats.get("won", false))
		bonus = clampf(float(stats.get("ash_bonus", 0.0)), 0.0, MAX_ASH_BONUS)
	var raw := float(BASE_PER_ROOM * cleared + BASE_PER_FLOOR * floor_index)
	if won:
		raw += float(WIN_BONUS)
	return maxi(0, int(round(raw * (1.0 + bonus))))

## 规整一份含 `ashes`/`growth` 的字典（返回**新字典**，不改传入值）：
## `ashes` 非负整数、`growth` 只保留已知 id 且等级 clamp 到上限、去零。
static func sanitize(profile_data: Dictionary) -> Dictionary:
	var out: Dictionary = {"ashes": 0, "growth": {}}
	if not (profile_data is Dictionary):
		return out
	out["ashes"] = _ashes_of(profile_data)
	var clean: Dictionary = {}
	var growth := _growth_of(profile_data)
	for id in growth:
		var node_id := str(id)
		if not NODES.has(node_id):
			continue
		var value := level_of(profile_data, node_id)
		if value > 0:
			clean[node_id] = value
	out["growth"] = clean
	return out

## 命中判定几何字段黑名单（测试用；`effects()`/`power()` 永不产出这些键）。
static func forbidden_keys() -> Array:
	return FORBIDDEN_KEYS.duplicate()

## 全部规范效果键（`effects()` 的键集）。
static func canonical_keys() -> Array:
	var out: Array = []
	out.append_array(SCALE_KEYS)
	out.append_array(INT_KEYS)
	out.append_array(FLOAT_KEYS)
	return out

# ---------------------------------------------------------------- 内部工具

## `profile.data` 的 `ashes`，容错非字典/非数值/负数/浮点。
static func _ashes_of(profile_data: Variant) -> int:
	if not (profile_data is Dictionary):
		return 0
	var raw: Variant = (profile_data as Dictionary).get("ashes", 0)
	if raw is int or raw is float:
		return maxi(0, int(raw))
	return 0

## `profile.data` 的 `growth` **副本**（非字典/脏值 → `{}`；不在此处 clamp，交给 `level_of`）。
static func _growth_of(profile_data: Variant) -> Dictionary:
	if not (profile_data is Dictionary):
		return {}
	var raw: Variant = (profile_data as Dictionary).get("growth", {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}

## 按 `BOUNDS` 逐键 clamp；整数键保持 int（四舍五入）。
static func _clamp(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in source:
		var stat := str(key)
		var value: Variant = source[key]
		if not BOUNDS.has(stat):
			continue
		var bounds: Array = BOUNDS[stat]
		if INT_KEYS.has(stat):
			out[stat] = clampi(int(round(float(value))), int(bounds[0]), int(bounds[1]))
		else:
			out[stat] = clampf(float(value), float(bounds[0]), float(bounds[1]))
	return out

## 安全获取会话上的 `profile.data`（见文件头"profile 通道"）。
## 注意：`get_meta(name, null)` 在键不存在时**会打印引擎错误**，所以先 `has_meta()` 再取。
static func _session_profile_data(s) -> Dictionary:
	if s == null:
		return {}
	if s.has_method("profile_data"):
		var via_method: Variant = s.profile_data()
		if via_method is Dictionary:
			return via_method
	if s.has_meta("profile_data"):
		var via_meta: Variant = s.get_meta("profile_data")
		if via_meta is Dictionary:
			return via_meta
	return {}
