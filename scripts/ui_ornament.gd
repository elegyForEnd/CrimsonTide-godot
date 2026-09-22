class_name UIOrnament
extends Control

var mode := "line"
var accent := Color("c6a28c")
var tick := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	if mode in ["title","seal"]:
		tick+=dt
		queue_redraw()

func diamond(p: Vector2,r: float,c: Color) -> void:
	draw_polyline(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,0),p+Vector2(0,r),p+Vector2(-r,0),p+Vector2(0,-r)]),c,1,true)

func _draw() -> void:
	if mode=="line":
		var mid := size/2
		draw_polyline_colors(PackedVector2Array([Vector2(0,mid.y),mid,Vector2(size.x,mid.y)]),PackedColorArray([Color(accent,0),Color(accent,0.7),Color(accent,0)]),1,true)
		diamond(mid,4,accent)
	elif mode=="rail":
		draw_line(Vector2(20,0),Vector2(20,size.y),Color(accent,0.3),1)
		diamond(Vector2(20,0),4,Color(accent,0.5))
		diamond(Vector2(20,size.y),4,Color(accent,0.5))
	elif mode=="frame":
		var a := 16.0
		for p in [Vector2(a,a),Vector2(size.x-a,a),Vector2(a,size.y-a),size-Vector2(a,a)]:
			var sx := 1.0 if p.x<size.x/2 else -1.0
			var sy := 1.0 if p.y<size.y/2 else -1.0
			draw_line(p+Vector2(sx*45,0),p,Color(accent,0.7),1,true)
			draw_line(p,p+Vector2(0,sy*30),Color(accent,0.7),1,true)
			diamond(p,4,accent)
		for y in [8.0,size.y-8]:
			draw_line(Vector2(60,y),Vector2(size.x-60,y),Color(accent,0.2),1)
	elif mode=="seal":
		var mid := size/2
		var r := minf(size.x,size.y)*0.46
		for rr in [r,r*0.89,r*0.67]:
			draw_arc(mid,rr,0,TAU,120,Color(accent,0.12),1,true)
		for i in 12:
			var angle := i*TAU/12+tick*0.02
			var v := Vector2.from_angle(angle)
			draw_line(mid+v*r*0.7,mid+v*r*0.97,Color(accent,0.12),1,true)
			diamond(mid+v*r,5,Color(accent,0.35))
		draw_line(mid-Vector2(0,r*1.12),mid+Vector2(0,r*1.12),Color(accent,0.14),1)
	elif mode=="title":
		for i in 48:
			var p := Vector2(fposmod(i*173.7+sin(tick*0.1+i)*22,size.x),fposmod(i*87.3-tick*(7+i%7),size.y))
			var alpha := 0.15+0.2*sin(i+tick*0.7)
			draw_circle(p,1.0+(i%3)*0.4,Color(0.93,0.45,0.42,alpha))
		# Subtle cinematic top and bottom fades.
		for i in 45:
			draw_rect(Rect2(0,size.y-2*(i+1),size.x,2),Color(0.025,0.012,0.026,0.6*pow(1-float(i)/45,2)))
