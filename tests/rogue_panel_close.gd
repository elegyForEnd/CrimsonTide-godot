extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-panel-close.json"
	root.add_child(app)
	# This regression covers the raid HUD, without loading unrelated camp models.
	app.session.changed.disconnect(app.on_lobby)
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,20261005)
	app.session.set_physics_process(false)
	app.set_process(false)
	var p: Dictionary=app.session.players[app.session.my_id()]
	if not p.rogue_selection.is_empty():
		app.update_rogue_hud(p)
		check(not app.rogue_panel.has_node("RoguePanelClose"),"mandatory starting selection still requires a choice")
		app.session.perform(p.id,"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
	p.p.x=0
	app.session.raid.room="shop"
	app.session.raid.phase="rogue_shop"
	app.update_rogue_hud(p)
	check(app.rogue_panel_open,"shop opens on entry")
	var close: Button=app.rogue_panel.get_node("RoguePanelClose")
	close.pressed.emit()
	check(not app.rogue_panel_open,"close button dismisses shop")
	check(app.rogue_panel.has_node("RoguePanelReopen"),"closed shop has a reopen entry")
	app.session.raid.revision+=1
	p.rogue_gold+=20
	app.update_rogue_hud(p)
	check(not app.rogue_panel_open,"resource and revision updates preserve dismissal")
	app.rogue_panel.get_node("RoguePanelReopen").pressed.emit()
	check(app.rogue_panel_open,"reopen button restores shop")
	var escape := InputEventAction.new()
	escape.action="pause"
	escape.pressed=true
	app._unhandled_input(escape)
	check(not app.rogue_panel_open and not app.modal,"Escape closes shop before opening pause menu")
	for kind in ["forge","gamble","mirror","event"]:
		app.session.raid.room=kind
		app.session.raid.area+=1
		app.session.raid.phase="rogue_shop"
		if kind=="event":
			preload("res://scripts/rogue_events.gd").roll_offer(app.session)
		else:
			app.session.raid.pending_event={}
		app.update_rogue_hud(p)
		check(app.rogue_panel_open,"new %s room opens automatically" % kind)
		app._unhandled_input(escape)
		check(not app.rogue_panel_open,"Escape dismisses %s" % kind)
		app.session.raid.revision+=1
		app.update_rogue_hud(p)
		check(not app.rogue_panel_open,"%s remains dismissed after refresh" % kind)
		app.open_rogue_panel()
		check(app.rogue_panel_open,"%s can be reopened" % kind)
	app.pause_menu()
	app._unhandled_input(escape)
	check(not app.modal and app.rogue_panel_open,"Escape closes overlay before underlying room panel")
	app.session.raid.pending_event={}
	app.session.raid.room="combat"
	app.session.raid.phase="rogue_reward"
	var offers: Array=app.session.roguelike.reward_offers(app.session,1,"gear",p)
	p.rogue_selection={"id":999,"version":0,"tier":1,"category":"gear","offers":offers}
	app.update_rogue_hud(p)
	check(app.rogue_panel.has_node("RoguePanelClose"),"world loot selection can be closed")
	var drops_before: int=app.session.raid.reward_drops.size()
	app._unhandled_input(escape)
	app.update_rogue_hud(p)
	check(p.rogue_selection.is_empty(),"closing world loot releases pending selection")
	check(app.session.raid.reward_drops.size()==drops_before+1,"closing returns loot to the world")
	check(app.session.raid.reward_drops.back().offers==offers,"returned loot preserves the original choices")
	check(not app.rogue_panel_open,"returned loot no longer covers the scene")
	app.session.disconnect_room()
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	print("ROGUE PANEL CLOSE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
