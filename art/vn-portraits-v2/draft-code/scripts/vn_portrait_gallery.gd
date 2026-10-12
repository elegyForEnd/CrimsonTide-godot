extends Control
## Independent VN art inspection. No campaign, equipment or profile writes.
const Art = preload("res://scripts/story_portrait_art.gd")
const View = preload("res://scripts/story_portrait_view.gd")
const UISkin = preload("res://scripts/story_ui_skin.gd")
var hero := 0
var clothing := 0
var gesture := 0
var emotion := 0
var blush_on := true
var blank := false
var inspection := "all"
var portrait: Control
var zoom: Control
var status: Label
var choices: Dictionary={}

func text(parent: Node, value: String, at: Vector2, extent: Vector2, font_size: int = 22) -> Label:
	var label := Label.new();label.text=value;label.position=at;label.size=extent
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e3c99d"));parent.add_child(label);return label

func button(parent: Node, value: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var node := Button.new();node.text=value;node.position=at;node.size=extent
	node.focus_mode=Control.FOCUS_NONE;UISkin.button(node);node.pressed.connect(action);parent.add_child(node);return node

func stepper(title: String, key: String, y: float) -> void:
	text(self,title,Vector2(75,y),Vector2(270,30),20)
	button(self,"‹",Vector2(65,y+37),Vector2(48,43),func(): shift(key,-1))
	choices[key]=text(self,"",Vector2(120,y+37),Vector2(180,43),20)
	choices[key].horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button(self,"›",Vector2(310,y+37),Vector2(48,43),func(): shift(key,1))

func _ready() -> void:
	size=Vector2(1440,900);mouse_filter=MOUSE_FILTER_STOP
	var backdrop := ColorRect.new();backdrop.color=Color("171522");backdrop.size=size;backdrop.mouse_filter=MOUSE_FILTER_IGNORE;add_child(backdrop)
	var panel := Panel.new();panel.position=Vector2(40,134);panel.size=Vector2(340,696);panel.add_theme_stylebox_override("panel",UISkin.frame(5));add_child(panel)
	text(self,"灯下肖像",Vector2(55,45),Vector2(700,50),36)
	text(self,"PORTRAIT GALLERY / COSTUME · POSE · EXPRESSION",Vector2(57,101),Vector2(950,30),16)
	for i in 3:
		button(self,["绯月","雪璃","鸦羽"][i],Vector2(58+103*i,159),Vector2(98,43),func(): hero=i;refresh())
	stepper("服饰", "costume", 230)
	stepper("姿势", "pose", 336)
	stepper("表情", "expression", 442)
	button(self,"腮红 · 开 / 关",Vector2(66,551),Vector2(286,41),func(): blush_on=not blush_on;refresh())
	button(self,"无表情底图 · 开 / 关",Vector2(66,601),Vector2(286,41),func(): blank=not blank;refresh())
	text(self,"分层查看",Vector2(74,660),Vector2(250,30),18)
	for i in 4:
		var kind: String=["all","eyes","mouth","blush"][i]
		button(self,["完整","眉眼","嘴型","腮红"][i],Vector2(65+(i%2)*148,699+45*(i/2)),Vector2(139,39),func(): inspection=kind;refresh())
	portrait=View.new();portrait.position=Vector2(477,28);portrait.size=Vector2(585,830);add_child(portrait)
	var zoom_panel := Panel.new();zoom_panel.position=Vector2(1090,205);zoom_panel.size=Vector2(308,305);zoom_panel.clip_contents=true;zoom_panel.add_theme_stylebox_override("panel",UISkin.frame(4));add_child(zoom_panel)
	zoom=View.new();zoom_panel.add_child(zoom)
	text(self,"面部细节",Vector2(1100,165),Vector2(280,35),20)
	status=text(self,"",Vector2(1092,536),Vector2(308,215),17);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text(self,"1/2/3 角色 · A/D 服饰 · W/S 姿势 · ←/→ 表情 · B 腮红 · P 底图",Vector2(440,862),Vector2(950,28),16)
	refresh()
	if "--capture-vn-gallery" in OS.get_cmdline_user_args(): capture.call_deferred()

func shift(key: String, direction: int) -> void:
	match key:
		"costume": clothing=posmod(clothing+direction,Art.COSTUMES.size())
		"pose": gesture=posmod(gesture+direction,Art.POSES.size())
		"expression": emotion=posmod(emotion+direction,Art.EXPRESSIONS.size())
	refresh()

func refresh() -> void:
	if portrait==null: return
	for view in [portrait,zoom]:
		view.blush_enabled=blush_on;view.blank=blank;view.inspection=inspection
		view.set_actor("hero:%d" % hero,null,Art.EXPRESSIONS[emotion],Art.COSTUMES[clothing],Art.POSES[gesture])
	choices.costume.text=Art.COSTUME_NAMES[clothing];choices.pose.text=Art.POSE_NAMES[gesture];choices.expression.text=Art.EXPRESSION_NAMES[emotion]
	var rect: Rect2=portrait.face_rect
	zoom.size=Vector2(2160,3840);zoom.position=Vector2(154-rect.get_center().x,138-rect.get_center().y)
	status.text="%s / %s / %s\n\n独立眉眼 + 嘴型 + 腮红\n底图保持不动\n\n腮红：%s\n无表情底：%s\n\n2160×3840 导出画布\n生成原稿约 1.6K 高度\n4K 为 Lanczos 放大" % [Art.COSTUME_NAMES[clothing],Art.POSE_NAMES[gesture],Art.EXPRESSION_NAMES[emotion],"开启" if blush_on else "关闭","开启" if blank else "关闭"]

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1,KEY_2,KEY_3: hero=int(event.keycode)-int(KEY_1);refresh()
		KEY_A: shift("costume",-1)
		KEY_D: shift("costume",1)
		KEY_W: shift("pose",-1)
		KEY_S: shift("pose",1)
		KEY_LEFT: shift("expression",-1)
		KEY_RIGHT: shift("expression",1)
		KEY_B: blush_on=not blush_on;refresh()
		KEY_P: blank=not blank;refresh()
		KEY_ESCAPE: get_tree().quit()
	get_viewport().set_input_as_handled()

func capture() -> void:
	for i in 12: await get_tree().process_frame
	for person in 3:
		for costume in 3:
			for pose in 3:
				hero=person;clothing=costume;gesture=pose;emotion=(person*3+costume+pose)%10;refresh()
				for i in 3:await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var name := "vn-gallery-%d-%d-%d.png" % [hero,clothing,gesture]
				var error := get_viewport().get_texture().get_image().save_png("res://build/"+name)
				if error!=OK:push_error(name);get_tree().quit(1);return
	print("VN_GALLERY_CAPTURE 27 combinations; natural blush enabled")
	get_tree().quit()

func _draw() -> void:
	draw_line(Vector2(430,135),Vector2(1400,135),Color(.6,.47,.29,.6),1,true)
	for radius in [60,90,128]:draw_arc(Vector2(775,809),radius,0,TAU,72,Color(.5,.35,.25,.12),1,true)
