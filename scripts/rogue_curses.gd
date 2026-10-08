class_name RogueCurses
extends RefCounted
## R9 · 魔境诅咒数据层（纯数据 + 纯函数）。静态签名见 output/ROGUE-CONTRACTS.md §5。
##
## 三条必须遵守的设计纪律（改这个文件前先读）：
##
## 1. 诅咒是"个人"状态：id 列表存在 p["rogue_curses"]（String 数组），随 players 整表快照同步。
##    契约 §2 的 raid["curse_serial"] 只做"施加序号"，用于一次性提示与去重。
##
## 2. 诅咒**不开新乘数**：它的减益被折算成"既有减伤池里的一项负贡献"。魔境分支的伤害应写成
##        (1 - clampf(RogueBuild.conditional_defense(s,p) - stat_delta(p).damage_taken, -0.60, RogueCurses.MAX_POOL))
##    这样诅咒 / 天赋 / 装备共用同一个池与同一个上限，不会出现乘算爆炸。
##    defense_penalty() 与 damage_taken_scale() 是同一份信息的两种表达（见各自的注释）。
##
## 3. 诅咒必须"成对"：每条都带 boon（对称回报），由 apply_pair() 一并发放；
##    表中不允许出现"只给惩罚"或"只给好处"的行。
##
## 随机性：除 roll() 外全部无副作用、无 RNG；roll() 只消耗 1 次 s.rng.randi_range，
## 是诅咒房唯一的随机点（契约 §6.2）。

## 单个玩家身上的诅咒上限。到顶后 apply() 返回 false（房内应改发"赎罪/清除"选项）。
const MAX_CURSES := 4
## 减伤池合成上限：诅咒与天赋/装备共享同一个池，因此共享同一个上限。
const MAX_POOL := 0.75
## 叠加上限（"上下限生效"的验收对象，见 aggregate()）。
const CAPS := {
	"damage_taken": 0.60,
	"move_speed": -60.0,
	"gold_income": -0.60,
	"shop_price": 0.80,
	"chest_drop": -0.70,
	"heal_scale": -0.60,
	"flask_max": -50.0,
	"vision": -0.60,
	"cooldown": 0.60,
}
## effect 允许键（冻结）。正数＝对玩家更糟（更痛/更贵/更慢），负数＝资源/手感变差。
const EFFECT_KEYS := ["damage_taken", "move_speed", "gold_income", "shop_price", "chest_drop", "heal_scale", "flask_max", "vision", "cooldown"]
## 每层诅咒使"诅咒房补偿"提升的比例，以及补偿上限。
const REWARD_SCALE_PER_CURSE := 0.15
const REWARD_SCALE_CAP := 1.50

const TABLE := [
	{"id": "CU01", "name": "血蚀", "desc": "受到的伤害 +15%", "effect": {"damage_taken": 0.15}, "boon": {"gold": 90, "desc": "魔晶 +90"}},
	{"id": "CU02", "name": "铁枷", "desc": "移动速度 -18", "effect": {"move_speed": -18.0}, "boon": {"gear_reward": 1, "desc": "立即获得一次装备三选一"}},
	{"id": "CU03", "name": "贪婪之握", "desc": "魔晶收入 -30%", "effect": {"gold_income": -0.30}, "boon": {"attribute_points": 1, "desc": "局内属性 +1"}},
	{"id": "CU04", "name": "奸商印记", "desc": "商店价格 +35%", "effect": {"shop_price": 0.35}, "boon": {"gold": 120, "desc": "魔晶 +120"}},
	{"id": "CU05", "name": "空箱咒", "desc": "宝箱掉落率 -40%", "effect": {"chest_drop": -0.40}, "boon": {"gear_reward": 1, "desc": "立即获得一次装备三选一"}},
	{"id": "CU06", "name": "干涸", "desc": "治疗效果 -30%", "effect": {"heal_scale": -0.30}, "boon": {"gold": 110, "desc": "魔晶 +110"}},
	{"id": "CU07", "name": "破瓶", "desc": "血瓶容量 -25", "effect": {"flask_max": -25.0}, "boon": {"attribute_points": 1, "desc": "局内属性 +1"}},
	{"id": "CU08", "name": "迷雾", "desc": "视野 -35%", "effect": {"vision": -0.35}, "boon": {"gear_reward": 1, "desc": "立即获得一次装备三选一"}},
	{"id": "CU09", "name": "迟滞", "desc": "技能冷却 +25%", "effect": {"cooldown": 0.25}, "boon": {"gold": 130, "desc": "魔晶 +130"}},
	{"id": "CU10", "name": "碎盾", "desc": "受到的伤害 +10%，治疗效果 -15%", "effect": {"damage_taken": 0.10, "heal_scale": -0.15}, "boon": {"gold": 150, "desc": "魔晶 +150"}},
]

