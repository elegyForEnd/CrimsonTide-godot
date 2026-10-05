class_name RogueVariants
extends RefCounted

## 深渊变数（Contracts §5/§6.2）· 数据层 + 纯函数。
##
## 分工（R8 实测）：R2 冻结的「通道」原样保留 —— `roll(s)` 副作用只写 `raid.variant` /
## `raid.variant_serial`，`table()` / `active(s)` 签名不变（R2 已把它接进
## `roguelike.enter()`，验收在 `tests/rogue_wiring.gd`）。
## R8 在其上扩展：数据表 5 → 18 条（**R2 原有的 5 条 id/name/desc/effect 原样保留**，
## 只追加 kind/weight/min_floor），并追加纯函数 `pick()/describe()/modifiers_of()/
## effect_text()/canonical_keys()/bounds()/forbidden_keys()/integer_keys()/
## polarity_map()/ids()/weight_total()`。effect 的键沿用 R2 已选定的词汇表
## （enemy_damage / loot_tier / bullet_size / gold …），避免两轮各造一套名字。
##
## 纪律（契约 §6.2 ／ CHANGE-LOG v2-11）：
## - `roll()` **完全不消耗 `s.rng`**（抽取前后 `s.rng.state` 逐位不变）：改用由
##   `(seed_value, floor, variants_seen 内容)` 纯函数派生的**局部 RNG**，与
##   `RogueGraph.build(seed_value, floor)` 同一思路。这样既保持「同 (seed, floor)
##   必同结果」，又不会给任何既有「按 s.rng 序列走」的断言带来连带漂移；
## - 禁止重置 s.rng.seed；绝不用全局 `randi()/randf()`；
## - 结果写进 raid（会随快照同步），所以客户端读到的永远是房主抽出来的那一条。
##
## 硬约束：
## 1. 变数**只**影响数值倍率与敌人弹幕的「视觉尺寸 / 速度」；任何变数都**不得**产生
##    命中判定几何字段（见 FORBIDDEN_KEYS）。命中判定不变是用户硬要求。
## 2. `pick()` 只用自己的局部 rng（种子由 seed_value/floor/exclude 纯函数派生）。
## 3. `table()` 是纯静态数据：不进存档、不进快照、不落盘。
## 4. 本文件是纯数据 + 纯函数：除 `raid.variant` / `raid.variant_serial` 外不读不写状态。

