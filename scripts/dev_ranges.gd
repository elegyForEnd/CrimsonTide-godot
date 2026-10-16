extends Node2D
## 开发者模式 · 判定框总览（**仅开发可见**；正式对局零可见、零行为影响）。
##
## 开关：环境变量 `CRIMSON_DEV_RANGES`（`开发者模式启动.cmd` 设成 `all`）。`main.gd` 只在
## 该变量有值时创建本节点；正式游玩时**连节点都不建**（见路牌 §11.48）。
##
## 四种表现层各挂一份，`mode` 由挂载处显式指定，投影一律向宿主取：
##   魔境 ROGUE        `rogue_field.gd`(Control)   模拟坐标 → 画布 = 一次仿射（camera_offset）
##   搜打撤 EXPEDITION  `battlefield.gd`(Node2D)   模拟坐标 → 画布 = ground_transform()（3D 正交相机贴地）
##   营地 CAMP         `camp_screen.gd`(Control)   `site.project_ground()` 逐点投影（带地面高度）
##   故事 STORY        `story_screen.gd`(Control)  `project()` 逐点投影（带 height_at）
##
## 铁律（路牌 §11.48）：**只读**——只画 session / campaign / site 里已经存在的状态与公开常量，
## 不改数值、不写状态、不吃 rng、不参与任何命中判定。半径一律引用原系统常量或运行时字段；
## 故事模式的内联字面量已在 2026-10-11 收拢成 `story_campaign.gd` 顶部的常量块。
##
## 2026-10-11 第 5 批：①勾选面板（原生 Control，模式→大类→小类，实时生效、内存保留、可拖动、
## 可最小化 F10）；②魔境补子弹框；③营地/故事圆环改**逐点带高度**投影（原来的一次仿射拟合在
## 台阶上会把圈压下 ~90px，"有圈无事件"就是这么来的）；④新增 NPC 互动圈与建筑碰撞箱。
##
## 批次进度与清单见仓库根 `KAIFAZHEMOSHI.md`。

const Build = preload("res://scripts/rogue_build.gd")
const Ecology = preload("res://scripts/ecology.gd")
const BossTactics = preload("res://scripts/boss_tactics.gd")
const CampRules = preload("res://scripts/camp_activities.gd")
const CombatVisuals = preload("res://scripts/combat_visuals.gd")

enum Mode { NONE, ROGUE, EXPEDITION, CAMP, STORY }

## `ruins.gd blocked()/move()` 的默认碰撞半径（搜打撤与魔境共用同一个默认值）。
const PLAYER_RADIUS := 15.0
## `rogue_combat.setup_minion()` 的 `rogue_radius` 兜底值。
const FALLBACK_ENEMY_RADIUS := 13.0
## 只画这个半径内的东西（比相机视距略大，避免整张地图的圆环拖慢开发机）。
const DRAW_RANGE := 1700.0
## Boss 伤害域轮廓的采样精度：射线条数 / 粗扫步数 / 二分细化步数。
const HAZARD_RAYS := 32
const HAZARD_COARSE := 12
const HAZARD_REFINE := 6

const INK := Color(1, .97, .92, .95)
const GOLD := Color(1, .85, .5, .95)
const MUTED := Color(.72, .74, .80, .95)
const C_SEEK := Color(.45, .85, 1, .55)
const C_NEAR := Color(.80, .60, 1, .45)
const C_RANGE := Color(1, .92, .45, .38)
const C_KEEP := Color(1, .72, .35, .28)
const C_PLAYER := Color(.50, 1, .60, .85)
const C_ENEMY := Color(1, .45, .45, .75)
const C_TARGET := Color(1, .42, .42, .70)
const C_BULLET := Color(1, .88, .40, .80)
const C_INTERACT := Color(.55, .92, 1, .70)
const C_RESCUE := Color(.55, 1, .80, .75)
const C_BOSS := Color(1, .35, .95, .85)
const C_CAMP := Color(.60, .88, 1, .70)
const C_FADE := Color(.88, .88, .88, .40)
## 故事：白细线＝"提示圈"（走到这里就出 [E]），青＝"使用半径"（按下去真的生效），
## 绿＝英雄此刻已在"使用半径"内，红＝距离够了但被威胁门挡住（见 `draw_story()` 注释）。
const C_PROMPT := Color(1, 1, 1, .38)
const C_USE := Color(.55, .92, 1, .85)
const C_READY := Color(.45, 1, .60, .95)
const C_BLOCKED := Color(1, .40, .40, .95)
const C_BUILD := Color(1, .78, .35, .85)
const C_WALL := Color(1, .55, .35, .75)
const C_OBSTACLE := Color(.85, .55, .95, .55)

