extends Node

const BG := Color("0d121c")
const PANEL := Color("151b27")
const INK := Color("e7dfd5")
const MUTED := Color("969aaa")
const RED := Color("ad4056")
const GOLD := Color("c5a67b")
var profile := Profile.new()
var session: TideSession
var sound: TideSound
var field: Battlefield
var canvas: CanvasLayer
var root: Control
var page: Control
var overlay: Control
var toast: Label
var page_name := "title"
var hud: Dictionary = {}
var inventory_open := false
var selected := -1
var rotated := false
var bag_signature := ""
var nickname: LineEdit
var address: LineEdit
var long_run := false
var extra_meds := 0
var toast_time := 0.0
var modal := false
var ready_local := false
var time_ui := 0.0
var title_font: Font
var ultimate: UltimateCinematic

func _ready() -> void:
	profile.load_profile()
	setup_inputs()
	sound=TideSound.new()
	add_child(sound)
	session=TideSession.new()
	session.name="Session"
	add_child(session)
	field=Battlefield.new()
	field.session=session
	field.visible=false
	add_child(field)
	canvas=CanvasLayer.new()
	add_child(canvas)
	root=Control.new()
	root.size=Vector2(1440,900)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	root.theme=make_theme()
	var serif := FontVariation.new()
	serif.base_font=load("res://assets/NotoSerifSC.ttf")
	serif.variation_embolden=0.55
	title_font=serif
	page=Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(page)
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	toast=label(root,"",Vector2(230,752),19,GOLD,Vector2(980,38))
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast.z_index=50
	session.started.connect(on_started)
	session.finished.connect(on_finished)
	session.changed.connect(on_lobby)
	session.message.connect(notify)
	session.effect.connect(on_effect)
	session.combat_event.connect(on_combat_audio)
	get_viewport().size_changed.connect(fit_ui)
	fit_ui()
	var cinema_layer := CanvasLayer.new()
	cinema_layer.layer=100
	add_child(cinema_layer)
	ultimate=UltimateCinematic.new()
	cinema_layer.add_child(ultimate)
	ultimate.burst.connect(func(): sound.burst_cinematic(ultimate.hero))
	ultimate.ended.connect(sound.end_cinematic)
	ultimate.began.connect(sound.begin_cinematic)
	session.combat_event.connect(func(data: Dictionary):
		if data.kind=="skill" and int(data.get("id",-1))==session.my_id() and page_name=="game":
			ultimate.play(int(data.hero),session.online)
	)
	set_volume(float(profile.data.volume))
	set_voice_volume(float(profile.data.voice_volume))
	if profile.data.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	show_title()
	# A deterministic screenshot/smoke path, separate from normal player saves.
	if "--preview-camp" in OS.get_cmdline_user_args():
		session.solo(config())
	if "--preview-game" in OS.get_cmdline_user_args():
		session.solo(config())
		session.launch(false,1729)
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/preview-"+page_name+".png")
		get_tree().quit()

func fit_ui() -> void:
	var view := get_viewport().get_visible_rect().size
	var scale_factor := minf(view.x/1440,view.y/900)
	root.scale=Vector2.ONE*scale_factor
	root.position=(view-Vector2(1440,900)*scale_factor)/2

func setup_inputs() -> void:
	var keys := {"left":KEY_A,"right":KEY_D,"up":KEY_W,"down":KEY_S,"interact":KEY_E,"reload":KEY_R,"skill":KEY_Q,"dash":KEY_SPACE,"sprint":KEY_SHIFT,"heal":KEY_F,"burn":KEY_B,"bag":KEY_TAB,"map":KEY_M,"pause":KEY_ESCAPE,"weapon_0":KEY_4,"weapon_1":KEY_1,"weapon_2":KEY_2,"weapon_3":KEY_3}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode=keys[action]
		InputMap.action_add_event(action,event)
	InputMap.add_action("fire")
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire",click)

func make_theme() -> Theme:
	var theme := Theme.new()
	var face := FontVariation.new()
	face.base_font=load("res://assets/NotoSansSC.ttf")
	face.variation_opentype={"wght":450.0}
	face.variation_embolden=0.45
	theme.default_font=face
	theme.default_font_size=18
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","Button",INK)
	theme.set_color("font_hover_color","Button",Color.WHITE)
	theme.set_color("font_disabled_color","Button",Color("5f6576"))
	theme.set_stylebox("normal","Button",style(Color("202332"),Color("46404b")))
	theme.set_stylebox("hover","Button",style(Color("52303e"),Color("b36272")))
	theme.set_stylebox("pressed","Button",style(Color("702f43"),GOLD))
	theme.set_stylebox("focus","Button",style(Color(0,0,0,0),GOLD))
	theme.set_stylebox("disabled","Button",style(Color("161c27"),Color("303642")))
	theme.set_stylebox("normal","LineEdit",style(Color("121724"),Color("4f4657")))
	theme.set_stylebox("focus","LineEdit",style(Color("1b2030"),GOLD))
	theme.set_color("font_color","LineEdit",INK)
	theme.set_color("font_placeholder_color","LineEdit",MUTED)
	return theme

func style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color
	s.border_color=border
	s.border_width_top=1 if border.a>0 else 0
	s.border_width_bottom=1 if border.a>0 else 0
	s.set_corner_radius_all(10)
	s.content_margin_left=18
	s.content_margin_right=18
	s.content_margin_top=10
	s.content_margin_bottom=10
	return s

