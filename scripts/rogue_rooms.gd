class_name RogueRooms
extends RefCounted
## R10 · 魔境三个新房间（铁匠铺 forge / 赌徒 gamble / 镜像挑战 mirror）的行为数据层。
##
## 改这个文件前先读这四条纪律：
##
## 1. **纯函数 / 纯数据**：本模块只「读」context（`context_of()` 或调用方自行拼装），
##    返回**增量字典**，从不直接改 `s` / `p` / `raid`。落地由 W1 轮次接线负责
##    （见 `output/R10-NEW-ROOMS.md` 的待接线清单）。
##
## 2. **随机只用传入的 rng**：`gamble_roll()` / `mirror_resolve()` 各自**恰好消耗 1 次
##    `rng.randf()`**；调用方必须传 `s.rng`（契约 §6.2.3：禁止全局 `randi()`/`randf()`）。
##    每个随机入口都配一个 `*_from_roll(value, ...)` 的纯变体，使「恰好一次抽取」可被测试证明
##    （tests/rogue_rooms.gd 用同种子的 `randf()` 与之对齐比较）。
##
## 3. **绝不产出命中判定几何字段**：房间只谈资源与阶位，任何返回字典都不得含
##    `hit_radius` / `collision_radius` / `velocity` 之类的键（测试有递归扫描断言）。
##
## 4. **深度下限必须与 `scripts/rogue_graph.gd` 的 `NEW_KIND_MIN_DEPTH` 一致**
##    （`curse`:3 `event`:3 `forge`:3 `gamble`:4 `mirror`:5；tests/rogue_rooms.gd 有交叉断言）。

# B3-2：诅咒的只读查询（条数 / 最近一条）来自诅咒数据层，本模块不复制那张表。
# 预加载而非裸类名：与 roguelike.gd 的写法一致，避免依赖 .godot 类缓存。
const Curses = preload("res://scripts/rogue_curses.gd")

## 本模块负责的房间类型（boss 与其它房间不在这里）。
const KINDS := ["forge", "gamble", "mirror"]
## 出现深度下限；语义与 `RogueGraph.NEW_KIND_MIN_DEPTH` 的对应项逐字相同，改动必须两边同步。
const MIN_DEPTH := {"forge": 3, "gamble": 4, "mirror": 5}
## 房间显示名（接线时并入 `roguelike.gd` 的 ROOM_NAMES）。
const ROOM_NAMES := {"forge": "游方锻炉", "gamble": "赌徒营帐", "mirror": "镜中挑战"}

# ---------------------------------------------------------------- 铁匠铺
## 与 `RogueBuild.FORGE_COST = [1,1,2,2,2]`、`mini(5, raid.floor)` 同源的规则，不另造一套。
const FORGE_MAX_LEVEL := 5
const FORGE_POINT_BASE := 30
const FORGE_POINT_PER_FLOOR := 12
const FORGE_BUNDLE_SIZE := 3
const FORGE_BUNDLE_DISCOUNT := 15
const FORGE_DIRECT_BASE := 90
const FORGE_DIRECT_PER_FLOOR := 25

# B3-2（A3「赎罪」途径）· 锻炉的第五项服务：清除一条诅咒。
## 价格 = CURSE_CLEAR_BASE + CURSE_CLEAR_PER_FLOOR × max(1, floor)（与其它锻炉报价同款随层递增）。
## 120 / 45 这两个数的理由（不是随手取的）：
##   * 全表最大的"魔晶"诅咒回报是 CU10 的 150（TABLE 里 gold boon ∈ {90,110,120,130,150}），
##     而最低价的解咒（1 层 165）已经**高于**任何一条诅咒当场给的魔晶——拿诅咒换来的钱
##     永远买不回一条解药，"诅咒＝真代价"因此不被本服务抵消成白嫖。
##   * 它同时是锻炉最贵的服务：直接锻打 90+25×floor（5 层 215）＜解咒 165..345，
##     所以解咒始终是"要不要为这一条代价赎身"的高档决策，而不是顺手买的东西。
const CURSE_CLEAR_BASE := 120
const CURSE_CLEAR_PER_FLOOR := 45

