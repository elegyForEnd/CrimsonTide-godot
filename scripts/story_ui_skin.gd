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
static func button(node: Button, selected: bool = false, dangerous: bool = false) -> void:
	node.add_theme_stylebox_override("normal",frame(8 if dangerous else 3 if selected else 2))
	node.add_theme_stylebox_override("hover",frame(3))
	node.add_theme_stylebox_override("pressed",frame(3))
	var disabled: StyleBoxTexture=frame(2).duplicate(); disabled.modulate_color=Color(0.55,0.55,0.55,0.8)
	node.add_theme_stylebox_override("disabled",disabled)
	node.add_theme_color_override("font_color",Color("efe0c2"))
	node.add_theme_color_override("font_hover_color",Color("fff0cf"))
	node.add_theme_color_override("font_disabled_color",Color("747477"))
	node.add_theme_font_size_override("font_size",17)
static func theme_controls(theme: Theme) -> void:
	theme.set_stylebox("panel","TooltipPanel",frame(5))
	theme.set_color("font_color","TooltipLabel",Color("f1e2c9"))
	theme.set_font_size("font_size","TooltipLabel",17)
	theme.set_stylebox("panel","AcceptDialog",frame(5))
	theme.set_stylebox("normal","Button",frame(2)); theme.set_stylebox("hover","Button",frame(3)); theme.set_stylebox("pressed","Button",frame(3))
	theme.set_stylebox("scroll","VScrollBar",frame(0)); theme.set_stylebox("grabber","VScrollBar",frame(2)); theme.set_stylebox("grabber_highlight","VScrollBar",frame(3))