func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func rect(parent: Node, at: Vector2, size: Vector2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var panel := Panel.new()
	panel.position=at
	panel.size=size
	panel.add_theme_stylebox_override("panel",style(color,border))
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func label(parent: Node, text: String, at: Vector2, font_size: int = 18, color: Color = INK, size: Vector2 = Vector2(700,40)) -> Label:
	var l := Label.new()
	l.text=text
	l.clip_text=true
	l.position=at
	l.size=size
	l.add_theme_font_size_override("font_size",font_size)
	if font_size>=28:
		l.add_theme_font_override("font",title_font)
	l.add_theme_color_override("font_shadow_color",Color(0.015,0.01,0.018,0.85))
	l.add_theme_constant_override("shadow_offset_y",2)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Node, text: String, at: Vector2, size: Vector2, callback: Callable, primary: bool = false) -> Button:
	var b := GothicButton.new()
	b.primary=primary
	b.accent=GOLD
	b.serif=title_font
	b.text=text
	b.position=at
	b.size=size
	b.focus_mode=Control.FOCUS_NONE
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): sound.play("ui"); callback.call())
	parent.add_child(b)
	return b

func ornament(parent: Node, at: Vector2, dimensions: Vector2, mode: String = "line", color: Color = GOLD) -> UIOrnament:
	var art := UIOrnament.new()
	art.position=at
	art.size=dimensions
	art.mode=mode
	art.accent=color
	parent.add_child(art)
	return art

func fade(parent: Node, at: Vector2, dimensions: Vector2, color: Color, reverse: bool = false, vertical: bool = false) -> void:
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color(color,0),color] if reverse else [color,Color(color,0)])
	var texture := GradientTexture2D.new()
	texture.gradient=gradient
	texture.width=256
	texture.height=4
	if vertical:
		texture.width=4
		texture.height=256
		texture.fill_to=Vector2(0,1)
	var image := TextureRect.new()
	image.texture=texture
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.position=at
	image.size=dimensions
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

func portrait(parent: Node, hero: int, at: Vector2, height: float, camp: bool = false) -> Sprite2D:
	var art := Sprite2D.new()
	var solo_path := "res://assets/portrait-%d.png" % hero
	if camp and ResourceLoader.exists(solo_path):
		art.texture=load(solo_path)
		art.position=at
		art.scale=Vector2.ONE*(height*1.04/art.texture.get_height())
		parent.add_child(art)
		return art
	var atlas := AtlasTexture.new()
	var path := "res://assets/camp-sentinels.png" if camp and ResourceLoader.exists("res://assets/camp-sentinels.png") else "res://assets/sentinels.png"
	atlas.atlas=load(path)
	var dims := atlas.atlas.get_size()
	atlas.region=Rect2(hero*dims.x/3,0,dims.x/3,dims.y)
	art.texture=atlas
	art.position=at
	art.scale=Vector2.ONE*(height/dims.y)
	parent.add_child(art)
	return art