# B3-2（P2「魔晶付费刷新」）· 圣坛天赋 / 奖励三选一的逃生门（数据层的价目与上限）。
## 固定价，不随层数变。理由：刷新服务解决的是"这三张牌的方向不对口"，而这件事在任何一层
## 都同样可能发生；价随层数上涨只会让前两层（钱包本来最薄、构筑最需要对齐的时候）买不起。
## 60 = 开局魔晶全额（`roguelike.reset()` 给 60），所以它不可能变成早期免费通道；又低于
## 最便宜的商品牌价（65+floor×10 ≥ 75），也低于解咒 165，不会跟任何既有服务抢同一价格带。
const PAID_REROLL_COST := 60
## 同一份选择（一次 `p.rogue_selection`）最多用魔晶刷 2 次。
## 取值理由：一份报价只有 3 张候选，1 次付费刷新已经换了整整一屏；第 2 次兜住"第一次也霉"的
## 情况。给到第 3 次就等于花魔晶"刷到对口径为止"，那正好把这个设计要保留的代价（方向不对口
## 要么吃下、要么用稀缺的刷新卡）抹掉。上限绑在 selection 实例上，刷新卡换牌**不重置**它，
## 因此"卡片 + 魔晶"无法串成无界连刷（单次选择的付费刷新总数恒 ≤ 2）。
const PAID_REROLL_MAX := 2
## 允许付费刷新的奖励类别。与 `roguelike.reward_offers()` 真正会重新抽牌的类别一一对应；
## 其余类别（例如固定单张的属性灵晶 category="attribute"）必须明确拒绝——若放行，
## `reward_offers()` 会落到装备分支，花魔晶反而把属性灵晶换成装备（吞掉既有奖励）。
const PAID_REROLL_CATEGORIES := ["talent", "core", "boon", "gear", "weapon", "starter"]

# ---------------------------------------------------------------- 赌徒
## 三种赌法。`multiplier` 是「赢时到手的倍数（含本金）」，tier 赌法用阶位而非倍数。
## 三种赌法的期望都**不高于** 100%（诚实告知风险，不给白嫖口子）：
##   coin: 0.48 × 2.0 = 96%   ash: 0.32 × 3.0 = 96%   tier: 2×0.40-1 = -0.20 阶
const GAMBLE_METHODS := ["coin", "tier", "ash"]
const GAMBLE_ODDS := {
	"coin": {"win": 0.48, "multiplier": 2.0},
	"tier": {"win": 0.40, "multiplier": 0.0},
	"ash": {"win": 0.32, "multiplier": 3.0},
}
const GAMBLE_BASE_STAKE := 40
const GAMBLE_STAKE_PER_FLOOR := 15
const GAMBLE_MAX_STAKE := 220
## 押阶位的上下界：胜则 +1（不超 FORGE_MAX_LEVEL），败则 -1（不低于 1）。
const GAMBLE_TIER_FLOOR := 1
const GAMBLE_TIER_CEIL := 5

# ---------------------------------------------------------------- 镜像挑战
const MIRROR_REWARD_GOLD_BASE := 60
const MIRROR_REWARD_GOLD_PER_FLOOR := 20
const MIRROR_REWARD_GOLD_CAP := 400
const MIRROR_REWARD_ASH_BASE := 20
const MIRROR_REWARD_ASH_PER_FLOOR := 5
const MIRROR_REWARD_ASH_CAP := 60
const MIRROR_REWARD_GEAR := 1

## 增量字典允许的键（冻结；B3-2 追加 `curse_clear`，见 §A3）。
## 正数=进账，负数=支出；`bind` 是布尔，`curse_clear` 是「解咒条数/目标 id」（见 apply_room_delta）。
const DELTA_KEYS := ["gold", "forge_points", "forge_level", "bind", "weapon_tier", "ash", "gear_reward", "curse_clear"]

