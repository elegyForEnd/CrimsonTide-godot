extends SceneTree
## Full-reserve reward trap — visual counterpart (**needs a real window**).
##
##   引擎: Godot_v4.7.2-stable_win64_console.exe --path . --script tests/rogue_full_bag_visual.gd
##   产物: res://build/rogue-full-bag-*.png
##
## `tests/rogue_full_bag.gd` pins the state machine; this one draws the screen the player
## actually gets, so "the refusal is visible and the way out is on screen" is something a
## human can confirm at a glance instead of trusting a dictionary key.

const Equipment = preload("res://scripts/rogue_equipment.gd")

var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image!=null, "the viewport produced a frame for "+file)
	if image!=null: image.save_png("res://build/"+file+".png")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-full-bag-visual.json"
	root.add_child(app)
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,90210)
	app.session.set_physics_process(false)
	await process_frame
	var p: Dictionary=app.session.players[app.session.my_id()]
	# Clear the starter choice so the panel below is ours to drive.
	if not p.get("rogue_selection",{}).is_empty():
		app.session.perform(app.session.my_id(),"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
	app.session.roguelike.equip(app.session,p,Equipment.make_gear(0,3))
	while p.rogue_stash.size()<12: p.rogue_stash.append(Equipment.make_gear(1,2))
	app.session.roguelike.loot_serial+=1
	var item: Dictionary=Equipment.make_gear(0,5)
	p.rogue_selection={"id":app.session.roguelike.loot_serial,"version":0,"tier":3,"category":"gear","personal":true,
		"offers":[{"name":Catalog.item_name(item),"desc":"","tier":3,"item":item}]}
	app.update_hud()
	await capture("rogue-full-bag-panel")

	# The claim is refused: the reason must be on screen and the way out must be clickable.
	app.session.perform(app.session.my_id(),"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
	await process_frame
	await process_frame
	var notice: Label=app.find_child("RewardNotice",true,false)
	check(notice!=null, "the reward panel owns a notice label")
	if notice!=null:
		check(notice.visible, "the refusal is visible to the player")
		check(notice.text.contains("行囊"), "the notice names the full reserve (got '%s')" % notice.text)
	var abandon: Button=app.find_child("RewardAbandon",true,false)
	check(abandon!=null, "a personal offer carries an abandon button")
	if abandon!=null:
		check(not abandon.disabled, "the abandon button is clickable — this is the way out")
		check(abandon.text.contains("放弃"), "the abandon button says what it does (got '%s')" % abandon.text)
	await capture("rogue-full-bag-notice")

	print("FULL BAG VISUAL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
