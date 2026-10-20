extends SceneTree
## 血潮深潜可视化回归：真实窗口渲染，出图到 build/hunt-*.png。
## 断言只守"页面能开、面板能开、不崩"；画面细节靠出图肉眼验收。
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

func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		check(false, "no frame texture")
		return
	image.save_png("res://build/hunt-%s.png" % name)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("HUNT VISUAL: skipped in headless")
		quit()
		return
	root.size = Vector2i(1440, 900)
	var profile := Profile.new()
	profile.path = "user://hunt-visual.json"
	var screen = Screen.new()
	root.add_child(screen)
	screen.set_context(profile, null)
	screen.show_briefing()
	await shot("01-briefing")
	check(screen.mode == "briefing", "briefing mode")
	screen.start_run(0)
	await process_frame
	screen.run.note("找到：松脂、硫磺。")
	await shot("02-run")
	check(screen.mode == "run", "run mode")
	check(screen.run != null and screen.run.hero == 0, "run started")
	# Raw stage shot: temporarily hide the HUD/vignette so a dark overlay cannot be
	# mistaken for missing 3D props during art review.
	screen.hud.visible = false
	screen.vignette.visible = false
	screen.hotspot_layer.visible = false
	await shot("02b-raw-stage")
	screen.hud.visible = true
	screen.vignette.visible = true
	screen.hotspot_layer.visible = true
	if screen.stage and screen.stage.root:
		print("STAGE area=", screen.stage.area_id, " phase=", screen.stage.phase, " children=", screen.stage.root.get_child_count())
		for child in screen.stage.root.get_children():
			print("  STAGE CHILD ", child.name, " ", child.get_class())
	if screen.stage_view:
		var direct: Image = screen.stage_view.get_texture().get_image()
		if direct:
			direct.save_png("res://build/hunt-stage-direct.png")
	screen._open_map()
	await shot("03-map")
	check(screen.map_overlay.visible, "map visible")
	screen._close_overlay()
	screen._open_craft()
	await shot("04-craft")
	check(screen.craft_overlay.visible, "craft visible")
	screen._close_overlay()
	screen._open_bag()
	await shot("05-bag")
	check(screen.bag_overlay.visible, "bag visible")
	screen._close_overlay()
	# 随身物面板（空袋也要能开）。
	screen._open_overlay("pocket")
	await shot("05a-pocket")
	check(screen.pocket_overlay.visible, "pocket overlay visible")
	screen._close_overlay()
	# 随机事件互动窗：黑箱问号点 → 中等窗口 + 物件插图 + 选项耗时。
	var event_uid: String = screen.run.debug_spawn_event("cellar_door")
	screen.run.begin_event(event_uid)
	screen._open_event_window()
	await shot("05b-event")
	check(screen.event_open, "event window visible")
	check(screen.event_art.texture != null, "event illustration loaded")
	if not screen.event_option_buttons.is_empty():
		screen.event_option_buttons[0].pressed.emit()
		await shot("05c-event-action")
		check(not screen.run.event_action().is_empty(), "event action is running in real time")
		screen.run.tick(4.2)
		screen._refresh_all()
		await shot("05c2-event-step")
		check(str(screen.run.event_state.get("step", "")) == "shape", "event advanced a step after the action")
	screen._close_event_window()
	# 时停解密：三环血纹锁与记忆符文各来一张，验收按钮/符文盘/机会文本的位置。
	screen.run.debug_clear_events()
	var dial_uid: String = screen.run.debug_spawn_event("sealed_vault")
	screen.run.begin_event(dial_uid)
	var dial_at := -1
	for i in screen.run.event_options().size():
		if "铜环" in str(screen.run.event_options()[i].get("label", "")):
			dial_at = i
	if dial_at >= 0:
		screen.run.event_choose(dial_at)
		screen._open_event_window()
		await shot("05d-puzzle-dial")
		check(screen.run.puzzle_active(), "dial puzzle visible")
	screen._close_event_window()
	screen.run.debug_clear_events()
	var seq_uid: String = screen.run.debug_spawn_event("stopped_clock")
	screen.run.begin_event(seq_uid)
	var seq_at := -1
	for i in screen.run.event_options().size():
		if "敲击" in str(screen.run.event_options()[i].get("label", "")):
			seq_at = i
	if seq_at >= 0:
		screen.run.event_choose(seq_at)
		screen._open_event_window()
		await shot("05e-puzzle-sequence")
		check(screen.run.puzzle_active(), "sequence puzzle visible")
	screen._close_event_window()
	# 搜索仪式：中央探针 + 血环 + 进度环。
	screen.run.search_cd = 0.0
	screen.run.start_search()
	screen._process(1.1)
	await shot("05f-search")
	check(screen.search_fx.visible, "search ritual visible")
	screen.run.cancel_search("出图用")
	screen._process(0.2)
	# Force an encounter in the current area for the combat panel.
	screen.run.debug_kill_enemies()
	screen.run.debug_spawn_enemy("scavenger")
	var enemies: Array = screen.run.active_enemies()
	if not enemies.is_empty():
		screen.run.start_combat(str(enemies[0].uid))
		screen._refresh_all()
		await shot("06-combat")
		check(screen.combat_panel.visible, "combat panel visible")
	# Result overlay (victory path).
	screen.run.finish(true, "出图验收")
	await shot("07-result")
	check(screen.result_layer != null, "result layer built")
	# Night lighting pass: hide the result card, then rebuild the stage at night.
	if screen.result_layer:
		screen.result_layer.visible = false
	screen._build_stage("catacombs", "night")
	await shot("08-night")
	check(screen.stage.phase == "night", "night stage")
	# Dusk pass for the golden-hour grading.
	screen._build_stage("black_pines", "dusk")
	await shot("08b-dusk")
	check(screen.stage.phase == "dusk", "dusk stage")
	# Every area gets its own box-garden build; shoot all eight for art review.
	for id in ["old_town", "black_pines", "hospital", "docks", "institute", "catacombs", "bell_square", "altar"]:
		screen._build_stage(id, "day")
		await shot("theme-" + id)
		check(screen.stage.area_id == id, "box garden built: " + id)
	# 隐藏角色（墓煜）的正式 8 表情立绘：放到最后单独起一局，避免新 run 的
	# _refresh_all 把上面手动搭的舞台又拽回它自己的地区。
	screen.start_run(3)
	await process_frame
	screen.run.note("墓煜：冥火已备。")
	await shot("09-hero3")
	check(screen.run.hero == 3, "hidden hero run starts")
	check(screen.portrait != null and screen.portrait.hero == 3, "hidden hero portrait bound")
	print("HUNT VISUAL: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
