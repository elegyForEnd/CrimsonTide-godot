extends Control
## ADV stage with authored whole-image expression/pose changes, persistent cursor,
## CG camera motion, history, deliberate choices and choice-safe skipping.
const Art=preload("res://scripts/scarlet/art.gd")
const TypeReveal=preload("res://scripts/type_reveal.gd")
var campaign
var screen
var event: Dictionary={}
var replay := false
var index := 0
var elapsed := 0.0
var revealed := 0.0
var typer=TypeReveal.new()
var wait := 0.0
var auto := false
var hidden_box := false
var choosing := false
var cg_id := ""
var cg_view: TextureRect
var backdrop: TextureRect
var shade: ColorRect
var actors: Dictionary={}
var expressions: Dictionary={}
var poses: Dictionary={}
var costumes: Dictionary={}
var body: RichTextLabel
var name_label: Label
var counter: Label
var title_label: Label
var text_panel: Panel
var actions: VBoxContainer
var action_scroll: ScrollContainer
var controls: HBoxContainer
var log_panel: Panel
var transition: Tween
var video: VideoStreamPlayer
var queued_page := false
var current_npc:=""
var front_hero:=""
var speaker_portrait: TextureRect
var cg_fit_above_dialogue:=false

func _ready() -> void:
	size=Vector2(1440,900); mouse_filter=MOUSE_FILTER_STOP
	typer.on_char=func(_index: int,glyph: String):
		if bool(campaign.state.settings.get("type_sound",true)) and screen and screen.sound:
			screen.sound.play_type(glyph,float(campaign.state.settings.get("type_volume",50.0)))
	shade=ColorRect.new(); shade.size=size; shade.color=Color(.014,.016,.03,.55); shade.mouse_filter=MOUSE_FILTER_IGNORE; add_child(shade)
	backdrop=TextureRect.new(); backdrop.size=size; backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; backdrop.mouse_filter=MOUSE_FILTER_IGNORE
	if event.get("background","")!="": backdrop.texture=Art.texture("res://assets/story/scarlet/bg/"+event.background+".png")
	backdrop.modulate=Color(.77,.76,.83); add_child(backdrop)
	cg_view=TextureRect.new(); cg_view.size=size; cg_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cg_view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; cg_view.mouse_filter=MOUSE_FILTER_IGNORE; add_child(cg_view)
	var stage:=Control.new(); stage.size=Vector2(1440,730); stage.clip_contents=true; stage.mouse_filter=MOUSE_FILTER_IGNORE; add_child(stage)
	for actor in ["feiyue","xueli","yayu","other"]:
		var portrait:=TextureRect.new(); portrait.size=Vector2(530,920); portrait.position=Vector2(0,85)
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; portrait.mouse_filter=MOUSE_FILTER_IGNORE; portrait.hide(); stage.add_child(portrait); actors[actor]=portrait
	title_label=label(event.get("title",""),Vector2(55,27),Vector2(1250,42),26)
	title_label.add_theme_color_override("font_color",Color("e9d09c"))
	text_panel=Panel.new(); text_panel.position=Vector2(68,643); text_panel.size=Vector2(1304,233)
	text_panel.add_theme_stylebox_override("panel",Art.frame(Color(.04,.04,.075,.95),Color("ad8a69"),3)); add_child(text_panel)
	name_label=label("",Vector2(105,651),Vector2(900,38),23)
	speaker_portrait=TextureRect.new(); speaker_portrait.position=Vector2(86,674); speaker_portrait.size=Vector2(190,151)
	speaker_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; speaker_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	speaker_portrait.mouse_filter=MOUSE_FILTER_IGNORE; add_child(speaker_portrait)
	body=RichTextLabel.new(); body.position=Vector2(106,704); body.size=Vector2(1225,105)
	body.scroll_active=false; body.add_theme_font_size_override("normal_font_size",23); body.add_theme_constant_override("line_separation",7); body.mouse_filter=MOUSE_FILTER_IGNORE; add_child(body)
	counter=label("",Vector2(109,830),Vector2(230,25),14)
	controls=HBoxContainer.new(); controls.position=Vector2(600,824); controls.add_theme_constant_override("separation",8); add_child(controls)
	button(controls,"自动 A",func(): auto=not auto)
	button(controls,"已读快进",skip_read)
	button(controls,"回顾 L",show_log)
	button(controls,"隐藏 H",toggle_box)
	button(controls,"跳过本段",skip_scene)
	action_scroll=ScrollContainer.new(); action_scroll.position=Vector2(340,200); action_scroll.size=Vector2(760,390); add_child(action_scroll)
	actions=VBoxContainer.new(); actions.custom_minimum_size.x=730; actions.add_theme_constant_override("separation",13); action_scroll.add_child(actions); action_scroll.hide()
	index=clampi(int(event.get("page",0)),0,maxi(0,event.get("pages",[]).size()-1))
	if event.kind=="scene":
		for who in event.get("cast",[]):
			expressions[who]="neutral"; poses[who]=event.get("default_pose","turn"); costumes[who]=event.get("default_costume","travel")
		for page in event.pages:
			var who: String=page.get("actor","")
			if who in ["feiyue","xueli","yayu"] and not expressions.has(who) and not page.get("portrait_only",false):
				expressions[who]="neutral"; poses[who]="front"; costumes[who]="regular"
		for j in range(index+1):
			var page: Dictionary=event.pages[j]
			var who: String=page.get("actor","")
			if who=="": continue
			expressions[who]=page.get("expression","neutral"); poses[who]=page.get("pose","front"); costumes[who]=page.get("costume","regular")
			if who in ["feiyue","xueli","yayu"]: front_hero=who
			else: current_npc=who
		if event.has("wardrobe_note"): title_label.text=event.title+"  ·  "+event.wardrobe_note
	if event.kind=="scene": show_page()
	elif event.kind=="cinematic": show_cinematic()
	else: show_prompt()
	gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT: advance(); accept_event())