## —— 变数数据表（纯静态）——
## 字段：id / name / desc / kind(boon|bane|mixed) / weight / min_floor / effect。
## 前 5 条是 R2 冻结的原始条目（id/name/desc/effect 未改），其余为 R8 追加。
## effect 的键必须 ⊆ canonical_keys()，数值语义见 bounds() 与 LABELS。
const TABLE := [
	{"id":"blood_moon","name":"血月","desc":"敌人伤害 +15% · 掉落品质 +1 档",
		"kind":"mixed","weight":8,"min_floor":1,
		"effect":{"enemy_damage":0.15,"loot_tier":1}},
	{"id":"rust","name":"锈蚀","desc":"普攻 -10% · 商店价格 -30%",
		"kind":"mixed","weight":8,"min_floor":1,
		"effect":{"player_damage":-0.10,"shop_price":-0.30}},
	{"id":"fog","name":"雾障","desc":"敌人弹幕更大 · 弹速 -20%",
		"kind":"boon","weight":8,"min_floor":1,
		"effect":{"bullet_size":0.25,"bullet_speed":-0.20}},
	{"id":"bounty","name":"丰饶","desc":"魔晶获取 +25%",
		"kind":"boon","weight":8,"min_floor":1,
		"effect":{"gold":0.25}},
	{"id":"frenzy","name":"狂暴","desc":"敌人移速 +12% · 生命 -8%",
		"kind":"mixed","weight":7,"min_floor":1,
		"effect":{"enemy_speed":0.12,"enemy_hp":-0.08}},
	{"id":"starlight","name":"星辉","desc":"星屑落在伤口上，也落在经验里：经验 +30%",
		"kind":"boon","weight":7,"min_floor":1,
		"effect":{"xp_gain":0.30}},
	{"id":"iron_law","name":"铁律","desc":"无形的甲胄覆在守望者身上：受到伤害 -12%",
		"kind":"boon","weight":7,"min_floor":1,
		"effect":{"player_damage_taken":-0.12}},
	{"id":"stasis","name":"静滞","desc":"魔弹更慢，却也更痛：弹速 -25% · 敌人伤害 +8%",
		"kind":"mixed","weight":6,"min_floor":1,
		"effect":{"bullet_speed":-0.25,"enemy_damage":0.08}},
	{"id":"wolves","name":"群狼","desc":"精英嚎叫此起彼伏：精英出现率 +12% · 掉落品质 +1 档",
		"kind":"mixed","weight":6,"min_floor":2,
		"effect":{"elite_chance":0.12,"loot_tier":1}},
	{"id":"austerity","name":"苦修","desc":"以痛换财：受到伤害 +10% · 魔晶获取 +40%",
		"kind":"mixed","weight":6,"min_floor":1,
		"effect":{"player_damage_taken":0.10,"gold":0.40}},
	{"id":"surge","name":"狂潮","desc":"魔弹又大又急：弹速 +15% · 弹幕尺寸 +10%",
		"kind":"mixed","weight":6,"min_floor":1,
		"effect":{"bullet_speed":0.15,"bullet_size":0.10}},
	{"id":"abundance","name":"余裕","desc":"裂土渗出金屑与星屑：魔晶 +20% · 经验 +20%",
		"kind":"boon","weight":6,"min_floor":1,
		"effect":{"gold":0.20,"xp_gain":0.20}},
	{"id":"bargain","name":"议价","desc":"游商急着清货：商店价格 -25% · 掉落品质 -1 档",
		"kind":"mixed","weight":6,"min_floor":2,
		"effect":{"shop_price":-0.25,"loot_tier":-1}},
	{"id":"apocalypse","name":"天启","desc":"深层的启示让每一击都更重：普攻 +15%",
		"kind":"boon","weight":5,"min_floor":3,
		"effect":{"player_damage":0.15}},
	{"id":"blood_debt","name":"血债","desc":"魔境开始索要利息：受到伤害 +12%",
		"kind":"bane","weight":5,"min_floor":2,
		"effect":{"player_damage_taken":0.12}},
	{"id":"sanctuary","name":"圣佑","desc":"残破的圣坛仍在庇护靠近它的人：受到伤害 -10% · 敌人生命 -10%",
		"kind":"boon","weight":5,"min_floor":3,
		"effect":{"player_damage_taken":-0.10,"enemy_hp":-0.10}},
	{"id":"bedrock","name":"顽石","desc":"魔物的皮壳结成岩石：敌人生命 +20%",
		"kind":"bane","weight":6,"min_floor":2,
		"effect":{"enemy_hp":0.20}},
	{"id":"famine","name":"饥荒","desc":"魔境吞掉了收成：经验 -20% · 魔晶 -15%",
		"kind":"bane","weight":5,"min_floor":2,
		"effect":{"xp_gain":-0.20,"gold":-0.15}},
]

## 每个数值键的中文名（HUD / 提示文本用）。
const LABELS := {
	"enemy_damage":"敌人伤害",
	"enemy_hp":"敌人生命",
	"enemy_speed":"敌人移动与出手速度",
	"player_damage":"我方普攻",
	"player_damage_taken":"我方受到伤害",
	"loot_tier":"掉落品质",
	"shop_price":"商店价格",
	"gold":"魔晶获取",
	"xp_gain":"经验获取",
	"elite_chance":"精英出现率",
	"bullet_size":"敌人弹幕视觉尺寸",
	"bullet_speed":"敌人弹幕速度",
}

## 每个数值键的合成上下限（加法合成后 clamp）。全部是「倍率加成」，不是绝对倍率。
const BOUNDS := {
	"enemy_damage":[-0.50, 0.75],
	"enemy_hp":[-0.50, 1.00],
	"enemy_speed":[-0.50, 0.50],
	"player_damage":[-0.50, 1.00],
	"player_damage_taken":[-0.60, 0.60],
	"loot_tier":[-2.0, 4.0],
	"shop_price":[-0.60, 0.60],
	"gold":[-0.50, 1.00],
	"xp_gain":[-0.50, 1.50],
	"elite_chance":[0.00, 0.50],
	# 下限锁 0.0：变数永远不许把敌人弹幕缩小（用户要求：弹幕只能更显眼）。
	"bullet_size":[0.00, 1.00],
	"bullet_speed":[-0.50, 0.50],
}

## 以「档位」（整数）语义输出的键：合成后四舍五入为 int。
const INTEGER_KEYS := ["loot_tier"]

