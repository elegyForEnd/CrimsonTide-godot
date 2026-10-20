extends Control
signal exit_requested
const Campaign=preload("res://scripts/scarlet/campaign.gd")
const World=preload("res://scripts/scarlet/world.gd")
const ADV=preload("res://scripts/scarlet/adv.gd")
const UISkin=preload("res://scripts/story_ui_skin.gd")
const Art=preload("res://scripts/scarlet/art.gd")
var campaign=Campaign.new()
var world: Node3D
var active:=false
var sound
var hud: Control
var overlay: Control
var modal:=false
var dialogue: Control
var heading: Label
var objective: Label
var hint: Label
var message: Label
var hp_bar: ProgressBar
var skill_label: Label
var boss_name: Label
var boss_bar: ProgressBar
var boss_phase: Label
var speech: Label
var speech_time:=0.0
var toast_time:=0.0
var elapsed:=0.0
var aim:=Vector2.UP
var floating: Array=[]
var attacks: Array=[]
var pause_cover: Control
var photo_mode:=false
var last_music:=""
var account_path:=""
var slots: Array=[]
var move_target:=Vector2.INF
var field_panel: Control
var map_capture
var quest_navigation
var minimap: Control
var tracking_detail: Label

func _ready() -> void:
	size=Vector2(1440,900); mouse_filter=MOUSE_FILTER_IGNORE; theme=Art.theme(); UISkin.theme_controls(theme)
	world=World.new(); world.campaign=campaign; add_child(world)
	map_capture=preload("res://scripts/scarlet/map_capture.gd").new(); map_capture.campaign=campaign; add_child(map_capture)
	quest_navigation=preload("res://scripts/scarlet/quest_navigation.gd").new(); quest_navigation.campaign=campaign
	hud=Control.new(); hud.size=size; hud.mouse_filter=MOUSE_FILTER_IGNORE; add_child(hud)
	var header:=panel_at(hud,Vector2(22,18),Vector2(600,118))
	heading=label(header,"赤月遗书",Vector2(16,8),Vector2(570,55),23)
	hp_bar=ProgressBar.new(); hp_bar.position=Vector2(16,79); hp_bar.size=Vector2(550,15); hp_bar.show_percentage=false
	hp_bar.add_theme_stylebox_override("background",Art.frame(Color("2c2033"),Color("574357"),2)); hp_bar.add_theme_stylebox_override("fill",Art.frame(Color("a94d69"),Color("bf7181"),2)); header.add_child(hp_bar)
	var task_panel:=panel_at(hud,Vector2(952,74),Vector2(472,224))
	objective=label(task_panel,"",Vector2(13,11),Vector2(450,145),18)
	tracking_detail=label(task_panel,"",Vector2(13,153),Vector2(450,59),16)
	tracking_detail.add_theme_color_override("font_color",Color("efd19a"))
	minimap=preload("res://scripts/scarlet/map.gd").new()
	minimap.campaign=campaign; minimap.capture=map_capture; minimap.navigator=quest_navigation; minimap.compact=true
	minimap.position=Vector2(1150,312); minimap.size=Vector2(274,306); minimap.open_requested.connect(show_map); hud.add_child(minimap)
	button(hud,"任务 J",Vector2(968,24),Vector2(100,38),show_journal)
	button(hud,"行囊 TAB",Vector2(1078,24),Vector2(115,38),show_items)
	button(hud,"地图 M",Vector2(1203,24),Vector2(100,38),show_map)
	button(hud,"菜单",Vector2(1313,24),Vector2(95,38),show_menu)
	boss_name=label(hud,"",Vector2(420,612),Vector2(600,34),23); boss_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_bar=ProgressBar.new(); boss_bar.position=Vector2(435,651); boss_bar.size=Vector2(570,12); boss_bar.show_percentage=false; hud.add_child(boss_bar)
	boss_bar.add_theme_stylebox_override("fill",Art.frame(Color("9e4265"),Color("c17d92"),2))
	boss_phase=label(hud,"",Vector2(420,666),Vector2(600,38),16); boss_phase.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	speech=label(hud,"",Vector2(345,140),Vector2(750,72),22); speech.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	speech.add_theme_constant_override("outline_size",7); speech.add_theme_color_override("font_outline_color",Color("0e0c18"))
	hint=label(hud,"",Vector2(300,716),Vector2(840,72),21); hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.add_theme_constant_override("outline_size",5)
	message=label(hud,"",Vector2(315,218),Vector2(745,90),18); message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; message.add_theme_constant_override("outline_size",6)
	button(hud,"小队委托 J",Vector2(30,795),Vector2(180,38),show_journal)
	button(hud,"返营路标",Vector2(30,745),Vector2(140,38),func():
		if campaign.state.stage==0: toast("已经在营地。")
		elif campaign.hero_at.distance_to(campaign.gate_at())<Campaign.INTERACT_RADIUS: campaign.enter_zone("%d:0" % int(campaign.state.act))
		else: toast("沿原路回营，或在路口打开地图旅行。"))
	button(hud,"线索 I",Vector2(1220,795),Vector2(160,38),show_evidence)
	skill_label=label(hud,"",Vector2(225,793),Vector2(970,54),16)
	label(hud,"WASD 移动  ·  左键攻击  ·  E 交互（机关按住）  ·  C 人物  ·  B 遭遇手册  ·  空格闪避  ·  Q 技能  ·  R 协同  ·  F 补给  ·  1/2/3 切换",Vector2(100,853),Vector2(1240,30),16)
	overlay=Control.new(); overlay.size=size; overlay.mouse_filter=MOUSE_FILTER_IGNORE; add_child(overlay)
	campaign.location_changed.connect(func(): world.build(); refresh(); sync_music())
	campaign.changed.connect(refresh); campaign.notice.connect(toast); campaign.combat_event.connect(on_combat_event)
	campaign.fieldwork.opened.connect(show_fieldwork)
	campaign.fieldwork.closed.connect(close_panel)
	campaign.audio_cue.connect(func(kind: String):
		if sound: sound.play(kind))
	campaign.battle_speech.connect(func(who: String,text: String): speech.text=who+"\n“"+text+"”"; speech_time=4.5)
	campaign.presentation_requested.connect(func(event: Dictionary):
		if event.kind=="service": show_items("forge")
		if event.kind=="inventory": show_items(event.tab)
		if event.kind=="map": show_map())
	set_active(false)

