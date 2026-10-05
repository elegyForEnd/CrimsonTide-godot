extends ProgressBar
var fine := false
func _ready() -> void:
	show_percentage = false
	var clear := StyleBoxEmpty.new()
	add_theme_stylebox_override("fill",clear)
	add_theme_stylebox_override("background",clear)
	value_changed.connect(func(_value): queue_redraw())
func _draw() -> void:
	var left := 0.35 if fine else 0.48
	var right := 0.9 if fine else 0.82
	draw_style_box(make_style(Color("0e1c1e")),Rect2(Vector2.ZERO,size))
	draw_rect(Rect2(size.x*left,3,size.x*(right-left),size.y-6),Color("39745a"))
	draw_line(Vector2(size.x*0.65,3),Vector2(size.x*0.65,size.y-3),Color("9ee4ad"),2)
	for i in 11:
		var x := size.x*i/10.0
		draw_line(Vector2(x,size.y-6),Vector2(x,size.y),Color("7b9a8d"),1)
	var cursor := clampf(value/100.0*size.x,3,size.x-3)
	draw_line(Vector2(cursor,0),Vector2(cursor,size.y),Color("ffe0a0"),4,true)
	draw_circle(Vector2(cursor,size.y*0.5),5,Color("ffe9bc"))
func make_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