func item_icon(parent: Node, kind: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture=load("res://assets/icons/"+kind+".svg")
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position=at
	icon.size=dimensions
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func line_edit(parent: Node, value: String, at: Vector2, size: Vector2, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text=value
	edit.placeholder_text=placeholder
	edit.position=at
	edit.size=size
	edit.max_length=64
	parent.add_child(edit)
	return edit

func background(dim: float = 0.0) -> void:
	var art := TextureRect.new()
	art.texture=load("res://assets/keyart.png")
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size=Vector2(1440,900)
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	page.add_child(art)
	if dim>0:
		rect(page,Vector2.ZERO,Vector2(1440,900),Color(0.02,0.03,0.06,dim))

func new_page(name_value: String) -> void:
	if ultimate and ultimate.active:
		ultimate.stop()
	clear(page)
	clear(overlay)
	modal=false
	inventory_open=false
	page_name=name_value
	sound.set_scene(name_value)
	toast_time=0
	field.visible=name_value=="game"
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func show_title() -> void:
	new_page("title")
	background()
	fade(page,Vector2.ZERO,Vector2(850,900),Color(0.025,0.018,0.035,0.64))
	ornament(page,Vector2.ZERO,Vector2(1440,900),"title")
	ornament(page,Vector2(242,59),Vector2(170,170),"seal",Color("c76f78"))
	label(page,"血潮守望",Vector2(74,124),91,Color("f7e8df"),Vector2(560,140))
	label(page,"C  R  I  M  S  O  N     T  I  D  E",Vector2(90,260),20,Color("ddc9c2"),Vector2(540,42))
	ornament(page,Vector2(89,312),Vector2(480,14))
	var motto := label(page,"当血月升起\n我们依然守望人类的明天",Vector2(92,340),22,Color("c8b6b5"),Vector2(505,90))
	motto.add_theme_font_override("font",title_font)
	motto.add_theme_constant_override("line_spacing",12)
	ornament(page,Vector2(74,498),Vector2(40,287),"rail",Color("9b5c65"))
	var entries := ["开始游戏","创建 / 加入房间","设置","制作组","退出游戏"]
	var actions: Array[Callable]=[func(): session.solo(config()),show_network,show_settings,show_credits,func(): get_tree().quit()]
	for i in entries.size():
		var b := button(page,entries[i],Vector2(74,493+i*57),Vector2(445,57),actions[i]) as GothicButton
		b.menu=true
		b.selected=i==0
		b.heat=1 if i==0 else 0
		b.add_theme_font_size_override("font_size",32 if i==0 else 29)
		b.focus_mode=Control.FOCUS_ALL
		b.mouse_entered.connect(func(): select_title_entry(b))
		b.focus_entered.connect(func(): select_title_entry(b))
	button(page,"守夜手册",Vector2(1200,817),Vector2(155,45),show_help)
	label(page,"晨钟城档案   Lv.%02d    /    远征 %d" % [profile.level(),profile.data.runs],Vector2(95,822),13,Color("a599a0"))
	label(page,"© CRIMSON TIDE   ·   共赴黎明",Vector2(95,867),11,Color("7d717b"))

func select_title_entry(target: GothicButton) -> void:
	for node in page.get_children():
		if node is GothicButton and node.menu:
			node.selected=node==target

func config() -> Dictionary:
	return {"name":profile.data.name,"hero":profile.data.hero,"gear":profile.data.gear,"talents":profile.data.talents.duplicate(),"meds":1+extra_meds,"ready":ready_local or session.authority()}

func show_network() -> void:
	new_page("network")
	background(0.72)
	header("守夜人集结","COOPERATIVE EXPEDITION   /   ENET · UDP 24872")
	fade(page,Vector2(80,225),Vector2(590,485),Color(0.03,0.02,0.04,0.8))
	fade(page,Vector2(705,225),Vector2(655,485),Color(0.03,0.02,0.04,0.8))
	ornament(page,Vector2(658,245),Vector2(25,420),"rail")
	ornament(page,Vector2(95,637),Vector2(1230,15))
	label(page,"01  /  建立通讯",Vector2(111,251),26)
	label(page,"你的代号",Vector2(113,317),15,MUTED)
	nickname=line_edit(page,profile.data.name,Vector2(113,357),Vector2(520,55),"输入代号")
	nickname.max_length=16
	label(page,"成为房主，在营地等待最多 3 名好友。",Vector2(113,445),18,MUTED)
	button(page,"创建房间",Vector2(113,531),Vector2(520,60),func():
		remember_name()
		var err := session.host(config())
		if err!=OK: notify("创建失败：UDP 24872 可能已被占用。")
	,true)
	label(page,"02  /  接入信标",Vector2(741,251),26)
	label(page,"房主的 IP 地址",Vector2(742,317),15,MUTED)
	address=line_edit(page,"127.0.0.1",Vector2(742,357),Vector2(580,55),"例如 192.168.1.20")
	label(page,"同一局域网，或使用虚拟局域网连接。",Vector2(742,436),18,MUTED)
	label(page,"公网直连需要房主映射 UDP 24872。",Vector2(742,470),16,MUTED)
	button(page,"加入房间",Vector2(742,531),Vector2(580,60),func():
		remember_name()
		var host_address := address.text.strip_edges().trim_suffix(":24872")
		var err := session.join(host_address,config())
		notify("正在连接房主…" if err==OK else "地址无效或网络不可用。")
	,true)
	label(page,"房主负责战斗与掉落结算。进入废墟后锁定房间；下一局可重新加入。",Vector2(85,755),17,MUTED)
	button(page,"← 返回",Vector2(80,811),Vector2(180,48),func(): session.disconnect_room(); show_title())

func remember_name() -> void:
	profile.data.name=nickname.text.strip_edges() if not nickname.text.strip_edges().is_empty() else "守夜人"
	profile.save_profile()

func header(title: String, subtitle: String) -> void:
	label(page,"血潮守望  /  CRIMSON TIDE",Vector2(80,35),13,GOLD)
	label(page,title,Vector2(78,89),43)
	label(page,subtitle,Vector2(82,161),13,MUTED)
	ornament(page,Vector2(80,203),Vector2(1280,12))

func on_lobby() -> void:
	if session.players.is_empty():
		if page_name in ["camp","game","results"]:
			show_title()
		return
	if not session.running:
		if page_name=="results":
			extra_meds=0
			ready_local=false
		show_camp()

func show_camp() -> void:
	new_page("camp")
	background(0.74)
	fade(page,Vector2(480,0),Vector2(960,900),Color(0.025,0.02,0.037,0.97),true)
	fade(page,Vector2.ZERO,Vector2(470,900),Color(0.025,0.02,0.037,0.6))
	ornament(page,Vector2.ZERO,Vector2(1440,900),"title")
	label(page,"晨钟城",Vector2(66,37),37,INK,Vector2(280,60))
	label(page,"T H E   L A S T   S A N C T U A R Y",Vector2(70,106),11,GOLD)
	label(page,"整 备  /  守 夜 人 档 案",Vector2(581,64),16,GOLD)
	label(page,"Lv.%02d    ◈ %d" % [profile.level(),profile.data.coins],Vector2(1110,56),22,GOLD,Vector2(265,42))
	ornament(page,Vector2(571,121),Vector2(790,14))
	var hero: Dictionary=Catalog.HEROES[profile.data.hero]
	ornament(page,Vector2(30,216),Vector2(505,505),"seal",hero.color)
	var character := portrait(page,profile.data.hero,Vector2(294,435),625,true)
	var breath := character.create_tween().set_loops()
	breath.tween_property(character,"position:y",430.0,2.4).set_trans(Tween.TRANS_SINE)
	breath.tween_property(character,"position:y",435.0,2.4).set_trans(Tween.TRANS_SINE)
	fade(page,Vector2(46,575),Vector2(500,170),Color(0.035,0.019,0.04,0.94),true,true)
	label(page,hero.name,Vector2(72,605),52,INK,Vector2(180,80))
	label(page,hero.title,Vector2(226,642),19,hero.color)
	label(page,hero.desc,Vector2(74,691),15,Color("c1b5bb"),Vector2(453,50)).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for i in 3:
		var h: Dictionary=Catalog.HEROES[i]
		var b := button(page,h.name,Vector2(66+i*160,750),Vector2(147,50),func():
			profile.data.hero=i
			ready_local=false
			profile.save_profile()
			session.configure(config())
		) as GothicButton
		b.selected=profile.data.hero==i
		b.accent=h.color
		b.add_theme_font_size_override("font_size",22)
	label(page,"出战装备",Vector2(583,160),27,INK,Vector2(250,45))
	label(page,"LOADOUT",Vector2(583,207),10,GOLD)
	for i in 3:
		var gear: Dictionary=Catalog.GEAR[i]
		var x := 582+i*126
		var b := button(page,"",Vector2(x,247),Vector2(113,104),func():
			profile.data.gear=i
			profile.save_profile()
			ready_local=false
			session.configure(config())
		) as GothicButton
		b.selected=profile.data.gear==i
		var icon: String = ["armor","rifle","boots"][i]
		item_icon(page,icon,Vector2(x+31,251),Vector2(52,52))
		label(page,gear.name,Vector2(x,310),15,INK if profile.data.gear==i else MUTED,Vector2(113,31)).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label(page,Catalog.GEAR[profile.data.gear].desc,Vector2(584,356),15,GOLD)
	ornament(page,Vector2(578,406),Vector2(384,12))
	label(page,"灵契天赋",Vector2(583,431),27,INK,Vector2(250,45))
	for i in 3:
		var level: int=profile.data.talents[i]
		var y := 495+i*78
		item_icon(page,["heart","rifle","boots"][i],Vector2(585,y+5),Vector2(34,34))
		label(page,Catalog.TALENTS[i],Vector2(636,y-4),18,INK,Vector2(180,34))
		label(page,["生命 +12 / 级","伤害 +8% / 级","移速 +9 / 级"][i],Vector2(636,y+29),12,MUTED)
		for rank in 5:
			var pip := ornament(page,Vector2(785+rank*13,y+11),Vector2(11,8),"line",GOLD if rank<level else Color("4c3d46"))
			pip.modulate.a=1.0 if rank<level else 0.7
		var upgrade := button(page,"满阶" if level>=5 else "+ %d" % (80+level*65),Vector2(858,y-3),Vector2(108,48),func():
			if profile.upgrade(i):
				ready_local=false
				session.configure(config())
			else: notify("银币不足，带回战利品即可升级。")
		)
		upgrade.disabled=level>=5
	ornament(page,Vector2(1001,150),Vector2(25,585),"rail",Color("66505a"))
	label(page,"远征小队",Vector2(1058,160),27,INK,Vector2(270,45))
	label(page,"WATCHERS  /  %02d" % session.players.size(),Vector2(1061,209),11,GOLD)
	var row := 0
	for p in session.players.values():
		var y := 259+row*69
		portrait(page,p.hero,Vector2(1080,y+22),61)
		label(page,p.name,Vector2(1115,y-3),18,INK,Vector2(148,32))
		label(page,("房主" if p.id==1 else "队友")+" · "+Catalog.HEROES[p.hero].name,Vector2(1115,y+26),12,MUTED)
		label(page,"就绪" if p.ready else "整备",Vector2(1300,y+7),13,Color("98bcae") if p.ready else GOLD,Vector2(60,30))
		row+=1
	for i in range(row,4):
		label(page,"◇",Vector2(1066,260+i*69),22,Color("68505d"),Vector2(36,40))
		label(page,"等待守夜人" if session.online else "空席",Vector2(1116,263+i*69),15,Color("746671"))
	if session.online:
		button(page,"邀请好友 · 复制地址",Vector2(1050,555),Vector2(310,42),copy_invite)
	else:
		label(page,"单人远征  /  无需联网",Vector2(1061,561),13,MUTED)
	ornament(page,Vector2(1047,611),Vector2(314,10))
	item_icon(page,"medicine",Vector2(1056,648),Vector2(38,45))
	label(page,"急救针  ×%d" % (1+extra_meds),Vector2(1113,645),17,INK,Vector2(180,37))
	label(page,"每局免费补给一支",Vector2(1113,679),12,MUTED)
	var supply := button(page,"+ 25 ◈",Vector2(1256,646),Vector2(112,48),func():
		if extra_meds<2 and profile.data.coins>=25:
			profile.data.coins-=25
			extra_meds+=1
			profile.save_profile()
			session.configure(config())
		else: notify("物资已满或银币不足。")
	)
	supply.disabled=extra_meds>=2
	var mode := button(page,"长局 · 15 分钟" if long_run else "标准局 · 8 分钟",Vector2(1024,735),Vector2(349,43),func(): long_run=not long_run; show_camp())
	mode.disabled=not session.authority()
	ornament(page,Vector2(62,814),Vector2(1314,10))
	button(page,"← 离开营地",Vector2(60,839),Vector2(183,43),leave_to_title)
	button(page,"守夜手册",Vector2(251,839),Vector2(165,43),show_help)
	label(page,"活着带回来的，才属于你。",Vector2(583,849),16,Color("a797a3"))
	if session.authority():
		button(page,"全队出发    →",Vector2(1032,831),Vector2(340,61),func(): session.launch(long_run),true).add_theme_font_size_override("font_size",27)
	else:
		button(page,"取消准备" if session.players.get(session.my_id(),{}).get("ready",false) else "准备出发",Vector2(1032,831),Vector2(340,61),func(): ready_local=not ready_local; session.configure(config()),true)

func copy_invite() -> void:
	var ip := "127.0.0.1"
	for candidate in IP.get_local_addresses():
		if candidate.begins_with("192.168.") or candidate.begins_with("10.") or candidate.begins_with("172."):
			ip=candidate
			break
	DisplayServer.clipboard_set(ip+":24872")
	notify("已复制 "+ip+":24872  ·  发给同一网络的好友")

func on_started() -> void:
	extra_meds=0
	ready_local=false
	new_page("game")
	field.camera=Vector2(300,1100)
	field.explored.clear()
	field.map_open=false
	hud.clear()
	fade(page,Vector2(0,0),Vector2(365,245),Color(0.025,0.018,0.035,0.7))
	label(page,"血潮守望",Vector2(29,17),24).add_theme_font_override("font",title_font)
	hud.time=label(page,"",Vector2(30,54),15,GOLD)
	hud.mission=label(page,"",Vector2(550,18),20,INK)
	label(page,"共 同 目 标  /  点 亮 晨 钟",Vector2(550,53),11,GOLD)
	ornament(page,Vector2(540,83),Vector2(300,10))
	hud.seed=label(page,"遗迹 #"+str(session.seed_value),Vector2(1175,26),14,MUTED)
	hud.team=label(page,"",Vector2(31,125),15,INK,Vector2(320,180))
	hud.team.add_theme_constant_override("line_spacing",10)
	button(page,"背包  TAB",Vector2(1175,310),Vector2(234,39),toggle_bag)
	button(page,"地图  M",Vector2(1175,360),Vector2(111,38),toggle_map)
	button(page,"菜单",Vector2(1298,360),Vector2(111,38),pause_menu)
	hud.notice=label(page,"",Vector2(375,664),22,GOLD,Vector2(690,50))
	hud.notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hud.prompt=label(page,"",Vector2(335,716),18,INK,Vector2(770,48))
	hud.prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	fade(page,Vector2(15,776),Vector2(555,112),Color(0.03,0.018,0.033,0.94))
	ornament(page,Vector2(20,775),Vector2(475,110),"frame")
	portrait(page,session.players[session.my_id()].hero,Vector2(80,824),102)
	hud.health=label(page,"",Vector2(132,794),17,Color("efc3c4"),Vector2(230,32))
	hud.sanity=label(page,"",Vector2(132,841),13,Color("b5b8d4"),Vector2(280,30))
	rect(page,Vector2(134,832),Vector2(220,5),Color("3c2333"))
	hud.hpbar=rect(page,Vector2(134,832),Vector2(220,5),RED)
	item_icon(page,"rifle",Vector2(404,791),Vector2(39,39))
	hud.ammo=label(page,"",Vector2(454,791),18,INK,Vector2(267,35))
	hud.scent=label(page,"",Vector2(412,842),13,GOLD,Vector2(260,33))
	ornament(page,Vector2(722,785),Vector2(48,85),"seal",Color("b8a0c8"))
	item_icon(page,"skill",Vector2(728,801),Vector2(40,40))
	hud.skill=label(page,"",Vector2(792,793),17,Color("d4c0de"),Vector2(283,33))
	hud.items=label(page,"",Vector2(792,842),13,MUTED,Vector2(315,30))
	label(page,"WASD 走路 · SHIFT 奔跑",Vector2(1170,786),12,MUTED,Vector2(241,28))
	label(page,"SPACE 闪避 · 鼠标攻击",Vector2(1170,812),12,MUTED,Vector2(241,28))
	label(page,"1 单剑  2 重剑  3 法杖  4 枪",Vector2(1170,837),12,MUTED,Vector2(241,28))
	notify("已抵达灰烬废墟。点亮封印，带回战利品。")

func _process(dt: float) -> void:
	toast_time-=dt
	toast.visible=toast_time>0
	if page_name!="game" or not session.running:
		return
	sound.update_world(field.camera,session.players,dt)
	var blocked := inventory_open or modal or field.map_open
	session.local_input={"move":Vector2.ZERO if blocked else Input.get_vector("left","right","up","down"),"aim":field.aim(),"fire":not blocked and Input.is_action_pressed("fire") and not mouse_over_button(),"interact":not blocked and Input.is_action_pressed("interact"),"sprint":not blocked and Input.is_action_pressed("sprint")}
	time_ui+=dt
	if time_ui>0.1:
		time_ui=0
		update_hud()
		if inventory_open:
			var p: Dictionary=session.players.get(session.my_id(),{})
			var signature := str(p.get("bag",[]))
			if signature!=bag_signature:
				show_inventory()

func mouse_over_button() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered is Button

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if modal:
			close_modal()
		elif inventory_open:
			close_bag()
		elif page_name=="game":
			pause_menu()
		return
	if page_name!="game" or modal:
		return
	if event.is_action_pressed("bag"):
		toggle_bag()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map") and not inventory_open:
		toggle_map()
	if inventory_open:
		for action in ["heal","burn"]:
			if event.is_action_pressed(action):
				session.action(action)
				show_inventory()
		if event.is_action_pressed("reload") and selected>=0:
			rotated=not rotated
			var bag: Array=session.players[session.my_id()].bag
			var item: Dictionary=bag[selected]
			session.action("bag_move",{"index":selected,"x":item.x,"y":item.y,"rot":rotated})
			show_inventory()
		return
	if field.map_open:
		return
	for weapon in 4:
		if event.is_action_pressed("weapon_"+str(weapon)) and not event.is_echo():
			session.action("weapon",{"index":weapon})
	for action in ["reload","skill","dash","heal","burn"]:
		if event.is_action_pressed(action) and not event.is_echo():
			session.action(action)

func update_hud() -> void:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty() or hud.is_empty():
		return
	var remaining := maxi(0,int(session.duration-session.elapsed))
	hud.time.text="%02d:%02d  /  %s" % [remaining/60,remaining%60,"毒雾正在收缩" if session.threat>0.45 else "血月初升"]
	hud.mission.text="晨钟封印    %d / 3" % session.objectives
	hud.health.text="生命   %d / %d" % [maxf(0,p.hp),p.max_hp]
	hud.hpbar.size.x=220*clampf(p.hp/p.max_hp,0,1)
	hud.sanity.text="理智  %d%%    ·    血香  %d" % [p.sanity,p.scent]
	hud.ammo.text=Catalog.WEAPONS[p.weapon].name+(" · 装填中" if p.reload>0 else (" %02d/%d" % [p.ammo,p.reserve] if p.weapon==0 else " · 三连击" if p.weapon==1 else ""))
	hud.scent.text="战利品  %d ◈   /   击杀 %d" % [Catalog.bag_value(p.bag),p.kills]
	hud.skill.text="[Q] "+Catalog.HEROES[p.hero].skill+("  %.0fs" % ceil(p.skill) if p.skill>0 else "  就绪")
	hud.items.text="[F] 急救针 ×%d    [B] 血晶 ×%d" % [Catalog.count(p.bag,"medicine"),Catalog.count(p.bag,"crystal")]
	var team := "远征小队\n"
	for ally in session.players.values():
		var status: String={"active":"%d HP" % ally.hp,"down":"倒地 · %.0fs" % ally.bleed,"dead":"阵亡","extracted":"已撤离"}[ally.status]
		team+="%s  /  %s\n" % [ally.name,status]
	hud.team.text=team
	hud.notice.text=""
	hud.prompt.text=""
	if p.status=="down":
		hud.notice.text="你已倒地 · 等待队友救援"
		hud.prompt.text="[F] 消耗急救针自救（每局一次）" if p.self_revive and Catalog.count(p.bag,"medicine")>0 else "倒计时结束后阵亡；队友靠近并长按 E 可救起你。"
		return
	if p.status in ["extracted","dead"]:
		hud.notice.text="撤离成功 · 战利品已保全" if p.status=="extracted" else "守夜终结 · 本局背包遗失"
		hud.prompt.text="正在观战队友；所有人撤离或阵亡后统一结算。"
		return
	if p.p.distance_to(Ruins.CENTER)>session.safe_radius():
		hud.notice.text="你正处于毒雾中！向地图中央移动"
	elif p.scent>32:
		hud.notice.text="血香浓烈 · 猎手将至   [B] 燃烧血晶"
	elif p.sanity<25:
		hud.notice.text="理智濒临崩坏 · 燃晶、治疗或尽快撤离"
	for ally in session.players.values():
		if ally.id!=p.id and ally.status=="down" and p.p.distance_to(ally.p)<75:
			hud.prompt.text="长按 [E] 3 秒救援 "+ally.name
			return
	for exit_pos in session.ruins.exits:
		if p.p.distance_to(exit_pos)<83:
			hud.prompt.text="长按 [E] 4 秒独立撤离 · 受伤会打断"
			return
	for shrine in session.ruins.shrines:
		if not shrine.done and p.p.distance_to(shrine.p)<72:
			hud.prompt.text="长按 [E] 3 秒点亮封印 · 引来精英 · 全队 +55 ◈"
			return
	for drop in session.drops:
		if p.p.distance_to(drop.p)<65:
			hud.prompt.text="[E] 拾取 "+Catalog.ITEMS[drop.kind].name+"   /   [TAB] 整理背包"
			return
	for chest in session.ruins.chests:
		if not chest.items.is_empty() and p.p.distance_to(chest.p)<70:
			hud.prompt.text="长按 [E] 搜刮物资箱 · 剩余 %d 件   /   空间不足时 [TAB] 整理" % chest.items.size()
			return

func toggle_bag() -> void:
	if modal:
		return
	if inventory_open:
		close_bag()
	else:
		sound.play("ui-open")
		inventory_open=true
		selected=-1
		rotated=false
		show_inventory()

func close_bag() -> void:
	if inventory_open:
		sound.play("ui-close")
	inventory_open=false
	clear(overlay)

func toggle_map() -> void:
	field.map_open=not field.map_open
	sound.play("ui-open" if field.map_open else "ui-close")

func show_inventory() -> void:
	clear(overlay)
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	bag_signature=str(p.bag)
	if selected>=p.bag.size():
		selected=-1
	var blocker := rect(overlay,Vector2.ZERO,Vector2(1440,900),Color(0.015,0.02,0.04,0.65))
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	rect(overlay,Vector2(351,170),Vector2(738,561),BG,Color("6e4d5d"))
	ornament(overlay,Vector2(351,170),Vector2(738,561),"frame")
	label(overlay,"随身背包",Vector2(388,190),30)
	label(overlay,"6 × 4   /   撤离后折算 %d ◈" % Catalog.bag_value(p.bag),Vector2(389,241),15,GOLD)
	button(overlay,"关闭 TAB",Vector2(921,191),Vector2(133,42),close_bag)
	for y in 4:
		for x in 6:
			var at := Vector2(388+x*66,304+y*66)
			var cell := button(overlay,"",at,Vector2(61,61),func(): move_item(x,y)) as GothicButton
			cell.slot=true
	for i in p.bag.size():
		var item: Dictionary=p.bag[i]
		var info: Dictionary=Catalog.ITEMS[item.kind]
		var dims := Catalog.item_size(item)
		var b := button(overlay,info.name,Vector2(388+item.x*66,304+item.y*66),Vector2(dims.x*66-5,dims.y*66-5),func():
			selected=i
			rotated=item.rot
			show_inventory()
		)
		b.add_theme_font_size_override("font_size",12)
		b.slot=true
		b.item_kind=item.kind
		b.accent=info.color
		b.selected=selected==i
		b.tooltip_text=info.name+"\n"+info.desc+"\n价值："+str(info.value)
		b.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
				session.action("drop",{"index":i})
				selected=-1
		)
	label(overlay,"战利品档案",Vector2(817,297),18,GOLD)
	ornament(overlay,Vector2(800,278),Vector2(247,10))
	if selected>=0:
		var info: Dictionary=Catalog.ITEMS[p.bag[selected].kind]
		item_icon(overlay,p.bag[selected].kind,Vector2(882,328),Vector2(75,75))
		label(overlay,info.name,Vector2(817,411),23,info.color)
		var text := label(overlay,info.desc,Vector2(817,460),14,MUTED,Vector2(222,65))
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(overlay,"朝向："+("已旋转" if rotated else "默认"),Vector2(817,522),15,GOLD)
		button(overlay,"丢弃到地面",Vector2(817,570),Vector2(232,46),func(): session.action("drop",{"index":selected}); selected=-1)
	else:
		ornament(overlay,Vector2(839,346),Vector2(180,180),"seal")
		label(overlay,"选择一件战利品",Vector2(852,527),15,MUTED)
	label(overlay,"选择物品 → [R] 旋转 → 点击空格放置；右键丢弃。",Vector2(388,595),14,MUTED)
	label(overlay,"[F] 使用急救针   ·   [B] 燃烧血晶",Vector2(388,631),15,INK)
	label(overlay,"背包打开时战斗继续，请先找到安全的位置。",Vector2(388,680),14,Color("b8838f"))

func move_item(x: int,y: int) -> void:
	if selected<0:
		return
	session.action("bag_move",{"index":selected,"x":x,"y":y,"rot":rotated})
	selected=-1
	show_inventory()

func on_finished() -> void:
	ultimate.stop()
	var reward: Dictionary=session.results.get(session.my_id(),{})
	if not session.report_paid and not reward.is_empty():
		profile.data.coins+=reward.coins
		profile.data.xp+=reward.xp
		profile.data.runs+=1
		if reward.escaped:
			profile.data.extracts+=1
		profile.data.best=maxi(profile.data.best,reward.coins)
		profile.save_profile()
		session.report_paid=true
	new_page("results")
	background(0.85)
	header("黎明的回响" if reward.get("escaped",false) else "长夜未尽","EXPEDITION REPORT   /   个人战利品与全队目标已结算")
	label(page,"%d / 3  晨钟封印" % session.objectives,Vector2(83,235),25,GOLD)
	label(page,"遗迹 #%d   ·   探索 %02d:%02d" % [session.seed_value,int(session.elapsed)/60,int(session.elapsed)%60],Vector2(860,235),17,MUTED)
	var i := 0
	for id in session.results:
		var r: Dictionary=session.results[id]
		var y := 305+i*99
		fade(page,Vector2(80,y),Vector2(1280,83),Color(0.13,0.06,0.10,0.7))
		ornament(page,Vector2(80,y+81),Vector2(1280,8))
		portrait(page,session.players[id].hero,Vector2(122,y+40),72)
		label(page,r.name,Vector2(162,y+18),24)
		label(page,"成功撤离" if r.escaped else "阵亡 / 失联",Vector2(370,y+21),18,Color("85c8b1") if r.escaped else Color("d38193"))
		label(page,"战利品 %d   +   共享 %d" % [r.loot,r.shared],Vector2(585,y+21),18,MUTED)
		label(page,"%d ◈     +%d XP" % [r.coins,r.xp],Vector2(1020,y+21),22,GOLD)
		i+=1
	label(page,"当前等级  Lv.%02d     ·     城邦银币  %d     ·     历史最佳  %d" % [profile.level(),profile.data.coins,profile.data.best],Vector2(83,741),19,MUTED)
	button(page,"返回标题",Vector2(80,804),Vector2(205,57),leave_to_title)
	if session.authority():
		button(page,"返回营地 · 继续守夜  →",Vector2(978,797),Vector2(382,66),func(): session.return_to_camp(),true)
	else:
		label(page,"等待房主带领小队返回营地…",Vector2(987,814),18,GOLD)

func on_effect(kind: String,pos: Vector2) -> void:
	# These legacy events still drive VFX. Their sound is emitted once via combat events.
	if kind in ["shot","skill","hurt"]:
		return
	if page_name=="game":
		sound.listener.global_position=field.camera
		sound.play("death" if kind=="hit" else kind,-1,pos)

func on_combat_audio(data: Dictionary) -> void:
	if page_name!="game":
		return
	sound.listener.global_position=field.camera
	var emitter := int(data.get("id",0))
	var speaker: Dictionary=session.players.get(emitter,{})
	var voice_hero := int(speaker.get("hero",0))
	sound.dialogue.local_id=session.my_id()
	match str(data.kind):
		"strike":
			sound.attack(int(data.weapon),int(data.get("combo",0)),data.p,emitter)
			sound.dialogue.play_line(voice_hero,"attack",emitter,data.p,field.camera)
		"windup":
			if int(data.weapon)==3:
				sound.play("magic-windup",-1,data.p,0.0,emitter)
		"impact":
			var weapon := int(data.get("weapon",-1))
			var cue := "impact-magic" if weapon==3 else "impact-heavy" if data.get("heavy",false) else "hit"
			sound.play(cue,-1,data.p)
			if int(data.get("enemy_type",0)) in [2,3] and weapon in [0,1,2]:
				sound.play("impact-metal",-1,data.p,-4.0)
		"audio":
			if str(data.cue) in ["equip","down"]:
				sound.stop_cue("reload",emitter)
				sound.stop_cue("magic-windup",emitter)
			sound.play(str(data.cue),int(data.get("variant",-1)),data.p,0.0,emitter)
			if str(data.cue) in ["heal","hurt","down"]:
				sound.dialogue.play_line(voice_hero,str(data.cue),emitter,data.p,field.camera)
		"dodge":
			sound.stop_cue("magic-windup",emitter)
			sound.dialogue.play_line(voice_hero,"dash",emitter,data.p,field.camera)
		"skill":
			if emitter!=session.my_id():
				sound.play("skill",int(data.hero),data.p,0.0,emitter)
				sound.dialogue.play_line(int(data.hero),"ultimate-short",emitter,data.p,field.camera)

func notify(text: String) -> void:
	toast.text=text
	toast_time=5.0
	toast.visible=true

func modal_box(title: String, size: Vector2 = Vector2(800,580)) -> Vector2:
	clear(overlay)
	modal=true
	var at := (Vector2(1440,900)-size)/2
	var shade := rect(overlay,Vector2.ZERO,Vector2(1440,900),Color(0.015,0.02,0.04,0.85))
	shade.mouse_filter=Control.MOUSE_FILTER_STOP
	rect(overlay,at,size,BG,Color("6b495c"))
	ornament(overlay,at,size,"frame")
	label(overlay,title,at+Vector2(33,21),29)
	button(overlay,"关闭",at+Vector2(size.x-135,23),Vector2(103,43),close_modal)
	return at

func close_modal() -> void:
	clear(overlay)
	modal=false
	if inventory_open:
		show_inventory()

func pause_menu() -> void:
	var at := modal_box("守夜通讯",Vector2(630,460))
	label(overlay,"本局时间继续流逝，请先移动到安全处。",at+Vector2(35,100),18,MUTED)
	button(overlay,"继续探索",at+Vector2(35,174),Vector2(560,56),close_modal,true)
	button(overlay,"守夜手册",at+Vector2(35,249),Vector2(270,52),show_help)
	button(overlay,"设置",at+Vector2(325,249),Vector2(270,52),show_settings)
	button(overlay,"放弃本局并离开",at+Vector2(35,325),Vector2(560,52),confirm_leave)
	label(overlay,"房主离开会结束房间；未结算的战利品将丢失。",at+Vector2(35,394),14,Color("c38b98"))

func confirm_leave() -> void:
	var at := modal_box("确认放弃远征？",Vector2(650,320))
	label(overlay,"尚未结算的战利品会遗失；房主离开将关闭房间。",at+Vector2(32,105),17,MUTED)
	button(overlay,"继续守夜",at+Vector2(32,206),Vector2(275,55),close_modal,true)
	button(overlay,"确认离开",at+Vector2(331,206),Vector2(285,55),leave_to_title)

func leave_to_title() -> void:
	session.disconnect_room()
	extra_meds=0
	ready_local=false
	show_title()

func show_settings() -> void:
	var at := modal_box("设置",Vector2(740,510))
	label(overlay,"主音量",at+Vector2(37,112),20)
	var slider := HSlider.new()
	slider.position=at+Vector2(185,127)
	slider.size=Vector2(480,30)
	slider.min_value=0
	slider.max_value=1
	slider.step=0.01
	slider.value=profile.data.volume
	slider.value_changed.connect(func(value: float): set_volume(value); profile.data.volume=value; profile.save_profile())
	overlay.add_child(slider)
	label(overlay,"角色语音",at+Vector2(37,187),20)
	var voice_slider := HSlider.new()
	voice_slider.position=at+Vector2(185,202)
	voice_slider.size=Vector2(480,30)
	voice_slider.min_value=0
	voice_slider.max_value=1
	voice_slider.step=.01
	voice_slider.value=profile.data.voice_volume
	voice_slider.value_changed.connect(func(value: float): set_voice_volume(value); profile.data.voice_volume=value; profile.save_profile())
	overlay.add_child(voice_slider)
	button(overlay,"切换全屏 / 窗口",at+Vector2(37,278),Vector2(665,56),func():
		profile.data.fullscreen=not profile.data.fullscreen
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		profile.save_profile()
	)
	label(overlay,"日语角色语音 · 奥义配有中文字幕",at+Vector2(37,368),16,MUTED)
	label(overlay,"成长自动保存；联机使用固定 UDP 24872 端口。",at+Vector2(37,410),15,MUTED)

func set_voice_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Dialogue")
	AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(.001,value)))
	AudioServer.set_bus_mute(bus,value<.005)