func label(value: String,at: Vector2,extent: Vector2,font: int) -> Label:
	var n:=Label.new(); n.text=value; n.position=at; n.size=extent; n.mouse_filter=MOUSE_FILTER_IGNORE; n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; n.add_theme_font_size_override("font_size",font); add_child(n); return n
func button(parent: Node,value: String,action: Callable) -> Button:
	var n:=Button.new(); n.text=value; n.custom_minimum_size=Vector2(130,36); n.pressed.connect(action); parent.add_child(n); return n
func page_key(page: Dictionary) -> String: return (str(event.get("id",""))+"|"+str(page.get("speaker",""))+"|"+str(page.text)).sha256_text()
func clear_actions() -> void:
	for n in actions.get_children(): actions.remove_child(n); n.queue_free()

func show_page() -> void:
	choosing=false; wait=0; revealed=0; action_scroll.hide()
	var page: Dictionary=event.pages[index]
	body.text=page.text
	typer.begin(str(page.text),body.get_total_character_count(),float(campaign.state.settings.get("speed",35.0)),abs(page_key(page).hash()))
	body.visible_characters=typer.shown()
	name_label.text=page.get("speaker","旁白")
	counter.text="%02d / %02d   ·   点击 / 空格继续" % [index+1,event.pages.size()]
	var actor: String=page.get("actor","")
	if event.has("cast"):
		# A later speaker may enter, but never reveal someone who has not arrived.
		for who in ["feiyue","xueli","yayu"]:
			if not who in event.cast and who!=actor: expressions.erase(who)
	if actor in ["feiyue","xueli","yayu"]: front_hero=actor
	elif actor!="": current_npc=actor
	var next_cg: String=page.get("cg","")
	if next_cg!=cg_id:
		cg_id=next_cg; cg_view.texture=Art.cg(cg_id); cg_view.modulate.a=0
		if cg_id!="": create_tween().tween_property(cg_view,"modulate:a",1.0,.4)
	cg_view.visible=cg_id!=""
	cg_fit_above_dialogue=bool(page.get("cg_fit_above_dialogue",false)) and not hidden_box
	cg_view.size=Vector2(1440,643) if cg_fit_above_dialogue else size
	cg_view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED if cg_fit_above_dialogue else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cg_view.scale=Vector2.ONE; cg_view.position=Vector2.ZERO
	speaker_portrait.visible=(cg_id!="" or page.get("portrait_only",false)) and actor!=""
	if speaker_portrait.visible: speaker_portrait.texture=Art.bust(actor,page.get("expression","neutral"),page.get("pose","turn"),page.get("costume",event.get("default_costume","travel")))
	body.position.x=295.0 if speaker_portrait.visible else 106.0
	body.size.x=1036.0 if speaker_portrait.visible else 1225.0
	name_label.position.x=295.0 if speaker_portrait.visible else 105.0
	if cg_id!="" and not replay and not cg_id in campaign.state.gallery: campaign.state.gallery.append(cg_id)
	if transition: transition.kill()
	transition=null
	if actor!="":
		expressions[actor]=page.get("expression","neutral"); poses[actor]=page.get("pose","front"); costumes[actor]=page.get("costume","regular")
	var visible_heroes: Array=[]
	for who in ["feiyue","xueli","yayu"]:
		if expressions.has(who): visible_heroes.append(who)
	var npc: String=current_npc
	if front_hero=="" and not visible_heroes.is_empty(): front_hero=visible_heroes[0]
	# A new NPC replaces the right stage; absent cast never leaks from a previous scene.
	for who in actors:
		var n: TextureRect=actors[who]
		var actual: String=npc if who=="other" else who
		var shown: bool=(who=="other" and npc!="") or (who in visible_heroes and (npc=="" or who==front_hero))
		n.visible=shown and cg_id=="" and not page.get("portrait_only",false)
		if not shown: continue
		n.texture=Art.portrait(actual,expressions.get(actual,"neutral"),poses.get(actual,"front"),costumes.get(actual,"regular"))
		var slot: int=visible_heroes.find(who)
		var x: float=900.0 if who=="other" else 30.0 if npc!="" else [30.0,470.0,900.0][clampi(slot,0,2)]
		if npc=="" and visible_heroes.size()==2: x=[110.0,790.0][clampi(slot,0,1)]
		elif npc=="" and visible_heroes.size()==1: x=455.0
		n.position.x=x
		var speaking: bool=actual==actor
		if not transition: transition=create_tween().set_parallel(true)
		transition.tween_property(n,"modulate",Color.WHITE if speaking or actor=="" else Color(.72,.75,.84,.96),.24)
		transition.tween_property(n,"position:y",80.0 if speaking else 90.0,.24)
	campaign.update_page(index)

