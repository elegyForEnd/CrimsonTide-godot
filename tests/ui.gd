extends SceneTree

var app: Node
var failures := 0

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

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-ui-profile.json"
	app.profile.data.hero=0
	await create_timer(0.5).timeout
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
	for choice in [[KEY_1,1],[KEY_2,2],[KEY_3,3],[KEY_4,0]]:
		await key(choice[0])
		check(app.session.players[1].weapon==choice[1],"weapon hotkey reaches authoritative session")
	await key(KEY_1)
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
	check(Catalog.container_count(app.session.players[1].backpack,"crystal")>0,"swapping backpacks keeps loot")
	await capture("ui-inventory-equipped")
	await key(KEY_TAB)
	check(not app.inventory_open,"Tab closes inventory")
	# --- searching a container and dragging loot out ------------------------
	var walker: Dictionary=app.session.players[1]
	app.session.spawn_timer=9999
	app.session.enemies.clear()
	walker.backpack.items.clear()
	var chest: Dictionary=app.session.ruins.chests[0]
	walker.p=chest.p
	app.field.camera=chest.p
	await create_timer(0.2).timeout
	await key(KEY_F)
	check(app.inventory_open,"F opens the inventory together with the search window")
	check(app._loot_index==0,"the search window points at the chest")
	check(app.session.container_units(chest)>0 and app.session.visible_units(chest)==0,"nothing is revealed when the search starts")
	await capture("ui-loot-search")
	check(app.session.container_units(chest)>0,"the container is stocked once the search starts")
	check(app.session.visible_units(chest)==0,"a fresh container starts with nothing revealed")
	# The search advances on its own: one unit roughly every 1.2 seconds.
	await create_timer(1.5).timeout
	check(app.session.visible_units(chest)>=1,"loot surfaces by itself while the search window is open")
	check(app.session.visible_units(chest)<app.session.container_units(chest),"a container is not searched instantly")
	await capture("ui-loot-revealed")
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
