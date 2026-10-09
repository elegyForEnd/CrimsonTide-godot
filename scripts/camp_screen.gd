extends Control
## 出征前的初始营地界面：一座可以走动、种植、垂钓的独立 3D 家园。
##
## The screen owns the camp map (`scripts/camp_site.gd`), the on-station prompts
## and the bottom bar. It never launches a raid itself: it raises a signal and
## `main.gd` decides, so the camp cannot fork the online or single-player flow.
## Pressing `F` falls back to the classic整备 panel for players who would rather
## read menus than walk.

signal home_changed

signal station_requested(id: String)
signal launch_requested
signal exit_requested
signal codex_requested
## TAB: open (or close) the远征行囊 panel. The camp never draws it itself — `main.gd`
## owns every panel and every save write.
signal pack_requested
## TAB/ESC while an overlay owns the screen: close whatever panel is open. The camp
## still has to reach these keys even though `input_blocked` freezes the rest, or a
## panel would have no way out.
signal dismiss_requested
## A top-centre notice for answers the player must not miss (wired to main.notice_popup).
signal notice_requested(message: String)

const Site = preload("res://scripts/camp_site.gd")
const HomeSkin = preload("res://scripts/home_ui_skin.gd")
const HomeArt = preload("res://scripts/home_art.gd")

const BG := Color("070b12")
const PANEL := Color("0e1420")
const INK := Color("d4c8c8")
const MUTED := Color("a599a4")
const ARC := Color("c4919c")
const GOLD := Color("c7b5b1")
const RED := Color("d3556b")
const BOUNDS := Rect2(1050, 1250, 3900, 3600)

var home_ui: Control
var home_map: Control
var activities: Node3D
var fishing_meter: ProgressBar
var seed_status: Label

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
var squad_panel: Panel
var station_shortcuts: Dictionary = {}
var squad_count: Label
var supply_status: Label
var extra_meds := 0
var input_hint: Callable
var input_blocked := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ensure_actions()
	var serif := FontVariation.new()
	serif.base_font = load("res://assets/NotoSerifSC.ttf")
	serif.variation_embolden = 0.0
	title_font = serif
	var face := FontVariation.new()
	face.base_font = load("res://assets/NotoSansSC.ttf")
	face.variation_opentype = {"wght": 400.0}
	face_font = face

	site = Site.new()
	site.name = "Hearthhaven"
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
	flash.color = Color.TRANSPARENT
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
	# Home has no lightning; an always-visible flash washed out even the HUD.
	flash_art.visible = false
	flash.add_child(flash_art)
	add_child(flash)

	_build_vignette()
	_build_hud()
	_build_markers()
	home_ui = preload("res://scripts/home_screen.gd").new()
	home_ui.camp = self
	add_child(home_ui)
	home_map = preload("res://scripts/home_map.gd").new()
	home_map.camp = self
	add_child(home_map)
	activities = preload("res://scripts/camp_activities.gd").new()
	activities.camp = self
	site.add_child(activities)
	fishing_meter = preload("res://scripts/fishing_meter.gd").new()
	fishing_meter.custom_minimum_size = Vector2(260,24)
	fishing_meter.size = Vector2(260,24)
	fishing_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fishing_meter.visible = false
	marker_layer.add_child(fishing_meter)
	seed_status = _struck("",Vector2(470,600),15,GOLD,Vector2(500,24),HORIZONTAL_ALIGNMENT_CENTER)



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
	material.set_shader_parameter("strength",0.32)
	material.set_shader_parameter("inner",0.20)
	material.set_shader_parameter("outer",0.74)
	material.set_shader_parameter("edge_tint",Color("170c17"))
	material.set_shader_parameter("saturation",1.0)
	rect.material = material
	add_child(rect)
	move_child(rect, marker_layer.get_index())


func set_context(session_value: TideSession, profile_value: Profile) -> void:
	session = session_value
	profile = profile_value
	selected = int(profile.data.hero) if profile else 0
	if site:
		site.hero = selected
		site.refresh_crops(profile.data.home)
		activities.context(profile)
		update_static()
		refresh_roster()