# ============================================================================
# 通用：房间级查询与 context 拼装
# ============================================================================

static func kinds() -> Array:
	return KINDS.duplicate()

static func min_depth(kind: String) -> int:
	return int(MIN_DEPTH.get(kind, 0))

## 纯函数：这个房间能否出现在「本层第 floor_index 层、图深度 depth」的位置。
## 与 RogueGraph 的深度下限同源；未知房间一律 false。
static func appears_at(kind: String, floor_index: int, depth: int) -> bool:
	if kind not in KINDS: return false
	return maxi(0, depth) >= int(MIN_DEPTH[kind])

## 只读地把 session / player 摊成一个扁平 context。缺字段全部走安全默认值，
## 传 null session 或空字典也不会崩。
static func context_of(s, p: Dictionary) -> Dictionary:
	var data: Dictionary = p if p is Dictionary else {}
	var equipped: Dictionary = _dict(data.get("equipped", {}))
	var weapon: Dictionary = _dict(equipped.get("weapon", {}))
	var raid: Dictionary = {}
	if s != null:
		raid = _dict(s.get("raid"))
	return {
		"floor": maxi(1, _int(raid.get("floor", 1), 1)),
		"depth": maxi(1, _int(raid.get("depth", 1), 1)),
		"player": maxi(0, _int(data.get("id", 0), 0)),
		"gold": maxi(0, _int(data.get("rogue_gold", 0), 0)),
		"forge_points": maxi(0, _int(data.get("build_forge_points", 0), 0)),
		"forge_level": maxi(0, _int(data.get("build_forge_level", 0), 0)),
		"weapon_tier": maxi(0, _int(weapon.get("tier", 0), 0)),
		"ash_run": maxi(0, _int(data.get("rogue_ash_run", 0), 0)),
		"mirror_used": bool(data.get("rogue_mirror_used", false)),
		"mirror_active": bool(_dict(raid.get("mirror_state", {})).get("active", false)),
		# B3-2（A3）：本人身上的诅咒。`count()` 只数表里真实存在的 id，未知垃圾 id 不计；
		# `curse_last` 是"最近获得的一条"（p["rogue_curses"] 尾部），锻炉的赎罪行按它报价。
		"curse_count": Curses.count(data),
		"curse_last": Curses.last_id(data),
	}

## HUD / 测试用的房间说明。未知房间 → {}。
static func describe(kind: String, ctx: Dictionary) -> Dictionary:
	if kind not in KINDS: return {}
	var context: Dictionary = ctx if ctx is Dictionary else {}
	return {
		"kind": kind,
		"name": str(ROOM_NAMES[kind]),
		"min_depth": int(MIN_DEPTH[kind]),
		"available": not offers(kind, context).is_empty(),
	}

## 统一入口：返回房间的选项列表（未知房间 → 空数组）。
static func offers(kind: String, ctx: Dictionary) -> Array:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	match kind:
		"forge": return forge_offers(context)
		"gamble": return gamble_offers(context)
		"mirror": return [mirror_offer(context)]
	return []

