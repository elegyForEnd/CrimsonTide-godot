extends RefCounted
## R7 (contract CHANGE-LOG v2/v3): the view-model behind `main.gd`'s roguelike UI.
##
## Everything that can be decided without a window lives here — the frozen
## UI -> simulation action names, the HUD strings, the event-room view, the
## growth-tree rows and the seed/每日挑战 helpers. `main.gd` only draws the
## widgets, so the whole surface is assertable from a headless `--script` test.
##
## Action names are frozen by the top-level调度 and MUST NOT be renamed:
##   rogue_event / rogue_growth / rogue_seed / rogue_daily
## `roguelike.choose()` (roguelike.gd:666) routes everything through
## `session.action()` and already carries the `revision` replay guard at
## roguelike.gd:681, so every payload below ships `revision`.
##
## NOTE: no `class_name` on purpose — the .godot class cache is stale for the
## newer Rogue* modules and a bare class name fails at parse time in headless
## runs. Always `preload` this file.

const RogueVariants = preload("res://scripts/rogue_variants.gd")
const RogueCurses = preload("res://scripts/rogue_curses.gd")
const RogueEvents = preload("res://scripts/rogue_events.gd")
const RogueDaily = preload("res://scripts/rogue_daily.gd")
const RogueGrowth = preload("res://scripts/rogue_growth.gd")

# ---------------------------------------------------------------- frozen action names

const ACTION_EVENT := "rogue_event"
const ACTION_GROWTH := "rogue_growth"
const ACTION_SEED := "rogue_seed"
const ACTION_DAILY := "rogue_daily"

# `RogueDaily` reserves seed 0 for "random run" (session.gd:1386), so the UI must
# never hand 0 to `launch()`: a bad seed has to be refused, not silently randomised.
const SEED_MIN := 1

# ---------------------------------------------------------------- HUD lines

## 「深渊变数」一行。未抽到时给一句明确的占位，而不是空字符串。
static func variant_line(raid: Dictionary) -> String:
	var id := str(raid.get("variant", ""))
	if id == "":
		return "深渊变数 · 未显现"
	var info := describe_variant(id)
	if info.is_empty():
		return "深渊变数 · 未知（%s）" % id
	return "深渊变数 · " + str(info.get("label", id))


## 只读包装，方便测试替换。
static func describe_variant(id: String) -> Dictionary:
	return RogueVariants.describe(id)


static func variant_polarity(raid: Dictionary) -> float:
	var id := str(raid.get("variant", ""))
	if id == "":
		return 0.0
	var info := describe_variant(id)
	return float(info.get("polarity", 0.0))


## 诅咒摘要（多行）。无诅咒时给一行明确的「无」。
static func curses_text(p: Dictionary) -> String:
	return "\n".join(curses_lines(p))


static func curses_lines(p: Dictionary) -> PackedStringArray:
	var rows := RogueCurses.summary(p)
	var out := PackedStringArray()
	if rows.is_empty():
		out.append("诅咒 · 无")
		return out
	var scale := RogueCurses.damage_taken_scale(p)
	out.append("诅咒 %d / %d · 受创 ×%.2f" % [rows.size(), int(RogueCurses.MAX_CURSES), scale])
	for row in rows:
		out.append("· %s · %s" % [str(row.name), str(row.desc)])
	return out


## 灰烬：本局产出与局外累计必须分开显示，否则玩家分不清哪个能花。
static func ash_line(p: Dictionary, profile_data: Dictionary) -> String:
	var run_ash := int(p.get("rogue_ash_run", 0)) if p is Dictionary else 0
	var bank := 0
	if profile_data is Dictionary:
		bank = int(profile_data.get("ashes", 0))
	return "灰烬 · 本局 %d · 累计 %d" % [run_ash, bank]


## 节点图进度：层 / 深度 / 当前房间中文名。
static func node_line(raid: Dictionary, room_names: Dictionary) -> String:
	var floor_value := int(raid.get("floor", 1))
	var depth := int(raid.get("depth", 1))
	var kind := str(raid.get("room", ""))
	var room := str(room_names.get(kind, kind))
	if room == "":
		room = "未知区域"
	return "路线 · 第 %d 层 · 深度 %d · %s" % [floor_value, depth, room]


