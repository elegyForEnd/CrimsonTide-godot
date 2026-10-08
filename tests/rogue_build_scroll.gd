extends SceneTree
const UI = preload("res://scripts/rogue_build_ui.gd")
var app
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func frames(count: int = 5) -> void:
	for i in count: await process_frame
func sheet():
	for child in app.overlay.get_children():
		if child.get_script()==UI: return child
	return null
func run() -> void:
	app=load("res://scripts/main.gd").new(); root.add_child(app); await frames()
	app.session.set_physics_process(false)
	app.session.solo({"hero":0,"mode":"roguelike"}); app.session.launch(false,731)
	var p: Dictionary=app.session.players[1]
	p.rogue_selection={}; p.build_reward_queue=[]; p.build_cultivation=18
	p.build_library=["T001","T002","T003","T004","T005","T006","T007","T008","T065","T066","T067","T068","T069","T070","T071","T072","T073","T074","T075","T076"]
	app.session.raid.phase="rogue_exit"
	app.inventory_open=true; app.rogue_inventory.selected_tab="build"; UI.section="talents"; UI.scroll_positions={}
	app.show_inventory(); await frames()
	var old=sheet(); old.scroll.scroll_vertical=1100; await frames(1)
	var old_button: Button=old.find_child("TalentActivate_T065",true,false)
	var old_y: float=old_button.global_position.y
	check(old.scroll.scroll_vertical==1100,"Test starts below top of long talent list")
	old_button.pressed.emit(); app.show_inventory(); await frames()
	var current=sheet()
	check(p.build_talents.get("T065",0)==1,"Actual button activates talent")
	check(current.scroll.scroll_vertical==1100,"Activation preserves scroll after rebuilding layout")
	check(is_equal_approx(current.find_child("TalentActivate_T065",true,false).global_position.y,old_y),"Activated row stays at same screen position")
	current.find_child("TalentActivate_T065",true,false).pressed.emit(); app.show_inventory(); await frames()
	current=sheet()
	check(p.build_talents.get("T065",0)==2 and current.scroll.scroll_vertical==1100,"Upgrade preserves scroll")
	current.find_child("TalentRemove_T065",true,false).pressed.emit(); app.show_inventory(); await frames()
	current=sheet()
	check(p.build_talents.get("T065",0)==1 and current.scroll.scroll_vertical==1100,"Downgrade preserves scroll")
	current.remember_scroll(); UI.section="forge"; app.show_inventory(); await frames()
	current=sheet(); current.scroll.scroll_vertical=200; await frames(1); current.remember_scroll()
	UI.section="talents"; app.show_inventory(); await frames()
	check(sheet().scroll.scroll_vertical==1100,"Returning from another section restores talent scroll")
	UI.section="forge"; app.show_inventory(); await frames()
	check(sheet().scroll.scroll_vertical==200,"Each section remembers its own position")
	# Scroll very near the bottom; remove a row and verify clamp never jumps to zero.
	UI.section="talents"; app.show_inventory(); await frames(); current=sheet()
	current.scroll.scroll_vertical=100000; await frames(1); var bottom: int=current.scroll.scroll_vertical
	current.find_child("TalentRemove_T076",true,false).pressed.emit(); app.show_inventory(); await frames()
	check(not "T076" in p.build_library and sheet().scroll.scroll_vertical>0 and sheet().scroll.scroll_vertical<=bottom,"Forget clamps bottom position when content shrinks")
	app.queue_free(); await frames(2)
	print("ROGUE BUILD SCROLL: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
