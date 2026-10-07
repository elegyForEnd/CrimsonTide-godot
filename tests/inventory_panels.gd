extends SceneTree
## Both bag panels, headless.
##
## The raid panel and the camp panel now share one cell renderer (`item_tile.gd`) and
## one drag controller, and the raid panel's own test (`tests/extraction_inventory.gd`)
## is a screenshot test that needs a real window. This file covers the wiring without a
## display: the raid panel still registers its grids and sockets, still resolves a drop,
## and the camp panel does not leak into it.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func socket_count(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("extraction_inventory_socket.gd"):
			total += 1
	return total

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-inventory-panels.json"
	app.profile.data=Profile.new().data.duplicate(true)
	app.profile.sanitize_storage()
	app.session.solo(app.config())
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var p: Dictionary=app.session.players[app.session.my_id()]

	# --- the raid panel -------------------------------------------------------
	app.inventory_open=true
	app.show_inventory()
	await process_frame
	check(app.grids.has("backpack") and app.grids.has("pocket"),"the raid panel registers both carried grids")
	check(Vector2i(app.grids.backpack.grid)==Catalog.bag_grid(p.backpack),"the backpack grid follows its quality")
	check(app.equip_zones.has("weapon") and app.equip_zones.has("gear0") and app.equip_zones.has("charm1"),"every worn socket registers")
	check(app.equip_zones.has("bag") and app.equip_zones.has("slot0"),"the pack socket and the item bar register")
	check(app.cabinet_zones.is_empty(),"the raid panel has no cabinet sockets")
	var bag_cells: int=Catalog.bag_grid(p.backpack).x*Catalog.bag_grid(p.backpack).y
	check(socket_count(app.overlay)>=bag_cells+Catalog.POCKET_GRID.x*Catalog.POCKET_GRID.y,"the shared renderer filled both grids with cells")
	check(not app.camp_pack_open,"and the camp panel stays out of the raid")
	# The drop resolver still answers for a carried container. A Watcher sets out with a
	# free medkit in the bag, so the scrap lands after it.
	Catalog.add_item(p.backpack,"scrap")
	var scrap: int = p.backpack.items.size()-1
	app.show_inventory()
	check(app.index_at("backpack",Vector2i(1,0))==scrap,"a carried item is found by its cell")
	app.start_drag("backpack",scrap,false)
	check(str(app.held_item().kind)=="scrap","and a drag picks it up")
	var probe: Dictionary=app.drag_target_rect({"slot":"pocket","cell":Vector2i(0,0)},"scrap")
	check(int(probe.get("cell",Vector2i(-1,-1)).x)>=0,"the landing preview resolves against the pocket")
	app.stop_drag()
	# --- a worn piece is a drag source in the raid too ------------------------
	# Worn kit can be carried to the bag or swapped into a bar socket, and letting go
	# outside every panel is a miss rather than a piece of equipment on the floor.
	app.session.set_worn_slot(p,"gear",0,Catalog.make_equipment("gear",0,3))
	app.show_inventory()
	check(not app.session.kit_gear(p)[0].is_empty(),"armour is worn for the raid drag")
	app.start_drag("gear0",0,false)
	check(not app.held_item().is_empty(),"a worn socket can be picked up")
	check(app.held_size(app.held_item()).x>0.0,"and the hand has a size to draw")
	var grid: Dictionary=app.grids["backpack"]
	var step: float=float(grid.cell)+float(grid.gap)
	app.release_drag(Vector2(grid.origin)+Vector2(1,1)*step+Vector2(9,9))
	await process_frame
	check(app.session.kit_gear(p)[0].is_empty(),"dropping it on the bag takes it off the body")
	check(Catalog.container_count(p.backpack,"gear")==1,"and the piece is in the bag")
	p.backpack.items.clear()
	app.session.set_worn_slot(p,"gear",1,Catalog.make_equipment("gear",1,4))
	app.session.set_item_slot(p,0,{"kind":"medicine","count":1})
	app.show_inventory()
	app.start_drag("gear1",0,false)
	var bar: Rect2=app.slot_zone_rects[0]
	app.release_drag(Vector2(bar.position)+bar.size*0.5)
	await process_frame
	check(app.session.item_slot(p,0).kind=="gear","dropping a worn piece on a bar socket swaps it in")
	check(app.session.kit_gear(p)[1].kind=="medicine","and the bar's item took its place on the body")
	app.session.set_worn_slot(p,"gear",2,Catalog.make_equipment("gear",2,4))
	var drops_before: int=app.session.world_drops.size()
	app.show_inventory()
	check(app.drop_region.size.x>0.0,"the panel registers where it ends")
	app.start_drag("gear2",0,false)
	# Inside the panel, on its own empty space: nothing happens at all.
	app.release_drag(Vector2(930,840))
	await process_frame
	check(app.session.kit_gear(p)[2].kind=="gear","a release on the panel's own empty space keeps the piece on the body")
	check(app.session.world_drops.size()==drops_before,"and drops nothing")
	# Outside the panel: the drop-to-ground zone.
	app.show_inventory()
	app.start_drag("gear2",0,false)
	app.release_drag(Vector2(20,20))
	await process_frame
	check(app.session.world_drops.size()==drops_before+1,"dragging a worn piece outside the panel puts it on the ground")
	check(app.session.kit_gear(p)[2].is_empty(),"and it leaves the body")
	check(app.session.container_units(app.session.world_drops[drops_before])==1,"as one loose item")
	# A carried item released inside the panel's empty space is kept too.
	Catalog.add_item(p.backpack,"scrap")
	app.show_inventory()
	var loose: int=p.backpack.items.size()-1
	app.start_drag("backpack",loose,false)
	var kept_before: int=p.backpack.items.size()
	app.release_drag(Vector2(930,840))
	await process_frame
	check(p.backpack.items.size()==kept_before,"a carried item released inside the panel stays in the bag")
	app.close_bag()
	check(not app.inventory_open,"closing the raid panel clears the screen")

	# --- the camp panel, same controller -------------------------------------
	# The camp only offers its own panel outside a live raid.
	app.session.running=false
	app.go_camp()
	await process_frame
	app.show_camp_pack(false)
	check(app.camp_pack_open and app.grids.has("warehouse"),"the camp panel takes over the same registrations")
	check(app.grids.has("backpack") and app.grids.has("pocket"),"with all three grids")
	app.close_bag()
	check(not app.camp_pack_open and app.grids.is_empty(),"and hands them back when it closes")

	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-inventory-panels.json"))
	print("INVENTORY PANELS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
