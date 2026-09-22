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
var drag: Dictionary = {"active":false,"slot":"backpack","source":-1,"rot":false}
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
var damage_overlay: ColorRect
var damage_tween: Tween

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
	var damage_layer := CanvasLayer.new()
	damage_layer.layer=50
	add_child(damage_layer)
	damage_overlay=ColorRect.new()
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	damage_overlay.color=Color(0.75,0.035,0.09,0.25)
	var damage_material := ShaderMaterial.new()
	damage_material.shader=preload("res://resources/damage_vignette.gdshader")
	damage_overlay.material=damage_material
	damage_layer.add_child(damage_overlay)
	damage_overlay.hide()
	var cinema_layer := CanvasLayer.new()
	cinema_layer.layer=100
	add_child(cinema_layer)
	ultimate=UltimateCinematic.new()
	cinema_layer.add_child(ultimate)
	ultimate.burst.connect(func(): sound.burst_cinematic(ultimate.hero))
	ultimate.ended.connect(sound.end_cinematic)
	ultimate.ended.connect(func(_interrupted: bool):
		if not session.online and page_name=="game":
			session.release_ultimate(session.my_id())
	)
	ultimate.began.connect(sound.begin_cinematic)
	session.combat_event.connect(func(data: Dictionary):
		if data.kind=="ultimate-start" and int(data.get("id",-1))==session.my_id() and page_name=="game":
			ultimate.play(int(data.hero),session.online)
	)
	set_volume(float(profile.data.volume))
	set_voice_volume(float(profile.data.voice_volume))
	set_music_volume(float(profile.data.music_volume))
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

func button(parent: Node, text: String, at: Vector2, size: Vector2, callback: Callable, primary: bool = false, font_size: int = 0) -> Button:
	var b := GothicButton.new()
	b.primary=primary
	b.accent=GOLD
	b.serif=title_font
	# The font size has to be in place before the size is assigned, otherwise the
	# cell inherits the minimum height of the default 18px font.
	if font_size>0:
		b.add_theme_font_size_override("font_size",font_size)
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
	clear_damage_feedback()
	if name_value!="game" and not session.online:
		session.cancel_ultimate(session.my_id())
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
			if profile.data.hero!=i:
				profile.data.hero=i
				ready_local=false
				profile.save_profile()
				session.configure(config())
			sound.dialogue.play_selection(i)
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
		var icon: String = Catalog.GEAR_ICONS[i]
		item_icon(page,icon,Vector2(x+31,251),Vector2(52,52))
		label(page,gear.name,Vector2(x,310),15,INK if profile.data.gear==i else MUTED,Vector2(113,31)).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label(page,Catalog.GEAR[profile.data.gear].desc,Vector2(584,356),15,GOLD)
	label(page,"局内搜到的武器与装备可当场穿上，本局立即生效",Vector2(584,380),12,MUTED,Vector2(384,20))
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
	label(page,"WASD 走路 · SHIFT 奔跑 · 鼠标攻击",Vector2(1170,784),11,MUTED,Vector2(241,20))
	label(page,"SPACE 闪避 · R 装填 · 1-4 换武器",Vector2(1170,806),11,MUTED,Vector2(241,20))
	label(page,"F 拾取/搜索/急救 · TAB 背包 · M 地图",Vector2(1170,828),11,MUTED,Vector2(241,20))
	hud.loadout=label(page,"",Vector2(1170,858),11,GOLD,Vector2(241,18))
	hud.loadout2=label(page,"",Vector2(1170,876),11,MUTED,Vector2(241,18))
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
		keep_loot_window()
		if inventory_open:
			var p: Dictionary=session.players.get(session.my_id(),{})
			var container: Dictionary=session.container_at(_loot_index) if _loot_index>=0 else {}
			if container.is_empty() and _loot_index>=0:
				_loot_index=-1
			var signature := str(p.get("backpack",{}))+str(p.get("pocket",{}))+str(p.get("equipped",{}))+str(container)
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
		# Right click is the mouse shortcut for the same R rotation.
		rotate_selected()
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
		toggle_map()
	if event.is_action_pressed("loot") and not event.is_echo():
		# F is one key with two jobs: loot what is in reach, and fall through to the
		# medkit when there is nothing left to grab or search. Going down always
		# tries the self-revive first.
		var me: Dictionary=session.players.get(session.my_id(),{})
		var downed := not me.is_empty() and str(me.get("status",""))=="down"
		var looted := false if downed else loot_action()
		if not looted:
			heal_action()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("heal") and not event.is_echo():
		heal_action()
	if event.is_action_pressed("burn") and not event.is_echo():
		session.action("burn")
		if inventory_open:
			show_inventory()
	if inventory_open:
		if event.is_action_pressed("reload") and not event.is_echo():
			rotate_selected()
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
# Returns false when there was nothing to loot, which is what lets the same key
# fall through to the medkit.
func loot_action() -> bool:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty() or p.status not in ["active","down"]:
		return false
	if session.pick_up_ground(p):
		if inventory_open:
			show_inventory()
		return true
	var index: int=session.search_target(p)
	if index<0:
		return false
	var container: Dictionary=session.container_at(index)
	if container.is_empty():
		return false
	# A container the window already points at and that is fully revealed has
	# nothing left to show, so F is free to do the other job.
	if index==_loot_index and session.container_searched(container):
		return false
	session.action("search",{"index":index})
	_loot_index=index
	inventory_open=true
	selected=-1
	show_inventory()
	return true

