class_name RogueEvents
extends RefCounted
## R9 · 魔境事件房数据层（纯数据 + 纯函数）。静态签名见 output/ROGUE-CONTRACTS.md §5。
##
## 设计纪律：
## 1. 事件结果是**纯数据**：resolve() 不读 s、不用 RNG，同样的 (event_id, index) 永远得到同样的增量。
##    因此事件房不会打乱 s.rng 序列（契约 §6.2 只允许"唯一确定的随机点"，这里是 zero）。
## 2. roll_offer() 是事件房唯一的 s.rng 消耗点（恰好 1 次），并把三选一写进 raid.pending_event，
##    格式遵守契约 §2：{"offer":Array,"revision":int}（另有 id 用于结算，属追加字段）。
## 3. apply() 只允许改动"已有系统能承接"的状态：魔晶 / 生命 / 蓝量 / 血瓶 / 属性点 / 锻造点 /
##    诅咒 / 装备三选一队列。它**不碰**命中判定几何、不碰弹数、不新增乘数。
## 4. 选项消耗（花魔晶、掉血）必须先过 available()，否则 apply() 拒绝并保留 pending_event，
##    让玩家改选；任何路径下 hp 都不低于 1、魔晶都不低于 0。

const Curses = preload("res://scripts/rogue_curses.gd")

## result 允许键（冻结）。任何表内出现别的键都会被 resolve() 整体拒绝，避免脏状态。
const DELTA_KEYS := ["gold", "hp_ratio", "mana_ratio", "flask", "attribute_points", "forge_points", "curse", "gear_reward"]

const TABLE := [
	{"id": "EV01", "name": "血祭石阶", "floor_min": 1, "options": [
		{"name": "献祭心血", "desc": "失去 30% 生命，换取 2 点局内属性", "result": {"hp_ratio": -0.30, "attribute_points": 2}, "require": {"hp_ratio": 0.35}},
		{"name": "取走贡品", "desc": "魔晶 +40", "result": {"gold": 40}},
		{"name": "触碰碑文", "desc": "获得 1 条诅咒，并立刻得到一次装备三选一", "result": {"curse": "CU01", "gear_reward": 1}, "require": {"curse_slots": 1}},
	]},
	{"id": "EV02", "name": "锈蚀商栈", "floor_min": 1, "options": [
		{"name": "买下整箱", "desc": "花 120 魔晶，立刻得到一次装备三选一", "result": {"gold": -120, "gear_reward": 1}, "require": {"gold": 120}},
		{"name": "买下药膏", "desc": "花 60 魔晶，回复 40% 生命", "result": {"gold": -60, "hp_ratio": 0.40}, "require": {"gold": 60}},
		{"name": "只捡零钱", "desc": "魔晶 +15", "result": {"gold": 15}},
	]},
	{"id": "EV03", "name": "迷途魂灯", "floor_min": 1, "options": [
		{"name": "饮下灯油", "desc": "回复 35% 生命", "result": {"hp_ratio": 0.35}},
		{"name": "献出灯火", "desc": "失去 15% 生命，换取 1 点局内属性", "result": {"hp_ratio": -0.15, "attribute_points": 1}, "require": {"hp_ratio": 0.20}},
		{"name": "把灯带走", "desc": "获得 1 条诅咒，魔晶 +110", "result": {"curse": "CU06", "gold": 110}, "require": {"curse_slots": 1}},
	]},
	{"id": "EV04", "name": "拾遗老树", "floor_min": 2, "options": [
		{"name": "摘下果实", "desc": "回复 50% 生命", "result": {"hp_ratio": 0.50}},
		{"name": "摇落枝干", "desc": "魔晶 +70，血瓶 -20", "result": {"gold": 70, "flask": -20.0}},
		{"name": "掘出树心", "desc": "获得 1 条诅咒，并立刻得到一次装备三选一", "result": {"curse": "CU07", "gear_reward": 1}, "require": {"curse_slots": 1}},
	]},
	{"id": "EV05", "name": "深渊回声", "floor_min": 2, "options": [
		{"name": "侧耳倾听", "desc": "失去 20% 生命，换取 1 点锻造点", "result": {"hp_ratio": -0.20, "forge_points": 1}, "require": {"hp_ratio": 0.25}},
		{"name": "掩耳离开", "desc": "魔晶 +30", "result": {"gold": 30}},
	]},
	{"id": "EV06", "name": "贪婪秤盘", "floor_min": 3, "options": [
		{"name": "压上魔晶", "desc": "花 150 魔晶，换取 2 点局内属性", "result": {"gold": -150, "attribute_points": 2}, "require": {"gold": 150}},
		{"name": "压上护符", "desc": "血瓶 -30，魔晶 +200", "result": {"flask": -30.0, "gold": 200}, "require": {"flask": 30}},
		{"name": "不押", "desc": "魔晶 +20", "result": {"gold": 20}},
	]},
	{"id": "EV07", "name": "蚀骨温泉", "floor_min": 3, "options": [
		{"name": "浸泡", "desc": "回复 60% 生命与 60% 蓝量", "result": {"hp_ratio": 0.60, "mana_ratio": 0.60}},
		{"name": "深潜", "desc": "获得 1 条诅咒，换取 1 点局内属性", "result": {"curse": "CU08", "attribute_points": 1}, "require": {"curse_slots": 1}},
		{"name": "取一瓶水样", "desc": "血瓶 +25", "result": {"flask": 25.0}},
	]},
	{"id": "EV08", "name": "无名祭坛", "floor_min": 4, "options": [
		{"name": "供奉魔晶", "desc": "花 200 魔晶，换取一次装备三选一", "result": {"gold": -200, "gear_reward": 1}, "require": {"gold": 200}},
		{"name": "供奉生命", "desc": "失去 25% 生命，换取 1 点锻造点", "result": {"hp_ratio": -0.25, "forge_points": 1}, "require": {"hp_ratio": 0.30}},
		{"name": "供奉理智", "desc": "获得 1 条诅咒，魔晶 +150", "result": {"curse": "CU10", "gold": 150}, "require": {"curse_slots": 1}},
	]},
	{"id": "EV09", "name": "星屑坠地", "floor_min": 4, "options": [
		{"name": "只拾一颗", "desc": "局内属性 +1", "result": {"attribute_points": 1}},
		{"name": "全部收走", "desc": "获得 1 条诅咒，并立刻得到一次装备三选一", "result": {"curse": "CU03", "gear_reward": 1}, "require": {"curse_slots": 1}},
	]},
]

