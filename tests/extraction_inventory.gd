extends SceneTree

var app: Node
var failures := 0
var checks := 0
# Window pixels and the 1440x900 design space differ by whatever the stretch mode
# picked, so the ratio is measured once instead of assumed.
var mouse_scale := Vector2.ONE

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("UI FAIL: "+text)

func capture(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+name_value+".png")

func press(text: String) -> void:
	for child in app.page.get_children():
		if child is Button and child.text==text:
			child.pressed.emit()
			return
	check(false,"missing button "+text)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame

# --- real mouse input -------------------------------------------------------
# A parsed mouse event does reach main.gd's _input, but the viewport cursor that
# _input reads back only follows a warp. Every helper therefore warps first and
# then clicks, exactly like a player's hand would.

# Ctrl+left is read from the key state rather than the mouse event, so the test
# presses the key the way a hand would and parses each press and release.
func ctrl_down() -> void:
	await key_event(KEY_CTRL,true)

func ctrl_up() -> void:
	await key_event(KEY_CTRL,false)

func key_event(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	await process_frame

func ctrl_click_point(design: Vector2) -> void:
	await ctrl_down()
	await click_point(design)
	await ctrl_up()

func ctrl_click_item(slot: String, index: int) -> void:
	await ctrl_click_point(item_point(slot,index))

func calibrate_mouse() -> void:
	Input.warp_mouse(Vector2(600,600))
	await process_frame
	var read: Vector2=app.get_viewport().get_mouse_position()
	if read.x>1.0 and read.y>1.0:
		mouse_scale=Vector2(600,600)/read

func window_point(design: Vector2) -> Vector2:
	return design*mouse_scale

func mouse_move(design: Vector2) -> void:
	Input.warp_mouse(window_point(design))
	await process_frame

func mouse_press(design: Vector2) -> void:
	await mouse_move(design)
	await button_event(design,true)

func mouse_release(design: Vector2) -> void:
	await button_event(design,false)

func button_event(design: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=down
	event.position=window_point(design)
	event.global_position=event.position
	Input.parse_input_event(event)
	await process_frame

func click_point(design: Vector2) -> void:
	await mouse_press(design)
	await mouse_release(design)

# Both taps have to land inside the double click window, so no timer is waited
# out between them.
func double_click_point(design: Vector2) -> void:
	await click_point(design)
	await click_point(design)

func drag_between(from: Vector2, to: Vector2) -> void:
	await mouse_press(from)
	await mouse_move(from.lerp(to,0.5))
	await mouse_move(to)
	await mouse_release(to)

# Centre of one cell of a registered grid, in design space.
func cell_point(slot: String, cell: Vector2i) -> Vector2:
	var entry: Dictionary=app.grids[slot]
	var step: float=float(entry.cell)+float(entry.gap)
	return Vector2(entry.origin)+Vector2((cell.x+0.5)*step,(cell.y+0.5)*step)

func item_point(slot: String, index: int) -> Vector2:
	var list: Array=Catalog.container_items(app.session.players[1][slot])
	var item: Dictionary=list[index]
	return cell_point(slot,Vector2i(int(item.x),int(item.y)))

func zone_point(zone: String) -> Vector2:
	var zone_rect: Rect2=app.equip_zones[zone]
	return zone_rect.get_center()

func click_item(slot: String, index: int) -> void:
	await click_point(item_point(slot,index))

func double_click_item(slot: String, index: int) -> void:
	await double_click_point(item_point(slot,index))

func drag_item_to_zone(slot: String, index: int, zone: String) -> void:
	await drag_between(item_point(slot,index),zone_point(zone))

func drag_item_to_point(slot: String, index: int, point: Vector2) -> void:
	await drag_between(item_point(slot,index),point)

func spans(item: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(item.x),int(item.y)),Catalog.item_size(item))

func index_of_kind(container: Dictionary, kind: String) -> int:
	var items: Array=Catalog.container_items(container)
	for i in items.size():
		if str(items[i].kind)==kind:
			return i
	return -1

# Two items may never share a cell: this is the invariant the rotation bug broke,
# when a turned 2x2 relic landed on top of the 1x1 item beside it. The comparison
# is made cell by cell through Catalog.overlaps() because Rect2i.intersects()
# answers false for rectangles that plainly share cells in this build.
func check_no_overlap(container: Dictionary, text: String) -> void:
	var list: Array=Catalog.container_items(container)
	for i in list.size():
		for j in range(i+1,list.size()):
			var at := Vector2i(int(list[i].x),int(list[i].y))
			check(not Catalog.overlaps(at,Catalog.item_size(list[i]),list[j]),text+" (%s covers %s)" % [list[i].kind,list[j].kind])

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-extraction-design.json"
	root.add_child(app)
	await process_frame
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var p: Dictionary=app.session.players[1]
	p.backpack=Catalog.clean_container(Catalog.make_bag("red"),Catalog.tier("red").grid)
	p.pocket=Catalog.make_container()
	for kind in ["scrap","medicine","ammo","relic","charm"]: Catalog.add_item(p.backpack,kind)
	Catalog.place_item(p.backpack,Catalog.make_equipment("weapon",2,3))
	Catalog.add_item(p.pocket,"relic")
	p.backpack.items.append({"kind":"scrap","x":6,"y":7,"rot":false,"count":1})
	app.toggle_bag()
	await calibrate_mouse()
	check(app.grids.backpack.grid==Vector2i(8,8),"Largest backpack retains all cells")
	check(app.grids.pocket.grid==Vector2i(4,4),"Secure pocket retains fixed capacity")
	check(app.grids.pocket.origin.y>app.grids.backpack.clip.end.y,"Pocket always sits below backpack")
	check(app.equip_zones.weapon.position.x<app.grids.backpack.origin.x,"Equipment sits left of storage")
	check(not app.slot_bar_stale(),"New quick sockets register valid hit rectangles")
	await capture("extraction-inventory-overview")
	check(not app.grids.has("loot"),"Normal TAB view has no outdoor chest")
	check(app.overlay.get_node("ExtractionBackdrop").size.x<1000,"TAB physically removes entire right column")
	check(app.grids.pocket.origin.y+4*(app.pocket_cell+app.pocket_gap)<690,"Pocket fits inside main frame above footer")
	check(app.extraction_inventory.bag_scroller.get_v_scroll_bar().has_theme_stylebox_override("grabber"),"Scrollbar uses designed metallic grip")
	var original_pocket: Vector2=app.grids.pocket.origin
	var original_bag: Vector2=app.grids.backpack.origin
	await mouse_move(app.grids.backpack.clip.get_center())
	for i in 10:
		var wheel := InputEventMouseButton.new()
		wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed=true
		wheel.position=window_point(app.grids.backpack.clip.get_center())
		Input.parse_input_event(wheel)
		await process_frame
	check(app.extraction_inventory.bag_scroller.scroll_vertical>0,"Actual mouse wheel scrolls oversized backpack")
	check(app.grids.backpack.origin.y<original_bag.y,"Hit-test origin follows scroll")
	check(app.grids.pocket.origin==original_pocket,"Pocket stays fixed when backpack scrolls")
	check(app.grid_at(app.grids.backpack.clip.position-Vector2(0,10)).is_empty(),"Clipped rows cannot intercept header clicks")
	await click_point(cell_point("backpack",Vector2i(6,7)))
	check(app.selected==p.backpack.items.size()-1,"Bottom-row item can be selected after scrolling")
	await capture("extraction-inventory-scrolled")
	app.extraction_inventory.bag_scroller.scroll_vertical=0
	await process_frame
	await mouse_move(item_point("backpack",0))
	await create_timer(0.1).timeout
	check(is_instance_valid(app.extraction_inventory.tooltip),"Hover opens readable item details")
	await capture("extraction-inventory-tooltip")
	await click_point(item_point("backpack",1))
	check(app.selected==1,"Single click selects a supply")
	await capture("extraction-inventory-selected")
	var med: int=index_of_kind(p.backpack,"medicine")
	await mouse_press(item_point("backpack",med))
	await key(KEY_R)
	await mouse_move(cell_point("backpack",Vector2i(4,3)))
	await mouse_release(cell_point("backpack",Vector2i(4,3)))
	check(Catalog.container_count(p.backpack,"medicine")==1,"Rotated supply stays in backpack")
	check_no_overlap(p.backpack,"Rotation preserves collision")
	var weapon: int=index_of_kind(p.backpack,"weapon")
	await drag_item_to_zone("backpack",weapon,"weapon")
	check(int(app.session.kit_weapon(p).get("weapon",-1))==2,"Dragged weapon equips on new character slot")
	await capture("extraction-inventory-equipped")
	await ctrl_click_point(zone_point("weapon"))
	check(app.session.kit_weapon(p).is_empty(),"Ctrl click stows worn weapon")
	await mouse_move(item_point("backpack",index_of_kind(p.backpack,"medicine")))
	await key(KEY_F)
	check(app.session.item_slot_kind(p,0)=="medicine","F places supply in redesigned quick slot")
	await mouse_move((app.slot_zone_rects[0] as Rect2).get_center())
	await key(KEY_F)
	check(app.session.item_slot(p,0).is_empty(),"F returns quick-slot supply")
	for tier in Catalog.BAG_TIERS:
		p.backpack=Catalog.clean_container(Catalog.make_bag(tier.key),tier.grid)
		Catalog.add_item(p.backpack,"medicine")
		app.show_inventory()
		check(app.grids.backpack.clip.end.y<app.grids.pocket.origin.y,"Every size keeps pocket below scroll window")
		await capture("extraction-inventory-"+tier.key)
	p.backpack=Catalog.clean_container(Catalog.make_bag("red"),Catalog.tier("red").grid)
	app.close_bag()
	var chest: Dictionary=app.session.ruins.chests[0]
	chest.items.clear()
	Catalog.place_item(chest,{"kind":"relic","count":1,"rot":false})
	chest.searched=0
	p.p=chest.p
	app.loot_action()
	check(app.grids.has("loot") and app.grids.has("pocket"),"Search shows loot and both own containers")
	await capture("extraction-inventory-search-sealed")
	chest.searched=1
	app.show_inventory()
	await capture("extraction-inventory-search-revealed")
	await mouse_press(cell_point("loot",Vector2i(1,1)))
	check(app.drag.active and app.drag.slot=="loot","Revealed relic can be grabbed from any occupied cell")
	await mouse_move(cell_point("backpack",Vector2i(1,1)))
	await mouse_release(cell_point("backpack",Vector2i(1,1)))
	check(app.session.container_units(chest)==0,"Drag pickup removes loot from chest")
	check(Catalog.container_count(p.backpack,"relic")+Catalog.container_count(p.pocket,"relic")==2,"Pickup preserves both existing and new relic")
	app.close_bag()
	check(app.overlay.get_child_count()==0,"Close removes inventory overlays")
	print("EXTRACTION INVENTORY: %d checks / %d failures" % [checks,failures])
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)