func heal_action() -> void:
	session.action("heal")
	if inventory_open:
		show_inventory()

# R (or the right mouse button) turns the item in hand, and the item selected in
# the grid when nothing is held. Position is preserved whenever the turned
# footprint still fits, otherwise the session slides it to the nearest free cell.
func rotate_selected() -> void:
	if drag.active:
		# "rot" is the orientation the item will end up in, not a delta: releasing
		# the drag writes exactly this back, so a turned item stays turned.
		drag.rot=not bool(drag.rot)
		show_inventory()
		return
	if selected<0 or selected_slot not in ["backpack","pocket"]:
		return
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	var list: Array=Catalog.container_items(p[selected_slot])
	if selected>=list.size():
		return
	rotated=not bool(list[selected].get("rot",false))
	session.action("bag_rotate",{"slot":selected_slot,"index":selected})
	# The authoritative item decides the shown orientation: a refused rotation
	# must not leave the panel claiming the item turned.
	var after: Array=Catalog.container_items(p[selected_slot])
	if selected<after.size():
		rotated=bool(after[selected].get("rot",false))
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
	hud.ammo.text=weapon_title(p)+(" · 装填中" if p.reload>0 else (" %02d/%d" % [p.ammo,p.reserve] if p.weapon==0 else " · 三连击" if p.weapon==1 else ""))
	hud.scent.text="战利品  %d ◈   /   击杀 %d" % [loot_total(p),p.kills]
	hud.skill.text="[Q] "+Catalog.HEROES[p.hero].skill+("  %.0fs" % ceil(p.skill) if p.skill>0 else "  就绪")
	hud.items.text="[F] 急救针 ×%d    [B] 血晶 ×%d    /    %s" % [session.carried(p,"medicine"),session.carried(p,"crystal"),session.backpack_label(p)]
	var kit: Array=loadout_lines(p)
	hud.loadout.text=str(kit[0])
	hud.loadout2.text=str(kit[1])
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
		hud.notice.text="撤离成功 · 战利品已保全" if p.status=="extracted" else "守夜终结 · 背包与身上装备已散落，次元口袋仍在"
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
		sound.play("ui-open")
		inventory_open=true
		selected=-1
		selected_slot="backpack"
		drag.active=false
		show_inventory()

# Closing the bag has to take the panels off the screen: the whole inventory is
# drawn straight onto the overlay, so nothing else would ever erase it. The search
# window closes with it — the container keeps its search progress, and pressing F
# at the chest opens it again.
func close_bag() -> void:
	if inventory_open:
		sound.play("ui-close")
	inventory_open=false
	_loot_index=-1
	selected=-1
	stop_drag()
	grids.clear()
	clear(overlay)
	drag_ghost=null
	drag_ring=null
	drag_caption=null