# ----------------------------------------------------------------------------
# 只读查询
# ----------------------------------------------------------------------------

static func table() -> Array:
	return TABLE.duplicate(true)

static func ids() -> Array:
	var result: Array=[]
	for row in TABLE: result.append(str(row.id))
	return result

static func find(event_id: String) -> Dictionary:
	for row in TABLE:
		if str(row.id)==event_id: return row.duplicate(true)
	return {}

## 当前层可抽到的事件 id（floor_min 门槛）。
static func floor_pool(floor: int) -> Array:
	var result: Array=[]
	for row in TABLE:
		if int(row.floor_min)<=floor: result.append(str(row.id))
	return result

static func pending(s) -> Dictionary:
	return s.raid.get("pending_event", {}).duplicate(true)

## 供 roguelike.choose() 的接线用：payload 里的 revision 必须与待选事件一致，否则丢弃（契约 §9.2）。
static func matches_revision(s, revision: int) -> bool:
	var current := pending(s)
	return not current.is_empty() and int(current.get("revision", -1))==revision

## 客户端可见的选项视图：只给"玩家看得到的东西"，**不含 result**（结果由房主用 resolve() 取）。
static func options_view(event: Dictionary) -> Array:
	var offers: Array=[]
	var options: Array=event.get("options", [])
	for i in options.size():
		var option: Dictionary=options[i]
		var view := {"index": i, "name": str(option.get("name", "")), "desc": str(option.get("desc", ""))}
		if option.has("require"): view["require"]=(option.require as Dictionary).duplicate(true)
		offers.append(view)
	return offers

# ----------------------------------------------------------------------------
# 抽选（唯一 RNG 点）
# ----------------------------------------------------------------------------

## 抽一个事件房三选一，写进 raid.pending_event，并返回同一个字典。
static func roll_offer(s) -> Dictionary:
	var pool := floor_pool(int(s.raid.floor))
	if pool.is_empty(): pool=ids()
	var event_id := str(pool[int(s.rng.randi_range(0, pool.size()-1))])
	var event := find(event_id)
	var current := {"offer": options_view(event), "revision": int(s.raid.get("revision", 0)), "id": event_id}
	s.raid["pending_event"]=current
	return current

# ----------------------------------------------------------------------------
# 结算（纯函数 + 落地）
# ----------------------------------------------------------------------------

