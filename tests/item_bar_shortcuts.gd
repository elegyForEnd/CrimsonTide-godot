extends SceneTree

var app: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("ITEM BAR SHORTCUTS: "+message)

func key(code: int, pressed: bool = true, echo: bool = false, logical: bool = false) -> void:
	var event := InputEventKey.new()
	if logical:
		event.keycode=code
	else:
		event.physical_keycode=code
	event.pressed=pressed
	event.echo=echo
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-item-bar-shortcuts-profile.json"
	await process_frame
	app.session.solo({"hero":0})
	app.session.launch(false,4242)
	app.session.enemies.clear()
	app.session.spawn_timer=99999
	app.page_name="game"
	await process_frame
	var p: Dictionary=app.session.players[1]
	p.hp=40.0
	app.session.set_item_slot(p,0,{"kind":"medicine"})
	await key(KEY_1)
	check(int(p.hp)==85,"1 heals on key down without F")
	check(app.session.item_slot(p,0).is_empty(),"1 consumes only its own slot")
	app.session.set_item_slot(p,0,{"kind":"medicine"})
	await key(KEY_1,true,true)
	check(not app.session.item_slot(p,0).is_empty(),"key repeat does not consume another item")
	await key(KEY_1,false)
	check(not app.session.item_slot(p,0).is_empty(),"key release does not consume another item")
	app.session.set_item_slot(p,1,Catalog.make_equipment("weapon",2,4))
	app.toggle_bag()
	await key(KEY_2)
	await key(KEY_2,false)
	check(int(p.weapon)==2,"2 equips its weapon while the bag is open")
	check(app.session.item_slot(p,1).is_empty(),"the temporary weapon leaves no item behind")
	app.close_bag()
	var reserve_before: int=p.reserve
	app.session.set_item_slot(p,2,{"kind":"ammo"})
	await key(KEY_3,true,false,true)
	await key(KEY_3,false,false,true)
	check(int(p.reserve)==reserve_before+48,"3 uses ammo with logical keycode fallback")
	check(app.session.item_slot(p,2).is_empty(),"3 consumes its ammo")
	app.session.set_item_slot(p,2,{"kind":"relic"})
	await key(KEY_3)
	await key(KEY_3,false)
	check(app.session.item_slot(p,2).kind=="relic","treasure stays in its slot")
	check(not app.session.item_slot(p,0).is_empty(),"empty or inert slots do not fall back to healing")
	app.field.map_open=true
	await key(KEY_1)
	await key(KEY_1,false)
	check(not app.session.item_slot(p,0).is_empty(),"map number keys do not use items")
	app.field.map_open=false
	app.modal=true
	await key(KEY_1)
	await key(KEY_1,false)
	check(not app.session.item_slot(p,0).is_empty(),"modal number keys do not use items")
	app.modal=false
	app.session.disconnect_room()
	DirAccess.remove_absolute("user://test-item-bar-shortcuts-profile.json")
	print("ITEM BAR SHORTCUTS: %d checks, %d failures" % [checks,failures])
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
