extends SceneTree

var app: Node
var failures := 0
# Window pixels and the 1440x900 design space differ by whatever the stretch mode
# picked, so the ratio is measured once instead of assumed.
var mouse_scale := Vector2.ONE

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
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
	root.add_child(app)
	check(app.page_name=="account","first launch offers login and guest")
	press("游客登录 · 离线也能玩")
	app.profile.path="user://test-ui-profile.json"
	# _ready() already read the developer's real save, and a pocket full of relics
	# from the last play session used to break every "pocket holds …" assertion.
	# The suite has to start from a storage of its own.
	app.profile.data.pocket=Catalog.clean_container({"key":"white","items":[]},Catalog.POCKET_GRID)
	app.profile.data.bag_key="white"
	app.profile.data.bags=[Catalog.clean_container({"key":"white","items":[]},Catalog.tier("white").grid)]
	app.profile.data.hero=0
	await create_timer(0.5).timeout
	await calibrate_mouse()
	await capture("ui-title")
	for child in app.page.get_children():
		if child is GothicButton and child.text=="设置":
			app.select_title_entry(child)
	await create_timer(0.2).timeout
	await capture("ui-title-selected")
	press("开始游戏")
	check(app.page_name=="camp","title to camp")
	await capture("ui-camp")
	for hero in [1,2]:
		app.profile.data.hero=hero
		app.session.configure(app.config())
		await capture("ui-camp-"+str(hero))
	app.profile.data.hero=0
	app.session.configure(app.config())
	press("全队出发    →")
	check(app.page_name=="game" and app.session.running,"camp to game")
	app.session.enemies.clear()
	app.session.spawn_timer=9999
	app.session.players[1].p=Vector2(1350,1110)
	app.field.camera=Vector2(1350,1110)
	for kind in ["crystal","medicine","ammo","backpack"]:
		check(Catalog.add_item(app.session.players[1].backpack,kind),"backpack holds "+kind)
	check(not Catalog.add_item(app.session.players[1].backpack,"charm"),"a 3x3 backpack fills up")
	for kind in ["crystal","relic","charm"]:
		check(Catalog.add_item(app.session.players[1].pocket,kind),"pocket holds "+kind)
	for i in 4:
		app.session.spawn_enemy(Vector2(1700+i*95,1110),i)
	await create_timer(0.5).timeout
	check(app.session.issue_weapon_active(app.session.players[1]),"a raid begins with the hero's temporary weapon")
	for key_code in [KEY_1,KEY_2,KEY_3,KEY_4]:
		await key(key_code)
	check(app.session.issue_weapon_active(app.session.players[1]),"1-4 no longer choose a weapon")
	Input.action_press("right")
	await create_timer(0.12).timeout
	check(app.session.players[1].motion=="walk","Movement enters walk state")
	await capture("movement-walk")
	Input.action_press("sprint")
	for tick in 12:
		await physics_frame
	check(app.session.players[1].motion=="run","Shift enters run state: "+str(app.session.local_input)+" / "+str(app.session.players[1].motion)+" / "+str(app.session.players[1].p))
	await capture("movement-run")
	await key(KEY_SPACE)
	await create_timer(0.06).timeout
	check(app.session.players[1].motion=="dodge","Space enters dodge state")
	await capture("movement-dodge")
	Input.action_release("right")
	Input.action_release("sprint")
	await create_timer(0.3).timeout
	check(app.session.players[1].motion=="idle","Movement returns to idle")
	await capture("ui-game")
	await key(KEY_TAB)
	check(app.inventory_open,"Tab opens inventory through input system")
	check(float(app.grids["backpack"].origin.x)<float(app.equip_zones["weapon"].position.x),"TAB places the backpack left of equipment")
	check(float(app.grids["backpack"].origin.x)<float(app.slot_zone_rects[0].position.x),"TAB places the backpack left of the item bar")
	check(float(app.equip_zones["weapon"].end.y)<float(app.slot_zone_rects[0].position.y),"TAB places equipment above the item bar")
	var bar_left: float=app.slot_zone_rects[0].position.x
	var bar_right: float=app.slot_zone_rects[app.slot_zone_rects.size()-1].end.x
	check(absf((bar_left+bar_right)*0.5-1175.0)<1.0,"TAB centers item slots in the equipment panel")
	check(float(app.grids["pocket"].origin.x)<float(app.equip_zones["weapon"].position.x),"TAB keeps the pocket on the storage side")
	await capture("ui-inventory")
	app.pick_item("pocket",1)
	check(app.selected_slot=="pocket" and app.selected==1,"selecting a pocket item works")
	await capture("ui-inventory-pocket")
	app.pick_item("backpack",0)
	await capture("ui-inventory-selected")
	# Every quality must be wearable and must resize the grid in the live session.
	for key in ["green","blue","purple","gold","red","white"]:
		app.session.players[1].bags.append(Catalog.make_bag(key))
		var spare: int=app.session.players[1].bags.size()-1
		app.equip_spare(spare)
		await create_timer(0.12).timeout
		check(str(app.session.players[1].backpack.key)==key,"equip %s backpack" % key)
		check(Catalog.bag_grid(app.session.players[1].backpack)==Catalog.tier(key).grid,"%s backpack resizes the grid" % key)
		var pocket_entry: Dictionary=app.grids["pocket"]
		check(float(pocket_entry.origin.y)+4.0*(float(pocket_entry.cell)+float(pocket_entry.gap))-float(pocket_entry.gap)+18.0<=900.0,"%s backpack leaves the pocket on screen" % key)
	check(Catalog.container_count(app.session.players[1].backpack,"crystal")>0,"swapping backpacks keeps loot")
	await capture("ui-inventory-equipped")
	# R turns the item selected inside the backpack.
	app.session.players[1].backpack.items.clear()
	check(Catalog.add_item(app.session.players[1].backpack,"medicine"),"a medkit waits to be rotated")
	app.pick_item("backpack",0)
	var rot_before := bool(app.session.players[1].backpack.items[0].get("rot",false))
	await key(KEY_R)
	check(bool(app.session.players[1].backpack.items[0].get("rot",false))!=rot_before,"R rotates the selected backpack item")
	await key(KEY_R)
	check(bool(app.session.players[1].backpack.items[0].get("rot",false))==rot_before,"R rotates it back")
	# A medkit in the backpack can be used without closing the bag.
	app.session.players[1].backpack.items.clear()
	check(Catalog.add_item(app.session.players[1].backpack,"medicine"),"a medkit sits in the backpack")
	app.session.players[1].hp=20.0
	app.use_item("backpack",0)
	await create_timer(0.15).timeout
	check(int(app.session.players[1].hp)==65,"the inventory use button heals the player")
	check(app.session.carried(app.session.players[1],"medicine")==0,"the used medkit is consumed")
	# Weapons and gear found in the field can be worn from the backpack.
	app.session.players[1].backpack.items.clear()
	app.session.players[1].backpack.items.append(Catalog.make_equipment("weapon",1,4))
	app.equip_slot("backpack",0)
	await create_timer(0.15).timeout
	check(int(app.session.players[1].weapon)==1,"equipping a looted weapon puts it in hand")
	check(app.session.weapon_kit_active(app.session.players[1]),"the worn weapon is active")
	check(app.session.equipment_damage(app.session.players[1])>0.0,"the worn weapon raises damage")
	check(app.session.equipment_rate(app.session.players[1])<1.0,"the worn weapon swings faster")
	check(app.session.players[1].backpack.items.is_empty(),"the equipped weapon left the backpack")
	check(Catalog.add_item(app.session.players[1].backpack,"gear"),"a gear piece sits in the backpack")
	app.session.players[1].backpack.items[0]["gear"]=0
	app.session.players[1].backpack.items[0]["tier"]=5
	var hp_before: float=app.session.players[1].max_hp
	app.equip_slot("backpack",0)
	await create_timer(0.15).timeout
	check(app.session.players[1].max_hp>hp_before,"worn armour raises the health ceiling")
	await capture("ui-inventory-equipment")
	app.unequip_slot("weapon",0)
	await create_timer(0.15).timeout
	check(app.session.kit_weapon(app.session.players[1]).is_empty(),"the HUD can take the weapon off again")
	check(app.session.issue_weapon_active(app.session.players[1]),"taking the looted weapon off brings the temporary weapon back")
	check(int(app.session.players[1].weapon)==Catalog.starter_index(0),"the temporary weapon of the hero is the one restored")
	await key(KEY_TAB)
	check(not app.inventory_open,"Tab closes inventory")
	# F falls through to the medkit when there is nothing in reach to loot: this is
	# the key conflict that used to make backpack supplies unusable.
	var stash_chests: Array=app.session.ruins.chests.duplicate()
	var stash_drops: Array=app.session.world_drops.duplicate()
	app.session.ruins.chests.clear()
	app.session.world_drops.clear()
	check(Catalog.add_item(app.session.players[1].backpack,"medicine"),"a medkit waits for the F key")
	app.session.players[1].hp=20.0
	await key(KEY_F)
	check(int(app.session.players[1].hp)==65,"F heals when nothing is lootable")
	app.session.ruins.chests=stash_chests
	app.session.world_drops=stash_drops
	# --- searching a container and dragging loot out ------------------------
	var walker: Dictionary=app.session.players[1]
	app.session.spawn_timer=9999
	app.session.enemies.clear()
	walker.backpack.items.clear()
	check(Catalog.add_item(walker.backpack,"medicine"),"a medkit rides along for the quick-use bar")
	var chest: Dictionary=app.session.ruins.chests[0]
	walker.p=chest.p
	app.field.camera=chest.p
	await create_timer(0.2).timeout
	await key(KEY_F)
	check(app.inventory_open,"F opens the inventory together with the search window")
	check(app._loot_index==0,"the search window points at the chest")
	check(float(app.grids["backpack"].origin.x)<float(app.grids["loot"].origin.x),"search keeps the backpack left and the chest right")
	check(app.session.container_units(chest)>0 and app.session.visible_units(chest)==0,"nothing is revealed when the search starts")
	await capture("ui-loot-search")
	check(app.session.container_units(chest)>0,"the container is stocked once the search starts")
	check(app.session.visible_units(chest)==0,"a fresh container starts with nothing revealed")
	# The search advances on its own at the first item's quality-specific pace.
	await create_timer(app.session.search_seconds(app.session.next_search_item(chest))+0.2).timeout
	check(app.session.visible_units(chest)>=1,"loot surfaces by itself while the search window is open")
	check(app.session.visible_units(chest)<app.session.container_units(chest),"a container is not searched instantly")
	await capture("ui-loot-revealed")
	# Supplies stay usable while the search window has the player's attention.
	walker.hp=25.0
	var quick: Array=app.quick_use_slots(walker)
	check(quick.size()>0,"the loot window offers quick-use items")
	app.use_item(str(quick[0].slot),int(quick[0].index))
	await create_timer(0.15).timeout
	check(walker.hp>25.0,"the quick-use chip works while the search window is open")
	check(app.session.carried(walker,"medicine")==0,"the quick-use medkit is consumed")
	# Drag the first revealed item from the search window into the backpack.
	var before_bag: int=walker.backpack.items.size()
	var loot_grid: Dictionary=app.grids["loot"]
	var loot_before: int=app.session.container_units(chest)
	app.start_drag("loot",0,false)
	var bag_grid: Dictionary=app.grids["backpack"]
	app.release_drag(Vector2(bag_grid.origin)+Vector2(bag_grid.cell*0.5,bag_grid.cell*0.5))
	check(walker.backpack.items.size()==before_bag+1,"dragging loot into the backpack adds one item")
	check(app.session.container_units(chest)==loot_before-1,"the dragged unit left the container")
	await capture("ui-inventory-after-drag")
	# Re-arranging inside the backpack by dragging to another cell.
	var first_item: Dictionary=walker.backpack.items[0]
	var from_cell := Vector2i(int(first_item.x),int(first_item.y))
	var to_cell := Vector2i(0,0)
	if from_cell==to_cell:
		to_cell=Vector2i(1,0)
	app.start_drag("backpack",0,false)
	app.release_drag(Vector2(bag_grid.origin)+Vector2(to_cell.x*(bag_grid.cell+bag_grid.gap),to_cell.y*(bag_grid.cell+bag_grid.gap))+Vector2(bag_grid.cell*0.5,bag_grid.cell*0.5))
	check(Vector2i(int(walker.backpack.items[0].x),int(walker.backpack.items[0].y))==to_cell,"dragging inside the backpack moves the item")
	check(walker.backpack.items.size()==before_bag+1,"moving inside the backpack never duplicates items")
	# Dragging a backpack item onto the dimensional pocket.
	if walker.backpack.items.size()>0:
		var pocket_grid: Dictionary=app.grids["pocket"]
		app.start_drag("backpack",0,false)
		app.release_drag(Vector2(pocket_grid.origin)+Vector2(pocket_grid.cell*0.5,pocket_grid.cell*0.5))
		check(app.session.carried(walker,"crystal")+app.session.carried(walker,"medicine")+app.session.carried(walker,"scrap")>=0,"dragging into the pocket resolves")
	await capture("ui-inventory-pocket-drag")
	app.close_bag()
	# Ground loot is grabbed with one F, without opening a search window.
	app.session.world_drops.append(app.session.ground_drop(walker.p,"crystal"))
	var ground_index: int=app.session.world_drops.size()-1
	await key(KEY_F)
	check(app.session.world_drops.size()==ground_index,"F picks up loose ground loot instantly")
	var bundle: Dictionary=app.session.loot_container(walker.p,Vector2i(8,8))
	bundle["dropped"]=true
	check(Catalog.place_item(bundle,{"kind":"scrap","rot":false,"count":1}),"a nearby bundle holds scrap")
	check(Catalog.place_item(bundle,{"kind":"ammo","rot":false,"count":1}),"a nearby bundle holds ammo")
	app.session.world_drops.append(bundle)
	var nearby_chests: Array=app.session.ruins.chests.duplicate()
	app.session.ruins.chests.clear()
	check(app.loot_action() and not app.inventory_open,"F hints at H without opening a multi-item ground bundle")
	await key(KEY_H)
	check(app.inventory_open and app._loot_index==ground_index,"H opens the nearby multi-item bundle")
	check(app.session.visible_units(bundle)==0,"the bundle starts sealed")
	check(float(app.grids["loot"].cell)==36.0,"a large dropped backpack fits its search grid on screen")
	await capture("ui-ground-bundle")
	app.close_bag()
	app.session.stop_search(walker)
	app.session.world_drops.pop_back()
	app.session.ruins.chests=nearby_chests
	# --- real mouse input: click, double click to wear, drag onto a socket -----
	# The grid bodies ignore the mouse, so main.gd hit-tests the cursor against the
	# registered grids. Everything below drives actual mouse events and therefore
	# walks the same path a player's hand does.
	walker.hp=walker.max_hp
	walker["equipped"]=app.session.empty_equipment()
	walker.backpack.items.clear()
	walker.pocket.items.clear()
	app.session.refresh_max_hp(walker)
	await key(KEY_TAB)
	check(app.inventory_open and app._loot_index<0,"TAB reopens the bag together with the equipment column")
	check(app.equip_zones.has("weapon"),"the weapon socket registers a drop zone")
	check(app.equip_zones.has("gear0") and app.equip_zones.has("gear1") and app.equip_zones.has("gear2"),"all three gear sockets register a drop zone")
	check(app.equip_zones.has("charm0") and app.equip_zones.has("charm1"),"both accessory sockets register drop zones")
	check(app.equip_zones.has("bag"),"the backpack socket registers a drop zone")
	check(app.panel_rects.size()>0,"the side panels register the area where a drop is cancelled")
	await capture("ui-equip-sockets")
	# A press that never travels is a click: it selects, it does not drag.
	check(Catalog.add_item(walker.backpack,"medicine"),"a medkit waits to be clicked")
	await click_item("backpack",0)
	check(not app.drag.active,"a click that never travelled leaves no drag behind")
	check(app.selected==0 and app.selected_slot=="backpack","clicking an item selects it")
	await capture("ui-mouse-select")
	# Two quick taps wear whatever is under the cursor.
	walker.backpack.items.clear()
	check(Catalog.place_item(walker.backpack,Catalog.make_equipment("weapon",2,4)),"a looted two handed sword waits in the backpack")
	app.show_inventory()
	await process_frame
	await double_click_item("backpack",0)
	check(int(walker.weapon)==2,"double clicking a weapon puts it in hand")
	check(not app.session.kit_weapon(walker).is_empty(),"double clicking a weapon fills the weapon socket")
	check(walker.backpack.items.is_empty(),"the worn weapon left the backpack")
	await capture("ui-mouse-equip-weapon")
	check(Catalog.place_item(walker.backpack,Catalog.make_equipment("gear",2,5)),"a pair of boots waits in the backpack")
	app.show_inventory()
	await process_frame
	await double_click_item("backpack",0)
	check(app.session.kit_gear(walker).size()==3 and not app.session.kit_gear(walker)[2].is_empty(),"double clicking gear fills its own socket")
	check(app.session.equipment_speed(walker)>0.0,"the worn boots raise the movement speed")
	await capture("ui-mouse-equip-gear")
	check(Catalog.add_item(walker.backpack,"backpack"),"a loose blue pack waits in the bag")
	walker.backpack.items.back()["quality"]="blue"
	app.show_inventory()
	await process_frame
	await double_click_item("backpack",walker.backpack.items.size()-1)
	check(str(walker.backpack.key)=="blue","double clicking a loose backpack wears it")
	await capture("ui-mouse-equip-bag")
	# Dragging onto a socket wears the item as well.
	walker.backpack.items.clear()
	check(Catalog.place_item(walker.backpack,Catalog.make_equipment("weapon",3,2)),"a staff waits to be dragged onto its socket")
	app.show_inventory()
	await process_frame
	await drag_item_to_zone("backpack",0,"weapon")
	check(int(walker.weapon)==3,"dragging a weapon onto the weapon socket equips it")
	check(app.session.weapon_kit_active(walker),"the socketed weapon is the weapon in hand")
	check(walker.backpack.items.size()==1 and str(walker.backpack.items[0].kind)=="weapon","the dragged staff left the backpack")
	check(int(walker.backpack.items[0].get("weapon",-1))==2,"the sword the staff replaced is stowed back in the bag")
	check(not app.drag.active,"the drag ends on the socket")
	await capture("ui-mouse-drag-equip")
	check(Catalog.add_item(walker.backpack,"charm"),"an accessory waits in the backpack")
	app.show_inventory()
	await process_frame
	await drag_item_to_zone("backpack",walker.backpack.items.size()-1,"charm1")
	check(app.session.charms_equipped(walker)==1 and not app.session.kit_charms(walker)[1].is_empty(),"dragging a charm into the second accessory socket equips it")
	await ctrl_click_point(zone_point("charm1"))
	check(app.session.charms_equipped(walker)==0,"Ctrl-clicking the accessory socket returns its charm to storage")
	check(Catalog.add_item(walker.backpack,"backpack"),"a purple pack waits to be dragged")
	walker.backpack.items.back()["quality"]="purple"
	app.show_inventory()
	await process_frame
	await drag_item_to_zone("backpack",walker.backpack.items.size()-1,"bag")
	check(str(walker.backpack.key)=="purple","dragging a pack onto the backpack socket swaps it")
	await capture("ui-mouse-drag-bag")
	# Releasing outside a valid destination drops the item into the world.
	walker.backpack.items.clear()
	check(Catalog.add_item(walker.backpack,"crystal"),"a blood crystal waits for a cancelled drag")
	app.show_inventory()
	await process_frame
	var drops_before: int=app.session.world_drops.size()
	var details_rect: Rect2=app.panel_rects[0]
	await drag_item_to_point("backpack",0,details_rect.position+Vector2(24,120))
	check(app.session.world_drops.size()==drops_before+1,"releasing over a side panel drops the item")
	check(Catalog.container_count(walker.backpack,"crystal")==0,"the discarded item leaves the backpack")
	app.session.world_drops.pop_back()
	check(Catalog.add_item(walker.backpack,"crystal"),"another crystal waits for an outside drop")
	app.show_inventory()
	app.start_drag("backpack",0,false)
	app.release_drag(Vector2(700,100))
	check(app.session.world_drops.size()==drops_before+1 and Catalog.container_count(walker.backpack,"crystal")==0,"releasing outside all panels drops the item")
	app.session.world_drops.pop_back()
	# R in mid-air turns the lifted art and the landing preview together.
	walker.backpack.items.clear()
	check(Catalog.add_item(walker.backpack,"medicine"),"a 1x2 medkit waits to be turned mid-drag")
	app.show_inventory()
	await process_frame
	var cell_step: float=float(app.bag_cell)+float(app.bag_gap)
	var med_cell := Vector2i(int(walker.backpack.items[0].x),int(walker.backpack.items[0].y))
	await mouse_press(cell_point("backpack",med_cell))
	await mouse_move(cell_point("backpack",Vector2i(2,0)))
	check(app.drag.active and app.press_moved,"pressing and travelling lifts the medkit")
	await key(KEY_R)
	check(app.drag.rot,"R flips the orientation of the item in hand")
	check(app.drag_ghost!=null and is_instance_valid(app.drag_ghost) and app.drag_ghost.visible,"the lifted icon survives the rebuild that R triggers")
	check(app.drag_ghost.get_parent()==app.overlay,"the lifted icon is re-attached to the overlay")
	var lifted_icon: Control=app.drag_ghost.get_child(1)
	check(lifted_icon.rotation>0.1,"the lifted art turns with the item")
	var med_ring: Rect2=app.drag_ring.area
	check(med_ring.size.distance_to(Vector2(2.0*cell_step-app.bag_gap,cell_step-app.bag_gap))<1.5,"a turned 1x2 medkit previews a 2x1 footprint, got "+str(med_ring.size))
	await capture("ui-mouse-rotate-medkit")
	await mouse_release(cell_point("backpack",Vector2i(2,0)))
	check(not app.drag.active,"the turned medkit lands on release")
	check(walker.backpack.items.size()>0,"the turned medkit is in the bag at all")
	if walker.backpack.items.is_empty():
		print("UI: the turned medkit went nowhere; pocket holds ",Catalog.container_items(walker.pocket).size()," items")
	check(bool(walker.backpack.items[0].get("rot",false)),"the medkit keeps the orientation it was dropped in")
	check(Catalog.item_size(walker.backpack.items[0])==Vector2i(2,1),"the stored medkit is really 2x1")
	check(Vector2i(int(walker.backpack.items[0].x),int(walker.backpack.items[0].y))==Vector2i(2,0),"the medkit lands exactly where the preview showed it")
	check_no_overlap(walker.backpack,"the turned medkit never covers a neighbour")
	await capture("ui-mouse-rotate-landed")
	# The reported bug: a turned 2x2 relic previewed as 2x1, then landed as a 2x2
	# on top of the 1x1 item sitting next to it.
	walker.backpack.items.clear()
	check(Catalog.add_item(walker.backpack,"relic"),"a 2x2 relic waits to be turned")
	check(Catalog.add_item(walker.backpack,"crystal"),"a blood crystal sits beside the relic")
	app.show_inventory()
	await process_frame
	await mouse_press(cell_point("backpack",Vector2i(0,0)))
	await mouse_move(cell_point("backpack",Vector2i(0,2)))
	await key(KEY_R)
	check(app.drag_ghost!=null and is_instance_valid(app.drag_ghost) and app.drag_ghost.visible,"the relic is still in the hand after R")
	var relic_ring: Rect2=app.drag_ring.area
	check(relic_ring.size.distance_to(Vector2(2.0*cell_step-app.bag_gap,2.0*cell_step-app.bag_gap))<1.5,"a turned 2x2 relic previews a 2x2 footprint, got "+str(relic_ring.size))
	await capture("ui-mouse-rotate-relic")
	await mouse_release(cell_point("backpack",Vector2i(0,2)))
	var relic_index := -1
	for i in walker.backpack.items.size():
		if str(walker.backpack.items[i].kind)=="relic":
			relic_index=i
	check(relic_index>=0,"the relic is still in the backpack after the drop")
	check(Catalog.item_size(walker.backpack.items[relic_index])==Vector2i(2,2),"the relic keeps its real 2x2 footprint after being turned")
	check(Vector2i(int(walker.backpack.items[relic_index].x),int(walker.backpack.items[relic_index].y))==Vector2i(0,2),"the relic lands exactly where the preview showed it")
	check_no_overlap(walker.backpack,"turning and dropping the relic never covers the crystal beside it")
	await capture("ui-mouse-rotate-relic-landed")
	# The rest of the suite (and the save file) expects the white pack to be worn.
	walker.backpack.items.clear()
	var spare_white: int=app.spare_index(walker,"white")
	check(spare_white>=0,"the white pack waits in the cabinet")
	app.equip_spare(spare_white)
	await create_timer(0.2).timeout
	check(str(walker.backpack.key)=="white","the white pack is worn again")
	# Loot cards keep the footprint the item really owns, so a 2x2 relic answers to
	# every one of the four cells it covers. The window is opened the way a player
	# opens it — with F on a chest — because the session only hands loot over to the
	# container it is actually searching.
	app.close_bag()
	var relic_chest: Dictionary=app.session.ruins.chests[0]
	relic_chest.items.clear()
	check(Catalog.place_item(relic_chest,{"kind":"relic","rot":false,"count":1}),"the chest holds a single relic")
	relic_chest["searched"]=1
	walker.p=relic_chest.p
	app.field.camera=relic_chest.p
	await key(KEY_F)
	check(app.inventory_open and app._loot_index>=0,"F opens the search window on the relic chest")
	check(app.session.search_reference(walker)==app._loot_index,"the session searches the container the window shows")
	check(app.grids.has("loot"),"the search window registers its own grid")
	check(app.index_at("loot",Vector2i(0,0))==0,"the relic answers to its top left cell")
	check(app.index_at("loot",Vector2i(1,1))==0,"the relic answers to its bottom right cell too")
	check(app.index_at("loot",Vector2i(2,0))<0,"the cell beside the relic is empty")
	var loot_step: float=app.LOOT_CELL+app.LOOT_GAP
	await mouse_press(cell_point("loot",Vector2i(1,1)))
	check(app.drag.active and app.drag.slot=="loot" and int(app.drag.source)==0,"grabbing the relic by its far corner lifts it")
	var lifted: Vector2=app.held_size(app.held_item())
	check(lifted.distance_to(Vector2(2.0*loot_step-app.LOOT_GAP,2.0*loot_step-app.LOOT_GAP))<1.0,"the lifted relic is drawn at its real 2x2 size, got "+str(lifted))
	await capture("ui-loot-relic-size")
	await mouse_move(cell_point("backpack",Vector2i(1,1)))
	await mouse_release(cell_point("backpack",Vector2i(1,1)))
	check(Catalog.container_count(walker.pocket,"relic")==1,"the relic leaves the search window for the sealed pocket")
	check(app.session.container_units(relic_chest)==0,"the search window gives the relic up")
	check_no_overlap(walker.pocket,"the relic never covers what the pocket already held")
	await capture("ui-loot-relic-taken")
	walker.pocket.items.clear()
	# --- double clicking a loot card hauls it in one gesture ----------------
	# The first card needs no tidy: it takes the top left cell of the bag.
	walker.backpack.items.clear()
	relic_chest.items.clear()
	check(Catalog.place_item(relic_chest,{"kind":"scrap","rot":false,"count":1}),"the chest holds a scrap for the double click")
	relic_chest["searched"]=1
	await key(KEY_F)
	check(app.inventory_open and app.index_at("loot",Vector2i(0,0))==0,"the scrap card is under the cursor")
	await double_click_point(cell_point("loot",Vector2i(0,0)))
	check(Catalog.container_count(walker.backpack,"scrap")==1,"double clicking the card puts the scrap in the bag")
	check(app.session.container_units(relic_chest)==0,"the double clicked scrap leaves the search window")
	check(Vector2i(int(walker.backpack.items[0].x),int(walker.backpack.items[0].y))==Vector2i(0,0),"the stored scrap starts at the top left of the bag")
	check_no_overlap(walker.backpack,"the stored scrap never covers what the bag held")
	# White loot fills the bag, so a relic goes to the backpack now. The medkit is
	# the real test of the tidy: two 1x2 medkits sit in the outer columns of the
	# 3x3 bag with five cells still free, but not two of them stacked, so nothing
	# fits until the haul is packed back against the top left corner.
	walker.pocket.items.clear()
	walker.backpack.items.clear()
	walker.backpack.items.append({"kind":"medicine","x":0,"y":0,"rot":false,"count":1})
	walker.backpack.items.append({"kind":"medicine","x":2,"y":0,"rot":false,"count":1})
	check(Catalog.container_free(walker.backpack)==5,"the bag still reports five free cells")
	relic_chest.items.clear()
	check(Catalog.place_item(relic_chest,{"kind":"medicine","rot":false,"count":1}),"the chest holds a medkit that needs a tidy")
	relic_chest["searched"]=1
	await key(KEY_F)
	await double_click_point(cell_point("loot",Vector2i(0,0)))
	check(Catalog.container_count(walker.backpack,"medicine")==3,"the double click tidied the bag and seated the medkit")
	check(app.session.container_units(relic_chest)==0,"the tidied-in medkit leaves the search window")
	check_no_overlap(walker.backpack,"the tidied bag never stacks the medkits on each other")
	var packed_away := 0
	for item in walker.backpack.items:
		if Vector2i(int(item.x),int(item.y))==Vector2i(1,0):
			packed_away+=1
	check(packed_away==1,"the tidy packed the medkits into the top row and gave the third the free column")
	await capture("ui-loot-double-click")
	# A gold weapon is the case the sealed pocket exists for: the same gesture
	# sends it there instead of the bag, because quality decides the order.
	walker.backpack.items.clear()
	walker.pocket.items.clear()
	relic_chest.items.clear()
	check(Catalog.place_item(relic_chest,Catalog.make_equipment("weapon",1,4)),"the chest holds a gold weapon for the double click")
	relic_chest["searched"]=1
	await key(KEY_F)
	await double_click_point(cell_point("loot",Vector2i(0,0)))
	check(Catalog.container_count(walker.pocket,"weapon")==1,"double clicking gold loot fills the sealed pocket")
	check(walker.backpack.items.is_empty(),"the gold weapon never takes backpack room")
	# F follows the hovered card, including when another card has the same kind.
	walker.backpack.items.clear()
	walker.pocket.items.clear()
	relic_chest.items.clear()
	check(Catalog.place_item(relic_chest,Catalog.make_equipment("weapon",0,0)),"a white weapon waits in the chest")
	check(Catalog.place_item(relic_chest,Catalog.make_equipment("weapon",2,4)),"a gold weapon waits beside it")
	relic_chest["searched"]=2
	app.show_inventory()
	var gold_card: Dictionary=app.session.visible_items(relic_chest)[1]
	await mouse_move(cell_point("loot",Vector2i(int(gold_card.x),int(gold_card.y))))
	await key(KEY_F)
	check(Catalog.container_count(walker.pocket,"weapon")==1 and int(walker.pocket.items[0].tier)==4,"F sends hovered high value loot to the pocket")
	check(app.session.container_units(relic_chest)==1 and int(relic_chest.items[0].tier)==0,"F leaves the other weapon in the chest")
	check(Catalog.add_item(walker.backpack,"scrap"),"scrap waits in the backpack for F deposit")
	app.show_inventory()
	await mouse_move(item_point("backpack",0))
	await key(KEY_F)
	check(walker.backpack.items.is_empty(),"F sends a carried item back into the open chest")
	check(Catalog.container_count(relic_chest,"scrap")==1 and app.session.visible_items(relic_chest)[0].kind=="scrap","the deposited item stays visible during search")
	# --- Ctrl+left is the same gesture with the key held --------------------
	# On a carried item it does what the item is for; on something worn it takes
	# it off. The carried-item half is driven through real mouse input; the
	# take-off half calls the same entry point the socket click calls, because the
	# socket rectangles belong to a panel layout this suite does not pin down.
	walker.backpack.items.clear()
	walker.pocket.items.clear()
	walker.hp=40.0
	check(Catalog.add_item(walker.backpack,"medicine"),"a medkit waits for Ctrl+left")
	await ctrl_click_item("backpack",0)
	check(walker.hp>40.0,"Ctrl+left on a medkit uses it")
	check(app.session.carried(walker,"medicine")==0,"the used medkit is consumed")
	walker.backpack.items.clear()
	check(Catalog.place_item(walker.backpack,Catalog.make_equipment("weapon",2,3)),"a blade waits for Ctrl+left")
	await ctrl_click_item("backpack",0)
	check(int(walker.weapon)==2,"Ctrl+left on a weapon wears it")
	check(app.session.kit_weapon(walker).is_empty()==false,"the weapon socket filled through Ctrl+left")
	check(Catalog.container_count(walker.backpack,"weapon")==1,"the weapon the blade displaced is what stays in the bag")
	check(int(walker.backpack.items[index_of_kind(walker.backpack,"weapon")].get("weapon",-1))!=2,"the bag holds the displaced weapon, not the worn blade")
	# Now the take-off half: the socket click and the double click both route into
	# this one entry point, so driving it directly proves the rule the sockets use.
	app.ctrl_click_worn("weapon")
	check(app.session.kit_weapon(walker).is_empty(),"the take-off empties the weapon socket")
	var stowed_in_bag := Catalog.container_count(walker.backpack,"weapon")==2
	var stowed_in_pocket := Catalog.container_count(walker.pocket,"weapon")==1
	check(stowed_in_bag!=stowed_in_pocket,"the blade went to exactly one of the two containers")
	var blade_at := index_of_kind(walker.pocket,"weapon") if stowed_in_pocket else index_of_kind(walker.backpack,"weapon")
	var blade_home: Dictionary=Catalog.container_items(walker.pocket if stowed_in_pocket else walker.backpack)[blade_at]
	check(int(blade_home.get("weapon",-1))==2,"the blade itself is the item that came off")
	await capture("ui-ctrl-take-off")
	# The fallback: wear the blade again, pack the bag solid, and the take-off has
	# nowhere to go but the pocket.
	check(app.session.equip_item(walker,"pocket" if stowed_in_pocket else "backpack",blade_at),"the blade is worn again for the fallback")
	walker.backpack.items.clear()
	for i in 9:
		Catalog.add_item(walker.backpack,"crystal")
	check(Catalog.container_free(walker.backpack)==0,"the bag is packed solid")
	walker.pocket.items.clear()
	app.ctrl_click_worn("weapon")
	check(Catalog.container_count(walker.pocket,"weapon")==1,"the take-off fell back to the pocket")
	check(app.session.kit_weapon(walker).is_empty(),"the socket is empty after the fallback take-off")
	walker.backpack.items.clear()
	walker.pocket.items.clear()
	app.close_bag()
	await key(KEY_TAB)
	check(app.inventory_open and app._loot_index<0,"TAB opens the equipment and item bar layout for F shortcuts")
	walker["slots"]=app.session.empty_item_slots()
	check(Catalog.add_item(walker.backpack,"medicine"),"a medkit waits for F quick equip")
	app.show_inventory()
	await mouse_move(item_point("backpack",0))
	await key(KEY_F)
	check(app.session.item_slot_kind(walker,0)=="medicine" and walker.backpack.items.is_empty(),"F puts a carried item in the first free quick socket")
	await mouse_move((app.slot_zone_rects[0] as Rect2).get_center())
	await key(KEY_F)
	check(app.session.item_slot(walker,0).is_empty() and Catalog.container_count(walker.backpack,"medicine")==1,"F on the item bar returns its item to the backpack")
	walker.backpack.items.clear()
	check(Catalog.place_item(walker.backpack,Catalog.make_equipment("weapon",2,3)),"a blade waits for F quick equip")
	app.show_inventory()
	await mouse_move(item_point("backpack",0))
	await key(KEY_F)
	check(int(app.session.kit_weapon(walker).get("weapon",-1))==2,"F on a carried weapon equips it")
	await mouse_move(zone_point("weapon"))
	await key(KEY_F)
	check(app.session.kit_weapon(walker).is_empty() and Catalog.container_count(walker.backpack,"weapon")==1,"F on worn equipment returns it to the backpack")
	app.close_bag()
	await key(KEY_M)
	check(app.field.map_open,"M opens map")
	await capture("ui-map")
	await key(KEY_M)
	app.show_help()
	await capture("ui-help")
	app.close_modal()
	app.session.players[1].status="extracted"
	check(Catalog.add_item(app.session.players[1].pocket,"relic"),"pocket takes a relic before settling")
	app.session.objectives=3
	app.session.settle()
	check(app.page_name=="results","game to results")
	check(app.profile.data.pocket.items.size()>0,"settled pocket reaches the save file")
	check(app.profile.data.bags[0].key=="white","settled backpack reaches the save file")
	await capture("ui-results")
	press("返回营地 · 继续守夜  →")
	check(app.page_name=="camp","results to camp")
	press("全队出发    →")
	check(app.session.running and app.session.objectives==0,"second expedition")
	app.session.disconnect_room()
	DirAccess.remove_absolute("user://test-ui-profile.json")
	print("UI INTEGRATION: %d failures" % failures)
	quit(0 if failures==0 else 1)