func toggle_map() -> void:
	field.map_open=not field.map_open
	sound.play("ui-open" if field.map_open else "ui-close")

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
	var rot: bool=bool(drag.rot)
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
	var count := int(held.get("count",1))
	var accent := item_tint(held)
	var icon := drag_ghost.get_child(1) as TextureRect
	var plate := drag_ghost.get_child(0) as Panel
	var stroke := drag_ghost.get_child(3) as ObjectRing
	if icon==null or plate==null:
		return
	icon.texture=load("res://assets/icons/"+Catalog.item_icon(held)+".svg")
	# The lifted art turns with the item, exactly like the slot it came from.
	icon.rotation=PI*0.5 if bool(drag.rot) else 0.0
	plate.add_theme_stylebox_override("panel",style(Color(accent.darkened(0.88),0.62),Color(accent,0.95)))
	if stroke:
		stroke.tone=Color(accent,0.95)
		stroke.queue_redraw()
	drag_caption.text=Catalog.item_name(held)+(" ×%d" % count if count>1 else "")
	drag_caption.visible=true
	drag_ghost.visible=true
	drag_ring.visible=true

# One frame of drag feedback: move the icon under the cursor and redraw the
# landing cell so the preview always matches what the session would do.
func sync_drag() -> void:
	if not drag.active:
		if drag_ghost and is_instance_valid(drag_ghost):
			drag_ghost.visible=false
		if drag_ring and is_instance_valid(drag_ring):
			drag_ring.visible=false
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
		var dims := Catalog.item_size({"kind":kind,"rot":bool(drag.rot)})
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
		icon.pivot_offset=icon.size/2
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
	var probe := {"kind":kind,"rot":bool(drag.rot)}
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
	return Catalog.item_color(item)

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
	var size := Catalog.item_size({"kind":held.kind,"rot":bool(drag.rot)})
	return Vector2(size.x*(cell+gap)-gap,size.y*(cell+gap)-gap)

