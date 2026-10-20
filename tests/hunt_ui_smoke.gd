extends SceneTree
## 深潜页面的 headless 冒烟：只验证脚本能编译、页面能创建、简报与一局能起，
## 以及正式美术（背景 / 地图 / 图标 / 敌人 / 立绘 / UI 九宫格）能被解析到。
const Screen = preload("res://scripts/hunt/hunt_screen.gd")
const Art = preload("res://scripts/hunt/hunt_art.gd")
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
	root.size = Vector2i(1440, 900)
	var profile := Profile.new()
	profile.path = "user://hunt-smoke.json"
	var screen = Screen.new()
	root.add_child(screen)
	screen.set_context(profile, null)
	screen.show_briefing()
	await process_frame
	check(screen.visible, "briefing is visible")
	check(screen.mode == "briefing", "briefing mode")
	screen.start_run(0)
	await process_frame
	check(screen.mode == "run", "run mode")
	check(screen.run != null, "run created")
	check(screen.run.hero == 0, "hero selected")
	check(screen.hp_bar != null, "hud built")
	screen._open_map()
	await process_frame
	check(screen.map_overlay.visible, "map opens")
	check(screen.run.paused, "map pauses run")
	screen._close_overlay()
	check(not screen.run.paused, "closing map resumes")
	screen._open_craft()
	await process_frame
	check(screen.craft_overlay.visible, "craft opens")
	screen._close_overlay()
	screen._open_bag()
	await process_frame
	check(screen.bag_overlay.visible, "bag opens")
	screen._close_overlay()
	screen.run.tick(1.0)
	await process_frame
	# 正式素材接入：缺任何一类都应该在冒烟里就红，而不是出图时才看出来。
	check(Art.background("old_town", "night") != null, "painted old-town night background")
	check(Art.background("altar", "dusk") != null, "painted altar dusk background")
	check(Art.map_texture() != null, "parchment region map")
	check(Art.has_hunt_icon("branch") and Art.has_hunt_icon("hand_cannon"), "item icon table")
	check(Art.icon("branch") != Art.icon("stone"), "item icons are distinct")
	check(Art.enemy_texture("apostle") != null, "apostle enemy frame")
	check(Art.portrait_texture(3, "angry") != null, "hidden hero expression portrait")
	check(Art.crop_texture("panel.png") != null and Art.crop_texture("toast.png") != null, "ui nine-slice crops")
	check(Art.button_style(false, "normal") != null and Art.button_style(true, "pressed") != null, "ui button styles")
	check(Art.hotspot_texture("locked") != null, "hotspot ring art")
	check(Art.event_texture("reliquary") != null and Art.event_texture("blood_clock") != null, "event illustrations")
	check(Art.event_texture("missing") == null, "missing event art falls back to text only")
	# 2026-10-20：搜索仪式与两种时停解密的素材。
	check(Art.search_probe() != null, "search ritual probe art")
	check(Art.puzzle_dial() != null, "three-ring rune dial art")
	check(Art.puzzle_seal("success") != null and Art.puzzle_seal("fail") != null, "puzzle success and failure seals")
	check(Art.search_probe() != Art.puzzle_dial(), "search art and puzzle art are distinct")
	print("HUNT UI SMOKE: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
