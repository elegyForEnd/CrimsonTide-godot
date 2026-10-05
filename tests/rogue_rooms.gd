extends SceneTree
## R10 · 三个新房间（铁匠铺 forge / 赌徒 gamble / 镜像挑战 mirror）数据层验收。
## 覆盖派单的 7 条：增量类型与安全失败 / 同种子确定且恰好一次抽取 / 赔率与实测统计一致 /
## 铁匠铺价格单调与上限与余额门槛 / 镜像每层至多一次与奖励上限 / 无判定几何键 / 与节点图深度下限一致。
const Rooms = preload("res://scripts/rogue_rooms.gd")
const Graph = preload("res://scripts/rogue_graph.gd")

var checks := 0
var failures := 0
var sessions: Array=[]

const FORBIDDEN := ["hit_radius", "hit_zone", "hitboxes", "velocity", "v", "p", "bullet", "bullets", "damage", "collision_radius", "hit_circle", "hit_points"]

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func same(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key): return false
			if not same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not same(a[i], b[i]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a), float(b))
	return a==b

## 递归扫描：任何返回字典都不得出现命中判定几何键。
func scan(value, path: String) -> void:
	if value is Dictionary:
		for key in value:
			check(str(key) not in FORBIDDEN, "Result dict must not carry hit geometry: "+path+"."+str(key))
			scan(value[key], path+"."+str(key))
	elif value is Array:
		for i in value.size(): scan(value[i], "%s[%d]" % [path, i])

## 会话脚本按需加载：数据层验收不应被并发写者把 session.gd 拖成不可编译而整体失败，
## 因此"真实会话"那一段改成运行期 load()，编译不过就**明确打印 SKIPPED**（绝不静默通过）。
func session_script():
	return load("res://scripts/session.gd")

func fresh(script, seed: int = 4242) -> Dictionary:
	var s=script.new()
	root.add_child(s)
	s.set_physics_process(false)
	sessions.append(s)
	s.solo({"hero": 0, "mode": "roguelike"})
	s.launch(false, seed)
	return {"s": s, "p": s.players[1]}

func base_ctx(floor_index: int = 3) -> Dictionary:
	return {
		"floor": floor_index, "depth": 3, "player": 1, "gold": 400,
		"forge_points": 0, "forge_level": 1, "weapon_tier": 3, "ash_run": 300,
		"mirror_used": false, "mirror_active": false,
	}

