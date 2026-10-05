extends SceneTree
## Also runnable as an absolute --script path against the exported EXE/PCK.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var required := ["res://resources/rogue_build_content.json","res://assets/rogue/build/atlas-manifest.json","res://assets/rogue/build/jump-manifest.json","res://assets/rogue/animations/packed-manifest.json"]
	for path in required:
		if not FileAccess.file_exists(path): push_error("Missing exported data: "+path); quit(1); return
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-build-pack.json"
	root.add_child(app); await process_frame
	app.session.solo({"hero":0,"mode":"roguelike"}); app.session.launch(false,512)
	app.session.set_physics_process(false)
	var p: Dictionary=app.session.players[1]
	app.session.perform(1,"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
	app.session.roguelike.tick(app.session,.01)
	var rules=load("res://scripts/rogue_build.gd")
	if p.build_level!=1 or p.build_attribute_points!=0: push_error("Exported run grants old fixed points"); quit(1); return
	rules.enemy_experience(app.session,{"hp":0.0,"build_xp_reward":40})
	if p.build_level!=2 or p.build_attribute_points!=2: push_error("Exported level growth is incorrect"); quit(1); return
	app.session.roguelike.apply_offer(app.session,p,{"attribute_points":1})
	if p.build_attribute_points!=3: push_error("Exported attribute shard is incorrect"); quit(1); return
	app.session.raid.phase="rogue_exit"
	app.inventory_open=true; app.rogue_inventory.selected_tab="build"
	var ui=load("res://scripts/rogue_build_ui.gd")
	for section in ["talents","attributes","forge","combos","codex"]:
		ui.section=section; app.show_inventory(); await process_frame
	var art=load("res://scripts/rogue_build_art.gd")
	var content=load("res://scripts/rogue_content.gd")
	for category in ["weapons","gear","talents","engravings","cores"]:
		for def in content.data[category]:
			if art.icon(str(def.id))==null: push_error("Missing exported icon "+str(def.id)); quit(1); return
	for hero in 4:
		for velocity in [420.0,200.0,0.0,-250.0]:
			var pose: Dictionary=app.rogue_field.frames.jump_frame(hero,velocity)
			if pose.texture==null: push_error("Missing exported jump texture"); quit(1); return
	app.close_bag()
	app.session.raid.floor=2; app.session.raid.area=2; app.session.raid.route[1]="talent"
	app.session.roguelike.enter(app.session)
	if p.rogue_selection.get("category","")!="talent" or p.build_reward_queue!=["talent","core"] or not app.session.raid.reward_chest.is_empty():
		push_error("Exported sanctuary rules are incorrect"); quit(1); return
	while not p.rogue_selection.is_empty():
		app.session.perform(1,"rogue_selection_bank",{"id":p.rogue_selection.id,"version":p.rogue_selection.version})
	if app.session.raid.phase!="rogue_exit": push_error("Exported sanctuary exit stays locked"); quit(1); return
	print("BUILD PACK: main scene, five build tabs,252 icons,4 hero jump sheets, sanctuary choices, XP leveling, attribute shards and JSON data loaded")
	app.session.disconnect_room()
	app.queue_free(); await process_frame; await process_frame
	# Disconnect schedules title resource loading; allow background jobs to drain.
	await create_timer(.5).timeout
	quit()
