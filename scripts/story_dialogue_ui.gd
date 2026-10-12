extends Control
## Galgame presentation over the paused RPG. Actions execute once, only on explicit choice.
signal finished
const UISkin = preload("res://scripts/story_ui_skin.gd")
const Data = preload("res://scripts/story_dialogue_data.gd")
const PortraitView = preload("res://scripts/story_portrait_view.gd")
const PortraitArt = preload("res://scripts/story_portrait_art.gd")
const LETTERS_PER_SECOND := 32.0
const AUTO_DELAY := 1.5
const PORTRAIT_BASE_Y := 235.0
const PORTRAIT_EXTENT := Vector2(576,894)
var screen
var title := ""
var pages: Array=[]
var choices: Array=[]
var index := 0
var body: RichTextLabel
var name_label: Label
var page_label: Label
var prompt: Label
var left: Control
var right: Control
var portraits := ["",""]
var portrait_emotions: Dictionary={}
var portrait_poses: Dictionary={}
var wardrobe: Control
var actions: VBoxContainer
var log_view: Control
var auto_button: Button
var skip_button: Button
var log_button: Button
var auto := false
var skipping := false
var choosing := false
var done := false
var revealed := 0.0
var wait_time := 0.0
var elapsed := 0.0
var transition: Tween
var recorded_index := -1

func _ready() -> void:
	size=Vector2(1440,900); mouse_filter=MOUSE_FILTER_STOP
	var shade := ColorRect.new(); shade.color=Color(.015,.012,.025,.64); shade.size=size; shade.mouse_filter=MOUSE_FILTER_IGNORE; add_child(shade)
	left=portrait(Vector2(17,PORTRAIT_BASE_Y)); right=portrait(Vector2(847,PORTRAIT_BASE_Y))
	var title_label: Label=screen.label(self,title,Vector2(80,47),Vector2(1100,45),26)
	title_label.add_theme_color_override("font_color",Color("d5bb88"))
	screen.label(self,"CRIMSON TIDE  /  MEMORIES BY LAMPLIGHT",Vector2(82,88),Vector2(950,24),12)
	var frame := Panel.new(); frame.position=Vector2(115,650); frame.size=Vector2(1210,223); frame.mouse_filter=MOUSE_FILTER_IGNORE; frame.add_theme_stylebox_override("panel",UISkin.frame(5)); add_child(frame)
	var nameplate := Panel.new(); nameplate.position=Vector2(144,608); nameplate.size=Vector2(265,49); nameplate.mouse_filter=MOUSE_FILTER_IGNORE; nameplate.add_theme_stylebox_override("panel",UISkin.frame(3)); add_child(nameplate)
	name_label=screen.label(self,"",Vector2(162,618),Vector2(225,33),23)
	body=RichTextLabel.new(); body.position=Vector2(163,684); body.size=Vector2(1110,119); body.mouse_filter=MOUSE_FILTER_IGNORE
	body.scroll_active=false; body.add_theme_font_size_override("normal_font_size",23); body.add_theme_constant_override("line_separation",9); add_child(body)
	page_label=screen.label(self,"",Vector2(171,826),Vector2(195,25),14)
	prompt=screen.label(self,"",Vector2(360,826),Vector2(300,26),15)
	auto_button=button("自动",Vector2(731,822),Vector2(105,34),func(): auto=not auto; skipping=false; update_buttons())
	skip_button=button("已读快进",Vector2(844,822),Vector2(129,34),func(): skipping=not skipping; auto=false; update_buttons())
	log_button=button("回看",Vector2(981,822),Vector2(94,34),toggle_log)
	button("立绘",Vector2(1083,822),Vector2(83,34),toggle_wardrobe)
	button("收起对话",Vector2(1174,822),Vector2(112,34),finish)
	var scroll := ScrollContainer.new(); scroll.position=Vector2(470,225); scroll.size=Vector2(525,355); scroll.name="Choices"; add_child(scroll); scroll.hide()
	actions=VBoxContainer.new(); actions.custom_minimum_size.x=500; actions.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_theme_constant_override("separation",10); scroll.add_child(actions)
	gui_input.connect(on_gui_input)
	if pages.is_empty(): pages=[{"speaker":"旁白","text":"灯火还在。"}]
	show_page()