func label(parent: Node,value: String,at: Vector2,extent: Vector2,font: int=18) -> Label:
	var n:=Label.new(); n.text=value; n.position=at; n.size=extent; n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; n.mouse_filter=MOUSE_FILTER_IGNORE; n.add_theme_font_size_override("font_size",font); parent.add_child(n); return n
func button(parent: Node,value: String,at: Vector2,extent: Vector2,action: Callable) -> Button:
	var n:=Button.new(); n.text=value; n.position=at; n.size=extent; UISkin.button(n); n.pressed.connect(action); parent.add_child(n); return n
func panel_at(parent: Node,at: Vector2,extent: Vector2) -> Panel:
	var p:=Panel.new(); p.position=at; p.size=extent; p.mouse_filter=MOUSE_FILTER_IGNORE; p.add_theme_stylebox_override("panel",UISkin.frame(4)); parent.add_child(p); return p

func start(save_path: String="") -> void:
	var selected: String=save_path if save_path!="" else "user://story-campaign.json"
	if not selected.ends_with(".scarlet.json"):
		selected=selected.trim_suffix(".json")+".scarlet.json"
		account_path=selected
		slots=[]
		if FileAccess.file_exists(account_path+".slots.json"):
			var index_data: Variant=JSON.parse_string(FileAccess.get_file_as_string(account_path+".slots.json"))
			if index_data is Dictionary:
				slots=index_data.get("slots",[])
				var last: String=index_data.get("active","")
				if last in slots and FileAccess.file_exists(last): selected=last
	elif account_path=="": account_path=selected
	campaign.save_enabled=true; campaign.save_error=""
	var loaded: bool=campaign.load_campaign(selected)
	selected=campaign.path
	set_active(true); world.build(); refresh()
	if not loaded: show_load_error(); return
	if not selected in slots: slots.append(selected)
	save_slot_index(selected)
	if "--preview-scarlet" in OS.get_cmdline_user_args():
		campaign.save_enabled=false
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--scarlet-zone="):
				var z:=arg.trim_prefix("--scarlet-zone=")
				if campaign.content.zones.has(z): campaign.state.unlocked.append(z); campaign.enter_zone(z)
		return
	campaign.begin(); continue_opening()

