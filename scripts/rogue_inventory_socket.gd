extends Control
## Cut-metal socket with a quality aura; the item itself remains the focal point.
var tone := Color("857253")
var occupied := false
var hovered := false
var heat := 0.0
var icon: TextureRect

func _ready() -> void:
	mouse_entered.connect(func(): hovered=true)
	mouse_exited.connect(func(): hovered=false)

func _process(dt: float) -> void:
	heat=move_toward(heat,1.0 if hovered else 0.0,dt*7)
	if is_instance_valid(icon):
		icon.scale=Vector2.ONE*(1.0+heat*0.07)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var cut := 10.0
	var points := PackedVector2Array([Vector2(cut,0),Vector2(w-cut,0),Vector2(w,cut),Vector2(w,h-cut),Vector2(w-cut,h),Vector2(cut,h),Vector2(0,h-cut),Vector2(0,cut),Vector2(cut,0)])
	draw_colored_polygon(points,Color(0.035,0.028,0.036,0.86))
	if occupied:
		for i in range(12,0,-1):
			draw_circle(size*0.5,w*0.038*i,Color(tone,0.012+heat*0.004))
	draw_polyline(points,Color(tone,0.46+heat*0.5),1.0,true)
	for corner in [Vector2(5,5),Vector2(w-5,5),Vector2(5,h-5),Vector2(w-5,h-5)]:
		var direction: Vector2 = (size*0.5-corner).sign()
		draw_line(corner+Vector2(direction.x*8,0),corner+Vector2(direction.x*19,0),Color(tone,0.65),1,true)
		draw_line(corner+Vector2(0,direction.y*8),corner+Vector2(0,direction.y*19),Color(tone,0.65),1,true)
	if occupied:
		var center := Vector2(w*0.5,h-5)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-4),center+Vector2(5,0),center+Vector2(0,4),center+Vector2(-5,0)]),tone)
	else:
		draw_arc(size*0.5,12,0,TAU,32,Color(tone,0.12),1,true)
		draw_line(size*0.5-Vector2(5,0),size*0.5+Vector2(5,0),Color(tone,0.25),1,true)