func can_drop_at(slot: String, cell: Vector2i) -> bool:
	var held := held_item()
	if held.is_empty():
		return false
	if slot=="loot":
		if str(drag.slot)=="loot":
			return false
		var target: Dictionary=session.container_at(_loot_index)
		var probe := {"kind":str(held.kind),"rot":bool(drag.rot)}
		return Catalog.can_place(session.peek_items(target),probe,cell,-1,session.container_grid(target))
	if slot=="backpack" or slot=="pocket":
		var p: Dictionary=session.players.get(session.my_id(),{})
		var dest: Dictionary=p[slot]
		var probe := {"kind":str(held.kind),"rot":bool(drag.rot)}
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
		var dims := Catalog.item_size(item)
		var accent: Color=Catalog.item_color(item)
		var count := int(item.get("count",1))
		var caption: String=Catalog.item_name(item)+(" ×%d" % count if count>1 else "")
		if drag.active and str(drag.slot)==slot and i==int(drag.source):
			continue	# the held item follows the cursor instead
		var item_button := button(overlay,caption,origin+Vector2(item.x*(cell+gap),item.y*(cell+gap)),Vector2(dims.x*(cell+gap)-gap-3,dims.y*(cell+gap)-gap-3),func(): pick_item(slot,i),false,12)
		item_button.slot=true
		item_button.item_kind=Catalog.item_icon(item)
		item_button.rotated=bool(item.get("rot",false))
		item_button.short_caption=Catalog.item_short_name(item)+(" ×%d" % count if count>1 else "")
		item_button.accent=accent
		item_button.selected=selected==i and selected_slot==slot
		item_button.tooltip_text=Catalog.item_name(item)+"\n"+Catalog.item_desc(item)+"\n价值："+str(Catalog.item_value(item))
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
	# A deferred rebuild can land after the bag was closed; drawing then would put
	# the panels back on a screen the player already dismissed.
	if not inventory_open or modal:
		return
	clear(overlay)
	grids.clear()
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	var container: Dictionary=session.container_at(_loot_index) if _loot_index>=0 else {}
	if container.is_empty():
		_loot_index=-1
	bag_signature=str(p.backpack)+str(p.pocket)+str(p.get("equipped",{}))+str(container)
	var bag_grid: Vector2i=Catalog.bag_grid(p.backpack)
	var pocket_grid: Vector2i=Catalog.container_grid(p.pocket)
	var bag_items: Array=p.backpack.items
	if selected_slot not in ["backpack","pocket"]:
		selected_slot="backpack"
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
# The right column is also the equipment screen: the selected item's actions on
# top, the worn weapon and gear in the middle, the backpack cabinet at the bottom.
func draw_details(p: Dictionary, x: float, y: float, wide: float, tall: float) -> void:
	rect(overlay,Vector2(x,y),Vector2(wide,tall),BG,Color("6e4d5d"))
	ornament(overlay,Vector2(x,y),Vector2(wide,tall),"frame")
	label(overlay,"战利品档案 / 装备",Vector2(x+20,y+15),21,GOLD)
	ornament(overlay,Vector2(x+18,y+50),Vector2(wide-36,10))
	var ix := x+22
	var inner := wide-44.0
	if selected>=0 and selected_slot in ["backpack","pocket"] and selected<p[selected_slot].items.size():
		var item: Dictionary=p[selected_slot].items[selected]
		var accent: Color=Catalog.item_color(item)
		item_icon(overlay,Catalog.item_icon(item),Vector2(ix,y+68),Vector2(58,58))
		label(overlay,Catalog.item_name(item),Vector2(ix+70,y+72),21,accent,Vector2(inner-74,32))
		label(overlay,("角色背包" if selected_slot=="backpack" else Catalog.POCKET_NAME)+" · 第 %d 件" % (selected+1),Vector2(ix+71,y+106),13,MUTED)
		var text := label(overlay,Catalog.item_desc(item),Vector2(ix,y+138),13,MUTED,Vector2(inner,48))
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(overlay,"朝向："+("已旋转" if item.get("rot",false) else "默认")+"      价值 %d ◈" % Catalog.item_value(item),Vector2(ix,y+190),14,GOLD)
		var action: Dictionary=use_action(item,p)
		if action.is_empty():
			label(overlay,"这件战利品只能带回去结算。",Vector2(ix,y+240),13,Color("8d8494"),Vector2(inner,30))
		else:
			var primary := button(overlay,str(action.text),Vector2(ix,y+234),Vector2(inner,42),use_selected,true)
			primary.disabled=not bool(action.enabled)
		var other: String="pocket" if selected_slot=="backpack" else "backpack"
		var label_text := "存入 "+Catalog.POCKET_NAME if other=="pocket" else "放回角色背包"
		button(overlay,label_text,Vector2(ix,y+286),Vector2(inner-158,40),func(): move_to_other(selected_slot,selected))
		button(overlay,"丢到地面",Vector2(ix+inner-150,y+286),Vector2(150,40),func():
			session.action("drop",{"index":selected,"slot":selected_slot})
			selected=-1
			show_inventory()
		)
	else:
		ornament(overlay,Vector2(x+wide/2-56,y+62),Vector2(112,112),"seal")
		label(overlay,"点击或拖动一件物品",Vector2(ix,y+192),15,MUTED,Vector2(inner,30))
		label(overlay,"选中武器或装备即可穿到身上",Vector2(ix,y+218),13,Color("8d8494"),Vector2(inner,30))
	draw_equipment(p,x,y,wide)
	label(overlay,"[R] 或右键旋转   ·   拖到框外丢到地面",Vector2(ix,y+490),13,MUTED,Vector2(inner,22))
	draw_cabinet(p,x,y,wide)

