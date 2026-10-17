extends SceneTree
## 猎场页面的 headless 冒烟：只验证脚本能编译、页面能创建、简报与一局能起。
const Screen = preload("res://scripts/hunt/hunt_screen.gd")
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
	print("HUNT UI SMOKE: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
