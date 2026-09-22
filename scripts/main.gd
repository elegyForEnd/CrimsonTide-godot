extends Node

# A frame that can be moved and recoloured every frame: used for the ghost plate,
# the landing-cell preview and the "cannot drop here" hatch.
class ObjectRing extends Control:
	var area := Rect2()
	var tone := Color("d8bd8a")
	var blocked := false

	func _init(colour: Color) -> void:
		tone=colour
		mouse_filter=Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(area,Color(tone,0.18 if not blocked else 0.22),true)
		draw_rect(area,tone,false,2.0)
		if blocked:
			var step := 11.0
			var offset := 0.0
			var span := area.size.x+area.size.y
			while offset<span:
				var a := Vector2(maxf(0.0,offset-area.size.y),minf(offset,area.size.y))
				var b := Vector2(minf(offset,area.size.x),maxf(0.0,offset-area.size.x))
				if a!=b:
					draw_line(area.position+a,area.position+b,Color(tone,0.55),1.6)
				offset+=step

func object_ring(colour: Color) -> ObjectRing:
	return ObjectRing.new(colour)

func object_ring_node(parent: Node, colour: Color) -> void:
	var ring := ObjectRing.new(colour)
	ring.name="GhostRing"
	ring.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(ring)

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
var selected_slot := "backpack"
var rotated := false
# The grabbed item is a live overlay node, so it can follow the cursor every
# frame instead of only when the inventory happens to be rebuilt.
var drag_ghost: Control
var drag_ring: Control
var drag_caption: Label
var drag_last_point := Vector2(-1,-1)
var drag: Dictionary = {"active":false,"slot":"backpack","source":-1,"rot":false,"rot_changed":false}
var _loot_index := -1
var bag_cell := 46.0
var bag_gap := 6.0
var pocket_cell := 44.0
var pocket_gap := 6.0
var grids: Dictionary = {}
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
	session.combat_event.connect(func(data: Dictionary):
		if field and data.p.distance_to(field.camera)<950:
			if data.kind=="strike" and data.weapon>0:
				sound.play(["shot","slash","heavy","magic"][data.weapon])
			elif data.kind=="impact":
				sound.play("heavy" if data.get("heavy",false) else "hit")
	)
	get_viewport().size_changed.connect(fit_ui)
	fit_ui()
	var cinema_layer := CanvasLayer.new()
	cinema_layer.layer=100
	add_child(cinema_layer)
	ultimate=UltimateCinematic.new()
	cinema_layer.add_child(ultimate)
	ultimate.burst.connect(func(): sound.play("heavy"); sound.play("magic"))
	session.combat_event.connect(func(data: Dictionary):
		if data.kind=="skill" and int(data.get("id",-1))==session.my_id() and page_name=="game":
			ultimate.play(int(data.hero),session.online)
	)
	set_volume(float(profile.data.volume))
	if profile.data.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	show_title()
	# A deterministic screenshot/smoke path, separate from normal player saves.
	if "--preview-camp" in OS.get_cmdline_user_args():
		session.solo(config())
	if "--preview-game" in OS.get_cmdline_user_args():
		session.solo(config())
		session.launch(false,1729)
	# Fills both containers so the dual-grid panel can be inspected without playing.
	if "--preview-bag" in OS.get_cmdline_user_args():
		session.solo(config())
		session.launch(false,1729)
		var preview: Dictionary=session.players.get(session.my_id(),{})
		if not preview.is_empty():
			var sizes := [9,12,15,16,18]
			var kinds := ["crystal","scrap","medicine","ammo","charm","relic","backpack"]
			for i in 18:
				if Catalog.container_free(preview.backpack)>sizes[i%5]:
					Catalog.add_item(preview.backpack,kinds[i%kinds.size()])
			for i in 6:
				Catalog.add_item(preview.pocket,kinds[i])
			preview.bags=[Catalog.make_bag("white"),Catalog.make_bag("blue"),Catalog.make_bag("gold"),Catalog.make_bag("red")]
			inventory_open=true
			show_inventory()
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
	var keys := {"left":KEY_A,"right":KEY_D,"up":KEY_W,"down":KEY_S,"interact":KEY_E,"loot":KEY_F,"reload":KEY_R,"skill":KEY_Q,"dash":KEY_SPACE,"sprint":KEY_SHIFT,"heal":KEY_F,"burn":KEY_B,"bag":KEY_TAB,"map":KEY_M,"pause":KEY_ESCAPE,"weapon_0":KEY_4,"weapon_1":KEY_1,"weapon_2":KEY_2,"weapon_3":KEY_3}
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
	b.pressed.connect(func(): sound.play("loot"); callback.call())
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
	var payload := profile.storage_payload()
	return {"name":profile.data.name,"hero":profile.data.hero,"gear":profile.data.gear,"talents":profile.data.talents.duplicate(),"meds":1+extra_meds,"ready":ready_local or session.authority(),"pocket":payload.pocket,"bags":payload.bags,"bag_key":payload.bag_key}

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
	button(page,"地图  M",Vector2(1175,360),Vector2(111,38),func(): field.map_open=not field.map_open)
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
	var blocked := inventory_open or modal or field.map_open
	session.local_input={"move":Vector2.ZERO if blocked else Input.get_vector("left","right","up","down"),"aim":field.aim(),"fire":not blocked and Input.is_action_pressed("fire") and not mouse_over_button(),"interact":not blocked and Input.is_action_pressed("interact"),"sprint":not blocked and Input.is_action_pressed("sprint")}
	time_ui+=dt
	if time_ui>0.1:
		time_ui=0
		update_hud()
		keep_loot_window()
		if inventory_open:
			var p: Dictionary=session.players.get(session.my_id(),{})
			var container: Dictionary=session.container_at(_loot_index) if _loot_index>=0 else {}
			if container.is_empty() and _loot_index>=0:
				_loot_index=-1
			var signature := str(p.get("backpack",{}))+str(p.get("pocket",{}))+str(container)
			if signature!=bag_signature:
				show_inventory()
	# The grabbed item follows the cursor on every frame, not only on a rebuild.
	sync_drag()