# The worn kit: one weapon slot plus armour, sight and boots. Each filled slot
# can be taken off and returns to the backpack.
func draw_equipment(p: Dictionary, x: float, y: float, wide: float) -> void:
	var ix := x+22
	var inner := wide-44.0
	label(overlay,"装备栏   /   本局强化",Vector2(ix,y+340),17,GOLD,Vector2(inner,26))
	ornament(overlay,Vector2(x+18,y+366),Vector2(wide-36,10))
	var rows: Array = [{"title":"武器","item":session.kit_weapon(p),"type":"weapon","slot":0}]
	var gear: Array=session.kit_gear(p)
	for i in Catalog.GEAR.size():
		var entry: Dictionary={}
		if i<gear.size() and gear[i] is Dictionary:
			entry=gear[i]
		rows.append({"title":["护甲","瞄具","轻靴"][i],"item":entry,"type":"gear","slot":i})
	var row := 0
	for entry in rows:
		var ry := y+378+row*24
		var item: Dictionary=entry.item
		var kind := str(entry.type)
		var index := int(entry.slot)
		if item.is_empty():
			label(overlay,"· %s   空槽" % entry.title,Vector2(ix,ry),13,Color("6a6470"),Vector2(inner-70,22))
		else:
			label(overlay,"%s %s" % [entry.title,Catalog.item_name(item)],Vector2(ix,ry),12,Catalog.quality_color(int(item.get("tier",0))),Vector2(154,22))
			label(overlay,equipment_bonus_text(item,kind),Vector2(ix+156,ry),12,GOLD,Vector2(110,22))
			button(overlay,"卸下",Vector2(x+wide-88,ry-3),Vector2(66,22),func(): unequip_slot(kind,index))
		row+=1

# Compact slot bonus for the equipment list: one glance, no wrapping.
func equipment_bonus_text(item: Dictionary, kind: String) -> String:
	if kind=="weapon":
		return "伤+%d%% 速+%d%%" % [int(round(Catalog.weapon_bonus(item)*100.0)),int(round(Catalog.weapon_rate_bonus(item)*100.0))]
	match Catalog.gear_slot(item):
		0: return "生命+%d" % int(round(Catalog.gear_bonus(item)))
		1: return "火力+%d%%" % int(round(Catalog.gear_bonus(item)*100.0))
		_: return "移速+%d" % int(round(Catalog.gear_bonus(item)))

func draw_cabinet(p: Dictionary, x: float, y: float, wide: float) -> void:
	var ix := x+22
	var inner := wide-44.0
	label(overlay,"背包柜   /   点击装备",Vector2(ix,y+512),17,GOLD,Vector2(inner,26))
	ornament(overlay,Vector2(x+18,y+538),Vector2(wide-36,10))
	label(overlay,"当前："+session.backpack_label(p),Vector2(ix,y+548),13,GOLD,Vector2(inner,22))
	var half := inner/2.0
	for i in Catalog.BAG_TIERS.size():
		var tier: Dictionary=Catalog.BAG_TIERS[i]
		var tx := ix+float(i%2)*half
		var ty := y+574+float(int(i/2))*22
		if tier.key==str(p.backpack.key):
			label(overlay,"◈ %s %d×%d  已装备" % [tier.quality,tier.grid.x,tier.grid.y],Vector2(tx,ty),12,tier.color,Vector2(half-4,20))
		else:
			var spare := spare_index(p,tier.key)
			label(overlay,"· %s %d×%d" % [tier.quality,tier.grid.x,tier.grid.y],Vector2(tx,ty),12,Color("cfc6bb") if spare>=0 else Color("6a6470"),Vector2(half-58,20))
			if spare>=0:
				var take := spare
				button(overlay,"装备",Vector2(tx+half-54,ty-2),Vector2(52,20),func(): equip_spare(take))

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
		var cell_pos := origin+Vector2((i%grid.x)*(LOOT_CELL+LOOT_GAP),int(i/grid.x)*(LOOT_CELL+LOOT_GAP))
		var count := int(item.get("count",1))
		var caption: String=Catalog.item_name(item)+(" ×%d" % count if count>1 else "")
		if item.kind=="backpack":
			var key := str(item.get("quality",Catalog.DEFAULT_BAG_KEY))
			caption=Catalog.tier(key).quality+"背包"
		var card := button(overlay,caption,cell_pos,Vector2(LOOT_CELL,LOOT_CELL),func(): take_loot_card(i),false,12)
		card.slot=true
		card.item_kind=Catalog.item_icon(item)
		card.rotated=bool(item.get("rot",false))
		card.short_caption=Catalog.item_short_name(item)+(" ×%d" % count if count>1 else "")
		card.accent=Catalog.item_color(item)
		card.tooltip_text=Catalog.item_name(item)+"\n"+Catalog.item_desc(item)+"\n左键拖入背包，或点「拿取」"
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
		label(overlay,"把鼠标移到搜索框里的物品上，按住左键拖进背包。",Vector2(x+20,top+46),13,MUTED,Vector2(350,40)).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	else:
		item_icon(overlay,Catalog.item_icon(held),Vector2(x+20,top+44),Vector2(46,46))
		label(overlay,Catalog.item_name(held),Vector2(x+78,top+48),19,Catalog.item_color(held),Vector2(286,30))
		var text := label(overlay,Catalog.item_desc(held),Vector2(x+20,top+98),13,MUTED,Vector2(350,46))
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(overlay,"价值 %d ◈   ·   拖到左侧网格即可拿走" % Catalog.item_value(held),Vector2(x+20,top+146),13,GOLD)
	# Supplies stay usable while the search window is open, so a medkit never
	# needs the window closed first.
	label(overlay,"快捷使用",Vector2(x+20,top+178),13,Color("9fb6c8"),Vector2(80,22))
	var quick := quick_use_slots(p)
	if quick.is_empty():
		label(overlay,"背包与口袋中没有可用的消耗品。",Vector2(x+94,top+179),12,Color("6d7d8c"),Vector2(270,22))
	var slot_x := x+94.0
	for entry in quick:
		var kind := str(entry.kind)
		var slot := str(entry.slot)
		var index := int(entry.index)
		var chip := button(overlay,"%s ×%d" % [Catalog.ITEMS[kind].name,Catalog.container_count(p[slot],kind)],Vector2(slot_x,top+204),Vector2(112,34),func(): use_item(slot,index),false,13)
		chip.tooltip_text=Catalog.ITEMS[kind].desc
		slot_x+=118.0

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

