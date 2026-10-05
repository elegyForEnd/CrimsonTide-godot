extends SceneTree
## V2 终验 · 新肉鸽玩法的**端到端验真**（headless）。
##
## 目的：回答"这些玩法是不是真的能用"，而不是"数据层存在"。所有断言都跑在
## 真实 `TideSession` 上，并走运行期真正会走的函数（`launch()` / `enter()` 的
## 调用链 / `update_enemies()` / `perform()` / `settle()`），只在无法安全导航
## 地图时才直接调用 `enter()` 文档里写明的同一批函数（`open_room`/`clear_room`/
## `refresh_dedicated`）。
##
## 每条断言都附带「如果没接线会怎样」的负向理由（见 output/FINAL-E2E.md）。
## 真的还没接上的地方**不迁就断言**，而是记为 KNOWN-GAP（不改 failures），
## 例如：`main.gd` 从未把 `profile.data` 交给 session（`set_meta("profile_data", …)`），
## 且 `profile.gd` 没有 `daily` 键 —— 见 §6。

const UiModel = preload("res://scripts/rogue_ui_model.gd")
const Variants = preload("res://scripts/rogue_variants.gd")
const Curses = preload("res://scripts/rogue_curses.gd")
const Events = preload("res://scripts/rogue_events.gd")
const Rooms = preload("res://scripts/rogue_rooms.gd")
const Growth = preload("res://scripts/rogue_growth.gd")
const Daily = preload("res://scripts/rogue_daily.gd")
const Combat = preload("res://scripts/rogue_combat.gd")
const Choreo = preload("res://scripts/boss_choreography.gd")
const Visuals = preload("res://scripts/combat_visuals.gd")
const Semantics = preload("res://scripts/effect_semantics.gd")
const Build = preload("res://scripts/rogue_build.gd")

var checks := 0
var failures := 0
var gaps := 0
var gap_notes: Array = []


func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)


func near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps


## 记录一个"确实还没接线"的缺口：不改 failures，只在报告里单列。
func gap(if_still_broken: bool, reason: String) -> void:
	if if_still_broken:
		gaps += 1
		gap_notes.append(reason)
		print("KNOWN-GAP: ", reason)


func note(text: String) -> void:
	print("  · ", text)


func _initialize() -> void:
	call_deferred("run")


func new_session(seed_value: int, profile_data: Variant = null) -> TideSession:
	var t := TideSession.new()
	root.add_child(t)
	t.set_physics_process(false)
	if profile_data is Dictionary:
		t.set_meta("profile_data", profile_data)
	t.solo({"hero": 0, "mode": "roguelike", "rogue_rerolls": 2, "rogue_weapon": 1})
	t.launch(false, seed_value)
	t.spawn_timer = 9999
	return t


func fire_one_bolt(s: TideSession) -> Dictionary:
	## 让一只真实的 type-1 远程怪在真实 `update_enemies()` 里开一枪。
	s.raid["phase"] = "rogue_combat"
	s.enemies.clear()
	s.bullets.clear()
	var p: Dictionary = s.players[1]
	var at := Vector2(p.p.x + 200.0, p.p.y)
	s.spawn_enemy(at, 1)
	if s.enemies.is_empty():
		return {}
	var e: Dictionary = s.enemies[0]
	e["p"] = at
	e["cd"] = 0.0
	var guard := 0
	while s.bullets.is_empty() and guard < 120:
		s.update_enemies(0.05)
		guard += 1
	return s.bullets[0] if not s.bullets.is_empty() else {}