func mouse_over_button() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered is Button

# Dragging lives on the overlay: item bodies ignore the mouse, so the pointer is
# hit-tested against whichever grid is underneath it.
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not inventory_open or modal or page_name!="game":
		return
	if event.button_index==MOUSE_BUTTON_RIGHT:
		if drag.active:
			drag.rot=not bool(drag.rot)
			drag["rot_changed"]=true
			show_inventory()
		elif selected>=0 and selected_slot!="loot":
			session.action("drop",{"index":selected,"slot":selected_slot})
			selected=-1
			show_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.button_index!=MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var hit := grid_at(get_viewport().get_mouse_position())
		if hit.is_empty():
			return
		var slot := str(hit.slot)
		var index := index_at(slot,Vector2i(hit.cell))
		if index<0:
			return
		var rot := false
		if slot=="loot":
			var shown: Array=session.visible_items(session.container_at(_loot_index))
			if index<shown.size():
				rot=bool(shown[index].get("rot",false))
		else:
			rot=bool(session.players[session.my_id()][slot].items[index].get("rot",false))
		start_drag(slot,index,rot)
		get_viewport().set_input_as_handled()
	elif drag.active:
		release_drag()
		get_viewport().set_input_as_handled()

# Which item covers a cell. Loot cards are one per cell in search order, so the
# index follows the row-major sequence rather than the item's own coordinates.
func index_at(slot: String, cell: Vector2i) -> int:
	if slot=="loot":
		var container: Dictionary=session.container_at(_loot_index)
		if container.is_empty():
			return -1
		var grid: Vector2i=session.container_grid(container)
		var flat := cell.y*grid.x+cell.x
		var shown: Array=session.visible_items(container)
		return flat if flat<shown.size() else -1
	var list: Array=session.players[session.my_id()][slot].items
	for i in list.size():
		var at := Vector2i(int(list[i].x),int(list[i].y))
		var size := Catalog.item_size(list[i])
		if Rect2i(at,size).has_point(cell):
			return i
	return -1

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
		field.map_open=not field.map_open
	if event.is_action_pressed("loot") and not event.is_echo():
		loot_action()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("heal") and not event.is_echo():
		session.action("heal")
		if inventory_open:
			show_inventory()
	if event.is_action_pressed("burn") and not event.is_echo():
		session.action("burn")
		if inventory_open:
			show_inventory()
	if inventory_open:
		if event.is_action_pressed("reload") and selected>=0:
			rotated=not rotated
			if selected_slot=="loot":
				show_inventory()
				return
			var slot: String=selected_slot
			var bag: Array=session.players[session.my_id()][slot].items
			var item: Dictionary=bag[selected]
			session.action("bag_move",{"index":selected,"slot":slot,"x":item.x,"y":item.y,"rot":rotated})
			show_inventory()
		return
	if field.map_open:
		return
	for weapon in 4:
		if event.is_action_pressed("weapon_"+str(weapon)) and not event.is_echo():
			session.action("weapon",{"index":weapon})
	for action in ["reload","skill","dash"]:
		if event.is_action_pressed(action) and not event.is_echo():
			session.action(action)

# F: quick-grab loose ground loot, otherwise open the search window on whatever
# container is in reach. Grabbing never closes the backpack you already have open.
func loot_action() -> void:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty() or p.status not in ["active","down"]:
		return
	if session.pick_up_ground(p):
		if inventory_open:
			show_inventory()
		return
	var index: int=session.search_target(p)
	if index<0:
		return
	session.action("search",{"index":index})
	_loot_index=index
	inventory_open=true
	selected=-1
	show_inventory()

# The search window follows the player: walking out of reach closes it.
func keep_loot_window() -> void:
	if _loot_index<0:
		return
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	var container: Dictionary=session.container_at(_loot_index)
	if container.is_empty() or p.p.distance_to(container.p)>150:
		_loot_index=-1

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
	hud.scent.text="战利品  %d ◈   /   击杀 %d" % [loot_total(p),p.kills]
	hud.skill.text="[Q] "+Catalog.HEROES[p.hero].skill+("  %.0fs" % ceil(p.skill) if p.skill>0 else "  就绪")
	hud.items.text="[F] 急救针 ×%d    [B] 血晶 ×%d    /    %s" % [session.carried(p,"medicine"),session.carried(p,"crystal"),session.backpack_label(p)]
	var team := "远征小队\n"
	for ally in session.players.values():
		var status: String={"active":"%d HP" % ally.hp,"down":"倒地 · %.0fs" % ally.bleed,"dead":"阵亡","extracted":"已撤离"}[ally.status]
		team+="%s  /  %s\n" % [ally.name,status]
	hud.team.text=team
	hud.notice.text=""
	hud.prompt.text=""
	if p.status=="down":
		hud.notice.text="你已倒地 · 等待队友救援"
		hud.prompt.text="[F] 消耗急救针自救（每局一次）" if p.self_revive and session.carried(p,"medicine")>0 else "倒计时结束后阵亡；队友靠近并长按 E 可救起你。"
		return
	if p.status in ["extracted","dead"]:
		hud.notice.text="撤离成功 · 战利品已保全" if p.status=="extracted" else "守夜终结 · 背包已散落，次元口袋仍在"
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
	for i in session.container_count():
		var container: Dictionary=session.container_at(i)
		if container.is_empty() or container.p.distance_to(p.p)>=70:
			continue
		var title: String=session.container_title(container)
		if session.container_searched(container):
			hud.prompt.text="[F] 打开 "+title+"   /   [TAB] 整理背包"
		else:
			hud.prompt.text="[F] 搜索 "+title+"   ·   已搜出 %d / %d" % [session.visible_units(container),session.container_units(container)]
		return

func loot_total(p: Dictionary) -> int:
	return Catalog.container_value(p.backpack)+Catalog.container_value(p.pocket)

func toggle_bag() -> void:
	if modal:
		return
	if inventory_open:
		close_bag()
	else:
		inventory_open=true
		selected=-1
		selected_slot="backpack"
		drag.active=false
		drag["rot_changed"]=false
		show_inventory()