func record_page() -> void:
	if event.kind!="scene": return
	var page: Dictionary=event.pages[index]
	var key:=page_key(page)
	if not campaign.state.read.has(key):
		campaign.state.read[key]=true
		campaign.state.history.append({"title":event.title,"speaker":page.get("speaker","旁白"),"text":page.text})
		if campaign.state.history.size()>700: campaign.state.history.pop_front()
	campaign.save_campaign()

func advance() -> void:
	if choosing or is_instance_valid(log_panel) or is_instance_valid(video): return
	if hidden_box: toggle_box(); return
	if event.kind=="scene":
		if not typer.finished and typer.total>0:
			typer.finish(); revealed=typer.total; body.visible_characters=-1; return
		record_page()
		if index+1<event.pages.size(): index+=1; show_page()
		elif not event.get("choices",[]).is_empty(): show_choices()
		else: finish()
	elif event.kind=="cinematic": finish()

func show_choices() -> void:
	typer.finish(); body.visible_characters=-1; clear_actions(); choosing=true; auto=false; action_scroll.show()
	for i in event.choices.size():
		var slot: int=i
		var entry: Dictionary=event.choices[i]
		var b:=button(actions,entry.text,func():
			if replay: finish(); return
			if campaign.choose(slot): screen.dismiss_adv())
		b.custom_minimum_size=Vector2(730,62); b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		# Final answers have equal styling and no default-focused answer.
		if i==0 and event.id!="06-13" and event.id!="confirm-resolution": b.grab_focus()
	if event.get("question","")!="": body.text=event.question; body.visible_characters=-1
	counter.text="请选择 · 自动播放已暂停"

func show_prompt() -> void:
	typer.finish()
	for n in actors.values(): n.hide()
	speaker_portrait.hide()
	choosing=true; auto=false
	name_label.text="调查" if event.kind=="question" else "行动确认"
	body.visible_characters=-1; body.text=event.get("question",event.get("text","")); counter.text="选择不会自动替你作答"
	clear_actions(); action_scroll.show()
	if event.kind=="choices": show_choices(); return
	if event.kind=="question":
		for i in event.options.size():
			var slot: int=i
			var b:=button(actions,event.options[i],func():
				if campaign.choose(slot): screen.dismiss_adv()
				else: counter.text="与证据不吻合；查看线索袋后再试。")
			b.custom_minimum_size=Vector2(730,60); b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button(actions,"查看线索袋",show_evidence)
	else:
		button(actions,"从当前阶段继续" if event.kind=="death" else "确认继续",finish).custom_minimum_size=Vector2(730,58)
		if event.kind!="death": button(actions,"先停留，稍后继续",func(): campaign.state.pending={}; campaign.save_campaign(); screen.dismiss_adv()).custom_minimum_size=Vector2(730,48)

