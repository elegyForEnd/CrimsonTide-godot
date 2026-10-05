extends RefCounted
## Actual ImageGen skin atlas. All interactive labels remain live Godot controls.
const PATH := "res://assets/home/generated/hearthhaven-chrome-v3.png"
const REGIONS := {
	"modal": Rect2(24,610,876,390), "plaque": Rect2(16,22,790,256),
	"button": Rect2(16,312,628,130), "primary": Rect2(16,462,628,140),
	"team": Rect2(828,24,684,312), "card": Rect2(24,610,876,390),
	"toolbar": Rect2(672,422,840,122)
}
static var atlas: Texture2D
static var textures := {}
static func texture(kind: String) -> Texture2D:
	if textures.has(kind): return textures[kind]
	if not atlas: atlas = load(PATH)
	var region := AtlasTexture.new()
	region.atlas = atlas
	var scale := atlas.get_size()/Vector2(1536,1024)
	var rect: Rect2 = REGIONS[kind]
	region.region = Rect2(rect.position*scale,rect.size*scale)
	region.filter_clip = true
	textures[kind] = region
	return region
static func style(kind: String, margin: int = 16) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture(kind)
	box.texture_margin_left = 18
	box.texture_margin_right = 18
	box.texture_margin_top = 18
	box.texture_margin_bottom = 18
	if kind in ["button","primary"]:
		# Scale the illustrated top/bottom with the control height; fixed slices
		# were squeezing the painted center behind the live text.
		box.texture_margin_top = 0
		box.texture_margin_bottom = 0
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box
static func dress(node: Button, primary: bool = false) -> void:
	var compact := node.text in ["i","×",""]
	var normal: StyleBox = StyleBoxEmpty.new() if compact else style("primary" if primary else "button",10)
	node.add_theme_stylebox_override("normal",normal)
	var hover := style("primary" if primary else "button",10)
	hover.modulate_color = Color(1.18,1.08,1.12)
	node.add_theme_stylebox_override("hover",hover)
	node.add_theme_stylebox_override("focus",hover)
	var pressed := hover.duplicate()
	pressed.modulate_color = Color(0.8,0.67,0.7)
	node.add_theme_stylebox_override("pressed",pressed)
	var disabled: StyleBox = StyleBoxEmpty.new() if compact else style("button",10)
	if disabled is StyleBoxTexture: disabled.modulate_color = Color(0.68,0.6,0.63)
	node.add_theme_stylebox_override("disabled",disabled)
	node.add_theme_color_override("font_color",Color("cbbdbd"))
	node.add_theme_color_override("font_hover_color",Color("e7d6d3"))
	node.add_theme_color_override("font_disabled_color",Color("74676f"))
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
static func picture(parent: Node, kind: String, at: Vector2, extent: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(kind)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.position = at
	node.size = extent
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
static func info(parent: Node, camp: Control, heading: String, message: String) -> Button:
	var node := Button.new()
	node.text = "i"
	node.custom_minimum_size = Vector2(38,38)
	node.add_theme_font_size_override("font_size",20)
	node.tooltip_text = heading
	dress(node)
	node.pressed.connect(func(): help(camp,heading,message))
	parent.add_child(node)
	return node
static func help(camp: Control, heading: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = heading
	dialog.dialog_text = message
	dialog.dialog_autowrap = true
	dialog.ok_button_text = "知道了"
	dialog.add_theme_font_override("font",load("res://assets/NotoSansSC.ttf"))
	dialog.add_theme_font_size_override("font_size",18)
	dialog.add_theme_color_override("font_color",Color("eee5e1"))
	dialog.add_theme_stylebox_override("panel",style("modal",64))
	dialog.get_label().add_theme_font_override("font",load("res://assets/NotoSansSC.ttf"))
	dialog.get_label().add_theme_font_size_override("font_size",17)
	dialog.get_label().add_theme_color_override("font_color",Color("eee5e1"))
	dialog.get_ok_button().custom_minimum_size = Vector2(130,44)
	dress(dialog.get_ok_button())
	var blocked: bool = camp.input_blocked
	camp.input_blocked = true
	camp.site.hero_walking = false
	camp.add_child(dialog)
	var reference: WeakRef = weakref(dialog)
	var hide_on_exit := func():
		var live: AcceptDialog = reference.get_ref()
		if live and not camp.visible: live.hide()
	camp.visibility_changed.connect(hide_on_exit)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			camp.input_blocked = blocked and camp.visible
			if camp.visibility_changed.is_connected(hide_on_exit): camp.visibility_changed.disconnect(hide_on_exit)
			dialog.queue_free())
	dialog.popup_centered(Vector2i(570,420))