func save_slot_index(selected: String) -> void:
	var file:=FileAccess.open(account_path+".slots.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"active":selected,"slots":slots}))

func continue_opening() -> void:
	if campaign.current_main().get("id","")=="R-P01" and campaign.state.pending.is_empty():
		var n:=campaign.current_node(); var item:=n.duplicate(true); item.qid="R-P01"; item.p=campaign.hero_at; campaign.use(item)

func set_active(value: bool) -> void:
	active=value; visible=value; set_process(value); set_physics_process(value); set_process_unhandled_input(value)
	if world:
		world.visible=value
		if world.view_camera: world.view_camera.current=value
	if not value and not campaign.state.is_empty(): campaign.save_campaign(); close_panel()

func refresh() -> void:
	if not is_instance_valid(heading) or campaign.state.is_empty(): return
	var s: Dictionary=campaign.state
	var q:=campaign.tracked(); var n:=campaign.current_node(q)
	heading.text="赤月遗书  /  第%d章\n%s" % [int(s.act),campaign.zone().name]
	if campaign.current_main().get("id","").begins_with("R-P"): heading.text="赤月遗书  /  序章\n"+campaign.zone().name
	hp_bar.max_value=campaign.max_hp(); hp_bar.value=s.hp
	objective.text="旅程已完成\n可以回访各地、补做支线，或在鉴赏中回看旅程。" if q.is_empty() else "【%s】\n%s\n%s · %d/%d" % [q.title,n.get("label","收束剧情") if q.id in s.accepted else "待接取 · 与"+str(q.intake.giver)+"交谈／调查",campaign.content.zones[n.get("zone",s.zone)].name,campaign.step_count(q),q.nodes.size()]
	skill_label.text="Q  %s  %.1fs   ·   R 协同 %d%%\nF 药剂 %d   ·   旅费 %d   ·   %s" % [["破势斩","灯下防护","鸦羽突进"][int(s.hero)],campaign.skill_cd,int(campaign.charge),int(s.potions),int(s.coins),"备用剑" if s.sword=="backup" else "普通替代剑" if s.sword=="broken" else "血契剑"]
	if campaign.equipment_combat.barrier>0: skill_label.text+=" · 护盾 %.0f（%.1fs）" % [campaign.equipment_combat.barrier,campaign.equipment_combat.barrier_time]
	var boss: Dictionary={}
	for e in campaign.enemies:
		if e.boss and e.hp>0: boss=e; break
	boss_name.visible=not boss.is_empty(); boss_bar.visible=not boss.is_empty(); boss_phase.visible=not boss.is_empty()
	if not boss.is_empty():
		boss_name.text=boss.name; boss_bar.max_value=boss.maxhp; boss_bar.value=boss.hp
		var info: Dictionary=campaign.content.bosses[boss.key]
		boss_phase.text="%s · %d/%d · %s" % [info.phases[campaign.combat.phase],campaign.combat.phase+1,info.phases.size(),"先解除场内机关" if campaign.combat.armor()<.8 else "攻击机会"]
	queue_redraw()

func toast(value: String) -> void:
	if message: message.text=value
	toast_time=5.0
func _physics_process(dt: float) -> void:
	if not active or modal or not campaign.state.pending.is_empty(): return
	var motion:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).limit_length(1)
	if motion.length()>0: move_target=Vector2.INF
	elif move_target!=Vector2.INF:
		if campaign.hero_at.distance_to(move_target)<20: move_target=Vector2.INF
		else: motion=campaign.navigate(campaign.hero_at,move_target)
	if (InputMap.has_action("sprint") and Input.is_action_pressed("sprint")) or Input.is_physical_key_pressed(KEY_SHIFT): motion*=1.3
	campaign.update(dt,motion,Input.is_physical_key_pressed(KEY_E))
	if not campaign.state.pending.is_empty(): return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not get_viewport().gui_get_hovered_control() is Button: campaign.attack(aim)
