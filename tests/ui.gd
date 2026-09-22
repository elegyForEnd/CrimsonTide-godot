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
	for kind in Catalog.ITEMS:
		Catalog.insert(app.session.players[1].bag,kind)
	for i in 4:
		app.session.spawn_enemy(Vector2(1700+i*95,1110),i)
	await create_timer(0.5).timeout
	for choice in [[KEY_1,1],[KEY_2,2],[KEY_3,3],[KEY_4,0]]:
		await key(choice[0])
		check(app.session.players[1].weapon==choice[1],"weapon hotkey reaches authoritative session")
	await key(KEY_1)
	await capture("ui-game")
	await key(KEY_TAB)
	check(app.inventory_open,"Tab opens inventory through input system")
	await capture("ui-inventory")
	app.selected=2
	app.show_inventory()
	await capture("ui-inventory-selected")
	await key(KEY_TAB)
	check(not app.inventory_open,"Tab closes inventory")
	await key(KEY_M)
	check(app.field.map_open,"M opens map")
	await capture("ui-map")
	await key(KEY_M)
	app.show_help()
	await capture("ui-help")
	app.close_modal()
	app.session.players[1].status="extracted"
	Catalog.insert(app.session.players[1].bag,"relic")
	app.session.objectives=3
	app.session.settle()
	check(app.page_name=="results","game to results")
	await capture("ui-results")
	press("返回营地 · 继续守夜  →")
	check(app.page_name=="camp","results to camp")
	press("全队出发    →")
	check(app.session.running and app.session.objectives==0,"second expedition")
	app.session.disconnect_room()
	DirAccess.remove_absolute("user://test-ui-profile.json")
	print("UI INTEGRATION: %d failures" % failures)
	quit(0 if failures==0 else 1)
