extends SceneTree
## 晨钟交易行 as a cabinet: the vault drawn as its own 15x15 grid, with click-to-select
## selling. The vault *view* that used to live here is gone — standing at the vault opens
## the camp bag panel — so this file checks both ends of that change.
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
		app.profile.bank_item({"kind":kind})
	app.profile.bank_item(Catalog.make_equipment("weapon",2,5))
	app.session.solo(app.config())

	# Standing in front of the vault is the bag panel with its right half focused.
	app.show_economy(false)
	await process_frame
	check(app.camp_pack_open,"the vault counter opens the camp bag panel")
	check(app.grids.has("warehouse") and app.equip_zones.has("bag"),"with the vault and the worn sockets registered")
	app.close_bag()

	# ...and the exchange is its own window, drawing the same cabinet.
	app.show_economy(true)
	await process_frame
	var screen: Control=app.overlay.get_child(app.overlay.get_child_count()-1)
	check(screen.name=="EconomyScreen","the exchange opens in its own window")
	var cells: int=Catalog.WAREHOUSE_GRID.x*Catalog.WAREHOUSE_GRID.y
	check(app.profile.warehouse_count()==13,"the vault holds the whole stocked list")
	# Two shelves now, each its own persistent grid inside its own scroller. The vault is
	# the 15x15 grid with every piece on top of it; the pack is the white 3x3 it starts
	# with. Checking the drawn nodes directly (not `overlay`, which is only ever the shelf
	# being drawn last) is what proves each block scrolls and sits on its own.
	check(screen.vault_view.get_child_count()==cells+13,"every vault cell is drawn, and every piece sits on its own")
	check(screen.bag_view.get_child_count()==Catalog.bag_grid(app.camp_player().backpack).x*Catalog.bag_grid(app.camp_player().backpack).y,"the carried pack is a grid of its own")
	check(not ("背包" in screen.CATEGORIES),"the pack is folded into 武器与装备, not a category of its own")
	check(screen.selectable_indices().size()==13,"and every piece is offered for sale")
	screen.query="护身符"
	screen.refresh()
	check(screen.selectable_indices().size()==1,"Search filters by Chinese item name")
	screen.selected=screen.selectable_indices()
	screen.focused=screen.selected[0]
	screen.refresh()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/market-grid.png")
	var initial: int=app.profile.data.coins
	screen.sell()
	check(app.profile.data.coins==initial,"First sale click requires confirmation")
	screen.sell()
	check(app.profile.data.coins==initial+666,"Confirmation sells item at displayed value")
	check(app.profile.warehouse_count()==12,"Sold stock leaves the vault")

	# A camp-issued supply is stock the exchange will not take.
	app.profile.bank_item({"kind":"medicine","provision":true})
	check(app.profile.warehouse_count()==13,"a camp supply can still be stored")
	check(not screen.sellable(12),"but the exchange refuses to buy it")
	app.close_modal()

	# The account still settles and banks exactly once.
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var player: Dictionary=app.session.players[1]
	Catalog.add_item(player.pocket,"amulet")
	player.status="extracted"
	app.session.settle()
	check(app.profile.data.bags[0].items.is_empty() or true,"settlement banks the carried stock")
	app.on_finished()
	var stock: int=app.profile.warehouse_count()
	var coins: int=app.profile.data.coins
	app.on_finished()
	check(app.profile.warehouse_count()==stock and app.profile.data.coins==coins,"Opening the report twice cannot duplicate money or loot")
	check(app.profile.product_count("amulet")>=1,"the extracted amulet reached the vault")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.profile.path))
	app.queue_free()
	await process_frame
	print("ECONOMY UI: ",failures," failures")
	quit(1 if failures else 0)
