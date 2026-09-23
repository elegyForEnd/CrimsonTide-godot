extends SceneTree

var failures := 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures+=1
		push_error("ACCESSORY FAIL: "+description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.session.solo({"name":"Accessory test","hero":0,"talents":[0,0,0]})
	check(app.session.launch(false,7),"the solo run launches")
	var p: Dictionary=app.session.players[1]
	p.backpack.items.clear()
	app.inventory_open=true
	app.show_inventory()
	check(app.equip_zones.has("charm0") and app.equip_zones.has("charm1"),"both accessory sockets are visible drop zones")
	check(Catalog.add_item(p.backpack,"charm"),"a charm fits in the backpack")
	app.show_inventory()
	var charm_index: int=p.backpack.items.size()-1
	app.drag={"active":true,"slot":"backpack","source":charm_index,"rot":false}
	app.release_drag((app.equip_zones["charm1"] as Rect2).get_center())
	check(app.session.charms_equipped(p)==1 and not app.session.kit_charms(p)[1].is_empty(),"dragging to the second socket equips the charm")
	check(p.backpack.items.is_empty(),"the equipped charm leaves the backpack")
	app.ctrl_click_worn("charm1")
	check(app.session.charms_equipped(p)==0 and Catalog.container_count(p.backpack,"charm")==1,"Ctrl-clicking the socket returns the charm to storage")
	app.queue_free()
	print("ACCESSORY TESTS: %d failures" % failures)
	quit(0 if failures==0 else 1)
