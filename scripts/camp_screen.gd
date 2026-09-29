extends Control
## 出征前的初始营地界面：一座可以走动的 3D 雷霆要塞。
##
## The screen owns the camp map (`scripts/camp_site.gd`), the on-station prompts
## and the bottom bar. It never launches a raid itself: it raises a signal and
## `main.gd` decides, so the camp cannot fork the online or single-player flow.
## Pressing `F` falls back to the classic整备 panel for players who would rather
## read menus than walk.

signal station_requested(id: String)
signal launch_requested
signal exit_requested
signal codex_requested

const Site = preload("res://scripts/camp_site.gd")

const BG := Color("070b12")
const PANEL := Color("0e1420")
const INK := Color("f2f6ff")
const MUTED := Color("a7b3c6")
const ARC := Color("7fd4ff")
const GOLD := Color("c8b184")
const RED := Color("d3556b")
const BOUNDS := Rect2(180, 180, 5240, 5240)

var site: Node3D
var hud: Control
var marker_layer: Control
var flash: ColorRect
var title_font: Font
var face_font: Font
var session: TideSession
var profile: Profile

var selected := 0
var ready_local := false
var station_markers: Dictionary = {}
var hero_marker: Control
var prompt: Label
var toast: Label
var clock := 0.0

var strikes: Label
var charges: Label
var roster: VBoxContainer
var loadout: Label
var launch_button: Button
var warp_charge := 0.0
var warp_target := ""
var toast_tween: Tween
var squad_count: Label
var supply_status: Label
var extra_meds := 0
var input_blocked := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ensure_actions()
	var serif := FontVariation.new()
	serif.base_font = load("res://assets/NotoSerifSC.ttf")
	serif.variation_embolden = 0.5
	title_font = serif
	var face := FontVariation.new()
	face.base_font = load("res://assets/NotoSansSC.ttf")
	face.variation_opentype = {"wght": 500.0}
	face_font = face

	site = Site.new()
	site.name = "Thunderhold"
	add_child(site)
	site.build()

	marker_layer = Control.new()
	marker_layer.name = "Markers"
	marker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marker_layer)

	hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	flash = ColorRect.new()
	flash.name = "Flash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.62, 0.80, 1.0, 0.0), Color(0.80, 0.90, 1.0, 0.30)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.42)
	texture.fill_to = Vector2(1.0, 0.5)
	var flash_art := TextureRect.new()
	flash_art.texture = texture
	flash_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flash_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.add_child(flash_art)
	add_child(flash)

	_build_hud()
	_build_markers()
	_build_vignette()


## A storm-locked frame: dark, cool edges over the 3D map, drawn under the HUD.
func _build_vignette() -> void:
	var copy := BackBufferCopy.new()
	copy.name = "CampBackBuffer"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	move_child(copy, marker_layer.get_index())
	var rect := ColorRect.new()
	rect.name = "Vignette"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = preload("res://resources/camp_vignette.gdshader")
	rect.material = material
	add_child(rect)
	move_child(rect, marker_layer.get_index())


func set_context(session_value: TideSession, profile_value: Profile) -> void:
	session = session_value
	profile = profile_value
	selected = int(profile.data.hero) if profile else 0
	if site:
		site.hero = selected


func set_active(value: bool) -> void:
	visible = value
	site.visible = value
	site.set_process(value)
	warp_charge = 0.0
	warp_target = ""
	site.hero_walking = false
	for player in site.audio_root.get_children():
		if player is AudioStreamPlayer:
			player.stream_paused = not value
	# Only one 3D camera may be current: entering the camp claims it, leaving it
	# releases it so the raid's own presentation camera takes over again.
	if value and site.camp_camera:
		site.camp_camera.make_current()


## The camp is reachable from the title screen and from preview captures, so it
## binds its own movement actions when `main.gd` has not already done it.
func ensure_actions() -> void:
	var keys := {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "sprint": KEY_SHIFT,
		"interact": KEY_E}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var binding := InputEventKey.new()
		binding.physical_keycode = keys[action]
		InputMap.action_add_event(action, binding)