func close_bag() -> void:
	inventory_open=false
	stop_drag()

func stop_drag() -> void:
	drag.active=false
	if drag_ghost and is_instance_valid(drag_ghost):
		drag_ghost.visible=false
	if drag_ring and is_instance_valid(drag_ring):
		drag_ring.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func pick_item(slot: String, index: int) -> void:
	selected=index
	selected_slot=slot
	rotated=bool(session.players[session.my_id()][slot].items[index].get("rot",false))
	show_inventory()

# --- mouse dragging --------------------------------------------------------
# Grabs an item without removing it: the item only moves when the mouse is
# released over a legal slot, exactly like a loot screen in an extraction game.
func start_drag(slot: String, index: int, rot: bool) -> void:
	drag.active=true
	drag.slot=slot
	drag.source=index
	drag.rot=rot
	drag["rot_changed"]=false
	drag_last_point=Vector2(-1,-1)
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	show_inventory()
	var held := held_item()
	if not held.is_empty():
		show_drag_item(held)
	sync_drag()

func release_drag(at: Vector2 = Vector2.INF) -> void:
	if not drag.active:
		return
	var source_slot := str(drag.slot)
	var source_index := int(drag.source)
	var rot: bool=bool(drag.rot_changed)
	stop_drag()
	var slot := ""
	var spot := Vector2i.ZERO
	var point: Vector2=mouse_point() if not at.is_finite() else at
	var hit := grid_at(point)
	if not hit.is_empty():
		slot=str(hit.slot)
		spot=Vector2i(hit.cell)
	var index := source_index
	if source_slot=="loot" and slot.is_empty():
		index=-1	# dropping loot nowhere means leaving it in the container
	if index>=0:
		if slot.is_empty():
			session.action("bag_drop",{"from":source_slot,"to":"world","index":index})
		else:
			session.action("bag_drop",{"from":source_slot,"to":slot,"index":index,"x":spot.x,"y":spot.y,"rot":rot})
	selected=-1
	show_inventory()

# Which inventory grid, if any, sits under a point; loot cards are rectangular,
# everything else is a square grid.
func grid_at(point: Vector2) -> Dictionary:
	for key in grids:
		var entry: Dictionary=grids[key]
		var local: Vector2=point-entry.origin
		if local.x<0 or local.y<0:
			continue
		var step: float=float(entry.cell)+float(entry.gap)
		var col := int(local.x/step)
		var row := int(local.y/step)
		if col<0 or row<0 or col>=int(entry.grid.x) or row>=int(entry.grid.y):
			continue
		return {"slot":key,"cell":Vector2i(col,row)}
	return {}

# While an item is held the screen shows three things: the slot it came from as a
# dashed outline, the cell the item would land in, and a lifted icon that follows
# the cursor. The icon is a live overlay node updated every frame in _process,
# because the inventory itself is only rebuilt when something changes.
func build_drag_nodes() -> void:
	if drag_ghost==null or not is_instance_valid(drag_ghost):
		drag_ghost=Control.new()
		drag_ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
		drag_ghost.visible=false
		overlay.add_child(drag_ghost)
		var plate := Panel.new()
		plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
		plate.size=Vector2(70,70)
		drag_ghost.add_child(plate)
		var icon := TextureRect.new()
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate=Color(1.07,1.05,1.04,0.96)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.size=Vector2(60,60)
		icon.position=Vector2(5,5)
		drag_ghost.add_child(icon)
		drag_caption=label(drag_ghost,"",Vector2(0,74),13,INK,Vector2(220,22))
		drag_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		drag_caption.visible=false
		object_ring_node(drag_ghost,GOLD)
		drag_ghost.get_child(3).visible=false
	if drag_ring==null or not is_instance_valid(drag_ring):
		drag_ring=object_ring(GOLD)
		drag_ring.visible=false
		overlay.add_child(drag_ring)

func show_drag_item(held: Dictionary) -> void:
	build_drag_nodes()
	var kind := str(held.kind)
	var count := int(held.get("count",1))
	var info: Dictionary=Catalog.ITEMS[kind]
	var accent := item_tint(held)
	var icon := drag_ghost.get_child(1) as TextureRect
	var plate := drag_ghost.get_child(0) as Panel
	var stroke := drag_ghost.get_child(3) as ObjectRing
	if icon==null or plate==null:
		return
	icon.texture=load("res://assets/icons/"+kind+".svg")
	plate.add_theme_stylebox_override("panel",style(Color(accent.darkened(0.88),0.62),Color(accent,0.95)))
	if stroke:
		stroke.tone=Color(accent,0.95)
		stroke.queue_redraw()
	drag_caption.text=info.name+(" ×%d" % count if count>1 else "")
	drag_caption.visible=true
	drag_ghost.visible=true
	drag_ring.visible=true

# One frame of drag feedback: move the icon under the cursor and redraw the
# landing cell so the preview always matches what the session would do.
func sync_drag() -> void:
	if not drag.active:
		if drag_ghost: drag_ghost.visible=false
		if drag_ring: drag_ring.visible=false
		return
	var held := held_item()
	if held.is_empty():
		return
	var kind := str(held.kind)
	var accent := item_tint(held)
	var cell_size := held_size(held)
	var point := mouse_point()
	if point.distance_to(drag_last_point)>0.01:
		drag_last_point=point
		move_drag_ghost(point,cell_size)
	drag_ring.size=cell_size
	drag_ring.queue_redraw()
	var hit := grid_at(point)
	var target := drag_target_rect(hit,kind)
	var slot := ""
	var cell := Vector2i.ZERO
	var exact := false
	if not target.is_empty():
		slot=str(target.slot)
		cell=Vector2i(target.cell)
		exact=bool(target.exact)
	if not slot.is_empty():
		var entry: Dictionary=grids[slot]
		var step: float=float(entry.cell)+float(entry.gap)
		var dims := Catalog.item_size({"kind":kind,"rot":bool(drag.rot_changed)})
		if cell.x<0:
			drag_ring.area=Rect2(Vector2(entry.origin)+Vector2(int(target.cursor.x)*step,int(target.cursor.y)*step),Vector2(entry.cell,entry.cell))
			drag_ring.tone=Color("c96a74")
			drag_ring.blocked=true
		else:
			drag_ring.area=Rect2(Vector2(entry.origin)+Vector2(cell.x*step,cell.y*step),Vector2(dims.x*step-float(entry.gap),dims.y*step-float(entry.gap)))
			drag_ring.tone=accent if exact else Color("c9a06a")
			drag_ring.blocked=false
	else:
		drag_ring.area=Rect2(point-cell_size/2,cell_size)
		drag_ring.tone=Color("c96a74")
		drag_ring.blocked=true