## 纯函数：返回该选项的状态增量；非法 event/index 或表里写了非法键 → {}（整体拒绝）。
static func resolve(event_id: String, index: int) -> Dictionary:
	var event := find(event_id)
	if event.is_empty(): return {}
	var options: Array=event.get("options", [])
	if index<0 or index>=options.size(): return {}
	var result: Dictionary=(options[index].get("result", {}) as Dictionary).duplicate(true)
	if result.is_empty(): return {}
	for key in result.keys():
		if key not in DELTA_KEYS: return {}
	return result

## 选项是否可点：花不起魔晶 / 血量不够 / 血瓶不够 / 诅咒位已满 → false。
static func available(s, p: Dictionary, event_id: String, index: int) -> bool:
	var event := find(event_id)
	if event.is_empty(): return false
	var options: Array=event.get("options", [])
	if index<0 or index>=options.size(): return false
	var require: Dictionary=(options[index].get("require", {}) as Dictionary)
	if int(require.get("gold", 0))>0 and int(p.get("rogue_gold", 0))<int(require.gold): return false
	if float(require.get("hp_ratio", 0.0))>0.0 and float(p.hp)<float(p.max_hp)*float(require.hp_ratio): return false
	if float(require.get("flask", 0.0))>0.0 and float(p.flask)<float(require.flask): return false
	if int(require.get("curse_slots", 0))>0 and Curses.count(p)>=Curses.MAX_CURSES: return false
	return true

## 把增量落到玩家身上，返回**实际到账**的增量（可能因上限而被夹小）。
## 这是本模块唯一会改状态的地方，且只经由已有系统。
static func commit(s, p: Dictionary, delta: Dictionary) -> Dictionary:
	var paid := {"gold": 0, "hp": 0.0, "mana": 0.0, "flask": 0.0, "attribute_points": 0, "forge_points": 0, "curse": 0, "gear_reward": 0}
	if delta.is_empty(): return paid
	if int(delta.get("gold", 0))!=0:
		var before_gold := int(p.get("rogue_gold", 0))
		var after_gold := maxi(0, before_gold+int(delta.gold))
		p["rogue_gold"]=after_gold
		paid["gold"]=after_gold-before_gold
	if float(delta.get("hp_ratio", 0.0))!=0.0:
		var before_hp: float=float(p.hp)
		p.hp=clampf(float(p.hp)+float(p.max_hp)*float(delta.hp_ratio), 1.0, float(p.max_hp))
		paid["hp"]=float(p.hp)-before_hp
	if float(delta.get("mana_ratio", 0.0))!=0.0:
		var before_mana: float=float(p.mana)
		p.mana=clampf(float(p.mana)+float(p.max_mana)*float(delta.mana_ratio), 0.0, float(p.max_mana))
		paid["mana"]=float(p.mana)-before_mana
	if float(delta.get("flask", 0.0))!=0.0:
		var before_flask: float=float(p.flask)
		p.flask=clampf(float(p.flask)+float(delta.flask), 0.0, 100.0)
		paid["flask"]=float(p.flask)-before_flask
	if int(delta.get("attribute_points", 0))!=0:
		var points := int(delta.attribute_points)
		p["build_attribute_points"]=maxi(0, int(p.get("build_attribute_points", 0))+points)
		paid["attribute_points"]=points
	if int(delta.get("forge_points", 0))!=0:
		var forge := int(delta.forge_points)
		p["build_forge_points"]=maxi(0, int(p.get("build_forge_points", 0))+forge)
		paid["forge_points"]=forge
	if str(delta.get("curse", ""))!="" and Curses.apply(s, p, str(delta.curse)):
		paid["curse"]=1
	if int(delta.get("gear_reward", 0))>0:
		if not p.has("build_reward_queue"): p["build_reward_queue"]=[]
		var queue: Array=p["build_reward_queue"]
		for i in int(delta.gear_reward): queue.append("gear")
		paid["gear_reward"]=int(delta.gear_reward)
		if s!=null and s.get("roguelike")!=null: s.roguelike.next_personal(s, p)
	return paid

## 契约签名：结算玩家选择的选项；成功后清空 pending_event 并推进 raid.revision（防过期点击重放）。
static func apply(s, p: Dictionary, index: int) -> bool:
	var current := pending(s)
	if current.is_empty(): return false
	var event_id := str(current.get("id", ""))
	if event_id=="" or not available(s, p, event_id, index): return false
	var delta := resolve(event_id, index)
	if delta.is_empty(): return false
	commit(s, p, delta)
	s.raid["pending_event"]={}
	s.raid["revision"]=int(s.raid.get("revision", 0))+1
	return true