## 极性：+1 = 该键升高对玩家有利，-1 = 有害。用于校验 kind 与 effect 自洽。
const POLARITY := {
	"enemy_damage":-1, "enemy_hp":-1, "enemy_speed":-1,
	"player_damage":1, "player_damage_taken":-1, "loot_tier":1,
	"shop_price":-1, "gold":1, "xp_gain":1, "elite_chance":-1,
	"bullet_size":1, "bullet_speed":-1,
}

## 命中判定几何相关键：任何变数效果都不得出现（精确匹配，不是子串匹配）。
## 这条是用户硬要求「命中判定不变」在数据层的守卫。
const FORBIDDEN_KEYS := [
	"hit_radius", "hit_box", "hitbox", "hit_scale", "radius", "collision",
	"collision_radius", "collision_shape", "zone", "geometry", "bolt",
	"projectile_damage", "damage", "hp", "speed",
]

## modifiers_of 的记忆化缓存（键 = ids 拼接串）。数据是静态的，所以结果可复用。
static var _mod_cache: Dictionary = {}


## 变数定义表（契约 §5）。返回深拷贝，调用方改不动内部数据。
static func table() -> Array:
	return TABLE.duplicate(true)


## 全部变数 id（固定顺序 = 表顺序）。
static func ids() -> Array:
	var out: Array = []
	for entry in TABLE:
		out.append(str(entry.id))
	return out


## 数值键清单（= LABELS 的键，顺序固定）。
static func canonical_keys() -> Array:
	return LABELS.keys()


## 合成上下限（副本）。
static func bounds() -> Dictionary:
	return BOUNDS.duplicate(true)


## 整数语义的键（副本）。
static func integer_keys() -> Array:
	return INTEGER_KEYS.duplicate()


## 极性表（副本）。
static func polarity_map() -> Dictionary:
	return POLARITY.duplicate(true)


## 命中判定几何禁用键清单（副本）。
static func forbidden_keys() -> Array:
	return FORBIDDEN_KEYS.duplicate()


## 单条变数的原始定义；未知 id → {}。
static func _raw(id: String) -> Dictionary:
	for entry in TABLE:
		if str(entry.id) == id:
			return entry
	return {}


## 该变数 id 的极性总分（正 = 对玩家有利）。
static func polarity_score(id: String) -> float:
	var entry := _raw(id)
	if entry.is_empty():
		return 0.0
	var score := 0.0
	for key in (entry.effect as Dictionary).keys():
		score += float(POLARITY.get(key,0)) * float(entry.effect[key])
	return score


## 把一条变数的效果渲染成中文短句，例如「敌人伤害 +15% / 掉落品质 +1」。
static func effect_text(id: String) -> String:
	var entry := _raw(id)
	if entry.is_empty():
		return ""
	var parts := PackedStringArray()
	for key in (entry.effect as Dictionary).keys():
		var value := float(entry.effect[key])
		var label := str(LABELS.get(key,key))
		if INTEGER_KEYS.has(key):
			parts.append("%s %+d" % [label,int(round(value))])
		else:
			parts.append("%s %+d%%" % [label,int(round(value*100.0))])
	return " / ".join(parts)


## HUD 用描述：定义深拷贝 + `label`（中文短句）+ `polarity`。未知 id → {}。
static func describe(id: String) -> Dictionary:
	var entry := _raw(id)
	if entry.is_empty():
		return {}
	var out: Dictionary = entry.duplicate(true)
	out["label"] = "%s：%s" % [str(entry.name),effect_text(id)]
	out["polarity"] = polarity_score(id)
	return out


## 可选变数的权重总和（测试与调试用）。floor 过滤 min_floor，exclude 去重。
static func weight_total(floor: int, exclude: Array = []) -> float:
	var total := 0.0
	for entry in TABLE:
		if int(entry.min_floor) > floor:
			continue
		if exclude.has(str(entry.id)):
			continue
		total += float(entry.weight)
	return total