func held(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


# --------------------------------------------------------------------- layout

func _struck(text: String, at: Vector2, size: int, color: Color = INK,
		box: Vector2 = Vector2(420, 34), align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.size = box
	node.clip_text = true
	node.horizontal_alignment = align
	node.add_theme_font_override("font", title_font if size >= 26 else face_font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0.0, 0.01, 0.03, 0.98))
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(node)
	return node


func _panel(at: Vector2, size: Vector2, color: Color = PANEL) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.45, 0.58, 0.72, 0.35)
	style.set_border_width_all(1)
	style.border_width_left = 2
	style.border_color = Color(0.45, 0.62, 0.78, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	return panel


func _rule(at: Vector2, size: Vector2, color: Color = GOLD) -> void:
	var line := ColorRect.new()
	line.color = Color(color, 0.55)
	line.position = at
	line.size = size
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(line)


func _action(text: String, at: Vector2, size: Vector2, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = at
	node.size = size
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.10, 0.16, 0.92) if primary else Color(0.05, 0.07, 0.11, 0.82)
	normal.border_color = ARC if primary else Color(0.42, 0.5, 0.62, 0.55)
	normal.set_border_width_all(1)
	normal.border_width_bottom = 2
	normal.border_width_top = 2
	node.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.10, 0.20, 0.30, 0.95) if primary else Color(0.10, 0.14, 0.20, 0.9)
	hover.border_color = Color("bfe9ff")
	node.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.16, 0.30, 0.42, 0.98)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_font_override("font", title_font)
	node.add_theme_font_size_override("font_size", 22 if primary else 18)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.pressed.connect(callback)
	hud.add_child(node)
	return node