func set_active(value: bool) -> void:
	if not value and activities: activities.cancel()
	# Floor loot is parked as data while the camp is not on screen: the nodes go away
	# and are rebuilt on the way back, so a raid pays nothing for it.
	if activities:
		if value: activities.restore_drops()
		else: activities.stash_drops()
	if not value and home_ui and home_ui.visible: home_ui.close()
	if not value and home_map and home_map.visible: home_map.close()
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
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", title_font if size >= 22 else face_font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.40))
	node.add_theme_constant_override("shadow_offset_y", 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(node)
	return node


func _panel(at: Vector2, size: Vector2, color: Color = PANEL) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.032, 0.065, 0.94)
	style.border_color = Color("655f50")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
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
	HomeSkin.dress(node,primary)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("643849") if primary else Color(0.12,0.085,0.14,0.94)
		if state in ["hover", "pressed", "focus"]: style.bg_color = Color("483747")
		style.border_color = Color("91836a") if primary else Color("65505f")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 12
		style.content_margin_right = 12
		node.add_theme_stylebox_override(state,style)
	node.add_theme_font_override("font", title_font)
	node.add_theme_font_size_override("font_size", 18 if primary else 16)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", Color("e7d6d3"))
	node.pressed.connect(func():
		if activities and activities.busy(): say("先完成操作，或按 Esc 收起工具。")
		else: callback.call())
	hud.add_child(node)
	return node