func set_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,value)))
	AudioServer.set_bus_mute(0,value<0.005)

func show_help() -> void:
	var at := modal_box("守夜手册",Vector2(1060,720))
	var left := at+Vector2(36,100)
	label(overlay,"01  /  活着带回去",left,23,GOLD)
	label(overlay,"WASD 移动 · 鼠标瞄准与左键攻击\n1 单手剑 · 2 双手剑 · 3 法杖 · 4 步枪\n空格闪避 · Q 技能 · R 装填\nF 急救 / 一次性自救 · B 燃烧血晶\nTAB 网格背包 · M 战术地图 · ESC 菜单",left+Vector2(0,51),18,INK,Vector2(480,190)).add_theme_constant_override("line_spacing",13)
	label(overlay,"02  /  你来决定风险",left+Vector2(0,240),23,GOLD)
	var risk := label(overlay,"靠近物资箱，长按 E 搜刮。背包满时可旋转、移动或丢弃物品。护符自动强化伤害。\n\n血晶越多，血香越浓，越容易引来精英。燃烧血晶可降低血香并恢复理智。",left+Vector2(0,291),18,MUTED,Vector2(462,210))
	risk.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var right := at+Vector2(554,100)
	label(overlay,"03  /  一同出征，独立撤离",right,23,GOLD)
	var coop := label(overlay,"地图上的金色菱形是晨钟封印。长按 E 3 秒激活；每处全队奖励 55 银币，完成三处额外奖励 100。\n\n绿色十字是撤离点。长按 E 4 秒撤离，受伤中断。先撤离的玩家可以观战，队友无需同时离开。",right+Vector2(0,51),18,MUTED,Vector2(463,237))
	coop.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(overlay,"04  /  不要遗忘时间",right+Vector2(0,308),23,GOLD)
	var danger := label(overlay,"后半局毒雾从外围收缩，圈外持续损失生命与理智。到达时限，未撤离者全部阵亡。\n\n倒地后队友可长按 E 救援。全员离场才统一结算：成功撤离保留背包价值，阵亡仍获得共享目标奖励。",right+Vector2(0,356),18,MUTED,Vector2(463,220))
	danger.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func show_credits() -> void:
	var at := modal_box("制作组 / 资源说明",Vector2(830,620))
	label(overlay,"血潮守望 · Crimson Tide",at+Vector2(37,107),29,GOLD)
	label(overlay,"游戏实现  /  Godot 4 · GDScript\n主视觉、立绘与精灵  /  AI 原创插画\n音效  /  Lentikula · Kenney 等 CC0 素材再设计\n日语合成语音  /  MiniMax speech-2.8-hd\n绯月 · 雪璃 · 鸦羽  /  三套独立日语声线\n攻击 · 施法 · 受伤 · 专属奥义咏唱\n原创台词 · 日语语音 · 中文奥义字幕\n完整鸣谢  /  AUDIO-CREDITS.txt · VOICE-CREDITS.txt\n字体  /  Noto Serif & Sans SC · SIL OFL",at+Vector2(37,172),18,MUTED,Vector2(750,340)).add_theme_constant_override("line_spacing",10)
	label(overlay,"献给每一位在长夜中守望黎明的人。",at+Vector2(37,550),18,INK)
