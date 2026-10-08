extends RefCounted
## R7b: the view-model behind `main.gd`'s UI for the three dedicated rooms that
## `RogueRooms` defines — 游方锻炉 (forge) / 赌徒营帐 (gamble) / 镜中挑战 (mirror).
##
## Why a separate file: everything here can be decided without a window, so a headless
## `--script` test can assert the panel contents (offers, prices, disabled reasons and
## the exact action payloads) without opening a real window.
##
## Action names are frozen by the top-level调度 and MUST NOT be renamed:
##   rogue_forge / rogue_gamble / rogue_mirror
## `roguelike.choose()` (roguelike.gd:779) drops any click whose `revision` does not
## match `raid.revision`, and only accepts these three while `raid.room` really is the
## matching room, so every payload below ships `revision`.
##
## The room's authoritative state is written by `roguelike.open_room()` /
## `refresh_dedicated()` into `raid.pending_forge` (`{offers, revision}`),
## `raid.pending_gamble` (`{stake, revision}`) and `raid.mirror_state`
## (`{active, owner, round, settled}`). The panel re-quotes from those so the price the
## player sees is the price the guard will accept.
##
## NOTE: no `class_name` on purpose — the .godot class cache is stale for the newer
## Rogue* modules and a bare class name fails at parse time in headless runs. Always
## `preload` this file.

const RogueRooms = preload("res://scripts/rogue_rooms.gd")

const ACTION_FORGE := "rogue_forge"
const ACTION_GAMBLE := "rogue_gamble"
const ACTION_MIRROR := "rogue_mirror"

## R7d (2026-06 · 实机修复) · `PHASE_EXIT` 曾在这里，R7e 删除：显示门不再看相位，见 `panel_open()`。
## （删除前全仓核实过没有第二个读者：`grep PHASE_EXIT` 只命中本文件这一处声明。）

## The rooms this panel owns. Everything else keeps its existing UI.
static func handled(kind: String) -> bool:
	return kind in RogueRooms.KINDS


## R7e (2026-06 · 实机修复) · "本间服务房有没有被玩家**主动**离店"这个状态位的唯一读取口。
##
## 位置与默认值：`s.raid["room_left"]`，`roguelike.gd` 的 `reset()` 里默认 `false`，
## `enter()` 里"进房即清"。`raid` 字典整体是快照元素 11，接收端只校验顶层 `size ∈ [12,13]`，
## 所以这是 raid **内部**加键、不触碰快照顶层形状。
##
## 旧对端快照退化（契约要求）：缺键 / 形状不是 bool / key 不是 String 一律读成 `false`
## ＝"没离店"。这个方向是刻意选的——退化时面板仍按服务房显示（也就是 R7d 之前"只看房间种类"
## 的可见行为），`rogue_leave` 也照常可用，最坏结果是"离店后面板多留一帧到对端升级"，而不是
## "面板打不开、玩家被卡在服务房里"。绝不直接下标取键。
static func room_left(raid) -> bool:
	if not (raid is Dictionary): return false
	var flag: Variant=(raid as Dictionary).get("room_left",false)
	if flag is bool: return bool(flag)
	return false