## 派生子种子：纯整数混合（FNV-1a 32 位），不依赖 `String.hash()` 的实现细节。
## 输入固定为 (seed_value, floor, exclude 的**规范排序**串)，所以：
##   * 同 (seed_value, floor, exclude 集合) 必得同值；
##   * exclude 的排列顺序不影响结果（variants_seen 追加顺序变了也不漂移）；
##   * **不读、不写、不消耗 `s.rng`**。
static func _derive_seed(seed_value: int, floor: int, exclude: Array) -> int:
	var parts := PackedStringArray()
	for raw in exclude:
		parts.append(str(raw))
	parts.sort()
	var text := "%d|%d|%s" % [int(seed_value),int(floor),"|".join(parts)]
	var h := 2166136261
	for i in text.length():
		h = (h ^ text.unicode_at(i)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	if h == 0:
		h = 0x9E3779B9
	return h


## 抽取一条变数 id。**不消耗 `s.rng`、也不用任何全局随机函数**：局部 rng 的种子由
## `_derive_seed(seed_value, floor, exclude)` 纯函数派生，因此每局每层的结果只由
## (seed_value, floor, exclude) 决定，与 `s.rng` 的当前位置完全无关（CHANGE-LOG v2-11）。
## floor：当前层；exclude：需要排除的 id（例如本局已出现过的）。
## 无候选时返回 ""；权重与 min_floor 门控规则与 v1 一致。
static func pick(seed_value: int, floor: int, exclude: Array = []) -> String:
	var local := RandomNumberGenerator.new()
	local.seed = _derive_seed(seed_value,floor,exclude)
	var roll_value := local.randf()
	var total := 0.0
	var eligible: Array = []
	for entry in TABLE:
		if int(entry.min_floor) > floor:
			continue
		if exclude.has(str(entry.id)):
			continue
		eligible.append(entry)
		total += float(entry.weight)
	if eligible.is_empty() or total <= 0.0:
		return ""
	var target := roll_value * total
	for entry in eligible:
		target -= float(entry.weight)
		if target < 0.0:
			return str(entry.id)
	return str(eligible[eligible.size()-1].id)


## 会话种子（`s.seed_value`）。缺失/非法一律当 0，绝不因此崩溃。
static func _seed_value_of(s) -> int:
	var value = s.get("seed_value")
	if value == null:
		return 0
	return int(value)


## 抽取并落盘当前层变数。**完全不消耗 `s.rng`**（契约 CHANGE-LOG v2-11）：
## 结果由 `(s.seed_value, raid.floor, variants_seen)` 纯函数决定，所以房主抽一次即可，
## 客户端只读同步过来的 `raid.variant`（契约 §6.2 第 5 条）。
## 副作用只写 `raid.variant` / `raid.variant_serial`。返回被抽中的定义（无 → {}）。
## 若 `raid` 里已存在可选的 `variants_seen`（Array[String]，W1 维护），
## 会据此排除本局已出现过的变数——本函数只读不写该字段。
static func roll(s) -> Dictionary:
	if s == null:
		return {}
	var raid = s.get("raid")
	if not (raid is Dictionary):
		return {}
	var floor := int(raid.get("floor",1))
	var seen: Array = raid.get("variants_seen",[])
	var id := pick(_seed_value_of(s),floor,seen)
	raid["variant"] = id
	raid["variant_serial"] = int(raid.get("variant_serial",0)) + 1
	return describe(id)


## 只读：当前层生效的变数定义，无则 {}。
static func active(s) -> Dictionary:
	if s == null:
		return {}
	var raid = s.raid
	if not (raid is Dictionary):
		return {}
	return describe(str(raid.get("variant","")))


## 多条变数合成一张数值表：先逐键**加法合成**，再逐键 clamp 到 bounds()；
## INTEGER_KEYS 里的键四舍五入为 int，其余保持 float。
## 入参可以是 Array[String]、单个 String；重复 id 会叠加。
## 未知 id 忽略。返回值总是含全部 canonical_keys()（缺省 0.0）+ `sources`。
## **绝不**含任何命中判定几何键（FORBIDDEN_KEYS）。
static func modifiers_of(ids) -> Dictionary:
	var list: Array = []
	if ids is String:
		list = [ids]
	elif ids is Array:
		list = ids
	var cache_key := ""
	for raw in list:
		cache_key += str(raw) + "|"
	if _mod_cache.has(cache_key):
		return (_mod_cache[cache_key] as Dictionary).duplicate(true)
	var result: Dictionary = {}
	for key in LABELS.keys():
		result[key] = 0.0
	var sources: Array = []
	for raw in list:
		var id := str(raw)
		var def := _raw(id)
		if def.is_empty():
			continue
		sources.append(id)
		for key in (def.effect as Dictionary).keys():
			if not result.has(key):
				continue
			result[key] = float(result[key]) + float(def.effect[key])
	for key in LABELS.keys():
		var value := clampf(float(result[key]),float(BOUNDS[key][0]),float(BOUNDS[key][1]))
		result[key] = int(round(value)) if INTEGER_KEYS.has(key) else value
	result["sources"] = sources
	_mod_cache[cache_key] = result
	return result.duplicate(true)