func _process(dt: float) -> void:
	if not active: return
	elapsed+=dt; toast_time=maxf(0,toast_time-dt); speech_time=maxf(0,speech_time-dt)
	message.visible=toast_time>0 and not modal; speech.visible=speech_time>0 and not modal
	world.sync(dt if is_instance_valid(field_panel) else 0 if modal else dt)
	if not campaign.state.is_empty():
		map_capture.refresh()
		quest_navigation.refresh(dt)
		tracking_detail.text="◆ "+quest_navigation.target.get("label","")+"\n"+quest_navigation.distance_text() if not quest_navigation.target.is_empty() else ""
	aim=world.unproject(get_global_transform_with_canvas()*get_local_mouse_position())-campaign.hero_at
	if not campaign.state.pending.is_empty() and not is_instance_valid(dialogue): present_pending()
	var n:=campaign.nearest()
	hint.text="[E] "+n.label if not n.is_empty() and not modal else ""
	if not n.is_empty() and not modal and campaign.fieldwork.supports(n): hint.text+="\n"+campaign.fieldwork.summary(n)
	if not campaign.interaction.is_empty(): hint.text="按住 E · "+campaign.interaction.label+"  %d%%" % int(campaign.interaction.time/campaign.interaction.total*100)
	if not campaign.water_hazard.is_empty() and not modal: hint.text="红潮将在 %.1f 秒后冲过下层甲板 · 先带伤者到高处" % campaign.water_hazard.delay
	for f in floating: f.time-=dt
	floating=floating.filter(func(f): return f.time>0)
	for effect in attacks: effect.time-=dt
	attacks=attacks.filter(func(e): return e.time>0)
	queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseButton and event.pressed and not modal:
		if event.button_index==MOUSE_BUTTON_RIGHT: move_target=world.unproject(event.position)
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: world.zoom=clampf(world.zoom-1,11,21)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: world.zoom=clampf(world.zoom+1,11,21)
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(field_panel):
		field_panel.handle_key(event.keycode); get_viewport().set_input_as_handled(); return
	if is_instance_valid(pause_cover):
		if event.keycode==KEY_ESCAPE: pause_cover.queue_free(); pause_cover=null
		get_viewport().set_input_as_handled(); return
	if is_instance_valid(dialogue): dialogue.handle_key(event.keycode); get_viewport().set_input_as_handled(); return
	if event.keycode==KEY_ESCAPE:
		if modal: close_panel()
		else: show_menu()
	elif not modal:
		match event.keycode:
			KEY_E: campaign.use(campaign.nearest())
			KEY_SPACE: campaign.dodge(Input.get_vector("left","right","up","down"))
			KEY_Q: campaign.attack(aim,1)
			KEY_R: campaign.attack(aim,2)
			KEY_F: campaign.heal()
			KEY_1: campaign.switch_hero(0)
			KEY_2: campaign.switch_hero(1)
			KEY_3: campaign.switch_hero(2)
			KEY_J: show_journal()
			KEY_I: show_evidence()
			KEY_TAB: show_items()
			KEY_M: show_map()
			KEY_C: show_party()
			KEY_B: preload("res://scripts/scarlet/bestiary.gd").open(self)
	get_viewport().set_input_as_handled()

func present_pending() -> void:
	close_panel(); modal=true; hud.hide()
	dialogue=ADV.new(); dialogue.screen=self; dialogue.campaign=campaign; dialogue.event=campaign.state.pending.duplicate(true); overlay.add_child(dialogue)
func dismiss_adv() -> void:
	if is_instance_valid(dialogue): overlay.remove_child(dialogue); dialogue.queue_free()
	dialogue=null; modal=false; hud.show(); continue_opening()
	if campaign.state.ending_seen and not campaign.state.world.get("credits_shown",false) and campaign.state.pending.is_empty():
		campaign.state.world.credits_shown=true; campaign.save_campaign(); show_credits()
func adv_pause() -> void:
	if is_instance_valid(pause_cover): return
	pause_cover=Control.new(); pause_cover.size=size; pause_cover.mouse_filter=MOUSE_FILTER_STOP; overlay.add_child(pause_cover)
	var dim:=ColorRect.new(); dim.color=Color(0,0,0,.8); dim.size=size; pause_cover.add_child(dim)
	var p:=panel_at(pause_cover,Vector2(460,280),Vector2(520,300))
	label(p,"演出已暂停",Vector2(32,25),Vector2(450,45),28)
	button(p,"继续阅读",Vector2(70,100),Vector2(380,50),func(): pause_cover.queue_free(); pause_cover=null)
	button(p,"保存并返回标题",Vector2(70,180),Vector2(380,50),func(): campaign.save_campaign(); set_active(false); exit_requested.emit())
func close_panel() -> void:
	if not campaign.fieldwork.active.is_empty(): campaign.fieldwork.cancel(); return
	if not is_instance_valid(overlay): return
	for n in overlay.get_children(): overlay.remove_child(n); n.queue_free()
	dialogue=null; pause_cover=null; field_panel=null; modal=false
	if hud: hud.visible=not photo_mode
func show_fieldwork() -> void:
	move_target=Vector2.INF
	modal=true; hud.hide()
	field_panel=preload("res://scripts/scarlet/fieldwork_ui.gd").new()
	field_panel.screen=self; field_panel.activity=campaign.fieldwork; overlay.add_child(field_panel)
func panel(title: String) -> Control:
	close_panel(); modal=true
	var dim:=ColorRect.new(); dim.size=size; dim.color=Color(.02,.015,.04,.84); dim.mouse_filter=MOUSE_FILTER_STOP; overlay.add_child(dim)
	var p:=Panel.new(); p.position=Vector2(100,88); p.size=Vector2(1240,720); overlay.add_child(p)
	label(p,title,Vector2(30,20),Vector2(1060,45),28); button(p,"返回",Vector2(1100,22),Vector2(105,40),close_panel); return p