## R7e (2026-06 · 实机修复) · 面板的**显示门**：房间种类属于本模块，**且**玩家还没主动离店。
##
## 为什么不再看相位：`phase=="rogue_exit"` **不是**"玩家主动走了"的同义词。三个专属房
## （锻炉 / 赌徒 / 镜像）的相位轨迹（逐行核过 `roguelike.gd`）：
##   * 进房：`enter()` 走 `SAFE_ROOMS` 分支 → `clear_room()` 把 phase 钉在 `rogue_reward`；
##   * 开箱 / 领完奖励：`finish_rewards()`（`roguelike.gd:1382`，终态在 `:1397`）**也**把服务房
##     推到 `rogue_exit` —— 这不是玩家主动离店，按用户明确要求面板必须**继续显示**，他还要接着
##     锻造 / 赌博 / 打镜像（三个动作串本来就不看相位，只要求 `raid.room` 是那间房）；
##   * 主动离店：点「离开此间」或按 ESC → `rogue_leave` 置 `raid.room_left=true`
##     （`roguelike.gd:1269`）—— 这才是面板该收起的唯一信号，收起来之后 ESC 才回到暂停菜单。
##
## 为什么不新增第三参、也不留一个没人读的 `phase` 形参：留一个不用来判定的形参会诱导下一个
## 维护者"顺手"把它用回相位门，而多一个形参又要在每个调用点上重新核实一遍。所以显示门只吃
## `raid`——它名字里连 "phase" 都没有，读者改不回相位判断，也读不到过期的相位字符串。
##
## `handled()` 的签名与返回值一个字都不能动（`tests/rogue_room_ui.gd:42-43` 直接调它），
## 状态位维度因此单独放在这个新函数里，由 `main.gd` 的派发处调用。
static func panel_open(kind: String, raid) -> bool:
	if not handled(kind): return false
	if kind=="mirror" and raid is Dictionary and bool(raid.get("mirror_state",{}).get("active",false)): return false
	return not room_left(raid)


static func action_for(kind: String) -> String:
	match kind:
		"forge": return ACTION_FORGE
		"gamble": return ACTION_GAMBLE
		"mirror": return ACTION_MIRROR
	return ""


static func room_name(kind: String) -> String:
	return str(RogueRooms.ROOM_NAMES.get(kind, kind))


static func title(kind: String) -> String:
	match kind:
		"forge": return "游方锻炉 · 熔炼与锻打"
		"gamble": return "赌徒营帐 · 三样赌法"
		"mirror": return "镜中挑战 · 与你自己的构筑对打"
	return room_name(kind)


## 一句房间说明（头顶那一行）。空房间/未知房间也给一句明确文字，不留空白。
static func body(kind: String, ctx: Dictionary) -> String:
	match kind:
		"forge":
			return "熔炼魔晶换锻造点，或当场把武器锻打 +1 级（本层上限 +%d）。转移锻造免费。" % RogueRooms.forge_level_cap(int(ctx.get("floor", 1)))
		"gamble":
			return "三种赌法的胜率与期望都写在每一项里，不藏赔率。押注只在点击的那一刻结算。"
		"mirror":
			return "应战后与持有你当前武器的镜像战斗。躲开预警并击败它领取奖励；挑战者倒地即失败，每局一次。"
	return ""


## 安全地把会话摊成 `RogueRooms` 的 context（缺字段走默认值，null 也不崩）。
static func context_of(s, p: Dictionary) -> Dictionary:
	return RogueRooms.context_of(s, p)


## 面板要画的每一行。每行都带：index / name / desc / cost / enabled / reason /
## action / payload —— main.gd 只负责画和发，不再自己判断能不能点。
static func rows(kind: String, raid: Dictionary, ctx: Dictionary) -> Array:
	var out: Array = []
	if not handled(kind):
		return out
	if kind == "mirror":
		out.append(_mirror_row(raid, ctx))
		return out
	var offers: Array = _offers_of(kind, raid, ctx)
	for i in offers.size():
		var offer: Dictionary = (offers[i] as Dictionary).duplicate(true)
		var enabled := bool(offer.get("available", false))
		out.append({
			"index": i,
			"name": str(offer.get("name", "")),
			"desc": str(offer.get("desc", "")),
			"cost": maxi(0, int(offer.get("cost", 0))),
			"enabled": enabled,
			"reason": "" if enabled else unavailable_reason(kind, offer, ctx),
			"action": action_for(kind),
			"payload": payload(raid, i),
		})
	return out


## 服务房优先用 `raid.pending_*` 里的报价（那是结算时真正要比对的 revision），
## 拿不到才退回按 context 现算，保证面板永不空白。
static func _offers_of(kind: String, raid: Dictionary, ctx: Dictionary) -> Array:
	if kind == "forge":
		var pending: Dictionary = raid.get("pending_forge", {}) if raid.get("pending_forge", {}) is Dictionary else {}
		var quoted: Array = pending.get("offers", []) if pending.get("offers", []) is Array else []
		if not quoted.is_empty():
			return quoted
	return RogueRooms.offers(kind, ctx)