func _build_hud() -> void:
	# Top-left: where you are and what the storm is doing.
	_panel(Vector2(30, 26), Vector2(430, 132), Color(0.02, 0.035, 0.065, 0.93))
	_struck("晨钟城 · 雷霆要塞", Vector2(50, 36), 30)
	_struck("T H E   T H U N D E R H O L D", Vector2(52, 76), 12, ARC)
	_rule(Vector2(52, 100), Vector2(386, 1), ARC)
	strikes = _struck("", Vector2(52, 108), 14, MUTED)
	charges = _struck("", Vector2(52, 132), 14, MUTED)

	# Top-right: the storm's own readout, because the storm is the landmark here.
	_panel(Vector2(1120, 26), Vector2(290, 132), Color(0.02, 0.035, 0.065, 0.93))
	_struck("雷暴强度", Vector2(1140, 36), 14, MUTED)
	_struck("THUNDERHEAD  LIVE", Vector2(1140, 60), 11, ARC)
	_rule(Vector2(1140, 84), Vector2(250, 1), ARC)
	_struck("每 0.4–4.6 秒落雷", Vector2(1140, 92), 13, MUTED)
	_struck("雷光先到，雷声后到", Vector2(1140, 116), 13, MUTED)

	# Right column: the squad.
	_panel(Vector2(1120, 176), Vector2(290, 236), Color(0.02, 0.035, 0.065, 0.9))
	_struck("远征小队", Vector2(1140, 186), 22)
	squad_count = _struck("", Vector2(1142, 214), 11, ARC)
	_rule(Vector2(1140, 234), Vector2(250, 1))
	roster = VBoxContainer.new()
	roster.position = Vector2(1140, 244)
	roster.size = Vector2(252, 150)
	roster.add_theme_constant_override("separation", 4)
	roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(roster)
	_panel(Vector2(30, 176), Vector2(260, 352), Color(0.02, 0.035, 0.065, 0.9))
	_struck("营地设施", Vector2(50, 188), 22)
	_struck("点击前往 · 抵达后按 E 使用", Vector2(50, 224), 13, MUTED)
	for i in site.stations.size():
		var station: Dictionary = site.stations[i]
		_action("%02d  %s" % [i + 1, station.name], Vector2(48, 262 + i * 49),
			Vector2(224, 41), func(): warp_to(str(station.id)); say("已抵达 " + str(station.name)))
	supply_status = _struck("急救针 ×1 / 3", Vector2(1140, 430), 16, GOLD, Vector2(260, 30))
	_action("打开整备  [F]", Vector2(1120, 474), Vector2(290, 44),
		func(): station_requested.emit("table"))

	# Bottom bar: hero identity, controls and the departure pair.
	_panel(Vector2(30, 800), Vector2(1380, 76), Color(0.015, 0.028, 0.05, 0.95))
	_rule(Vector2(30, 800), Vector2(1380, 2), ARC)
	_struck("整备 · 出征", Vector2(50, 810), 26)
	loadout = _struck("", Vector2(246, 818), 15, MUTED, Vector2(620, 24))
	_struck("WASD 走动 · SHIFT 疾行 · 右键指向设施蓄力 · E 交互 · F 整备 · TAB 手册", Vector2(246, 846),
		13, MUTED, Vector2(824, 24), HORIZONTAL_ALIGNMENT_LEFT)
	_action("← 离开营地", Vector2(1090, 814), Vector2(150, 46), func(): exit_requested.emit())
	_action("晨钟手册", Vector2(1250, 814), Vector2(150, 46), func(): codex_requested.emit())
	launch_button = _action("全队出发    →", Vector2(880, 736), Vector2(530, 58),
		func(): launch_requested.emit(), true)
	_struck("踏出闸门，血潮开始计时", Vector2(880, 700), 14, MUTED, Vector2(530, 22),
		HORIZONTAL_ALIGNMENT_CENTER)

	toast = _struck("", Vector2(470, 616), 18, ARC, Vector2(500, 30), HORIZONTAL_ALIGNMENT_CENTER)
	prompt = _struck("", Vector2(470, 652), 20, INK, Vector2(500, 30), HORIZONTAL_ALIGNMENT_CENTER)
	_struck("（提示：走近发光站点，按 E 使用）", Vector2(470, 682), 13, MUTED, Vector2(500, 22),
		HORIZONTAL_ALIGNMENT_CENTER)
	refresh_roster()
	update_static()


func _build_markers() -> void:
	for station in site.stations:
		var marker := StationMarker.new()
		marker.station = station
		marker.color = station.tint
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker_layer.add_child(marker)
		station_markers[str(station.id)] = marker
	hero_marker = Control.new()
	hero_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_layer.add_child(hero_marker)


func refresh_roster() -> void:
	site.squad.clear()
	for child in roster.get_children():
		child.queue_free()
	var rows: Array = []
	if session and not session.players.is_empty():
		for player in session.players.values():
			if int(player.id) != session.my_id():
				site.squad.append(player)
			rows.append({"name": str(player.name), "hero": int(player.hero),
				"tag": "房主" if player.id == session.leader_id else "队友",
				"state": "就绪" if player.get("ready", false) else "整备"})
	else:
		rows.append({"name": "守夜人", "hero": selected, "tag": "单人", "state": "整备"})
	squad_count.text = "WATCHERS  /  %02d" % rows.size()
	if session and not session.is_leader():
		launch_button.text = "取消准备" if session.players.get(session.my_id(), {}).get("ready", false) else "准备出发    →"
	else:
		launch_button.text = "全队出发    →"
	for row in rows:
		var line := Label.new()
		line.text = "%s  ·  %s  ·  %s" % [row.tag, row.name, row.state]
		line.clip_text = true
		line.add_theme_font_override("font", face_font)
		line.add_theme_font_size_override("font_size", 15)
		line.add_theme_color_override("font_color", INK if row.state == "就绪" else MUTED)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		roster.add_child(line)
	for i in range(rows.size(), 4):
		var empty := Label.new()
		empty.text = "◇  空席"
		empty.add_theme_font_override("font", face_font)
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.42, 0.48, 0.6))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		roster.add_child(empty)