func show_cinematic() -> void:
	typer.finish()
	for n in actors.values(): n.hide()
	speaker_portrait.hide()
	name_label.text=event.title; body.visible_characters=-1
	# Reserved video slots are optional. The authored prose makes every missing movie playable.
	var path: String=str(event.get("path","") if event.get("path")!=null else "")
	if path!="" and ResourceLoader.exists(path):
		video=VideoStreamPlayer.new(); video.size=size; video.expand=true; video.stream=load(path); add_child(video); move_child(video,2)
		video.finished.connect(func(): video.queue_free(); video=null; finish()); video.play()
	body.text=event.summary; counter.text="点击继续  ·  过场可跳过" if is_instance_valid(video) else "点击继续  ·  场景过渡"
	shade.color=Color(.015,.008,.025,.93)
	var ornament:=label("◆",Vector2(650,270),Vector2(140,140),80); ornament.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ornament.modulate=Color("be8799")
	create_tween().set_loops().tween_property(ornament,"modulate:a",.35,1.5)

func finish() -> void:
	if replay:
		screen.dismiss_adv(); return
	if campaign.finish_presentation(): screen.dismiss_adv()

func skip_scene() -> void:
	if choosing or event.kind in ["question","choices","confirm","death"]: return
	if event.kind=="scene":
		index=event.pages.size()-1; show_page(); typer.finish(); revealed=body.get_total_character_count(); body.visible_characters=-1; record_page()
		if not event.get("choices",[]).is_empty(): show_choices()
		else: finish()
	elif event.kind=="cinematic":
		if is_instance_valid(video): video.stop(); video.queue_free(); video=null
		finish()

func skip_read() -> void:
	if choosing or event.kind!="scene": return
	while index+1<event.pages.size() and campaign.state.read.has(page_key(event.pages[index])): index+=1
	show_page()

func toggle_box() -> void:
	hidden_box=not hidden_box
	for n in [text_panel,body,name_label,counter,controls]: n.visible=not hidden_box
	if event.kind=="scene":
		cg_fit_above_dialogue=bool(event.pages[index].get("cg_fit_above_dialogue",false)) and not hidden_box
		cg_view.size=Vector2(1440,643) if cg_fit_above_dialogue else size
		cg_view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED if cg_fit_above_dialogue else TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cg_view.scale=Vector2.ONE; cg_view.position=Vector2.ZERO
		speaker_portrait.visible=not hidden_box and (cg_id!="" or event.pages[index].get("portrait_only",false)) and event.pages[index].get("actor","")!=""

func show_log() -> void:
	if is_instance_valid(log_panel): log_panel.queue_free(); log_panel=null; return
	log_panel=Panel.new(); log_panel.position=Vector2(230,110); log_panel.size=Vector2(980,510); add_child(log_panel)
	var l:=RichTextLabel.new(); l.position=Vector2(30,65); l.size=Vector2(920,410); l.add_theme_font_size_override("normal_font_size",19); log_panel.add_child(l)
	for entry in campaign.state.history: l.append_text(entry.speaker+" · "+entry.title+"\n"+entry.text+"\n\n")
	l.scroll_to_line.call_deferred(maxi(0,l.get_line_count()-1))
	var b:=button(log_panel,"返回演出",show_log); b.position=Vector2(790,15)

func show_evidence() -> void:
	show_log()
	if not is_instance_valid(log_panel): return
	var l: RichTextLabel=log_panel.get_child(0)
	l.clear()
	for key in campaign.state.facts:
		var fact: Dictionary=campaign.content.facts.get(key,{"title":key,"text":"已查证"})
		l.append_text(fact.title+"\n"+fact.text+"\n\n")

func handle_key(key: int) -> void:
	match key:
		KEY_SPACE,KEY_ENTER,KEY_KP_ENTER: advance()
		KEY_A: if not choosing: auto=not auto
		KEY_L: show_log()
		KEY_H: toggle_box()
		KEY_ESCAPE:
			if is_instance_valid(log_panel): show_log()
			elif hidden_box: toggle_box()
			else: screen.adv_pause()

func _process(dt: float) -> void:
	elapsed+=dt
	if cg_view.visible and not cg_fit_above_dialogue:
		var zoom:=1.015+minf(elapsed*.0008,.025)
		cg_view.scale=Vector2.ONE*zoom; cg_view.position=(size-size*zoom)*.5
	if choosing or hidden_box or is_instance_valid(log_panel) or event.kind!="scene": return
	var count:=body.get_total_character_count()
	if not typer.finished:
		_tick_type(dt)
	else:
		wait+=dt
		if auto and wait>float(campaign.state.settings.auto_delay)+count*.035: advance()

## 把节奏器放出来的字数抄进 RichTextLabel。放完后 `shown()` 直接返回 -1，
## 一次把 visible_characters 收成"全显"，不留半开状态。
func _tick_type(dt: float) -> void:
	typer.tick(dt)
	revealed=typer.revealed
	body.visible_characters=typer.shown()
	if typer.finished: revealed=typer.total