## 统一入口：结算一个选项。
## `rng` 只在 gamble / mirror 上被使用（各恰好 1 次 `randf()`）；forge 完全不用随机。
## 未知房间 / 非法 index / 条件不足 → `{"ok":false, "reason":...}`，绝不崩、绝不改状态。
static func resolve(kind: String, option_index: int, ctx: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	match kind:
		"forge": return forge_resolve(option_index, context)
		"gamble":
			if rng == null: return {"ok": false, "reason": "rng"}
			return gamble_roll(rng, option_index, context)
		"mirror":
			if rng == null: return {"ok": false, "reason": "rng"}
			return mirror_resolve(rng, context)
	return {"ok": false, "reason": "kind"}

# ============================================================================
# 铁匠铺 forge —— 全部无随机、纯函数
# ============================================================================

## 单点锻造点的价格（随楼层单调不降）。
static func forge_point_price(floor_index: int) -> int:
	return FORGE_POINT_BASE + FORGE_POINT_PER_FLOOR*maxi(1, floor_index)

## 三点套餐价（比单买省 FORGE_BUNDLE_DISCOUNT）。
static func forge_bundle_price(floor_index: int) -> int:
	var single := forge_point_price(floor_index)
	return maxi(1, FORGE_BUNDLE_SIZE*single - FORGE_BUNDLE_DISCOUNT)

## 直接锻打一级的价格（随楼层单调不降）。
static func forge_direct_price(floor_index: int) -> int:
	return FORGE_DIRECT_BASE + FORGE_DIRECT_PER_FLOOR*maxi(1, floor_index)

## 本层允许达到的锻造等级上限，与 `RogueBuild` 的 `mini(5, raid.floor)` 相同。
static func forge_level_cap(floor_index: int) -> int:
	return mini(FORGE_MAX_LEVEL, maxi(1, floor_index))

## B3-2（A3）· 赎罪价（随楼层单调递增）。公式见 CURSE_CLEAR_BASE 的注释。
static func curse_clear_price(floor_index: int) -> int:
	return CURSE_CLEAR_BASE + CURSE_CLEAR_PER_FLOOR*maxi(1, floor_index)

## B3-2（A3）· 只读：当前这场报价里"赎罪行"的下标；没有这一行返回 -1。
## 行只在本人**确实有真诅咒**时存在（`curse_count>0`），所以其余玩家的锻炉报价仍是冻结的 4 项。
static func curse_clear_index(ctx: Dictionary) -> int:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	if maxi(0, _int(context.get("curse_count", 0), 0))<=0: return -1
	return 4

## 四个基础服务（+ 有诅咒时的第五项「赎罪」）。每项都带 `cost` / `delta` / `available`，
## UI 直接照抄即可；追加项**永远排在最后**，因此既有 4 项的下标 0..3 不会移动。
static func forge_offers(ctx: Dictionary) -> Array:
	var floor_index := maxi(1, _int(ctx.get("floor", 1), 1))
	var gold := maxi(0, _int(ctx.get("gold", 0), 0))
	var level := maxi(0, _int(ctx.get("forge_level", 0), 0))
	var cap := forge_level_cap(floor_index)
	var single := forge_point_price(floor_index)
	var bundle := forge_bundle_price(floor_index)
	var direct := forge_direct_price(floor_index)
	var offers: Array=[]
	offers.append({
		"id": "forge_points_1", "name": "熔炼 · 1 点锻造",
		"desc": "花 %d 魔晶换 1 点锻造点。" % single,
		"cost": single, "delta": {"forge_points": 1}, "available": gold>=single,
	})
	offers.append({
		"id": "forge_points_3", "name": "熔炼 · 3 点锻造（套餐）",
		"desc": "花 %d 魔晶换 3 点锻造点（比单买省 %d）。" % [bundle, FORGE_BUNDLE_SIZE*single-bundle],
		"cost": bundle, "delta": {"forge_points": FORGE_BUNDLE_SIZE}, "available": gold>=bundle,
	})
	offers.append({
		"id": "forge_direct", "name": "当场锻打 · +1 级",
		"desc": "花 %d 魔晶直接把武器锻造等级 +1（本层上限 +%d，当前 +%d）。" % [direct, cap, level],
		"cost": direct, "delta": {"forge_level": 1}, "available": gold>=direct and level<cap,
	})
	offers.append({
		"id": "forge_rebind", "name": "转移锻造",
		"desc": "把已有的锻造等级重新绑定到当前武器上（免费）。",
		"cost": 0, "delta": {"bind": true}, "available": true,
	})
	# B3-2（A3）· 赎罪途径：只有身上**确实有真诅咒**时才追加这一行（无诅咒 → 报价仍是 4 项，
	# 与冻结的既有断言逐位一致）。价格随层数递增；清除目标＝最近获得的那一条（列表尾部）。
	var curse_count := maxi(0, _int(ctx.get("curse_count", 0), 0))
	if curse_count>0:
		var price := curse_clear_price(floor_index)
		var target := str(ctx.get("curse_last", ""))
		var row: Dictionary = Curses.find(target)
		offers.append({
			"id": "forge_absolve", "name": "赎罪仪式 · 清除一条诅咒",
			"desc": "花 %d 魔晶清除最近获得的诅咒「%s」（%s）；身上还剩 %d 条。" % [
				price, str(row.get("name", target)), str(row.get("desc", "")), curse_count],
			"cost": price, "delta": {"curse_clear": 1}, "available": gold>=price,
			"curse_id": target,
		})
	return offers

## 结算一个铁匠铺选项。用 0 次随机。
static func forge_resolve(option_index: int, ctx: Dictionary) -> Dictionary:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	var offers_list := forge_offers(context)
	if option_index<0 or option_index>=offers_list.size():
		return {"ok": false, "reason": "index"}
	var offer: Dictionary=offers_list[option_index]
	if not bool(offer.get("available", false)):
		return {"ok": false, "reason": "unavailable", "offer": offer.duplicate(true)}
	return {
		"ok": true, "id": str(offer.id), "cost": int(offer.cost),
		"delta": _dict(offer.get("delta", {})).duplicate(true),
		"desc": str(offer.desc),
	}

# ============================================================================
# 赌徒 gamble —— 每次有效下注恰好 1 次 rng.randf()
# ============================================================================

static func gamble_stake(floor_index: int) -> int:
	return clampi(GAMBLE_BASE_STAKE + GAMBLE_STAKE_PER_FLOOR*maxi(1, floor_index), GAMBLE_BASE_STAKE, GAMBLE_MAX_STAKE)

static func gamble_odds(method: String) -> Dictionary:
	return _odds(method)

## 期望"回报率"（coin/ash：到手倍数×胜率；tier：期望阶位变化）。未知赌法 → 0。
static func gamble_return_ratio(method: String) -> float:
	var odds := _odds(method)
	if odds.is_empty(): return 0.0
	if method=="tier": return 2.0*float(odds.win)-1.0
	return float(odds.win)*float(odds.multiplier)

## 期望"净变化"：coin/ash 是净魔晶/净灰烬，tier 是净阶位。未知赌法 / 非正注额 → 0。
static func gamble_expectation(method: String, stake: int) -> float:
	var odds := _odds(method)
	if odds.is_empty(): return 0.0
	if method=="tier": return 2.0*float(odds.win)-1.0
	return (float(odds.win)*float(odds.multiplier)-1.0)*float(maxi(0, stake))

## 三种赌法。描述文本里必须写清胜率与期望，不许藏着。
static func gamble_offers(ctx: Dictionary) -> Array:
	var floor_index := maxi(1, _int(ctx.get("floor", 1), 1))
	var stake := gamble_stake(floor_index)
	var gold := maxi(0, _int(ctx.get("gold", 0), 0))
	var ash := maxi(0, _int(ctx.get("ash_run", 0), 0))
	var tier := maxi(0, _int(ctx.get("weapon_tier", 0), 0))
	var offers: Array=[]
	var coin := _odds("coin")
	offers.append({
		"id": "gamble_coin", "method": "coin", "name": "掷币 · 押魔晶", "stake": stake,
		"desc": "押 %d 魔晶：胜率 %d%% · 净赢 %d · 期望回报 %.0f%%。" % [
			stake, int(round(float(coin.win)*100.0)), stake, gamble_return_ratio("coin")*100.0],
		"cost": stake, "p_win": float(coin.win), "available": gold>=stake,
	})
	var tier_odds := _odds("tier")
	offers.append({
		"id": "gamble_tier", "method": "tier", "name": "押装备升阶", "stake": 1,
		"desc": "押 1 级武器阶位：胜率 %d%% · 胜则阶 +1（上限 %d），败则阶 -1（不低于 %d）· 期望 %.2f 阶。" % [
			int(round(float(tier_odds.win)*100.0)), GAMBLE_TIER_CEIL, GAMBLE_TIER_FLOOR, gamble_expectation("tier", 1)],
		"cost": 0, "p_win": float(tier_odds.win), "available": tier>=GAMBLE_TIER_FLOOR and tier<GAMBLE_TIER_CEIL,
	})
	var ash_odds := _odds("ash")
	offers.append({
		"id": "gamble_ash", "method": "ash", "name": "押灰烬", "stake": stake,
		"desc": "押 %d 灰烬：胜率 %d%% · 净赢 %d · 期望回报 %.0f%%。" % [
			stake, int(round(float(ash_odds.win)*100.0)), 2*stake, gamble_return_ratio("ash")*100.0],
		"cost": 0, "p_win": float(ash_odds.win), "available": ash>=stake,
	})
	return offers

## 唯一随机点：恰好消耗 1 次 `rng.randf()`。条件不足 / 非法 index 时**不抽取**、不改状态。
static func gamble_roll(rng: RandomNumberGenerator, option_index: int, ctx: Dictionary) -> Dictionary:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	var offers_list := gamble_offers(context)
	if rng==null: return {"ok": false, "reason": "rng"}
	if option_index<0 or option_index>=offers_list.size():
		return {"ok": false, "reason": "index"}
	var offer: Dictionary=offers_list[option_index]
	if not bool(offer.get("available", false)):
		return {"ok": false, "reason": "unavailable", "offer": offer.duplicate(true)}
	return gamble_from_roll(rng.randf(), str(offer.method), int(offer.stake), context)

## 纯变体：把一次抽取的结果喂进来即可复算，用于证明"只抽一次"与同种子可复现。
static func gamble_from_roll(value: float, method: String, stake: int, ctx: Dictionary) -> Dictionary:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	var odds := _odds(method)
	if odds.is_empty() or method not in GAMBLE_METHODS:
		return {"ok": false, "reason": "method"}
	var floor_index := maxi(1, _int(context.get("floor", 1), 1))
	var stake_value := maxi(1, int(stake))
	var p_win := clampf(float(odds.win), 0.0, 1.0)
	var roll := clampf(float(value), 0.0, 0.999999)
	var win := roll<p_win
	var tier := maxi(0, _int(context.get("weapon_tier", 0), 0))
	var delta: Dictionary={}
	match method:
		"coin":
			delta["gold"]=stake_value if win else -stake_value
		"ash":
			delta["ash"]=2*stake_value if win else -stake_value
		"tier":
			if win: delta["weapon_tier"]=mini(GAMBLE_TIER_CEIL, maxi(tier, GAMBLE_TIER_FLOOR)+1)
			else: delta["weapon_tier"]=maxi(GAMBLE_TIER_FLOOR, tier-1)
	var payout := 0
	if win and method!="tier": payout=stake_value*int(round(float(odds.multiplier)))
	return {
		"ok": true, "method": method, "stake": stake_value, "roll": roll, "p_win": p_win,
		"win": win, "payout": payout, "delta": delta,
		"floor": floor_index,
	}

# ============================================================================
# 镜像挑战 mirror —— 每次有效结算恰好 1 次 rng.randf()
# ============================================================================

## 本局还能不能开镜像：契约 §3 的 `p.rogue_mirror_used`（本局是否已领奖）
## ＋ `raid.mirror_state.active`（是否正在打）。节点图保证每层最多一个 mirror 节点。
static func mirror_allowed(ctx: Dictionary) -> bool:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	if bool(context.get("mirror_used", false)): return false
	if bool(context.get("mirror_active", false)): return false
	return int(context.get("floor", 1))>=1

## 镜像对手与奖励描述（纯数据，不实例化任何战斗单位）。
static func mirror_offer(ctx: Dictionary) -> Dictionary:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	var floor_index := maxi(1, _int(context.get("floor", 1), 1))
	var tier := maxi(0, _int(context.get("weapon_tier", 0), 0))
	var gold_reward := clampi(MIRROR_REWARD_GOLD_BASE + MIRROR_REWARD_GOLD_PER_FLOOR*floor_index + 10*tier, MIRROR_REWARD_GOLD_BASE, MIRROR_REWARD_GOLD_CAP)
	var ash_reward := clampi(MIRROR_REWARD_ASH_BASE + MIRROR_REWARD_ASH_PER_FLOOR*floor_index, MIRROR_REWARD_ASH_BASE, MIRROR_REWARD_ASH_CAP)
	# 对手强度只看层的进度，不看玩家战力，避免"装备越强镜像越无敌"。
	var hp_scale := clampf(0.90 + 0.22*float(floor_index-1), 0.90, 1.90)
	var p_win := clampf(0.62 - 0.045*float(floor_index) + 0.02*float(tier), 0.30, 0.65)
	return {
		"id": "mirror", "kind": "mirror", "name": str(ROOM_NAMES["mirror"]),
		"desc": "应战后生成持有你当前武器的镜像，击败它得 %d 魔晶 + 1 次装备三选一 + %d 灰烬；倒地即失败，每局一次。" % [gold_reward, ash_reward],
		"available": mirror_allowed(context),
		"opponent": {"name": "镜像 · 你的构筑", "hp_scale": hp_scale, "tier": tier, "floor": floor_index},
		"reward": {"gold": gold_reward, "gear_reward": MIRROR_REWARD_GEAR, "ash": ash_reward},
		"p_win": p_win,
	}

## 接受挑战：已用过 / 正在打 → 安全拒绝（这就是「连续请求第二次安全拒绝」）。
static func mirror_accept(ctx: Dictionary) -> Dictionary:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	if not mirror_allowed(context):
		return {"ok": false, "reason": "active" if bool(context.get("mirror_active", false)) else "used"}
	return {
		"ok": true,
		"state": {
			"active": true, "owner": maxi(0, _int(context.get("player", 0), 0)),
			"round": 1, "settled": false,
		},
		"offer": mirror_offer(context),
	}

## 唯一随机点：恰好消耗 1 次 `rng.randf()`。未处于 active 状态时**不抽取**。
static func mirror_resolve(rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	if rng==null: return {"ok": false, "reason": "rng"}
	var context: Dictionary = ctx if ctx is Dictionary else {}
	if not bool(context.get("mirror_active", false)):
		return {"ok": false, "reason": "inactive"}
	return mirror_from_roll(rng.randf(), context)

## 纯变体：把一次抽取的结果喂进来即可复算。
static func mirror_from_roll(value: float, ctx: Dictionary) -> Dictionary:
	var context: Dictionary = ctx if ctx is Dictionary else {}
	if not bool(context.get("mirror_active", false)):
		return {"ok": false, "reason": "inactive"}
	var offer := mirror_offer(context)
	var p_win := clampf(float(offer.get("p_win", 0.5)), 0.0, 1.0)
	var roll := clampf(float(value), 0.0, 0.999999)
	var win := roll<p_win
	var reward: Dictionary=_dict(offer.get("reward", {}))
	var delta: Dictionary={}
	var settled_reward: Dictionary={}
	if win:
		delta["gold"]=int(reward.get("gold", 0))
		delta["ash"]=int(reward.get("ash", 0))
		delta["gear_reward"]=int(reward.get("gear_reward", 0))
		settled_reward=delta.duplicate(true)
	return {
		"ok": true, "win": win, "roll": roll, "p_win": p_win, "delta": delta, "reward": settled_reward,
		"state": {
			"active": false, "owner": int(_dict(context).get("player", 0)),
			"round": 2, "settled": true,
		},
		"used": true,
	}

# ============================================================================
# B3-2（P2）· 圣坛天赋 / 奖励三选一：用魔晶付费刷新
# ============================================================================
# 设计约束（读代码前先读这五条）：
# 1. **计数在 selection 里，不在 raid 里**：`p["rogue_selection"]["paid_rerolls"]`。
#    selection 是玩家字典的一部分（随快照 data[0] 整表下发），所以不新增任何 raid 键、
#    不新增快照顶层字段；旧快照里没有这个键时按 0 处理（`paid_reroll_state()`），安全退化。
# 2. **上限绑在 selection 实例上**：换一份 `p.rogue_selection`（下一个奖励）才重置计数；
#    「刷新卡刷新」只改 offers/version，**不重置**它，所以卡片+魔晶串不成无界连刷。
# 3. **只读、纯函数**：本节的函数不改任何状态；扣费与换牌由 `roguelike.selection_action()`
#    在守卫通过后一次性完成（失败路径零变化：不扣魔晶、不换牌、不推进计数）。
# 4. **类别白名单**：只有 `reward_offers()` 真会重新抽牌的类别可刷（PAID_REROLL_CATEGORIES）。
#    其余（如固定单张的属性灵晶）明确拒绝——放行会被 reward_offers 换成装备＝吞掉既有奖励。
# 5. **不消耗任何新随机源**：刷新复用既有的 `reward_offers()`（即刷新卡那条路径），
#    因此同种子同输入仍然逐位可复现。

## 只读快照：这份选择已经用魔晶刷了几次 / 还能刷几次 / 单价多少。
static func paid_reroll_state(selection: Dictionary) -> Dictionary:
	var used := maxi(0, _int(_dict(selection).get("paid_rerolls", 0), 0))
	return {"used": used, "max": PAID_REROLL_MAX, "left": maxi(0, PAID_REROLL_MAX-used), "cost": PAID_REROLL_COST}

## 纯函数守卫：这次付费刷新能不能做，不能做就把**为什么**写清楚（供 UI 与错误回执直接照抄）。
## 返回 {"ok", "reason", "message", "cost", "used", "max", "left"}；reason ∈ ok/gold/exhausted/category。
static func paid_reroll_check(selection: Dictionary, gold: int) -> Dictionary:
	var sel: Dictionary = _dict(selection)
	var state := paid_reroll_state(sel)
	state["reason"] = "ok"
	state["message"] = ""
	var category := str(sel.get("category", "gear"))
	if int(state["left"])<=0:
		state["ok"]=false
		state["reason"]="exhausted"
		state["message"]="本次报价已用魔晶刷新 %d 次（上限 %d）：再用刷新卡换牌，或直接选一张。" % [
			int(state["used"]), PAID_REROLL_MAX]
		return state
	if category not in PAID_REROLL_CATEGORIES:
		state["ok"]=false
		state["reason"]="category"
		state["message"]="这类奖励不支持魔晶刷新（%s）" % category
		return state
	if maxi(0, int(gold))<PAID_REROLL_COST:
		state["ok"]=false
		state["reason"]="gold"
		state["message"]="魔晶不足：魔晶刷新需要 %d，当前 %d（本次报价还剩 %d 次）。" % [
			PAID_REROLL_COST, maxi(0, int(gold)), int(state["left"])]
		return state
	state["ok"]=true
	state["message"]="花 %d 魔晶更换这一屏候选（本次报价第 %d / %d 次）。" % [
		PAID_REROLL_COST, int(state["used"])+1, PAID_REROLL_MAX]
	return state

# ============================================================================
# 内部安全转换（缺字段 / 类型错一律降级，不崩）
# ============================================================================

static func _dict(value) -> Dictionary:
	return value if value is Dictionary else {}

static func _int(value, fallback: int = 0) -> int:
	if value is int: return int(value)
	if value is float: return int(value)
	return fallback

static func _odds(method: String) -> Dictionary:
	var row = GAMBLE_ODDS.get(method, {})
	return row.duplicate(true) if row is Dictionary else {}