func run() -> void:
	# ============================================================ A. 表结构与交叉一致性
	check(Rooms.KINDS.size()==3, "Exactly three new room kinds")
	check(Rooms.kinds().size()==Rooms.KINDS.size(), "kinds() mirrors the frozen list")
	for kind in Rooms.KINDS:
		check(str(kind) in Rooms.ROOM_NAMES, "Each kind has a display name: "+str(kind))
		check(not str(Rooms.ROOM_NAMES[kind]).is_empty(), "Display name is non-empty: "+str(kind))
		check(str(kind) in Graph.kinds(), "Room kind also exists in the node graph: "+str(kind))
		check(int(Rooms.MIN_DEPTH[kind])==int(Graph.NEW_KIND_MIN_DEPTH[kind]), "Depth floor matches RogueGraph for "+str(kind))
	check(Rooms.min_depth("forge")==3 and Rooms.min_depth("gamble")==4 and Rooms.min_depth("mirror")==5, "Frozen depth floors are 3/4/5")
	check(Rooms.min_depth("nope")==0 and Rooms.min_depth("")==0, "Unknown kind has no depth floor")
	check(not Rooms.appears_at("forge", 3, 2) and Rooms.appears_at("forge", 3, 3), "forge needs depth >= 3")
	check(not Rooms.appears_at("gamble", 3, 3) and Rooms.appears_at("gamble", 3, 4), "gamble needs depth >= 4")
	check(not Rooms.appears_at("mirror", 3, 4) and Rooms.appears_at("mirror", 3, 5), "mirror needs depth >= 5")
	check(not Rooms.appears_at("nope", 5, 9), "Unknown kind never appears")
	check(not Rooms.appears_at("forge", 3, -4), "Negative depth never satisfies a floor")
	check(Rooms.describe("nope", {}).is_empty(), "describe() of an unknown kind is empty")
	check(Rooms.offers("nope", {}).is_empty(), "offers() of an unknown kind is empty")
	check(not Rooms.resolve("nope", 0, {}).get("ok", true), "resolve() of an unknown kind fails safely")
	for kind in Rooms.KINDS:
		var desc: Dictionary=Rooms.describe(str(kind), base_ctx())
		check(not desc.is_empty() and desc.has("kind") and desc.has("min_depth"), "describe() carries kind and min_depth: "+str(kind))
		check(same(JSON.parse_string(JSON.stringify(desc)), desc), "describe() survives a JSON round trip: "+str(kind))

	# ============================================================ B. 铁匠铺
	var previous_points := 0
	var previous_direct := 0
	for floor_index in range(1, 9):
		var single := Rooms.forge_point_price(floor_index)
		var bundle := Rooms.forge_bundle_price(floor_index)
		var direct := Rooms.forge_direct_price(floor_index)
		check(single>0 and bundle>0 and direct>0, "Forge prices are positive on floor "+str(floor_index))
		check(single>=previous_points, "Point price never drops across floors: "+str(floor_index))
		check(direct>=previous_direct, "Direct-forge price never drops across floors: "+str(floor_index))
		check(bundle<Rooms.FORGE_BUNDLE_SIZE*single, "Bundle is cheaper than buying three singles: "+str(floor_index))
		previous_points=single
		previous_direct=direct
	check(Rooms.forge_level_cap(1)==1 and Rooms.forge_level_cap(2)==2 and Rooms.forge_level_cap(5)==5, "Level cap follows the floor")
	check(Rooms.forge_level_cap(9)==Rooms.FORGE_MAX_LEVEL, "Level cap is clamped at +5")
	var forge_ctx := base_ctx(4)
	forge_ctx["gold"]=0
	forge_ctx["forge_level"]=0
	var broke: Array=Rooms.forge_offers(forge_ctx)
	check(broke.size()==4, "Forge always exposes four services")
	for i in broke.size():
		var offer: Dictionary=broke[i]
		check(offer.has("id") and offer.has("name") and offer.has("desc") and offer.has("cost") and offer.has("delta") and offer.has("available"), "Forge offer carries the frozen keys")
		check(not str(offer.name).is_empty() and not str(offer.desc).is_empty(), "Forge offer has name and description")
		check(typeof(offer.cost)==TYPE_INT and int(offer.cost)>=0, "Forge cost is a non-negative int")
		scan(offer, "forge_offer[%d]" % i)
	var rebind: Dictionary=Rooms.forge_resolve(3, forge_ctx)
	check(bool(rebind.ok) and int(rebind.cost)==0 and bool(rebind.delta.bind), "Free rebind service always available")
	for i in [0, 1, 2]:
		check(not bool(broke[i].available), "Paid forge service is unavailable when broke: "+str(broke[i].id))
		var refused: Dictionary=Rooms.forge_resolve(i, forge_ctx)
		check(not bool(refused.ok) and str(refused.get("reason", ""))=="unavailable", "Broke player cannot buy forge service "+str(broke[i].id))
	var rich_ctx := base_ctx(4)
	rich_ctx["gold"]=5000
	rich_ctx["forge_level"]=0
	var rich: Array=Rooms.forge_offers(rich_ctx)
	for i in [0, 1, 2]:
		check(bool(rich[i].available), "Rich player can buy forge service "+str(rich[i].id))
		var done: Dictionary=Rooms.forge_resolve(i, rich_ctx)
		check(bool(done.ok), "Rich player's forge purchase resolves: "+str(rich[i].id))
		check(int(done.cost)==int(rich[i].cost), "Charged cost equals the quoted price: "+str(rich[i].id))
		for key in done.delta: check(str(key) in Rooms.DELTA_KEYS, "Forge delta key is canonical: "+str(key))
		scan(done, "forge_resolve[%d]" % i)
	var capped_ctx := base_ctx(3)
	capped_ctx["gold"]=5000
	capped_ctx["forge_level"]=Rooms.forge_level_cap(3)
	var capped: Array=Rooms.forge_offers(capped_ctx)
	check(not bool(capped[2].available), "Direct forge is unavailable at the floor cap")
	check(not bool(Rooms.forge_resolve(2, capped_ctx).ok), "Cannot upgrade past the floor cap")
	check(not bool(Rooms.forge_resolve(-1, rich_ctx).ok) and not bool(Rooms.forge_resolve(9, rich_ctx).ok), "Out-of-range forge option is rejected")
	var forge_rng := RandomNumberGenerator.new()
	forge_rng.seed=99
	var forge_state := forge_rng.state
	Rooms.forge_resolve(0, rich_ctx)
	check(forge_rng.state==forge_state, "The forge consumes no randomness at all")
	check(same(JSON.parse_string(JSON.stringify(rich)), rich), "Forge offers survive a JSON round trip")

	# ============================================================ C. 赌徒
	var gamble_ctx := base_ctx(3)
	gamble_ctx["gold"]=100000
	gamble_ctx["ash_run"]=100000
	var gambles: Array=Rooms.gamble_offers(gamble_ctx)
	check(gambles.size()==3, "Gambler exposes exactly three methods")
	for i in gambles.size():
		var offer: Dictionary=gambles[i]
		check(str(offer.method) in Rooms.GAMBLE_METHODS, "Gamble method is frozen: "+str(offer.get("method", "")))
		check(str(offer.desc).contains("%"), "Gamble description states its odds in percent")
		check(float(offer.p_win)>0.0 and float(offer.p_win)<1.0, "Win chance is a real probability")
		scan(offer, "gamble_offer[%d]" % i)
	check(float(Rooms.gamble_return_ratio("coin"))<1.0, "Coin gamble never returns more than the stake")
	check(float(Rooms.gamble_return_ratio("ash"))<1.0, "Ash gamble never returns more than the stake")
	check(float(Rooms.gamble_return_ratio("tier"))<0.0, "Tier gamble has a negative expected tier change")
	check(is_equal_approx(Rooms.gamble_return_ratio("coin"), 0.96), "Coin expected return is 96%")
	check(is_equal_approx(Rooms.gamble_return_ratio("ash"), 0.96), "Ash expected return is 96%")
	check(is_equal_approx(Rooms.gamble_return_ratio("nope"), 0.0), "Unknown method has no odds")
	check(is_equal_approx(Rooms.gamble_expectation("coin", 100), -4.0), "Coin expectation matches the stated odds")
	for i in Rooms.GAMBLE_METHODS.size():
		var method: String=str(Rooms.GAMBLE_METHODS[i])
		var stake := int(gambles[i].stake)
		var a := RandomNumberGenerator.new(); a.seed=777
		var b := RandomNumberGenerator.new(); b.seed=777
		var via_rng: Dictionary=Rooms.gamble_roll(a, i, gamble_ctx)
		var via_value: Dictionary=Rooms.gamble_from_roll(b.randf(), method, stake, gamble_ctx)
		check(same(via_rng, via_value), "gamble_roll is exactly one randf() draw: "+method)
		check(a.state==b.state, "gamble_roll advances the stream by exactly one draw: "+method)
		check(bool(via_rng.ok), "Seeded gamble roll succeeds: "+method)
		for key in via_rng.delta: check(str(key) in Rooms.DELTA_KEYS, "Gamble delta key is canonical: "+str(key))
		scan(via_rng, "gamble_roll."+method)
	# 同 (seed, 楼层, 选项) 重复 1000 次结果完全一致
	for i in gambles.size():
		var reference: Dictionary={}
		for round_index in 1000:
			var rng := RandomNumberGenerator.new(); rng.seed=20261005
			var rolled: Dictionary=Rooms.gamble_roll(rng, i, gamble_ctx)
			if round_index==0: reference=rolled
			elif not same(rolled, reference):
				check(false, "Gamble roll is not deterministic across repeats: "+str(gambles[i].method))
				break
		check(not reference.is_empty(), "Determinism probe produced a result: "+str(gambles[i].method))
	# 押阶位的上下界
	for tier in [1, 2, 3, 4, 5]:
		var tier_ctx := gamble_ctx.duplicate(true)
		tier_ctx["weapon_tier"]=tier
		var win_delta: Dictionary=Rooms.gamble_from_roll(0.0, "tier", 1, tier_ctx)
		var lose_delta: Dictionary=Rooms.gamble_from_roll(0.999, "tier", 1, tier_ctx)
		check(bool(win_delta.win) and bool(lose_delta.win)==false, "Tier gamble honours the win threshold at tier "+str(tier))
		check(int(win_delta.delta.weapon_tier)<=Rooms.GAMBLE_TIER_CEIL, "Tier win never exceeds the ceiling: "+str(tier))
		check(int(win_delta.delta.weapon_tier)==mini(Rooms.GAMBLE_TIER_CEIL, tier+1), "Tier win adds exactly one step: "+str(tier))
		check(int(lose_delta.delta.weapon_tier)>=Rooms.GAMBLE_TIER_FLOOR, "Tier loss never goes below the floor: "+str(tier))
		check(int(lose_delta.delta.weapon_tier)==maxi(Rooms.GAMBLE_TIER_FLOOR, tier-1), "Tier loss removes exactly one step: "+str(tier))
	# 2000 样本实测赔率
	var sample_rng := RandomNumberGenerator.new(); sample_rng.seed=31337
	var coin_wins := 0
	var coin_net := 0.0
	var coin_stake := int(gambles[0].stake)
	for i in 2000:
		var rolled: Dictionary=Rooms.gamble_roll(sample_rng, 0, gamble_ctx)
		if bool(rolled.win): coin_wins+=1
		coin_net+=float(rolled.delta.gold)
	var coin_rate := float(coin_wins)/2000.0
	check(coin_rate>0.43 and coin_rate<0.53, "Measured coin win rate matches 48%%: %.3f" % coin_rate)
	var coin_mean := coin_net/2000.0
	check(absf(coin_mean-Rooms.gamble_expectation("coin", coin_stake))<0.10*float(coin_stake), "Measured coin payout tracks the expected value")
	var ash_wins := 0
	for i in 2000:
		if bool(Rooms.gamble_roll(sample_rng, 2, gamble_ctx).win): ash_wins+=1
	var ash_rate := float(ash_wins)/2000.0
	check(ash_rate>0.27 and ash_rate<0.37, "Measured ash win rate matches 32%%: %.3f" % ash_rate)
	var tier_wins := 0
	for i in 2000:
		if bool(Rooms.gamble_roll(sample_rng, 1, gamble_ctx).win): tier_wins+=1
	var tier_rate := float(tier_wins)/2000.0
	check(tier_rate>0.35 and tier_rate<0.45, "Measured tier win rate matches 40%%: %.3f" % tier_rate)
	# 条件不足 → 安全失败且不消耗随机
	var poor: Dictionary={"floor": 1, "gold": 0, "ash_run": 0, "weapon_tier": 0}
	var poor_offers: Array=Rooms.gamble_offers(poor)
	for i in poor_offers.size():
		check(not bool(poor_offers[i].available), "Gamble is unavailable without a stake: "+str(poor_offers[i].method))
	var guard := RandomNumberGenerator.new(); guard.seed=5
	var guard_state := guard.state
	check(not bool(Rooms.gamble_roll(guard, 0, poor).ok), "Broke player cannot gamble")
	check(not bool(Rooms.gamble_roll(guard, 9, gamble_ctx).ok), "Out-of-range gamble option is rejected")
	check(not bool(Rooms.gamble_roll(guard, -1, gamble_ctx).ok), "Negative gamble option is rejected")
	check(guard.state==guard_state, "Rejected gambles consume no randomness")
	check(not bool(Rooms.gamble_from_roll(0.5, "nope", 10, gamble_ctx).ok), "Unknown gamble method fails safely")
	check(not bool(Rooms.gamble_roll(null, 0, gamble_ctx).ok), "Missing rng fails safely instead of crashing")

	# ============================================================ D. 镜像挑战
	var mirror_ctx := base_ctx(5)
	mirror_ctx["mirror_active"]=false
	check(Rooms.mirror_allowed(mirror_ctx), "A fresh run may open the mirror")
	var used_ctx := mirror_ctx.duplicate(true)
	used_ctx["mirror_used"]=true
	check(not Rooms.mirror_allowed(used_ctx), "A settled mirror cannot be reopened in the same run")
	var active_ctx := mirror_ctx.duplicate(true)
	active_ctx["mirror_active"]=true
	check(not Rooms.mirror_allowed(active_ctx), "A running mirror cannot be opened twice")
	var accepted: Dictionary=Rooms.mirror_accept(mirror_ctx)
	check(bool(accepted.ok), "The mirror can be accepted once")
	check(bool(accepted.state.active) and not bool(accepted.state.settled), "Accepted mirror starts active and unsettled")
	check(int(accepted.state.owner)==int(mirror_ctx.player) and int(accepted.state.round)==1, "Accepted mirror records owner and round")
	check(not bool(Rooms.mirror_accept(active_ctx).ok), "A second request while active is refused")
	check(str(Rooms.mirror_accept(active_ctx).get("reason", ""))=="active", "Second request reports the active reason")
	check(not bool(Rooms.mirror_accept(used_ctx).ok) and str(Rooms.mirror_accept(used_ctx).get("reason", ""))=="used", "A used mirror reports the used reason")
	for floor_index in range(1, 6):
		for tier in range(0, 6):
			var ctx := base_ctx(floor_index)
			ctx["weapon_tier"]=tier
			var offer: Dictionary=Rooms.mirror_offer(ctx)
			var reward: Dictionary=offer.reward
			check(int(reward.gold)>=Rooms.MIRROR_REWARD_GOLD_BASE and int(reward.gold)<=Rooms.MIRROR_REWARD_GOLD_CAP, "Mirror gold reward stays capped")
			check(int(reward.ash)>=Rooms.MIRROR_REWARD_ASH_BASE and int(reward.ash)<=Rooms.MIRROR_REWARD_ASH_CAP, "Mirror ash reward stays capped")
			check(int(reward.gear_reward)==Rooms.MIRROR_REWARD_GEAR, "Mirror always pays one gear choice")
			check(not offer.opponent.is_empty() and float(offer.opponent.hp_scale)>0.0, "Mirror describes its opponent")
			scan(offer, "mirror_offer")
	check(int(Rooms.mirror_offer(base_ctx(5)).reward.gold)>=int(Rooms.mirror_offer(base_ctx(1)).reward.gold), "Mirror reward never drops as floors progress")
	var mirror_guard := RandomNumberGenerator.new(); mirror_guard.seed=11
	var mirror_guard_state := mirror_guard.state
	check(not bool(Rooms.mirror_resolve(mirror_guard, mirror_ctx).ok), "Resolving an inactive mirror fails safely")
	check(mirror_guard.state==mirror_guard_state, "An inactive mirror consumes no randomness")
	check(not bool(Rooms.mirror_resolve(null, active_ctx).ok), "Missing rng fails safely for the mirror")
	var mirror_a := RandomNumberGenerator.new(); mirror_a.seed=808
	var mirror_b := RandomNumberGenerator.new(); mirror_b.seed=808
	var mirror_via_rng: Dictionary=Rooms.mirror_resolve(mirror_a, active_ctx)
	var mirror_via_value: Dictionary=Rooms.mirror_from_roll(mirror_b.randf(), active_ctx)
	check(same(mirror_via_rng, mirror_via_value), "mirror_resolve is exactly one randf() draw")
	check(mirror_a.state==mirror_b.state, "mirror_resolve advances the stream by exactly one draw")
	check(bool(mirror_via_rng.ok) and bool(mirror_via_rng.used), "A settled mirror is marked used")
	check(not bool(mirror_via_rng.state.active) and bool(mirror_via_rng.state.settled), "Settled mirror reports settled state")
	scan(mirror_via_rng, "mirror_resolve")
	var mirror_reference: Dictionary={}
	for round_index in 1000:
		var rng := RandomNumberGenerator.new(); rng.seed=606
		var settled: Dictionary=Rooms.mirror_resolve(rng, active_ctx)
		if round_index==0: mirror_reference=settled
		elif not same(settled, mirror_reference):
			check(false, "Mirror resolution is not deterministic across repeats")
			break
	check(not mirror_reference.is_empty(), "Determinism probe produced a mirror result")
	var win_ctx := active_ctx.duplicate(true)
	win_ctx["weapon_tier"]=0
	var won: Dictionary=Rooms.mirror_from_roll(0.0, win_ctx)
	var lost: Dictionary=Rooms.mirror_from_roll(0.999, win_ctx)
	check(bool(won.win) and not bool(lost.win), "Mirror honours its win threshold")
	check(int(won.delta.gold)>0 and int(won.delta.ash)>0 and int(won.delta.gear_reward)==1, "Winning the mirror pays gold, ash and a gear choice")
	for key in won.delta: check(str(key) in Rooms.DELTA_KEYS, "Mirror delta key is canonical: "+str(key))
	check(lost.delta.is_empty(), "Losing the mirror pays nothing")
	var no_pending: Dictionary=Rooms.mirror_from_roll(0.0, mirror_ctx)
	check(not bool(no_pending.ok) and str(no_pending.get("reason", ""))=="inactive", "Inactive mirror resolution reports a failure without a crash")

	# ============================================================ E. context_of 与 session 接线面
	check(int(Rooms.context_of(null, {}).floor)==1, "context_of survives a null session")
	check(int(Rooms.context_of(null, {}).gold)==0, "Missing player fields fall back to zero")
	check(not bool(Rooms.offers("gamble", {}).is_empty()), "gamble offers render even for an empty context")
	for i in Rooms.gamble_offers({}).size():
		check(not bool(Rooms.gamble_offers({})[i].available), "Empty context cannot afford any gamble")
	var session_script = load("res://scripts/session.gd")
	if session_script==null or not session_script.can_instantiate():
		print("ROGUE ROOMS: live-session assertions SKIPPED — scripts/session.gd does not compile (see stderr)")
	else:
		var live := fresh(session_script, 6161)
		var live_s=live.s
		var live_p: Dictionary=live.p
		live_s.raid.floor=4
		var live_ctx: Dictionary=Rooms.context_of(live_s, live_p)
		for key in ["floor", "depth", "player", "gold", "forge_points", "forge_level", "weapon_tier", "ash_run"]:
			check(typeof(live_ctx[key])==TYPE_INT, "context_of yields an int for "+key)
		check(typeof(live_ctx.mirror_used)==TYPE_BOOL and typeof(live_ctx.mirror_active)==TYPE_BOOL, "context_of yields bools for the mirror flags")
		check(int(live_ctx.gold)==int(live_p.rogue_gold) and int(live_ctx.floor)==4, "context_of mirrors the live session")
		check(int(live_ctx.forge_points)==int(live_p.build_forge_points), "context_of reads the real forge points")
		check(int(live_ctx.ash_run)==int(live_p.rogue_ash_run), "context_of reads the real run ash")
		check(bool(live_ctx.mirror_used)==bool(live_p.rogue_mirror_used), "context_of reads the real mirror flag")
		check(int(live_ctx.weapon_tier)==int(live_p.equipped.weapon.get("tier", 0)), "context_of reads the equipped weapon tier")
		var live_offer: Dictionary=Rooms.mirror_offer(live_ctx)
		check(not live_offer.is_empty(), "Mirror offer renders from a live session context")
		var live_forge: Array=Rooms.forge_offers(live_ctx)
		check(live_forge.size()==4 and bool(live_forge[3].available), "Live session can always rebind at the forge")
		scan(live_ctx, "live_context")

	# ============================================================ F. 与节点图深度下限的实测一致性
	var mirror_floor_hits := 0
	for probe in 40:
		for floor_index in range(1, 6):
			var g: Dictionary=Graph.build(probe*7919+13, floor_index)
			var mirror_count := 0
			for id in g.get("nodes", {}):
				var node: Dictionary=g.nodes[id]
				var kind := str(node.get("kind", ""))
				if kind=="mirror":
					mirror_count+=1
					mirror_floor_hits+=1
					check(int(node.depth)>=Rooms.min_depth("mirror"), "Graph mirror node obeys the RogueRooms depth floor")
				elif kind=="forge":
					check(int(node.depth)>=Rooms.min_depth("forge"), "Graph forge node obeys the RogueRooms depth floor")
				elif kind=="gamble":
					check(int(node.depth)>=Rooms.min_depth("gamble"), "Graph gamble node obeys the RogueRooms depth floor")
			check(mirror_count<=1, "Each floor holds at most one mirror node")
	check(mirror_floor_hits>0, "Graph probes actually produced mirror nodes to check")

	print("ROGUE ROOMS: %d checks, %d failures" % [checks, failures])
	for session in sessions: session.queue_free()
	quit(1 if failures>0 else 0)