## 顶栏的层/区进度。分母必须由节点图给出（每层 7~9 个房间），不能再写死
## `AREAS_PER_FLOOR`，否则第 8 个房间会显示成「第 8 / 7 区」。
static func floor_line(raid: Dictionary, room_total: int) -> String:
	return "第 %d / 5 层 · 第 %d / %d 区" % [int(raid.get("floor", 1)), int(raid.get("area", 1)), maxi(1, room_total)]


## 本局种子（分享串由房主随 begin 下发，写在 raid.seed_shared）。
static func seed_line(raid: Dictionary) -> String:
	var text := str(raid.get("seed_shared", ""))
	var daily := bool(raid.get("daily", false))
	if text == "":
		return "每日挑战 · 进行中" if daily else ""
	return ("每日挑战 · " if daily else "分享种子 · ") + text


# ---------------------------------------------------------------- 事件房

static func pending_event(raid: Dictionary) -> Dictionary:
	if not raid.has("pending_event") or not (raid["pending_event"] is Dictionary):
		return {}
	return raid["pending_event"] as Dictionary


static func event_active(raid: Dictionary) -> bool:
	return not pending_event(raid).is_empty()


static func event_id(raid: Dictionary) -> String:
	return str(pending_event(raid).get("id", ""))


static func event_def(raid: Dictionary) -> Dictionary:
	var id := event_id(raid)
	if id == "":
		return {}
	return RogueEvents.find(id)


static func event_title(raid: Dictionary) -> String:
	var def := event_def(raid)
	var name := str(def.get("name", ""))
	if name == "":
		return "幽暗异事"
	return name


## 事件本体的说明；表里没有 desc 字段时给一句通用说明（不返回空串）。
static func event_body(raid: Dictionary) -> String:
	var def := event_def(raid)
	var described := str(def.get("desc", ""))
	if described != "":
		return described
	return "此处的抉择不可撤销：选中后立刻结算。"


## 选项视图：在 `RogueEvents.options_view()` 之上补 `enabled`（供按钮 disable）。
static func event_options(s, p: Dictionary, raid: Dictionary) -> Array:
	var id := event_id(raid)
	var out: Array = []
	var rows: Array = []
	if id != "":
		rows = RogueEvents.options_view(RogueEvents.find(id))
		if rows.is_empty():
			rows = pending_event(raid).get("offer", [])
	else:
		rows = pending_event(raid).get("offer", [])
	for row in rows:
		var view: Dictionary = (row as Dictionary).duplicate(true)
		var index := int(view.get("index", -1))
		view["enabled"] = id != "" and RogueEvents.available(s, p, id, index)
		out.append(view)
	return out


## 选项门槛的可读文本（无门槛 → ""）。
static func require_text(view: Dictionary) -> String:
	var require: Dictionary = view.get("require", {}) if view.get("require", {}) is Dictionary else {}
	if require.is_empty():
		return ""
	var parts := PackedStringArray()
	if int(require.get("gold", 0)) > 0:
		parts.append("需 %d 魔晶" % int(require.gold))
	if float(require.get("hp_ratio", 0.0)) > 0.0:
		parts.append("需生命 ≥ %d%%" % int(round(float(require.hp_ratio) * 100.0)))
	if float(require.get("flask", 0.0)) > 0.0:
		parts.append("需血瓶 ≥ %d" % int(require.flask))
	if int(require.get("curse_slots", 0)) > 0:
		parts.append("需诅咒位空余")
	return " / ".join(parts)


static func event_payload(raid: Dictionary, index: int) -> Dictionary:
	return {"index": int(index), "revision": int(raid.get("revision", 0))}


# ---------------------------------------------------------------- 成长树