func move_drag_ghost(point: Vector2, cell_size: Vector2) -> void:
	var lift := Vector2.ONE*minf(cell_size.x,cell_size.y)*0.10
	var ghost_size := cell_size+lift
	drag_ghost.position=point-ghost_size/2
	drag_ghost.size=ghost_size
	var plate := drag_ghost.get_child(0) as Panel
	if plate:
		plate.size=ghost_size
	var stroke := drag_ghost.get_child(3) as ObjectRing
	if stroke:
		stroke.area=Rect2(Vector2(0,0),ghost_size)
		stroke.queue_redraw()
	var icon := drag_ghost.get_child(1) as TextureRect
	if icon:
		icon.size=ghost_size-Vector2(10,10)
		icon.position=Vector2(5,5)
	drag_caption.position=Vector2(0,ghost_size.y+4)
	reparent_drag_nodes()

# The lifted icon always draws on top of every panel. Panels are rebuilt by
# clearing the overlay, which detaches these nodes, so re-attach defensively.
func reparent_drag_nodes() -> void:
	if drag_ghost==null or not is_instance_valid(drag_ghost):
		return
	var holder: Node=drag_ghost.get_parent()
	if holder!=overlay:
		if holder!=null:
			holder.remove_child(drag_ghost)
		overlay.add_child(drag_ghost)
	if drag_ring==null or not is_instance_valid(drag_ring):
		return
	holder=drag_ring.get_parent()
	if holder!=overlay:
		if holder!=null:
			holder.remove_child(drag_ring)
		overlay.add_child(drag_ring)

# Where the item under the cursor would land, asked of the same resolver the
# session uses. cell is (-1,-1) when the container cannot take the item at all.
func drag_target_rect(hit: Dictionary, kind: String) -> Dictionary:
	if hit.is_empty():
		return {}
	var slot := str(hit.slot)
	var cursor: Vector2i=Vector2i(hit.cell)
	var probe := {"kind":kind,"rot":bool(drag.rot_changed)}
	var landing := Vector2i(-1,-1)
	if slot=="loot":
		var target: Dictionary=session.container_at(_loot_index)
		if not target.is_empty():
			landing=session.resolve_drop(session.peek_items(target),session.container_grid(target),probe,cursor)
	else:
		var p: Dictionary=session.players.get(session.my_id(),{})
		if not p.is_empty() and p.has(slot):
			var dest: Dictionary=p[slot]
			var skip := int(drag.source) if str(drag.slot)==slot else -1
			landing=session.resolve_drop(Catalog.container_items(dest),Catalog.container_grid(dest),probe,cursor,skip)
	return {"slot":slot,"cell":landing,"cursor":cursor,"exact":landing==cursor}

# The cursor in the same space as the panels (the 1440x900 design space).
func mouse_point() -> Vector2:
	var viewport := get_viewport()
	if viewport and root and root.is_inside_tree():
		return root.get_global_transform_with_canvas().affine_inverse()*viewport.get_mouse_position()
	return Vector2.ZERO

# Every cell the held item covers where it currently sits.
func drag_slot_rect() -> Rect2:
	var slot := str(drag.slot)
	var index := int(drag.source)
	if slot=="loot":
		var entry: Dictionary=grids.get("loot",{})
		if entry.is_empty():
			return Rect2()
		var grid: Vector2i=entry.grid
		var col := index%grid.x
		var row := int(index/grid.x)
		return Rect2(Vector2(entry.origin)+Vector2(col*(float(entry.cell)+float(entry.gap)),row*(float(entry.cell)+float(entry.gap))),Vector2(entry.cell,entry.cell))
	var list: Array=session.players[session.my_id()][slot].items
	if index<0 or index>=list.size():
		return Rect2()
	var entry: Dictionary=grids.get(slot,{})
	if entry.is_empty():
		return Rect2()
	var item: Dictionary=list[index]
	var dims := Catalog.item_size(item)
	var cell: float=float(entry.cell)
	var gap: float=float(entry.gap)
	return Rect2(Vector2(entry.origin)+Vector2(int(item.x)*(cell+gap),int(item.y)*(cell+gap)),Vector2(dims.x*(cell+gap)-gap,dims.y*(cell+gap)-gap))

func item_tint(item: Dictionary) -> Color:
	var info: Dictionary=Catalog.ITEMS[str(item.kind)]
	if str(item.kind)=="backpack":
		return Catalog.tier(str(item.get("quality",Catalog.DEFAULT_BAG_KEY))).color
	return info.color

func outline(area: Rect2, color: Color, width: float) -> void:
	rect(overlay,area.position,Vector2(area.size.x,width),color)
	rect(overlay,area.position+Vector2(0,area.size.y-width),Vector2(area.size.x,width),color)
	rect(overlay,area.position,Vector2(width,area.size.y),color)
	rect(overlay,area.position+Vector2(area.size.x-width,0),Vector2(width,area.size.y),color)

func draw_cross(area: Rect2, color: Color) -> void:
	var step := 11.0
	var span := area.size.x+area.size.y
	var offset := 0.0
	while offset<span:
		var a := Vector2(maxf(0.0,offset-area.size.y),minf(offset,area.size.y))
		var b := Vector2(minf(offset,area.size.x),maxf(0.0,offset-area.size.x))
		if a!=b:
			draw_diagonal(area.position+a,area.position+b,color)
		offset+=step