func portrait(at: Vector2) -> Control:
	var stage := Control.new(); stage.size=Vector2(1440,650); stage.clip_contents=true; stage.mouse_filter=MOUSE_FILTER_IGNORE; add_child(stage)
	var node := PortraitView.new()
	node.position=at; node.size=PORTRAIT_EXTENT; node.mouse_filter=MOUSE_FILTER_IGNORE; stage.add_child(node); return node

func button(value: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var node: Button=screen.button(self,value,at,extent,action); node.focus_mode=Control.FOCUS_NONE; return node

func texture(actor: String) -> Texture2D:
	if actor.begins_with("hero:"): return load("res://assets/portrait-%d.png" % int(actor.get_slice(":",1)))
	if actor.begins_with("npc:"):
		var slot := clampi(int(actor.get_slice(":",1)),0,5)
		var atlas := AtlasTexture.new(); atlas.atlas=load("res://assets/story/npc-atlas-v1.png")
		var cell := atlas.atlas.get_size()/Vector2(3,2); atlas.region=Rect2(Vector2(slot%3,slot/3)*cell,cell); atlas.filter_clip=true; return atlas
	if actor=="queen": return load("res://assets/bosses/blood-queen-portrait.png")
	return null

func page_key(page: Dictionary) -> String:
	return (title+"|"+str(page.speaker)+"|"+str(page.text)).sha256_text()

func was_read() -> bool:
	return screen.dialogue_read.has(page_key(pages[index]))

func mark_read() -> void:
	if body.visible_characters<0 or revealed>=body.get_total_character_count():
		screen.dialogue_read[page_key(pages[index])]=true

func show_page() -> void:
	var page: Dictionary=pages[index]
	choosing=false; revealed=0; wait_time=0; body.text=page.text; body.visible_characters=0; name_label.text=page.speaker
	page_label.text="%02d / %02d" % [index+1,pages.size()]
	var actor: String=str(page.get("actor",Data.actor_for(str(page.speaker),screen.campaign.content)))
	if page.has("left"): portraits[0]=page.left
	if page.has("right"): portraits[1]=page.right
	if actor!="" and not actor in portraits:
		portraits[0 if actor.begins_with("hero:") else 1]=actor
	if actor.begins_with("hero:"): portrait_emotions[actor]=Data.expression_for(page)
	for side in 2:
		var property := "left_expression" if side==0 else "right_expression"
		if page.has(property): portrait_emotions[portraits[side]]=page[property]
		var pose_property := "left_pose" if side==0 else "right_pose"
		if page.has(pose_property) and page[pose_property] in PortraitArt.POSES:portrait_poses[portraits[side]]=page[pose_property]
	if page.has("pose") and page.pose in PortraitArt.POSES:portrait_poses[actor]=page.pose
	if transition: transition.kill()
	transition=create_tween().set_parallel(true)
	for side in 2:
		var node: Control=left if side==0 else right
		var clothing: String=screen.dialogue_outfits.get(portraits[side],"regular")
		if page.has("costume") and actor==portraits[side] and not screen.dialogue_outfits.has(actor): clothing=page.costume
		node.set_actor(portraits[side],texture(portraits[side]),portrait_emotions.get(portraits[side],"neutral"),clothing,portrait_poses.get(portraits[side],"front"))
		var speaking: bool=portraits[side]==actor and actor!=""
		var tone := Color(1,1,1,1) if speaking or actor=="" else Color(.52,.56,.64,.9)
		transition.tween_property(node,"modulate",tone,.22)
		transition.tween_property(node,"position:y",PORTRAIT_BASE_Y-6.0 if speaking else PORTRAIT_BASE_Y,.22)
	if skipping and not was_read(): skipping=false
	prompt.text="点击 / 空格 · 显示全文"
	update_buttons()

func update_buttons() -> void:
	auto_button.text="自动 ●" if auto else "自动"
	skip_button.text="快进 ●" if skipping else "已读快进"
	auto_button.disabled=choosing; skip_button.disabled=choosing

func _process(dt: float) -> void:
	if done or is_instance_valid(log_view) or is_instance_valid(wardrobe): return
	elapsed+=dt
	if choosing: return
	var count := body.get_total_character_count()
	if skipping:
		if not was_read(): skipping=false; update_buttons()
		else:
			if revealed<count: reveal_all()
			wait_time+=dt
			if wait_time>.12: advance()
			return
	if revealed<count:
		revealed=minf(count,revealed+dt*LETTERS_PER_SECOND); body.visible_characters=int(revealed)
		if revealed>=count: mark_read(); prompt.text="点击 / 空格 · 下一句  ▾"
	else:
		wait_time+=dt
		if auto and wait_time>AUTO_DELAY+count*.025: advance()

func reveal_all() -> void:
	revealed=body.get_total_character_count(); body.visible_characters=-1; mark_read(); prompt.text="点击 / 空格 · 下一句  ▾"; wait_time=0

func advance() -> void:
	if done or choosing or is_instance_valid(log_view) or is_instance_valid(wardrobe): return
	if revealed<body.get_total_character_count(): reveal_all(); return
	mark_read()
	record_page()
	if index+1<pages.size(): index+=1; show_page()
	elif not choices.is_empty(): show_choices()
	else: finish()

func record_page() -> void:
	if recorded_index==index: return
	recorded_index=index
	screen.dialogue_history.append({"title":title,"speaker":pages[index].speaker,"text":pages[index].text})
	while screen.dialogue_history.size()>180: screen.dialogue_history.pop_front()

func show_choices() -> void:
	choosing=true; auto=false; skipping=false; update_buttons(); prompt.text="请选择 · 不会自动作出决定"
	actions.get_parent().show()
	for i in choices.size():
		var entry: Dictionary=choices[i]
		var node := Button.new(); node.text=entry.text+("（准备不足）" if entry.get("disabled",false) else ""); node.custom_minimum_size=Vector2(500,46); node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		UISkin.button(node); node.disabled=entry.get("disabled",false); node.tooltip_text=entry.get("reason","")
		node.pressed.connect(choose.bind(i)); actions.add_child(node)
		if not node.disabled and get_viewport().gui_get_focus_owner()==null: node.grab_focus()

func choose(slot: int) -> void:
	if done or not choosing or slot<0 or slot>=choices.size() or choices[slot].get("disabled",false): return
	done=true; screen.save_dialogue_read()
	var action: Callable=choices[slot].action
	# The action may replace this overlay. Do not touch its nodes after dispatch.
	action.call()

func toggle_log() -> void:
	if is_instance_valid(wardrobe): toggle_wardrobe()
	if is_instance_valid(log_view): log_view.queue_free(); log_view=null; return
	log_view=Panel.new(); log_view.position=Vector2(285,136); log_view.size=Vector2(870,448); log_view.add_theme_stylebox_override("panel",UISkin.frame(5)); add_child(log_view)
	screen.label(log_view,"灯下回声 · 对话回看",Vector2(27,20),Vector2(650,34),23)
	var close: Button=screen.button(log_view,"返回",Vector2(735,22),Vector2(100,34),toggle_log); close.focus_mode=Control.FOCUS_NONE
	var log_text := RichTextLabel.new(); log_text.position=Vector2(30,72); log_text.size=Vector2(806,348); log_text.add_theme_font_size_override("normal_font_size",18); log_text.add_theme_constant_override("line_separation",6)
	var lines := PackedStringArray()
	for entry in screen.dialogue_history: lines.append("%s · %s\n%s\n" % [entry.title,entry.speaker,entry.text])
	lines.append("%s · %s\n%s" % [title,pages[index].speaker,pages[index].text.substr(0,int(revealed))])
	log_text.text="\n".join(lines); log_view.add_child(log_text); log_text.scroll_following=true
	log_text.scroll_to_line.call_deferred(maxi(0,log_text.get_line_count()-1))

func handle_key(event: InputEventKey) -> bool:
	if done: return false
	if event.keycode==KEY_ESCAPE:
		if is_instance_valid(wardrobe): toggle_wardrobe()
		elif is_instance_valid(log_view): toggle_log()
		else: finish()
		return true
	if event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]: advance(); return true
	if event.keycode==KEY_L: toggle_log(); return true
	if event.keycode==KEY_C: toggle_wardrobe(); return true
	if event.keycode==KEY_A and not choosing: auto=not auto; skipping=false; update_buttons(); return true
	return false

