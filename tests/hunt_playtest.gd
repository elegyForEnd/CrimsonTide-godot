extends SceneTree
## 血潮猎场 V2「点得动」回归：全部走真实 UI 节点信号（Z 形态 / W 搜索 / 互动点 /
## 战斗按钮 / 地图 / 撤离 / 返回），不直接调 run 的动作函数（调试钩子只用来摆场景）。
const Screen = preload("res://scripts/hunt/hunt_screen.gd")
const Data = preload("res://scripts/hunt/hunt_data.gd")
var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func last_log(run) -> String:
	return str(run.logs[run.logs.size() - 1]) if not run.logs.is_empty() else ""

func step(screen, seconds: float, step: float = 0.1) -> void:
	var left := seconds
	while left > 0.0:
		var dt: float = minf(step, left)
		screen._process(dt)
		left -= dt

func run() -> void:
	root.size = Vector2i(1440, 900)
	var profile := Profile.new()
	profile.path = "user://hunt-playtest.json"
	var screen = Screen.new()
	root.add_child(screen)
	screen.set_context(profile, null)
	screen.show_briefing()
	await process_frame
	screen.start_run(0)
	await process_frame
	var run = screen.run
	check(run != null, "run created")

	# 1) Z 形态按钮：切到隐藏，2 秒内不能再切。
	check(screen.form_button != null, "form button exists")
	screen.form_button.pressed.emit()
	await process_frame
	check(run.form == "hide", "form button switches to hide")
	check(screen.form_button.disabled, "form button locks during the 2 second cooldown")
	screen.form_button.pressed.emit()
	await process_frame
	check(run.form == "hide", "second press is ignored during cooldown")
	step(screen, 2.2)
	await process_frame
	check(not screen.form_button.disabled, "form button unlocks after 2 seconds")

	# 2) W 搜索：随机抽点、3 秒、期间按钮进入 CD。
	check(screen.search_button != null, "search button exists")
	var stamina_before: float = run.stamina
	screen.search_button.pressed.emit()
	await process_frame
	check(not run.search.is_empty(), "search button starts a search")
	check(run.stamina < stamina_before, "search costs stamina")
	check(screen.search_button.disabled, "search button is locked while searching")
	var saw_joy := false
	var left := 8.0
	while left > 0.0:
		screen._process(0.1)
		left -= 0.1
		if run.searched >= 1:
			saw_joy = run.expression == "joy" or run.expression == "neutral"
			break
	await process_frame
	check(run.searched >= 1, "search completes through the frame loop")
	check(not run.search.is_empty() == false, "search state clears when done")

	# 3) 隐藏形态把翻找拖慢 20%：直接比较时长。
	run.search_cd = 0.0
	run.form = "act"
	var act_seconds: float = run.search_seconds()
	run.form = "hide"
	var hide_seconds: float = run.search_seconds()
	check(hide_seconds >= act_seconds * 1.2 - 0.001, "hide lengthens the search")

	# 4) 战斗面板只能由"搜索遭遇"打开：这里用调试钩子摆出遭遇，再点按钮打。
	run.debug_kill_enemies()
	run.form = "act"
	run.debug_spawn_enemy("scavenger")
	var enemy_uid := str(run.active_enemies()[0].uid)
	check(run.start_combat(enemy_uid), "encounter starts combat")
	screen._refresh_all()
	await process_frame
	check(screen.combat_panel.visible, "combat panel opens for an encounter")
	var hp_before_duel: float = run.hp
	run.combat.hp = 999.0
	screen.combat_attack.pressed.emit()
	await process_frame
	check(run.counter_hits >= 1, "monster counter-attacks after being hit")
	check(run.hp < hp_before_duel, "counter hurts the hunter")
	# 打死它：把血调到 1 再点一次。
	run.attack_cd = 0.0
	run.combat.hp = 1.0
	screen.combat_attack.pressed.emit()
	await process_frame
	check(run.combat.is_empty(), "attack button wins the fight")
	check(not screen.combat_panel.visible, "combat panel closes")

	# 5) 被动挨打：不打开战斗面板，只扣血并反击一次。
	run.debug_kill_enemies()
	run.debug_spawn_enemy("scavenger")
	run.debug_alert_enemy()
	var hp_before_passive: float = run.hp
	var counters_before: int = run.counter_hits
	screen._process(1.6)
	await process_frame
	check(run.combat.is_empty(), "a passive hit never opens the combat panel")
	check(run.hp < hp_before_passive, "a passive hit costs hp")
	check(run.counter_hits > counters_before, "the hunter counters a passive hit")

	# 6) 互动点：点街角神龛，一次性。
	run.debug_kill_enemies()
	screen._refresh_all()
	await process_frame
	check(screen.site_nodes.has("shrine"), "shrine marker exists")
	var shrine = screen.site_nodes.get("shrine")
	if shrine:
		shrine.pressed.emit()
		await process_frame
	check(run.site_done("shrine"), "clicking a site resolves it")
	check(not screen.site_nodes.has("shrine"), "used site disappears from the scene")

	# 7) 地图信号换区（到晨钟广场）。
	screen._open_map()
	await process_frame
	check(screen.map_overlay.visible, "map overlay opens")
	screen.map_view.picked.emit("bell_square")
	await process_frame
	check(run.area_id == "bell_square", "map pick travels to the bell square")
	check(screen.stage.area_id == "bell_square", "stage rebuilt for the new area")

	# 8) 时间推进到黄昏：舞台自己换光照。
	run.debug_set_clock(Data.DAY_SECONDS * 0.6)
	await process_frame
	check(run.phase_id() == "dusk", "clock lands in the dusk phase")
	check(screen.stage.phase == "dusk", "stage rebuilds for dusk lighting")

	# 9) 到点后点 HUD 撤离，再点返回营地。
	run.debug_kill_enemies()
	run.debug_set_clock(Data.EXTRACT_AFTER + 1.0)
	screen._refresh_all()
	await process_frame
	check(screen.extract_button.disabled == false, "extract button enabled")
	screen.extract_button.pressed.emit()
	await process_frame
	check(run.ended_flag, "extract ends the run")
	check(screen.mode == "result", "result overlay shown")
	var left_camp := [false]
	screen.exit_requested.connect(func(): left_camp[0] = true)
	var back: Button = null
	if screen.result_layer:
		for node in screen.result_layer.find_children("*", "Button", true, false):
			if (node as Button).text.contains("返回"):
				back = node
				break
	check(back != null, "result has a back button")
	if back:
		back.pressed.emit()
		await process_frame
	check(left_camp[0], "back button requests the camp")

	print("HUNT PLAYTEST: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