func draw_diagonal(a: Vector2, b: Vector2, color: Color) -> void:
	var strip := Polygon2D.new()
	strip.polygon=PackedVector2Array([a+Vector2(0,1.6),b+Vector2(0,1.6),b-Vector2(0,1.6),a-Vector2(0,1.6)])
	strip.color=color
	strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(strip)

func held_item() -> Dictionary:
	if not drag.active:
		return {}
	var slot := str(drag.slot)
	var index := int(drag.source)
	if slot=="loot":
		var container: Dictionary=session.container_at(_loot_index)
		var visible: Array=session.visible_items(container)
		if index<0 or index>=visible.size():
			return {}
		return visible[index]
	var list: Array=session.players[session.my_id()][slot].items
	if index<0 or index>=list.size():
		return {}
	return list[index]

func held_size(held: Dictionary) -> Vector2:
	if drag.slot=="loot":
		return Vector2(70,70)
	var cell: float=bag_cell if drag.slot=="backpack" else pocket_cell
	var gap: float=bag_gap if drag.slot=="backpack" else pocket_gap
	var size := Catalog.item_size({"kind":held.kind,"rot":bool(drag.rot_changed)})
	return Vector2(size.x*(cell+gap)-gap,size.y*(cell+gap)-gap)

func can_drop_at(slot: String, cell: Vector2i) -> bool:
	var held := held_item()
	if held.is_empty():
		return false
	if slot=="loot":
		if str(drag.slot)=="loot":
			return false
		var target: Dictionary=session.container_at(_loot_index)
		var probe := {"kind":str(held.kind),"rot":bool(drag.rot_changed)}
		return Catalog.can_place(session.peek_items(target),probe,cell,-1,session.container_grid(target))
	if slot=="backpack" or slot=="pocket":
		var p: Dictionary=session.players.get(session.my_id(),{})
		var dest: Dictionary=p[slot]
		var probe := {"kind":str(held.kind),"rot":bool(drag.rot_changed)}
		var skip := int(drag.source) if str(drag.slot)==slot else -1
		if not Catalog.can_place(Catalog.container_items(dest),probe,cell,skip,Catalog.container_grid(dest)):
			return false
		if slot=="pocket" and not is_pocket_item(str(held.kind)):
			return false
		return true
	return false

# Only the relic is deliberately kept in the safe pocket; other loot belongs to
# the backpack, but a player may still park anything there by hand.
func is_pocket_item(kind: String) -> bool:
	return true

# One grid renderer for both containers: the backpack resizes with its quality,
# the dimensional pocket stays 4x4 forever.
func draw_grid(slot: String, at: Vector2, cell: float, gap: float, grid: Vector2i, title: String, subtitle: String, tint: Color) -> void:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	var panel_size := Vector2(grid.x*(cell+gap)-gap+34,grid.y*(cell+gap)-gap+96)
	rect(overlay,at,panel_size,BG,tint)
	ornament(overlay,at,panel_size,"frame",tint)
	label(overlay,title,at+Vector2(20,12),22,INK)
	label(overlay,subtitle,at+Vector2(21,46),13,tint,Vector2(panel_size.x-40,24))
	var origin := at+Vector2(17,78)
	grids[slot]={"origin":origin,"cell":cell,"gap":gap,"grid":grid}
	for y in grid.y:
		for x in grid.x:
			var cell_button := button(overlay,"",origin+Vector2(x*(cell+gap),y*(cell+gap)),Vector2(cell,cell),func(): place_selected(x,y)) as GothicButton
			cell_button.slot=true
			cell_button.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var items: Array=p[slot].items
	for i in items.size():
		var item: Dictionary=items[i]
		var info: Dictionary=Catalog.ITEMS[item.kind]
		var dims := Catalog.item_size(item)
		var accent: Color=info.color
		var caption: String=info.name
		if int(item.get("count",1))>1:
			caption="%s ×%d" % [info.name,int(item.get("count",1))]
		if item.kind=="backpack":
			var key := str(item.get("quality",Catalog.DEFAULT_BAG_KEY))
			accent=Catalog.tier(key).color
			caption=Catalog.tier(key).quality
		if drag.active and str(drag.slot)==slot and i==int(drag.source):
			continue	# the held item follows the cursor instead
		var item_button := button(overlay,caption,origin+Vector2(item.x*(cell+gap),item.y*(cell+gap)),Vector2(dims.x*(cell+gap)-gap-3,dims.y*(cell+gap)-gap-3),func(): pick_item(slot,i))
		item_button.add_theme_font_size_override("font_size",12)
		item_button.slot=true
		item_button.item_kind=item.kind
		item_button.accent=accent
		item_button.selected=selected==i and selected_slot==slot
		item_button.tooltip_text=Catalog.ITEMS[item.kind].name+"\n"+Catalog.ITEMS[item.kind].desc+"\n价值："+str(info.value)
		# The body ignores the mouse so the overlay can hit-test the whole grid and
		# drag items around; caption text is drawn, not clicked.
		item_button.mouse_filter=Control.MOUSE_FILTER_IGNORE

func place_selected(x: int,y: int) -> void:
	if selected<0:
		return
	session.action("bag_move",{"index":selected,"slot":selected_slot,"x":x,"y":y,"rot":rotated})
	selected=-1
	show_inventory()

const LOOT_CELL := 58.0
const LOOT_GAP := 6.0