# ----------------------------------------------------------------------------
# 只读查询
# ----------------------------------------------------------------------------

static func table() -> Array:
	# 深拷贝：调用方（UI/房逻辑）改动不能污染常量表。
	return TABLE.duplicate(true)

static func ids() -> Array:
	var result: Array=[]
	for row in TABLE: result.append(str(row.id))
	return result

static func caps() -> Dictionary:
	return CAPS.duplicate(true)

static func find(curse: String) -> Dictionary:
	for row in TABLE:
		if str(row.id)==curse: return row.duplicate(true)
	return {}

static func has(p: Dictionary, curse: String) -> bool:
	return curse in p.get("rogue_curses", [])

static func count(p: Dictionary) -> int:
	var total := 0
	for raw in p.get("rogue_curses", []):
		if find(str(raw)).is_empty(): continue
		total+=1
	return total

## A3（B3-2）· 只读查询：身上"最近获得的一条真诅咒"的 id（列表尾部，未知 id 跳过）。
## 与 remove_last() 的目标逐字一致，所以锻炉的赎罪行可以据此报价"这一条会被清除"。
## 无诅咒 → ""。无副作用、无 RNG。
static func last_id(p: Dictionary) -> String:
	var raw = p.get("rogue_curses", null)
	if not (raw is Array): return ""
	var list: Array = raw
	for i in range(list.size()-1, -1, -1):
		var id := str(list[i])
		if find(id).is_empty(): continue
		return id
	return ""

## 纯函数：把任意 id 列表（含重复、含未知 id）合成一张受上限约束的修正表。
## 契约要求"诅咒叠加后数值不越界"，因此每个键都必须过 CAPS。
static func aggregate(id_list: Array) -> Dictionary:
	var totals: Dictionary={}
	for key in EFFECT_KEYS: totals[key]=0.0
	for raw in id_list:
		var row := find(str(raw))
		if row.is_empty(): continue
		for key in row.get("effect", {}):
			if key not in EFFECT_KEYS: continue
			totals[key]=float(totals[key])+float(row.effect[key])
	var result: Dictionary={}
	for key in EFFECT_KEYS:
		var cap := float(CAPS[key])
		var value := float(totals[key])
		result[key]=clampf(value, 0.0, cap) if cap>0.0 else clampf(value, cap, 0.0)
	return result

static func stat_delta(p: Dictionary) -> Dictionary:
	return aggregate(p.get("rogue_curses", []))

# ----------------------------------------------------------------------------
# 接进既有减伤池的两个出口（同一份信息，两种表达）
# ----------------------------------------------------------------------------

## 伤害承受系数（>=1.0）：供 telemetry / 测试 / 日志阅读。
static func damage_taken_scale(p: Dictionary) -> float:
	return 1.0 + float(stat_delta(p).damage_taken)

## 减伤罚项的倒数形式（0.0 .. MAX_POOL），用于查询与遥测。
## 语义 = "从既有减伤池里减掉这么多"，而不是再乘一层 1.15。
## 与 damage_taken_scale 严格等价：penalty = 1 - 1/scale。
## session.incoming_damage 将 penalty/(1-penalty) 还原为加性贡献，允许负减伤。
static func defense_penalty(p: Dictionary) -> float:
	return clampf(1.0 - 1.0/damage_taken_scale(p), 0.0, MAX_POOL)

## 单个玩家的补偿倍率（诅咒越多，诅咒房里拿得越多）。
static func personal_reward_scale(p: Dictionary) -> float:
	return clampf(1.0 + REWARD_SCALE_PER_CURSE*float(count(p)), 1.0, REWARD_SCALE_CAP)

## 全队补偿倍率：取全队最重的诅咒负担（不按人数放大，避免"故意叠咒刷钱"）。
static func reward_scale(s) -> float:
	var worst := 0
	for p in s.players.values():
		worst=maxi(worst, count(p))
	return clampf(1.0 + REWARD_SCALE_PER_CURSE*float(worst), 1.0, REWARD_SCALE_CAP)

# ----------------------------------------------------------------------------
# 写入
# ----------------------------------------------------------------------------