func column(parent: Control,at: Vector2,extent: Vector2) -> VBoxContainer:
	var scroll:=ScrollContainer.new(); scroll.position=at; scroll.size=extent; parent.add_child(scroll)
	var box:=VBoxContainer.new(); box.size_flags_horizontal=SIZE_EXPAND_FILL; box.custom_minimum_size.x=extent.x-25; box.add_theme_constant_override("separation",14); scroll.add_child(box); return box
func row(parent: VBoxContainer,text: String,action: Callable,disabled: bool=false) -> Button:
	var b:=Button.new(); b.text=text; b.custom_minimum_size=Vector2(0,58); b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.disabled=disabled; b.pressed.connect(action); parent.add_child(b); return b
func prose(parent: VBoxContainer,text: String,font: int=18) -> Label:
	var l:=Label.new(); l.text=text; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.add_theme_font_size_override("font_size",font); parent.add_child(l); return l

func show_journal() -> void:
	var p:=panel("旅程 · 任务与已经发生的事")
	var list:=column(p,Vector2(25,90),Vector2(540,580)); var detail:=column(p,Vector2(600,90),Vector2(610,580))
	fill_details(detail,campaign.tracked())
	prose(list,"主线 %d / 40 · 可选委托 %d / 6" % [campaign.state.completed.filter(func(id): return id.begins_with("R-")).size(),campaign.state.completed.filter(func(id): return id.begins_with("S")).size()],20)
	for kind in ["main","side"]:
		prose(list,"主线旅程" if kind=="main" else "可选故事",23)
		for item in campaign.content.quests.values():
			if item.kind!=kind: continue
			var id: String=item.id; var done: bool=id in campaign.state.completed; var unlocked: bool=campaign.available(item)
			if not done and not unlocked: continue
			row(list,("✓ " if done else "◆ " if unlocked else "· ")+item.title,func():
				for n in detail.get_children(): detail.remove_child(n); n.queue_free()
				fill_details(detail,campaign.content.quests[id]))
func fill_details(box: VBoxContainer,q: Dictionary) -> void:
	if q.is_empty(): prose(box,"旅程已经结束。可以回访与鉴赏。"); return
	prose(box,q.title,26); prose(box,"第%d章 · %s" % [int(q.act),campaign.content.zones["%d:%d" % [q.act,q.stage]].name])
	var done: bool=q.id in campaign.state.completed
	for i in q.nodes.size():
		if i>campaign.step_count(q) and not done: continue
		var n: Dictionary=q.nodes[i]
		if not campaign.node_enabled(n): continue
		prose(box,("✓ " if i<campaign.step_count(q) else "→ ")+n.label+"\n地点："+campaign.content.zones[n.zone].name)
		if i==campaign.step_count(q) and campaign.fieldwork.supports(n): prose(box,campaign.fieldwork.summary(n)+"\n"+campaign.fieldwork.profiles[n.id].hint,16)
	if q.has("intake"):
		var final: Dictionary=q.nodes[-1]
		for index in range(q.nodes.size()-1,-1,-1):
			if campaign.node_enabled(q.nodes[index]): final=q.nodes[index]; break
		prose(box,"接取："+q.intake.giver+"\n地点："+q.intake.place+"\n交接："+campaign.content.zones[final.zone].name+" · "+final.label,16)
	if not done and not q.id in campaign.state.accepted: prose(box,"状态：已询问，尚未接取。回到现场按 E 交谈／调查。" if campaign.state.intake_viewed.has(q.id) else "状态：可接取。到上述地点按 E 交谈／调查；任务册只用于查看。",17)
	elif campaign.available(q): row(box,"追踪这项任务",func(): campaign.track(q.id); close_panel())
	if not done and not q.id in campaign.state.accepted and q.id==campaign.current_main().get("id",""):
		row(box,"追踪接取地点",func(): campaign.track(q.id); close_panel())
	if done: prose(box,"结果已保存。鉴赏回看不会重复发奖或更改世界。")
func show_evidence() -> void:
	var p:=panel("线索袋 · 只记录角色已经查证的事实"); var box:=column(p,Vector2(40,90),Vector2(1150,580))
	if campaign.state.facts.is_empty(): prose(box,"暂时没有实物证据。先查看眼前的信与追缉令。"); return
	for key in campaign.state.facts:
		var fact: Dictionary=campaign.content.facts.get(key,{"title":key,"text":"已查证"}); prose(box,fact.title,23); prose(box,fact.text+"\n")
