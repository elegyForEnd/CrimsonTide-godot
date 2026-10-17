extends Control
## 血潮猎场 · 地区图
##
## 纯绘制 + 点击命中。数据全部来自 HuntData.AREAS / HuntRun，不自己记状态。
## 当前地区高亮，相邻可走，未解锁地区变暗；点相邻地区发出 picked。

signal picked(id: String)

const Data = preload("res://scripts/hunt/hunt_data.gd")

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

func _at(id: String) -> Vector2:
	var data: Dictionary = Data.area(id)
	var norm: Vector2 = data.get("map_at", Vector2(0.5, 0.5))
	return Vector2(norm.x * (size.x - 90) + 45, norm.y * (size.y - 90) + 45)

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
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(panel, Color(0.025, 0.03, 0.045, 0.96), true)
	draw_rect(panel, Color("6f5c55"), false, 2.0)
	# Faint contour lines, to read as a hand-drawn field map rather than a list.
	for i in 9:
		var y := 30.0 + i * (size.y - 60.0) / 8.0
		draw_line(Vector2(24, y), Vector2(size.x - 24, y + sin(i * 1.7) * 18.0), Color(0.35, 0.30, 0.28, 0.10), 1.0)
	var current := str(run.area_id)
	var neighbors: Array = run.area().get("neighbors", [])
	for id in Data.AREAS:
		var a: Dictionary = Data.AREAS[id]
		for other in a.get("neighbors", []):
			if str(other) <= str(id):
				continue
			var p1 := _at(str(id))
			var p2 := _at(str(other))
			var unlocked := int(Data.area(str(other)).get("unlock_day", 1)) <= int(run.day)
			var lit := str(id) == current or str(other) == current
			draw_line(p1, p2, Color(0.55, 0.47, 0.40, 0.55 if lit else 0.22), 2.0 if lit else 1.0, true)
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
		draw_circle(at, radius, Color(0.08, 0.07, 0.09, 0.95))
		draw_arc(at, radius, 0, TAU, 36, colour, 2.0, true)
		var label := str(a.get("short", a.get("name", id)))
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, at + Vector2(-width * 0.5, radius + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, colour)
		if locked:
			draw_string(font, at + Vector2(-30, 6), "第%d天" % int(a.get("unlock_day", 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.50, 0.48))
		elif is_current:
			draw_string(font, at + Vector2(-18, 6), "现在", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f0c98a"))
	# Legend / current state.
	draw_string(font, Vector2(26, size.y - 26), "点击相邻地区移动 · 每次 6 秒 · 消耗 3 体力", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.60, 0.55))
