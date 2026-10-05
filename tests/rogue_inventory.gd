extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func command(s, source: String, index: int, verb: String, version: int = -1) -> void:
	s.perform(1,"rogue_inventory",{"source":source,"index":index,"verb":verb,"version":s.players[1].rogue_inventory_revision if version<0 else version})
func capture(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/rogue-inventory-"+tag+".png")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-inventory.json"
	root.add_child(app)
	await process_frame
	var s=app.session
	s.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2})
	s.launch(false,1729)
	s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	check(p.backpack.items.is_empty() and p.pocket.items.is_empty(),"Run supplies use independent count, no extraction grids")
	check(s.carried(p,"medicine")==1,"One starting medicine")
	s.perform(1,"heal")
	check(s.carried(p,"medicine")==1,"Full health cannot waste medicine")
	p.hp=20
	s.perform(1,"heal")
	check(p.hp==65 and s.carried(p,"medicine")==0,"Heal consumes counter once")
	s.perform(1,"heal")
	check(p.hp==65,"Empty supply cannot heal")
	p.rogue_medicine=1
	p.status="down"; p.hp=0
	s.perform(1,"heal")
	check(p.status=="active" and not p.self_revive and p.hp==45,"Dedicated supply supports self-revive")
	s.roguelike.equip(s,p,Catalog.make_equipment("weapon",1,2))
	s.roguelike.equip(s,p,Catalog.make_equipment("weapon",2,3))
	check(p.rogue_stash.size()==1 and p.rogue_stash[0].weapon==1,"Replaced weapon preserved")
	p.ammo=3; p.reserve=21
	var stale: int=p.rogue_inventory_revision
	command(s,"reserve",0,"equip")
	check(p.weapon==1 and p.rogue_stash.size()==1 and p.rogue_stash[0].weapon==2,"Reserve weapon swaps atomically")
	check(p.ammo==3 and p.reserve==21,"Swapping cannot refill ammunition")
	command(s,"reserve",0,"discard",stale)
	check(p.rogue_stash.size()==1,"Stale menu cannot discard a different item")
	command(s,"reserve",99,"discard")
	check(p.rogue_stash.size()==1,"Invalid index rejected")
	p.pending_strike=true
	command(s,"reserve",0,"equip")
	check(p.weapon==1,"Cannot swap during pending attack")
	p.pending_strike=false
	s.roguelike.equip(s,p,Catalog.make_equipment("gear",0,3))
	p.hp=30
	command(s,"equipped",1,"stow")
	command(s,"reserve",p.rogue_stash.size()-1,"equip")
	check(p.hp==30,"Armour swaps cannot heal")
	command(s,"equipped",0,"stow")
	check(p.equipped.weapon.is_empty() and Catalog.is_starter(p.weapon),"Stowed weapon restores starter")
	var size_before: int=p.rogue_stash.size()
	command(s,"equipped",0,"discard")
	check(p.rogue_stash.size()==size_before,"Starter cannot be discarded")
	command(s,"reserve",0,"discard")
	check(p.rogue_stash.size()==size_before-1,"Discard removes exactly one reserve item")
	s.perform(1,"unequip_stow",{"type":"gear","index":0})
	check(not p.equipped.gear[0].is_empty(),"Extraction storage actions rejected in rogue mode")
	s.roguelike.clear_room(s)
	preload("res://tests/rogue_reward_flow.gd").pick(s,p)
	p.rogue_selection.offers=[{"boon":s.roguelike.BOONS[0],"name":"test","desc":"","price":0}]
	s.perform(1,"rogue_selection_take",{"index":0,"id":p.rogue_selection.id,"version":p.rogue_selection.version})
	check(p.rogue_boons.rogue_damage==1 and is_equal_approx(p.rogue_damage,0.12),"Boon tally follows actual reward")
	app.toggle_bag()
	check(app.inventory_open and app.grids.is_empty(),"TAB opens independent build inventory")
	check(app.rogue_inventory.stats_label.text.contains("攻击间隔"),"Live combat attributes shown")
	await capture("overview")
	for i in 17: p.rogue_stash.append(Catalog.make_equipment("weapon",i%4,i%6))
	app.show_inventory()
	await capture("filled")
	for hero in 4:
		p.hero=hero
		app.show_inventory()
		await capture("hero-%d" % hero)
	p.hero=0
	app.show_inventory()
	var tile: Control
	for child in app.overlay.get_children():
		if child.name=="ReserveSlot0": tile=child
	var motion := InputEventMouseMotion.new()
	motion.position=tile.get_global_transform_with_canvas()*Vector2(90,50)
	root.push_input(motion)
	await process_frame
	check(is_instance_valid(app.rogue_inventory.tooltip),"Detailed tooltip opens")
	await capture("tooltip")
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_RIGHT
	click.pressed=true
	click.position=motion.position
	root.push_input(click)
	await process_frame
	check(is_instance_valid(app.rogue_inventory.menu),"Right-click menu opens")
	await capture("menu")
	click.pressed=false
	root.push_input(click)
	var before_confirmation: int=p.rogue_stash.size()
	var menu_box: Control=app.rogue_inventory.menu.get_child(0)
	for child in menu_box.get_children():
		if child is Button and child.text=="丢弃此物品…": child.pressed.emit()
	check(p.rogue_stash.size()==before_confirmation,"Discard menu requires confirmation")
	await capture("discard-confirm")
	for child in menu_box.get_children():
		if child is Button and child.text=="确认丢弃": child.pressed.emit()
	check(p.rogue_stash.size()==before_confirmation-1,"Confirmation button discards selected item")
	app.rogue_inventory.close_menu()
	app.rogue_inventory.reserve_page=1
	app.show_inventory()
	check(app.rogue_inventory.reserve_page==1,"Reserve paginates")
	app.rogue_inventory.selected_tab="boons"
	app.show_inventory()
	await capture("boons")
	var design=preload("res://scripts/rogue_equipment.gd")
	app.rogue_inventory.show_tooltip(design.engrave(Catalog.make_equipment("weapon",3,5),3),false)
	await capture("engraved-tooltip")
	app.close_bag()
	check(not app.inventory_open and app.overlay.get_child_count()==0,"Closing clears inventory and popovers")
	var tab := InputEventKey.new()
	tab.physical_keycode=KEY_TAB
	tab.pressed=true
	root.push_input(tab)
	check(app.inventory_open,"Actual TAB event opens inventory")
	tab.pressed=false
	root.push_input(tab)
	tab.pressed=true
	root.push_input(tab)
	check(not app.inventory_open,"Actual TAB event closes inventory")
	p.rogue_medicine=1
	command(s,"supply",0,"discard")
	check(p.rogue_medicine==0,"Supply menu discards one medicine")
	app.queue_free()
	await process_frame
	print("ROGUE INVENTORY %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
