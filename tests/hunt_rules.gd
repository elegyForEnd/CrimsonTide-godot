extends SceneTree
## 血潮深潜规则层回归：不建 3D、不开窗口，只跑纯逻辑。
const Data = preload("res://scripts/hunt/hunt_data.gd")
const Run = preload("res://scripts/hunt/hunt_run.gd")

var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Data.AREAS.size() >= 8, "at least eight areas")
	check(Data.RECIPES.size() >= 30, "at least thirty recipes")
	check(Data.ENEMIES.size() >= 4, "at least four enemy kinds")
	check(Data.EVENTS.size() >= 30, "at least thirty random events")
	check(Data.EVENT_SPAWNS.size() >= 8, "every area has event spawn points")
	for kind in Data.ITEMS:
		check(Catalog.ITEMS.has(kind), "Catalog has hunt item: " + kind)
	check(Data.DAY_SECONDS == 480.0, "eight minute day")
	check(Data.DAYS == 3, "three day run")
	check(Data.area("old_town").get("neighbors", []).has("bell_square"), "old town connects to square")
	check(Data.recipe("stone_axe").get("out", "") == "stone_axe", "stone axe recipe")
	# 深潜物品进搜打撤：尺寸按价值分档、稀有度只做白/绿/蓝。
	check(Catalog.is_hunt_loot("iron") and not Catalog.is_hunt_loot("scrap"), "catalog marks hunt loot")
	check(Catalog.hunt_loot_size("branch") == Vector2i(1, 1), "cheap hunt loot takes one cell")
	check(Catalog.hunt_loot_size("hand_cannon") == Vector2i(2, 2), "expensive hunt loot takes a 2x2 block")
	check(Catalog.hunt_loot_size("machete") == Vector2i(2, 1), "mid-value hunt loot takes two cells")
	check(Catalog.item_size({"kind": "hand_cannon"}) == Vector2i(2, 2), "item_size derives from value")
	check(not Catalog.hunt_exportable("stone_axe") and not Catalog.hunt_exportable("cloth_armor"), "gear cannot leave the dive")
	check(Catalog.hunt_exportable("iron") and Catalog.hunt_exportable("herbal_bandage"), "ordinary loot can leave the dive")
	check(Data.weapon("stone_axe").get("damage", 0) > 0, "stone axe has damage")

	var run = Run.new()
	run.setup(0, 12345, -1, [0, 0, 0])
	check(run.day == 1 and run.area_id == "old_town", "starts day one in old town")
	check(run.hp > 0 and run.stamina == 100.0, "starts with hp and stamina")
	check(run.item_count("bandage") == 1, "starts with one bandage")
	check(run.hotspot_uses("car") == 3, "car has three searches")
	run.debug_give("branch", 2)
	run.debug_give("stone", 2)
	run.debug_give("rope", 2)
	check(run.craft("stone_axe"), "craft stone axe")
	check(run.item_count("stone_axe") == 1, "stone axe in bag")
	check(run.equip("stone_axe"), "equip stone axe")
	check(run.weapon_kind() == "stone_axe", "wielding stone axe")
	check(run.attack_power() > run.base_attack, "weapon raises attack")
	var before := run.hotspot_uses("car")
	check(run.start_search("car"), "start search")
	run.tick(9.0)
	check(run.hotspot_uses("car") == before - 1, "search consumes a use")
	check(run.searched >= 1, "search counted")
	check(run.bag.size() > 0, "search yields loot")
	# Travel and day rollover.
	check(run.travel("bell_square"), "travel to bell square")
	check(run.area_id == "bell_square", "arrived at bell square")
	run.debug_kill_enemies()
	run.debug_set_clock(Data.DAY_SECONDS - 0.1)
	run.tick(0.2)
	check(run.day == 2, "day advances at the 8 minute mark")
	check(run.clock < 1.0, "clock resets for day two")
	check(run.area_enemies.size() == Data.AREAS.size(), "enemy tables rebuilt")
	# Extraction is available at the square after four minutes.
	run.debug_set_clock(Data.EXTRACT_AFTER + 1.0)
	check(run.can_extract(), "extraction opens at the square")
	var captured: Array = []
	run.finished.connect(func(result): captured.append(result))
	check(run.extract(), "extract")
	check(not captured.is_empty(), "result emitted")
	var result: Dictionary = captured[0] if not captured.is_empty() else {}
	check(bool(result.get("victory", false)), "extraction is a victory")
	check(bool(result.get("extracted", false)), "extraction banks loot")
	check(int(result.get("day", 0)) == 2, "result records the day")

	# Death path: no banking, no victory.
	var dead = Run.new()
	dead.setup(1, 999, -1, [0, 0, 0])
	dead.debug_set_clock(Data.EXTRACT_AFTER + 1.0)
	dead.area_id = "bell_square"
	dead.hp = 1.0
	dead.start_combat(str(dead.active_enemies()[0].uid))
	for i in 20:
		dead.tick(1.0)
		if dead.ended_flag:
			break
	check(dead.ended_flag, "combat can kill the hunter")
	check(not dead.hp > 0.0, "death leaves no hp")

	# Locked containers need a key or a lockpick, and consume it on open.
	var locked = Run.new()
	locked.setup(2, 7, -1, [0, 0, 0])
	check(locked.travel("hospital"), "travel to hospital")
	check(locked.is_locked("cabinet"), "hospital cabinet is locked")
	var spots_without_key := locked.available_spots().size()
	check(not locked.start_search("cabinet"), "search refused without a key")
	locked.debug_give("key", 1)
	check(locked.start_search("cabinet"), "key opens the cabinet")
	check(locked.item_count("key") == 0, "key consumed on open")
	check(locked.available_spots().size() >= spots_without_key, "locked spots join the pool after unlocking")
	locked.tick(12.0)
	check(locked.hotspot_uses("cabinet") == 1, "locked search spent one use")

	# Bag capacity: a full bag refuses new stacks but still allows stacking.
	var full = Run.new()
	full.setup(0, 21, -1, [0, 0, 0])
	full.capacity = full.bag.size()
	check(full.bag_space() == 0, "bag reports no free slot")
	check(not full.add_item("stone", 1), "full bag refuses a new item")
	check(full.add_item("bandage", 1), "full bag still merges a stack")

	# Bandage heals through use_item().
	var healer = Run.new()
	healer.setup(0, 31, -1, [0, 0, 0])
	healer.hp = 20.0
	var bandage_slot := -1
	for i in healer.bag.size():
		if str(healer.bag[i].kind) == "bandage":
			bandage_slot = i
	check(bandage_slot >= 0, "bandage starts in the bag")
	check(healer.use_item(bandage_slot), "bandage can be used")
	check(healer.hp > 20.0, "bandage restores hp")

	# Crafting fails cleanly when materials are missing.
	var poor = Run.new()
	poor.setup(0, 41, -1, [0, 0, 0])
	var poor_bag: int = poor.bag.size()
	check(not poor.craft("machete"), "craft fails without materials")
	check(poor.bag.size() == poor_bag, "failed craft does not fill the bag")

	# Surviving to the end of day three is a win.
	var survivor = Run.new()
	survivor.setup(0, 51, -1, [0, 0, 0])
	survivor.day = Data.DAYS
	survivor.debug_kill_enemies()
	survivor.debug_set_clock(Data.DAY_SECONDS - 0.1)
	var survived: Array = []
	survivor.finished.connect(func(result): survived.append(result))
	survivor.tick(0.2)
	check(survivor.ended_flag, "third night ends the run")
	check(not survived.is_empty() and bool(survived[0].get("victory", false)), "surviving three days wins")

	# Boss kill ends the run with the boss reason.
	var boss_run = Run.new()
	boss_run.setup(0, 61, -1, [0, 0, 0])
	boss_run.debug_kill_enemies()
	boss_run.debug_spawn_enemy("apostle")
	var boss_enemies: Array = boss_run.active_enemies()
	check(not boss_enemies.is_empty() and bool(boss_enemies[0].get("boss", false)), "apostle is a boss")
	var boss_result: Array = []
	boss_run.finished.connect(func(result): boss_result.append(result))
	if not boss_enemies.is_empty():
		check(boss_run.start_combat(str(boss_enemies[0].uid)), "boss combat starts")
		boss_run.combat.hp = 1.0
		boss_run.attack()
		check(boss_run.ended_flag, "boss kill ends the run")
		check(not boss_result.is_empty() and bool(boss_result[0].get("victory", false)), "boss kill is a victory")
		check(not boss_result.is_empty() and str(boss_result[0].get("reason", "")).contains("使徒"), "boss reason recorded")

	# ---------------------------------------------------------------- V2 形态
	var act = Run.new()
	act.setup(0, 71, -1, [0, 0, 0])
	check(act.form == "act", "starts in act form")
	check(act.toggle_form(), "toggle to hide")
	check(act.form == "hide", "form is hide")
	check(not act.toggle_form(), "2 second switch cooldown blocks the second toggle")
	act.tick(2.1)
	check(act.toggle_form(), "toggle works again after the cooldown")
	# 隐藏形态：伤害 ×0.6 向下取整。
	var dmg_act := Run.new()
	dmg_act.setup(0, 72, -1, [0, 0, 0])
	dmg_act.rng.seed = 909
	var plain: float = dmg_act._player_damage(1.0)
	dmg_act.rng.seed = 909
	dmg_act.toggle_form()
	var hidden: float = dmg_act._player_damage(1.0)
	check(hidden <= floorf(plain * 0.6) + 0.001, "hide damage is floored to 60%")
	check(hidden >= floorf(plain * 0.6) - 1.001, "hide damage is close to 60%")
	# 隐藏形态：行动 CD 变长 20%。
	check(dmg_act.attack_rate() >= 0.9 * 1.2 - 0.001, "hide lengthens the attack cooldown")

	# ---------------------------------------------------------------- V2 搜索
	var search_run = Run.new()
	search_run.setup(0, 73, -1, [0, 0, 0])
	check(search_run.start_search(), "W search starts without a target")
	check(not search_run.search.is_empty(), "search is running")
	search_run.tick(1.0)
	check(not search_run.search.is_empty(), "search is longer than one second")
	search_run.tick(3.0)
	check(search_run.search.is_empty(), "search completes after about three seconds")
	check(search_run.searched == 1, "search counted once")
	# 搜空之后同一地区没有可搜点，W 会拒绝。
	for spot in search_run.hotspots():
		search_run.uses["%s:%s" % [search_run.area_id, str(spot.id)]] = 0
	check(not bool(search_run.can_search().ok), "empty area refuses W search")

	# 条件搜索点：没面具时黑松林空心巨木不可搜，拿到面具后可搜。
	var gate = Run.new()
	gate.setup(0, 74, -1, [0, 0, 0])
	gate.area_id = "black_pines"
	gate._refresh_area_enemies()
	var before_spots := gate.available_spots().size()
	check(before_spots == 3, "torch spot is locked without a torch")
	gate.flags.torch = true
	check(gate.available_spots().size() == before_spots + 1, "torch unlocks the dark hollow")

	# 区域解锁：祭坛需要血契石（第 3 天也不够）。
	var unlock = Run.new()
	unlock.setup(0, 75, -1, [0, 0, 0])
	unlock.day = 3
	unlock.area_id = "catacombs"
	unlock._refresh_area_enemies()
	check(not unlock.travel("altar"), "altar refuses without the blood sigil")
	unlock.debug_give("blood_sigil", 1)
	check(unlock.travel("altar"), "blood sigil opens the altar")

	# ---------------------------------------------------------------- V2 反击
	var duel = Run.new()
	duel.setup(0, 76, -1, [0, 0, 0])
	duel.debug_kill_enemies()
	duel.debug_spawn_enemy("guard")
	duel.start_combat(str(duel.active_enemies()[0].uid))
	duel.combat.hp = 999.0
	var hp_before_duel: float = duel.hp
	var counters_before: int = duel.counter_hits
	duel.rng.seed = 7
	duel.attack()
	check(duel.counter_hits == counters_before + 1, "attacking a monster triggers one counter")
	check(duel.hp < hp_before_duel, "the monster counter hurts the hunter")

	# 被偷袭：怪物不打开战斗面板，只扣血；角色还手一次。
	var ambushed = Run.new()
	ambushed.setup(0, 77, -1, [0, 0, 0])
	ambushed.debug_kill_enemies()
	ambushed.debug_spawn_enemy("scavenger")
	var prey: Dictionary = ambushed.active_enemies()[0]
	prey.alert = true
	prey.next = 0.0
	var hp_before_ambush: float = ambushed.hp
	ambushed.tick(0.1)
	check(ambushed.combat.is_empty(), "a passive hit never opens the combat panel")
	check(ambushed.hp <= hp_before_ambush, "a passive hit deals damage")
	check(ambushed.counter_hits >= 1, "the hunter counters a passive hit")
	check(float(prey.hp) < float(prey.max_hp), "the passive attacker takes counter damage")

	# 隐藏形态几乎不会被主动攻击：同一个怪 60 秒内不会察觉。
	var sneak = Run.new()
	sneak.setup(0, 78, -1, [0, 0, 0])
	sneak.debug_kill_enemies()
	sneak.debug_spawn_enemy("hound")
	sneak.toggle_form()
	sneak.tick(60.0)
	check(not bool(sneak.active_enemies()[0].alert), "hide keeps a monster from noticing")
	var loud = Run.new()
	loud.setup(0, 79, -1, [0, 0, 0])
	loud.debug_kill_enemies()
	loud.debug_spawn_enemy("hound")
	loud.tick(60.0)
	check(bool(loud.active_enemies()[0].alert), "act form gets noticed within a minute")

	# ---------------------------------------------------------------- 随机事件
	var ev_run = Run.new()
	ev_run.setup(0, 91, -1, [0, 0, 0])
	check(ev_run.events_here().size() >= 2, "each area seeds at least two event markers")
	for marker in ev_run.events_here():
		check(not marker.has("name") and not marker.has("desc"), "markers are black boxes before interaction")
	# 同一个种子 + 同一天，事件点完全一致；换一个种子就换一套。
	var ev_twin = Run.new()
	ev_twin.setup(0, 91, -1, [0, 0, 0])
	var ids_a: Array = []
	var ids_b: Array = []
	for marker in ev_run.events_here():
		ids_a.append(str(marker.id))
	for marker in ev_twin.events_here():
		ids_b.append(str(marker.id))
	check(ids_a == ids_b, "the run seed reproduces the same event set")
	var ev_other = Run.new()
	ev_other.setup(0, 92, -1, [0, 0, 0])
	var ids_c: Array = []
	for marker in ev_other.events_here():
		ids_c.append(str(marker.id))
	check(ids_a != ids_c or ev_run.events_here().is_empty(), "a different seed can roll a different set")
	# 互动窗口：默认暂停；选项消耗局内时间；名字点开才揭示。
	var uid := ev_run.debug_spawn_event("cellar_door")
	check(not uid.is_empty(), "debug event spawns in the current area")
	check(ev_run.begin_event(uid), "clicking an event opens the interaction")
	check(ev_run.paused, "the interaction pauses the run by default")
	check(str(ev_run.event_state.get("name", "")) == "地窖铁门", "the event title is revealed after opening")
	var clock_before: float = ev_run.clock
	check(ev_run.event_choose(0), "the first option resolves")
	check(ev_run.clock > clock_before, "event actions consume in-game time")
	check(str(ev_run.event_state.get("step", "")) == "shape", "the interaction advances a step")
	# 需要道具的分支：没有铁片/钉子时点不动，而且只说人话。
	var bag_before_ev: int = ev_run.bag.size()
	check(not ev_run.event_choose(0), "an item-gated action refuses without the item")
	check(ev_run.bag.size() == bag_before_ev, "a refused action changes nothing")
	ev_run.close_event()
	check(ev_run.event_state.is_empty() and not ev_run.paused, "closing the interaction resumes the run")
	# 奖励：进入带 reward 的步骤时按稀有度入包。
	var gift_run = Run.new()
	gift_run.setup(0, 93, -1, [0, 0, 0])
	var gift_uid := gift_run.debug_spawn_event("blood_sigil_site")
	var bag_before_gift: int = gift_run.bag.size()
	check(gift_run.begin_event(gift_uid), "sigil event opens")
	gift_run.event_choose(1)
	check(gift_run.bag.size() > bag_before_gift, "event rewards land in the bag")
	var tiered := false
	for entry in gift_run.bag:
		if entry.has("tier"):
			tiered = true
	check(tiered, "event rewards carry a rarity tier")
	gift_run.close_event()
	# live 事件不暂停：窗口开着的时候时间照走。
	var live_run = Run.new()
	live_run.setup(0, 94, -1, [0, 0, 0])
	var live_uid := live_run.debug_spawn_event("gas_corridor")
	check(live_run.begin_event(live_uid), "live event opens")
	check(not live_run.paused, "a live event never pauses the run")
	live_run.close_event()

	# ---------------------------------------------------------------- 随身物
	var pocket_run = Run.new()
	pocket_run.setup(0, 96, -1, [0, 0, 0], [{"kind": "mead", "count": 1}, {"kind": "torch", "count": 1}])
	check(pocket_run.pocket.size() == 2, "the pocket seeds from the profile")
	pocket_run.stamina = 10.0
	check(pocket_run.pocket_use(0), "a pocket item can be used in the dive")
	check(pocket_run.stamina > 10.0, "pocket mead restores stamina")
	check(pocket_run.pocket.size() == 1, "a used pocket pile leaves the pocket")
	check(pocket_run.pocket_use(0), "pocket torch lights up")
	check(bool(pocket_run.flags.torch), "pocket torch sets the torch flag")
	# 搜索战利品也带稀有度。
	var rarity_run = Run.new()
	rarity_run.setup(0, 97, -1, [0, 0, 0])
	rarity_run.start_search("car")
	rarity_run.tick(9.0)
	var any_tier := false
	for entry in rarity_run.bag:
		if entry.has("tier"):
			any_tier = true
	check(any_tier, "searched loot carries a rarity tier")

	print("HUNT RULES: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