func show_inventory() -> void:
	clear(overlay)
	grids.clear()
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	var container: Dictionary=session.container_at(_loot_index) if _loot_index>=0 else {}
	if container.is_empty():
		_loot_index=-1
	bag_signature=str(p.backpack)+str(p.pocket)+str(container)
	var bag_grid: Vector2i=Catalog.bag_grid(p.backpack)
	var pocket_grid: Vector2i=Catalog.container_grid(p.pocket)
	var bag_items: Array=p.backpack.items
	if selected_slot=="backpack" and selected>=bag_items.size():
		selected=-1
	if selected_slot=="pocket" and selected>=p.pocket.items.size():
		selected=-1
	var blocker := rect(overlay,Vector2.ZERO,Vector2(1440,900),Color(0.015,0.02,0.04,0.65))
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	var tint: Color=Catalog.bag_color(p.backpack)
	# The right column belongs to the search window whenever one is open, because
	# searching never stops a run and the player still needs both grids.
	var right_x := 980.0
	if _loot_index>=0:
		bag_cell=34.0
		bag_gap=5.0
		pocket_cell=32.0
		pocket_gap=5.0
	else:
		bag_cell=46.0
		bag_gap=6.0
		pocket_cell=44.0
		pocket_gap=6.0
	draw_grid("backpack",Vector2(70,150),bag_cell,bag_gap,bag_grid,"角色背包 · "+Catalog.bag_name(p.backpack),
		"%s品质  %d×%d  /  阵亡时连同物资掉落  /  价值 %d ◈" % [Catalog.bag_quality(p.backpack),bag_grid.x,bag_grid.y,Catalog.container_value(p.backpack)],tint)
	draw_grid("pocket",Vector2(70,600),pocket_cell,pocket_gap,pocket_grid,Catalog.POCKET_NAME,
		"固定 %d×%d  /  永不掉落  /  价值 %d ◈" % [pocket_grid.x,pocket_grid.y,Catalog.container_value(p.pocket)],Color("b9a7d6"))
	button(overlay,"关闭 TAB",Vector2(802,160),Vector2(150,44),close_bag)
	if _loot_index<0:
		draw_details(p,right_x,150.0,390.0,660.0)
	else:
		# The search window sits clear of the HUD buttons and the details panel
		# slides underneath it, so a run in progress stays readable.
		draw_search_window(container,right_x,190.0)
		draw_loot_details(p,right_x,190.0)
	# The held item must stay above every panel, so the live drag nodes are
	# re-attached to the end of the overlay after the panels are rebuilt.
	if drag.active:
		build_drag_nodes()
		reparent_drag_nodes()
		var held := held_item()
		if not held.is_empty():
			show_drag_item(held)
		sync_drag()

# --- item details ----------------------------------------------------------
func draw_details(p: Dictionary, x: float, y: float, wide: float, tall: float) -> void:
	rect(overlay,Vector2(x,y),Vector2(wide,tall),BG,Color("6e4d5d"))
	ornament(overlay,Vector2(x,y),Vector2(wide,tall),"frame")
	label(overlay,"战利品档案",Vector2(x+20,y+15),21,GOLD)
	ornament(overlay,Vector2(x+18,y+50),Vector2(wide-36,10))
	var ix := x+22
	if selected>=0 and selected<p[selected_slot].items.size():
		var item: Dictionary=p[selected_slot].items[selected]
		var info: Dictionary=Catalog.ITEMS[item.kind]
		item_icon(overlay,item.kind,Vector2(ix,y+70),Vector2(62,62))
		label(overlay,info.name,Vector2(ix+74,y+76),23,info.color,Vector2(wide-100,34))
		label(overlay,("角色背包" if selected_slot=="backpack" else Catalog.POCKET_NAME)+" · 第 %d 件" % (selected+1),Vector2(ix+75,y+112),13,MUTED)
		var text := label(overlay,info.desc,Vector2(ix,y+152),14,MUTED,Vector2(wide-44,80))
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(overlay,"朝向："+("已旋转" if rotated else "默认")+"      价值："+str(info.value),Vector2(ix,y+240),15,GOLD)
		if item.kind=="backpack":
			label(overlay,"未装备 · 价值 %d ◈" % info.value,Vector2(ix,y+268),14,Color("b9a7d6"))
			button(overlay,"装备这个背包",Vector2(ix,y+294),Vector2(wide-44,44),func(): equip_pocket_pack(selected))
		else:
			var other: String="pocket" if selected_slot=="backpack" else "backpack"
			var label_text := "存入 "+Catalog.POCKET_NAME if other=="pocket" else "放回角色背包"
			button(overlay,label_text,Vector2(ix,y+294),Vector2(wide-44,44),func(): move_to_other(selected_slot,selected))
		button(overlay,"丢到地面",Vector2(ix,y+346),Vector2(wide-44,44),func():
			session.action("drop",{"index":selected,"slot":selected_slot})
			selected=-1
			show_inventory()
		)
	else:
		ornament(overlay,Vector2(x+wide/2-70,y+70),Vector2(140,140),"seal")
		label(overlay,"点击或拖动一件物品",Vector2(ix,y+230),15,MUTED,Vector2(wide-44,30))
	label(overlay,"拖动：按住物品拖到目标格子松开",Vector2(ix,y+412),13,MUTED,Vector2(wide-44,22))
	label(overlay,"[R] 旋转   ·   拖到框外丢到地面",Vector2(ix,y+434),13,MUTED,Vector2(wide-44,22))
	# --- backpack cabinet ---------------------------------------------------
	label(overlay,"背包柜   /   点击装备",Vector2(ix,y+468),18,GOLD)
	ornament(overlay,Vector2(x+18,y+498),Vector2(wide-36,10))
	label(overlay,"当前："+session.backpack_label(p),Vector2(ix,y+512),13,GOLD,Vector2(wide-44,24))
	var row := 0
	for i in Catalog.BAG_TIERS.size():
		var tier: Dictionary=Catalog.BAG_TIERS[i]
		var ty := y+540+row*26
		if tier.key==str(p.backpack.key):
			label(overlay,"◈ "+tier.quality+" "+tier.name+"  %d×%d  已装备" % [tier.grid.x,tier.grid.y],Vector2(ix,ty),14,tier.color,Vector2(wide-44,24))
		else:
			var spare := spare_index(p,tier.key)
			if spare>=0:
				label(overlay,"· "+tier.quality+" "+tier.name+"  %d×%d" % [tier.grid.x,tier.grid.y],Vector2(ix,ty),14,Color("cfc6bb"),Vector2(wide-140,24))
				button(overlay,"装备",Vector2(x+wide-126,ty-3),Vector2(102,23),func(): equip_spare(spare))
			else:
				label(overlay,"· "+tier.quality+" 未获得  %d×%d" % [tier.grid.x,tier.grid.y],Vector2(ix,ty),14,Color("6a6470"),Vector2(wide-44,24))
		row+=1

