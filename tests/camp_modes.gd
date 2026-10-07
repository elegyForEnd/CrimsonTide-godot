extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-camp-modes.json"
	app.profile.data.coins=200
	app.go_camp()
	await process_frame
	var camp=app.camp
	var a: Dictionary=camp.site.station_by_id("gate")
	var b: Dictionary=camp.site.station_by_id("rogue_gate")
	check(a.action=="launch" and b.action=="rogue","two entrances have separate modes")
	check(a.at.distance_to(b.at)>1000,"entrances are spatially separated")
	camp.warp_to("rogue_gate")
	check(camp.site.is_walkable(camp.site.hero_position()),"rogue portal is reachable")
	if DisplayServer.get_name()!="headless":
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/camp-rogue-entrance.png")
	camp.interact()
	check(app.page_name=="rogue_setup" and app.session.selected_mode=="roguelike","walking to portal opens rogue preparation")
	app.rogue_cards=2
	app.rogue_weapon=1
	app.start_rogue()
	check(app.session.running and app.session.roguelike.active(app.session),"camp portal starts rogue")
	# 原文 `players[1].weapon==1`：装备武器后 `p.weapon` 是 Content 域（`WEAPON_BASE+index` = 600+i），
	# 不再是 Catalog 索引；用稳定的 `build_id` 表达同一意图（配置买的那把真的进了这一局）。
	# `rogue_rerolls==2` 现在真的成立：`Build.reset()` 不再把调用方配置的刷新卡覆盖成 3。
	check(app.session.players[1].rogue_rerolls==2 and str(app.session.players[1].equipped.get("weapon",{}).get("build_id",""))=="W001","purchased kit reaches run")
	check(app.profile.data.coins==100,"confirmed purchases charged once on start")
	app.session.players[1].status="extracted"
	app.session.roguelike.settle(app.session)
	app.session.request_camp()
	check(app.page_name=="ground" and camp.visible,"results return to shared walking camp")
	camp.warp_to("gate")
	camp.interact()
	check(app.session.running and not app.session.roguelike.active(app.session),"other gate starts extraction after rogue")
	check(app.profile.data.coins>=100,"extraction does not repeat rogue purchase charge")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-camp-modes.json"))
	print("CAMP MODES: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
