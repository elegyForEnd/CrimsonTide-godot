extends SceneTree
## 营地入口可视化 + 点击链路：出征栏出现「血潮猎场」，点它传送到新站点，
## 再按 E 走 station_requested → main.show_hunt()。出图 build/hunt-camp.png。
const MainScene = preload("res://scenes/main.tscn")
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
	if DisplayServer.get_name() == "headless":
		print("HUNT CAMP VISUAL: skipped in headless")
		quit()
		return
	root.size = Vector2i(1440, 900)
	var app = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.go_camp()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/hunt-camp.png")
	check(app.camp.station_shortcuts.has("hunt_gate"), "camp shortcut row")
	var shortcut: Button = app.camp.station_shortcuts.get("hunt_gate")
	check(shortcut != null and shortcut.text == "血潮猎场", "shortcut label")
	if shortcut:
		shortcut.emit_signal("pressed")
		await process_frame
		await process_frame
		check(app.page_name == "ground", "shortcut only warps, does not open mode")
		check(app.camp.site.hero_position().distance_to(Vector2(3320, 4240)) < 220.0, "warped to hunt station")
		app.on_camp_station("hunt")
		await process_frame
		await process_frame
		check(app.page_name == "hunt", "E/station opens hunt")
		check(app.hunt_screen.mode == "briefing", "hunt briefing visible")
	print("HUNT CAMP VISUAL: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
