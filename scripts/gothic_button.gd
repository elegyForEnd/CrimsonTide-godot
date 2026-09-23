class_name GothicButton
extends Button

var accent := Color("c2a187")
var primary := false
var menu := false
var selected := false
var heat := 0.0
var slot := false
var sealed_slot := false
var serif: Font
var item_texture: Texture2D
# A slot must never be resized by its own caption: a button grows to fit its text
# unless clip_text is on, and a long name like "金色 守夜护甲" was widening a 1x2
# cell until the icon and the label spilled over the neighbouring slots.
var rotated := false
# Optional shorter caption ("守夜护甲" instead of "红色 守夜护甲") used when the
# slot is too narrow for the full name.
var short_caption := ""
# Assigning the kind loads the art immediately. Loading it lazily in _process
# meant every rebuilt grid (a rotation, a drag, a stack change) drew one frame of
# empty cells, which read as the item icon vanishing.
var item_kind := "":
	set(value):
		item_kind=value
		item_texture=null if value.is_empty() else TideUIArt.icon(value)
		queue_redraw()

func _init() -> void:
	# A slot has to keep exactly the size it is given, and a Control clamps
	# set_size() to its minimum size. Both the default Button theme (content
	# margins + text width) and a long item name would inflate the cell, which is
	# what made "红色 守夜护甲" draw over its neighbours. Doing this in _init
	# matters: callers assign text and size before the node ever enters the tree,
	# so setting it in _ready would already be too late.
	clip_text=true
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())

func _ready() -> void:
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	set_process(true)

func _process(dt: float) -> void:
	if not item_kind.is_empty() and not item_texture:
		item_texture=TideUIArt.icon(item_kind)
	heat=move_toward(heat,1.0 if (is_hovered() or has_focus() or selected) and not disabled else 0.0,dt*7)
	queue_redraw()

# Names are cut to the cell and given an ellipsis instead of being drawn over the
# next cell; the full name lives in the tooltip and the details panel.
func fit_caption(face: Font, value: String, limit: float, font_size: int) -> String:
	if face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=limit:
		return value
	var shortened := value
	while shortened.length()>1 and face.get_string_size(shortened+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>limit:
		shortened=shortened.substr(0,shortened.length()-1)
	return shortened+"…"

func _draw() -> void:
	var w := size.x
	var h := size.y
	var glow := maxf(heat,0.52 if primary else 0.0)
	var ink := Color("f5e8de").lerp(Color.WHITE,heat)
	if disabled:
		ink=Color("77717a")
	if slot:
		draw_style_box(_slot_style(),Rect2(Vector2.ZERO,size))
		if sealed_slot:
			draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color("555b66",0.72),true)
			var face := get_theme_font("font")
			draw_string(face,Vector2(w/2.0-5.0,h/2.0+7.0),"?",HORIZONTAL_ALIGNMENT_LEFT,w,22,Color("b9bec7"))
			return
		if not item_kind.is_empty():
			# The icon owns the cell; the name rides a translucent strip along the
			# bottom so it never covers the art or the neighbouring slot.
			var edge := minf(w-6.0,h-6.0)
			if item_texture and edge>0.0:
				if rotated:
					# The art turns with the item: a 1x2 piece laid on its side has to
					# look laid on its side, not like the same upright picture.
					draw_set_transform(Vector2(w/2.0,h/2.0),PI*0.5,Vector2.ONE)
					draw_texture_rect(item_texture,Rect2(Vector2.ONE*(-edge/2.0),Vector2.ONE*edge),false)
					draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
				else:
					draw_texture_rect(item_texture,Rect2(Vector2((w-edge)/2.0,(h-edge)/2.0),Vector2.ONE*edge),false)
			if h>=30.0 and not text.is_empty():
				var face := get_theme_font("font")
				# Narrow cells drop the quality prefix and shrink the type instead of
				# showing "红色 …"; the full name is on the tooltip and the panel.
				var font_size := 10 if w>=58.0 else 9
				var caption := text
				if not short_caption.is_empty() and face.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>w-5.0:
					caption=short_caption
				draw_rect(Rect2(0,h-13.0,w,13.0),Color(0.035,0.025,0.04,0.78),true)
				draw_string(face,Vector2(0,h-3.0),fit_caption(face,caption,w-5.0,font_size),HORIZONTAL_ALIGNMENT_CENTER,w,font_size,ink)
		return
	# Feathered crimson illumination, no opaque rectangular button body.
	if glow>0:
		for i in 64:
			var x := float(i)/64
			var alpha := sin(minf(1,x*9)*PI/2)*pow(1-x,1.35)*glow*0.72
			draw_rect(Rect2(x*w,4,w/64,h-8),Color(0.55,0.08,0.16,alpha))
		var colors := PackedColorArray([Color(accent,0),Color(accent,glow*0.6),Color(accent,0)])
		for y in [4.0,h-4]:
			draw_polyline_colors(PackedVector2Array([Vector2(0,y),Vector2(w*0.3,y),Vector2(w,y)]),colors,1,true)
	var center := Vector2(20,h/2)
	if menu or primary or heat>0.03:
		var r := 5.0+heat*2.0
		var points := PackedVector2Array([center+Vector2(0,-r),center+Vector2(r,0),center+Vector2(0,r),center+Vector2(-r,0),center+Vector2(0,-r)])
		draw_polyline(points,Color(accent,0.3+glow*0.7),1.3,true)
		if glow>0.3:
			draw_circle(center,2,Color(ink,glow))
	var font: Font=serif if serif else get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var tw := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var left := 51.0+heat*5 if menu else (w-tw)/2+7
	draw_string(font,Vector2(left+1,(h+font.get_ascent(font_size)-font.get_descent(font_size))/2+2),text,HORIZONTAL_ALIGNMENT_LEFT,w-left,font_size,Color(0,0,0,0.8))
	draw_string(font,Vector2(left,(h+font.get_ascent(font_size)-font.get_descent(font_size))/2),text,HORIZONTAL_ALIGNMENT_LEFT,w-left,font_size,ink if (primary or heat>0) else Color("c0b5b5"))
	if not menu and not primary:
		draw_line(Vector2(22,h-3),Vector2(w-22,h-3),Color(accent,0.12+heat*0.4),1)

func _slot_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=Color(0.06,0.05,0.08,0.7) if item_kind.is_empty() else Color(accent.darkened(0.85),0.9)
	s.border_color=Color(accent,0.8 if selected or heat>0.2 else 0.25)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	return s