# --- the search window -----------------------------------------------------
# Loot surfaces one card at a time; unrevealed slots stay as sealed placeholders.
func draw_search_window(container: Dictionary, x: float, y: float) -> void:
	var grid: Vector2i=session.container_grid(container)
	var units: int=session.container_units(container)
	var revealed: int=session.visible_units(container)
	var wide := grid.x*(LOOT_CELL+LOOT_GAP)-LOOT_GAP+34
	var tall := grid.y*(LOOT_CELL+LOOT_GAP)-LOOT_GAP+128
	rect(overlay,Vector2(x,y),Vector2(wide,tall),BG,Color("4b6076"))
	ornament(overlay,Vector2(x,y),Vector2(wide,tall),"frame",Color("7fa0bd"))
	label(overlay,session.container_title(container),Vector2(x+18,y+12),22,Color("cfe0f0"))
	var state := "搜索完毕 %d 件" % units if revealed>=units else "搜索中…  %d / %d" % [revealed,units]
	label(overlay,state,Vector2(x+19,y+46),13,Color("8fb0cc"),Vector2(wide-44,22))
	label(overlay,"[F] 继续   ·   [TAB] 关闭",Vector2(x+wide-172,y+46),12,MUTED,Vector2(160,22))
	var origin := Vector2(x+17,y+76)
	grids["loot"]={"origin":origin,"cell":LOOT_CELL,"gap":LOOT_GAP,"grid":grid}
	for cy in grid.y:
		for cx in grid.x:
			var cell := button(overlay,"",origin+Vector2(cx*(LOOT_CELL+LOOT_GAP),cy*(LOOT_CELL+LOOT_GAP)),Vector2(LOOT_CELL,LOOT_CELL),func(): pass) as GothicButton
			cell.slot=true
			cell.accent=Color("6d8aa8")
			cell.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shown: Array=session.visible_items(container)
	var sealed := 0
	for i in shown.size():
		var item: Dictionary=shown[i]
		if i>=units:
			break
		var info: Dictionary=Catalog.ITEMS[item.kind]
		var cell_pos := origin+Vector2((i%grid.x)*(LOOT_CELL+LOOT_GAP),int(i/grid.x)*(LOOT_CELL+LOOT_GAP))
		var count := int(item.get("count",1))
		var caption: String=info.name+(" ×%d" % count if count>1 else "")
		if item.kind=="backpack":
			var key := str(item.get("quality",Catalog.DEFAULT_BAG_KEY))
			caption=Catalog.tier(key).quality+"背包"
		var card := button(overlay,caption,cell_pos,Vector2(LOOT_CELL,LOOT_CELL),func(): take_loot_card(i))
		card.add_theme_font_size_override("font_size",12)
		card.slot=true
		card.item_kind=str(item.kind)
		card.accent=Catalog.tier(str(item.get("quality",""))).color if item.kind=="backpack" else info.color
		card.tooltip_text=info.name+"\n"+info.desc+"\n左键拖入背包，或点「拿取」"
		card.mouse_filter=Control.MOUSE_FILTER_IGNORE
		sealed+=1
	for slot_index in range(shown.size(),grid.x*grid.y):
		var hidden := button(overlay,"",origin+Vector2((slot_index%grid.x)*(LOOT_CELL+LOOT_GAP),int(slot_index/grid.x)*(LOOT_CELL+LOOT_GAP)),Vector2(LOOT_CELL,LOOT_CELL),func(): pass) as GothicButton
		hidden.slot=true
		hidden.disabled=true
		hidden.accent=Color("5d7690")
		hidden.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# progress bar
	var bar_w := wide-44.0
	rect(overlay,Vector2(x+22,y+tall-32),Vector2(bar_w,6),Color("26303c"))
	var ratio := 1.0 if units<=0 else clampf(float(revealed)/float(units),0,1)
	rect(overlay,Vector2(x+22,y+tall-32),Vector2(maxf(0,bar_w*ratio),6),Color("7fa0bd"))

func draw_loot_details(p: Dictionary, x: float, y: float) -> void:
	var top := y+404.0
	rect(overlay,Vector2(x,top),Vector2(390,254),BG,Color("4b6076"))
	ornament(overlay,Vector2(x,top),Vector2(390,254),"frame",Color("7fa0bd"))
	label(overlay,"选中物品",Vector2(x+20,top+12),18,GOLD)
	var held := held_item()
	if held.is_empty() and selected_slot=="loot" and selected>=0:
		var shown: Array=session.visible_items(session.container_at(_loot_index))
		if selected<shown.size():
			held=shown[selected]
	if held.is_empty():
		label(overlay,"把鼠标移到搜索框里的物品上，按住左键拖进背包。",Vector2(x+20,top+52),13,MUTED,Vector2(350,44)).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(overlay,"已搜出的物品可以随时拿走；未搜出的格子还锁着。",Vector2(x+20,top+104),13,MUTED,Vector2(350,44)).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		return
	var info: Dictionary=Catalog.ITEMS[str(held.kind)]
	item_icon(overlay,str(held.kind),Vector2(x+20,top+44),Vector2(46,46))
	label(overlay,info.name,Vector2(x+78,top+48),20,info.color,Vector2(220,30))
	var text := label(overlay,info.desc,Vector2(x+20,top+104),13,MUTED,Vector2(350,50))
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(overlay,"价值 %d ◈   ·   右键旋转   ·   拖到框外丢弃" % int(info.value),Vector2(x+20,top+162),13,GOLD)
	label(overlay,"背包 %d/%d ◈      口袋 %d/%d ◈" % [Catalog.container_value(p.backpack),Catalog.container_free(p.backpack),Catalog.container_value(p.pocket),Catalog.container_free(p.pocket)],Vector2(x+20,top+190),13,MUTED)
	label(overlay,"拖动已搜出的物品到左侧网格即可拿走。",Vector2(x+20,top+216),13,Color("9fb6c8"))

func take_loot_card(index: int) -> void:
	session.action("loot_take",{"ref":_loot_index,"index":index})
	call_deferred("show_inventory")

func spare_index(p: Dictionary, key: String) -> int:
	for i in p.bags.size():
		if str(p.bags[i].key)==key:
			return i
	return -1