## 契约签名：追加一条诅咒并推进 raid.curse_serial。重复 / 未知 / 超上限一律拒绝且不变更状态。
static func apply(s, p: Dictionary, curse: String) -> bool:
	if find(curse).is_empty(): return false
	if not p.has("rogue_curses"): p["rogue_curses"]=[]
	var list: Array=p["rogue_curses"]
	if curse in list: return false
	if list.size()>=MAX_CURSES: return false
	list.append(curse)
	if s!=null:
		s.raid["curse_serial"]=int(s.raid.get("curse_serial", 0))+1
	return true

## A3（B3-2）· 解咒：把一条诅咒从 p 身上摘掉（p["rogue_curses"] 是本人的状态，随快照整表替换）。
## **绝不触碰 raid["curse_serial"]**：那个键是"已施加次数"的追加计数器，只增不减——移除一条
## 再重新获得同一条时序号更大，一次性提示/去重因此仍然成立（移除 ≠ 重置序号）。
## 未知 id / 不在身上 → false 且零变化（调用方据此不收费）。
static func remove(p: Dictionary, curse: String) -> bool:
	if find(curse).is_empty(): return false
	var raw = p.get("rogue_curses", null)
	if not (raw is Array): return false
	var list: Array = raw
	for i in list.size():
		if str(list[i]) != curse: continue
		list.remove_at(i)
		return true
	return false

## A3（B3-2）· 摘掉"最后追加的那一条真诅咒"（列表尾部＝最近获得，见 apply() 的 append 语义）。
## 未知 id 一律跳过、不删（否则"付费解咒"会拿垃圾 id 冒充成果）；返回被移除的 id，没有则 ""。
## 同样不动 curse_serial。
static func remove_last(p: Dictionary) -> String:
	var raw = p.get("rogue_curses", null)
	if not (raw is Array): return ""
	var list: Array = raw
	for i in range(list.size()-1, -1, -1):
		var id := str(list[i])
		if find(id).is_empty(): continue
		list.remove_at(i)
		return id
	return ""

## 诅咒房的实际入口：施加诅咒 + 立刻发放对称回报，返回 {applied, curse, boon}。
static func apply_pair(s, p: Dictionary, curse: String) -> Dictionary:
	var applied := apply(s, p, curse)
	var paid: Dictionary={}
	if applied: paid=grant_boon(s, p, curse)
	return {"applied": applied, "curse": curse, "boon": paid}

## 发放对称回报。正数=实际到账。gear_reward 通过既有 reward_queue 走三选一，
## 不新造装备通道（也就不会撑爆 rogue_stash<=12）。
static func grant_boon(s, p: Dictionary, curse: String) -> Dictionary:
	var row := find(curse)
	if row.is_empty(): return {}
	var boon: Dictionary=row.get("boon", {})
	var paid := {"gold": 0, "attribute_points": 0, "gear_reward": 0}
	if int(boon.get("gold", 0))>0:
		var gold := int(boon.gold)
		p["rogue_gold"]=int(p.get("rogue_gold", 0))+gold
		paid["gold"]=gold
	if int(boon.get("attribute_points", 0))>0:
		var points := int(boon.attribute_points)
		p["build_attribute_points"]=int(p.get("build_attribute_points", 0))+points
		paid["attribute_points"]=points
	if int(boon.get("gear_reward", 0))>0:
		if not p.has("build_reward_queue"): p["build_reward_queue"]=[]
		var queue: Array=p["build_reward_queue"]
		for i in int(boon.gear_reward): queue.append("gear")
		paid["gear_reward"]=int(boon.gear_reward)
		if s!=null and s.get("roguelike")!=null: s.roguelike.next_personal(s, p)
	return paid

## 诅咒房唯一的随机点：抽一条不在 exclude 里的诅咒（exclude 传该玩家已有的 id）。
## 始终消耗恰好 1 次 s.rng.randi_range，保证同种子同结果、且消耗次数固定。
static func roll(s, exclude: Array = []) -> String:
	var pool: Array=[]
	for row in TABLE:
		if str(row.id) in exclude: continue
		pool.append(str(row.id))
	if pool.is_empty(): pool=ids()
	var index := int(s.rng.randi_range(0, pool.size()-1))
	return str(pool[index])

## HUD/测试用：把 p 身上的诅咒摊成可读列表（JSON 可序列化）。
static func summary(p: Dictionary) -> Array:
	var result: Array=[]
	for raw in p.get("rogue_curses", []):
		var row := find(str(raw))
		if row.is_empty(): continue
		result.append({"id": str(row.id), "name": str(row.name), "desc": str(row.desc)})
	return result
