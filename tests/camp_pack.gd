extends SceneTree
## The camp远征行囊 panel, driven through the real screen.
##
## `tests/camp_storage.gd` pins the rules with no UI; this file checks that the panel
## is actually wired to them: TAB opens it, it registers the three grids and every
## worn socket with the drag controller, a released drag moves loot between the bag
## and the vault, and TAB/ESC closes it again.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func cell_point(app, slot: String, cell: Vector2i) -> Vector2:
	var entry: Dictionary=app.grids[slot]
	return Vector2(entry.origin)+Vector2(cell)*(float(entry.cell)+float(entry.gap))

func _initialize() -> void:
	call_deferred("run")

## A known starting point. The profile on disk is whatever a previous run left
## behind — and `user://` is not always writable in a sandboxed run, so the panel
## is reset here instead of trusting the file: an empty carried backpack, an empty
## pocket, no spare packs and an empty vault.
func reset_kit(app) -> void:
	var p: Dictionary=app.session.players[app.session.my_id()]
	p["backpack"]=Catalog.make_bag("white")
	p.backpack["gw"]=Catalog.BAG_TIERS[0].grid.x
	p.backpack["gh"]=Catalog.BAG_TIERS[0].grid.y
	p["pocket"]=Catalog.make_container([],Catalog.POCKET_GRID)
	p["bags"]=[]
	p["equipped"]=app.session.empty_equipment()
	p["slots"]=app.session.empty_item_slots()
	app.profile.data["warehouse"]=app.profile.make_vault()
	app.profile.data["warehouse_spill"]=[]
	app.profile.data["loot_value"]=0

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-camp-pack.json"
	app.profile.data.coins=1000
	app.profile.data.home=preload("res://scripts/homestead.gd").clean({})
	app.go_camp()
	await process_frame
	reset_kit(app)
	check(app.page_name=="ground","the camp map is up")

	app.camp.pack_requested.emit()
	check(app.camp_pack_open and app.inventory_open,"TAB opens the camp bag panel")
	check(app.grids.has("warehouse") and app.grids.has("backpack") and app.grids.has("pocket"),"all three grids register with the drag controller")
	check(Vector2i(app.grids.warehouse.grid)==Catalog.WAREHOUSE_GRID,"the vault registers as the 15x15 grid")
	check(app.equip_zones.has("weapon") and app.equip_zones.has("gear0") and app.equip_zones.has("charm1"),"every worn socket registers")
	check(app.equip_zones.has("bag") and app.equip_zones.has("slot0") and app.equip_zones.has("slot2"),"the pack socket and the whole item bar register")
	check(app.cabinet_zones.is_empty(),"an empty cabinet registers no spare sockets")
	check(app.camp.input_blocked,"the camp stops walking while the panel is open")

	# A drag from the bag into the vault, released on a vault cell. A single item lands
	# on the cell it was aimed at (a stack would merge into its own pile instead).
	var p: Dictionary=app.session.players[app.session.my_id()]
	Catalog.add_item(p.backpack,"wind_chime")
	app.show_inventory()
	app.start_drag("backpack",0,false)
	app.release_drag(cell_point(app,"warehouse",Vector2i(4,5)))
	check(app.profile.warehouse_count()==1,"a drag from the bag into the vault stores the item")
	check(p.backpack.items.is_empty(),"and the bag no longer holds it")
	var stored: Dictionary=app.profile.warehouse_item(0)
	check(Vector2i(int(stored.x),int(stored.y))==Vector2i(4,5),"the item lands on the cell it was dropped on")

	# And back out of the vault into the pocket.
	app.show_inventory()
	app.start_drag("warehouse",0,false)
	app.release_drag(cell_point(app,"pocket",Vector2i(1,1)))
	check(p.pocket.items.size()==1 and app.profile.warehouse_count()==0,"a drag out of the vault reaches the pocket")

	# Double clicking a wearable in the vault wears it.
	app.profile.bank_item(Catalog.make_equipment("weapon",2,4))
	check(app.profile.warehouse_count()==1,"a field weapon waits in the vault")
	app.show_inventory()
	check(app.double_click_equip("warehouse",0) and int(app.session.kit_weapon(p).weapon)==2,"double clicking a vault weapon wears it")
	check(app.profile.warehouse_count()==0,"and it leaves the vault")

	# The station button opens the same panel focused on the vault.
	app.camp.dismiss_requested.emit()
	check(not app.camp_pack_open and not app.inventory_open,"dismiss closes the panel")
	check(not app.camp.input_blocked,"and hands the camp its controls back")
	app.on_camp_station("warehouse")
	check(app.camp_pack_open and app.camp_pack.focus_vault,"the warehouse station opens the panel focused on the vault")

	# The take-off gestures (double tap / Ctrl+left / F / the "卸" button) all share
	# `take_off_worn()`. In the camp the piece lands in the carried backpack AND the
	# panel repaints in the same gesture — the bug that made a worn piece look stuck
	# in the vault was a take-off that changed the state without redrawing.
	app.camp_pack_open=false
	app.close_bag()
	reset_kit(app)
	p["equipped"]["weapon"]={"kind":"weapon","weapon":3,"tier":4}
	p["weapon"]=3
	app.show_camp_pack(false)
	var sig_before: String=app.bag_signature
	app.take_off_worn("weapon")
	check(app.session.kit_weapon(p).is_empty(),"a take-off empties the weapon socket")
	check(Catalog.container_count(p.backpack,"weapon")==1,"and the piece lands in the carried backpack")
	check(app.bag_signature!=sig_before and app.bag_signature==app.camp_signature(p),"and the panel repainted in the same gesture")
	# With the carried bag and the vault both solid the take-off refuses outright and
	# says why, instead of dropping the piece on the ground.
	p.backpack.items.clear()
	for i in 9:
		Catalog.add_item(p.backpack,"crystal")
	p["equipped"]["weapon"]={"kind":"weapon","weapon":3,"tier":4}
	p["weapon"]=3
	var solid_vault: Dictionary=app.profile.data.warehouse
	for y in Catalog.WAREHOUSE_GRID.y:
		for x in Catalog.WAREHOUSE_GRID.x:
			solid_vault.items.append({"kind":"wind_chime","x":x,"y":y,"rot":false,"valued":true})
	app.show_camp_pack(false)
	app.take_off_worn("weapon")
	check(not app.session.kit_weapon(p).is_empty(),"a take-off with nowhere to go leaves the piece on the body")
	# Hand the vault back so the spare-pack drag below has somewhere to put one.
	reset_kit(app)
	app.show_camp_pack(false)

	# The pack on the back is a drag source too: to the vault it comes off and the old
	# pack is banked, outside the panel the pack itself lands on the camp floor.
	app.ensure_camp()
	reset_kit(app)
	p["backpack"]=Catalog.make_bag("purple")
	p.backpack["gw"]=6
	p.backpack["gh"]=6
	Catalog.add_item(p.backpack,"scrap")
	app.show_camp_pack(false)
	app.start_drag("bag",0,false)
	check(not app.held_item().is_empty(),"the worn pack can be picked up")
	app.release_drag(cell_point(app,"warehouse",Vector2i(0,0)))
	await process_frame
	check(str(p.backpack.key)=="white","dragging the pack to the vault takes it off")
	check(app.profile.warehouse_count()>0,"and the pack itself is in the vault")
	check(Catalog.container_count(p.backpack,"scrap")==1,"its loot moved into the 3x3 issue pack")
	p["backpack"]=Catalog.make_bag("gold")
	p.backpack["gw"]=7
	p.backpack["gh"]=7
	app.show_camp_pack(false)
	var floor_before: int=app.camp.activities.drops.size()
	app.start_drag("bag",0,false)
	app.release_drag(Vector2(20,20))
	await process_frame
	check(str(p.backpack.key)=="white","dragging the pack outside the panel takes it off as well")
	check(app.camp.activities.drops.size()>floor_before,"and the pack lands on the camp floor")
	reset_kit(app)
	app.show_camp_pack(false)

	# The right-button hand: holding it lifts the **whole** pile, and each left click sets
	# exactly one unit down on the cell under the cursor. The source is trimmed only as
	# units really land, which is what keeps a refusal free and the pile unlosable.
	reset_kit(app)
	p["backpack"]=Catalog.make_bag("green")
	p.backpack["gw"]=5
	p.backpack["gh"]=5
	Catalog.add_item(p.backpack,"crystal")
	p.backpack.items[0]["count"]=5
	app.show_camp_pack(false)
	app.start_whole_carry(cell_point(app,"backpack",Vector2i(0,0)))
	await process_frame
	check(int(app.drag.get("carry",0))==5,"holding the right button lifts the whole pile")
	check(int(app.held_item().get("count",1))==5,"and the hand shows all five")
	check(int(p.backpack.items[0].get("count",1))==5,"while the pile in the bag is still whole")
	app.carry_place_one(cell_point(app,"warehouse",Vector2i(3,3)))
	await process_frame
	check(int(app.drag.get("carry",0))==4,"one left click sets exactly one unit down")
	check(int(p.backpack.items[0].get("count",1))==4,"and takes exactly one off the source pile")
	app.carry_place_one(cell_point(app,"warehouse",Vector2i(3,3)))
	await process_frame
	check(app.profile.warehouse_count()==1 and int(app.profile.vault_items()[0].get("count",1))==2,"a second click on the same cell stacks next to the first")
	app.carry_finish(cell_point(app,"warehouse",Vector2i(3,3)))
	await process_frame
	check(int(app.drag.get("carry",0))==0,"letting the right button up ends the gesture")
	check(app.profile.warehouse_count()==1 and int(app.profile.vault_items()[0].get("count",1))==5,"and the rest of the pile lands where the cursor was")
	check(p.backpack.items.is_empty(),"so the bag pile is gone rather than duplicated")
	# A cancel gives back whatever is still in the hand. Units that already landed stay
	# landed — they were taken as each click was seated, so there is nothing to undo and
	# nothing to lose.
	Catalog.add_item(p.backpack,"crystal")
	p.backpack.items[0]["count"]=4
	app.show_camp_pack(false)
	app.start_whole_carry(cell_point(app,"backpack",Vector2i(0,0)))
	await process_frame
	check(int(app.drag.get("carry",0))==4,"a pile can be lifted again")
	app.carry_place_one(cell_point(app,"warehouse",Vector2i(8,8)))
	await process_frame
	check(int(p.backpack.items[0].get("count",1))==3,"one unit really left the pile")
	app.cancel_carry()
	await process_frame
	check(int(p.backpack.items[0].get("count",1))==3,"cancelling leaves the units that already landed alone")
	check(app.profile.warehouse_count()==2,"and the vault keeps the pile that was set down")
	# A right click on empty space lifts nothing.
	reset_kit(app)
	app.show_camp_pack(false)
	p["equipped"]["weapon"]={"kind":"weapon","weapon":3,"tier":4}
	app.show_camp_pack(false)
	app.start_whole_carry(cell_point(app,"warehouse",Vector2i(0,0)))
	await process_frame
	check(int(app.drag.get("carry",0))==0,"a right click on empty space lifts nothing")
	reset_kit(app)
	app.show_camp_pack(false)

	# A spare pack is a drag source: it can be moved into the vault and sold.
	app.camp_pack_open=false
	app.close_bag()
	p["bags"]=[Catalog.make_bag("gold")]
	app.show_camp_pack(false)
	check(app.cabinet_zones.has(0),"a spare pack registers a cabinet socket")
	app.start_drag("cab",0,false)
	app.release_drag(cell_point(app,"warehouse",Vector2i(0,0)))
	check(p.bags.is_empty() and app.profile.warehouse_count()==1,"a spare pack can be dragged into the vault")
	check(app.profile.sell_items([0])>0,"and sold from there")

	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-camp-pack.json"))
	print("CAMP PACK: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
