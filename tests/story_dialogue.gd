extends SceneTree
const Screen = preload("res://scripts/story_screen.gd")
const Data = preload("res://scripts/story_dialogue_data.gd")
var checks := 0
var failures := 0
var screen
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func click(at: Vector2) -> void:
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new(); motion.position=at; Input.parse_input_event(motion); await process_frame
	var down := InputEventMouseButton.new(); down.position=at; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; Input.parse_input_event(down); await process_frame
	var up := InputEventMouseButton.new(); up.position=at; up.button_index=MOUSE_BUTTON_LEFT; Input.parse_input_event(up); await process_frame
func shot(name: String) -> void:
	if not "--capture-dialogue" in OS.get_cmdline_user_args(): return
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/galgame-"+name+".png")==OK,"actual galgame capture "+name)
func run() -> void:
	root.size=Vector2i(1440,900)
	screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false; screen.start("user://dialogue-fixture.json"); screen.set_physics_process(false)
	var c=screen.campaign; c.state=c.new_state(); c.enter(1,0); c.save_enabled=false
	var sources: Array=[c.content.history]
	for q in c.content.quests.values(): sources.append(q.story+"\n\n【奖励】"+q.reward_text)
	for ending in c.content.endings.values(): sources.append(ending.story)
	for original in sources:
		var pages := Data.chapter(original,c.content)
		var reconstructed := ""; var bounded := true
		for page in pages: reconstructed+=page.text; bounded=bounded and page.text.length()<=Data.MAX_PAGE
		check(reconstructed==str(original).replace("\n",""),"complete chapter prose retained")
		check(bounded,"long prose fits paginated dialogue without clipping")
	check(Data.chapter("“别猜我的名字。”",c.content)[0].speaker=="旁白","unattributed speech never assigned to an invented character")
	check(Data.chapter("鸦羽问：“还疼吗？”",c.content)[1].speaker=="鸦羽","explicit speaker gets matching portrait")
	for act in c.content.acts:
		for index in 6:
			var pages := Data.npc(index,act.npcs[index],act.id if act.has("id") else c.content.acts.find(act)+1,0)
			check(not pages.is_empty() and pages[-1].right=="npc:%d" % index,"all thirty-six camp service routes have dialogue")
	var before := JSON.stringify(c.state)
	screen.show_npc(0); var ui=screen.dialogue; ui.set_process(false)
	check(screen.modal and not screen.hud.visible and ui.left.texture!=null and ui.right.texture!=null,"actual dialogue pauses gameplay and shows two portraits")
	ui._process(.28)
	await shot("camp")
	await click(Vector2(650,735)); check(ui.index==0 and ui.body.visible_characters==-1,"first native click reveals current line")
	await click(Vector2(650,735)); check(ui.index==1 and ui.body.visible_characters==0,"second native click advances exactly one page")
	var event := InputEventKey.new(); event.keycode=KEY_SPACE; event.pressed=true
	screen._unhandled_input(event); check(ui.index==1 and ui.body.visible_characters==-1,"dialogue space reveals text rather than dodging")
	ui.toggle_log(); var position: int=ui.index; ui._process(100); ui.advance()
	check(ui.index==position and ui.log_view!=null,"backlog pauses auto and advancement")
	await shot("backlog"); ui.toggle_log()
	ui.auto=true; ui._process(10); check(ui.index==2,"auto waits after revealed text and advances")
	ui.skipping=true; ui._process(.01); check(not ui.skipping and ui.index==2,"skip stops at unread text")
	ui.reveal_all(); var read_index: int=ui.index; ui.skipping=true; ui._process(.15)
	check(ui.index==read_index+1 and not ui.skipping,"read skip advances then stops at next unread page")
	while ui.index<ui.pages.size()-1: ui.reveal_all(); ui.advance()
	ui.reveal_all(); ui.advance()
	check(ui.choosing and not ui.auto and not ui.skipping,"choices require an explicit decision")
	check(JSON.stringify(c.state)==before,"reading NPC dialogue cannot alter inventory or quest rewards")
	await shot("choices")
	ui.choose(ui.choices.size()-1); check(not screen.modal and screen.hud.visible,"farewell restores gameplay HUD")
	screen.show_npc(1); ui=screen.dialogue; ui.set_process(false); c.state.hp=1
	while ui.index<ui.pages.size()-1: ui.reveal_all(); ui.advance()
	ui.reveal_all(); ui.advance()
	await click(ui.actions.global_position+Vector2(180,23))
	check(c.state.hp==c.max_hp() and not screen.modal,"native service choice performs authoritative healing")
	screen.show_final_choice(); ui=screen.dialogue; ui.set_process(false)
	while ui.index<ui.pages.size()-1: ui.reveal_all(); ui.advance()
	ui.reveal_all(); ui.advance(); before=JSON.stringify(c.state)
	ui.choose(0); ui._process(100)
	check(ui.choices[0].disabled and JSON.stringify(c.state)==before and not ui.done,"unprepared rescue cannot execute by choice or auto")
	await shot("finale-locked")
	ui.choose(2); check(not screen.modal,"finale can be deferred without making a choice")
	c.complete("P-M01"); ui=screen.dialogue; ui.set_process(false); before=JSON.stringify(c.state)
	while ui.index<ui.pages.size()-1: ui.reveal_all(); ui.advance()
	ui.reveal_all(); ui.advance()
	check(JSON.stringify(c.state)==before and not screen.modal,"completed chapter reading never reapplies rewards")
	screen.show_chapter("回看",c.content.quests["P-M01"].story); ui=screen.dialogue; ui.set_process(false); ui.reveal_all()
	var reader_file: String=c.path+".dialogue-read.json"; c.save_enabled=true; screen.save_dialogue_read(); c.save_enabled=false
	var read_count: int=screen.dialogue_read.size(); screen.load_dialogue_read()
	check(screen.dialogue_read.size()==read_count and ui.was_read(),"read flags survive restart separately from campaign state")
	DirAccess.remove_absolute(reader_file)
	# Wider output uses the same logical canvas, while text and buttons remain native.
	DisplayServer.window_set_size(Vector2i(1920,1080)); root.size=Vector2i(1920,1080); screen.scale=Vector2(1.2,1.2)
	screen.close_panel(); screen.show_npc(4); ui=screen.dialogue; ui.set_process(false)
	while ui.index<ui.pages.size()-1: ui.reveal_all(); ui.advance()
	ui.reveal_all(); ui.advance()
	await process_frame
	await click(root.get_final_transform()*(ui.actions.get_global_transform_with_canvas()*Vector2(180,23)))
	check(screen.dialogue==null and screen.modal and screen.overlay.get_child(1).tab=="shop","scaled native merchant choice opens existing transaction GUI")
	screen.close_panel(); DisplayServer.window_set_size(Vector2i(1440,900)); root.size=Vector2i(1440,900); screen.scale=Vector2.ONE
	screen.show_chapter("生命周期", "归来的灯火。"); ui=screen.dialogue
	screen.set_active(false); check(not screen.modal and screen.dialogue==null,"leaving story removes dialogue and restores pause state")
	screen.free(); for i in 5: await process_frame
	print("story dialogue: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
