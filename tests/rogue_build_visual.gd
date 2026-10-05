extends SceneTree
const Content = preload("res://scripts/rogue_content.gd")
const Build = preload("res://scripts/rogue_build.gd")
func _initialize() -> void: call_deferred("run")
func capture(tag: String) -> void:
	await create_timer(.65).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/rogue-build-"+tag+".png")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-build-visual.json"
	root.add_child(app); await process_frame
	app.session.solo({"hero":0,"mode":"roguelike"}); app.session.launch(false,731)
	app.session.set_physics_process(false)
	var p: Dictionary=app.session.players[1]
	await capture("starting-choice")
	app.session.perform(1,"rogue_selection_take",{"id":p.rogue_selection.id,"version":0,"index":0})
	app.session.roguelike.tick(app.session,.01)
	app.session.raid.phase="rogue_exit"; app.session.raid.floor=5
	app.session.roguelike.equip(app.session,p,Content.make_weapon(0,3))
	for i in [0,29,52]: app.session.roguelike.equip(app.session,p,app.session.RogueEquipment.make_gear(i,2))
	p.build_forge_level=5; p.build_forge_bound=p.equipped.weapon.instance_id; p.build_forge_points=2; p.build_core="WC002"; p.build_cultivation=18
	Build.add_experience(app.session,p,250)
	p.build_library=["T001","T002","T003","T004","T005","T006","T008","T065","T066","T073","T075"]
	p.build_talents={"T001":3,"T002":3,"T003":2,"T004":2,"T006":2,"T008":1,"T066":2,"T075":1}
	app.inventory_open=true; app.show_inventory(); await capture("inventory")
	app.rogue_inventory.selected_tab="build"
	var UI=load("res://scripts/rogue_build_ui.gd")
	for section in ["talents","attributes","forge","combos","codex"]:
		UI.section=section; app.show_inventory(); await capture(section)
	app.close_bag()
	app.session.raid.phase="rogue_shop"; app.session.raid.room="shop"; app.session.roguelike.roll_offers(app.session,true)
	await capture("shop")
	app.session.raid.floor=2; app.session.raid.area=2; app.session.raid.route[1]="talent"
	app.session.roguelike.enter(app.session)
	await capture("sanctuary-choice")
	while not p.rogue_selection.is_empty():
		app.session.perform(1,"rogue_selection_bank",{"id":p.rogue_selection.id,"version":p.rogue_selection.version})
	await capture("sanctuary")
	app.session.roguelike.add_reward_drop(app.session,p.p+Vector2(105,0),0,{"name":"属性灵晶 +1","attribute_points":1},0,1,"attribute")
	app.session.raid.reward_drops.back()["personal"]=true
	app.session.elapsed+=2
	await capture("attribute-shard")
	app.session.raid.phase="rogue_combat"; app.session.raid.room="combat"; p.height=73; p.height_velocity=0; p.pending_strike=false; p.swing_time=0
	p.build_shield=p.max_hp*.1; p.build_summons=[{"p":p.p+Vector2(55,0),"time":5}]
	p.build_combo_label="红莲追影"; p.build_combo_time=2
	await capture("jump")
	print("BUILD VISUAL: 12 views captured")
	app.queue_free(); await process_frame; quit()
