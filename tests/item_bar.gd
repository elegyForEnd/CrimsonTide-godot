extends SceneTree

# A focused integration test for the item bar: three sockets under the worn kit,
# a second row along the bottom of the screen, and the drags and key presses that
# move items between them, the backpack and the player's hands. It runs on its own
# so a failure here cannot be mistaken for a failure somewhere else in the suite.

var app: Node
var failures := 0
var checks := 0
var mouse_scale := Vector2.ONE

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("ITEM BAR FAIL: "+text)

func key_event(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	await process_frame

func press_key(code: int) -> void:
	await key_event(code,true)
	await key_event(code,false)

func window_point(design: Vector2) -> Vector2:
	return design*mouse_scale

func calibrate_mouse() -> void:
	Input.warp_mouse(Vector2(600,600))
	await process_frame
	var read: Vector2=app.get_viewport().get_mouse_position()
	if read.x>1.0 and read.y>1.0:
		mouse_scale=Vector2(600,600)/read

func cell_point(slot: String, cell: Vector2i) -> Vector2:
	var entry: Dictionary=app.grids[slot]
	var step: float=float(entry.cell)+float(entry.gap)
	return Vector2(entry.origin)+Vector2((cell.x+0.5)*step,(cell.y+0.5)*step)

func item_point(slot: String, index: int) -> Vector2:
	var list: Array=Catalog.container_items(app.session.players[1][slot])
	var item: Dictionary=list[index]
	return cell_point(slot,Vector2i(int(item.x),int(item.y)))

func zone_point(zone: String) -> Vector2:
	return (app.equip_zones[zone] as Rect2).get_center()

# A real drag: the cursor is warped onto the item first, then the button goes
# down, travels in two steps and comes back up. Every coordinate is measured once
# and held for the whole gesture, because a point recomputed from the grids while
# the button is down would move the target under the drag. The pause is what keeps
# two drags from the same cell apart: back to back they fall inside the 450ms
# double-click window, which is a different (and deliberate) gesture.
func drag_item_to(container: String, index: int, target: Vector2) -> void:
	await create_timer(0.5).timeout
	var from := item_point(container,index)
	await mouse_press(from)
	check(app.drag.active,"pressing an item starts a drag (from %s, drag %s)" % [from,app.drag])
	await mouse_move(from.lerp(target,0.45))
	await mouse_move(target)
	await mouse_release(target)
	await process_frame

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

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-item-bar-profile.json"
	app.profile.data.pocket=Catalog.clean_container({"key":"white","items":[]},Catalog.POCKET_GRID)
	app.profile.data.bag_key="white"
	app.profile.data.bags=[Catalog.clean_container({"key":"white","items":[]},Catalog.tier("white").grid)]
	app.profile.data.hero=0
	await create_timer(0.4).timeout
	await calibrate_mouse()
	app.session.solo({"hero":0})
	app.session.launch(false,4242)
	app.session.enemies.clear()
	app.session.spawn_timer=99999
	app.page_name="game"
	app.session.players[1].p=Vector2(1350,1110)
	app.field.camera=Vector2(1350,1110)
	await create_timer(0.25).timeout
	var walker: Dictionary=app.session.players[1]
	check(app.session.item_slots(walker).size()==3,"a raid starts with three empty item sockets")
	# --- the panel half -----------------------------------------------------
	await press_key(KEY_TAB)
	check(app.inventory_open,"TAB opens the bag")
	check(app.slot_zone_rects.size()==3,"the panel registers three sockets")
	check(app.equip_zones.has("slot0") and app.equip_zones.has("slot1") and app.equip_zones.has("slot2"),"every socket is a drop zone")
	# A 2x2 weapon goes into a single socket and the socket keeps its real size.
	walker.backpack.items.clear()
	check(Catalog.place_item(walker.backpack,Catalog.make_equipment("weapon",2,4)),"a 2x2 gold sword waits in the bag")
	app.show_inventory()
	await process_frame
	await drag_item_to("backpack",0,zone_point("slot1"))
	check(str(app.session.item_slot(walker,1).get("kind",""))=="weapon","dragging a weapon onto a socket parks it there")
	check(int(app.session.item_slot(walker,1).get("weapon",-1))==2,"the socket holds the sword itself")
	check(walker.backpack.items.is_empty(),"the parked weapon left the backpack")
	check(app.selected_item_slot==1,"the socket a drag lands in becomes the selected one")
	check(Catalog.item_size(app.session.item_slot(walker,1))==Vector2i(2,2),"a socket keeps the real 2x2 footprint")
	check(not app.session.item_slot(walker,1).has("x"),"a socket strips the grid coordinates it came with")
	# Clicking selects a socket; number keys also apply its item immediately.
	await app.slot_at(app.slot_zones()[0].get_center())
	var first_box: Rect2=app.slot_zones()[0]
	app.select_item_slot(0)
	check(app.selected_item_slot==0,"clicking the first socket selects it")
	await press_key(KEY_3)
	check(app.selected_item_slot==2,"3 selects the third socket")
	await press_key(KEY_1)
	check(app.selected_item_slot==0,"1 selects the first socket back")
	# A relic has no verb at all: [E] refuses it and leaves it where it is.
	check(Catalog.place_item(walker.backpack,{"kind":"relic","rot":false,"count":1}),"a relic waits for a socket")
	app.show_inventory()
	await process_frame
	await drag_item_to("backpack",index_of(walker.backpack,"relic"),zone_point("slot0"))
	check(str(app.session.item_slot(walker,0).get("kind",""))=="relic","a 2x2 relic fits one socket")
	await press_key(KEY_1)
	check(app.apply_item_slot(0)==false,"a relic has no use action")
	check(str(app.session.item_slot(walker,0).get("kind",""))=="relic","the inert relic is still in its socket")
	# A weapon in a socket swaps with what is in hand.
	await press_key(KEY_2)
	check(app.selected_item_slot==1,"2 selects the weapon socket as it equips it")
	check(int(walker.weapon)==2,"the socket's weapon is now in hand")
	check(app.session.weapon_kit_active(walker),"the swapped-in weapon is the active one")
	check(app.session.item_slot(walker,1).is_empty(),"the temporary issue weapon is not an item, so the socket is empty")
	# One item in, one item out: the displaced relic goes back to the bag. The bag
	# has to be big enough for both, which is why the player wears a 4x4 pack here:
	# a 2x2 staff plus the 2x2 relic it displaces is more than a white 3x3 holds,
	# and a swap with nowhere to put the old item is refused on purpose.
	walker.bags.append(Catalog.make_bag("green"))
	var green_at: int=walker.bags.size()-1
	check(Catalog.swap_bags(walker,green_at),"the player wears a 4x4 pack for the swap")
	walker.backpack.items.clear()
	check(Catalog.place_item(walker.backpack,Catalog.make_equipment("weapon",3,2)),"a staff waits to displace the relic")
	app.show_inventory()
	await process_frame
	await drag_item_to("backpack",0,zone_point("slot0"))
	check(str(app.session.item_slot(walker,0).get("kind",""))=="weapon","the staff takes the socket the relic held")
	check(index_of(walker.backpack,"relic")>=0,"the displaced relic went back to the bag")
	# Gear swaps by part, and the piece it replaced waits in the socket.
	walker.backpack.items.clear()
	check(Catalog.place_item(walker.backpack,Catalog.make_equipment("gear",1,4)),"a purple sight waits in the bag")
	app.show_inventory()
	await process_frame
	await drag_item_to("backpack",0,zone_point("slot2"))
	await press_key(KEY_3)
	check(int(app.session.kit_gear(walker)[1].get("tier",0))==4,"the socket's sight is the one worn")
	check(app.session.item_slot(walker,2).is_empty(),"an empty gear socket gives nothing back")
	# "收回" is the way back out of a socket.
	check(str(app.session.item_slot(walker,0).get("kind",""))=="weapon","the staff waits in a socket to be taken out")
	app.take_item_slot(0)
	await process_frame
	check(app.session.item_slot(walker,0).is_empty(),"taking a socket's item out empties it")
	check(index_of(walker.backpack,"weapon")>=0,"the staff landed back in the bag")
	walker.backpack.items.clear()
	# --- the bottom half ---------------------------------------------------
	app.close_bag()
	check(not app.equip_zones.has("slot0"),"closing the bag unregisters the panel sockets")
	app.update_hud()
	await process_frame
	var hud_slots := 0
	for child in app.overlay.get_children():
		if str(child.name).begins_with("HudItemBar") and child is Panel and child.size.x>60.0:
			hud_slots+=1
	check(hud_slots>=3,"three sockets are drawn into the game HUD")
	check(app.bottom_slot_y>600.0,"the item bar sits along the bottom of the screen")
	# A supply in a socket is spent by the bar's one key.
	walker.hp=40.0
	check(Catalog.add_item(walker.backpack,"medicine"),"a medkit waits for a socket")
	app.session.slot_put(walker,2,"backpack",0)
	await key_event(KEY_3,true)
	check(int(walker.hp)==85,"3 spends the medkit immediately on key down")
	await key_event(KEY_3,false)
	check(int(walker.hp)==85,"the socket's medkit heals for 45")
	check(app.session.item_slot(walker,2).is_empty(),"the used supply leaves the socket")
	# A backpack is a special kind of weapon: the two packs change places.
	check(Catalog.add_item(walker.backpack,"backpack"),"a loose pack waits for a socket")
	walker.backpack.items.back()["quality"]="purple"
	app.session.slot_put(walker,2,"backpack",walker.backpack.items.size()-1)
	await press_key(KEY_3)
	check(str(walker.backpack.key)=="purple","the socket's pack is the one on the player's back")
	check(str(app.session.item_slot(walker,2).get("quality",""))=="green","the pack that was worn waits in the socket")
	check(Catalog.item_size(app.session.item_slot(walker,2))==Vector2i(1,1),"a green pack takes a single cell in a socket")
	walker.backpack.items.clear()
	check(app.session.slot_put(walker,1,"backpack",-1)==false,"a socket refuses an index the bag does not have")
	check(app.session.item_slot(walker,1).is_empty(),"the refused index left the socket alone")
	app.session.disconnect_room()
	DirAccess.remove_absolute("user://test-item-bar-profile.json")
	print("ITEM BAR: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func index_of(container: Dictionary, kind: String) -> int:
	var items: Array=Catalog.container_items(container)
	for i in items.size():
		if str(items[i].kind)==kind:
			return i
	return -1