static func _mirror_row(raid: Dictionary, ctx: Dictionary) -> Dictionary:
	var state: Dictionary = raid.get("mirror_state", {}) if raid.get("mirror_state", {}) is Dictionary else {}
	var active := bool(state.get("active", false))
	var used := bool(ctx.get("mirror_used", false))
	var offer: Dictionary = RogueRooms.mirror_offer(ctx)
	var enabled := true
	var reason := ""
	var name := str(offer.get("name", room_name("mirror")))
	var desc := str(offer.get("desc", ""))
	if active:
		name = "镜像战斗进行中"
		desc = "击败影子即可获胜，挑战者倒地即失败。"
		enabled = false
		reason = "请在场景中战斗"
	elif used:
		enabled = false
		reason = "本局已经挑战过镜像"
	else:
		enabled = bool(offer.get("available", false))
		if not enabled:
			reason = "本层暂不可用"
	return {
		"index": 0,
		"name": name,
		"desc": desc,
		"cost": 0,
		"enabled": enabled,
		"reason": reason,
		"action": ACTION_MIRROR,
		"payload": mirror_payload(raid),
	}


## 不可用原因：优先说「缺什么」，而不是笼统的「不可用」。
static func unavailable_reason(kind: String, offer: Dictionary, ctx: Dictionary) -> String:
	var cost := maxi(0, int(offer.get("cost", 0)))
	if cost > 0 and int(ctx.get("gold", 0)) < cost:
		return "魔晶不足（需 %d）" % cost
	match str(offer.get("method", "")):
		"tier": return "阶位已到边界（%d~%d）" % [RogueRooms.GAMBLE_TIER_FLOOR, RogueRooms.GAMBLE_TIER_CEIL]
		# BUG-SWEEP: the ash wager carries its requirement in `stake`, not in `cost`
		# (its gold cost is 0), so quoting `cost` printed "需 0".
		"ash": return "本局灰烬不足（需 %d）" % maxi(0, int(offer.get("stake", cost)))
	if str(offer.get("id", "")) == "forge_direct":
		return "本层锻造等级已达上限"
	return "当前不可用"


static func payload(raid: Dictionary, index: int) -> Dictionary:
	return {"index": int(index), "revision": int(raid.get("revision", 0))}


## 镜像只有一次点击语义（"应战" / "结算"），不需要 index，但同样必须带 revision。
static func mirror_payload(raid: Dictionary) -> Dictionary:
	return {"revision": int(raid.get("revision", 0))}


## 面板重建用的签名：房间种类、revision、以及会改变"能不能点"的本地资源。
## revision 在每次成交/应战后自增，所以报价变化一定会带上新 revision。
static func signature(kind: String, raid: Dictionary, ctx: Dictionary) -> String:
	var state: Dictionary = raid.get("mirror_state", {}) if raid.get("mirror_state", {}) is Dictionary else {}
	return "%s:%d:%d:%d:%d:%d:%d" % [
		kind,
		int(raid.get("revision", 0)),
		int(ctx.get("gold", 0)),
		int(ctx.get("forge_level", 0)),
		int(ctx.get("ash_run", 0)),
		int(ctx.get("weapon_tier", 0)),
		1 if bool(state.get("active", false)) else 0,
	]


## 面板底部那行状态提示（与既有 HUD 的措辞保持一致）。
static func footer(kind: String, raid: Dictionary, phase: String) -> String:
	var state: Dictionary = raid.get("mirror_state", {}) if raid.get("mirror_state", {}) is Dictionary else {}
	if kind == "mirror" and bool(state.get("active", false)):
		return "击败镜像领取奖励 · 挑战者倒地即失败"
	if phase == "rogue_reward":
		return "E 开箱 / 拾取 · 每人武器与装备三选一 · Tab 管理构筑"
	if phase in ["rogue_shop", "rogue_exit"]:
		return "全队向右集合 · 靠近目标路线末端按 E"
	return ""
