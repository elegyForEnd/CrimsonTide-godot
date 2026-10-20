extends SceneTree
## 集成冒烟：真实 main.tscn 起来后，从营地进入血潮深潜，再回营地。
## 只验证接线与生命周期，不替代窗口出图。
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
	root.size = Vector2i(1440, 900)
	var app = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.go_camp()
	await process_frame
	await process_frame
	check(app.page_name == "ground", "camp page")
	check(app.camp != null, "camp created")
	check(not app.camp.site.station_by_id("hunt_gate").is_empty(), "hunt station exists")
	check(app.camp.station_shortcuts.has("hunt_gate"), "hunt shortcut row exists")
	app.camp.warp_to("hunt_gate")
	check(app.camp.site.hero_position().distance_to(Vector2(3320, 4240)) < 220.0, "hunt warp lands near station")
	app.show_hunt()
	await process_frame
	await process_frame
	check(app.page_name == "hunt", "hunt page")
	check(app.hunt_screen != null, "hunt screen created")
	check(app.hunt_screen.mode == "briefing", "hunt briefing")
	# 随身物：先进深潜口袋，再从仓库消失（带进去就回不来）。
	app.profile.data["hunt_pocket"] = [
		{"kind": "mead", "count": 1}, {"kind": "torch", "count": 1}, {"kind": "key", "count": 1},
	]
	app.profile.save_profile()
	app.hunt_screen.start_run(0)
	await process_frame
	await process_frame
	check(app.hunt_screen.mode == "run", "hunt run")
	check(app.hunt_screen.run != null, "hunt run state")
	check(app.hunt_screen.run.pocket.size() == 3, "the dive loads the pocket")
	var warehouse_before: int = app.profile.warehouse_value()
	app.hunt_screen.run.debug_give("stone", 2)
	app.hunt_screen.run.debug_give("honey", 1)
	# 武器/防具带不出深潜：撤离时按"带不出来的装备"记一笔，不进仓库。
	app.hunt_screen.run.debug_give("stone_axe", 1)
	var bag_before: int = app.hunt_screen.run.bag.size()
	app.hunt_screen.run.finish(true, "集成测试撤离")
	await process_frame
	check(app.hunt_screen.mode == "result", "hunt result")
	check(int(app.profile.data.get("hunt", {}).get("runs", 0)) >= 1, "hunt run recorded")
	check(int(app.profile.data.get("hunt", {}).get("extracts", 0)) >= 1, "hunt extract recorded")
	check(int(app.profile.data.get("hunt", {}).get("wins", 0)) >= 1, "hunt win recorded")
	check(int(app.profile.data.get("hunt", {}).get("best_day", 0)) >= 1, "hunt best day recorded")
	check(app.profile.warehouse_value() > warehouse_before, "extracted loot reached the warehouse")
	check(bag_before >= 4, "loot was carried in the bag")
	var result: Dictionary = app.hunt_screen.last_result
	check((result.get("gear_lost", []) as Array).size() >= 1, "weapons are flagged as un-extractable")
	check(app.profile.hunt_pocket_count() <= 1, "extraction sinks 2-3 pocket pieces")
	var warehouse_has_axe := false
	for item in app.profile.warehouse_items():
		if str(item.get("kind", "")) == "stone_axe":
			warehouse_has_axe = true
	check(not warehouse_has_axe, "hunt weapons never reach the warehouse")
	app.go_camp()
	await process_frame
	check(app.page_name == "ground", "back to camp")
	check(not app.hunt_screen.visible, "hunt hidden after leaving")
	print("HUNT INTEGRATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