func update_static() -> void:
	if profile:
		selected = int(profile.data.hero)
		site.hero = selected
		var hero: Dictionary = Catalog.HEROES[clampi(selected, 0, Catalog.HEROES.size() - 1)]
		loadout.text = "%s  ·  %s    Lv.%02d    ◈ %d" % [hero.name, hero.title,
			profile.level(), profile.data.coins]
		strikes.text = "本次守夜落雷 %d 次    营地岗哨 %d 处" % [int(site.storm_state().strikes), site.stations.size()]
		charges.text = "已选角色 %s    %s" % [hero.name, String(hero.desc).left(26)]
	supply_status.text = "急救针 ×%d / 3  ·  补给 25 银币" % (1 + extra_meds)


# ---------------------------------------------------------------------- input

func _process(dt: float) -> void:
	if not visible:
		return
	if input_blocked:
		warp_charge = 0.0
		warp_target = ""
		site.hero_walking = false
		return
	clock += dt
	var speed := 420.0
	var stick := Vector2.ZERO
	if held("right"):
		stick.x += 1.0
	if held("left"):
		stick.x -= 1.0
	if held("down"):
		stick.y += 1.0
	if held("up"):
		stick.y -= 1.0
	if held("sprint"):
		speed = 700.0
	if stick.length() > 0.01:
		stick = stick.normalized()
	drive_hero(stick, dt * (speed / 420.0))

	# Hold the right mouse button to charge a jump straight to a station.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		warp_charge = minf(1.0, warp_charge + dt * 1.4)
		var target: Dictionary = pointed_station(get_global_mouse_position())
		if target.is_empty() or str(target.id) != warp_target:
			warp_charge = 0.0
		warp_target = "" if target.is_empty() else str(target.id)
		if not target.is_empty():
			warp_target = str(target.id)
			prompt.text = "蓄力直取  %s   %d%%" % [target.name, int(warp_charge * 100)]
	elif warp_charge > 0.0:
		var jump := warp_target if warp_charge >= 1.0 else ""
		warp_charge = 0.0
		warp_target = ""
		var station: Dictionary = site.station_by_id(jump)
		if not station.is_empty():
			warp_to(jump)
			say("已抵达 " + str(station.name))

	_update_markers()
	var state: Dictionary = site.storm_state()
	flash.color = Color(1, 1, 1, clampf(float(state.flash) * 0.10, 0.0, 0.24))
	strikes.text = "本次守夜落雷 %d 次    营地岗哨 %d 处" % [int(state.strikes), site.stations.size()]


## The single place the hero moves, so a test drives exactly the player's path.
func drive_hero(stick: Vector2, dt: float) -> void:
	var at: Vector2 = site.hero_position()
	if stick.length() > 0.01:
		var destination: Vector2 = (at + stick * 420.0 * dt).clamp(BOUNDS.position, BOUNDS.end)
		at = site.move_actor(at, destination - at)
		at.x = clampf(at.x, BOUNDS.position.x, BOUNDS.end.x)
		at.y = clampf(at.y, BOUNDS.position.y, BOUNDS.end.y)
		site.hero_walking = true
		if absf(stick.x) > 0.09:
			site.hero_facing = signf(stick.x)
	else:
		site.hero_walking = false
	site.hero_at = at


func nearest_station(at: Vector2, within: float) -> Dictionary:
	var best := {}
	var distance := INF
	for station in site.stations:
		var target: Vector2 = station.at + station.offset
		var d := at.distance_to(target)
		if d < within and d < distance:
			distance = d
			best = station
	return best


func pointed_station(at: Vector2) -> Dictionary:
	var best := {}
	var distance := 90.0
	for station in site.stations:
		var d: float = at.distance_to(site.project(station.at + station.offset))
		if d < distance:
			distance = d
			best = station
	return best