# ------------------------------------------------------------------ 勾选树
# [模式, [大类, [小类…]]]，小类＝[key, 标签, 默认开]。**内存保留**：`toggles` 是 static，
# 换宿主（魔境→营地→故事…）时勾选状态不丢；重启游戏回默认。
const PANEL_TREE := [
	{"mode": "魔境（2D 战场）", "groups": [
		{"name": "引魂灵体（只在该玩家真有灵体时画）", "items": [
			["rogue_soul_master", "主人索敌圈 300", true],
			["rogue_soul_body", "灵体自身：索敌 167 / 射程 150 / 停靠 128", true],
			["rogue_soul_target", "点名目标 / 灵体当前目标连线", true],
		]},
		{"name": "角色与怪物", "items": [
			["rogue_actor", "角色地形判定 15", true],
			["rogue_enemy", "怪物半径（rogue_radius）", true],
		]},
		{"name": "子弹与互动", "items": [
			["rogue_bullet", "子弹：敌弹命中圆 18 / 玩家弹扫掠线段", true],
			["rogue_interact", "宝箱 85 / 奖励箱 / 掉落 80 / 分叉 64 / 救援 75", true],
		]},
	]},
	{"mode": "搜打撤（3D 战场）", "groups": [
		{"name": "角色与怪物", "items": [
			["exp_actor", "角色地形 15 / 倒地救援 75", true],
			["exp_enemy_body", "怪物体型半径（Ecology.RADIUS）", true],
			["exp_enemy_seek", "索敌：动态 440+威胁 / 骑士 780 / 野怪 470", true],
			["exp_enemy_reach", "攻击射程：近身 58 / 骑士招式 / 野怪起手", true],
		]},
		{"name": "子弹与互动", "items": [
			["exp_bullet", "子弹：敌弹命中圆 / 玩家弹扫掠线段", true],
			["exp_interact", "城门 85 / 撤离 83 / 封印 72 / 搜刮 80 / 掉落 70", true],
			["exp_hazard", "Boss 伤害域轮廓（权威判定采样）", true],
		]},
	]},
	{"mode": "营地 / 家园（3D）", "groups": [
		{"name": "设施与角色", "items": [
			["camp_station", "设施交互圈（stations[].radius）", true],
			["camp_name", "地名名牌可见 650（与交互半径不同源）", true],
			["camp_actor", "角色地形判定 24", true],
			["camp_activity", "田畦 155 / 栈桥 240 / 地面拾取 120", true],
		]},
	]},
	{"mode": "故事（连续地图）", "groups": [
		{"name": "英雄", "items": [
			["story_hero", "普攻判定 200/580/245（技能 430 / 奥义 670）", true],
			["story_melee", "近身无条件命中 80", true],
		]},
		{"name": "敌人与伙伴", "items": [
			["story_enemy", "敌人索敌 300/80 · 出手 650/120 · 休眠 900", true],
			["story_windup", "前摇 AoE（ring 内圈 100 / cross 臂 65）", true],
			["story_ally", "伙伴索敌 350 / 事件 150 / 跟随 80", true],
		]},
		{"name": "互动（白＝提示圈，青＝使用圈，绿＝已在圈内）", "items": [
			["story_object", "任务物：提示 125 / 使用 110 / 威胁门 260", true],
			["story_cache", "宝箱：提示 125 / 使用 130", true],
			["story_door", "门洞：提示 125 / 使用 150（只画当前区域）", true],
			["story_waypoint", "传送阵：提示 125 / 使用 160（HUD 按钮 150）", true],
			["story_npc", "NPC 互动 125（只有营地 stage 0 可交互）", true],
			["story_building", "建筑碰撞箱：占地矩形 + 5 段墙 + 障碍", true],
		]},
	]},
	{"mode": "通用", "groups": [
		{"name": "显示", "items": [
			["common_labels", "文字标签（F9 也可切换）", true],
			["common_legend", "数值图例（面板已含数值，默认关）", false],
			["common_blocked", "把被威胁门挡住的目标画成红色", true],
		]},
	]},
]

## 勾选状态（static ⇒ 换宿主/换模式不丢；重启回默认）。
static var toggles: Dictionary = {}

var main
var mode := Mode.NONE
var show_labels := true
var _hazard_cache: Dictionary = {}
var _dt := 0.016
## 本帧的仿射变换（魔境/搜打撤）或 IDENTITY（营地/故事走逐点投影）。
var _tf := Transform2D.IDENTITY

# 面板状态
var _panel: PanelContainer
var _mini: Button
var _minimized := false
var _dragging := false
var _panel_pos := Vector2(24, 24)

## 环境变量开了才算开发者模式；`0/off/false/no` 都当关。
static func enabled() -> bool:
	var flag := OS.get_environment("CRIMSON_DEV_RANGES").strip_edges().to_lower()
	return not (flag in ["", "0", "off", "false", "no"])

## 鼠标是不是落在本覆盖层的面板上。`main.gd` 用它把"点在面板上"和"点在世界里"分开：
## 勾选框是 Button（`main.gd mouse_over_button()` 认），但面板的空白处不是，不挡的话
## 点一下面板就会顺带蓄力一刀。用 Godot 自己的命中结果，不做坐标换算。
func captures_mouse() -> bool:
	if _panel == null or not _panel.is_visible_in_tree():
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and (_panel == hovered or _panel.is_ancestor_of(hovered))

func mode_group_key() -> String:
	match mode:
		Mode.ROGUE: return "魔境"
		Mode.EXPEDITION: return "搜打撤"
		Mode.CAMP: return "营地"
		Mode.STORY: return "故事"
	return ""

func _ready() -> void:
	z_index = 4096
	set_process(true)
	add_to_group("dev_ranges")
	for group in PANEL_TREE:
		for section in group.groups:
			for item in section.items:
				var key := str(item[0])
				if not toggles.has(key):
					toggles[key] = bool(item[2])
	_build_panel()

func _process(dt: float) -> void:
	_dt = dt
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			show_labels = not show_labels
			toggles["common_labels"] = show_labels
		elif event.keycode == KEY_F10:
			set_minimized(not _minimized)

# ---------------------------------------------------------------- 勾选查询

func toggle_on(key: String) -> bool:
	return bool(toggles.get(key, true))

func _set_toggle(key: String, on: bool) -> void:
	toggles[key] = on
	if key == "common_labels":
		show_labels = on
	queue_redraw()

func _set_all(on: bool) -> void:
	for group in PANEL_TREE:
		for section in group.groups:
			for item in section.items:
				toggles[str(item[0])] = on
	show_labels = toggle_on("common_labels")
	_sync_boxes()
	queue_redraw()

# ---------------------------------------------------------------- 面板（原生 Control）