func show_map() -> void:
	var p:=panel("地区路线 · 营地与现场之间"); var box:=column(p,Vector2(645,95),Vector2(555,535))
	quest_navigation.remaining=0; quest_navigation.refresh()
	var local_map:=preload("res://scripts/scarlet/map.gd").new(); local_map.campaign=campaign; local_map.capture=map_capture; local_map.navigator=quest_navigation; local_map.position=Vector2(30,95); local_map.size=Vector2(580,535); p.add_child(local_map)
	var can_travel: bool=campaign.can_travel()
	prose(box,"当前位置："+campaign.zone().name+"\n"+("选择已开放区域出发。" if can_travel else "路线可查；前往原地图的传送阵后才能出发。战斗和护送需先完成当前安全段。"),20)
	var n:=campaign.current_node()
	if not n.is_empty(): prose(box,"当前目标在："+campaign.content.zones[n.zone].name+" · "+n.label,21)
	for a in range(1,7):
		var places: Array=[]
		for z in campaign.state.unlocked:
			if int(z.get_slice(":",0))==a: places.append(z)
		if places.is_empty(): continue
		prose(box,"第%d章 · %s" % [a,campaign.content.acts[a-1].title],22)
		for z in places:
			var target: String=z
			row(box,("● " if target==campaign.state.zone else "→ ")+campaign.content.zones[z].name,func(): close_panel(); campaign.enter_zone(target),not can_travel or target==campaign.state.zone or not target in campaign.state.waypoints)
	label(p,"原野外道路与副本入口可直接行走。传送阵激活后可旅行，回访保留剧情结果。",Vector2(40,651),Vector2(1150,35),17)
func show_party() -> void: show_items("character")
func show_service() -> void: show_items("forge")
func show_gallery() -> void:
	var p:=panel("记忆鉴赏 · 回看不改变任务与结局"); var box:=column(p,Vector2(35,95),Vector2(1160,580))
	prose(box,"CG 插画",24)
	for id in campaign.state.gallery:
		var cg: String=id
		row(box,cg,func(): play_replay({"id":"gallery:"+cg,"kind":"scene","title":"CG 鉴赏 · "+cg,"pages":[{"speaker":"记忆","actor":"","text":"点击继续返回。此处仅回看插画，不会提交任务。","cg":cg}],"choices":[],"page":0}))
	prose(box,"已经看过的场景",24)
	for id in campaign.content.scenes:
		if not campaign.state.seen.has(id): continue
		var sid: String=id
		row(box,campaign.content.scenes[id].title,func():
			var e: Dictionary=campaign.content.scenes[sid].duplicate(true); e.kind="scene"; e.page=0; play_replay(e))
	prose(box,"结局收藏："+" / ".join(campaign.state.ending_collection))
func play_replay(event: Dictionary) -> void:
	close_panel(); modal=true; hud.hide(); dialogue=ADV.new(); dialogue.screen=self; dialogue.campaign=campaign; dialogue.event=event; dialogue.replay=true; overlay.add_child(dialogue)
func show_menu() -> void:
	var p:=panel("赤月遗书 · 暂停")
	button(p,"继续游戏",Vector2(90,110),Vector2(480,58),close_panel)
	button(p,"任务与旅程",Vector2(90,192),Vector2(480,58),show_journal)
	button(p,"记忆鉴赏",Vector2(90,274),Vector2(480,58),show_gallery)
	button(p,"保存并返回标题",Vector2(90,356),Vector2(480,58),func(): campaign.save_campaign(); set_active(false); exit_requested.emit())
	button(p,"新建独立战役槽",Vector2(90,438),Vector2(480,58),new_slot)
	button(p,"切换已有战役记录",Vector2(90,520),Vector2(480,58),show_slots)
	button(p,"恢复决战前记录",Vector2(660,110),Vector2(480,58),confirm_restore).disabled=not FileAccess.file_exists(campaign.path+".before-finale")
	button(p,"从王冠回答前重新选择",Vector2(660,192),Vector2(480,58),func():
		var view:=panel("回到绯月回答之前")
		label(view,"当前结局另存为 after-finale。恢复已接收最后六人、已解除强制认证的安全记录，再由你回答王冠的事。",Vector2(100,140),Vector2(1020,160),23)
		button(view,"另存当前结局，恢复安全记录",Vector2(340,365),Vector2(550,65),func():
			close_panel()
			if campaign.restore_snapshot(".pre-choice"): campaign.begin(); world.build(); refresh()
			else: toast("回答前记录无法读取，当前进度保留。"))).disabled=not FileAccess.file_exists(campaign.path+".pre-choice")
	label(p,"阅读速度",Vector2(660,212),Vector2(440,35),21)
	var speed:=HSlider.new(); speed.position=Vector2(660,270); speed.size=Vector2(440,35); speed.min_value=15; speed.max_value=80; speed.value=campaign.state.settings.speed
	speed.value_changed.connect(func(value: float): campaign.state.settings.speed=value; campaign.save_campaign()); p.add_child(speed)
	label(p,"当前记录：\n"+campaign.path+"\n\n旧版战役记录不会被覆盖。\n视频尚未制作，当前用对应场景文字衔接。",Vector2(660,365),Vector2(450,200),17)
