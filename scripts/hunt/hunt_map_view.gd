extends Control
## 血潮猎场 · 地区图
##
## 纯绘制 + 点击命中。数据全部来自 HuntData.AREAS / HuntRun，不自己记状态。
## 当前地区高亮，相邻可走，未解锁地区变暗；点相邻地区发出 picked。

signal picked(id: String)

const Data = preload("res://scripts/hunt/hunt_data.gd")
const Art = preload("res://scripts/hunt/hunt_art.gd")

var run
var font: Font
var hover := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	font = ThemeDB.fallback_font
	var face := FontVariation.new()
	face.base_font = load("res://assets/NotoSansSC.ttf")
	if face.base_font:
		font = face
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): hover = ""; queue_redraw())

func set_run(value) -> void:
	run = value
	queue_redraw()

## 羊皮纸地图按 16:9 原比例放进控件；节点坐标是图上的归一化位置，
## 所以 _at() 必须用「图实际占的那块矩形」，不能用整个控件。
func _frame_rect() -> Rect2:
	var tex := Art.map_texture()
	if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
		return Rect2(Vector2.ZERO, size)
	var tex_aspect := float(tex.get_width()) / float(tex.get_height())
	var box_aspect := size.x / maxf(1.0, size.y)
	if tex_aspect >= box_aspect:
		var h := size.x / tex_aspect
		return Rect2(0.0, (size.y - h) * 0.5, size.x, h)
	var w := size.y * tex_aspect
	return Rect2((size.x - w) * 0.5, 0.0, w, size.y)

func _at(id: String) -> Vector2:
	var data: Dictionary = Data.area(id)
	var norm: Vector2 = data.get("map_at", Vector2(0.5, 0.5))
	var frame := _frame_rect()
	return frame.position + norm * frame.size

func _hit(at: Vector2) -> String:
	var best := ""
	var distance := 46.0
	for id in Data.AREAS:
		var d := at.distance_to(_at(id))
		if d < distance:
			distance = d
			best = id
	return best

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next := _hit(event.position)
		if next != hover:
			hover = next
			queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _hit(event.position)
		if not id.is_empty():
			picked.emit(id)
			accept_event()

func _draw() -> void:
	if run == null:
		return
	var frame := _frame_rect()
	var tex := Art.map_texture()
	if tex != null:
		draw_texture_rect(tex, frame, false, Color(0.94, 0.91, 0.87))
		draw_rect(frame, Color("6f5c55"), false, 2.0)
	else:
		draw_rect(frame, Color(0.025, 0.03, 0.045, 0.96), true)
		draw_rect(frame, Color("6f5c55"), false, 2.0)
		# Faint contour lines, to read as a hand-drawn field map rather than a list.
		for i in 9:
			var y := frame.position.y + 30.0 + i * (frame.size.y - 60.0) / 8.0
			draw_line(Vector2(frame.position.x + 24, y),
				Vector2(frame.end.x - 24, y + sin(i * 1.7) * 18.0), Color(0.35, 0.30, 0.28, 0.10), 1.0)
	var current := str(run.area_id)
	var neighbors: Array = run.area().get("neighbors", [])
	for id in Data.AREAS:
		var a: Dictionary = Data.AREAS[id]
		for other in a.get("neighbors", []):
			if str(other) <= str(id):
				continue
			var p1 := _at(str(id))
			var p2 := _at(str(other))
			var lit := str(id) == current or str(other) == current
			var ink := Color(0.86, 0.70, 0.45, 0.60 if lit else 0.26) if tex != null else Color(0.55, 0.47, 0.40, 0.55 if lit else 0.22)
			draw_line(p1, p2, ink, 2.0 if lit else 1.0, true)
	for id in Data.AREAS:
		var a: Dictionary = Data.AREAS[id]
		var at := _at(str(id))
		var locked := int(a.get("unlock_day", 1)) > int(run.day)
		var is_current := str(id) == current
		var can_go := str(id) in neighbors and not locked
		var colour := Color("cbb087")
		if locked:
			colour = Color(0.38, 0.35, 0.34)
		elif is_current:
			colour = Color("f0c98a")
		elif can_go:
			colour = Color("b7d4c2")
		var radius := 39.0 if is_current else 31.0
		if str(id) == hover:
			radius += 4.0
		if is_current:
			draw_circle(at, radius + 10.0, Color(colour, 0.10))
			draw_arc(at, radius + 8.0, 0, TAU, 40, Color(colour, 0.50), 2.0, true)
		draw_circle(at, radius, Color(0.015, 0.015, 0.022, 0.58) if tex != null else Color(0.08, 0.07, 0.09, 0.95))
		draw_arc(at, radius, 0, TAU, 36, colour, 2.0, true)
		var label := str(a.get("short", a.get("name", id)))
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_rect(Rect2(at + Vector2(-width * 0.5 - 6, radius + 6), Vector2(width + 12, 23)),
			Color(0.008, 0.01, 0.016, 0.62), true)
		draw_string(font, at + Vector2(-width * 0.5, radius + 25), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, colour)
		if locked:
			draw_string(font, at + Vector2(-30, 6), "第%d天" % int(a.get("unlock_day", 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.50, 0.48))
		elif is_current:
			draw_string(font, at + Vector2(-18, 6), "现在", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f0c98a"))
	# Legend / current state.
	draw_rect(Rect2(10, size.y - 37, size.x - 20, 29), Color(0.008, 0.01, 0.016, 0.62), true)
	draw_string(font, Vector2(26, size.y - 18), "点击相邻地区移动 · 每次 6 秒 · 消耗 3 体力",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.80, 0.73, 0.64))