func equip_spare(index: int) -> void:
	session.action("bag_swap",{"index":index})
	selected=-1
	call_deferred("show_inventory")

# A loose backpack found in the field becomes the equipped one; the backpack it
# replaces stays behind as loot, exactly like the cabinet swap.
func equip_pocket_pack(index: int) -> void:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty() or index<0 or index>=p.pocket.items.size():
		return
	var key := str(p.pocket.items[index].get("quality",Catalog.DEFAULT_BAG_KEY))
	p.bags.append(Catalog.make_bag(key))
	p.bags.back().gw=Catalog.bag_grid(p.bags.back()).x
	p.bags.back().gh=Catalog.bag_grid(p.bags.back()).y
	session.action("bag_swap",{"index":p.bags.size()-1})
	selected=-1
	call_deferred("show_inventory")

func move_to_other(slot: String, index: int) -> void:
	session.action("move_to",{"from":slot,"index":index})
	selected=-1
	call_deferred("show_inventory")

func move_item(x: int,y: int) -> void:
	place_selected(x,y)

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
		# The pocket always comes home; the backpack only if the player escaped.
		if reward.has("pocket"):
			profile.data.pocket=reward.pocket
		if reward.has("bags"):
			profile.data.bags=reward.bags
			profile.data.bag_key=str(reward.bags[0].get("key",Catalog.DEFAULT_BAG_KEY))
		profile.sanitize_storage()
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
		if r.get("bags",[]).size()>0 and r.escaped:
			label(page,"带出 "+Catalog.bag_quality(r.bags[0])+"背包",Vector2(585,y+50),13,Catalog.bag_color(r.bags[0]))
		i+=1
	label(page,"当前等级  Lv.%02d     ·     城邦银币  %d     ·     历史最佳  %d" % [profile.level(),profile.data.coins,profile.data.best],Vector2(83,741),19,MUTED)
	button(page,"返回标题",Vector2(80,804),Vector2(205,57),leave_to_title)
	if session.authority():
		button(page,"返回营地 · 继续守夜  →",Vector2(978,797),Vector2(382,66),func(): session.return_to_camp(),true)
	else:
		label(page,"等待房主带领小队返回营地…",Vector2(987,814),18,GOLD)

func on_effect(kind: String,pos: Vector2) -> void:
	if pos.distance_to(field.camera)<850:
		sound.play(kind)

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
	var at := modal_box("设置",Vector2(740,440))
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
	button(overlay,"切换全屏 / 窗口",at+Vector2(37,208),Vector2(665,56),func():
		profile.data.fullscreen=not profile.data.fullscreen
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		profile.save_profile()
	)
	label(overlay,"存档位置：user://profile.json",at+Vector2(37,298),15,MUTED)
	label(overlay,"成长自动保存；联机使用固定 UDP 24872 端口。",at+Vector2(37,340),15,MUTED)

func set_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,value)))
	AudioServer.set_bus_mute(0,value<0.005)

func show_help() -> void:
	var at := modal_box("守夜手册",Vector2(1060,720))
	var left := at+Vector2(36,100)
	label(overlay,"01  /  活着带回去",left,23,GOLD)
	label(overlay,"WASD 移动 · 鼠标瞄准与左键攻击\n1 单手剑 · 2 双手剑 · 3 法杖 · 4 步枪\n空格闪避 · Q 技能 · R 装填\nF 拾取 / 搜索 / 急救 · B 燃烧血晶 / 自救\nTAB 背包与口袋 · M 战术地图 · ESC 菜单",left+Vector2(0,51),18,INK,Vector2(480,190)).add_theme_constant_override("line_spacing",13)
	label(overlay,"02  /  搜刮要慢慢来",left+Vector2(0,240),23,GOLD)
	var risk := label(overlay,"对着物资箱按 [F] 开始搜索，物品会每隔约 1.2 秒浮出一件，搜索框和背包可以同时开着。\n\n用鼠标把搜出的物品拖进角色背包或次元口袋即可拿走；担心被偷袭就随时按 [TAB] 关掉。深处教堂的箱子是 5×5，普通箱子是 4×4。\n\n地上的掉落物直接按 [F] 秒拾，不需要搜索。背包里的物品也能用鼠标拖动调整位置。",left+Vector2(0,291),17,MUTED,Vector2(462,268))
	risk.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var right := at+Vector2(554,100)
	label(overlay,"03  /  一同出征，独立撤离",right,23,GOLD)
	var coop := label(overlay,"地图上的金色菱形是晨钟封印。长按 E 3 秒激活；每处全队奖励 55 银币，完成三处额外奖励 100。\n\n绿色十字是撤离点。长按 E 4 秒撤离，受伤中断。先撤离的玩家可以观战，队友无需同时离开。",right+Vector2(0,51),18,MUTED,Vector2(463,237))
	coop.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(overlay,"04  /  不要遗忘时间",right+Vector2(0,308),23,GOLD)
	var danger := label(overlay,"后半局毒雾从外围收缩，圈外持续损失生命与理智。到达时限，未撤离者全部阵亡。\n\n倒地后队友可长按 E 救援，但倒地瞬间背包就会散落。全员离场才统一结算：撤离成功保留背包与口袋价值，阵亡只剩次元口袋。",right+Vector2(0,356),18,MUTED,Vector2(463,220))
	danger.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func show_credits() -> void:
	var at := modal_box("制作组 / 资源说明",Vector2(830,500))
	label(overlay,"血潮守望 · Crimson Tide",at+Vector2(37,107),29,GOLD)
	label(overlay,"游戏实现  /  Godot 4 · GDScript\n主视觉、立绘与精灵  /  AI 原创插画\n界面与场景  /  Godot 原生绘制与手绘材质\n音效与氛围  /  原创程序合成\n字体  /  Noto Serif & Sans SC · SIL OFL",at+Vector2(37,178),19,MUTED,Vector2(750,230)).add_theme_constant_override("line_spacing",15)
	label(overlay,"献给每一位在长夜中守望黎明的人。",at+Vector2(37,429),18,INK)
