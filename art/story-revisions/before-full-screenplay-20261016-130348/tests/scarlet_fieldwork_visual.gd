extends SceneTree
var screen
var checks:=0
var failures:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func prepare(id: String) -> Dictionary:
	screen.close_panel()
	var c=screen.campaign; c.fieldwork.reset(); c.state=c.new_state(); c.save_enabled=false
	var qid:=id.get_slice(":",0)
	for previous in c.content.main_order:
		if previous==qid: break
		c.state.completed.append(previous)
	if qid.begins_with("S"): c.state.accepted=[qid]
	c.state.steps[qid]=int(id.get_slice(":",1)); c.state.pending={}; c.state.choices.palace_approach="side"; c.state.choices.ambush_prepared=true
	var n: Dictionary=c.current_node(c.content.quests[qid]).duplicate(true)
	c.state.zone=n.zone; c.state.act=int(n.zone.get_slice(":",0)); c.state.stage=int(n.zone.get_slice(":",1))
	c.state.hero=maxi(0,int(n.get("hero",0))); c.state.party=[0,1,2]
	n.qid=qid; n.p=c.place(Vector2(n.at[0],n.at[1])); c.hero_at=c.safe_place(n.p+Vector2(0,65))
	for i in 3: c.allies[i]=c.safe_place(c.hero_at+Vector2((i-1)*40,35))
	screen.world.build(); screen.world.original.focus=c.terrain().native(c.hero_at); screen.refresh()
	return n
func capture(name: String) -> void:
	for i in 12: await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path: String="res://output/fieldwork-"+name+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+name)
func layout_check() -> void:
	var ui=screen.field_panel
	for node in [ui.title_label,ui.body,ui.result,ui.counter,ui.gauge_caption]:
		check(node.position.x+node.size.x<=ui.panel.size.x,"text stays inside panel")
		check(node.get_line_count()*node.get_line_height()<=node.size.y+6,"text does not overflow: "+str(node.text))
	check(ui.submit_button.position.y+ui.submit_button.size.y<ui.panel.size.y,"confirmation remains visible")
func run() -> void:
	root.size=Vector2i(1440,900); root.content_scale_size=Vector2i(1440,900)
	screen=preload("res://scripts/story_screen.gd").new(); root.add_child(screen)
	screen.campaign.state=screen.campaign.new_state(); screen.campaign.save_enabled=false; screen.set_active(true)
	var n:=prepare("R-2-05:0"); await capture("valve-world")
	check(screen.world.field_props.objects.has(n.id),"physical valve exists in actual story world")
	var c=screen.campaign
	check(c.use(n) and is_instance_valid(screen.field_panel),"E interaction opens real activity UI")
	var ui=screen.field_panel; ui.part_buttons[ui.order.find(0)].pressed.emit()
	for i in 26: c.fieldwork.tick(.05,true)
	ui.part_buttons[ui.order.find(1)].pressed.emit()
	await capture("valve-calibration"); layout_check()
	check(screen.world.field_props.objects[n.id].moving.rotation.z!=0,"saved work drives physical wheel animation")
	var previous: float=c.fieldwork.needle()
	c.fieldwork.tick(.05,false); check(c.fieldwork.needle()!=previous,"calibration needle animates")
	var leave:=InputEventKey.new(); leave.keycode=KEY_ESCAPE; leave.physical_keycode=KEY_ESCAPE; leave.pressed=true; Input.parse_input_event(leave)
	await process_frame
	check(c.fieldwork.active.is_empty() and not screen.modal,"actual Escape cancels focus without opening pause menu")
	n=prepare("R-1-04:0"); check(c.use(n),"rope scene opens")
	ui=screen.field_panel; ui.part_buttons[ui.order.find(0)].pressed.emit()
	for i in 26: c.fieldwork.tick(.05,true)
	ui.part_buttons[ui.order.find(1)].pressed.emit()
	for i in 25: c.fieldwork.tick(.05,true)
	ui.mouse_holding=true
	await capture("rope-tension"); layout_check()
	n=prepare("R-1-04:3"); check(c.use(n),"lamp scene opens")
	ui=screen.field_panel; ui.part_buttons[ui.order.find(0)].pressed.emit()
	for i in 26: c.fieldwork.tick(.05,true)
	ui.part_buttons[ui.order.find(1)].pressed.emit(); c.fieldwork.adjust(.53)
	await capture("lamp-alignment"); layout_check()
	check(ui.adjustment_buttons[0].visible,"alignment exposes mouse and keyboard fine adjustment")
	n=prepare("R-1-02:2"); check(c.use(n),"ledger opens physical inspection")
	ui=screen.field_panel; ui.part_buttons[1].pressed.emit()
	for i in 19: c.fieldwork.tick(.05,true)
	await capture("ledger-survey"); layout_check()
	check(c.fieldwork.done()==[1],"actual hotspot button selects inspected evidence")
	ui.part_buttons[0].pressed.emit()
	for i in 19: c.fieldwork.tick(.05,true)
	ui.part_buttons[2].pressed.emit()
	for i in 19: c.fieldwork.tick(.05,true)
	await capture("ledger-ready"); layout_check()
	check(not ui.submit_button.disabled,"physical findings enable real confirmation button")
	ui.submit_button.pressed.emit(); await process_frame
	check(c.state.facts.has("ledger") and c.state.pending.kind=="scene","real confirmation returns to authored evidence scene")
	screen.close_panel(); c.state.pending={}
	n=prepare("R-2-05:0"); c.state.fieldwork[n.id]={"done":[0,1,2],"finished":true}; c.advance_step(n.qid,n.id)
	await capture("valve-completed-world")
	check(screen.world.field_props.objects.has(n.id),"completed machinery persists after task advances")
	# Render every close-up family through the same real screen, and verify all texts fit.
	var props: Dictionary={}
	for id in c.fieldwork.profiles:
		var kind: String=c.fieldwork.profiles[id].prop
		if props.has(kind): continue
		props[kind]=true; n=prepare(id); check(c.use(n),"opens prop family "+kind)
		await process_frame
		if is_instance_valid(screen.field_panel): layout_check()
	check(props.size()==10,"all ten physical prop families rendered")
	screen.close_panel(); screen.queue_free(); await process_frame
	print("SCARLET_FIELDWORK_VISUAL %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
