extends RefCounted
## Original raster materials; nine-sliced live controls stay interactive at any scale.
static var textures: Dictionary={}
static var styles: Dictionary={}
static var icons: Dictionary={}
static func item_icon(base: String) -> Texture2D:
	if not icons.has(base):
		var item_type: Dictionary=preload("res://scripts/story_inventory.gd").BASES[base]
		var regions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/items/icon-regions.json"))
		var region: Array=regions.regions[int(item_type.icon)]
		var texture := AtlasTexture.new(); texture.atlas=load("res://assets/story/items/inventory-atlas-v2.png")
		texture.region=Rect2(region[0],region[1],region[2],region[3]); icons[base]=texture
	return icons[base]
static func material(index: int) -> Texture2D:
	if not textures.has(index):
		var atlas: Texture2D=load("res://assets/story/items/control-materials-v1.png")
		var regions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/items/control-regions.json"))
		var region: Array=regions.regions[index]
		var image := atlas.get_image().get_region(Rect2i(region[0],region[1],region[2],region[3]))
		image.resize(96,96,Image.INTERPOLATE_LANCZOS)
		textures[index]=ImageTexture.create_from_image(image)
	return textures[index]
static func frame(index: int) -> StyleBoxTexture:
	if not styles.has(index):
		var style := StyleBoxTexture.new(); style.texture=material(index)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			style.set_texture_margin(side,8); style.set_content_margin(side,6)
		styles[index]=style
	return styles[index]
## 同一张九宫格材质压暗，不依赖第二张贴图：hover/pressed 都只是乘一层暖色调。
## 色调取暗红而不是灰，保留原按钮的暖色相（用户第 3 轮反馈）。
static func dimmed(index: int, tone: Color) -> StyleBoxTexture:
	var style: StyleBoxTexture=frame(index).duplicate()
	style.modulate_color=tone
	return style
## 所有剧情按钮共用的按下手感：鼠标按下缩到 0.96，松开回弹，不改变布局。
static func press_fx(node: Button) -> void:
	if node.has_meta("story_press_fx"): return
	node.set_meta("story_press_fx",true)
	node.pivot_offset=node.size*0.5
	node.resized.connect(func(): node.pivot_offset=node.size*0.5)
	node.button_down.connect(func(): _press_to(node,0.96,0.06))
	node.button_up.connect(func(): _press_to(node,1.0,0.14,true))
	node.mouse_exited.connect(func():
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _press_to(node,1.0,0.12))
static func _press_to(node: Button, target: float, seconds: float, bounce: bool = false) -> void:
	var previous: Tween=null
	if node.has_meta("story_press_tween"): previous=node.get_meta("story_press_tween")
	if previous: previous.kill()
	var tween:=node.create_tween()
	if bounce:
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node,"scale",Vector2.ONE*target,seconds)
	node.set_meta("story_press_tween",tween)
static func button(node: Button, selected: bool = false, dangerous: bool = false) -> void:
	var base:=8 if dangerous else 3 if selected else 2
	node.add_theme_stylebox_override("normal",frame(base))
	# 不换第二张贴图：hover / pressed 都在同一张九宫格上乘暗红色。
	node.add_theme_stylebox_override("hover",dimmed(base,Color(0.78,0.40,0.42)))
	node.add_theme_stylebox_override("pressed",dimmed(base,Color(0.52,0.22,0.26)))
	var disabled: StyleBoxTexture=frame(2).duplicate(); disabled.modulate_color=Color(0.55,0.55,0.55,0.8)
	node.add_theme_stylebox_override("disabled",disabled)
	node.add_theme_color_override("font_color",Color("efe0c2"))
	node.add_theme_color_override("font_hover_color",Color("e0c0b6"))
	node.add_theme_color_override("font_pressed_color",Color("c8a39b"))
	node.add_theme_color_override("font_disabled_color",Color("747477"))
	node.add_theme_font_size_override("font_size",17)
	press_fx(node)
## 勾选按钮：由调用方维护 `checked`（✓ / □），不用 `toggle_mode`——否则 Godot 会把
## “已勾选”和“正按住”共用 `pressed` 样式，勾上后看起来永远像按着。
## 材质仍是同一张「启用」九宫格，hover/pressed 只做代码压暗。
static func check_button(node: Button) -> void:
	node.toggle_mode=false
	node.add_theme_stylebox_override("normal",frame(2))
	node.add_theme_stylebox_override("hover",dimmed(2,Color(0.78,0.38,0.40)))
	node.add_theme_stylebox_override("pressed",dimmed(2,Color(0.50,0.20,0.24)))
	var disabled: StyleBoxTexture=frame(2).duplicate(); disabled.modulate_color=Color(0.45,0.45,0.5,0.8)
	node.add_theme_stylebox_override("disabled",disabled)
	node.add_theme_color_override("font_color",Color("efe0c2"))
	node.add_theme_color_override("font_hover_color",Color("e0c0b6"))
	node.add_theme_color_override("font_pressed_color",Color("c8a39b"))
	node.add_theme_color_override("font_disabled_color",Color("747477"))
	node.add_theme_font_size_override("font_size",20)
	press_fx(node)
static func theme_controls(theme: Theme) -> void:
	theme.set_stylebox("panel","TooltipPanel",frame(5))
	theme.set_color("font_color","TooltipLabel",Color("f1e2c9"))
	theme.set_font_size("font_size","TooltipLabel",17)
	theme.set_stylebox("panel","AcceptDialog",frame(5))
	theme.set_stylebox("normal","Button",frame(2)); theme.set_stylebox("hover","Button",frame(3)); theme.set_stylebox("pressed","Button",frame(3))
	theme.set_stylebox("scroll","VScrollBar",frame(0)); theme.set_stylebox("grabber","VScrollBar",frame(2)); theme.set_stylebox("grabber_highlight","VScrollBar",frame(3))