func on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		advance(); accept_event()

func finish() -> void:
	if done: return
	if revealed>=body.get_total_character_count(): record_page()
	done=true; mark_read(); screen.save_dialogue_read(); finished.emit()

func toggle_wardrobe() -> void:
	if is_instance_valid(wardrobe): wardrobe.queue_free(); wardrobe=null; return
	if is_instance_valid(log_view): toggle_log()
	wardrobe=Panel.new(); wardrobe.position=Vector2(255,125); wardrobe.size=Vector2(930,530); wardrobe.add_theme_stylebox_override("panel",UISkin.frame(5)); add_child(wardrobe)
	screen.label(wardrobe,"灯下立绘 · 服饰与姿态",Vector2(28,22),Vector2(650,37),26)
	screen.label(wardrobe,"三套服饰、三种姿态独立选择。服饰选择会保存。",Vector2(30,65),Vector2(820,30),17)
	screen.button(wardrobe,"返回对话",Vector2(760,24),Vector2(138,34),toggle_wardrobe)
	for hero in 3:
		screen.label(wardrobe,Data.HEROES[hero],Vector2(30,130+130*hero),Vector2(118,35),23)
		for slot in PortraitArt.COSTUMES.size():
			var costume: String=PortraitArt.COSTUMES[slot]
			var actor := "hero:%d" % hero
			var node: Button=screen.button(wardrobe,PortraitArt.COSTUME_NAMES[slot],Vector2(155+240*slot,120+130*hero),Vector2(225,42),func(): choose_costume(actor,costume))
			UISkin.button(node,screen.dialogue_outfits.get(actor,"regular")==costume)
		for slot in PortraitArt.POSES.size():
			var gesture: String=PortraitArt.POSES[slot]
			var actor := "hero:%d" % hero
			var node: Button=screen.button(wardrobe,PortraitArt.POSE_NAMES[slot],Vector2(155+240*slot,169+130*hero),Vector2(225,38),func(): choose_pose(actor,gesture))
			UISkin.button(node,portrait_poses.get(actor,"front")==gesture)