func new_slot() -> void:
	var p:=panel("新建一条独立的旅程")
	label(p,"现有战役文件保留。新旅程使用新的时间戳槽位，从序章开始。",Vector2(100,145),Vector2(1000,90),23)
	button(p,"创建并开始",Vector2(350,320),Vector2(510,70),func(): close_panel(); start("user://story-new-%d.scarlet.json" % int(Time.get_unix_time_from_system())))
func show_slots() -> void:
	var p:=panel("独立战役记录"); var box:=column(p,Vector2(45,100),Vector2(1135,550))
	for saved in slots:
		var target: String=saved
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(target)) if FileAccess.file_exists(target) else null
		var summary: String="尚未保存"
		if data is Dictionary:
			summary="第%d章 · %s · 已完成 %d 项" % [int(data.get("act",1)),"战后" if data.get("ending_seen",false) else "旅途中",data.get("completed",[]).size()]
		row(box,("当前 · " if target==campaign.path else "继续 · ")+summary+"\n"+target,func(): campaign.save_campaign(); close_panel(); start(target))
func confirm_restore() -> void:
	var p:=panel("恢复到进入王座前")
	label(p,"当前世界将备份为 after-finale，再恢复战前记录。已收藏 CG、已读文字与结局收藏保留。两条结局不会叠加成同一个世界。",Vector2(100,135),Vector2(1020,170),23)
	button(p,"确认恢复战前记录",Vector2(350,350),Vector2(500,65),func():
		close_panel()
		if campaign.restore_before_finale(): world.build(); refresh()
		else: toast("战前记录无法读取，当前世界未改动。"))
func show_load_error() -> void:
	var p:=panel("存档未能读取"); label(p,campaign.save_error,Vector2(100,130),Vector2(1000,140),23); button(p,"创建新的独立槽",Vector2(350,360),Vector2(500,60),new_slot)
func show_credits() -> void:
	var p:=panel("赤月遗书 · 旅程终点")
	label(p,"血潮守望\n赤月遗书\n\n绯月 · 雪璃 · 鸦羽\n\n故事与制作：项目开发者\n新增插画：内置 imagegen 生成\n\n感谢你走回等候的人身边。",Vector2(200,105),Vector2(840,420),25).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button(p,"返回战后营地",Vector2(420,590),Vector2(400,55),func(): close_panel(); campaign.state.unlocked.append("6:0"); campaign.enter_zone("6:0"))
func sync_music() -> void:
	if not sound: return
	var scene: String="camp" if campaign.state.stage==0 else "castle" if campaign.state.act==6 else "ruins"
	if scene!=last_music: last_music=scene; sound.set_scene(scene)
func on_combat_event(event: Dictionary) -> void:
	world.effect(event)
	if event.kind=="fieldwork_complete": floating.append({"p":event.p,"text":"✓  "+event.label,"time":2.8,"total":2.8})
	
	if sound:
		if event.kind=="attack": sound.play("magic" if event.hero==1 else "slash")
		elif event.kind=="heal": sound.play("heal")
func project(p: Vector2) -> Vector2: return get_global_transform_with_canvas().affine_inverse()*world.project(p)
func ground_transform() -> Transform2D:
	var origin:=project(Vector2.ZERO); return Transform2D(project(Vector2.RIGHT)-origin,project(Vector2.DOWN)-origin,origin)
func world_circle(p: Vector2,radius: float,color: Color,width: float=2) -> void:
	var points:=PackedVector2Array()
	for i in 49: points.append(project(p+Vector2.RIGHT.rotated(i*TAU/48)*radius))
	draw_polyline(points,color,width,true)
func world_polygon(points: Array,color: Color) -> void:
	var projected:=PackedVector2Array()
	for p in points: projected.append(project(p))
	if projected.size()>2: draw_colored_polygon(projected,color)