# A loose backpack found in the field is worn through the authoritative session,
# so the swap also works for clients in a co-op room.
func equip_pocket_pack(index: int, slot: String = "pocket") -> void:
	session.action("equip_bag",{"slot":slot,"index":index})
	selected=-1
	call_deferred("show_inventory")

func move_to_other(slot: String, index: int) -> void:
	session.action("move_to",{"from":slot,"index":index})
	selected=-1
	call_deferred("show_inventory")

# --- using and equipping from the backpack ---------------------------------
func use_selected() -> void:
	if selected<0 or selected_slot not in ["backpack","pocket"]:
		return
	use_item(selected_slot,selected)

# The one entry point for using an item, shared by the details panel, the quick
# bar next to a search window and the tests.
func use_item(slot: String, index: int) -> void:
	session.action("use",{"slot":slot,"index":index})
	call_deferred("show_inventory")

func equip_slot(slot: String, index: int) -> void:
	session.action("equip",{"slot":slot,"index":index})
	selected=-1
	call_deferred("show_inventory")

func unequip_slot(type: String, index: int = 0) -> void:
	session.action("unequip",{"type":type,"index":index})
	call_deferred("show_inventory")

# What the big button in the details panel does for the selected item. An empty
# dictionary means the item can only be carried home.
func use_action(item: Dictionary, p: Dictionary) -> Dictionary:
	match str(item.kind):
		"medicine":
			if float(p.hp)<float(p.max_hp):
				return {"text":"使用 · 恢复 45 生命","enabled":true}
			return {"text":"生命已满 · 留着","enabled":false}
		"crystal":
			return {"text":"使用 · 燃晶驱散血香","enabled":true}
		"ammo":
			return {"text":"使用 · 补充 48 发弹药","enabled":true}
		"weapon":
			return {"text":"装备 · 伤害 +%d%%  攻速 +%d%%" % [int(round(Catalog.weapon_bonus(item)*100.0)),int(round(Catalog.weapon_rate_bonus(item)*100.0))],"enabled":true}
		"gear":
			return {"text":"装备 · "+Catalog.gear_desc(item),"enabled":true}
		"backpack":
			return {"text":"装备这个背包","enabled":true}
	return {}

