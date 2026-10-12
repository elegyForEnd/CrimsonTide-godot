extends Control
## Independently generated full portraits, three separate selectors like a VN gallery.
const Art = preload("res://scripts/story_portrait_art.gd")
const View = preload("res://scripts/story_portrait_view.gd")
const UISkin = preload("res://scripts/story_ui_skin.gd")
var hero := 0
var clothing := 0
var gesture := 0
var emotion := 0
var distance := 0
var portrait: Control
var closeup: TextureRect
var status: Label
var choices: Dictionary={}

func label(value: String, at: Vector2, extent: Vector2, font_size: int = 22) -> Label:
	var node := Label.new();node.text=value;node.position=at;node.size=extent
	node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",Color("e3c99d"));add_child(node);return node
func button(value: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var node := Button.new();node.text=value;node.position=at;node.size=extent
	node.focus_mode=Control.FOCUS_NONE;UISkin.button(node);node.pressed.connect(action);add_child(node);return node
func stepper(title: String, key: String, y: float) -> void:
	label(title,Vector2(75,y),Vector2(270,30),20)
	button("‹",Vector2(65,y+37),Vector2(48,43),func(): shift(key,-1))
	choices[key]=label("",Vector2(120,y+37),Vector2(180,43),20);choices[key].horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button("›",Vector2(310,y+37),Vector2(48,43),func(): shift(key,1))
func _ready() -> void:
	size=Vector2(1440,900);mouse_filter=MOUSE_FILTER_STOP
	theme=Theme.new();theme.default_font=load("res://assets/NotoSansSC.ttf")
	var background := ColorRect.new();background.color=Color("171522");background.size=size;background.mouse_filter=MOUSE_FILTER_IGNORE;add_child(background)
	var panel := Panel.new();panel.position=Vector2(40,134);panel.size=Vector2(340,696);panel.add_theme_stylebox_override("panel",UISkin.frame(5));add_child(panel)
	label("灯下肖像 · 立绘鉴赏",Vector2(55,45),Vector2(900,50),36)
	label("CRIMSON TIDE / COMPLETE CHARACTER PORTRAITS",Vector2(57,101),Vector2(980,30),16)
	for i in 3:button(["绯月","雪璃","鸦羽"][i],Vector2(58+103*i,159),Vector2(98,43),func(): hero=i;refresh())
	stepper("服饰", "costume", 230);stepper("姿势", "pose", 345);stepper("表情", "expression", 460)
	button("观看距离",Vector2(65,596),Vector2(287,45),func(): distance=posmod(distance+1,3);refresh())
	label("三套服饰 × 三种姿势 × 八种表情",Vector2(67,680),Vector2(300,40),16)
	label("每种组合都是一张完整立绘",Vector2(67,724),Vector2(295,35),17)
	portrait=View.new();portrait.position=Vector2(474,30);portrait.size=Vector2(600,820);add_child(portrait)
	var frame := Panel.new();frame.position=Vector2(1090,205);frame.size=Vector2(310,310);frame.add_theme_stylebox_override("panel",UISkin.frame(4));add_child(frame)
	closeup=TextureRect.new();closeup.position=Vector2(6,6);closeup.size=Vector2(298,298);closeup.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;closeup.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;closeup.mouse_filter=MOUSE_FILTER_IGNORE;frame.add_child(closeup)
	label("面部细节",Vector2(1100,166),Vector2(280,34),20)
	status=label("",Vector2(1092,545),Vector2(306,220),17);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label("1/2/3 角色 · A/D 服饰 · W/S 姿势 · ←/→ 表情 · Z 距离",Vector2(440,862),Vector2(950,28),16)
	refresh()
	if "--capture-vn-full" in OS.get_cmdline_user_args():capture.call_deferred()
func shift(key: String, direction: int) -> void:
	match key:
		"costume":clothing=posmod(clothing+direction,3)
		"pose":gesture=posmod(gesture+direction,3)
		"expression":emotion=posmod(emotion+direction,8)
	refresh()
func refresh() -> void:
	if portrait==null:return
	var factor: float=[1.0,1.3,1.65][distance]
	portrait.size=Vector2(600,820)*factor;portrait.position=Vector2(774-portrait.size.x/2,850-portrait.size.y)
	portrait.set_actor("hero:%d" % hero,null,Art.EXPRESSIONS[emotion],Art.COSTUMES[clothing],Art.POSES[gesture])
	choices.costume.text=Art.COSTUME_NAMES[clothing];choices.pose.text=Art.POSE_NAMES[gesture];choices.expression.text=Art.EXPRESSION_NAMES[emotion]
	var crop := AtlasTexture.new();crop.atlas=portrait.texture;crop.region=Rect2(580,150,1000,1000);crop.filter_clip=true;closeup.texture=crop
	status.text="%s / %s / %s\n\n独立完整 PNG\n原画人物与自然腮红\n\n每人 72 张 · 共 216 张\n\n2160×3840 导出画布\n原稿尺寸保存在制作记录\n4K 画布由原稿整图放大" % [Art.COSTUME_NAMES[clothing],Art.POSE_NAMES[gesture],Art.EXPRESSION_NAMES[emotion]]
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_1,KEY_2,KEY_3:hero=int(event.keycode)-int(KEY_1);refresh()
		KEY_A:shift("costume",-1)
		KEY_D:shift("costume",1)
		KEY_W:shift("pose",-1)
		KEY_S:shift("pose",1)
		KEY_LEFT:shift("expression",-1)
		KEY_RIGHT:shift("expression",1)
		KEY_Z:distance=posmod(distance+1,3);refresh()
		KEY_ESCAPE:get_tree().quit()
	get_viewport().set_input_as_handled()
func capture() -> void:
	var directory: String=ProjectSettings.globalize_path("res://build") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().get_base_dir().path_join("build")
	DirAccess.make_dir_recursive_absolute(directory)
	for i in 12:await get_tree().process_frame
	for person in 3:
		for costume in 3:
			for pose in 3:
				hero=person;clothing=costume;gesture=pose;emotion=(person*3+costume+pose)%8;refresh()
				for i in 3:await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var name := "vn-full-gallery-%d-%d-%d.png" % [hero,clothing,gesture]
				var error := get_viewport().get_texture().get_image().save_png(directory.path_join(name))
				if error!=OK:push_error(name);get_tree().quit(1);return
	print("VN_FULL_GALLERY_CAPTURE 27 combinations, whole portraits");get_tree().quit()