func _unhandled_input(event: InputEvent) -> void:
	if not visible or input_blocked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		# Space is the hard commitment: it only exists at the departure gate.
		if code == KEY_SPACE:
			var gate: Dictionary = site.station_at(site.hero_position())
			if not gate.is_empty() and str(gate.id) == "gate":
				launch_requested.emit()
			else:
				say("先走到出征闸门，再按 Space 出发。")
			get_viewport().set_input_as_handled()
			return
		match code:
			KEY_E, KEY_ENTER:
				interact()
			KEY_F:
				station_requested.emit("table")
			KEY_TAB:
				codex_requested.emit()
			KEY_ESCAPE:
				exit_requested.emit()
			_:
				return
		get_viewport().set_input_as_handled()


## Uses whichever station the player is standing in, and reports what happened.
func interact() -> Dictionary:
	var station: Dictionary = site.station_at(site.hero_position())
	if station.is_empty():
		say("附近没有可用设施，去发光的地标处。")
		return {}
	say("进入 " + str(station.name))
	station_requested.emit(str(station.action))
	return station


func say(text: String) -> void:
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast.text = text
	toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(1.6)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.7)


## Public so a preview or a test can pose the camp without moving a mouse.
func warp_to(id: String) -> void:
	var station: Dictionary = site.station_by_id(id)
	if station.is_empty():
		return
	site.hero_at = site.safe_position(station.at + station.offset + Vector2(0, 120))
	site.set_camera_focus(site.hero_at, true)


func _update_markers() -> void:
	var near: Dictionary = site.station_at(site.hero_position())
	for station in site.stations:
		var marker: Control = station_markers[str(station.id)]
		var active: bool = not near.is_empty() and str(near.id) == str(station.id)
		marker.position = site.project(station.at + station.offset) - marker.size / 2
		marker.set_active(active)
	hero_marker.position = site.project(site.hero_position()) - Vector2(26, 78)
	hero_marker.queue_redraw()
	if near.is_empty():
		if warp_charge <= 0.0:
			prompt.text = "从左侧选择设施，或走近站点按 E"
	else:
		if warp_charge <= 0.0:
			prompt.text = "[E]  %s   ·   %s" % [near.name, near.hint]


# ------------------------------------------------------------------- drawings

class StationMarker extends Control:
	var station: Dictionary = {}
	var color := Color.WHITE
	var active := false

	func _init() -> void:
		size = Vector2(132, 132)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_active(value: bool) -> void:
		if value == active:
			return
		active = value
		queue_redraw()

	func _draw() -> void:
		var centre := size / 2
		var pulse := 1.0 + (0.06 * sin(Time.get_ticks_msec() * 0.004) if active else 0.0)
		var radius := (40.0 if active else 30.0) * pulse
		draw_arc(centre, radius + 9, 0, TAU, 40, Color(color, 0.22 if active else 0.10), 2.0, true)
		draw_arc(centre, radius, 0, TAU, 32, Color(color, 0.95 if active else 0.55), 2.5 if active else 1.5, true)
		for i in 4:
			var angle := i * TAU / 4 + PI * 0.25
			var from := centre + Vector2.from_angle(angle) * (radius + 3)
			var to := centre + Vector2.from_angle(angle) * (radius + 13 if active else radius + 8)
			draw_line(from, to, Color(color, 0.85 if active else 0.4), 2.0, true)
		# A caret hanging under the ring, so a marker never hides its own station.
		var foot := centre + Vector2(0, radius + 16)
		if active:
			draw_colored_polygon(PackedVector2Array([foot + Vector2(-9, 0), foot + Vector2(9, 0),
				foot + Vector2(0, 12)]), Color(color, 0.9))
		var font := ThemeDB.fallback_font
		var caption := "%s  %s" % [str(station.no), str(station.name)]
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var at := centre + Vector2(-width / 2, -radius - 14)
		draw_rect(Rect2(at + Vector2(-6, -14), Vector2(width + 12, 21)), Color(0.02, 0.04, 0.07, 0.72), true)
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(1, 1, 1) if active else Color(color, 0.9))
