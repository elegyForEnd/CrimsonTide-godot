extends SceneTree
const Equipment = preload("res://scripts/rogue_equipment.gd")
func _initialize() -> void: call_deferred("run")
func capture(tag: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/rogue-equipment-"+tag+".png")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-equipment-visual.json"
	root.add_child(app)
	await process_frame
	var s=app.session
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	s.roguelike.equip(s,p,Equipment.engrave(Catalog.make_equipment("weapon",11,5),0))
	for index in [2,4,8]: s.roguelike.equip(s,p,Equipment.make_gear(index,5))
	for index in 12: p.rogue_stash.append(Equipment.make_gear(index,3))
	app.toggle_bag()
	await capture("inventory")
	app.rogue_inventory.show_tooltip(p.equipped.weapon,false)
	await capture("weapon")
	app.rogue_inventory.hide_tooltip()
	app.rogue_inventory.show_tooltip(p.equipped.gear[0],false)
	await capture("armor")
	app.close_bag()
	s.enemies.clear()
	s.roguelike.clear_room(s)
	preload("res://tests/rogue_reward_flow.gd").pick(s,p)
	p.rogue_selection.offers=[]
	for index in [0,2,4]:
		var item := Equipment.make_gear(index,5)
		p.rogue_selection.offers.append({"name":Catalog.item_name(item),"desc":Equipment.description(item),"item":item,"price":0})
	p.rogue_selection.tier=5
	s.raid.revision+=1
	app.update_rogue_hud(p)
	await capture("rewards")
	app.queue_free()
	await process_frame
	quit()
