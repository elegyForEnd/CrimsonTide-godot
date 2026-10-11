extends Control
signal exit_requested
const Campaign = preload("res://scripts/story_campaign.gd")
const World = preload("res://scripts/story_world.gd")
const UISkin = preload("res://scripts/story_ui_skin.gd")
var campaign = Campaign.new()
var world: Node3D
var active := false
var hud: Control
var overlay: Control
var heading: Label
var stats: Label
var objective: Label
var hint: Label
var message: Label
var hp_bar: ProgressBar
var modal := false
var toast_time := 0.0
var aim := Vector2.DOWN
var screen_time := 0.0
var journal_open := false
var sound: TideSound
var music_signature := ""
var move_target := Vector2.INF
var photo_mode := false
var quest_fx: Control
var combat_fx: Node2D

func _ready() -> void:
	size=Vector2(1440,900); mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme_data := Theme.new()
	theme_data.default_font=load("res://assets/NotoSansSC.ttf")
	theme_data.default_font_size=18
	var frame := StyleBoxFlat.new()
	frame.bg_color=Color("15101f"); frame.border_color=Color("796476")
	frame.set_border_width_all(1); frame.set_corner_radius_all(7)
	theme_data.set_stylebox("panel","Panel",frame)
	var normal := StyleBoxFlat.new()
	normal.bg_color=Color("241a2b"); normal.border_color=Color("796476")
	normal.set_border_width_all(1); normal.set_corner_radius_all(5)
	normal.content_margin_left=12; normal.content_margin_right=12
	theme_data.set_stylebox("normal","Button",normal)
	var hover: StyleBoxFlat=normal.duplicate(); hover.bg_color=Color("493149")
	theme_data.set_stylebox("hover","Button",hover)
	theme_data.set_stylebox("pressed","Button",hover)
	var fill := StyleBoxFlat.new(); fill.bg_color=Color("b24360"); fill.set_corner_radius_all(3)
	theme_data.set_stylebox("fill","ProgressBar",fill)
	var empty := StyleBoxFlat.new(); empty.bg_color=Color("302035"); empty.set_corner_radius_all(3)
	theme_data.set_stylebox("background","ProgressBar",empty)
	theme=theme_data
	UISkin.theme_controls(theme_data)
	world=World.new(); world.name="StoryWorld"; add_child(world)
	combat_fx=preload("res://scripts/story_combat_vfx.gd").new(); combat_fx.screen=self; add_child(combat_fx)
	hud=Control.new(); hud.size=size; hud.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(hud)
	var top := Panel.new(); top.position=Vector2(22,18); top.size=Vector2(600,118); top.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(top)
	top.add_theme_stylebox_override("panel",UISkin.frame(4))
	heading=label(hud,"",Vector2(38,26),Vector2(900,33),23)
	stats=label(hud,"",Vector2(38,63),Vector2(570,28),16)
	hp_bar=ProgressBar.new(); hp_bar.position=Vector2(38,97); hp_bar.size=Vector2(550,15); hp_bar.show_percentage=false; hud.add_child(hp_bar)
	objective=label(hud,"",Vector2(965,85),Vector2(450,145),18)
	var right := Panel.new(); right.position=Vector2(952,74); right.size=Vector2(472,167); right.mouse_filter=Control.MOUSE_FILTER_IGNORE
	right.add_theme_stylebox_override("panel",UISkin.frame(5))
	hud.add_child(right); hud.move_child(right,0)
	button(hud,"任务 J",Vector2(968,24),Vector2(100,38),show_journal)
	button(hud,"行囊 TAB",Vector2(1078,24),Vector2(115,38),show_bag)
	button(hud,"地图 M",Vector2(1203,24),Vector2(100,38),show_travel)
	button(hud,"菜单",Vector2(1313,24),Vector2(95,38),show_menu)
	hint=label(hud,"",Vector2(290,720),Vector2(860,50),21); hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	message=label(hud,"",Vector2(280,670),Vector2(880,50),20); message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label(hud,"WASD 移动  ·  鼠标左键攻击  ·  E 交互  ·  C 人物  ·  空格闪避  ·  Q 技能  ·  R 协同奥义  ·  F 补给  ·  1/2/3 切换主角",Vector2(100,853),Vector2(1240,30),16)
	button(hud,"小队个人委托",Vector2(30,795),Vector2(180,38),show_personal)
	button(hud,"返营路标",Vector2(30,745),Vector2(140,38),func():
		if campaign.state.stage==0: toast("已经在营地。")
		elif campaign.hero_at.distance_to(campaign.map.waypoint)<150: campaign.activate_waypoint(); campaign.travel(int(campaign.state.act),0)
		else: toast("沿原路回营地，或到传送阵附近激活后旅行。"))
	overlay=Control.new(); overlay.size=size; overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(overlay)
	quest_fx=preload("res://scripts/story_quest_fx.gd").new(); quest_fx.screen=self; add_child(quest_fx)
	campaign.quest_event.connect(quest_fx.show_event)
	campaign.location_changed.connect(func(): world.build_story(campaign); refresh())
	campaign.changed.connect(refresh)
	campaign.notice.connect(toast)
	campaign.chapter_read.connect(show_chapter)
	campaign.audio_cue.connect(func(kind: String):
		if sound: sound.play(kind))
	set_active(false)