func choose_costume(actor: String, clothing: String) -> void:
	if not clothing in PortraitArt.COSTUMES: return
	screen.dialogue_outfits[actor]=clothing; screen.save_dialogue_outfits()
	for side in 2:
		if portraits[side]==actor:
			var node: Control=left if side==0 else right
			node.set_actor(actor,texture(actor),portrait_emotions.get(actor,"neutral"),clothing,portrait_poses.get(actor,"front"))
	if is_instance_valid(wardrobe): toggle_wardrobe(); toggle_wardrobe()

func choose_pose(actor: String, gesture: String) -> void:
	if not gesture in PortraitArt.POSES:return
	portrait_poses[actor]=gesture
	for side in 2:
		if portraits[side]==actor:
			var node: Control=left if side==0 else right
			node.set_actor(actor,texture(actor),portrait_emotions.get(actor,"neutral"),screen.dialogue_outfits.get(actor,"regular"),gesture)
	if is_instance_valid(wardrobe):toggle_wardrobe();toggle_wardrobe()

func _draw() -> void:
	var gold := Color(.69,.54,.31,.64)
	draw_line(Vector2(80,119),Vector2(1360,119),gold,1,true)
	for x in [83,1357]:
		draw_polyline(PackedVector2Array([Vector2(x,628),Vector2(x-7,643),Vector2(x,658),Vector2(x+7,643),Vector2(x,628)]),gold,1.5,true)
		draw_line(Vector2(x,662),Vector2(x,853),gold,1,true)