func hazard_polygon(h: Dictionary) -> Array:
	var points: Array=[]; var center: Vector2=h.p
	if h.shape=="flood":
		var half: Vector2=h.size*.5
		return [center-half,center+Vector2(half.x,-half.y),center+half,center+Vector2(-half.x,half.y)]
	if h.shape in ["line","rect"]:
		var along: Vector2=h.direction if h.shape=="line" else Vector2.DOWN; var cross:=Vector2(-along.y,along.x)
		var length: float=float(h.get("reach",520 if h.shape=="line" else 470)); var width: float=h.radius*.4 if h.shape=="line" else h.radius
		return [center-along*length-cross*width,center+along*length-cross*width,center+along*length+cross*width,center-along*length+cross*width]
	if h.shape=="cone":
		points.append(center)
		for i in 25: points.append(center+Vector2(h.direction).rotated(lerpf(-1.21,1.21,i/24.0))*h.radius)
		return points
	for i in 48: points.append(center+Vector2.RIGHT.rotated(i*TAU/48)*h.radius)
	return points
func _draw() -> void:
	if not active or modal or photo_mode or campaign.state.is_empty(): return
	var visible_hazards: Array=campaign.combat.hazards.duplicate()
	if not campaign.water_hazard.is_empty(): visible_hazards.append(campaign.water_hazard)
	for h in visible_hazards:
		var tint:=Color(1,.48,.56,.8) if h.delay>0 else Color(1,.75,.5,.95)
		if h.shape=="ring":
			world_circle(h.p,h.radius,tint,3); world_circle(h.p,float(h.get("inner",135)),Color("8dbeba"),3)
		else:
			var polygon:=PackedVector2Array()
			for point in hazard_polygon(h): polygon.append(project(point))
			if polygon.size()>2: polygon.append(polygon[0]); draw_polyline(polygon,tint,3,true)
	for item in campaign.objective_nodes():
		var p:=project(item.p); var tone:=Color("98d9d4") if item.kind in ["gadget","receive"] else Color("e3c484")
		if campaign.fieldwork.supports(item):
			var near: bool=item.p.distance_to(campaign.hero_at)<350
			if near:
				var at:=p+Vector2(0,-78-sin(elapsed*2)*3)
				draw_polyline(PackedVector2Array([at+Vector2(0,-8),at+Vector2(7,0),at+Vector2(0,8),at+Vector2(-7,0),at+Vector2(0,-8)]),tone,1.5,true)
				draw_string(theme.default_font,p+Vector2(19,-38),item.label,HORIZONTAL_ALIGNMENT_LEFT,330,16,tone)
			continue
		world_circle(item.p,44+sin(elapsed*2)*3,tone,.9); draw_circle(p-Vector2(0,28),5,tone)
		if item.p.distance_to(campaign.hero_at)<420: draw_string(theme.default_font,p+Vector2(18,-18),item.label,HORIZONTAL_ALIGNMENT_LEFT,-1,17,tone)
	for person in campaign.escort_group:
		var p:=project(person.p); draw_string(theme.default_font,p+Vector2(-35,-100),person.name+(" · E扶起" if person.hp<=0 else ""),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a6d9d8"))
	for e in campaign.enemies:
		if e.hp<=0 or e.boss: continue
		if campaign.combat.context.get("stealth",false):
			var points: Array=[e.p]
			for i in 20: points.append(e.p+Vector2(e.get("watch",Vector2.UP)).rotated(lerpf(-.98,.98,i/19.0))*330)
			world_polygon(points,Color(.95,.75,.35,.16))
		var p:=project(e.p)-Vector2(35,115); draw_rect(Rect2(p,Vector2(70,5)),Color("342235")); draw_rect(Rect2(p,Vector2(70*e.hp/e.maxhp,5)),Color("d87889"))
		var statuses := ""
		if float(e.get("rpg_bleed_time",0))>0: statuses+="裂伤 "
		if float(e.get("rpg_slow_time",0))>0: statuses+="寒意 "
		if float(e.get("rpg_vulnerable_time",0))>0: statuses+="易伤"
		if statuses!="": draw_string(theme.default_font,p+Vector2(-6,-8),statuses,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("9ed4ec"))
	for f in floating:
		var p:=project(f.p)+Vector2(0,-135-(1-f.time/f.total)*60); draw_string(theme.default_font,p,f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(1,.9,.8,f.time/f.total))

func npc_name(index: int) -> String:
	return ["小队教官","仓库管理员","工匠","医护","补给商人","联系人"][clampi(index,0,5)]
func show_items(tab: String="bag") -> void:
	close_panel(); modal=true; campaign.inventory.initialize()
	var dim:=ColorRect.new(); dim.size=size; dim.color=Color(.005,.008,.015,.8); overlay.add_child(dim)
	var ui=preload("res://scripts/story_items_ui.gd").new(); ui.screen=self; ui.tab=tab; ui.position=Vector2(72,70); overlay.add_child(ui)