func start(save_path: String = "") -> void:
	if "--preview-items" in OS.get_cmdline_user_args() or "--preview-quests" in OS.get_cmdline_user_args(): campaign.save_enabled=false
	campaign.load_campaign(save_path)
	var art_preview := false
	# Explicit art-preview launchers are transient, separate from campaign saves.
	if "--preview-story" in OS.get_cmdline_user_args():
		var preview_act := 0; var preview_stage := 0
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--story-act="): preview_act=clampi(int(arg.trim_prefix("--story-act=")),1,6)
			if arg.begins_with("--story-stage="): preview_stage=clampi(int(arg.trim_prefix("--story-stage=")),0,9)
		if preview_act>0:
			art_preview=true
			campaign.save_enabled=false; campaign.state=campaign.new_state()
			campaign.state.unlocked_act=6; campaign.state.waypoints=[]
			for act in range(1,7):
				for stage in range(10 if act==1 else 9): campaign.state.waypoints.append("%d:%d" % [act,stage])
			preview_stage=mini(preview_stage,campaign.content.acts[preview_act-1].maps.size())
			campaign.enter(preview_act,preview_stage)
	set_active(true)
	refresh()
	toast("场景试玩 · 临时进度不保存；在传送阵可选择六幕的全部区域。" if art_preview else "从营地南门向下走探索野外；M 查看地图，E 进入遗迹 / 激活传送阵。")
	if "--preview-items" in OS.get_cmdline_user_args():
		campaign.inventory.initialize()
		campaign.state.coins=1800; campaign.state.materials=40; campaign.state.xp=225
		for base in Campaign.Inventory.BASES:
			campaign.inventory.receive(campaign.inventory.make(base,2,1 if Campaign.Inventory.BASES[base].slot in Campaign.Inventory.SLOTS else 0,3 if base in ["potion","scrap","crystal"] else 1))
		for hero in 3:
			for slot in Campaign.Inventory.SLOTS:
				for item in campaign.state.bag.duplicate():
					if campaign.inventory.can_equip("bag",item.uid,hero,slot): campaign.inventory.equip("bag",item.uid,hero,slot); break
		for base in ["sword","plate","staff","robe","raven","frost"]: campaign.inventory.receive(campaign.inventory.make(base,2,2))
		show_bag()
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--items-shot="): capture_item_preview.call_deferred(argument.trim_prefix("--items-shot="))
	if "--preview-quests" in OS.get_cmdline_user_args():
		for id in ["P-M01","P-M02","P-M03","A1-M01","A1-M02"]: campaign.complete(id,false)
		show_journal("side")

func capture_item_preview(target: String) -> void:
	for i in 24: await get_tree().process_frame
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	var error := get_viewport().get_texture().get_image().save_png(target)
	print("STORY_ITEMS_READY bag=%d worn=%d shot=%s error=%d" % [campaign.state.bag.size(),campaign.state.equipment[0].size()+campaign.state.equipment[1].size()+campaign.state.equipment[2].size(),target,error])