func _panel_font() -> Font:
	if ResourceLoader.exists("res://assets/NotoSansSC.ttf"):
		return load("res://assets/NotoSansSC.ttf")
	return ThemeDB.fallback_font

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.03, .035, .05, .90)
	style.border_color = Color(1, .85, .5, .55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _build_panel() -> void:
	var font := _panel_font()
	_panel = PanelContainer.new()
	_panel.name = "DevRangesPanel"
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.position = _panel_pos
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)

	# 标题栏：整条可拖动，右侧是最小化按钮。
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.tooltip_text = "按住拖动 · F10 最小化"
	bar.gui_input.connect(_on_bar_input)
	column.add_child(bar)
	var title := Label.new()
	title.text = "开发者模式 · 判定框总览"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	var hide_button := Button.new()
	hide_button.text = "—"
	hide_button.tooltip_text = "最小化（F10 再展开）"
	hide_button.add_theme_font_override("font", font)
	hide_button.pressed.connect(func() -> void: set_minimized(true))
	bar.add_child(hide_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(336, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)

	# 当前模式的分组排在最前（换宿主时会重建面板），省得每次往下滚。
	var ordered: Array = PANEL_TREE.duplicate()
	var current := mode_group_key()
	if current != "":
		for i in ordered.size():
			if str(ordered[i].mode).begins_with(current):
				var picked: Dictionary = ordered[i]
				ordered.remove_at(i)
				ordered.push_front(picked)
				break
	for group in ordered:
		var heading := str(group.mode)
		if current != "" and heading.begins_with(current):
			heading += "　← 当前"
		list.add_child(_heading(heading, GOLD, 15, font))
		for section in group.groups:
			list.add_child(_heading("  " + str(section.name), MUTED, 13, font))
			for item in section.items:
				var key := str(item[0])
				var box := CheckBox.new()
				box.text = str(item[1])
				box.name = "cb_" + key
				box.button_pressed = toggle_on(key)
				box.add_theme_font_override("font", font)
				box.add_theme_font_size_override("font_size", 13)
				box.toggled.connect(func(on: bool) -> void: _set_toggle(key, on))
				list.add_child(box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	column.add_child(buttons)
	for spec in [["全选", true], ["全不选", false], ["重置", true]]:
		var button := Button.new()
		button.text = str(spec[0])
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 12)
		var on := bool(spec[1])
		if str(spec[0]) == "重置":
			button.pressed.connect(_reset_all)
		else:
			button.pressed.connect(func() -> void: _set_all(on))
		buttons.add_child(button)

	_mini = Button.new()
	_mini.text = "开发者模式"
	_mini.add_theme_font_override("font", font)
	_mini.add_theme_font_size_override("font_size", 13)
	_mini.position = _panel_pos
	_mini.visible = false
	_mini.pressed.connect(func() -> void: set_minimized(false))
	add_child(_mini)

func _heading(text: String, color: Color, size: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _reset_all() -> void:
	for group in PANEL_TREE:
		for section in group.groups:
			for item in section.items:
				toggles[str(item[0])] = bool(item[2])
	show_labels = toggle_on("common_labels")
	_sync_boxes()
	queue_redraw()

func _sync_boxes() -> void:
	if _panel == null:
		return
	for group in PANEL_TREE:
		for section in group.groups:
			for item in section.items:
				var key := str(item[0])
				var box := _panel.find_child("cb_" + key, true, false) as CheckBox
				if box != null:
					box.set_pressed_no_signal(toggle_on(key))

func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_panel.position += event.relative
		var extent := get_viewport_rect().size
		_panel.position = _panel.position.clamp(Vector2(-extent.x + 120, 0), Vector2(extent.x - 80, extent.y - 40))
		_panel_pos = _panel.position
		_mini.position = _panel_pos

func set_minimized(minimized: bool) -> void:
	_minimized = minimized
	if _panel != null:
		_panel.visible = not minimized
	if _mini != null:
		_mini.visible = minimized
		_mini.position = _panel_pos

# ---------------------------------------------------------------- 宿主投影适配

func host() -> Node:
	return get_parent()

func session():
	return main.session if main != null else null

## 魔境/搜打撤走一次仿射贴地变换（宿主自己画弧线/预警圈也用同一套）；营地/故事逐点投影。
func affine() -> bool:
	return mode == Mode.ROGUE or mode == Mode.EXPEDITION

func sim_space() -> bool:
	return mode != Mode.NONE

func host_transform() -> Transform2D:
	var h := host()
	if h == null:
		return Transform2D.IDENTITY
	match mode:
		Mode.ROGUE:
			return Transform2D(0, -h.camera_offset())
		Mode.EXPEDITION:
			return h.ground_transform()
		Mode.CAMP:
			return h.site.ground_transform()
		Mode.STORY:
			return h.ground_transform()
	return Transform2D.IDENTITY

## 逐点投影：营地用带地面高度的 `project_ground()`，故事用带 height_at 的 `project()`。
## 这两个才是"物体真正画在哪"的投影；`ground_transform()` 只是三点仿射拟合，台阶上会偏。
func project_point(p: Vector2) -> Vector2:
	if affine():
		return _tf * p
	var h := host()
	if h == null:
		return p
	match mode:
		Mode.CAMP:
			return h.site.project_ground(p)
		Mode.STORY:
			return h.project(p)
	return p

func canvas_point(p: Vector2) -> Vector2:
	return project_point(p)

## 模拟 1 单位在画布上的像素长度（正交相机下各向近似一致，用 x 轴）。
func canvas_scale() -> float:
	if mode == Mode.ROGUE:
		return 1.0
	if mode == Mode.CAMP or mode == Mode.STORY:
		return (project_point(Vector2(100, 0)) - project_point(Vector2.ZERO)).length() / 100.0
	return _tf.basis_xform(Vector2.RIGHT).length()

func begin_sim() -> void:
	_tf = host_transform()
	if affine():
		draw_set_transform_matrix(_tf)

func end_sim() -> void:
	if affine():
		draw_set_transform(Vector2.ZERO)

# ---------------------------------------------------------------- 画框工具

func arc_segments(radius: float) -> int:
	return clampi(int(radius * 0.5), 24, 96)

## 带高度模式下的圆环采样数（每点一次投影，所以比 draw_arc 便宜地取少一些）。
func height_segments(radius: float) -> int:
	return clampi(int(radius * 0.22), 16, 44)

func ring(at: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	if radius <= 0.0:
		return
	draw_arc(at, radius, 0, TAU, arc_segments(radius), color, width, true)

## 圆环：仿射模式直接 draw_arc（贴地）；带高度模式逐点投影成折线。
func circle(at: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	if radius <= 0.0:
		return
	if affine():
		ring(at, radius, color, width)
		return
	var segments := height_segments(radius)
	var points := PackedVector2Array()
	for i in segments + 1:
		points.append(project_point(at + Vector2.from_angle(TAU * float(i) / float(segments)) * radius))
	draw_polyline(points, color, width, true)

func line(from: Vector2, to: Vector2, color: Color, width: float = 2.0) -> void:
	draw_line(from, to, color, width, true)

## 线段：带高度模式两端各自投影。
func segment(from: Vector2, to: Vector2, color: Color, width: float = 2.0) -> void:
	if affine():
		draw_line(from, to, color, width, true)
	else:
		draw_line(project_point(from), project_point(to), color, width, true)

## 矩形轮廓（+可选半透明填充），四个角各自投影——建筑碰撞箱用它。
func rect_outline(rect: Rect2, color: Color, width: float = 1.5, fill: Color = Color(0, 0, 0, 0)) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var points := PackedVector2Array([
		project_point(rect.position),
		project_point(Vector2(rect.end.x, rect.position.y)),
		project_point(rect.end),
		project_point(Vector2(rect.position.x, rect.end.y)),
	])
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	var loop := points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, color, width, true)

## 文字永远画在画布空间（贴地变换会把字压扁/旋转），所以内部临时复位再投影锚点。
func label(at: Vector2, text: String, color: Color, lift: float = 0.0) -> void:
	if not show_labels:
		return
	draw_set_transform(Vector2.ZERO)
	draw_string(ThemeDB.fallback_font, project_point(at) + Vector2(-46, -10 - lift), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	if affine():
		draw_set_transform_matrix(_tf)

func legend_top() -> float:
	if _panel != null and _panel.visible and _panel.size.y > 0.0:
		return _panel.position.y + _panel.size.y + 8.0
	return 24.0

func draw_legend(rows: Array) -> void:
	if not toggle_on("common_legend"):
		return
	var font := ThemeDB.fallback_font
	var box := Rect2(24, legend_top(), 760, 21 * rows.size() + 14)
	draw_rect(box, Color(0, 0, 0, .58), true)
	draw_rect(box, Color(1, .85, .5, .45), false, 1.0)
	for i in rows.size():
		draw_string(font, box.position + Vector2(12, 22 + 21 * i), str(rows[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)

# ---------------------------------------------------------------- 绘制入口

func _draw() -> void:
	match mode:
		Mode.ROGUE: draw_rogue()
		Mode.EXPEDITION: draw_expedition()
		Mode.CAMP: draw_camp()
		Mode.STORY: draw_story()

# ---------------------------------------------------------------- 批次 1：魔境（2D 战场）

func draw_rogue() -> void:
	var s = session()
	if s == null:
		return
	begin_sim()
	draw_souls(s)
	draw_actors(s)
	draw_bullets(s, _hero_point(s))
	draw_rogue_interact(s)
	end_sim()
	draw_legend([
		"【开发者模式】判定框总览 · 魔境 · CRIMSON_DEV_RANGES=%s" % OS.get_environment("CRIMSON_DEV_RANGES"),
		"青 主人索敌圈 %.0f（只在该玩家真有灵体时画）｜ 紫 灵体索敌 %.0f ｜ 黄 灵体射程 %.0f ｜ 橙 停靠 %.0f" % [Build.SOUL_SEEK, Build.SOUL_NEAR, Build.SOUL_RANGE, Build.SOUL_KEEP],
		"绿 角色地形 %.0f ｜ 红 怪物半径 ｜ 黄 子弹命中 %.0f / 玩家弹扫掠线段 ｜ F9 文字 / F10 面板" % [PLAYER_RADIUS, CombatVisuals.ENEMY_BOLT_HIT_RADIUS],
	])

func _hero_point(s) -> Vector2:
	var me: Dictionary = s.players.get(s.my_id(), {})
	return me.p if not me.is_empty() else Vector2.ZERO

# —— 批次 1：引魂灵体（四档半径＝设计规则本身；数值来源 `rogue_build.gd:19-27`）——
# 2026-10-11：门控改成"该玩家真的有活着的灵体"（`build_summons` 非空）才算——
# `soul_focus` 只在有灵体时才被写（`rogue_build.gd hit_event`），所以没词条的角色不会再有误报的圈。
func draw_souls(s) -> void:
	for p in s.players.values():
		var souls: Array = p.get("build_summons", [])
		if souls.is_empty():
			continue
		if toggle_on("rogue_soul_master"):
			circle(p.p, Build.SOUL_SEEK, C_SEEK, 2.0)
			label(p.p, "主人索敌圈 %.0f" % Build.SOUL_SEEK, C_SEEK, -Build.SOUL_SEEK - 4)
		if toggle_on("rogue_soul_target"):
			var focus: Dictionary = Build.enemy_by_id(s, int(p.get("soul_focus", -1)))
			if not focus.is_empty():
				circle(focus.p, 20.0, Color(1, .55, .55, .9), 2.0)
				label(focus.p, "主人点名的目标", Color(1, .7, .7, .95), 26)
		if not toggle_on("rogue_soul_body"):
			continue
		for soul in souls:
			circle(soul.p, Build.SOUL_NEAR, C_NEAR, 1.5)
			circle(soul.p, Build.SOUL_RANGE, C_RANGE, 1.0)
			circle(soul.p, Build.SOUL_KEEP, C_KEEP, 1.0)
			var target: Dictionary = Build.enemy_by_id(s, int(soul.get("target", -1)))
			if not target.is_empty():
				segment(soul.p, target.p, C_TARGET, 2.0)
			label(soul.p, "灵体 · %s" % str(soul.get("tier", "?")), INK, 64)

# —— 批次 1：角色 / 怪物的判定半径 ——
func draw_actors(s) -> void:
	if toggle_on("rogue_actor"):
		for p in s.players.values():
			circle(p.p, PLAYER_RADIUS, C_PLAYER, 2.0)
			label(p.p, "角色地形判定 %.0f" % PLAYER_RADIUS, C_PLAYER, PLAYER_RADIUS + 6)
	if toggle_on("rogue_enemy"):
		for e in s.enemies:
			var radius := float(e.get("rogue_radius", FALLBACK_ENEMY_RADIUS))
			circle(e.p, radius, C_ENEMY, 2.0)

# —— 批次 1：魔境互动（宝箱 85 / 奖励箱 / 掉落 80 / 分叉 64 / 救援 75）——
func draw_rogue_interact(s) -> void:
	if not toggle_on("rogue_interact"):
		return
	var me: Vector2 = _hero_point(s)
	for chest in s.ruins.chests:
		circle(chest.p, s.CHEST_RADIUS, C_INTERACT, 1.5)
	var reward_chest: Dictionary = s.raid.get("reward_chest", {}) if s.raid != null else {}
	if not reward_chest.is_empty():
		circle(reward_chest.p, s.CHEST_RADIUS, C_INTERACT, 2.0)
		label(reward_chest.p, "宝箱 %.0f" % s.CHEST_RADIUS, C_INTERACT, 22)
	for packet in (s.raid.get("reward_drops", []) if s.raid != null else []):
		circle(packet.p, s.LOOT_RADIUS, C_BULLET, 1.0)
	for drop in s.world_drops:
		circle(drop.p, s.LOOT_RADIUS, C_BULLET, 1.0)
	if me.x > s.ruins.fork_start:
		for index in s.ruins.exits.size():
			var at: Vector2 = s.ruins.exit_position(index)
			circle(at, s.FORK_RADIUS, C_INTERACT, 1.0)
	for p in s.players.values():
		if str(p.get("status", "")) == "down":
			circle(p.p, s.RESCUE_RADIUS, C_RESCUE, 2.0)

# ---------------------------------------------------------------- 批次 2：搜打撤（3D 相机）

func draw_expedition() -> void:
	var s = session()
	if s == null:
		return
	var me: Dictionary = s.players.get(s.my_id(), {})
	var focus: Vector2 = me.p if not me.is_empty() else s.portal_position()
	begin_sim()
	# 角色：地形判定（ruins 默认 15）；倒地队友画救援圈
	if toggle_on("exp_actor"):
		for p in s.players.values():
			circle(p.p, PLAYER_RADIUS, C_PLAYER, 2.0)
			if str(p.status) == "down":
				circle(p.p, s.RESCUE_RADIUS, C_RESCUE, 1.5)
				label(p.p, "倒地 · 救援 %.0f" % s.RESCUE_RADIUS, C_RESCUE, 18)
			elif int(p.id) == int(s.my_id()):
				label(p.p, "地形判定 %.0f" % PLAYER_RADIUS, C_PLAYER, PLAYER_RADIUS + 6)
	# 敌人：体型/地形半径（Ecology.RADIUS，与 battlefield 自己的影子同源）+ 索敌 + 攻击射程
	for e in s.enemies:
		if float(e.hp) <= 0.0:
			continue
		if e.p.distance_to(focus) > DRAW_RANGE:
			continue
		var kind := clampi(int(e.type), 0, Ecology.RADIUS.size() - 1)
		if toggle_on("exp_enemy_body"):
			circle(e.p, Ecology.RADIUS[kind], C_ENEMY, 2.0)
		if toggle_on("exp_enemy_seek"):
			circle(e.p, enemy_seek_radius(s, kind), C_SEEK, 1.0)
		if toggle_on("exp_enemy_reach"):
			circle(e.p, enemy_attack_reach(s, e, kind), C_RANGE, 1.0)
	# 子弹：敌方弹画命中半径圆；玩家弹画本帧扫掠线段（判定就是"线段 ∩ 贴图矩形"）
	if toggle_on("exp_bullet"):
		draw_bullets(s, focus)
	# 场景互动：城门 / 撤离点 / 晨钟封印 / 搜刮容器 / 地面掉落
	if toggle_on("exp_interact"):
		var gate: Vector2 = s.portal_position()
		circle(gate, s.GATE_RADIUS, C_INTERACT, 2.0)
		label(gate, "城门 %.0f" % s.GATE_RADIUS, C_INTERACT, 30)
		for exit_at in s.ruins.exits:
			circle(exit_at, s.EXIT_RADIUS, C_INTERACT, 1.5)
		for shrine in s.ruins.shrines:
			if bool(shrine.get("done", false)):
				continue
			circle(shrine.p, s.SHRINE_RADIUS, C_INTERACT, 1.5)
		for chest in s.ruins.chests:
			if chest.p.distance_to(focus) > DRAW_RANGE:
				continue
			circle(chest.p, s.SEARCH_RADIUS, C_INTERACT, 1.0)
		for drop in s.world_drops:
			if drop.p.distance_to(focus) > DRAW_RANGE:
				continue
			circle(drop.p, s.DROP_RADIUS, C_INTERACT, 1.0)
	if toggle_on("exp_hazard"):
		draw_hazards(s, focus)
	end_sim()
	draw_legend([
		"【开发者模式】判定框总览 · 搜打撤 · CRIMSON_DEV_RANGES=%s" % OS.get_environment("CRIMSON_DEV_RANGES"),
		"绿 角色地形 %.0f ｜ 红 怪物体型 %.0f~%.0f ｜ 青 索敌 %.0f(动态)/%.0f/%.0f" % [PLAYER_RADIUS, Ecology.RADIUS.min(), Ecology.RADIUS.max(), s.ENEMY_SEEK_BASE, Ecology.SEEK_RANGE, s.KNIGHT_SEEK],
		"黄 子弹命中 %.0f(敌弹) / 玩家弹=扫掠线段 ｜ 品红 Boss 伤害域（按权威判定采样）" % CombatVisuals.ENEMY_BOLT_HIT_RADIUS,
		"青 互动：城门 %.0f / 撤离 %.0f / 封印 %.0f / 搜刮 %.0f / 掉落 %.0f / 救援 %.0f ｜ F9 文字 / F10 面板" % [s.GATE_RADIUS, s.EXIT_RADIUS, s.SHRINE_RADIUS, s.SEARCH_RADIUS, s.DROP_RADIUS, s.RESCUE_RADIUS],
	])

# —— 全模式共用的子弹框：敌弹（owner==0）画命中半径圆，玩家弹画本帧扫掠线段 ——
func draw_bullets(s, focus: Vector2) -> void:
	for b in s.bullets:
		if b.p.distance_to(focus) > DRAW_RANGE:
			continue
		if int(b.get("owner", 0)) == 0:
			circle(b.p, float(b.get("hit_radius", CombatVisuals.ENEMY_BOLT_HIT_RADIUS)), C_BULLET, 1.0)
		else:
			segment(b.p - b.v * _dt, b.p, C_BULLET, 1.0)

## 敌人索敌半径：type0-3 随血潮动态（session.enemy_seek_radius）、type4 骑士、
## type≥5 栖息生物（Ecology.SEEK_RANGE）——三套口径互不相同，这里如实分别取用。
func enemy_seek_radius(s, kind: int) -> float:
	if kind <= 3:
		return s.enemy_seek_radius()
	if kind == 4:
		return s.KNIGHT_SEEK
	return Ecology.SEEK_RANGE

## 敌人攻击射程：type0-3 近战接触帧命中半径、type4 骑士招式上限、type≥5 栖息生物起手射程。
func enemy_attack_reach(s, e: Dictionary, kind: int) -> float:
	if kind <= 3:
		return s.ENEMY_MELEE_HIT
	if kind == 4:
		var longest := 0.0
		for move in BossTactics.KNIGHT_MOVES.values():
			longest = maxf(longest, float(move.reach))
		return longest
	return Ecology.attack_reach(kind)

## Boss 伤害域轮廓：**不重算几何**——沿射线对权威判定 `expedition.hazard_contains()` 采样，
## 二分细化出内外边界。形状/字段的单一真值在 boss_geometry.gd + expedition.gd。
func draw_hazards(s, focus: Vector2) -> void:
	var raid = s.raid
	if raid == null:
		return
	for h in raid.get("hazards", []):
		if h.p.distance_to(focus) > DRAW_RANGE + float(h.get("radius", 100.0)):
			continue
		var outline: Array = hazard_outline(s, h)
		for points in outline:
			if points.size() < 3:
				continue
			var loop: PackedVector2Array = points.duplicate()
			loop.append(points[0])
			draw_polyline(loop, C_BOSS, 2.0, true)

func hazard_outline(s, h: Dictionary) -> Array:
	var key := "%s|%s|%s|%s|%s|%s|%s" % [str(h.p), str(h.get("radius", 0.0)), str(h.get("inner", 0.0)),
		str(h.get("arc", 0.0)), str(h.get("gap", 0.0)), str(h.get("shape", "")), str(h.get("aim", Vector2.ZERO))]
	if _hazard_cache.has(key):
		return _hazard_cache[key]
	var extent := float(h.get("radius", 100.0)) + 60.0
	var step := extent / float(HAZARD_COARSE)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in HAZARD_RAYS:
		var direction := Vector2.from_angle(TAU * float(i) / float(HAZARD_RAYS))
		var last_hit := -1.0
		var first_hit := -1.0
		var r := 0.0
		while r <= extent:
			if s.expedition.hazard_contains(h, h.p + direction * r):
				if first_hit < 0.0:
					first_hit = r
				last_hit = r
			r += step
		if last_hit >= 0.0:
			outer.append(h.p + direction * refine(s, h, direction, last_hit, minf(last_hit + step, extent), true))
		if first_hit > step * 1.5:
			inner.append(h.p + direction * refine(s, h, direction, maxf(first_hit - step, 0.0), first_hit, false))
	var result: Array = []
	if outer.size() >= 3:
		result.append(outer)
	if inner.size() >= 3:
		result.append(inner)
	_hazard_cache[key] = result
	return result

## 二分细化：`outward=true` 找"命中→不命中"的跳变，否则找"不命中→命中"的跳变。
func refine(s, h: Dictionary, direction: Vector2, lo: float, hi: float, outward: bool) -> float:
	for _i in HAZARD_REFINE:
		var mid := (lo + hi) * 0.5
		var hit: bool = s.expedition.hazard_contains(h, h.p + direction * mid)
		if hit == outward:
			lo = mid
		else:
			hi = mid
	return lo

# ---------------------------------------------------------------- 批次 3：营地 / 家园

func draw_camp() -> void:
	var h := host()
	if h == null or h.site == null:
		return
	var site = h.site
	begin_sim()
	if toggle_on("camp_actor"):
		circle(site.hero_at, site.ACTOR_RADIUS, C_PLAYER, 2.0)
		label(site.hero_at, "角色地形判定 %.0f" % site.ACTOR_RADIUS, C_PLAYER, 20)
	if toggle_on("camp_station"):
		for station in site.stations:
			var at: Vector2 = station.at + station.offset
			circle(at, float(station.radius), C_CAMP, 1.5)
			label(at, "%s · 交互 %.0f" % [str(station.name), float(station.radius)], C_CAMP, 12)
			# 650 只是"地名名牌"的可见范围（camp_screen.gd:733），与交互半径不同源，画出来给审计用。
			if toggle_on("camp_name"):
				circle(at, 650.0, C_FADE, 1.0)
	if toggle_on("camp_activity"):
		for i in 9:
			circle(site.garden_at(i), CampRules.PLOT_RADIUS, C_PLAYER, 1.0)
		circle(CampRules.PIER_AT, CampRules.PIER_RADIUS, C_INTERACT, 1.5)
		label(CampRules.PIER_AT, "栈桥抛竿 %.0f" % CampRules.PIER_RADIUS, C_INTERACT, 16)
		var activities = h.activities
		if activities != null:
			for drop in activities.drops:
				circle(drop.get("at", Vector2.ZERO), CampRules.DROP_RADIUS, C_BULLET, 1.0)
	end_sim()
	draw_legend([
		"【开发者模式】判定框总览 · 营地 · CRIMSON_DEV_RANGES=%s" % OS.get_environment("CRIMSON_DEV_RANGES"),
		"青 设施交互圈（半径真值＝站点表 stations[].radius）｜ 灰 地名名牌可见 650（与交互半径不同源）",
		"绿 角色地形 %.0f / 田畦 %.0f ｜ 青 栈桥抛竿 %.0f ｜ 黄 地面拾取 %.0f ｜ F9 文字 / F10 面板" % [site.ACTOR_RADIUS, CampRules.PLOT_RADIUS, CampRules.PIER_RADIUS, CampRules.DROP_RADIUS],
	])

# ---------------------------------------------------------------- 批次 4：故事模式

func draw_story() -> void:
	var h := host()
	if h == null or h.campaign == null:
		return
	var c = h.campaign
	if c.state.is_empty(): return
	if c.state.get("revision","")=="scarlet-1":
		begin_sim()
		circle(c.hero_at,float(c.INTERACT_RADIUS),C_INTERACT,1.5)
		for item in c.objective_nodes(): circle(item.p,float(c.INTERACT_RADIUS),C_READY,1.0)
		end_sim()
		return
	var hero: Vector2 = c.hero_at
	begin_sim()
	# 玩家：普攻判定半径（刀光只画到 245，判定圈更大）+ 近身无条件命中圈
	if toggle_on("story_hero"):
		var attack := float(c.HERO_ATTACK[clampi(int(c.state.get("hero", 0)), 0, 2)])
		circle(hero, attack, C_RANGE, 2.0)
		label(hero, "普攻判定 %.0f（刀光只画 245；技能1 %.0f / 奥义 %.0f）" % [attack, c.HERO_SPECIAL[0], c.HERO_SPECIAL[1]], C_RANGE, 24)
	if toggle_on("story_melee"):
		circle(hero, float(c.HERO_MELEE_HIT), C_PLAYER, 1.5)
	# 敌人：索敌 / 出手 / 休眠 + 前摇 AoE（形状 circle / ring / cross）
	for e in c.enemies:
		if float(e.hp) <= 0.0:
			continue
		if e.p.distance_to(hero) > 1100.0:
			continue
		var idx := 0 if bool(e.get("boss", false)) else 1
		if toggle_on("story_enemy"):
			circle(e.p, float(c.ENEMY_CHASE[idx]), C_SEEK, 1.0)
			circle(e.p, float(c.ENEMY_STRIKE[idx]), C_RANGE, 1.0)
			circle(e.p, float(c.ENEMY_SLEEP), C_FADE, 1.0)
		if toggle_on("story_windup") and float(e.get("windup", 0.0)) > 0.0:
			circle(e.target, float(e.radius), C_ENEMY, 2.0)
			if str(e.get("shape", "")) == "ring":
				circle(e.target, float(c.BOSS_RING_INNER), C_ENEMY, 1.0)
			elif str(e.get("shape", "")) == "cross":
				var arm := float(c.BOSS_CROSS_ARM)
				segment(e.target - Vector2(arm, 0), e.target + Vector2(arm, 0), C_ENEMY, 2.0)
				segment(e.target - Vector2(0, arm), e.target + Vector2(0, arm), C_ENEMY, 2.0)
	# 伙伴：索敌 / 攻击事件 / 跟随
	if toggle_on("story_ally"):
		for at in c.allies:
			circle(at, float(c.ALLY_SEEK), C_CAMP, 1.0)
			circle(at, float(c.ALLY_EVENT), C_CAMP, 1.0)
			circle(at, float(c.ALLY_FOLLOW), C_CAMP, 1.0)
	# 交互：全部是"英雄到可交互物的距离"判定，所以圈画在**物**上。
	# 白细线＝提示圈（PROMPT_RADIUS，走到就出 [E]）；青＝使用半径（按下去真的生效）；
	# 绿＝英雄此刻已在使用半径内；红＝距离够了但被威胁门挡住（镜像 `interact_object()` 的
	# 距离 + 威胁两道门；`available(q)` 那道门覆盖层不复算，只如实标出距离/威胁）。
	if toggle_on("story_object"):
		for node in c.objective_nodes():
			_interact_rings(c, hero, node.p, float(c.OBJECT_USE), true)
			circle(node.p, float(c.THREAT_BLOCK), C_FADE, 1.0)
			label(node.p, "任务物 · 提示 %.0f / 使用 %.0f" % [c.PROMPT_RADIUS, c.OBJECT_USE], C_INTERACT, 14)
	if toggle_on("story_cache"):
		for chest in c.nearby_chests():
			_interact_rings(c, hero, chest.p, float(c.CACHE_USE), false)
			label(chest.p, "宝箱 · 提示 %.0f / 使用 %.0f" % [c.PROMPT_RADIUS, c.CACHE_USE], C_INTERACT, 14)
	if toggle_on("story_door"):
		for door in _local_entrances(c):
			_interact_rings(c, hero, door.p, float(c.ENTRANCE_USE), false)
	if toggle_on("story_waypoint"):
		var waypoint: Vector2 = c.map.waypoint
		_interact_rings(c, hero, waypoint, float(c.WAYPOINT_USE), false)
		label(waypoint, "传送阵 %.0f（HUD 按钮 %.0f）" % [c.WAYPOINT_USE, c.WAYPOINT_BUTTON], C_INTERACT, 18)
	if toggle_on("story_npc"):
		draw_story_npcs(c, hero)
	if toggle_on("story_building"):
		draw_story_buildings(c, hero)
	end_sim()
	draw_legend([
		"【开发者模式】判定框总览 · 故事 · CRIMSON_DEV_RANGES=%s" % OS.get_environment("CRIMSON_DEV_RANGES"),
		"黄 普攻判定 %.0f/%.0f/%.0f（技能1 %.0f / 奥义 %.0f；刀光只画到 245）｜ 绿 近身无条件 %.0f" % [c.HERO_ATTACK[0], c.HERO_ATTACK[1], c.HERO_ATTACK[2], c.HERO_SPECIAL[0], c.HERO_SPECIAL[1], c.HERO_MELEE_HIT],
		"青 敌人索敌 %.0f/%.0f ｜ 黄 出手 %.0f/%.0f ｜ 灰 休眠 %.0f ｜ 红 前摇 AoE（ring 内圈 %.0f / cross 臂 %.0f）" % [c.ENEMY_CHASE[0], c.ENEMY_CHASE[1], c.ENEMY_STRIKE[0], c.ENEMY_STRIKE[1], c.ENEMY_SLEEP, c.BOSS_RING_INNER, c.BOSS_CROSS_ARM],
		"白 提示圈 %.0f ｜ 青 使用圈：任务物 %.0f / 宝箱 %.0f / 门洞 %.0f / 传送阵 %.0f（按钮 %.0f）｜ 绿 已在圈内 ｜ 红 被威胁门挡 ｜ F9 文字 / F10 面板" % [c.PROMPT_RADIUS, c.OBJECT_USE, c.CACHE_USE, c.ENTRANCE_USE, c.WAYPOINT_USE, c.WAYPOINT_BUTTON],
	])

## 提示圈（白细）+ 使用圈（绿/青/红）成对画，用于核对"提示出现 = 一定能按键"。
func _interact_rings(campaign, hero: Vector2, at: Vector2, use_radius: float, threat_gated: bool) -> void:
	circle(at, float(campaign.PROMPT_RADIUS), C_PROMPT, 0.8)
	var color := C_USE
	if hero.distance_to(at) <= use_radius:
		color = C_READY
		if threat_gated and toggle_on("common_blocked") and _threat_blocked(campaign, at):
			color = C_BLOCKED
	circle(at, use_radius, color, 1.6)

## 威胁门：`story_campaign.interact_object()` 里"附近 260 内有活敌 → 先解除威胁"。
func _threat_blocked(campaign, at: Vector2) -> bool:
	for e in campaign.enemies:
		if float(e.hp) > 0.0 and e.p.distance_to(at) < float(campaign.THREAT_BLOCK):
			return true
	return false

## 门只画**当前区域**的：`story_map.entrances()` 在户外会把别的户外区域的门也返回
## （`story_map.gd:139`），它们的世界坐标可能在远处甚至水里，画出来会误导。
func _local_entrances(c) -> Array:
	var stage := int(c.state.stage)
	var region = c.map.regions[stage]
	var origin: Vector2 = region.origin
	var extent: Vector2 = region.extent
	var box := Rect2(origin, extent).grow(400.0)
	var result: Array = []
	for door in c.map.entrances():
		if box.has_point(door.p):
			result.append(door)
	return result

## NPC 互动圈：位置真值 `story_map.npc_at`（世界坐标），门控复用 `PROMPT_RADIUS`
## （`story_screen.gd:217/232`，没有独立常量），且只有营地（stage 0）的 NPC 可交互。
func draw_story_npcs(c, hero: Vector2) -> void:
	if int(c.state.stage) != 0:
		return
	for i in c.map.npc_at.size():
		var at: Vector2 = c.map.npc_at[i]
		var color := C_READY if hero.distance_to(at) <= float(c.PROMPT_RADIUS) else C_INTERACT
		circle(at, float(c.PROMPT_RADIUS), color, 1.6)
		label(at, "NPC %d · 互动 %.0f" % [i, c.PROMPT_RADIUS], color, 12)

## 建筑碰撞箱：真值＝`region.buildings[].rect`（局部 Rect2）+ 公开函数
## `story_region.building_walls(rect)` 现算的 5 段 28 厚墙（南墙留 110 门洞，与
## `story_environment.gd:416-417` 摆的墙块同源）。act≥2 的户外/室内体积来自烘焙网格，
## 代码侧只有"被挡矩形"（`structural_obstacles` / `obstacles`，不按建筑分组），一并画出来。
func draw_story_buildings(c, hero: Vector2) -> void:
	var region = c.map.regions[int(c.state.stage)]
	var origin: Vector2 = region.origin
	for building in region.buildings:
		var rect: Rect2 = Rect2(building.rect.position + origin, building.rect.size)
		if rect.position.distance_to(hero) > DRAW_RANGE:
			continue
		rect_outline(rect, C_BUILD, 2.0, Color(C_BUILD.r, C_BUILD.g, C_BUILD.b, .10))
		for wall in region.building_walls(rect):
			rect_outline(wall, C_WALL, 1.0)
	for source in [region.structural_obstacles, region.obstacles]:
		for local in source:
			var rect: Rect2 = Rect2(local.position + origin, local.size)
			if rect.position.distance_to(hero) > DRAW_RANGE:
				continue
			rect_outline(rect, C_OBSTACLE, 1.0)