## 每个节点一行：等级、上限、下一级花费、能否购买与原因。
static func growth_rows(profile_data: Dictionary) -> Array:
	var tree := RogueGrowth.tree()
	var out: Array = []
	for id in RogueGrowth.ids():
		var row: Dictionary = tree.get(id, {})
		var level := RogueGrowth.level_of(profile_data, id)
		var reason := RogueGrowth.can_buy_reason(profile_data, id)
		out.append({
			"id": id,
			"name": RogueGrowth.label(id),
			"desc": RogueGrowth.describe(id),
			"level": level,
			"max": int(row.get("max", 0)),
			"cost": RogueGrowth.cost_for(id, level),
			"spent": RogueGrowth.spent_on(profile_data, id),
			"reason": reason,
			"can_buy": reason == "",
			"requires": (row.get("requires", []) as Array).duplicate(),
		})
	return out


static func growth_reason_text(reason: String) -> String:
	match reason:
		"": return "可购买"
		"maxed": return "已满级"
		"requires": return "需要前置节点"
		"ashes": return "灰烬不足"
		"unknown": return "未知节点"
	return reason


## 按钮文字：买得起给价格，买不起给原因（不允许出现「静默不可点」）。
static func growth_button_text(row: Dictionary) -> String:
	if bool(row.get("can_buy", false)):
		return "%d 灰烬" % int(row.get("cost", 0))
	return growth_reason_text(str(row.get("reason", "")))


static func growth_summary(profile_data: Dictionary) -> String:
	return "灰烬 %d · 已投入 %d / 满树 %d" % [
		int(profile_data.get("ashes", 0)) if profile_data is Dictionary else 0,
		RogueGrowth.total_spent(profile_data),
		RogueGrowth.total_cost(),
	]


## 购买成长树节点。灰烬与成长树是**本地档案**数据，所以 UI 先本地生效并落盘，
## 再把这个动作作为审计事件发出；`applied: true` 是给房主的硬约束——收到它时
## **不得再次扣费**，否则玩家会被重复收费。
static func growth_payload(raid: Dictionary, id: String) -> Dictionary:
	return {"id": id, "applied": true, "revision": int(raid.get("revision", 0))}


# ---------------------------------------------------------------- 种子 / 每日挑战

## 每日挑战必须由房主按 **UTC** 日期算好（contract v3-2），客户端不得各自计算。
static func daily_seed() -> int:
	return RogueDaily.global_daily_seed()


static func daily_date() -> String:
	return RogueDaily.utc_today()


static func daily_share() -> String:
	return RogueDaily.encode(daily_seed())


static func share_of(seed: int) -> String:
	return RogueDaily.encode(seed)


static func parse_seed(text: String) -> int:
	return RogueDaily.parse_seed(text)


## `""` = 可以出发；否则是不能出发的原因（必须提示，不许静默变随机局）。
static func seed_error(text: String) -> String:
	if text.strip_edges() == "":
		return "请输入种子或分享串（留空不会变成随机局，需先清空选择）"
	var value := RogueDaily.parse_seed(text)
	if value < SEED_MIN:
		return "种子不合法：需要 CT-XXXXXXXX-X 分享串，或 %d ~ 2147483647 的十进制种子" % SEED_MIN
	return ""


## 种子页/出发按钮上的状态文字。
static func pending_seed_text(seed: int, daily: bool) -> String:
	if daily:
		return "每日挑战（UTC %s）· %s" % [daily_date(), daily_share()]
	if seed > 0:
		return "自定义种子 · " + share_of(seed)
	return "未指定 · 每次出发随机"


static func seed_button_text(seed: int, daily: bool) -> String:
	if daily:
		return "每日挑战 · 已选"
	if seed > 0:
		return share_of(seed)
	return "种子 · 每日挑战"


static func seed_hint() -> String:
	return "同一条种子串必定生成同一座魔境。分享串一旦发布不可更改；指定种子需要由房主（本地主机）发起，联机队友输入无效。"


## 分享给队友的文本。
static func copy_text(seed: int, daily: bool) -> String:
	if daily:
		return daily_share()
	if seed > 0:
		return share_of(seed)
	return ""


# ---------------------------------------------------------------- 房间显示

static func room_name(raid: Dictionary, room_names: Dictionary) -> String:
	var kind := str(raid.get("room", ""))
	return str(room_names.get(kind, kind))