func set_active(value: bool) -> void:
	active=value; visible=value
	set_process(value); set_physics_process(value); set_process_unhandled_input(value)
	if world:
		world.visible=value
		world.view_camera.current=value
	if not value and not campaign.state.is_empty(): campaign.save_campaign()
	if not value and is_instance_valid(quest_fx): quest_fx.clear()
	if not value and is_instance_valid(combat_fx): combat_fx.reset()

func label(parent: Node, text: String, at: Vector2, extent: Vector2, font_size: int = 18) -> Label:
	var node := Label.new(); node.text=text; node.position=at; node.size=extent
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("e4d7cb"))
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node); return node

func button(parent: Node, text: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var node := Button.new(); node.text=text; node.position=at; node.size=extent
	UISkin.button(node)
	node.pressed.connect(action); parent.add_child(node); return node

func refresh() -> void:
	if campaign.state.is_empty() or heading==null: return
	var s: Dictionary=campaign.state
	var act: Dictionary=campaign.act_data()
	var location: String=act.camp if s.stage==0 else act.maps[int(s.stage)-1].name
	heading.text="第%d幕 · %s  /  %s" % [s.act,act.title,location]
	stats.text="%s  Lv.%d    银币 %d    铁料 %d    药剂 %d" % [["绯月","雪璃","鸦羽"][int(s.hero)],campaign.level(),s.coins,s.materials,s.potions]
	hp_bar.max_value=campaign.max_hp(); hp_bar.value=s.hp
	var q := campaign.tracked()
	objective.text="血潮已解除 · 可回访六地" if q.is_empty() else "【%s】\n%s\n%d/%d" % [q.title,q.description,campaign.step_count(q),q.steps.size()]
	queue_redraw()

func toast(text: String) -> void:
	if message: message.text=text
	toast_time=5.0

func _physics_process(dt: float) -> void:
	if not active or modal: return
	var motion := Input.get_vector("left","right","up","down")
	# S is south along the main road; right click provides screen-position walking.
	if motion.length()>0: move_target=Vector2.INF
	elif move_target!=Vector2.INF:
		if campaign.hero_at.distance_to(move_target)<40: move_target=Vector2.INF
		else: motion=campaign.steer("player",campaign.hero_at,move_target)
	if Input.is_action_pressed("sprint"): motion*=1.3
	campaign.update(dt,motion)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not get_viewport().gui_get_hovered_control() is Button:
		campaign.attack(aim)

func _process(dt: float) -> void:
	if not active: return
	screen_time+=dt; toast_time=maxf(0,toast_time-dt); message.visible=toast_time>0
	world.sync_story(size,dt)
	combat_fx.advance(dt)
	var screen_point := get_global_transform_with_canvas()*get_local_mouse_position()
	aim=world.unproject(screen_point)-campaign.hero_at
	var target := nearest()
	hint.text="[E] "+str(target.get("label","")) if not target.is_empty() and not modal else ""
	if int(screen_time*5)!=int((screen_time-dt)*5): refresh(); sync_music()
	queue_redraw()

func project(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse()*world.project(point)

func ground_transform() -> Transform2D:
	return get_global_transform_with_canvas().affine_inverse()*world.ground_transform()

func sync_music() -> void:
	if sound==null: return
	var cue := ""
	for e in campaign.enemies:
		if e.boss and e.hp>0 and e.p.distance_to(campaign.hero_at)<950:
			cue={"bell-hierophant":"bishop","ashen-vesper":"ember","thorn-huntsman":"hunter","mirror-weaver":"mirror","moon-leviathan":"abyss","blood-queen":"queen","earthsplitter":"earth","storm-roc-v2":"storm","frostbone-dragon":"dragon"}.get(e.art,"queen")
	var signature := campaign.key()+cue
	if signature==music_signature: return
	music_signature=signature
	sound.set_scene("camp" if campaign.state.stage==0 else "game")
	if campaign.state.stage>0:
		sound.music.world_cue="city" if campaign.state.act==6 else "ruins"
		sound.music.set_encounter(cue)
		sound.music.select_cue()

func nearest() -> Dictionary:
	var best := 125.0
	var found: Dictionary={}
	for door in campaign.map.entrances():
		if door.p.distance_to(campaign.hero_at)<best:
			best=door.p.distance_to(campaign.hero_at)
			found={"kind":"entrance","door":door,"label":"楼梯 · 返回上一层" if door.kind=="exit" else "进入 · "+campaign.act_data().maps[int(door.stage)-1].name}
	for chest in campaign.nearby_chests():
		if chest.p.distance_to(campaign.hero_at)<best:
			best=chest.p.distance_to(campaign.hero_at); found={"kind":"cache","node":chest,"label":chest.label}
	for object in campaign.objective_nodes():
		var distance: float=object.p.distance_to(campaign.hero_at)
		if distance<best: best=distance; found={"kind":"objective","label":object.label,"node":object}
	if campaign.state.stage==0:
		for i in 6:
			var distance: float=campaign.map.npc_at[i].distance_to(campaign.hero_at)
			if distance<best: best=distance; found={"kind":"npc","index":i,"label":npc_name(i)+" · "+["地区委托","治疗","锻造","故事资料","交易","仓库"][i]}
	if campaign.map.waypoint.distance_to(campaign.hero_at)<125 and found.is_empty():
		found={"kind":"waypoint","label":"传送阵 · 激活 / 旅行"}
	return found

func interact() -> void:
	var target := nearest()
	if target.is_empty(): return
	match target.kind:
		"objective": campaign.interact_object(target.node)
		"npc": show_npc(int(target.index))
		"waypoint": campaign.activate_waypoint(); show_travel()
		"entrance": campaign.use_entrance(target.door)
		"cache": campaign.open_cache(target.node)

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and event.pressed and not modal:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: world.zoom=clampf(world.zoom-1,11,21)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: world.zoom=clampf(world.zoom+1,11,21)
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			var destination: Vector2=world.unproject(get_global_transform_with_canvas()*get_local_mouse_position())
			if campaign.map.walkable(destination): move_target=destination; campaign.routes.erase("player")
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_ESCAPE:
		if modal: close_panel()
		else: show_menu()
	elif modal: return
	else:
		match event.keycode:
			KEY_E: interact()
			KEY_SPACE: campaign.dodge(Input.get_vector("left","right","up","down"))
			KEY_Q: campaign.attack(aim,1)
			KEY_R: campaign.attack(aim,2)
			KEY_F: campaign.heal()
			KEY_1: campaign.switch_hero(0)
			KEY_2: campaign.switch_hero(1)
			KEY_3: campaign.switch_hero(2)
			KEY_J: show_journal()
			KEY_TAB: show_bag()
			KEY_C: show_growth()
			KEY_M: show_travel()
	get_viewport().set_input_as_handled()

func panel(title: String) -> Control:
	close_panel(); modal=true; move_target=Vector2.INF
	var dim := ColorRect.new(); dim.size=size; dim.color=Color(0.015,0.01,0.03,0.78); overlay.add_child(dim)
	var back := Panel.new(); back.position=Vector2(220,125); back.size=Vector2(1000,670); back.add_theme_stylebox_override("panel",UISkin.frame(5)); overlay.add_child(back)
	label(back,title,Vector2(30,18),Vector2(860,38),26)
	button(back,"关闭",Vector2(882,20),Vector2(90,35),close_panel)
	return back

func close_panel() -> void:
	for child in overlay.get_children(): overlay.remove_child(child); child.queue_free()
	modal=false; journal_open=false

func text_block(parent: Control, text: String, at: Vector2, extent: Vector2) -> RichTextLabel:
	var node := RichTextLabel.new(); node.position=at; node.size=extent; node.text=text
	node.add_theme_font_size_override("normal_font_size",18)
	node.add_theme_constant_override("line_separation",8)
	parent.add_child(node); return node

func list_area(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new(); scroll.position=Vector2(30,80); scroll.size=Vector2(940,490); parent.add_child(scroll)
	var column := VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation",9); scroll.add_child(column); return column

func row_button(column: VBoxContainer, text: String, action: Callable) -> Button:
	var node := Button.new(); node.text=text; node.custom_minimum_size=Vector2(880,42); node.alignment=HORIZONTAL_ALIGNMENT_LEFT
	node.pressed.connect(action); column.add_child(node); return node

func show_chapter(title: String, body: String) -> void:
	var back := panel(title)
	text_block(back,body,Vector2(35,80),Vector2(930,480))
	button(back,"记入日志 · 继续",Vector2(720,600),Vector2(245,44),func():
		close_panel()
		if title==campaign.content.quests["A6-M06"].title and "A6-M06" in campaign.state.completed and not "E-M01" in campaign.state.completed: show_final_choice()
		elif title==campaign.content.quests["E-M01"].title and "E-M01" in campaign.state.completed: show_endings())

func show_npc(index: int) -> void:
	if index==2: show_items("forge"); return
	if index==4: show_items("shop"); return
	if index==5: show_bag(true); return
	var person: String=npc_name(index)
	var back := panel(person+" · "+["地区委托","治疗","锻造","故事资料","交易","仓库"][index])
	var lines: Array=["南门连着原野，沿小径能找到遗迹和传送阵。人们还在等着灯亮，我会替你们保留回来的路。","先把灯放下，休息一会儿。你们不用把每一次伤都藏起来。","工具和刃都要有人照顾。带回来的材料可以强化招式，也可以重新整理专精。","记录是为了让后来的人看清发生过什么。这里保留着你们已查证的档案。","药剂一直有备货。别为了带更多东西，把回来的力气也卖掉。","放在这里的物品会保留下来。行囊满了，章节装备也会替你们收好。"]
	var sheet: Texture2D=load("res://assets/story/npc-atlas-v1.png")
	var portrait := TextureRect.new(); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_texture := AtlasTexture.new(); portrait_texture.atlas=sheet; var cell := sheet.get_size()/Vector2(3,2)
	portrait_texture.region=Rect2(Vector2(index%3,int(index/3))*cell,cell); portrait.texture=portrait_texture
	portrait.position=Vector2(30,76); portrait.size=Vector2(108,144); portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE; back.add_child(portrait)
	label(back,"「%s」" % lines[index],Vector2(164,91),Vector2(774,113),20)
	var column := list_area(back)
	column.get_parent().position.y=236; column.get_parent().size.y=335
	var q := campaign.current_main()
	if index==0:
		if "A6-M06" in campaign.state.completed and not "E-M01" in campaign.state.completed: row_button(column,"破冠后的选择 · 再确认女王救援",show_final_choice)
		if not q.is_empty(): row_button(column,"当前主线：「%s」 · %s" % [q.title,q.description],func(): show_chapter(q.title,q.description+"\n\n"+"\n".join(q.steps)))
		if campaign.state.act<6 and "A%d-M06" % campaign.state.act in campaign.state.completed:
			row_button(column,"报告本幕结果 · 乘交通前往下一幕营地",func(): close_panel(); campaign.next_act())
	if index==1: row_button(column,"休息与补给 · 免费恢复生命，药剂至少补至5瓶",func(): campaign.service("heal"); toast("伤口已处理，晨灯仍亮着。"))
	if index==3:
		row_button(column,"查看地区与个人日志",show_journal)
		row_button(column,"王国前史与三位守望者",func(): show_chapter("王国档案",campaign.content.history))
	for id in campaign.content.quests:
		var optional: Dictionary=campaign.content.quests[id]
		if optional.kind=="side" and optional.contact==person and campaign.available(optional):
			var accepted: bool=id in campaign.state.accepted
			row_button(column,("追踪委托 · " if accepted else "接受委托 · ")+optional.title+" / 地图："+campaign.content.acts[int(optional.act)-1].maps[int(optional.stage)-1].name,func():
				campaign.accept(id); toast("已接取「%s」。任务日志可查看目标地点。" % optional.title); close_panel())
	row_button(column,"营地路标 · 回访已发现地区",show_travel)

func show_personal() -> void:
	if campaign.state.stage!=0: toast("回营休息时，可以与伙伴展开个人委托。"); return
	show_journal("personal")

func show_journal(kind: String = "") -> void:
	close_panel(); modal=true; journal_open=true; move_target=Vector2.INF
	var dim := ColorRect.new(); dim.size=size; dim.color=Color(0.005,0.008,0.015,0.8); overlay.add_child(dim)
	var ui=preload("res://scripts/story_quest_ui.gd").new(); ui.screen=self; ui.requested_filter=kind; ui.position=Vector2(72,70); overlay.add_child(ui)

func show_items(tab: String = "bag") -> void:
	close_panel(); modal=true; move_target=Vector2.INF
	var dim := ColorRect.new(); dim.size=size; dim.color=Color(0.005,0.008,0.015,0.8); overlay.add_child(dim)
	var ui=preload("res://scripts/story_items_ui.gd").new()
	ui.screen=self; ui.tab=tab; ui.position=Vector2(72,70); overlay.add_child(ui)

func show_bag(storage: bool = false) -> void:
	show_items("stash" if storage else "bag")

func show_growth() -> void:
	show_items("character")

func show_travel() -> void:
	if campaign.hero_at.distance_to(campaign.map.waypoint)>160:
		show_atlas()
		return
	campaign.activate_waypoint()
	var back := panel("已激活传送阵 · 地区回访")
	var column := list_area(back)
	for place in campaign.state.get("waypoints",["1:0"]):
		var parts: PackedStringArray=place.split(":")
		var a := int(parts[0]); var s := int(parts[1])
		var act: Dictionary=campaign.content.acts[a-1]
		row_button(column,"第%d幕 · %s" % [a,act.camp if s==0 else act.maps[s-1].name],func(): close_panel(); campaign.travel(a,s))
	label(back,"在野外与传送阵交互激活。M 在野外查看探索地图，在传送阵附近打开旅行。",Vector2(30,603),Vector2(920,42),17)

func show_atlas() -> void:
	var back := panel("地区地图 · 行走探索 / 遗迹入口 / 传送阵")
	var atlas=preload("res://scripts/story_atlas.gd").new()
	atlas.campaign=campaign; atlas.position=Vector2(35,82); atlas.size=Vector2(930,500); back.add_child(atlas)
	label(back,"灰色为未探索区域 · 金色为入口与目标 · 青色为传送阵 · 屋顶进入后自动隐藏",Vector2(30,603),Vector2(930,42),16)

func show_final_choice() -> void:
	var back := panel("月冠已碎 · 破冠后的选择")
	text_block(back,"女王失去了六翼与王冠，血潮正在退去。修复过的六路导光将光送向高空。\n\n救援需要三人的全部个人线与「留下她说过的话」。救援不恢复王权，她仍须面对居民的追问。",Vector2(35,85),Vector2(920,330))
	var rescue := button(back,"使用准备好的工具救援女王",Vector2(40,470),Vector2(510,45),func(): campaign.choose_rescue(true); close_panel(); campaign.enter(6,0))
	var ready: bool=campaign.prepared_rescue() and campaign.state.rescue_prepared_at_battle
	rescue.disabled=not ready
	label(back,"救援准备齐全" if ready else "救援准备必须在决战前完成：9个个人节点及 A6-S02。战前存档另有保留。",Vector2(40,530),Vector2(900,36),16)
	button(back,"送她离去 · 回残灯营地报平安",Vector2(40,590),Vector2(510,45),func(): campaign.choose_rescue(false); close_panel(); campaign.enter(6,0))

func show_endings() -> void:
	var text: String=campaign.content.endings["一"].story
	if campaign.prepared_routes(): text+="\n\n"+campaign.content.endings["二"].story
	if campaign.state.queen_rescued: text+="\n\n"+campaign.content.endings["三"].story
	var back := panel("血月尽头，仍有黎明")
	text_block(back,text,Vector2(35,80),Vector2(930,480))
	button(back,"继续回访与重建",Vector2(700,600),Vector2(250,44),close_panel)

func show_menu() -> void:
	var back := panel("故事模式 · 暂停")
	button(back,"继续守望",Vector2(350,160),Vector2(300,48),close_panel)
	button(back,"画面设置",Vector2(350,580),Vector2(300,44),func():
		var settings := panel("画面设置")
		preload("res://scripts/graphics_settings_ui.gd").build(settings,get_node("/root/GraphicsQuality"),Vector2(180,125)))
	if "A6-M06" in campaign.state.completed and not "E-M01" in campaign.state.completed:
		button(back,"破冠后的选择",Vector2(350,520),Vector2(300,48),show_final_choice)
	button(back,"保存并返回标题",Vector2(350,245),Vector2(300,48),func(): campaign.save_campaign(); close_panel(); set_active(false); exit_requested.emit())
	if FileAccess.file_exists(campaign.path+".before-finale"):
		button(back,"恢复决战前记录",Vector2(350,315),Vector2(300,42),func():
			close_panel(); toast("已恢复战前记录，原结局进度另存为 after-finale。" if campaign.restore_before_finale() else "战前记录无法读取。"))
	text_block(back,"战役自动保存，任务、装备与其他模式分开。\n\n六幕均有独立营地。靠近NPC按 E；南门连续步行进入野外。M 查看地图，E 进入副本或激活传送阵。\n\n1/2/3更换操作角色，另外两位伙伴会跟随并协助战斗。",Vector2(110,365),Vector2(800,220))

func _draw() -> void:
	if photo_mode: return
	if not active or world==null or campaign.state.is_empty(): return
	for e in campaign.enemies:
		if e.hp<=0: continue
		var p: Vector2=project(e.p)
		if e.boss or e.p.distance_to(campaign.hero_at)<750:
			draw_rect(Rect2(p+Vector2(-40,-160 if e.boss else -110),Vector2(80,6)),Color("1c1823"))
			draw_rect(Rect2(p+Vector2(-40,-160 if e.boss else -110),Vector2(80*e.hp/e.maxhp,6)),Color("b84a67"))
		if e.windup>0:
			var transform: Transform2D=ground_transform()
			draw_set_transform_matrix(transform)
			var color := Color(1,0.35,0.39,0.20+0.18*sin(screen_time*12))
			if e.shape=="cross":
				draw_rect(Rect2(e.target-Vector2(e.radius,65),Vector2(e.radius*2,130)),color)
				draw_rect(Rect2(e.target-Vector2(65,e.radius),Vector2(130,e.radius*2)),color)
			else:
				draw_circle(e.target,e.radius,color,false,4.0,true)
				if e.shape=="ring": draw_circle(e.target,100,Color("8dbeba"),false,4.0,true)
			draw_set_transform_matrix(Transform2D.IDENTITY)
	for node in campaign.objective_nodes():
		var p: Vector2=project(node.p)
		draw_circle(p,12,Color("d4b277"),false,2.0,true)
		draw_string(theme.default_font,p+Vector2(17,0),node.label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ebd7ac"))
	if campaign.state.stage==0:
		for i in 6:
			var p: Vector2=project(campaign.map.npc_at[i])+Vector2(-65,-120)
			draw_string(theme.default_font,p,npc_name(i)+" · "+["委托","治疗","锻造","档案","交易","仓库"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e5d7bf"))
		var gate: Vector2=project(Vector2(1100,1780))
		draw_string(theme.default_font,gate,"↓ 南门 · "+campaign.act_data().maps[0].name,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("edd49e"))
	for e in campaign.effects:
		if e.kind!="impact": continue # Player attacks now use the textured event-driven layer.
		draw_set_transform_matrix(ground_transform())
		var tone: Color=[Color("ef607f"),Color("94dbef"),Color("b99ae8")][int(e.hero)]
		tone.a=e.time/e.total
		draw_circle(e.p,e.radius,tone,false,4.0,true)
		draw_set_transform_matrix(Transform2D.IDENTITY)

func npc_name(index: int) -> String:
	if campaign.state.act==6 and index==5 and not "A6-M03" in campaign.state.completed: return "临时保管侍从"
	return campaign.act_data().npcs[index]