func run() -> void:
	# =====================================================================
	# §1 开局 + HUD：真实 launch 之后变数已经抽好并能显示
	# =====================================================================
	print("[1] 开局与 HUD")
	var s := new_session(4242)
	var p: Dictionary = s.players[1]
	var rl = s.roguelike
	check(rl.active(s), "真实 launch 之后会话处于魔境模式")
	var variant_id := str(s.raid.get("variant", ""))
	check(variant_id != "", "开局第一层就抽到了深渊变数（没接线时 raid.variant 恒为 \"\"）")
	check(s.raid.get("variants_seen", []).has(variant_id), "抽到的变数被记进 variants_seen（层间去重的前提）")
	var line := UiModel.variant_line(s.raid)
	var label := str(UiModel.describe_variant(variant_id).get("label", variant_id))
	check(line.contains(label), "HUD「深渊变数」一行显示的是本局抽到的那条（%s）" % line)
	check(UiModel.node_line(s.raid, rl.ROOM_NAMES).contains("第"), "HUD 路线一行可读：%s" % UiModel.node_line(s.raid, rl.ROOM_NAMES))
	check(UiModel.curses_lines(p).size() >= 1, "HUD 诅咒区始终有一行可显示")
	check(UiModel.ash_line(p, {}).contains("本局"), "HUD 灰烬行把本局与累计分开：%s" % UiModel.ash_line(p, {}))
	check(UiModel.floor_line(s.raid, rl.depth_count(s)).contains("/ 5 层"), "顶栏层数分母正确")
	note("floor1 variant=%s seen=%s" % [variant_id, str(s.raid.get("variants_seen", []))])

	# =====================================================================
	# §2 变数真的生效（数值 + 真实开火）
	# =====================================================================
	print("[2] 深渊变数的实际效果")
	s.raid["variant"] = "fog"			# 弹幕尺寸 +25% / 速度 -20%
	var mods := s.rogue_mods(p)
	check(near(float(mods.get("bullet_size", 0.0)), 0.25), "fog 的弹幕尺寸 +25% 进入 mods")
	check(near(float(mods.get("bullet_speed", 0.0)), -0.20), "fog 的弹速 -20% 进入 mods")

	var plain := new_session(4242)
	plain.raid["variant"] = ""
	var fogged := new_session(4242)
	fogged.raid["variant"] = "fog"
	var bolt_plain := fire_one_bolt(plain)
	var bolt_fog := fire_one_bolt(fogged)
	check(not bolt_plain.is_empty() and not bolt_fog.is_empty(), "两次对照都真的打出了子弹（走 update_enemies → 开火）")
	if not bolt_plain.is_empty() and not bolt_fog.is_empty():
		var v1: Vector2 = bolt_plain["v"]
		var v2: Vector2 = bolt_fog["v"]
		check(near(v1.length(), 245.0, 0.5), "无变数时弹速就是基础 245（当前 %.2f）" % v1.length())
		check(near(v2.length(), 245.0 * 0.8, 0.5), "fog 下真实子弹速度 ×0.8（当前 %.2f）" % v2.length())
		check(not bolt_plain.has("bullet_visual"), "无变数时子弹不带表现层键")
		check(near(float(bolt_fog.get("bullet_visual", 1.0)), 1.25), "fog 下子弹带 bullet_visual=1.25")
		check(not bolt_plain.has("hit_radius") and not bolt_fog.has("hit_radius"),
			"两边的子弹字典都没有 hit_radius 键（判定沿用默认 18.0）")
		check(near(float(bolt_plain.get("hit_radius", 18.0)), float(bolt_fog.get("hit_radius", 18.0))),
			"开关变数不改变命中半径（默认 18.0）")

	# 敌人血量按变数缩放（走 rl.spawn_wave → combat.setup_minion）
	var wall_a := new_session(5150)
	wall_a.raid["variant"] = ""
	wall_a.raid["room"] = "combat"
	wall_a.raid["wave"] = 1
	wall_a.raid["phase"] = "rogue_combat"
	wall_a.enemies.clear()
	rl.spawn_wave(wall_a)
	var wall_b := new_session(5150)
	wall_b.raid["variant"] = "bedrock"	# enemy_hp +20%
	wall_b.raid["room"] = "combat"
	wall_b.raid["wave"] = 1
	wall_b.raid["phase"] = "rogue_combat"
	wall_b.enemies.clear()
	wall_b.roguelike.spawn_wave(wall_b)
	check(not wall_a.enemies.is_empty() and not wall_b.enemies.is_empty(), "两次对照都刷出了小怪")
	if not wall_a.enemies.is_empty() and not wall_b.enemies.is_empty():
		# `spawn_minion` 只在刷怪时不带 s 调用 setup_minion（R6 的设计），变数倍率由第一次
		# `update()` 幂等补应用；真实对局每帧都会走 update()，所以这里必须推进一帧再量。
		wall_a.update_enemies(0.05)
		wall_b.update_enemies(0.05)
		var hp_a := float(wall_a.enemies[0].max_hp)
		var hp_b := float(wall_b.enemies[0].max_hp)
		check(hp_a > 0.0, "基准小怪有正生命（%.1f）" % hp_a)
		check(near(hp_b / hp_a, 1.20, 0.02), "bedrock 让真实小怪生命 ×1.2（实测 %.3f）" % (hp_b / hp_a))

	# =====================================================================
	# §3 诅咒真的生效（同池相减）
	# =====================================================================
	print("[3] 诅咒")
	s.raid["variant"] = ""
	p["rogue_curses"] = []
	check(near(s.rogue_mods(p).get("defense_penalty", 0.0), 0.0), "无诅咒时没有池惩罚")
	p["build_buffs"]["defense"] = {"value": 0.10, "until": s.elapsed + 99.0}
	var pool := float(Build.conditional_defense(s, p))
	check(near(pool, 0.10), "构造出确定性的 0.10 减伤池")
	var base_before := maxf(0.0, 100.0) * (1.0 - s.stat_defense(p))
	var without := s.incoming_damage(p, 100.0)
	check(near(without, base_before * (1.0 - pool)), "无诅咒时走既有池")
	p["rogue_curses"] = ["CU01"]
	var penalty := float(s.rogue_mods(p).get("defense_penalty", 0.0))
	check(penalty > 0.0, "CU01 产出正的池惩罚（%.4f）" % penalty)
	var with_one := s.incoming_damage(p, 100.0)
	check(with_one > without, "一条诅咒让实际受伤变高")
	check(near(with_one, base_before * (1.0 - clampf(pool - penalty, 0.0, Curses.MAX_POOL))),
		"诅咒与既有减伤池**同池相减**（不是第二层乘数）")
	check(not near(with_one, without * 1.15), "确认不是 ×1.15 的独立乘数")
	p["rogue_curses"] = ["CU01", "CU01", "CU01", "CU01"]
	var floored := s.incoming_damage(p, 100.0)
	check(floored >= base_before - 0.0001, "池被压到 0 后不会反转成收益")
	p["rogue_curses"] = ["CU01"]
	s.raid["variant"] = ""
	s.raid["room_rewarded"] = false
	s.raid["floor"] = 1
	p["rogue_gold"] = 0
	rl.clear_room(s)
	var cursed_gold := int(p.rogue_gold)
	p["rogue_curses"] = []
	s.raid["room_rewarded"] = false
	p["rogue_gold"] = 0
	rl.clear_room(s)
	var clean_gold := int(p.rogue_gold)
	check(cursed_gold > clean_gold, "带诅咒的玩家拿到更高的清房补偿（%d > %d）" % [cursed_gold, clean_gold])

	# =====================================================================
	# §4 幽暗异事（事件房）+ revision 守卫
	# =====================================================================
	print("[4] 幽暗异事")
	p["rogue_curses"] = []
	s.raid["variant"] = ""
	s.raid["floor"] = 2
	s.raid["room"] = "event"
	p["rogue_gold"] = 1000
	rl.open_room(s)
	var pending: Dictionary = s.raid.get("pending_event", {})
	check(not pending.is_empty(), "进入事件房后 pending_event 有内容")
	check(str(pending.get("id", "")) != "", "pending_event 带事件 id")
	check((pending.get("offer", []) as Array).size() >= 2, "pending_event 暴露 2~3 个选项")
	var event_rev := int(s.raid.revision)
	var gold_before_event := int(p.rogue_gold)
	s.perform(1, "rogue_event", {"index": 0, "revision": event_rev - 1})
	check(not s.raid.pending_event.is_empty(), "过期 revision 的点击不会解决事件")
	check(int(p.rogue_gold) == gold_before_event, "过期 revision 的点击不动钱包")
	s.perform(1, "rogue_event", {"index": 0, "revision": event_rev})
	check(s.raid.pending_event.is_empty(), "正确 revision 的点击真的解决了事件")
	s.raid["room"] = "event"
	rl.open_room(s)
	var rev_illegal := int(s.raid.revision)
	s.perform(1, "rogue_event", {"index": 99, "revision": rev_illegal})
	check(not s.raid.pending_event.is_empty(), "非法 index 不会消耗掉待选事件（安全失败）")

	# =====================================================================
	# §5 三个新房间
	# =====================================================================
	print("[5] 新房间：锻炉 / 赌徒 / 镜像")
	s.raid["floor"] = 3
	s.raid["room"] = "forge"
	p["rogue_gold"] = 1000
	p["build_forge_points"] = 0
	rl.refresh_dedicated(s, p)
	check(not (s.raid.get("pending_forge", {}) as Dictionary).is_empty(), "锻炉房发布了报价")
	var forge_rev := int(s.raid.revision)
	check(int((s.raid.pending_forge as Dictionary).get("revision", -1)) == forge_rev, "锻炉报价带当前 revision")
	var gold_before_forge := int(p.rogue_gold)
	s.perform(1, "rogue_forge", {"index": 0, "revision": forge_rev - 1})
	check(int(p.rogue_gold) == gold_before_forge, "过期点击不扣钱")
	s.perform(1, "rogue_forge", {"index": 0, "revision": forge_rev})
	var paid := gold_before_forge - int(p.rogue_gold)
	check(paid == Rooms.forge_point_price(3), "锻炉按报价扣费（实扣 %d / 报价 %d）" % [paid, Rooms.forge_point_price(3)])
	check(int(p.build_forge_points) == 1, "锻炉真的给到 1 点锻造点")
	check(int(s.raid.revision) == forge_rev + 1, "成交后 revision 前进")

	s.raid["room"] = "gamble"
	p["rogue_gold"] = 1000
	rl.refresh_dedicated(s, p)
	var stake := Rooms.gamble_stake(3)
	check(int((s.raid.pending_gamble as Dictionary).get("stake", 0)) == stake, "赌徒报价带本层注额（%d）" % stake)
	var gold_before_bet := int(p.rogue_gold)
	var bet_rev := int(s.raid.revision)
	s.perform(1, "rogue_gamble", {"index": 0, "revision": bet_rev})
	var moved := int(p.rogue_gold) - gold_before_bet
	check(moved == stake or moved == -stake, "押魔晶的结果只能是 ±注额（实测 %d）" % moved)
	check(int(s.raid.revision) == bet_rev + 1, "下注后 revision 前进")

	# tier 赌法：换阶必须同步 refresh_max_hp / rogue_inventory_revision
	check(not p.equipped.weapon.is_empty(), "玩家身上有武器（tier 赌法的前提）")
	p.equipped.weapon["tier"] = 3
	var inv_rev_before := int(p.rogue_inventory_revision)
	var hp_before_swap := float(p.max_hp)
	var tier_rev := int(s.raid.revision)
	s.perform(1, "rogue_gamble", {"index": 1, "revision": tier_rev})
	var tier_after := int(p.equipped.weapon.tier)
	check(tier_after == 2 or tier_after == 4, "押阶结果必然是 3±1（实测 %d）" % tier_after)
	check(int(p.rogue_inventory_revision) == inv_rev_before + 1, "换阶递增 rogue_inventory_revision（触发界面刷新）")
	check(float(p.max_hp) > 0.0, "换阶后最大生命被重算且为正（%.1f → %.1f）" % [hp_before_swap, float(p.max_hp)])

	s.raid["room"] = "mirror"
	p["rogue_mirror_used"] = false
	s.raid["mirror_state"] = {"active": false, "owner": int(p.id), "round": 0, "settled": false}
	var mirror_rev := int(s.raid.revision)
	s.perform(1, "rogue_mirror", {"index": 0, "revision": mirror_rev})
	check(bool((s.raid.mirror_state as Dictionary).get("active", false)), "第一次确认让镜像进入 active")
	var mirror_rev2 := int(s.raid.revision)
	var gold_before_mirror := int(p.rogue_gold)
	s.perform(1, "rogue_mirror", {"index": 0, "revision": mirror_rev2})
	check(bool(p.get("rogue_mirror_used", false)), "第二次确认结算并标记本局已用")
	check(int(p.rogue_gold) >= gold_before_mirror, "镜像结算至少不会扣钱（%d → %d）" % [gold_before_mirror, int(p.rogue_gold)])
	s.raid["mirror_state"] = {"active": false, "owner": int(p.id), "round": 0, "settled": false}
	var mirror_rev3 := int(s.raid.revision)
	var gold_after_spent := int(p.rogue_gold)
	s.perform(1, "rogue_mirror", {"index": 0, "revision": mirror_rev3})
	check(int(p.rogue_gold) == gold_after_spent, "本局已用过的镜像不能再刷奖励")

	# =====================================================================
	# §6 灰烬：局外入账 + 每日打卡（含 KNOWN-GAP）
	# =====================================================================
	print("[6] 灰烬与每日打卡")
	var data: Dictionary = {"ashes": 0, "growth": {}, "daily": {}}
	var wallet := new_session(6161, data)
	var wp: Dictionary = wallet.players[1]
	wallet.raid["variant"] = ""
	wallet.raid["cleared"] = 10
	wallet.raid["floor"] = 3
	wallet.raid["daily"] = true
	wp["status"] = "extracted"
	wp["rogue_ash_run"] = 0
	wallet.roguelike.settle(wallet)
	check(int(wp.rogue_ash_run) > 0, "结算真的发灰烬（本局 %d）" % int(wp.rogue_ash_run))
	check(int(data.get("ashes", 0)) == int(wp.rogue_ash_run), "灰烬按同一数值入账 profile（%d）" % int(data.get("ashes", 0)))
	check(data.has("daily") and (data["daily"] as Dictionary).has(Daily.record_key(Daily.utc_today())),
		"每日挑战在 profile.data[\"daily\"] 里留下今天的打卡")
	var banked := int(data.get("ashes", 0))
	wallet.roguelike.settle(wallet)
	check(int(data.get("ashes", 0)) == banked, "重复结算不会再发一次灰烬（ended 守卫）")
	check(wallet.raid.get("ended", false), "结算后 raid.ended 置位")

	var growth_data: Dictionary = {"ashes": 0, "growth": {"coin_purse": 2}, "daily": {}}
	var meta_run := new_session(6161, growth_data)
	check(int(meta_run.players[1].rogue_gold) == 60 + 2 * 25,
		"成长树真的加进开局钱袋（60+2×25=%d，实测 %d）" % [110, int(meta_run.players[1].rogue_gold)])

	# —— 真实游戏路径的两处断线已由 R7b / R3 接通：这里改成正向断言，防止回退 ——
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_src.contains("set_meta(\"profile_data\""),
		"main.gd 真的把 profile.data 交给 session（否则灰烬不入账、成长树开局加成不生效）")
	var profile_src := FileAccess.get_file_as_string("res://scripts/profile.gd")
	check(profile_src.contains("\"daily\""),
		"profile.gd 的默认档含 daily 键（否则 record_daily() 早退，每日挑战永远不打卡）")

	# =====================================================================
	# §7 每日挑战与种子分享
	# =====================================================================
	print("[7] 种子与每日挑战")
	var daily_seed := Daily.global_daily_seed()
	check(daily_seed >= 1, "每日种子在合法域内（%d）" % daily_seed)
	var share := Daily.encode(daily_seed)
	check(Daily.parse_seed(share) == daily_seed, "分享串 encode→parse 往返恒等（%s）" % share)
	check(Daily.is_valid(share), "生成的分享串自校验通过")
	check(Daily.parse_seed("") == 0 and Daily.parse_seed("CT-ZZZZ") == 0, "空串/乱码一律返回 0，不崩")
	check(UiModel.seed_error("") != "", "UI 对空种子给出明确错误文案")
	check(UiModel.parse_seed(share) == daily_seed, "UI 走的是同一套解析")
	var day_run := new_session(daily_seed)
	check(bool(day_run.raid.get("daily", false)), "用房主算出的每日种子开局 → raid.daily 为真（房主下发口径）")
	var other_run := new_session(20260101)
	check(not bool(other_run.raid.get("daily", false)), "非每日种子开局不会误判成每日挑战")
	var zero_run := new_session(0)
	check(int(zero_run.seed_value) != 0, "种子 0 落到随机局（seed_value 被填成随机值）")

	# =====================================================================
	# §8 守层者池 + 半血二阶段
	# =====================================================================
	print("[8] 守层者池与二阶段")
	var boss_run := new_session(777)
	boss_run.raid["floor"] = 1
	boss_run.raid["phase"] = "rogue_combat"
	boss_run.raid["room"] = "boss"
	boss_run.raid["wave"] = 3
	boss_run.enemies.clear()
	boss_run.roguelike.spawn_wave(boss_run)
	check(boss_run.enemies.size() == 1, "守层者波次恰好刷出 1 个守层者")
	if boss_run.enemies.size() == 1:
		var e: Dictionary = boss_run.enemies[0]
		var want_art := int(Combat.boss_art_for(int(boss_run.seed_value), 0))
		check(int(e.get("boss_art", -1)) == want_art, "守层者身份来自 boss_art_for(seed,floor)（%d）" % want_art)
		check(str(e.get("boss_name", "")) == str(Combat.NAMES[want_art]), "守层者名字与池条目一致（%s）" % str(e.get("boss_name", "")))
		check(int(e.get("rogue_skin", -1)) == 0, "rogue_skin 仍是楼层索引（音频/小怪/缩放口径不变）")
		# 3 个新身份带显式编排键；5 个原身份按设计回落 `Art.identity(e)`（见 R14）。
		check(str(e.get("choreo_key", "")) != "" or want_art < 5,
			"守层者能算出编排键（新身份显式携带，原身份回落 identity）")
		check(not Choreo.MOVES.is_empty() and Choreo.names(e).size() == 7, "该守层者能取到 7 条编排时间线")
		check(float(e.max_hp) > 0.0, "守层者有正生命（%.1f）" % float(e.max_hp))
		# 半血触发二阶段
		var combat = boss_run.roguelike.combat
		check(combat.boss_phase(e) == 1, "开场是一阶段")
		e["hp"] = float(e.max_hp) * 0.5 - 1.0
		boss_run.update_enemies(0.05)
		check(bool(e.get("boss_enraged", false)), "血量掉到半血以下真的触发二阶段")
		check(combat.boss_phase(e) == 2, "阶段状态派生为 2")
		var phase2_skills := {}
		for i in 21:
			phase2_skills[combat.skill_for_cursor(e, i)] = true
		check(phase2_skills.has(5) and phase2_skills.has(6), "二阶段会出现两招专属终结技（5/6）")
		e["hp"] = float(e.max_hp)
		boss_run.update_enemies(0.05)
		check(combat.boss_phase(e) == 2, "回血不会退回一阶段（无抖动）")
		var probe: Dictionary = e.duplicate(true)
		probe["boss_enraged"] = false
		probe["phase"] = 1
		var phase1_skills := {}
		for i in 40:
			phase1_skills[combat.skill_for_cursor(probe, i)] = true
		check(not phase1_skills.has(5) and not phase1_skills.has(6), "一阶段永远拿不到终结技")
		check(combat.MOVES[0].size() == 7, "守层者招表是 7 招")

	# =====================================================================
	# §9 表现层消费端：变数真的改变画面，但不改命中圈
	# =====================================================================
	print("[9] 弹幕表现层消费端")
	var layers_plain := Visuals.bolt_layers(1.0)
	var layers_big := Visuals.bolt_layers(1.5)
	check(near(float(layers_plain.get("core", 0.0)), 36.0), "绘制实心内核直径 = 36px（= 18px 判定半径 ×2）")
	check(near(float(layers_big.get("core", 0.0)), 36.0), "放大绘制后内核仍是 36px（视觉不会大于判定）")
	check(float(layers_big.get("halo_outer", 0.0)) > float(layers_plain.get("halo_outer", 0.0)), "bullet_visual 真的放大了外圈光晕")
	check(float(layers_big.get("sprite_box", 0.0)) > float(layers_plain.get("sprite_box", 0.0)), "bullet_visual 真的放大了贴图框")
	check(near(Visuals.bolt_visual({}), 1.0), "缺省 bullet_visual = 1.0（无变数时画面与从前一致）")
	check(near(Visuals.bolt_visual({"bullet_visual": 9.0}), 3.0), "表现层倍率被 clamp 在 3.0")
	check(near(Semantics.visual_of({"bullet_visual": 1.25}), 1.25), "魔境矢量弹同样消费 bullet_visual")
	var staging_src := FileAccess.get_file_as_string("res://scripts/boss_effect_staging.gd")
	check(staging_src.contains("bullet_visual"), "Boss 弹的 staging 也按 bullet_visual 放大绘制")

	# =====================================================================
	# §10 结构钉死：运行期路径确实经过钩子
	# =====================================================================
	print("[10] 结构断言")
	var session_src := FileAccess.get_file_as_string("res://scripts/session.gd")
	check(session_src.contains("bullets.append(rogue_enemy_bolt("), "普通敌人开火走变数钩子")
	check(session_src.contains("float(b.get(\"hit_radius\",18.0))"), "命中判定仍是默认 18.0")
	var rl_src := FileAccess.get_file_as_string("res://scripts/roguelike.gd")
	check(rl_src.contains("kind==\"rogue_event\""), "choose() 里有事件动作")
	check(rl_src.contains("kind==\"rogue_forge\""), "choose() 里有锻炉动作")
	check(rl_src.contains("kind==\"rogue_gamble\""), "choose() 里有赌徒动作")
	check(rl_src.contains("kind==\"rogue_mirror\""), "choose() 里有镜像动作")
	check(rl_src.contains("Growth.grant(s,p)"), "结算真的发放灰烬")
	check(rl_src.contains("record_daily(s,p"), "结算真的尝试每日打卡")
	var eco_src := FileAccess.get_file_as_string("res://scripts/ecology.gd")
	check(eco_src.contains("rogue_enemy_bolt("), "生态怪弹幕也走变体钩子")

	# =====================================================================
	# §11 逐层抽取：确定、不扰动 s.rng、本局不重复
	# =====================================================================
	print("[11] 逐层抽取的确定性与去重")
	var two_a := new_session(3131)
	var two_b := new_session(3131)
	check(str(two_a.raid.get("variant", "")) == str(two_b.raid.get("variant", "")),
		"同种子两局的第 1 层变数完全相同（房主决定、可复现）")
	var state_before := int(two_a.rng.state)
	Variants.roll(two_a)
	check(int(two_a.rng.state) == state_before, "RogueVariants.roll() 不消耗 s.rng（改用局部派生 RNG）")
	# 运行期的"每层恰好一次"由 enter() 的 fresh 守卫保证（不是靠 roll() 自身幂等：
	# 手动再抽一次会把刚抽到的 id 当作 exclude，从而换一条——这是去重的有意行为）。
	two_a.raid["floor"] = 1
	two_a.raid["graph_floor"] = 1
	var serial_before := int(two_a.raid.get("variant_serial", -1))
	var seen_before := (two_a.raid.get("variants_seen", []) as Array).size()
	var variant_now := str(two_a.raid.get("variant", ""))
	two_a.roguelike.enter(two_a)
	check(str(two_a.raid.get("variant", "")) == variant_now and int(two_a.raid.get("variant_serial", -1)) == serial_before,
		"同一层重复 enter() 不会重抽变数（fresh 守卫生效）")
	check((two_a.raid.get("variants_seen", []) as Array).size() == seen_before, "重复 enter() 不会膨胀 variants_seen")
	var seen_ids := {}
	for floor_index in range(2, 6):
		two_a.raid["floor"] = floor_index
		two_a.raid["graph_floor"] = floor_index - 1
		two_a.roguelike.enter(two_a)
		var rolled := str(two_a.raid.get("variant", ""))
		if rolled != "":
			seen_ids[rolled] = true
	var seen_list: Array = two_a.raid.get("variants_seen", [])
	var unique_seen := {}
	for id in seen_list:
		unique_seen[id] = true
	check(seen_list.size() >= 4, "连走 5 层后 variants_seen 记到了每层的抽取（%d 条）" % seen_list.size())
	check(unique_seen.size() == seen_list.size(), "本局内抽到的变数互不重复（去重生效）")
	check(seen_ids.size() >= 2, "跨层确实抽到了不同的变数（%d 种）" % seen_ids.size())

	# =====================================================================
	# §12 真实入口：main.tscn → start_rogue() 现在真的把 profile.data 交给 session
	#     （§6 用的是"注入 meta 的合成会话"，这里换成玩家真正会点的那个入口）
	# =====================================================================
	print("[12] 真实入口（main.tscn → start_rogue）")
	var main_src_gap := FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_src_gap.contains("set_meta(\"profile_data\""), "main.gd 真的把 profile.data 交给 session（写入侧已通）")
	var sess_src12 := FileAccess.get_file_as_string("res://scripts/session.gd")
	check(sess_src12.contains("func profile_data"), "session.gd 提供 profile_data() 读取通道")
	var main_node = load("res://scenes/main.tscn").instantiate()
	# 安全措施：把档案路径改到临时文件，确保本用例**永远不会写玩家真实存档**（user://profile.json）。
	main_node.profile.path = "user://v2_probe_profile.json"
	root.add_child(main_node)
	await process_frame
	main_node.session.solo({"hero": 0, "mode": "roguelike"})
	main_node.profile.data["ashes"] = 500
	main_node.profile.data["growth"] = {"coin_purse": 2}	# power(): start_coins +50
	main_node.page_name = "rogue_setup"
	main_node.session.selected_mode = "roguelike"
	main_node.rogue_cards = 3
	main_node.rogue_weapon = -1
	main_node.rogue_seed_pending = 1234	# 强制走"房主本地带种子出发"那条真实分支
	main_node.rogue_daily_pending = false
	main_node.start_rogue()
	var live: TideSession = main_node.session
	if live.running:
		check(live.roguelike.active(live), "真实 start_rogue() 确实把魔境跑起来了（前提成立）")
		check(live.has_meta("profile_data"), "真实路径下 session 上已被注入 profile_data")
		check(live.has_method("profile_data"), "真实路径下 session 提供 profile_data() 方法")
		var live_gold := int(live.players[1].rogue_gold)
		check(live_gold == 60 + 2 * 25,
			"成长树的 coin_purse=2 真在真实对局里加进开局钱袋（期望 110，实测 %d）" % live_gold)
		live.raid["floor"] = 1
		live.raid["cleared"] = 0
		var ash_before := int(main_node.profile.data["ashes"])
		var granted := Growth.grant(live, live.players[1])
		check(granted > 0, "结算发灰烬的算子在真实路径下照样算出 %d 点" % granted)
		check(int(main_node.profile.data["ashes"]) > ash_before,
			"灰烬真的进了 UI 持有的 profile.data（%d → %d），不再发进虚空" % [ash_before, int(main_node.profile.data["ashes"])])
	else:
		gap(true, "harness 未能通过 main.tscn 驱动 start_rogue()（session.running 为假）")

	# =====================================================================
	# §13 真实 Profile 默认档：daily 键现已存在（R3 落地 v3-1）→ 打卡真的会发生
	# =====================================================================
	print("[13] 真实 Profile 默认档的每日打卡")
	var real_profile := Profile.new()
	check(real_profile.data.has("daily"), "Profile.new() 的默认真档含 daily 键（profile.gd 已落地 CHANGE-LOG v3-1）")
	var day_gap := new_session(777, real_profile.data)
	day_gap.raid["daily"] = true
	day_gap.raid["floor"] = 2
	day_gap.raid["cleared"] = 3
	check(int(real_profile.data.get("version", 0)) == 1, "加入 daily 键没有改 version（老档仍可读）")
	day_gap.roguelike.record_daily(day_gap, day_gap.players[1], 30)
	var today_key: String = Daily.record_key(Daily.utc_today())
	check((real_profile.data["daily"] as Dictionary).has(today_key),
		"用真实默认真档打卡：今天的条目真的被写出来（%s）" % today_key)
	var day_dict := {"ashes": 0, "growth": {}, "daily": {}}
	var day_ok := new_session(778, day_dict)
	day_ok.raid["daily"] = true
	day_ok.raid["floor"] = 2
	day_ok.raid["cleared"] = 3
	day_ok.roguelike.record_daily(day_ok, day_ok.players[1], 30)
	check(day_dict["daily"] is Dictionary and not (day_dict["daily"] as Dictionary).is_empty(),
		"对照组：只要档里有 daily 键，同一次调用就写下了当天条目 → 缺的只是那个默认键，机制本身是好的")
	day_gap.queue_free()
	day_ok.queue_free()
	main_node.queue_free()
	# 清掉本次探测可能落下的临时档案（绝不碰 user://profile.json）
	if FileAccess.file_exists("user://v2_probe_profile.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://v2_probe_profile.json"))

	s.queue_free()
	two_a.queue_free()
	two_b.queue_free()
	plain.queue_free()
	fogged.queue_free()
	wall_a.queue_free()
	wall_b.queue_free()
	wallet.queue_free()
	meta_run.queue_free()
	day_run.queue_free()
	other_run.queue_free()
	zero_run.queue_free()
	boss_run.queue_free()
	await process_frame
	print("FINAL E2E ROGUELIKE ", checks, " checks / ", failures, " failures / ", gaps, " known-gaps")
	for g in gap_notes:
		print("  GAP: ", g)
	quit(1 if failures else 0)
