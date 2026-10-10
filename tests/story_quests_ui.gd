extends SceneTree
const Screen = preload("res://scripts/story_screen.gd")
var checks := 0
var failures := 0
var screen
var events: Array=[]
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func click(at: Vector2) -> void:
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new(); motion.position=at; Input.parse_input_event(motion); await process_frame
	var down := InputEventMouseButton.new(); down.position=at; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; Input.parse_input_event(down); await process_frame
	var up := InputEventMouseButton.new(); up.position=at; up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false; Input.parse_input_event(up); await process_frame
func capture(name: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/story-quests-"+name+".png")==OK,"actual task UI capture "+name)
func run() -> void:
	root.size=Vector2i(1440,900); DisplayServer.window_set_size(Vector2i(1440,900))
	screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false; screen.start("user://quest-ui-fixture.json")
	if screen.quest_fx==null: push_error("quest FX failed to instantiate"); quit(1); return
	var c=screen.campaign; c.save_enabled=false; c.state=c.new_state(); c.inventory.initialize(); c.enter(1,0); screen.set_physics_process(false)
	c.quest_event.connect(func(kind: String,id: String): events.append([kind,id]))
	for id in ["P-M01","P-M02","P-M03","A1-M01","A1-M02"]: c.complete(id,false)
	check(events.is_empty(),"silent restoration/setup never fakes quest celebrations")
	screen.show_journal(); await process_frame
	var ui=screen.overlay.get_child(1)
	check(ui.cards.size()==40 and ui.filter=="main","all forty main nodes represented in graphical journal")
	await capture("main")
	await click(ui.position+Vector2(379,94)); await process_frame
	check(ui.filter=="side" and ui.cards.size()==24,"real category click shows twenty-four side quests")
	ui.selected="A1-S01"; ui.refresh_details()
	var before := JSON.stringify([c.state.coins,c.state.xp,c.state.materials])
	await click(ui.position+ui.detail.position+Vector2(100,523)); await process_frame
	check("A1-S01" in c.state.accepted and events==[["accepted","A1-S01"]],"native accept button changes task and emits one actual event")
	check(JSON.stringify([c.state.coins,c.state.xp,c.state.materials])==before,"accepting does not grant completion rewards")
	check(c.tracked().id=="A1-S01" and screen.objective.text.contains(c.content.quests["A1-S01"].title),"accepted optional quest is tracked in actual HUD")
	check(screen.quest_fx.current.kind=="accepted","accept effect is running independently of paused simulation")
	await capture("accepted")
	var signal_count := events.size(); c.accept("A1-S01")
	check(events.size()==signal_count,"reaccepting emits no duplicate effect")
	var state_before := JSON.stringify(c.state); screen.quest_fx.show_event("progress","A1-S01")
	check(JSON.stringify(c.state)==state_before,"visual effect cannot award or mutate progress")
	screen.quest_fx.clear(); c.complete("A1-S01")
	await process_frame
	check("A1-S01" in c.state.completed and events[-1]==["completed","A1-S01"],"completion emits only after actual task transition")
	var reward: Dictionary=c.rewards(c.content.quests["A1-S01"])
	check(screen.quest_fx.current.reward==reward and c.state.tracked_quest=="","effect uses authoritative rewards and finished tracking clears")
	check(screen.modal,"completed chapter still opens the actual long story")
	await capture("completed")
	signal_count=events.size(); state_before=JSON.stringify(c.state)
	check(not c.complete("A1-S01") and events.size()==signal_count and JSON.stringify(c.state)==state_before,"repeated completion neither rewards nor celebrates")
	# Two-step personal quest advances through actual E interactions with authored world nodes.
	c.complete("A1-M03",false); c.complete("A1-M04",false); screen.quest_fx.clear(); check(c.accept("C-F01"),"personal prerequisite permits acceptance")
	c.enter(1,4); c.enemies.clear(); screen.close_panel(); screen.quest_fx.clear()
	var q: Dictionary=c.content.quests["C-F01"]
	var node: Dictionary={}
	for target in c.objective_nodes():
		if target.id==q.id: node=target; break
	check(not node.is_empty(),"accepted task spawns a real objective")
	c.hero_at=node.p; check(screen.nearest().get("kind")=="objective","authored target is the actual nearby interaction")
	before=JSON.stringify([c.state.coins,c.state.xp,c.state.materials])
	var key := InputEventKey.new(); key.keycode=KEY_E; key.pressed=true; Input.parse_input_event(key); await process_frame
	check(c.step_count(q)==1 and events[-1]==["progress",q.id],"real E advances first goal and progress effect")
	check(JSON.stringify([c.state.coins,c.state.xp,c.state.materials])==before,"partial goal gives no duplicate reward")
	await capture("progress")
	screen.quest_fx.clear()
	for target in c.objective_nodes():
		if target.id==q.id: node=target; break
	c.hero_at=node.p; key=InputEventKey.new(); key.keycode=KEY_E; key.pressed=true; Input.parse_input_event(key); await process_frame
	check(q.id in c.state.completed and c.step_count(q)==q.steps.size(),"last actual E goal completes the task")
	check(events[-1]==["completed",q.id] and screen.quest_fx.current.kind=="completed","final step uses completion effect rather than progress effect")
	await capture("personal-completed")
	c.enter(1,0); screen.quest_fx.clear(); screen.show_personal(); await process_frame; ui=screen.overlay.get_child(1)
	check(ui.filter=="personal" and ui.cards.size()==9,"personal NPC route uses nine graphical character tasks")
	await capture("personal")
	screen.show_journal("completed"); await process_frame; ui=screen.overlay.get_child(1)
	check(ui.cards.size()==c.state.completed.size(),"completed archive matches real state")
	await capture("archive")
	check(not c.track("C-F01") and not c.track("A6-M06"),"cannot track completed or locked future task")
	check(c.track(c.current_main().id),"current main quest remains trackable")
	c.path="user://quest-ui-roundtrip.json"; c.save_enabled=true; check(c.save_campaign(),"tracked quest persists")
	var reloaded=Screen.Campaign.new(); reloaded.save_enabled=false; reloaded.load_campaign(c.path)
	check(reloaded.tracked().id==c.tracked().id,"tracking restored without notifications")
	screen.set_active(false); check(screen.quest_fx.current.is_empty() and screen.quest_fx.queue.is_empty(),"leaving story clears temporary animations")
	screen.free(); for i in 8: await process_frame
	print("story quest UI: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
