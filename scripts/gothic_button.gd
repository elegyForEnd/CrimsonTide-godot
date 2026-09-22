class_name GothicButton
extends Button

var accent := Color("c2a187")
var primary := false
var menu := false
var selected := false
var heat := 0.0
var item_kind := ""
var slot := false
var serif: Font
var item_texture: Texture2D

func _ready() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	set_process(true)

func _process(dt: float) -> void:
	if not item_kind.is_empty() and not item_texture:
		item_texture=load("res://assets/icons/"+item_kind+".svg")
	heat=move_toward(heat,1.0 if (is_hovered() or has_focus() or selected) and not disabled else 0.0,dt*7)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var glow := maxf(heat,0.52 if primary else 0.0)
	var ink := Color("f5e8de").lerp(Color.WHITE,heat)
	if disabled:
		ink=Color("77717a")
	if slot:
		draw_style_box(_slot_style(),Rect2(Vector2.ZERO,size))
		if not item_kind.is_empty():
			var edge := minf(w-14,h-27)
			if item_texture:
				draw_texture_rect(item_texture,Rect2(Vector2((w-edge)/2,(h-edge)/2-6),Vector2.ONE*edge),false)
			var face := get_theme_font("font")
			var tw := face.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
			draw_string(face,Vector2((w-tw)/2,h-8),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
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