# The first usable supply of each kind, so the quick bar stays three wide while a
# search window has the player's attention.
func quick_use_slots(p: Dictionary) -> Array:
	var out: Array = []
	for slot in ["backpack","pocket"]:
		var items: Array=Catalog.container_items(p[slot])
		for i in items.size():
			var kind := str(items[i].kind)
			if not kind in ["medicine","crystal","ammo"]:
				continue
			var seen := false
			for entry in out:
				if str(entry.kind)==kind:
					seen=true
			if seen:
				continue
			out.append({"kind":kind,"slot":slot,"index":i})
			if out.size()>=3:
				return out
	return out

func weapon_title(p: Dictionary) -> String:
	var title: String=Catalog.WEAPONS[p.weapon].name
	if session.weapon_kit_active(p):
		title+=" 强化+%d%%" % int(round(Catalog.weapon_bonus(session.kit_weapon(p))*100.0))
	return title

# Two compact HUD lines: how many slots are filled, and what they add up to.
func loadout_lines(p: Dictionary) -> Array:
	var parts: Array = []
	var hp: float=session.equipment_hp(p)
	var damage: float=session.equipment_damage(p)
	var speed: float=session.equipment_speed(p)
	if hp>0.5:
		parts.append("生命 +%d" % int(round(hp)))
	if damage>0.005:
		parts.append("火力 +%d%%" % int(round(damage*100.0)))
	if speed>0.5:
		parts.append("移速 +%d" % int(round(speed)))
	var worn := 0 if session.kit_weapon(p).is_empty() else 1
	for entry in session.kit_gear(p):
		if entry is Dictionary and not entry.is_empty():
			worn+=1
	return ["本局装备  %d / %d" % [worn,1+Catalog.GEAR.size()]," ".join(PackedStringArray(parts)) if not parts.is_empty() else "在背包里点击武器 / 装备即可穿上"]

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
			label(page,"带出 "+Catalog.bag_quality(r.bags[0])+"背包",Vector2(585,y+50),13,Catalog.bag_color(r.bags[0]),Vector2(175,22))
		var worn: Array=r.get("worn",[])
		if not worn.is_empty():
			var shown: String="  ".join(PackedStringArray(worn.slice(0,2)))
			if worn.size()>2:
				shown+=" 等 %d 件" % worn.size()
			label(page,"身上装备 %s · %s" % [shown,"撤离后已消耗" if r.escaped else "已散落在废墟"],Vector2(770,y+50),12,MUTED,Vector2(540,22))
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