func _build_hud() -> void:
	# Compact image plaques keep the playable world in view.
	var heading_art := _panel(Vector2(24,22),Vector2(250,104))
	var heading := _struck("晨钟家园",Vector2.ZERO,23,GOLD,Vector2(186,32),HORIZONTAL_ALIGNMENT_CENTER)
	heading.reparent(heading_art)
	heading.position = Vector2(42,24)
	strikes = _struck("",Vector2.ZERO,12,MUTED,Vector2(186,20),HORIZONTAL_ALIGNMENT_CENTER)
	strikes.reparent(heading_art)
	strikes.position = Vector2(42,62)
	# Text stays in the slate's inner area, clear of the pointed corner artwork.
	squad_panel = _panel(Vector2(1084,22),Vector2(332,176))
	var squad_title := _struck("远征小队",Vector2.ZERO,19,GOLD,Vector2(176,28))
	squad_title.add_theme_font_override("font",title_font)
	squad_title.reparent(squad_panel)
	squad_title.position = Vector2(68,32)
	squad_count = _struck("",Vector2.ZERO,12,MUTED,Vector2(36,22),HORIZONTAL_ALIGNMENT_RIGHT)
	squad_count.reparent(squad_panel)
	squad_count.position = Vector2(214,36)
	charges = _struck("",Vector2.ZERO,13,MUTED,Vector2(228,24))
	charges.reparent(squad_panel)
	roster = VBoxContainer.new()
	roster.position = Vector2(56,78)
	roster.size = Vector2(228,40)
	roster.add_theme_constant_override("separation",6)
	roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	squad_panel.add_child(roster)
	var facilities := PanelContainer.new()
	facilities.name = "HomeFacilities"
	facilities.position = Vector2(24,150)
	facilities.size = Vector2(250,592)
	var facility_style := StyleBoxFlat.new()
	facility_style.bg_color = Color(0.035,0.032,0.065,0.90)
	facility_style.border_color = Color("655f50")
	facility_style.set_border_width_all(1)
	facility_style.set_corner_radius_all(8)
	facility_style.content_margin_left = 18
	facility_style.content_margin_right = 18
	facility_style.content_margin_top = 14
	facility_style.content_margin_bottom = 14
	facilities.add_theme_stylebox_override("panel",facility_style)
	hud.add_child(facilities)
	var links := VBoxContainer.new()
	links.add_theme_constant_override("separation",4)
	facilities.add_child(links)
	var facilities_title := Label.new()
	facilities_title.text = "家园设施"
	facilities_title.add_theme_font_override("font",title_font)
	facilities_title.add_theme_font_size_override("font_size",18)
	facilities_title.add_theme_color_override("font_color",GOLD)
	facilities_title.custom_minimum_size.y = 32
	links.add_child(facilities_title)
	for group in [["生活",["garden","fish","kitchen","home_shop"]],["整备",["table","forge","quarter","codex"]],["出征",["gate","rogue_gate"]]]:
		var group_title := Label.new()
		group_title.text = group[0]
		group_title.custom_minimum_size.y = 24
		group_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		group_title.add_theme_font_override("font",face_font)
		group_title.add_theme_font_size_override("font_size",12)
		group_title.add_theme_color_override("font_color",MUTED)
		links.add_child(group_title)
		for id in group[1]:
			var station: Dictionary = site.station_by_id(id)
			var shortcut := _action(station.name,Vector2.ZERO,Vector2(206,36),func(): warp_to(str(station.id)))
			shortcut.reparent(links)
			shortcut.toggle_mode = true
			shortcut.alignment = HORIZONTAL_ALIGNMENT_LEFT
			shortcut.clip_text = true
			shortcut.custom_minimum_size = Vector2(206,36)
			var quiet := StyleBoxEmpty.new()
			quiet.content_margin_left = 18
			quiet.content_margin_right = 18
			quiet.content_margin_top = 4
			quiet.content_margin_bottom = 4
			shortcut.add_theme_stylebox_override("normal",quiet)
			var selected_style := StyleBoxFlat.new()
			selected_style.bg_color = Color("493442")
			selected_style.set_corner_radius_all(4)
			shortcut.add_theme_stylebox_override("pressed",selected_style)
			for state in ["normal","hover","focus","pressed","disabled"]:
				var row_style: StyleBox = shortcut.get_theme_stylebox(state).duplicate()
				row_style.content_margin_left = 24
				row_style.content_margin_right = 18
				row_style.content_margin_top = 4
				row_style.content_margin_bottom = 4
				if row_style is StyleBoxTexture:
					row_style.texture_margin_left = 0
					row_style.texture_margin_right = 0
				shortcut.add_theme_stylebox_override(state,row_style)
			shortcut.add_theme_color_override("font_pressed_color",Color("e2b6b7"))
			station_shortcuts[id] = shortcut
	_panel(Vector2(24,812),Vector2(1392,66))
	loadout = _struck("",Vector2(54,830),16,INK,Vector2(320,26))
	supply_status = _struck("",Vector2(390,830),15,MUTED,Vector2(190,26))
	var navigation := HBoxContainer.new()
	navigation.name = "HomeNavigation"
	navigation.position = Vector2(618,827)
	navigation.size = Vector2(642,36)
	navigation.add_theme_constant_override("separation",6)
	hud.add_child(navigation)
	var destinations := [
		["整备",func(): station_requested.emit("table")],
		["行囊",func(): pack_requested.emit()],
		["仓库",func(): station_requested.emit("warehouse")],
		["交易",func(): station_requested.emit("market")],
		["地图",func(): home_map.open()],
		["手册",func(): codex_requested.emit()],
		["离开",func(): exit_requested.emit()]
	]
	for entry in destinations:
		var action := _action(entry[0],Vector2.ZERO,Vector2(102,36),entry[1])
		for state in ["normal","hover","focus","pressed","disabled"]:
			var frame: StyleBox = action.get_theme_stylebox(state).duplicate()
			frame.content_margin_top = 6
			frame.content_margin_bottom = 6
			action.add_theme_stylebox_override(state,frame)
		action.custom_minimum_size = Vector2(102,36)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.reparent(navigation)
	var info := HomeSkin.info(hud,self,"家园指南", "WASD 移动 · Shift 疾行 · E 使用设施
左侧设施名称可直接前往；M 打开地图；Tab 打开远征行囊。
菜园：E 播种、浇水与收获，Q 换种子；浇水加速生长，离线继续生长。
栈桥：E / Space 抛竿，等咬钩后在绿色区域收竿；Esc 收起工具。
厨房：烹饪后携带一份餐食，成功出征时消耗。
F 拾取地上的产物；整备台是付费购买装备的柜台，走到它面前按 E。
行囊里可以整理随身背包、次元口袋和守夜人仓库（15×15 真网格），
装备穿着与摆放都会立刻写入存档；仓库里的东西可在交易行出售。\n 菜与鱼是背包物品：自动进背包/口袋，满了掉地上，走近按 F 拾取；出售带去交易行，烹饪消耗背包/口袋/仓库里的收获实例。
南侧闸门进入搜打撤，东侧传送门进入魔境。出发按钮跟随当前模式，联机需要全队准备。")
	info.position = Vector2(1354,824)
	info.size = Vector2(40,40)
	launch_button = _action("出发 →",Vector2(1136,740),Vector2(280,58),func(): launch_requested.emit(),true)
	toast = _struck("",Vector2(470,670),18,GOLD,Vector2(500,30),HORIZONTAL_ALIGNMENT_CENTER)
	prompt = _struck("",Vector2(470,708),20,INK,Vector2(500,30),HORIZONTAL_ALIGNMENT_CENTER)
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
		roster.remove_child(child)
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
	squad_count.text = "%d / 4" % rows.size()
	if session and not session.is_leader():
		launch_button.text = "取消准备" if session.players.get(session.my_id(), {}).get("ready", false) else "准备出发    →"
	else:
		launch_button.text = "魔境 · 出发 →" if session and session.selected_mode=="roguelike" else "搜打撤 · 出发 →"
	squad_panel.size.y = 136 + maxi(1,rows.size())*40
	charges.position = Vector2(56,squad_panel.size.y-42)
	for row in rows:
		var member := VBoxContainer.new()
		member.add_theme_constant_override("separation",0)
		member.custom_minimum_size.y = 34
		roster.add_child(member)
		var identity := HBoxContainer.new()
		member.add_child(identity)
		var name_label := Label.new()
		name_label.text = row.name
		name_label.tooltip_text = row.name
		name_label.clip_text = true
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_override("font",face_font)
		name_label.add_theme_font_size_override("font_size",15)
		name_label.add_theme_color_override("font_color",INK)
		identity.add_child(name_label)
		var readiness := Label.new()
		readiness.text = row.state
		readiness.custom_minimum_size.x = 42
		readiness.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		readiness.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		readiness.add_theme_font_override("font",face_font)
		readiness.add_theme_font_size_override("font_size",12)
		readiness.add_theme_color_override("font_color",Color("c59b9e") if row.state=="就绪" else MUTED)
		identity.add_child(readiness)
		var role := Label.new()
		role.text = row.tag
		role.add_theme_font_override("font",face_font)
		role.add_theme_font_size_override("font_size",11)
		role.add_theme_color_override("font_color",MUTED)
		member.add_child(role)




func update_static() -> void:
	if profile:
		selected = int(profile.data.hero)
		site.hero = selected
		var hero: Dictionary = Catalog.HEROES[clampi(selected, 0, Catalog.HEROES.size() - 1)]
		loadout.text = "%s    Lv.%02d    ◈ %d" % [hero.name, profile.level(), profile.data.coins]
		strikes.text = home_summary()
		var meal := str(profile.data.home.prepared)
		var meals: Dictionary = preload("res://scripts/homestead.gd").MEALS
		charges.text = "餐食  %s" % [meals[meal].name if meals.has(meal) else "未携带"]
	supply_status.text = "急救针 ×%d / 3" % (1 + extra_meds)


# ---------------------------------------------------------------------- input

func _process(dt: float) -> void:
	if not visible:
		return
	fishing_meter.visible = activities.action=="fish" and activities.fishing_phase=="bite"
	if fishing_meter.visible:
		fishing_meter.position = (site.project(activities.target)-Vector2(130,-24)).clamp(Vector2(310,170),Vector2(840,560))
		fishing_meter.value = activities.fishing_value()
		fishing_meter.fine = profile.data.home.rod==2
	if activities.busy():
		site.hero_walking = false
		prompt.text = "[Space / E] 收竿  ·  [Esc] 收起钓竿" if activities.action=="fish" else "正在操作田畦  ·  [Esc] 取消"
		if input_hint.is_valid(): prompt.text=input_hint.call(prompt.text)
		return
	if input_blocked:
		warp_charge = 0.0
		warp_target = ""
		site.hero_walking = false
		return
	clock += dt
	var speed := 420.0
	var stick := Input.get_vector("left","right","up","down")
	if held("sprint"):
		speed = 700.0
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
	strikes.text = home_summary()


## The single place the hero moves, so a test drives exactly the player's path.
func drive_hero(stick: Vector2, dt: float) -> void:
	if activities and activities.busy(): return
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
	if not visible:
		return
	# A panel (the bag, the forge, the exchange) blocks the camp, but TAB and ESC
	# still belong to it: without that a panel would have no way out.
	if input_blocked:
		if event is InputEventKey and event.pressed and not event.echo:
			var blocked_code: int = event.physical_keycode if event.physical_keycode else event.keycode
			if blocked_code==KEY_TAB or blocked_code==KEY_ESCAPE:
				dismiss_requested.emit()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var ground: Vector2 = site.unproject(event.position)
		for i in 9:
			if Rect2(site.garden_at(i)-Vector2(106,100),Vector2(212,200)).has_point(ground):
				activities.farm(i)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if activities.busy():
			if code==KEY_ESCAPE: activities.cancel(); say("已收起工具。")
			elif code in [KEY_E,KEY_SPACE,KEY_ENTER] and activities.action=="fish": activities.reel()
			get_viewport().set_input_as_handled()
			return
		if code==KEY_Q:
			activities.cycle_seed()
			get_viewport().set_input_as_handled()
			return
		if code==KEY_SPACE and activities.at_pier():
			activities.cast()
			get_viewport().set_input_as_handled()
			return
		# Space is the hard commitment: it only exists at the departure gate.
		if code == KEY_SPACE:
			var gate: Dictionary = site.station_at(site.hero_position())
			if not gate.is_empty() and str(gate.action) in ["launch","rogue"]:
				station_requested.emit(str(gate.action))
			else:
				say("先走到搜打撤闸门或魔境传送门，再按 Space 出发。")
			get_viewport().set_input_as_handled()
			return
		match code:
			KEY_E, KEY_ENTER:
				interact()
			KEY_F:
				# A ground stack of produce is the only thing F does in the camp. The
				# prep table used to be its fallback, but the table is a paid counter
				# now and a movement key must not spend money by accident — walk to
				# it and press E instead.
				if activities and activities.has_drop_near(site.hero_at):
					if activities.pick_up_nearby(): home_changed.emit()
			KEY_TAB:
				pack_requested.emit()
			KEY_M:
				home_map.open()
			KEY_ESCAPE:
				exit_requested.emit()
			_:
				return
		get_viewport().set_input_as_handled()


## Uses whichever station the player is standing in, and reports what happened.
func interact() -> Dictionary:
	if activities.interact(): return {"action":"world_activity"}
	var station: Dictionary = site.station_at(site.hero_position())
	if station.is_empty():
		say("附近没有可用设施，去发光的地标处。")
		return {}
	say("进入 " + str(station.name))
	if str(station.action)=="garden":
		say("走近具体田块，E 播种、浇水或收获；Q 切换种子。")
	elif str(station.action)=="fish":
		activities.cast()
	elif str(station.action) in ["kitchen","home_shop"]:
		home_ui.open(str(station.action))
	else:
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
	if activities and activities.busy():
		say("先完成操作，或按 Esc 收起工具。")
		return
	var station: Dictionary = site.station_by_id(id)
	if station.is_empty():
		return
	site.hero_at = site.safe_position(station.at + station.offset + Vector2(0, 120))
	if id=="garden": site.hero_at = site.safe_position(Vector2(2050,2300))
	if id=="fish": site.hero_at = site.safe_position(preload("res://scripts/camp_activities.gd").PIER_AT)
	site.set_camera_focus(site.hero_at, true)


func _update_markers() -> void:
	var near: Dictionary = site.station_at(site.hero_position())
	for station in site.stations:
		var marker: Control = station_markers[str(station.id)]
		var active: bool = not near.is_empty() and str(near.id) == str(station.id)
		marker.position = site.project(station.at + station.offset) - marker.size / 2
		# 650 只是"地名名牌"的可见范围；可交互样式（光环/箭头）与 [E] 提示都只由
		# active（= station_at() 命中，距离 < station.radius）驱动，见 StationMarker._draw()。
		marker.visible = active or site.hero_at.distance_to(station.at + station.offset) < 650
		marker.set_active(active)
		if station_shortcuts.has(station.id): station_shortcuts[station.id].set_pressed_no_signal(active)
	hero_marker.position = site.project(site.hero_position()) - Vector2(26, 78)
	hero_marker.queue_redraw()
	if near.is_empty():
		if warp_charge <= 0.0:
			prompt.text = ""
	else:
		if warp_charge <= 0.0:
			prompt.text = "[E]  %s" % near.name
	var plot: int = activities.nearest_plot(site.hero_at)
	seed_status.text = ""
	if plot>=0:
		prompt.text = activities.plot_hint(plot)
		seed_status.text = str(preload("res://scripts/homestead.gd").CROPS[activities.selected_crop].name)+"  [Q]"
	elif activities.at_pier(): prompt.text = "[E / Space] 抛竿"
	# A pile on the ground outshouts everything else nearby — produce or a piece of
	# loot the player dropped out of the bag panel.
	if activities.has_drop_near(site.hero_at):
		var drop_index: int = activities.nearest_drop(site.hero_at)
		if drop_index>=0:
			var drop: Dictionary = activities.drops[drop_index]
			if drop.has("entry"):
				prompt.text = "[F]  拾取 " + Catalog.item_name(drop.entry)
			else:
				prompt.text = "[F] 拾取 %s ×%d" % [str(preload("res://scripts/homestead.gd").CROPS.get(str(drop.kind),preload("res://scripts/homestead.gd").FISH.get(str(drop.kind),{})).name),int(drop.units)]
	if input_hint.is_valid():
		prompt.text=input_hint.call(prompt.text)
		seed_status.text=input_hint.call(seed_status.text)




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
		var font := ThemeDB.fallback_font
		var caption := "%s  %s" % [str(station.no), str(station.name)]
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		if not active:
			# 圈外只当"地名"：变暗、不出环/箭头等任何可交互样式，更不出 [E] 等按键
			# 字样——按键提示只由 station_at() 命中（< station.radius）后的 prompt 提供。
			var far := centre + Vector2(-width / 2, -16.0 - 14)
			draw_rect(Rect2(far + Vector2(-6, -14), Vector2(width + 12, 21)), Color(0.02, 0.04, 0.07, 0.45), true)
			draw_string(font, far, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(color, 0.55))
			return
		var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.004)
		var radius := 23.0 * pulse
		draw_arc(centre, radius + 9, 0, TAU, 40, Color(color, 0.22), 2.0, true)
		draw_arc(centre, radius, 0, TAU, 32, Color(color, 0.95), 2.5, true)
		for i in 4:
			var angle := i * TAU / 4 + PI * 0.25
			var from := centre + Vector2.from_angle(angle) * (radius + 3)
			var to := centre + Vector2.from_angle(angle) * (radius + 13)
			draw_line(from, to, Color(color, 0.85), 2.0, true)
		# A caret hanging under the ring, so a marker never hides its own station.
		var foot := centre + Vector2(0, radius + 16)
		draw_colored_polygon(PackedVector2Array([foot + Vector2(-9, 0), foot + Vector2(9, 0),
			foot + Vector2(0, 12)]), Color(color, 0.9))
		var at := centre + Vector2(-width / 2, -radius - 14)
		draw_rect(Rect2(at + Vector2(-6, -14), Vector2(width + 12, 21)), Color(0.02, 0.04, 0.07, 0.72), true)
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))


func home_summary() -> String:
	if not profile: return "独立家园 · 种植 / 垂钓 / 烹饪"
	var ripe := 0
	var rules := preload("res://scripts/homestead.gd").new(profile)
	for i in rules.state().beds:
		if not str(rules.state().plots[i].crop).is_empty() and rules.remaining(i)==0: ripe += 1
	return "可收获 %d  ·  鱼饵 %d" % [ripe,profile.product_count("bait")]
