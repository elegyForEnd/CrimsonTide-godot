extends SceneTree
var failures := 0
func check(ok: bool, reason: String) -> void:
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://economy-ui-test.json"
	app.profile.data=Profile.new().data.duplicate(true)
	app.profile.sanitize_storage()
	for kind in ["relic","medicine","charm","scrap","ammo","amulet","frostbone_king_remains","wind_chime","thorn_crown","mirror_thread","dawn_testament","moon_core"]:
		app.profile.data.warehouse.append({"kind":kind,"x":0,"y":0})
	app.profile.data.warehouse.append(Catalog.make_equipment("weapon",2,5))
	app.session.solo(app.config())
	app.show_economy(false)
	await process_frame
	var screen: Control=app.overlay.get_child(app.overlay.get_child_count()-1)
	check(screen.grid.get_child_count()==13,"Warehouse renders saved stock")
	screen.focused=12
	screen.refresh()
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/warehouse.png")
	screen.withdraw(false)
	check(app.profile.data.bags[0].items.size()==1,"Warehouse UI withdraws selected equipment")
	app.show_economy(true)
	await process_frame
	screen=app.overlay.get_child(app.overlay.get_child_count()-1)
	screen.query="护身符"
	screen.refresh()
	check(screen.visible_indices().size()==1,"Search filters by Chinese item name")
	screen.selected=screen.visible_indices()
	screen.focused=screen.selected[0]
	screen.refresh()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/market.png")
	var initial: int=app.profile.data.coins
	screen.sell()
	check(app.profile.data.coins==initial,"First sale click requires confirmation")
	screen.sell()
	check(app.profile.data.coins==initial+666,"Confirmation sells item at displayed value")
	check(screen.visible_indices().is_empty(),"Sold stock leaves the UI")
	app.close_modal()
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var player: Dictionary=app.session.players[1]
	player.status="extracted"
	app.session.settle()
	check(app.profile.data.bags[0].items.is_empty(),"Actual settlement empties carried stock into the warehouse")
	var stock: int=app.profile.data.warehouse.size()
	var coins: int=app.profile.data.coins
	app.on_finished()
	check(app.profile.data.warehouse.size()==stock and app.profile.data.coins==coins,"Opening the report twice cannot duplicate money or loot")
	check(app.session.players[1].backpack.items.is_empty(),"Lobby configuration no longer contains banked loot")
	DirAccess.remove_absolute(app.profile.path)
	app.queue_free()
	await process_frame
	print("ECONOMY UI: ",failures," failures")
	quit(1 if failures else 0)