func flash_damage_feedback() -> void:
	if damage_tween:
		damage_tween.kill()
	damage_overlay.modulate.a=1.0
	damage_overlay.show()
	damage_tween=create_tween()
	damage_tween.tween_interval(0.045)
	damage_tween.tween_property(damage_overlay,"modulate:a",0.0,0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	damage_tween.tween_callback(damage_overlay.hide)

func clear_damage_feedback() -> void:
	if damage_tween:
		damage_tween.kill()
	if damage_overlay:
		damage_overlay.hide()

func on_combat_audio(data: Dictionary) -> void:
	if page_name!="game":
		return
	sound.listener.global_position=field.camera
	var emitter := int(data.get("id",0))
	var speaker: Dictionary=session.players.get(emitter,{})
	var voice_hero := int(speaker.get("hero",0))
	sound.dialogue.local_id=session.my_id()
	match str(data.kind):
		"ultimate-start":
			sound.stop_cue("reload",emitter)
			sound.stop_cue("magic-windup",emitter)
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
			# Authoritative hurt/down events also reach clients; only flash the victim's screen.
			if emitter==session.my_id() and str(data.cue) in ["hurt","down"]:
				flash_damage_feedback()
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
			# A host release may arrive just before the final local CG frame.
			if emitter==session.my_id() and ultimate.active:
				ultimate.stop(false)
			sound.play("skill",int(data.hero),data.p,0.0,emitter)
			if emitter!=session.my_id():
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
	var at := modal_box("设置",Vector2(740,585))
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
	label(overlay,"背景音乐",at+Vector2(37,262),20)
	var music_slider := HSlider.new()
	music_slider.position=at+Vector2(185,277)
	music_slider.size=Vector2(480,30)
	music_slider.min_value=0
	music_slider.max_value=1
	music_slider.step=.01
	music_slider.value=profile.data.music_volume
	music_slider.value_changed.connect(func(value: float): set_music_volume(value); profile.data.music_volume=value; profile.save_profile())
	overlay.add_child(music_slider)
	button(overlay,"切换全屏 / 窗口",at+Vector2(37,353),Vector2(665,56),func():
		profile.data.fullscreen=not profile.data.fullscreen
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		profile.save_profile()
	)
	label(overlay,"日语角色语音 · 奥义配有中文字幕",at+Vector2(37,443),16,MUTED)
	label(overlay,"成长自动保存；联机使用固定 UDP 24872 端口。",at+Vector2(37,485),15,MUTED)

func set_music_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(.001,value)))
	AudioServer.set_bus_mute(bus,value<.005)

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
	label(overlay,"WASD 移动 · 鼠标瞄准与左键攻击\n1 单手剑 · 2 双手剑 · 3 法杖 · 4 步枪\n空格闪避 · Q 技能 · R 装填\nF 拾取 / 搜索 / 没东西可捡时急救 · B 燃烧血晶 / 自救\nTAB 背包与口袋 · M 战术地图 · ESC 菜单",left+Vector2(0,51),18,INK,Vector2(480,190)).add_theme_constant_override("line_spacing",13)
	label(overlay,"02  /  搜刮要慢慢来",left+Vector2(0,240),23,GOLD)
	var risk := label(overlay,"对着物资箱按 [F] 开始搜索，物品会每隔约 1.2 秒浮出一件，搜索框和背包可以同时开着。\n\n用鼠标把搜出的物品拖进角色背包或次元口袋即可拿走；担心被偷袭就随时按 [TAB] 关掉。深处教堂的箱子是 5×5，普通箱子是 4×4。\n\n背包内按 [R]（或右键）旋转物品；点选物品后可以用面板按钮使用或装备。地上的掉落物直接按 [F] 秒拾。",left+Vector2(0,291),17,MUTED,Vector2(462,268))
	risk.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var right := at+Vector2(554,100)
	label(overlay,"03  /  一同出征，独立撤离",right,23,GOLD)
	var coop := label(overlay,"地图上的金色菱形是晨钟封印。长按 E 3 秒激活；每处全队奖励 55 银币，完成三处额外奖励 100。\n\n绿色十字是撤离点。长按 E 4 秒撤离，受伤中断。先撤离的玩家可以观战，队友无需同时离开。",right+Vector2(0,51),18,MUTED,Vector2(463,237))
	coop.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(overlay,"04  /  不要遗忘时间",right+Vector2(0,308),23,GOLD)
	var danger := label(overlay,"后半局毒雾从外围收缩，圈外持续损失生命与理智。到达时限，未撤离者全部阵亡。\n\n倒地后队友可长按 E 救援，但背包与身上装备当场散落。地上的武器（2×2）和护甲 / 瞄具 / 轻靴（1×2）可以捡起来装备，本局立刻变强。\n\n全员离场才统一结算：撤离成功保留背包与口袋价值，阵亡只剩次元口袋。",right+Vector2(0,356),18,MUTED,Vector2(463,220))
	danger.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func show_credits() -> void:
	var at := modal_box("制作组 / 资源说明",Vector2(830,620))
	label(overlay,"血潮守望 · Crimson Tide",at+Vector2(37,107),29,GOLD)
	label(overlay,"游戏实现  /  Godot 4 · GDScript\n主视觉、立绘与精灵  /  AI 原创插画\n音效  /  Lentikula · Kenney 等 CC0 素材再设计\n日语真人语音  /  フリーボイス素材屋すぱらんど\n声优  /  すぱるな瀟洒 · 三套角色演绎\n攻击 · 施法 · 受伤 · 奥义出招\n免费授权录音 · 日语台词 · 中文奥义字幕\n完整鸣谢  /  AUDIO-CREDITS.txt · VOICE-CREDITS.txt\n字体  /  Noto Serif & Sans SC · SIL OFL",at+Vector2(37,172),18,MUTED,Vector2(750,340)).add_theme_constant_override("line_spacing",10)
	label(overlay,"献给每一位在长夜中守望黎明的人。",at+Vector2(37,550),18,INK)
