extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-camp-flow.json"
	app.profile.data.coins=400
	app.profile.data.talents=[0,0,0]
	app.profile.data.hero=0
	app.go_camp()
	await process_frame
	check(app.page_name=="ground", "entry opens the camp map")
	app.buy_camp_supply()
	check(app.extra_meds==1 and app.profile.data.coins==375, "supply spends exactly 25 coins")
	check(app.session.players[app.session.my_id()].meds==2, "supply reaches the lobby loadout")
	check(app.camp.supply_status.text.contains("×2"), "supply count updates immediately")
	app.buy_camp_supply()
	app.buy_camp_supply()
	check(app.extra_meds==2 and app.profile.data.coins==350, "full supply cannot spend more coins")
	app.extra_meds=0
	app.profile.data.coins=24
	app.buy_camp_supply()
	check(app.extra_meds==0 and app.profile.data.coins==24, "insufficient funds do not mutate supply")
	app.profile.data.coins=400
	app.on_camp_station("forge")
	check(app.modal and app.camp.input_blocked, "forge blocks camp controls")
	var upgraded := false
	for child in app.overlay.get_children():
		if child is Button and child.text=="升级 · 80 银币":
			child.pressed.emit()
			upgraded=true
			break
	check(upgraded and app.profile.data.talents[0]==1, "forge upgrades the existing talent")
	check(app.profile.data.coins==320, "forge uses the existing talent price")
	check(app.session.players[app.session.my_id()].talents[0]==1, "talent reaches the lobby")
	if DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/camp-forge.png")
	app.close_modal()
	check(not app.camp.input_blocked, "closing the forge restores controls")
	app.show_camp()
	app.profile.data.hero=1
	app.go_camp()
	check(app.camp.site.hero==1 and app.camp.loadout.text.contains(Catalog.HEROES[1].name), "returning from equipment refreshes the hero")
	app.camp.warp_to("forge")
	var station: Dictionary=app.camp.site.station_by_id("forge")
	check(app.camp.pointed_station(app.camp.site.project(station.at+station.offset)).get("id", "")=="forge", "mouse target resolves the pointed facility")
	check(app.camp.pointed_station(Vector2(-9999,-9999)).is_empty(), "empty screen space has no warp target")
	# Model a client lobby; configuration is kept local, with no socket needed.
	app.session.players[2]=app.session.players[1].duplicate(true)
	app.session.players[2].id=2
	app.session.leader_id=2
	app.session.players[1].ready=false
	app.camp.refresh_roster()
	check(app.camp.launch_button.text.contains("准备出发"), "client sees a ready action")
	check(app.camp.site.squad.size()==1, "the local player is excluded by id")
	app.on_camp_launch()
	check(app.session.players[1].ready and not app.session.running, "client readies without launching")
	app.on_camp_launch()
	check(not app.session.players[1].ready, "client can cancel ready")
	app.camp.set_active(false)
	check(app.camp.site.wind_player.stream_paused, "hidden camp pauses ambient audio")
	app.session.players.erase(2)
	app.session.leader_id=1
	app.session.players[1].ready=true
	app.on_camp_launch()
	check(app.session.running and app.page_name=="game", "host departure enters the expedition")
	check(not app.camp.visible, "departure hides the camp")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-camp-flow.json"))
	print("CAMP FLOW: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
