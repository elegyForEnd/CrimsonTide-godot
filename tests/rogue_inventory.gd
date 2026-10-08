extends SceneTree
var checks := 0
var failures := 0
## Set as the very last statement of `_body()`; see `run()` below.
var completed := false
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
## Same safety net as `tests/roguelike.gd`: a runtime error aborts `_body()`, and without this
## wrapper the SceneTree keeps spinning forever (the old TIMEOUT symptom) instead of going red.
func run() -> void:
	await _body()
	check(completed,"the run reached the end of the body (a SCRIPT ERROR aborts `_body()` and skips the rest)")
	print("ROGUE INVENTORY %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _body() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-inventory.json"
	root.add_child(app)
	await process_frame
	var s=app.session
	var Build = preload("res://scripts/rogue_build.gd")
	s.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2})
	s.launch(false,1729)
	s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	check(p.backpack.items.is_empty() and p.pocket.items.is_empty(),"Run supplies use independent count, no extraction grids")
	# 血瓶（flask）模型：魔境治疗不再是"急救针计数"——carried("medicine")=flask/25（session.gd:683），
	# heal→RogueBuild.drink()（session.gd:1655-1657）起 0.75s 通道并上 2.5s CD（rogue_build.gd:812-819）；
	# tick 把通道推到 <=0.3s 时置 pending（rogue_build.gd:862-865），commit_flask 结算
	# （rogue_build.gd:1235-1249：耗 25 flask、+30% 上限生命）。物理已被关掉（见上），所以手动
	# 走一次 tick 把通道推到位再直接 commit——与 tests/rogue_build_rules.gd 断言的是同一契约。
	check(s.carried(p,"medicine")==4,"Run starts with a full flask: 100 points = four charges")
	s.perform(1,"heal")
	check(p.flask==100 and p.flask_time<=0,"Full health cannot start a drink")
	p.hp=20
	s.perform(1,"heal")
	check(p.flask_time>0 and p.flask==100 and p.hp==20,"A hurt drink opens the channel; the heal lands on commit")
	Build.tick(s,p,3.0)
	Build.commit_flask(s,p)
	check(p.flask==75 and s.carried(p,"medicine")==3 and is_equal_approx(p.hp,20.0+p.max_hp*.3),"The committed drink spends 25 flask and heals 30% of the ceiling")
	p.flask=20
	s.perform(1,"heal")
	check(p.flask_time<=0 and p.flask==20,"Below 25 flask no drink starts")
	p.status="down"; p.hp=0
	s.perform(1,"heal")
	check(p.status=="down" and p.flask==20,"A downed watcher cannot drink — the flask is not a revive tool")
	# Revival is the soul lamp now: hold the flask input for two seconds while down
	# (rogue_build.gd:848-855), once per run. This also restores status="active", which every
	# rogue_* command needs (roguelike.gd:1209 gates the whole choose() entry on it).
	s.inputs[p.id]={"flask_held":true}
	Build.tick(s,p,2.0)
	s.inputs[p.id]={}
	check(p.status=="active" and not p.soul_lamp and is_equal_approx(p.hp,p.max_hp*.25),"Holding the lamp for two seconds revives once per run")
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
	# T1-b (roguelike.gd:39-43): the boon pool has zero production grant points — `p.rogue_boons`
	# stays {} for the whole run. apply_offer_reason() refuses the hand-built offer with a reason
	# (roguelike.gd:792) and keeps the choice open; the dead tally must never be invented.
	check(p.get("rogue_boons",{}).is_empty() and not str(p.rogue_selection.get("error","")).is_empty(),"The dead boon offer tallies nothing and explains its refusal")
	# Close the dead end through the production escape hatch (roguelike.gd:849-862), which books
	# the claim / finish_rewards exactly like a resolved choice would.
	s.perform(1,"rogue_selection_abandon",{"id":p.rogue_selection.id,"version":p.rogue_selection.version})
	check(p.rogue_selection.is_empty(),"Abandoning clears the refused choice")
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
	check(tile!=null,"Reserve slot rendered for stash item 0")
	# The hover/right-click path under test is `bind_item()`'s `mouse_entered` / `gui_input`
	# connections (scripts/rogue_inventory.gd:185-191). Injecting raw mouse events never
	# drives the GUI hover pipeline under `--headless`, so tooltip/menu never appeared.
	# Call the same public entry points those signals would — the engraved tooltip below
	# already uses this direct-call pattern — so the rendering contracts stay covered.
	app.rogue_inventory.show_tooltip(p.rogue_stash[0],false)
	check(is_instance_valid(app.rogue_inventory.tooltip),"Detailed tooltip opens")
	await capture("tooltip")
	app.rogue_inventory.show_menu(p.rogue_stash[0],"reserve",0,false)
	check(is_instance_valid(app.rogue_inventory.menu),"Right-click menu opens")
	await capture("menu")
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
	# The supply row is the bound flask itself: the menu may drink it but never drop it
	# (roguelike.gd:1195-1199); `rogue_medicine` is a dead field — the pool lives in p.flask.
	var flask_before: float=p.flask
	command(s,"supply",0,"discard")
	check(p.flask==flask_before,"The bound flask cannot be discarded from the supply menu")
	app.queue_free()
	await process_frame
	completed=true
