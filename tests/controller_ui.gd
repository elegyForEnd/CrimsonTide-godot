extends SceneTree
var app: Node
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func pad(code: int, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new(); event.device=0; event.button_index=code; event.pressed=pressed
	root.push_input(event)
func tap(code: int) -> void:
	pad(code); pad(code,false)
func focused_text() -> String:
	var node := root.gui_get_focus_owner()
	return node.text if node is BaseButton else ""
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	await process_frame
	app.set_process(false)
	app.show_title()
	var ui=app.controller.ui
	# Full SceneTree input propagation, without bypassing main._input().
	tap(JOY_BUTTON_A)
	check(app.page_name=="ground","A activates the real Start Game button and enters camp")
	app.show_title()
	tap(JOY_BUTTON_DPAD_DOWN)
	check(focused_text()=="创建 / 加入房间","Down selects the next title button")
	tap(JOY_BUTTON_DPAD_DOWN)
	check(focused_text()=="设置","Down selects Settings")
	tap(JOY_BUTTON_A)
	check(app.modal,"A opens actual Settings callback")
	var controls: Array[Control]=[]; ui.collect(app.overlay,controls)
	var sliders := controls.filter(func(n): return n is HSlider)
	check(sliders.size()==4,"All audio and rumble sliders are navigable")
	if not sliders.is_empty():
		ui.focus_to(app,sliders[0]); var old: float=sliders[0].value
		tap(JOY_BUTTON_DPAD_LEFT)
		check(sliders[0].value<old,"Left changes actual slider value")
		# Restore the original user preference through its existing callback.
		sliders[0].value=old
	tap(JOY_BUTTON_B)
	check(not app.modal and app.page_name=="title","B closes settings without activating background UI")
	# The alternate cursor path must also traverse Godot's actual GUI event path.
	app.show_title(); await process_frame; app.controller.ui.pointer=true
	var settings: Button
	for child in app.page.get_children():
		if child is Button and child.text=="设置": settings=child
	app.controller.cursor_position=settings.get_global_transform_with_canvas()*(settings.size*0.5)
	app.controller.cursor_valid=true
	tap(JOY_BUTTON_A)
	await process_frame; await process_frame
	check(app.modal,"Pointer A click reaches real GUI button after original joy event is consumed")
	app.close_modal(); ui.pointer=false
	app.show_p2p_rooms(); tap(JOY_BUTTON_B)
	check(app.page_name=="title","B follows the real return button from room selection")
	# A live reward-like modal proves confirmation uses the selected callback.
	var chosen := [0]
	app.modal_box("手柄选择测试",Vector2(700,400))
	var first: Button=app.button(app.overlay,"选项一",Vector2(440,350),Vector2(230,60),func(): chosen[0]=1)
	var second: Button=app.button(app.overlay,"选项二",Vector2(760,350),Vector2(230,60),func(): chosen[0]=2)
	var disabled: Button=app.button(app.overlay,"不可选",Vector2(1100,350),Vector2(230,60),func(): chosen[0]=3)
	disabled.disabled=true
	ui.focus_to(app,first); tap(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner()==second,"Right moves among actual selection buttons")
	tap(JOY_BUTTON_A)
	check(chosen[0]==2,"A confirms the highlighted choice exactly once")
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner()!=disabled,"Disabled choices are skipped")
	ui.tick(app,0.11)
	check(ui.ribbon.visible and "A 确认" in ui.ribbon.text,"Menu displays controller confirmation hints")
	check(ui.frame.visible,"Selected control has a visible focus frame")
	var hint: Label=app.label(app.overlay,"[E] 互动 · [Tab] 行囊",Vector2(300,600))
	ui.convert_prompts(app,app.overlay)
	check(hint.text=="[Y] 互动 · [View] 行囊","Inline prompts switch to controller labels")
	app.controller.active=false; ui.convert_prompts(app,app.overlay)
	check(hint.text=="[E] 互动 · [Tab] 行囊","Keyboard prompts return when keyboard is used")
	app.close_modal(); app.controller.active=true
	app.session.solo({"hero":0,"mode":"roguelike"}); app.session.launch(false,1729); app.session.set_physics_process(false)
	var player: Dictionary=app.session.players[1]
	player.rogue_selection={"id":9001,"version":0,"tier":0,"category":"weapon","personal":true,"offers":app.session.roguelike.reward_offers(app.session,0,"weapon",player)}
	app.update_rogue_hud(player)
	var card: Button=app.rogue_panel.find_child("RewardCard0",true,false)
	check(is_instance_valid(card),"Actual rogue reward cards are present")
	if is_instance_valid(card):
		tap(JOY_BUTTON_DPAD_RIGHT); tap(JOY_BUTTON_A)
		check(root.gui_get_focus_owner().name=="RewardCard1","Right and A select the second real reward card")
		var expected: int=int(player.rogue_selection.offers[1].item.weapon)
		tap(JOY_BUTTON_DPAD_DOWN)
		check(focused_text()=="领取奖励","Down reaches real reward confirmation button (got: "+focused_text()+")")
		tap(JOY_BUTTON_A)
		check(player.rogue_selection.is_empty() and int(player.weapon)==expected,"A claims selected reward through authoritative game action")
	app.page_name="game"; player.rogue_selection={}; app.rogue_panel_open=false
	check("RT 重击/蓄力" in ui.hints(app) and "LB 奥义" in ui.hints(app),"Combat displays actual attack and ultimate bindings")
	app.queue_free(); await process_frame
	print("CONTROLLER UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
