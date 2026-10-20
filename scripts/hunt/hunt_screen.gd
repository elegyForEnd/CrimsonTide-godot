extends Control
## 血潮深潜 · 模式页面
##
## 三层：SubViewport 里的固定第一人称 3D 舞台 → 2D 热点/敌人 → HUD 与面板。
## 规则全部在 `hunt_run.gd`；这里只发动作、读字段、画界面，不写存档。
## 营地入口由 main.gd 调用 `show_briefing()`，返回营地走 `exit_requested`。

signal exit_requested
signal run_finished(result: Dictionary)

const Run = preload("res://scripts/hunt/hunt_run.gd")
const Stage = preload("res://scripts/hunt/hunt_stage.gd")
const Art = preload("res://scripts/hunt/hunt_art.gd")
const Portrait = preload("res://scripts/hunt/hunt_portrait.gd")
const MapView = preload("res://scripts/hunt/hunt_map_view.gd")
const Data = preload("res://scripts/hunt/hunt_data.gd")

const BG := Color("0b0d13")
const PANEL := Color("121722")
const PANEL_2 := Color("171d29")
const INK := Color("e7dfd5")
const MUTED := Color("979aa8")
const GOLD := Color("cbb087")
const RED := Color("c95666")
const GREEN := Color("8fbf9b")
const BLUE := Color("8fb7c9")
const DIM := Color("5f6370")
const CARD := Color("1a202c")

const VIEW := Vector2(1440, 900)
const HERO_CARD_W := 270.0
const HERO_CARD_H := 470.0

var profile: Profile
var sound
var run
var mode := "idle" # idle / briefing / run / result
var selected_hero := 0
var active := false

var title_font: Font
var face_font: Font

var stage_container: SubViewportContainer
var stage_view: SubViewport
var stage
var vignette: TextureRect

var hotspot_layer: Control
var hud: Control
var area_label: Label
var area_desc: Label
var day_label: Label
var timer_label: Label
var phase_label: Label
var phase_icon: TextureRect
var timer_bar
var hint_label: Label
var portrait
var hero_name_label: Label
var hp_bar
var sp_bar
var hp_text: Label
var sp_text: Label
var attack_label: Label
var defense_label: Label
var bag_label: Label
var log_label: Label
var combat_text: Node2D
var extract_button: Button
var rest_button: Button

var briefing: Control
var result_layer: Control
var map_overlay: Control
var map_view
var craft_overlay: Control
var craft_list: VBoxContainer
var craft_rows: Dictionary = {}
var craft_cat := "all"
var craft_buttons: Dictionary = {}
var bag_overlay: Control
var bag_grid: GridContainer
var combat_panel: Panel
var combat_enemy_art: TextureRect
var combat_name: Label
var combat_hp
var combat_hp_text: Label
var combat_attack: Button
var combat_heavy: Button
var combat_trap: Button
var combat_flare: Button
var combat_smoke: Button
var combat_flee: Button
var pause_layer: Control
var result_built_for := ""
var pocket_overlay: Control
var pocket_list: VBoxContainer
var pocket_hint: Label
var pocket_button: Button
var event_overlay: Control
var event_title: Label
var event_sub: Label
var event_art: TextureRect
var event_log: Label
var event_options: VBoxContainer
var event_option_buttons: Array = []
var event_action_box: Control
var event_action_bar
var event_action_label: Label
var event_action_hint: Label
var event_puzzle_box: Control
var event_puzzle_sig := ""
var event_puzzle_hint: Label
var event_puzzle_seal: TextureRect
var event_puzzle_art: TextureRect
var event_seal: TextureRect
var event_was_puzzle := false
var event_open := false
var event_sig := ""
# 搜索仪式：屏幕中央的探针 + 血环 + 进度环，只在 run.search 非空时出现。
var search_fx: Control
var search_fx_probe: TextureRect
var search_fx_ring
var search_fx_label: Label
var search_fx_hint: Label
var search_fx_was_active := false
var search_fx_break := 0.0
var search_fx_hide := 0.0
var search_fx_last_searched := 0

var spot_nodes: Dictionary = {}
var enemy_nodes: Dictionary = {}
var site_nodes: Dictionary = {}
var search_button: Button
var form_button: Button
var toast_layer: Control
var toast_slot := 0
var info_labels: Array = []
var marker_signature := ""
var overlay_kind := ""
var last_result: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	visible = false
	var serif := FontVariation.new()
	serif.base_font = load("res://assets/NotoSerifSC.ttf")
	title_font = serif
	var face := FontVariation.new()
	face.base_font = load("res://assets/NotoSansSC.ttf")
	face.variation_opentype = {"wght": 420.0}
	face_font = face
	_ensure_stage()
	vignette = TextureRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 256
	grad_tex.height = 256
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette.texture = grad_tex
	add_child(vignette)
	hotspot_layer = Control.new()
	hotspot_layer.name = "Hotspots"
	hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hotspot_layer)
	hud = Control.new()
	hud.name = "HuntHUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	# 中上方的浮动提示：单条、自动上浮淡出；多条就错位叠着走。
	toast_layer = Control.new()
	toast_layer.name = "HuntToasts"
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_layer)

func set_context(p_profile: Profile, p_sound = null) -> void:
	profile = p_profile
	sound = p_sound
	selected_hero = clampi(int(profile.data.get("hero", 0)), 0, profile.roster_size() - 1)

func set_active(value: bool) -> void:
	active = value
	visible = value
	set_process(value)
	if not value:
		_close_overlay(true)
		if run and not run.ended_flag:
			run.set_paused(true)

func _ensure_stage() -> void:
	if stage_container and is_instance_valid(stage_container):
		return
	stage_view = SubViewport.new()
	stage_view.name = "HuntViewport"
	stage_view.size = Vector2i(1440, 900)
	stage_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage_view.own_world_3d = true
	stage_view.msaa_3d = Viewport.MSAA_2X
	stage = Stage.new()
	stage.name = "HuntStage"
	stage_view.add_child(stage)
	stage_container = SubViewportContainer.new()
	stage_container.name = "HuntStageView"
	stage_container.stretch = true
	stage_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_container)
	stage_container.add_child(stage_view)

func _build_stage(area_id: String, phase: String) -> void:
	_ensure_stage()
	if stage.area_id != area_id or stage.phase != phase or not stage.built:
		stage.build(area_id, phase)

func show_briefing() -> void:
	mode = "briefing"
	run = null
	if hud:
		hud.visible = false
	if hotspot_layer:
		hotspot_layer.visible = false
	if result_layer:
		_clear(result_layer)
		result_layer = null
	_close_overlay(false)
	if vignette:
		vignette.visible = true
	_build_stage(Data.CAMP_AREA, "day")
	_clear(briefing)
	briefing = Control.new()
	briefing.name = "Briefing"
	briefing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(briefing)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	briefing.add_child(dim)
	_label(briefing, "血 潮 深 潜", Vector2(70, 42), Vector2(760, 70), 46, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	_label(briefing, "C R I M S O N   D I V E   /   三 日 禁 区", Vector2(74, 112), Vector2(760, 30), 15, GOLD)
	_label(briefing, "在血潮漫上来之前，搜到能活过第三夜的东西。", Vector2(74, 154), Vector2(900, 32), 19, MUTED)
	_label(briefing, "8 分钟 = 1 天，共 3 天。搜索消耗体力，地区资源有限；搜到的东西可以在局内合成。\n撤离成功才能把战利品带回晨钟家园；倒下就什么都没有。", Vector2(74, 192), Vector2(1180, 58), 16, MUTED)
	var slot := 0
	for hero in 4:
		var unlocked := hero < profile.roster_size()
		var x := 74.0 + slot * (HERO_CARD_W + 26.0)
		var card := _panel(briefing, Vector2(x, 262), Vector2(HERO_CARD_W, HERO_CARD_H), Color(0.055, 0.065, 0.095, 0.94), hero == selected_hero)
		if not unlocked:
			card.modulate = Color(0.62, 0.62, 0.66, 0.95)
		var art = Portrait.new()
		art.name = "HeroPortrait%d" % hero
		art.size = Vector2(HERO_CARD_W - 22, 300)
		art.position = Vector2(11, 10)
		art.set_hero(hero)
		card.add_child(art)
		var hd: Dictionary = Catalog.HEROES[hero]
		_label(card, str(hd.name), Vector2(16, 316), Vector2(220, 32), 26, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
		_label(card, str(hd.title), Vector2(16, 348), Vector2(240, 18), 13, GOLD)
		if unlocked:
			var desc := _label(card, "%s\nHP %d · 攻击 %d" % [str(hd.desc), int(hd.hp), int(hd.damage)],
				Vector2(16, 366), Vector2(238, 54), 10, MUTED, HORIZONTAL_ALIGNMENT_LEFT, null, true)
			desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		else:
			var hint := _label(card, "隐藏角色\n抵达护身符结局后解锁", Vector2(16, 370), Vector2(238, 60), 12, MUTED,
				HORIZONTAL_ALIGNMENT_LEFT, null, true)
			hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		var choose := _button(card, "选择" if unlocked else "未解锁", Vector2(16, 426), Vector2(238, 36), func(): _select_hero(hero), hero == selected_hero)
		choose.disabled = not unlocked
		slot += 1
	# 随身物：深潜自己的 3 格口袋。只能从营地仓库拿普通物品进来，且带进来就回不去。
	_panel(briefing, Vector2(74, 744), Vector2(1180, 56), Color(0.05, 0.058, 0.082, 0.94))
	_label(briefing, "随 身 物", Vector2(90, 752), Vector2(84, 40), 15, GOLD, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	var slots := profile.hunt_pocket()
	for i in 3:
		var at := Vector2(178.0 + i * 142.0, 752)
		var text := "空"
		if i < slots.size():
			var entry: Dictionary = slots[i]
			text = "%s ×%d" % [Data.item_name(str(entry.get("kind", ""))), int(entry.get("count", 1))]
		var b := _button(briefing, text, at, Vector2(134, 40), func(): _open_pocket_picker(), false)
		b.name = "HuntPocket%d" % i
		b.add_theme_font_size_override("font_size", 12)
	var take := _button(briefing, "从营地仓库取物", Vector2(612, 752), Vector2(190, 40), func(): _open_pocket_picker(), true)
	take.name = "HuntPocketTake"
	var warn := _label(briefing, "深潜只认它自己的规矩：从这里带下去的东西，血潮不会再让它回到营地。",
		Vector2(814, 750), Vector2(430, 44), 12, Color("b58f8a"), HORIZONTAL_ALIGNMENT_LEFT, null, true)
	warn.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label(briefing, "已解锁 %d / 4 名守夜人。每次进入深潜只带一名角色；武器、防具与饰品都带不出来。" % profile.roster_size(),
		Vector2(74, 806), Vector2(1000, 26), 14, MUTED)
	var back := _button(briefing, "返回营地", Vector2(74, 842), Vector2(200, 44), func(): exit_requested.emit())
	back.name = "HuntBack"
	var start := _button(briefing, "进入深潜  →", Vector2(1060, 824), Vector2(300, 62), func(): _start_selected(), true)
	start.name = "HuntStart"
	start.add_theme_font_size_override("font_size", 24)
	visible = true
	set_process(true)
	active = true

func _select_hero(hero: int) -> void:
	if hero >= profile.roster_size():
		return
	selected_hero = hero
	show_briefing()

func _start_selected() -> void:
	if selected_hero >= profile.roster_size():
		return
	_close_pocket_picker()
	start_run(selected_hero)

# ------------------------------------------------------------ 随身物（简报）
# 3 格，只能从营地仓库取普通物品。取走即从仓库消失——带进深潜的东西
# 不会被血潮放回营地，这是玩法的一部分，不是 bug。

func _open_pocket_picker() -> void:
	if pocket_overlay == null or not is_instance_valid(pocket_overlay):
		_build_pocket_picker()
	pocket_overlay.visible = true
	_refresh_pocket_picker()

func _close_pocket_picker() -> void:
	if pocket_overlay and is_instance_valid(pocket_overlay):
		pocket_overlay.visible = false

func _build_pocket_picker() -> void:
	pocket_overlay = Control.new()
	pocket_overlay.name = "HuntPocketPicker"
	pocket_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pocket_overlay.visible = false
	pocket_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pocket_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.012, 0.016, 0.024, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pocket_overlay.add_child(dim)
	var panel := _panel(pocket_overlay, Vector2(300, 70), Vector2(840, 760), Color(0.03, 0.04, 0.06, 0.99))
	panel.name = "PocketPanel"
	_label(panel, "从 营 地 仓 库 取 物", Vector2(28, 18), Vector2(600, 40), 28, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	_label(panel, "只挑三件普通物品。它们会离开仓库，跟着你沉进血潮——带不回来。",
		Vector2(30, 58), Vector2(780, 44), 13, Color("b58f8a"), HORIZONTAL_ALIGNMENT_LEFT, null, true)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(26, 112)
	scroll.size = Vector2(788, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", _style(Color(0.02, 0.03, 0.045, 0.9), Color(0.18, 0.20, 0.25)))
	panel.add_child(scroll)
	pocket_list = VBoxContainer.new()
	pocket_list.name = "PocketList"
	pocket_list.custom_minimum_size = Vector2(770, 0)
	pocket_list.add_theme_constant_override("separation", 4)
	scroll.add_child(pocket_list)
	pocket_hint = _label(panel, "", Vector2(30, 684), Vector2(560, 30), 13, GOLD)
	_button(panel, "关闭", Vector2(660, 680), Vector2(150, 44), func(): _close_pocket_picker())
	_refresh_pocket_picker()

func _refresh_pocket_picker() -> void:
	if pocket_list == null:
		return
	for child in pocket_list.get_children():
		child.queue_free()
	var pockets: Array = profile.hunt_pocket()
	var room: int = 3 - pockets.size()
	for i in profile.warehouse_items().size():
		var item: Dictionary = profile.warehouse_item(i)
		if item.is_empty():
			continue
		var kind := str(item.get("kind", ""))
		if not Catalog.hunt_exportable(kind):
			continue
		var row := Panel.new()
		row.custom_minimum_size = Vector2(760, 46)
		row.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.085, 0.82), Color(0.16, 0.18, 0.22)))
		var icon := TextureRect.new()
		icon.texture = Art.icon(kind)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(8, 7)
		icon.size = Vector2(32, 32)
		icon.modulate = Art.icon_modulate(kind)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		_label(row, Catalog.item_name(item), Vector2(50, 6), Vector2(430, 34), 15, INK)
		_label(row, "×%d" % int(item.get("count", 1)), Vector2(470, 6), Vector2(90, 34), 13, GOLD)
		var b := _button(row, "带下去", Vector2(600, 5), Vector2(150, 36), func(): _take_pocket_item(i), true)
		b.disabled = room <= 0
		pocket_list.add_child(row)
	if profile.warehouse_items().is_empty():
		var empty := _label(pocket_list, "仓库是空的。先去搜打撤里带点东西回来。", Vector2(10, 10), Vector2(700, 40), 15, MUTED)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if pocket_hint:
		pocket_hint.text = "随身物 %d / 3。撤离成功也会随机沉掉 2~3 件。" % profile.hunt_pocket_count()

func _take_pocket_item(index: int) -> void:
	if profile.hunt_pocket_take(index):
		if pocket_overlay and pocket_overlay.visible:
			_refresh_pocket_picker()
		show_briefing()
		if pocket_overlay:
			pocket_overlay.visible = true
	else:
		if pocket_hint:
			pocket_hint.text = "随身物已经满了，或者这件东西带不进去。"

func start_run(hero: int) -> void:
	_clear(briefing)
	briefing = null
	if result_layer:
		_clear(result_layer)
		result_layer = null
	if pause_layer:
		pause_layer.visible = false
	mode = "run"
	hud.visible = true
	hotspot_layer.visible = true
	vignette.visible = true
	run = Run.new()
	run.setup(hero, 0, int(profile.data.get("gear", -1)), profile.data.get("talents", [0, 0, 0]), profile.hunt_pocket())
	run.changed.connect(_on_run_changed)
	run.logged.connect(_on_run_log)
	run.finished.connect(_on_run_finished)
	run.floated.connect(_on_run_float)
	_build_stage(run.area_id, run.phase_id())
	_build_run_ui()
	_refresh_all()
	visible = true
	set_process(true)
	active = true

# ------------------------------------------------------------------ run HUD

func _build_run_ui() -> void:
	_clear_children(hud)
	_clear_children(hotspot_layer)
	_clear_children(toast_layer)
	toast_slot = 0
	spot_nodes.clear()
	enemy_nodes.clear()
	marker_signature = ""
	search_fx_was_active = false
	search_fx_break = 0.0
	search_fx_hide = 0.0
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top-left area plaque.
	_panel(hud, Vector2(24, 20), Vector2(370, 92), Color(0.035, 0.045, 0.07, 0.86))
	area_label = _label(hud, "", Vector2(44, 30), Vector2(330, 34), 25, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	area_desc = _label(hud, "", Vector2(44, 66), Vector2(334, 34), 12, MUTED, HORIZONTAL_ALIGNMENT_LEFT, null, true)
	# Top-centre timer.
	_panel(hud, Vector2(520, 18), Vector2(400, 98), Color(0.035, 0.045, 0.07, 0.88))
	day_label = _label(hud, "", Vector2(542, 26), Vector2(160, 26), 17, GOLD)
	phase_icon = _hud_icon(hud, "ui_day", Vector2(676, 29), Vector2(18, 18), Color("e8d8b0"))
	phase_label = _label(hud, "", Vector2(700, 26), Vector2(90, 26), 15, BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	timer_label = _label(hud, "", Vector2(790, 22), Vector2(112, 32), 26, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	timer_bar = _bar(hud, Vector2(542, 62), Vector2(356, 9), RED)
	hint_label = _label(hud, "", Vector2(542, 75), Vector2(356, 20), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	# Top-right mode buttons.
	_button(hud, "地图  M", Vector2(1078, 24), Vector2(106, 40), _open_map)
	_button(hud, "合成  C", Vector2(1192, 24), Vector2(106, 40), _open_craft)
	var bag_button := _button(hud, "背包  Tab", Vector2(1306, 24), Vector2(110, 40), _open_bag)
	bag_button.name = "HuntBagButton"
	# V2 形态切换：行动 act / 隐藏 hide（Z）。
	form_button = _button(hud, "形态：行动  Z", Vector2(24, 118), Vector2(186, 38), _do_form)
	form_button.name = "HuntFormButton"
	# 随身物：深潜自己的 3 格口袋，跨局保留，撤离/阵亡都会损耗。
	pocket_button = _button(hud, "随身物", Vector2(218, 118), Vector2(140, 38), func(): _open_overlay("pocket"))
	pocket_button.name = "HuntPocketButton"
	pocket_button.add_theme_font_size_override("font_size", 14)
	# 立绘：不再垫底板，整张透明 PNG 直接浮在场景上。
	portrait = Portrait.new()
	portrait.name = "HuntPortrait"
	portrait.size = Vector2(300, 300)
	portrait.position = Vector2(36, 296)
	portrait.set_hero(run.hero)
	hud.add_child(portrait)
	hero_name_label = _label(hud, str(run.hero_data.name), Vector2(36, 226), Vector2(300, 34), 24, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	_label(hud, str(run.hero_data.title), Vector2(36, 260), Vector2(300, 22), 12, GOLD)
	# 详细信息窗口：可滚动；血条/体力条在下面单独一个窗口，滚动永远不会把它们滚走。
	_panel(hud, Vector2(16, 604), Vector2(340, 196), Color(0.03, 0.038, 0.06, 0.88))
	var info_scroll := ScrollContainer.new()
	info_scroll.name = "HuntInfoScroll"
	info_scroll.position = Vector2(24, 610)
	info_scroll.size = Vector2(324, 184)
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	info_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hud.add_child(info_scroll)
	var info_box := VBoxContainer.new()
	info_box.name = "HuntInfoBox"
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 6)
	info_scroll.add_child(info_box)
	info_labels.clear()
	for i in 8:
		var line := Label.new()
		line.text = ""
		line.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		line.add_theme_font_override("font", face_font)
		line.add_theme_font_size_override("font_size", 12)
		line.add_theme_color_override("font_color", MUTED)
		info_box.add_child(line)
		info_labels.append(line)
	_panel(hud, Vector2(16, 806), Vector2(340, 82), Color(0.04, 0.048, 0.075, 0.92))
	_hud_icon(hud, "ui_hp", Vector2(26, 815), Vector2(16, 16), Color(1.0, 0.52, 0.56))
	hp_bar = _bar(hud, Vector2(48, 816), Vector2(220, 14), RED)
	hp_text = _label(hud, "", Vector2(274, 812), Vector2(76, 20), 12, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_icon(hud, "ui_stamina", Vector2(26, 839), Vector2(16, 16), Color(0.62, 1.0, 0.68))
	sp_bar = _bar(hud, Vector2(48, 840), Vector2(220, 12), GREEN)
	sp_text = _label(hud, "", Vector2(274, 836), Vector2(76, 20), 12, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_icon(hud, "ui_attack", Vector2(26, 859), Vector2(16, 16), Color("e8c07a"))
	attack_label = _label(hud, "", Vector2(46, 858), Vector2(126, 24), 12, GOLD)
	_hud_icon(hud, "ui_defense", Vector2(176, 859), Vector2(16, 16), Color("9fc4d8"))
	defense_label = _label(hud, "", Vector2(196, 858), Vector2(150, 24), 12, BLUE, HORIZONTAL_ALIGNMENT_RIGHT)
	# Bottom action strip: 搜索 / 合成 / 背包 / 地图 / 休息 / 撤离。
	_panel(hud, Vector2(356, 806), Vector2(720, 82), Color(0.035, 0.045, 0.07, 0.90))
	search_button = _button(hud, "搜索  W", Vector2(364, 820), Vector2(108, 54), _do_search, true)
	search_button.name = "HuntSearchButton"
	_button(hud, "合成  C", Vector2(480, 820), Vector2(108, 54), _open_craft)
	_button(hud, "背包 Tab", Vector2(596, 820), Vector2(108, 54), _open_bag)
	_button(hud, "地图  M", Vector2(712, 820), Vector2(108, 54), _open_map)
	rest_button = _button(hud, "休息  R", Vector2(828, 820), Vector2(108, 54), func(): run.rest(); _refresh_all())
	extract_button = _button(hud, "撤离", Vector2(944, 820), Vector2(108, 54), func(): run.extract(); _refresh_all(), true)
	# Log.
	_panel(hud, Vector2(1080, 700), Vector2(340, 190), Color(0.035, 0.045, 0.07, 0.78))
	_label(hud, "记录", Vector2(1096, 708), Vector2(120, 22), 13, GOLD)
	log_label = _label(hud, "", Vector2(1096, 732), Vector2(308, 150), 12, MUTED, HORIZONTAL_ALIGNMENT_LEFT, null, true)
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_build_combat_panel()
	combat_text = preload("res://scripts/combat_text.gd").new()
	combat_text.name = "HuntCombatText"
	hud.add_child(combat_text)
	_build_search_fx()
	_build_map_overlay()
	_build_craft_overlay()
	_build_bag_overlay()
	_build_pocket_overlay()
	_build_event_window()
	_build_pause_overlay()

func _on_run_changed() -> void:
	if run == null:
		return
	_refresh_all()

func _on_run_log(text: String) -> void:
	if log_label != null:
		var lines: Array = run.logs.slice(maxi(0, run.logs.size() - 7))
		log_label.text = "\n".join(lines)
	if not text.strip_edges().is_empty() and mode == "run":
		_spawn_toast(text)

func _on_run_float(kind: String, anchor: String, amount: float, heavy: bool) -> void:
	if combat_text == null or not is_instance_valid(combat_text) or run == null:
		return
	var at := Vector2.ZERO
	if anchor == "enemy" and combat_panel != null:
		at = combat_panel.position + Vector2(140, 8)
	elif portrait != null:
		at = portrait.position + Vector2(250, 60)
	else:
		at = Vector2(186, 360)
	combat_text.push(kind, at, amount, {"heavy": heavy})

## 中上方浮动提示：单条上浮 + 渐隐；多条（短时间内）错位叠着出现。
func _spawn_toast(text: String) -> void:
	if toast_layer == null:
		return
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = Art.toast_style()
	if style == null:
		var flat := _style(Color(0.03, 0.035, 0.05, 0.86), Color(0.62, 0.50, 0.38, 0.85))
		flat.set_corner_radius_all(10)
		flat.content_margin_left = 18
		flat.content_margin_right = 18
		flat.content_margin_top = 9
		flat.content_margin_bottom = 9
		style = flat
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", face_font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.84))
	panel.add_child(label)
	toast_layer.add_child(panel)
	var width := minf(760.0, face_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 40.0)
	panel.size = Vector2(width, 44)
	label.position = Vector2(18, 10)
	label.size = Vector2(width - 36, 24)
	var slot := toast_slot % 3
	toast_slot += 1
	var start := Vector2(720.0 - width * 0.5, 150.0 + slot * 36.0)
	panel.position = start
	panel.modulate = Color(1, 1, 1, 0.0)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.95, 0.16)
	tween.parallel().tween_property(panel, "position:y", start.y - 46.0, 2.0).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.05)
	tween.tween_property(panel, "modulate:a", 0.0, 0.45)
	tween.tween_callback(panel.queue_free)

## 搜索仪式：屏幕中央一枚血锈探针在轻微摆动，外面一圈血环一圈圈填满。
## 它只在 `run.search` 非空时出现；被打断会红一下再散掉，正常搜完是金色收束。
func _build_search_fx() -> void:
	search_fx = Control.new()
	search_fx.name = "HuntSearchFX"
	search_fx.position = Vector2(520, 236)
	search_fx.size = Vector2(400, 330)
	search_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_fx.visible = false
	hud.add_child(search_fx)
	var back := Panel.new()
	back.position = Vector2(80, 0)
	back.size = Vector2(240, 240)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.012, 0.015, 0.022, 0.55)
	plate.border_color = Color(0.30, 0.20, 0.20, 0.55)
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(120)
	back.add_theme_stylebox_override("panel", plate)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_fx.add_child(back)
	search_fx_ring = SearchRing.new()
	search_fx_ring.position = Vector2(80, 0)
	search_fx_ring.size = Vector2(240, 240)
	search_fx_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_fx.add_child(search_fx_ring)
	search_fx_probe = TextureRect.new()
	search_fx_probe.name = "SearchProbe"
	search_fx_probe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	search_fx_probe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	search_fx_probe.position = Vector2(130, 50)
	search_fx_probe.size = Vector2(140, 140)
	search_fx_probe.pivot_offset = Vector2(70, 70)
	search_fx_probe.texture = Art.search_probe()
	search_fx_probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_fx.add_child(search_fx_probe)
	# 文字压在一条半透明石板上，不然浅色地面会把提示吃掉。
	var text_back := Panel.new()
	text_back.position = Vector2(64, 246)
	text_back.size = Vector2(272, 72)
	var text_plate := StyleBoxFlat.new()
	text_plate.bg_color = Color(0.02, 0.024, 0.033, 0.82)
	text_plate.border_color = Color(0.32, 0.22, 0.22, 0.6)
	text_plate.set_border_width_all(1)
	text_plate.set_corner_radius_all(6)
	text_back.add_theme_stylebox_override("panel", text_plate)
	text_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_fx.add_child(text_back)
	search_fx_label = _label(search_fx, "", Vector2(64, 250), Vector2(272, 32), 20, GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, title_font)
	search_fx_hint = _label(search_fx, "别被撞见 · 换形态、换区或离开都会打断",
		Vector2(64, 282), Vector2(272, 30), 12, Color("c99a86"), HORIZONTAL_ALIGNMENT_CENTER)

## 每帧：摆动、进度、打断/完成的一瞬反馈。规则不在这里，只读 run.search。
func _refresh_search_fx(dt: float) -> void:
	if run == null or search_fx == null:
		return
	var active: bool = not run.search.is_empty()
	if active:
		search_fx.visible = true
		search_fx_hide = 0.0
		search_fx.modulate = Color(1, 1, 1, 1)
		var left := maxf(0.0, float(run.search.get("left", 0.0)))
		var total := maxf(0.01, float(run.search.get("total", 1.0)))
		search_fx_ring.ratio = clampf(1.0 - left / total, 0.0, 1.0)
		search_fx_ring.tone = Color("c95666") if search_fx_break <= 0.0 else Color("e08a7a")
		var t := Time.get_ticks_msec() / 1000.0
		search_fx_probe.rotation = sin(t * 4.2) * 0.12
		search_fx_probe.scale = Vector2.ONE * (1.0 + sin(t * 6.0) * 0.02)
		search_fx_break = maxf(0.0, search_fx_break - dt)
		search_fx_label.text = "翻找中…… %.1f 秒" % left
		search_fx_hint.text = "别被撞见 · 换形态、换区或离开都会打断"
		search_fx_was_active = true
		search_fx_last_searched = run.searched
		return
	if not search_fx_was_active:
		search_fx.visible = false
		return
	search_fx_was_active = false
	if run.searched > search_fx_last_searched:
		search_fx_label.text = "找到了点什么。"
		search_fx_hint.text = "战利品已进背包，腾出格子再翻。"
		search_fx_ring.tone = GOLD
	else:
		search_fx_label.text = "翻找被打断了。"
		search_fx_hint.text = "东西还在原地，缓一缓再来。"
		search_fx_ring.tone = Color("e08a7a")
		search_fx_break = 0.5
	search_fx_ring.ratio = 1.0
	search_fx_hide = 0.9

func _tick_search_fx_fade(dt: float) -> void:
	if search_fx == null or not search_fx.visible or search_fx_hide <= 0.0:
		return
	search_fx_hide = maxf(0.0, search_fx_hide - dt)
	search_fx.modulate = Color(1, 1, 1, clampf(search_fx_hide / 0.6, 0.0, 1.0))
	if search_fx_hide <= 0.0:
		search_fx.visible = false

func _refresh_all() -> void:
	if run == null:
		return
	if area_label:
		area_label.text = run.area_name()
		area_desc.text = str(run.area().get("desc", ""))
		day_label.text = run.day_text()
		var phase_tint := BLUE if run.is_night() else (Color("d9a36e") if run.phase_id() == "dusk" else GOLD)
		phase_label.text = run.phase_name()
		phase_label.add_theme_color_override("font_color", phase_tint)
		if phase_icon and is_instance_valid(phase_icon):
			phase_icon.texture = Art.icon("ui_night" if run.is_night() else ("ui_dusk" if run.phase_id() == "dusk" else "ui_day"))
			phase_icon.modulate = phase_tint
		timer_label.text = run.time_text()
		timer_bar.value = (1.0 - run.day_ratio()) * 100.0
		if not run.combat.is_empty():
			hint_label.text = "战斗：攻击 / 重击 / 道具 / 逃跑"
		elif not run.search.is_empty():
			hint_label.text = "翻找中……换姿态或离开会打断它"
		elif run.form == "hide":
			hint_label.text = "隐藏：很难被找到，出手与翻找都变慢"
		elif run.has_enemy():
			hint_label.text = "附近有东西在动。压低身形（Z）会更安全"
		else:
			var unknown := 0
			for marker in run.events_here():
				if not bool(marker.get("used", false)):
					unknown += 1
			if unknown > 0:
				hint_label.text = "这一带有 %d 处说不清的动静（问号）　W 翻找 / Z 换形态" % unknown
			else:
				hint_label.text = "W 翻找 / Z 换形态 / M 换区" if run.search_cd <= 0.0 else "缓一缓再翻（%.1fs）" % run.search_cd
		hp_bar.max_value = maxf(1.0, run.total_max_hp())
		hp_bar.value = run.hp
		sp_bar.max_value = maxf(1.0, run.max_stamina)
		sp_bar.value = run.stamina
		hp_text.text = "%d/%d" % [int(run.hp), int(run.total_max_hp())]
		sp_text.text = "%d/%d" % [int(run.stamina), int(run.max_stamina)]
		attack_label.text = "攻击 %d" % int(run.attack_power())
		defense_label.text = "防御 %d%%   背包 %d/%d" % [int(run.defense_value() * 100.0), run.bag.size(), run.capacity]
		if not info_labels.is_empty():
			var hide_now: bool = run.form == "hide"
			var rate_now: float = run.attack_rate()
			var base_rate: float = rate_now / 1.2 if hide_now else rate_now
			var search_now: float = run.search_seconds()
			var base_search: float = search_now / 1.2 if hide_now else search_now
			var alert_count := 0
			for enemy in run.active_enemies():
				if bool(enemy.get("alert", false)):
					alert_count += 1
			info_labels[0].text = "形态　%s（Z 切换，冷却 2 秒）" % run.form_name()
			info_labels[1].text = "被发现率　行动 100% ／ 隐藏 15%"
			info_labels[2].text = "攻击力　%d（隐藏形态最终伤害 ×0.6 向下取整）" % int(run.attack_power())
			info_labels[3].text = "攻速　%.2fs ／ 隐藏 %.2fs" % [base_rate, base_rate * 1.2]
			info_labels[4].text = "翻找　%.1fs ／ 隐藏 %.1fs（可被打断）" % [base_search, base_search * 1.2]
			info_labels[5].text = "防御　%d%%　背包　%d/%d" % [int(run.defense_value() * 100.0), run.bag.size(), run.capacity]
			info_labels[6].text = "附近威胁　%d 只（已察觉 %d）" % [run.active_enemies().size(), alert_count]
			info_labels[7].text = "第 %d 天 · %s · %s" % [run.day, run.phase_name(), run.area_name()]
		portrait.set_expression(run.expression)
		portrait.modulate = Color(1.0, 0.96, 0.88) if run.phase_id() == "day" else (Color(1.0, 0.78, 0.66) if run.phase_id() == "dusk" else Color(0.70, 0.80, 1.0))
		rest_button.disabled = not run.can_rest()
		extract_button.disabled = not run.can_extract()
		extract_button.text = "撤离" if run.can_extract() else "撤离(4:00)"
		if form_button:
			form_button.text = "形态：%s  Z%s" % [run.form_name(), ("（%.1f）" % run.form_cd) if run.form_cd > 0.0 else ""]
			form_button.disabled = run.form_cd > 0.0
		if search_button:
			if not run.search.is_empty():
				search_button.text = "翻找中…"
				search_button.disabled = true
			elif run.search_cd > 0.0:
				search_button.text = "整备 %.1fs" % run.search_cd
				search_button.disabled = true
			else:
				search_button.text = "搜索  W"
				search_button.disabled = not bool(run.can_search().ok)
		_on_run_log("")
	else:
		pass
	if run.area_id != stage.area_id or run.phase_id() != stage.phase:
		_build_stage(run.area_id, run.phase_id())
	_refresh_markers()
	_refresh_combat()
	_refresh_bag_text()
	_refresh_pocket_text()
	if pocket_overlay and pocket_overlay.visible:
		_refresh_pocket_overlay()
	if event_open:
		if _event_window_open():
			_refresh_event_window()
		else:
			_close_event_window()

func _refresh_bag_text() -> void:
	var b := hud.get_node_or_null("HuntBagButton")
	if b is Button:
		b.text = "背包 %d/%d" % [run.bag.size(), run.capacity]

func _refresh_pocket_text() -> void:
	if pocket_button == null:
		return
	pocket_button.text = "随身物 %d/3" % run.pocket.size()

# --------------------------------------------------------------- scene markers

func _refresh_markers() -> void:
	if run == null or hotspot_layer == null:
		return
	if run.ended_flag:
		for child in hotspot_layer.get_children():
			child.queue_free()
		site_nodes.clear()
		return
	var markers: Array = run.events_here()
	var uids: Array = []
	for marker in markers:
		if not bool(marker.get("used", false)):
			uids.append(str(marker.get("uid", "")))
	var sig := "%s|%s|%s|%s" % [run.area_id, run.day, run.phase_id(), "|".join(uids)]
	if sig == marker_signature:
		return
	marker_signature = sig
	spot_nodes.clear()
	enemy_nodes.clear()
	var area := Vector2(hotspot_layer.size)
	if area.x < 10.0:
		area = VIEW
	# Keep interactive markers out of the portrait/stat corner and the bottom action
	# strip: the authored 0..1 coordinates describe the painted scene, not the HUD.
	var scene_rect := Rect2(Vector2(372, 128), Vector2(area.x - 396, area.y - 368))
	# 淡出已经解决/不在本时段的问号点，再把新的淡入。
	for uid in site_nodes.keys():
		if uid in uids:
			continue
		var gone = site_nodes[uid]
		site_nodes.erase(uid)
		if gone and is_instance_valid(gone):
			var fade_out := create_tween()
			fade_out.tween_property(gone, "modulate:a", 0.0, 0.28)
			fade_out.tween_callback(gone.queue_free)
	for marker in markers:
		var uid := str(marker.get("uid", ""))
		if bool(marker.get("used", false)) or site_nodes.has(uid):
			continue
		var node := EventMarker.new()
		node.name = "Event_" + uid.replace(":", "_")
		node.run = run
		node.marker = marker
		node.size = Vector2(150, 150)
		var at: Vector2 = marker.get("at", Vector2(0.5, 0.5))
		node.position = scene_rect.position + at * scene_rect.size - node.size * 0.5
		node.position.x = clampf(node.position.x, scene_rect.position.x, scene_rect.end.x - node.size.x)
		node.position.y = clampf(node.position.y, scene_rect.position.y, scene_rect.end.y - node.size.y)
		node.modulate = Color(1, 1, 1, 0.0)
		node.pressed.connect(_on_event_pressed.bind(uid))
		hotspot_layer.add_child(node)
		site_nodes[uid] = node
		var fade_in := create_tween()
		fade_in.tween_interval(0.05)
		fade_in.tween_property(node, "modulate:a", 1.0, 0.45)

func _on_event_pressed(uid: String) -> void:
	if run == null or run.ended_flag:
		return
	if run.begin_event(uid):
		_open_event_window()
	_refresh_all()

## W 键 / 「搜索」按钮共用的入口：随机抽一个已解锁的点位，3 秒，可被打断。
func _do_search() -> void:
	if run == null or run.ended_flag:
		return
	run.start_search()
	_refresh_all()

## Z 键 / 「形态」按钮：行动 ⇄ 隐藏，2 秒切换 CD。
func _do_form() -> void:
	if run == null or run.ended_flag:
		return
	run.toggle_form()
	_refresh_all()

# ------------------------------------------------------------------- overlays

func _close_overlay(resume: bool = true) -> void:
	if map_overlay: map_overlay.visible = false
	if craft_overlay: craft_overlay.visible = false
	if bag_overlay: bag_overlay.visible = false
	if pocket_overlay: pocket_overlay.visible = false
	if pause_layer: pause_layer.visible = false
	overlay_kind = ""
	if run and resume and not run.ended_flag and not _event_window_open():
		run.set_paused(false)

func _open_overlay(kind: String) -> void:
	_close_overlay(false)
	overlay_kind = kind
	if run:
		run.set_paused(true)
	match kind:
		"map":
			map_overlay.visible = true
			_refresh_map_overlay()
		"craft":
			craft_overlay.visible = true
			_refresh_craft_overlay()
		"bag":
			bag_overlay.visible = true
			_refresh_bag_overlay()
		"pocket":
			pocket_overlay.visible = true
			_refresh_pocket_overlay()
		"pause":
			pause_layer.visible = true

func _open_map() -> void:
	if mode != "run": return
	_open_overlay("map")

func _open_craft() -> void:
	if mode != "run": return
	_open_overlay("craft")

func _open_bag() -> void:
	if mode != "run": return
	_open_overlay("bag")

func _build_map_overlay() -> void:
	if map_overlay: return
	map_overlay = Control.new()
	map_overlay.name = "HuntMap"
	map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_overlay.visible = false
	map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.03, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	map_overlay.add_child(dim)
	var panel := _panel(map_overlay, Vector2(70, 44), Vector2(1300, 812), Color(0.03, 0.04, 0.06, 0.98))
	_label(panel, "血 潮 深 潜 · 地 区 图", Vector2(30, 20), Vector2(600, 40), 30, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	_label(panel, "邻近地区才能移动；第 2 / 3 天会解锁更深的区域。", Vector2(32, 62), Vector2(900, 24), 14, MUTED)
	map_view = MapView.new()
	map_view.position = Vector2(30, 100)
	map_view.size = Vector2(1240, 610)
	map_view.picked.connect(_on_map_pick)
	panel.add_child(map_view)
	_button(panel, "关闭  Esc/M", Vector2(30, 730), Vector2(180, 48), func(): _close_overlay())
	_button(panel, "撤离  (4:00 后 / 需在广场或码头)", Vector2(900, 730), Vector2(370, 48), _extract_from_map, true)
	panel.name = "MapPanel"
	var extract := panel.get_child(panel.get_child_count() - 1)
	extract.name = "HuntExtractButton"

func _extract_from_map() -> void:
	if run and run.extract():
		_close_overlay()
		_refresh_all()

func _refresh_map_overlay() -> void:
	if map_view:
		map_view.set_run(run)
	var panel := map_overlay.get_node_or_null("MapPanel") if map_overlay else null
	if panel and panel.has_node("HuntExtractButton"):
		var b := panel.get_node("HuntExtractButton") as Button
		if b:
			b.disabled = not run.can_extract()

func _on_map_pick(id: String) -> void:
	if run == null:
		return
	if run.travel(id):
		_close_overlay()
		_refresh_all()
	else:
		_refresh_map_overlay()

func _build_craft_overlay() -> void:
	if craft_overlay: return
	craft_overlay = Control.new()
	craft_overlay.name = "HuntCraft"
	craft_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	craft_overlay.visible = false
	craft_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(craft_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.03, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	craft_overlay.add_child(dim)
	var panel := _panel(craft_overlay, Vector2(150, 40), Vector2(1140, 820), Color(0.03, 0.04, 0.06, 0.99))
	panel.name = "CraftPanel"
	_label(panel, "局 内 合 成", Vector2(28, 18), Vector2(400, 40), 30, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	_label(panel, "材料够就能合成；背包满时合成会失败并退还材料。", Vector2(30, 58), Vector2(900, 22), 13, MUTED)
	var x := 30.0
	for cat in Data.RECIPE_CATEGORIES:
		var id := str(cat.id)
		var b := _button(panel, str(cat.name), Vector2(x, 90), Vector2(104, 38), func(): _set_craft_cat(id))
		b.name = "CraftCat_" + id
		b.toggle_mode = true
		craft_buttons[id] = b
		x += 112.0
	_button(panel, "关闭  Esc/C", Vector2(970, 90), Vector2(140, 38), func(): _close_overlay())
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 142)
	scroll.size = Vector2(1084, 590)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", _style(Color(0.02, 0.03, 0.045, 0.9), Color(0.18, 0.20, 0.25)))
	panel.add_child(scroll)
	craft_list = VBoxContainer.new()
	craft_list.custom_minimum_size = Vector2(1060, 0)
	craft_list.add_theme_constant_override("separation", 4)
	scroll.add_child(craft_list)
	for recipe in Data.RECIPES:
		var row := _craft_row(recipe)
		craft_list.add_child(row)
		craft_rows[str(recipe.id)] = row
	_refresh_craft_overlay()
	_set_craft_cat("all")

func _craft_row(recipe: Dictionary) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(1050, 56)
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(1050, 52)
	panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.085, 0.8), Color(0.16, 0.18, 0.22)))
	row.add_child(panel)
	var out := str(recipe.get("out", ""))
	var icon := TextureRect.new()
	icon.texture = Art.icon(out)
	# expand_mode 必须排在 size 之前：TextureRect 的最小尺寸等于纹理尺寸，
	# 先设 size 会被钳回原图大小，图标就把右边的文字盖住了。
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(8, 6)
	icon.size = Vector2(40, 40)
	icon.modulate = Art.icon_modulate(out)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	_label(panel, "%s ×%d" % [Data.item_name(out), int(recipe.get("count", 1))], Vector2(56, 8), Vector2(210, 36), 17, INK)
	var inputs: Array = []
	for kind in recipe.get("inputs", {}):
		inputs.append("%s×%d" % [Data.item_name(str(kind)), int(recipe.inputs[kind])])
	_label(panel, " + ".join(inputs), Vector2(270, 10), Vector2(420, 32), 13, MUTED)
	_label(panel, _cat_name(str(recipe.get("cat", ""))), Vector2(700, 10), Vector2(90, 32), 12, DIM)
	var button := _button(panel, "合成", Vector2(930, 6), Vector2(104, 38), func(): _craft(str(recipe.id)), true)
	button.name = "Craft_" + str(recipe.id)
	row.set_meta("cat", str(recipe.get("cat", "")))
	row.set_meta("button", button)
	return row

func _cat_name(id: String) -> String:
	for cat in Data.RECIPE_CATEGORIES:
		if str(cat.id) == id:
			return str(cat.name)
	return id

func _set_craft_cat(cat: String) -> void:
	craft_cat = cat
	for id in craft_buttons:
		var b := craft_buttons[id] as Button
		if b: b.set_pressed_no_signal(id == cat)
	for id in craft_rows:
		var row: Control = craft_rows[id]
		row.visible = cat == "all" or str(row.get_meta("cat", "")) == cat
	_refresh_craft_overlay()

func _refresh_craft_overlay() -> void:
	if run == null: return
	for id in craft_rows:
		var row: Control = craft_rows[id]
		var button := row.get_meta("button") as Button
		var recipe := Data.recipe(str(id))
		var ok: bool = run.can_craft(recipe)
		if button:
			button.disabled = not ok
			button.text = "合成" if ok else "缺料"
		row.modulate = Color.WHITE if ok else Color(0.55, 0.55, 0.58, 0.85)
	_refresh_craft_header()

func _refresh_craft_header() -> void:
	var panel := craft_overlay.get_node_or_null("CraftPanel") if craft_overlay else null
	if panel == null: return
	var hint := panel.get_node_or_null("CraftHint") as Label
	if hint == null:
		hint = _label(panel, "", Vector2(700, 94), Vector2(250, 30), 12, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		hint.name = "CraftHint"
	hint.text = "背包 %d/%d" % [run.bag.size(), run.capacity]

func _craft(id: String) -> void:
	if run and run.craft(id):
		_refresh_all()
		_refresh_craft_overlay()

func _build_bag_overlay() -> void:
	if bag_overlay: return
	bag_overlay = Control.new()
	bag_overlay.name = "HuntBag"
	bag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bag_overlay.visible = false
	bag_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bag_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.03, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_overlay.add_child(dim)
	var panel := _panel(bag_overlay, Vector2(220, 60), Vector2(1000, 780), Color(0.03, 0.04, 0.06, 0.99))
	panel.name = "BagPanel"
	_label(panel, "局 内 行 囊", Vector2(26, 18), Vector2(400, 40), 30, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	_label(panel, "点击物品使用 / 装备；武器与防具会替换身上的那件。", Vector2(28, 58), Vector2(700, 22), 13, MUTED)
	var close := _button(panel, "关闭  Esc/Tab", Vector2(820, 90), Vector2(150, 38), func(): _close_overlay())
	close.name = "BagClose"
	bag_grid = GridContainer.new()
	bag_grid.columns = 5
	bag_grid.position = Vector2(30, 150)
	bag_grid.size = Vector2(940, 560)
	bag_grid.add_theme_constant_override("h_separation", 8)
	bag_grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(bag_grid)
	_label(panel, "装备", Vector2(28, 96), Vector2(120, 28), 17, GOLD)
	var equip := _label(panel, "", Vector2(100, 96), Vector2(600, 28), 14, INK)
	equip.name = "BagEquip"

func _refresh_bag_overlay() -> void:
	if bag_grid == null or run == null: return
	for child in bag_grid.get_children():
		child.queue_free()
	for i in run.capacity:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(178, 100)
		slot.focus_mode = Control.FOCUS_NONE
		slot.add_theme_font_override("font", face_font)
		slot.add_theme_stylebox_override("normal", _style(Color(0.045, 0.055, 0.08, 0.9), Color(0.16, 0.18, 0.22)))
		slot.add_theme_stylebox_override("hover", _style(Color(0.08, 0.09, 0.13, 0.95), Color(0.42, 0.36, 0.30)))
		slot.add_theme_stylebox_override("pressed", _style(Color(0.10, 0.11, 0.15, 1.0), Color(0.55, 0.45, 0.35)))
		if i < run.bag.size():
			var entry: Dictionary = run.bag[i]
			var kind := str(entry.kind)
			var tex := TextureRect.new()
			tex.texture = Art.icon(kind)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.position = Vector2(8, 8)
			tex.size = Vector2(52, 52)
			tex.modulate = Art.icon_modulate(kind)
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(tex)
			var name_label := _label(slot, Data.item_name(kind), Vector2(66, 8), Vector2(104, 34), 13, INK,
				HORIZONTAL_ALIGNMENT_LEFT, null, true)
			var count := int(entry.get("count", 1))
			_label(slot, "×%d" % count, Vector2(66, 48), Vector2(104, 22), 13, GOLD)
			slot.tooltip_text = "%s\n%s" % [Data.item_name(kind), str(Data.item(kind).get("desc", ""))]
			slot.pressed.connect(func(): _use_bag_slot(i))
		else:
			_label(slot, "空", Vector2(8, 38), Vector2(160, 24), 12, DIM, HORIZONTAL_ALIGNMENT_CENTER)
		bag_grid.add_child(slot)
	var equip := bag_overlay.get_node_or_null("BagPanel/BagEquip") as Label
	if equip:
		equip.text = "武器：%s    防具：%s    容量 %d" % [
			Data.item_name(run.weapon_kind()) if run.weapon_kind() != "fist" else "空手",
			Data.item_name(run.armor_kind()) if not run.armor_kind().is_empty() else "无",
			run.capacity,
		]

func _use_bag_slot(index: int) -> void:
	if run == null: return
	if run.use_item(index):
		_refresh_all()
		_refresh_bag_overlay()

# --------------------------------------------------------------- 随身物（局内）
# 3 格独立口袋：不占背包、不进仓库、撤离也不会被带回去。

func _build_pocket_overlay() -> void:
	if pocket_overlay: return
	pocket_overlay = Control.new()
	pocket_overlay.name = "HuntPocket"
	pocket_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pocket_overlay.visible = false
	pocket_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pocket_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.03, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pocket_overlay.add_child(dim)
	var panel := _panel(pocket_overlay, Vector2(400, 170), Vector2(640, 540), Color(0.03, 0.04, 0.06, 0.99))
	panel.name = "PocketRunPanel"
	_label(panel, "随 身 物", Vector2(28, 18), Vector2(300, 40), 30, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	_label(panel, "三格。跟着你下来的东西，血潮不会放它回去。", Vector2(30, 60), Vector2(560, 26), 13, MUTED)
	var box := VBoxContainer.new()
	box.name = "PocketRows"
	box.position = Vector2(28, 104)
	box.size = Vector2(584, 330)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_label(panel, "点击使用。用完就没了；没用的会留到下一局。", Vector2(30, 444), Vector2(560, 24), 12, MUTED)
	_button(panel, "关闭  Esc", Vector2(28, 476), Vector2(160, 44), func(): _close_overlay())
	_refresh_pocket_overlay()

func _refresh_pocket_overlay() -> void:
	if pocket_overlay == null or run == null:
		return
	var box := pocket_overlay.get_node_or_null("PocketRunPanel/PocketRows") as VBoxContainer
	if box == null:
		return
	for child in box.get_children():
		child.queue_free()
	for i in 3:
		var row := Panel.new()
		row.custom_minimum_size = Vector2(580, 96)
		row.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.085, 0.86), Color(0.16, 0.18, 0.22)))
		if i < run.pocket.size():
			var entry: Dictionary = run.pocket[i]
			var kind := str(entry.get("kind", ""))
			var icon := TextureRect.new()
			icon.texture = Art.icon(kind)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(12, 12)
			icon.size = Vector2(56, 56)
			icon.modulate = Art.icon_modulate(kind)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
			_label(row, Data.item_name(kind), Vector2(82, 12), Vector2(300, 30), 17, INK)
			_label(row, "×%d" % int(entry.get("count", 1)), Vector2(82, 44), Vector2(120, 24), 13, GOLD)
			var desc := _label(row, str(Data.item(kind).get("desc", "")), Vector2(82, 64), Vector2(380, 26), 11, MUTED,
				HORIZONTAL_ALIGNMENT_LEFT, null, true)
			desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			var use := _button(row, "使用", Vector2(470, 28), Vector2(96, 40), func(): _use_pocket_slot(i), true)
			use.name = "PocketUse%d" % i
			use.disabled = kind in ["snare", "alchemist_flare", "smoke_pouch"] and run.combat.is_empty()
		else:
			_label(row, "空", Vector2(20, 32), Vector2(160, 32), 14, DIM)
		box.add_child(row)

func _use_pocket_slot(index: int) -> void:
	if run == null:
		return
	if run.pocket_use(index):
		_refresh_all()
		_refresh_pocket_overlay()

# --------------------------------------------------------------- 互动事件窗
# 老式 2D 解谜的"调查窗口"：中等大小、非全屏，压住场景但留出画面边缘。
# 默认时停；每个选项标注要花掉的局内时间，点下去时间照走。`live` 事件不暂停。

func _build_event_window() -> void:
	if event_overlay: return
	event_overlay = Control.new()
	event_overlay.name = "HuntEvent"
	event_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_overlay.visible = false
	event_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(event_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.008, 0.01, 0.016, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	event_overlay.add_child(dim)
	var panel := _panel(event_overlay, Vector2(240, 108), Vector2(960, 668), Color(0.028, 0.036, 0.054, 0.99), true)
	panel.name = "EventPanel"
	# 左：物件插图（黑底生图，融进暗色面板）。
	var frame := Panel.new()
	frame.position = Vector2(28, 92)
	frame.size = Vector2(352, 352)
	frame.add_theme_stylebox_override("panel", _style(Color(0.012, 0.016, 0.024, 1.0), Color(0.24, 0.22, 0.24, 0.9)))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	event_art = TextureRect.new()
	event_art.name = "EventArt"
	event_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	event_art.position = Vector2(8, 8)
	event_art.size = Vector2(336, 336)
	event_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(event_art)
	event_title = _label(panel, "", Vector2(404, 20), Vector2(520, 44), 30, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	event_sub = _label(panel, "", Vector2(406, 66), Vector2(520, 24), 12, GOLD)
	var log_panel := Panel.new()
	log_panel.position = Vector2(398, 98)
	log_panel.size = Vector2(532, 300)
	log_panel.add_theme_stylebox_override("panel", _style(Color(0.018, 0.024, 0.036, 1.0), Color(0.16, 0.18, 0.22)))
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(log_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "EventLogScroll"
	scroll.position = Vector2(12, 12)
	scroll.size = Vector2(508, 276)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	log_panel.add_child(scroll)
	event_log = Label.new()
	event_log.name = "EventLog"
	event_log.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	event_log.add_theme_font_override("font", face_font)
	event_log.add_theme_font_size_override("font_size", 15)
	event_log.add_theme_color_override("font_color", Color("d8d2c6"))
	event_log.add_theme_constant_override("line_spacing", 5)
	event_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_log.custom_minimum_size = Vector2(488, 0)
	scroll.add_child(event_log)
	event_options = VBoxContainer.new()
	event_options.name = "EventOptions"
	event_options.position = Vector2(398, 414)
	event_options.size = Vector2(532, 190)
	event_options.add_theme_constant_override("separation", 6)
	panel.add_child(event_options)
	# 实时动作：一个进度条 + 剩余秒数。世界在跑，所以这里还要提醒别被撞见。
	event_action_box = Control.new()
	event_action_box.name = "EventActionBox"
	event_action_box.position = Vector2(398, 440)
	event_action_box.size = Vector2(532, 150)
	event_action_box.visible = false
	event_action_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(event_action_box)
	event_action_label = _label(event_action_box, "", Vector2(0, 0), Vector2(532, 40), 22, INK,
		HORIZONTAL_ALIGNMENT_LEFT, title_font)
	event_action_bar = _bar(event_action_box, Vector2(0, 52), Vector2(532, 16), GOLD)
	event_action_hint = _label(event_action_box, "保持动作中…… 世界没有停，怪物正在靠近。按 收起/Esc 可以中止（时间不退）。",
		Vector2(0, 82), Vector2(532, 60), 12, Color("c99a86"), HORIZONTAL_ALIGNMENT_LEFT, null, true)
	# 时停解密：三环血纹锁 / 记忆符文。
	event_puzzle_box = Control.new()
	event_puzzle_box.name = "EventPuzzleBox"
	event_puzzle_box.position = Vector2(398, 414)
	event_puzzle_box.size = Vector2(532, 190)
	event_puzzle_box.visible = false
	event_puzzle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(event_puzzle_box)
	# 血纹盘的整张底图压在按钮下面：黑底生图，只提一点亮度，不抢字的可读性。
	event_puzzle_art = TextureRect.new()
	event_puzzle_art.name = "PuzzleArt"
	event_puzzle_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_puzzle_art.stretch_mode = TextureRect.STRETCH_SCALE
	event_puzzle_art.position = Vector2(344, 4)
	event_puzzle_art.size = Vector2(180, 180)
	event_puzzle_art.texture = Art.puzzle_dial()
	event_puzzle_art.modulate = Color(1, 1, 1, 0.78)
	event_puzzle_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_puzzle_box.add_child(event_puzzle_art)
	event_puzzle_hint = _label(event_puzzle_box, "", Vector2(0, 148), Vector2(532, 42), 12, MUTED,
		HORIZONTAL_ALIGNMENT_LEFT, null, true)
	event_puzzle_seal = TextureRect.new()
	event_puzzle_seal.name = "EventPuzzleSeal"
	event_puzzle_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_puzzle_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	event_puzzle_seal.position = Vector2(196, 16)
	event_puzzle_seal.size = Vector2(140, 140)
	event_puzzle_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_puzzle_seal.visible = false
	event_puzzle_box.add_child(event_puzzle_seal)
	# 解开/失败时盖在插图上的血印（成功/失败各一张素材）。
	event_seal = TextureRect.new()
	event_seal.name = "EventSeal"
	event_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	event_seal.position = Vector2(104, 244)
	event_seal.size = Vector2(196, 196)
	event_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_seal.visible = false
	panel.add_child(event_seal)
	_button(panel, "收起  Esc", Vector2(398, 612), Vector2(150, 40), func(): _close_event_window())
	_label(panel, "动手之后，时间会照常走：撬锁、拆解、翻找都要花时间。", Vector2(28, 456), Vector2(344, 60), 12, MUTED,
		HORIZONTAL_ALIGNMENT_LEFT, null, true)
	_label(panel, "解密时，时间会为你停住。", Vector2(28, 520), Vector2(344, 60), 12, Color("c99a86"),
		HORIZONTAL_ALIGNMENT_LEFT, null, true)

func _event_window_open() -> bool:
	return event_open and run != null and not run.event_state.is_empty()

func _open_event_window() -> void:
	if run == null or run.event_state.is_empty():
		return
	event_open = true
	event_sig = ""
	event_was_puzzle = run != null and run.puzzle_active()
	if event_seal:
		event_seal.visible = false
	event_overlay.visible = true
	event_overlay.modulate = Color(1, 1, 1, 0.0)
	var tw := create_tween()
	tw.tween_property(event_overlay, "modulate:a", 1.0, 0.22)
	_refresh_event_window()

func _close_event_window() -> void:
	if not event_open and (run == null or run.event_state.is_empty()):
		return
	event_open = false
	event_was_puzzle = false
	if event_action_box:
		event_action_box.visible = false
	if event_puzzle_box:
		event_puzzle_box.visible = false
	if event_seal:
		event_seal.visible = false
	if event_overlay:
		event_overlay.visible = false
	if run and not run.event_state.is_empty():
		run.close_event()

func _refresh_event_window() -> void:
	if event_overlay == null or run == null:
		return
	if run.event_state.is_empty():
		_close_event_window()
		return
	var state: Dictionary = run.event_state
	var live := bool(state.get("live", false))
	var action: Dictionary = run.event_action()
	var puzzle: Dictionary = run.event_puzzle()
	var was_puzzle := event_was_puzzle
	event_was_puzzle = not puzzle.is_empty()
	if was_puzzle and puzzle.is_empty():
		_flash_event_seal("fail" if bool(state.get("finished", false)) else "success")
	# 进度条每帧都要跟手，但它不在签名里——重建按钮会把点击吃掉。
	_update_event_action_ui(action)
	# 只在内容真的变了才重建按钮：live 事件每帧 tick 都会发 changed，
	# 每帧重建按钮会把点击吃掉。
	var log_lines: Array = state.get("log", [])
	var puzzle_sig := _puzzle_sig(puzzle)
	var sig := "%s|%d|%s|%d|%d|%d|%s" % [str(state.get("step", "")), log_lines.size(),
		str(state.get("finished", false)), int(run.hp), int(run.stamina), action.size(), puzzle_sig]
	if sig == event_sig:
		return
	event_sig = sig
	event_title.text = str(state.get("name", ""))
	if not puzzle.is_empty():
		event_sub.text = "时间停住了 · 解开它，或者收起走人"
		event_sub.add_theme_color_override("font_color", GOLD)
	elif not action.is_empty():
		event_sub.text = "动作进行中 · 世界没有停，别被撞见"
		event_sub.add_theme_color_override("font_color", Color("d98b7a"))
	elif live:
		event_sub.text = "这里的时间没有停 · 你随时可能被打断"
		event_sub.add_theme_color_override("font_color", Color("d98b7a"))
	else:
		event_sub.text = "时间暂停 · 动手之后世界会继续走"
		event_sub.add_theme_color_override("font_color", GOLD)
	var art_tex := Art.event_texture(str(state.get("art", "")))
	event_art.texture = art_tex
	var lines: Array = state.get("log", [])
	event_log.text = "\n\n".join(lines)
	var scroll := event_overlay.get_node_or_null("EventPanel/EventLogScroll") as ScrollContainer
	if scroll:
		await get_tree().process_frame
		if scroll:
			scroll.scroll_vertical = 99999
	for child in event_options.get_children():
		child.queue_free()
	event_option_buttons.clear()
	if bool(state.get("finished", false)):
		event_puzzle_box.visible = false
		var done := _button(event_options, "离开这里", Vector2(0, 0), Vector2(532, 50), func(): _close_event_window(), true)
		done.name = "EventLeave"
		return
	if not puzzle.is_empty():
		event_options.visible = false
		event_action_box.visible = false
		event_puzzle_box.visible = true
		_rebuild_puzzle_ui(puzzle)
		return
	event_puzzle_box.visible = false
	if not action.is_empty():
		event_options.visible = false
		event_action_box.visible = true
		return
	event_action_box.visible = false
	event_options.visible = true
	var options: Array = run.event_options()
	for i in options.size():
		var opt: Dictionary = options[i]
		var label := str(opt.get("label", "继续"))
		var cost := int(opt.get("time", 0))
		if cost > 0:
			label += "   ·   %d 秒（真实）" % cost
		var b := _button(event_options, label, Vector2(0, 0), Vector2(532, 44), func(): _choose_event_option(i), i == 0)
		b.name = "EventOption%d" % i
		b.add_theme_font_size_override("font_size", 15)
		var ok := bool(opt.get("ok", false))
		b.disabled = not ok
		if not ok:
			b.tooltip_text = str(opt.get("why", ""))
		event_option_buttons.append(b)

## 进度条与剩余秒数：只更新数值，不碰按钮。
func _update_event_action_ui(action: Dictionary) -> void:
	if event_action_box == null:
		return
	if action.is_empty():
		event_action_box.visible = false
		return
	event_action_box.visible = true
	var left: float = run.event_action_left()
	var total := maxf(0.01, float(action.get("total", 1.0)))
	event_action_label.text = "动作中…… 还剩 %.1f / %.0f 秒" % [left, total]
	event_action_bar.max_value = total
	event_action_bar.value = total - left

func _puzzle_sig(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	var rings := ""
	for v in p.get("rings", []):
		rings += str(int(v))
	return "%s|%d|%d|%s|%s|%s" % [str(p.get("kind", "")), int(p.get("attempts", 0)),
		int(p.get("progress", 0)), rings, str(p.get("last_fail", "")), str(p.get("reveal", false))]

## 时停解密的界面：三环锁逐环转，记忆序列逐个敲。所有按钮都是 Godot Button；
## 解密状态下事件窗不重建选项，所以点击不会丢。
func _rebuild_puzzle_ui(p: Dictionary) -> void:
	for child in event_puzzle_box.get_children():
		if child != event_puzzle_hint and child != event_puzzle_seal and child != event_puzzle_art:
			child.queue_free()
	event_puzzle_seal.visible = false
	var glyphs := int(p.get("glyphs", 6))
	var attempts := int(p.get("attempts", 0))
	var max_attempts := int(p.get("max_attempts", 3))
	var at := int(p.get("attempts", 0))
	event_puzzle_art.visible = str(p.get("kind", "")) == "dial"
	if str(p.get("kind", "")) == "sequence":
		var seq: Array = p.get("sequence", [])
		event_puzzle_hint.text = "记忆符文 · 记住盒盖内侧亮起的顺序，然后照着重敲一遍。"
		for i in glyphs:
			var glyph: String = run.puzzle_glyph(i)
			var b := _button(event_puzzle_box, glyph, Vector2(i * 74, 0), Vector2(64, 56),
				func(): run.puzzle_press(i); _refresh_all(), false)
			b.add_theme_font_size_override("font_size", 26)
			b.add_theme_font_override("font", title_font)
			b.name = "PuzzleGlyph%d" % i
		var progress := int(p.get("progress", 0))
		_label(event_puzzle_box, "已经敲对 %d / %d" % [progress, seq.size()], Vector2(0, 64), Vector2(300, 26), 14, GOLD)
		var again := _button(event_puzzle_box, "再听一次", Vector2(0, 94), Vector2(140, 36),
			func(): if run != null: run.puzzle_replay(); _play_puzzle_reveal(); _refresh_all())
		again.name = "PuzzleReplay"
		_label(event_puzzle_box, "机会 %d / %d" % [at, max_attempts], Vector2(160, 100), Vector2(220, 26), 14,
			RED if at <= 1 else MUTED)
		if bool(p.get("reveal", false)):
			_play_puzzle_reveal()
	else:
		var rings: Array = p.get("rings", [])
		event_puzzle_hint.text = "三环血纹锁 · 把三道铜环转到封蜡上刻的那组血纹。机会 %d/%d" % [at, max_attempts]
		var names := ["第一环", "第二环", "第三环"]
		for r in rings.size():
			var y := r * 44
			_label(event_puzzle_box, names[r], Vector2(0, y + 6), Vector2(64, 30), 13, MUTED)
			var step := 68
			var left_b := _button(event_puzzle_box, "◀", Vector2(step, y), Vector2(34, 36),
				func(): run.puzzle_rotate(r, -1); _refresh_all(), false)
			left_b.name = "PuzzleRing%dLeft" % r
			var glyph: String = run.puzzle_glyph(int(rings[r]))
			var face := _label(event_puzzle_box, glyph, Vector2(step + 38, y), Vector2(44, 36), 24, INK,
				HORIZONTAL_ALIGNMENT_CENTER, title_font)
			face.name = "PuzzleRing%dFace" % r
			var right_b := _button(event_puzzle_box, "▶", Vector2(step + 84, y), Vector2(34, 36),
				func(): run.puzzle_rotate(r, 1); _refresh_all(), false)
			right_b.name = "PuzzleRing%dRight" % r
		var try_btn := _button(event_puzzle_box, "试 转", Vector2(210, 26), Vector2(124, 54),
			func(): run.puzzle_try(); _refresh_all(), true)
		try_btn.name = "PuzzleTry"
		_label(event_puzzle_box, "机会 %d / %d" % [at, max_attempts], Vector2(210, 88), Vector2(120, 26), 14,
			RED if at <= 1 else MUTED)
	if not str(p.get("last_fail", "")).is_empty():
		event_puzzle_seal.texture = Art.puzzle_seal("fail")
		event_puzzle_seal.visible = event_puzzle_seal.texture != null
		_fade_puzzle_seal()

## 记忆序列的回放：依次点亮每个符文，然后藏起来。
func _play_puzzle_reveal() -> void:
	if run == null:
		return
	var p: Dictionary = run.event_puzzle()
	var seq: Array = p.get("sequence", [])
	if seq.is_empty() or event_puzzle_box == null:
		return
	for child in event_puzzle_box.get_children():
		if str(child.name).begins_with("PuzzleGlyph") and child is Button:
			child.modulate = Color(1, 1, 1, 1)
	for step in seq.size():
		var idx := int(seq[step])
		var node := event_puzzle_box.get_node_or_null("PuzzleGlyph%d" % idx) as Button
		if node == null:
			return
		node.modulate = Color(1.0, 0.72, 0.62, 1.0)
		await get_tree().create_timer(0.28).timeout
		if not is_instance_valid(node):
			return
		node.modulate = Color(1, 1, 1, 1)
		await get_tree().create_timer(0.12).timeout

## 解开或失败时，在物件插图正中盖一枚血印，1 秒后褪掉。
func _flash_event_seal(kind: String) -> void:
	if event_seal == null:
		return
	event_seal.texture = Art.puzzle_seal(kind)
	if event_seal.texture == null:
		return
	event_seal.visible = true
	event_seal.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(event_seal, "modulate:a", 1.0, 0.12)
	tw.tween_interval(0.7)
	tw.tween_property(event_seal, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): if is_instance_valid(event_seal): event_seal.visible = false)

func _fade_puzzle_seal() -> void:
	if event_puzzle_seal == null:
		return
	var node := event_puzzle_seal
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(node):
		node.visible = false

func _choose_event_option(index: int) -> void:
	if run == null or run.event_state.is_empty():
		return
	run.event_choose(index)
	if run.event_state.is_empty() or run.ended_flag:
		_close_event_window()
	else:
		_refresh_event_window()
	_refresh_all()

# ------------------------------------------------------------------- combat

func _build_combat_panel() -> void:
	combat_panel = Panel.new()
	combat_panel.name = "HuntCombat"
	combat_panel.position = Vector2(360, 584)
	combat_panel.size = Vector2(720, 216)
	combat_panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.035, 0.055, 0.96), Color(0.55, 0.28, 0.30)))
	combat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_panel.visible = false
	hud.add_child(combat_panel)
	combat_enemy_art = TextureRect.new()
	combat_enemy_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	combat_enemy_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	combat_enemy_art.position = Vector2(16, 16)
	combat_enemy_art.size = Vector2(120, 156)
	combat_enemy_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_panel.add_child(combat_enemy_art)
	combat_name = _label(combat_panel, "", Vector2(152, 14), Vector2(300, 30), 23, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	combat_hp = _bar(combat_panel, Vector2(152, 50), Vector2(300, 14), RED)
	combat_hp_text = _label(combat_panel, "", Vector2(460, 44), Vector2(100, 24), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(combat_panel, "它挨打会还手（0.1 秒反击 CD）。重击消耗 12 体力，8 秒冷却。", Vector2(152, 74), Vector2(540, 22), 12, MUTED)
	combat_attack = _button(combat_panel, "攻击", Vector2(152, 108), Vector2(112, 52), func(): run.attack(); _refresh_all(), true)
	combat_heavy = _button(combat_panel, "重击", Vector2(272, 108), Vector2(112, 52), func(): run.heavy_attack(); _refresh_all())
	combat_trap = _button(combat_panel, "捕兽夹", Vector2(392, 108), Vector2(100, 52), func(): run.use_combat_item("snare"); _refresh_all())
	combat_flare = _button(combat_panel, "焰筒", Vector2(500, 108), Vector2(100, 52), func(): run.use_combat_item("alchemist_flare"); _refresh_all())
	combat_smoke = _button(combat_panel, "烟囊", Vector2(608, 108), Vector2(96, 52), func(): run.use_combat_item("smoke_pouch"); _refresh_all())
	combat_flee = _button(combat_panel, "逃跑", Vector2(152, 166), Vector2(552, 34), func(): run.flee(); _refresh_all())

func _refresh_combat() -> void:
	if combat_panel == null: return
	var active_combat: bool = run != null and not run.combat.is_empty()
	combat_panel.visible = active_combat
	if not active_combat:
		return
	var enemy: Dictionary = run.combat
	combat_name.text = "%s · %s" % [str(enemy.get("name", "敌人")), "首领" if bool(enemy.get("boss", false)) else "敌人"]
	combat_hp.max_value = maxf(1.0, float(enemy.get("max_hp", 1.0)))
	combat_hp.value = float(enemy.get("hp", 0.0))
	combat_hp_text.text = "%d/%d" % [int(enemy.get("hp", 0)), int(enemy.get("max_hp", 1))]
	combat_enemy_art.texture = Art.enemy_texture(str(enemy.get("kind", "")))
	combat_attack.disabled = run.attack_cd > 0.0
	combat_heavy.disabled = run.heavy_cd > 0.0 or run.stamina < 12.0
	combat_trap.disabled = run.item_count("snare") <= 0
	combat_flare.disabled = run.item_count("alchemist_flare") <= 0
	combat_smoke.disabled = run.item_count("smoke_pouch") <= 0
	combat_trap.text = "捕兽夹 ×%d" % run.item_count("snare")
	combat_flare.text = "焰筒 ×%d" % run.item_count("alchemist_flare")
	combat_smoke.text = "烟囊 ×%d" % run.item_count("smoke_pouch")

# ------------------------------------------------------------------- result

func _on_run_finished(result: Dictionary) -> void:
	mode = "result"
	last_result = result
	event_open = false
	if event_overlay:
		event_overlay.visible = false
	_close_overlay(false)
	run_finished.emit(result)
	_refresh_all()
	_build_result(result)

func _build_result(result: Dictionary) -> void:
	_clear(result_layer)
	result_layer = Control.new()
	result_layer.name = "HuntResult"
	result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.02, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.add_child(dim)
	var victory := bool(result.get("victory", false))
	var panel := _panel(result_layer, Vector2(300, 90), Vector2(840, 720), Color(0.035, 0.045, 0.07, 0.99), victory)
	_label(panel, "撤离成功" if victory else "深潜吞没了你", Vector2(36, 30), Vector2(760, 54), 38, GOLD if victory else RED, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	_label(panel, str(result.get("reason", "")), Vector2(38, 90), Vector2(720, 30), 17, MUTED)
	_label(panel, "第 %d 天 · %s   ·   击杀 %d   ·   搜索 %d 次   ·   战利品价值 %d ◈" % [
		int(result.get("day", 1)), _clock_text(float(result.get("clock", 0.0))), int(result.get("kills", 0)),
		int(result.get("searched", 0)), int(result.get("value", 0))], Vector2(38, 132), Vector2(760, 28), 15, INK)
	var y := 190.0
	_label(panel, "战利品", Vector2(38, y), Vector2(200, 28), 20, GOLD)
	y += 38.0
	var loot: Array = result.get("loot", [])
	if loot.is_empty():
		_label(panel, "什么也没带回来。", Vector2(44, y), Vector2(600, 28), 16, MUTED)
		y += 36.0
	else:
		for entry in loot:
			var kind := str(entry.get("kind", ""))
			var tex := TextureRect.new()
			tex.texture = Art.icon(kind)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.position = Vector2(44, y - 2)
			tex.size = Vector2(30, 30)
			tex.modulate = Art.icon_modulate(kind)
			panel.add_child(tex)
			var label_text := Data.item_name(kind)
			if entry.has("tier"):
				label_text = "%s%s" % [Data.tier_name(int(entry.tier)), label_text]
			var suffix := ""
			if victory and not Catalog.hunt_exportable(kind):
				suffix = "   · 血潮留下的东西，带不出去"
			_label(panel, "%s ×%d%s" % [label_text, int(entry.get("count", 1)), suffix],
				Vector2(82, y), Vector2(700, 28), 16, INK)
			y += 34.0
			if y > 566:
				_label(panel, "……还有更多，已经一并结算。", Vector2(82, y), Vector2(600, 24), 13, MUTED)
				break
	var gear_lost: Array = result.get("gear_lost", [])
	if not gear_lost.is_empty():
		_label(panel, "带不出来的装备：%s" % "、".join(gear_lost), Vector2(38, 596), Vector2(760, 24), 12, Color("b58f8a"))
	var pocket_lost: Array = result.get("pocket_lost", [])
	var pocket_kept: Array = result.get("pocket_kept", [])
	var pocket_text := "随身物：这一局没有带东西下去。"
	if not pocket_lost.is_empty() or not pocket_kept.is_empty():
		pocket_text = "随身物：沉掉 %d 件%s · 留在袋里 %d 件" % [
			pocket_lost.size(),
			("（%s）" % "、".join(pocket_lost)) if not pocket_lost.is_empty() else "",
			pocket_kept.size()]
	_label(panel, pocket_text, Vector2(38, 618), Vector2(760, 24), 12, MUTED)
	_label(panel, "战利品已存入守夜人仓库。" if victory else "本局战利品全部丢失；仓库里的东西不会受影响。", Vector2(38, 644), Vector2(760, 24), 14, GREEN if victory else MUTED)
	_button(panel, "返回营地", Vector2(38, 674), Vector2(220, 44), func(): exit_requested.emit(), victory)
	_button(panel, "再来一局", Vector2(272, 674), Vector2(180, 44), func(): _retry())

func _retry() -> void:
	_clear(result_layer)
	result_layer = null
	mode = "briefing"
	show_briefing()

func _clock_text(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [int(total / 60), total % 60]

func _build_pause_overlay() -> void:
	pause_layer = Control.new()
	pause_layer.name = "HuntPause"
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.visible = false
	pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.02, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.add_child(dim)
	var panel := _panel(pause_layer, Vector2(470, 300), Vector2(500, 280), Color(0.035, 0.045, 0.07, 0.99))
	_label(panel, "暂 停", Vector2(30, 24), Vector2(300, 44), 32, INK, HORIZONTAL_ALIGNMENT_LEFT, title_font)
	_label(panel, "时间暂停。继续深潜，或放弃本局回到营地。", Vector2(32, 78), Vector2(430, 44), 14, MUTED)
	_button(panel, "继续", Vector2(32, 146), Vector2(190, 48), func(): _close_overlay(), true)
	_button(panel, "放弃本局", Vector2(238, 146), Vector2(190, 48), _forfeit)
	_button(panel, "回营地", Vector2(32, 210), Vector2(396, 40), func(): exit_requested.emit())

func _forfeit() -> void:
	if run and not run.ended_flag:
		run.finish(false, "主动放弃")
	_close_overlay(false)

# ------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not active or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		# 互动窗口吃掉其余按键，只留 Esc 收起（事件点本身会保留）。
		if event_open:
			if code == KEY_ESCAPE:
				_close_event_window()
				get_viewport().set_input_as_handled()
			return
		if overlay_kind != "":
			if code == KEY_ESCAPE or (overlay_kind == "map" and code == KEY_M) or (overlay_kind == "craft" and code == KEY_C) or (overlay_kind == "bag" and code == KEY_TAB):
				_close_overlay()
				get_viewport().set_input_as_handled()
			return
		if mode == "run":
			match code:
				KEY_ESCAPE:
					_open_overlay("pause")
				KEY_W:
					_do_search()
				KEY_Z:
					_do_form()
				KEY_M:
					_open_map()
				KEY_C:
					_open_craft()
				KEY_TAB:
					_open_bag()
				KEY_R:
					if run and run.rest():
						_refresh_all()
				_:
					return
			get_viewport().set_input_as_handled()
			return
		if mode == "result" and code == KEY_ESCAPE:
			exit_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if mode == "briefing" and code == KEY_ESCAPE:
			exit_requested.emit()
			get_viewport().set_input_as_handled()
			return

func _process(dt: float) -> void:
	if not active or not visible:
		return
	if mode == "run" and run:
		run.tick(dt)
		_refresh_search_fx(dt)
		_tick_search_fx_fade(dt)
		if run.ended_flag:
			if event_open:
				_close_event_window()
			return
		# live 事件不暂停：被耗死或被打断时把窗口收掉，别挡住结算。
		if event_open and run.event_state.is_empty():
			_close_event_window()

# ------------------------------------------------------------------ helpers

func _clear(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.queue_free()
	for child in node.get_children():
		child.queue_free()

func _clear_children(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _style(colour: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colour
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _panel(parent: Node, at: Vector2, dim: Vector2, colour: Color = PANEL, accent: bool = false) -> Panel:
	var p := Panel.new()
	p.position = at
	p.size = dim
	# 大面板套石板九宫格；340×196 这类小 HUD 条保持平涂，避免细边框压住文字。
	var framed := dim.x >= 420.0 and dim.y >= 180.0
	var art := Art.panel_style(colour.a, accent) if framed else null
	if art != null:
		p.add_theme_stylebox_override("panel", art)
	else:
		p.add_theme_stylebox_override("panel", _style(colour, Color("cbb087") if accent else Color(0.20, 0.22, 0.28, 0.9)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _label(parent: Node, text: String, at: Vector2, dim: Vector2, size: int = 16, colour: Color = INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, font: Font = null, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font if font != null else face_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	# 必须在设 size 之前打开换行：Label 的最小宽度会被不换行的整行文本撑大，
	# 先设 size 会被钳到文本宽度，之后再改 autowrap 也不会缩回去（中文必须用 ARBITRARY）。
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.position = at
	l.size = dim
	parent.add_child(l)
	return l

func _hud_icon(parent: Node, kind: String, at: Vector2, dim: Vector2, colour: Color) -> TextureRect:
	var node := TextureRect.new()
	# expand_mode 必须排在 size 之前：TextureRect 的最小尺寸等于纹理尺寸。
	node.texture = Art.icon(kind)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = at
	node.size = dim
	node.modulate = colour
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _button(parent: Node, text: String, at: Vector2, dim: Vector2, cb: Callable, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = at
	b.size = dim
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_override("font", face_font)
	b.add_theme_font_size_override("font_size", 17)
	var art_normal := Art.button_style(accent, "normal")
	if art_normal != null:
		b.add_theme_stylebox_override("normal", art_normal)
		b.add_theme_stylebox_override("hover", Art.button_style(accent, "hover"))
		b.add_theme_stylebox_override("pressed", Art.button_style(accent, "pressed"))
		b.add_theme_stylebox_override("disabled", Art.button_style(accent, "normal", true))
	else:
		var normal := _style(Color(0.06, 0.07, 0.10, 0.94), Color(0.26, 0.24, 0.26))
		var hover := _style(Color(0.10, 0.09, 0.12, 0.98), Color("cbb087"))
		var pressed := _style(Color(0.14, 0.11, 0.13, 1.0), Color("d8b58a"))
		var disabled := _style(Color(0.04, 0.045, 0.06, 0.9), Color(0.18, 0.19, 0.22))
		if accent:
			normal = _style(Color(0.32, 0.12, 0.16, 0.95), Color("d8a48a"))
			hover = _style(Color(0.42, 0.16, 0.20, 1.0), Color("f0c9a0"))
			pressed = _style(Color(0.50, 0.20, 0.24, 1.0), Color("ffd9b0"))
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", pressed)
		b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.48))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _bar(parent: Node, at: Vector2, dim: Vector2, colour: Color) -> Bar:
	var bar := Bar.new()
	bar.position = at
	bar.size = dim
	bar.colour = colour
	bar.max_value = 100.0
	bar.value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar

# --------------------------------------------------------------- marker classes

## 细条进度。不用 ProgressBar：它带主题字体，最小高度会被撑到 27px 左右，
## 传进来的 9~14px 高度会被静默放大，条子盖到下面的文字上（已踩过）。
class Bar extends Control:
	var value := 100.0:
		set(v):
			value = v
			queue_redraw()
	var max_value := 100.0:
		set(v):
			max_value = v
			queue_redraw()
	var colour := Color.WHITE:
		set(v):
			colour = v
			if _fill:
				_fill.bg_color = v
			queue_redraw()
	var _bg: StyleBoxFlat
	var _fill: StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg = StyleBoxFlat.new()
		_bg.bg_color = Color(0.04, 0.045, 0.06, 1.0)
		_bg.border_color = Color(0.18, 0.19, 0.22)
		_bg.set_border_width_all(1)
		_bg.set_corner_radius_all(4)
		_fill = StyleBoxFlat.new()
		_fill.bg_color = colour
		_fill.set_corner_radius_all(4)

	func _draw() -> void:
		if _bg == null:
			return
		draw_style_box(_bg, Rect2(Vector2.ZERO, size))
		var ratio := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
		if ratio <= 0.0:
			return
		var w: float = maxf(size.x * ratio, minf(size.y, size.x))
		draw_style_box(_fill, Rect2(Vector2(1, 1), Vector2(w - 2.0, size.y - 2.0)))

## 搜索仪式的进度环：底圈常驻，已完成的弧随 ratio 长出来。
class SearchRing extends Control:
	var ratio := 0.0:
		set(v):
			ratio = v
			queue_redraw()
	var tone := Color("c95666"):
		set(v):
			tone = v
			queue_redraw()

	func _draw() -> void:
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 8.0
		draw_arc(centre, radius, 0.0, TAU, 72, Color(0.22, 0.17, 0.19, 0.75), 2.0, true)
		draw_arc(centre, radius - 5.0, 0.0, TAU, 72, Color(0.14, 0.10, 0.12, 0.55), 1.0, true)
		if ratio <= 0.0:
			return
		draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0), 72, tone, 4.0, true)
		# 弧头一颗小血珠，转起来更像在"抽丝"。
		var head := -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0)
		draw_circle(centre + Vector2(cos(head), sin(head)) * radius, 4.0, tone.lightened(0.15))

## 随机事件点：黄色圆环 + 问号，不显示名字与提示。
## 同一个点可能是神龛、上锁的箱子、一具尸体或一条会动的走廊——点下去才知道。
## 圆环有一点点呼吸，悬停变亮；进出场由 `_refresh_markers()` 的 Tween 负责。
class EventMarker extends Control:
	signal pressed
	const Art = preload("res://scripts/hunt/hunt_art.gd")
	var run
	var marker: Dictionary = {}
	var hover := false
	var font: Font
	var pulse := 0.0

	func _ready() -> void:
		size = Vector2(140, 140)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		font = ThemeDB.fallback_font
		var face := FontVariation.new()
		face.base_font = load("res://assets/NotoSansSC.ttf")
		if face.base_font:
			font = face
		mouse_entered.connect(func():
			hover = true
			queue_redraw())
		mouse_exited.connect(func():
			hover = false
			queue_redraw())
		set_process(true)

	func _process(dt: float) -> void:
		pulse = fmod(pulse + dt, 4.0)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		if run == null or marker.is_empty():
			return
		var c := size * 0.5
		var breath := 0.86 + sin(pulse * 1.3) * 0.08
		var tint := Color(0.72, 0.66, 0.52, 0.80 * breath)
		if hover:
			tint = Color(0.92, 0.84, 0.66, 0.95)
		var tex := Art.hotspot_texture("ready")
		if tex != null:
			var ring := 104.0
			var ring_h := ring * float(tex.get_height()) / float(tex.get_width())
			draw_texture_rect(tex, Rect2(c - Vector2(ring, ring_h) * 0.5, Vector2(ring, ring_h)), false, tint)
		else:
			draw_circle(c, 26.0, Color(0.02, 0.025, 0.04, 0.72))
			draw_arc(c, 30.0, 0, TAU, 40, Color(tint, 0.9), 2.5, true)
			draw_arc(c, 38.0, 0, TAU, 40, Color(tint, 0.18), 1.0, true)
		# 圆心永远只有一个问号：名字、种类、危险程度都不提前透露。
		var glyph := "?"
		var glyph_w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(font, c + Vector2(-glyph_w * 0.5, 11), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
			Color(1.0, 0.90, 0.66, 0.92 * breath))


class SpotButton extends Control:
	signal pressed
	var run
	var spot: Dictionary = {}
	var hover := false
	var font: Font

	func _ready() -> void:
		size = Vector2(136, 136)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		font = ThemeDB.fallback_font
		var face := FontVariation.new()
		face.base_font = load("res://assets/NotoSansSC.ttf")
		if face.base_font: font = face
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
		set_process(true)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		if run == null or spot.is_empty(): return
		var c := size * 0.5
		var used: bool = run.hotspot_uses(str(spot.id)) <= 0
		var locked: bool = run.is_locked(str(spot.id))
		var searching: bool = not run.search.is_empty() and str(run.search.id) == str(spot.id)
		var colour := Color("cbb087")
		if used: colour = Color(0.35, 0.34, 0.33)
		elif locked: colour = Color("b28b5e")
		elif searching: colour = Color("e8b36a")
		if hover: colour = colour.lightened(0.2)
		draw_circle(c, 33.0, Color(0.02, 0.025, 0.04, 0.72))
		draw_arc(c, 36.0, 0, TAU, 40, Color(colour, 0.85), 2.0 if not searching else 3.0, true)
		draw_arc(c, 44.0, 0, TAU, 40, Color(colour, 0.18), 1.0, true)
		if searching:
			var total := maxf(0.01, float(run.search.get("total", 1.0)))
			var ratio := clampf(1.0 - float(run.search.left) / total, 0.0, 1.0)
			draw_arc(c, 36.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40, Color("ffe0a8"), 5.0, true)
		if locked:
			draw_rect(Rect2(c + Vector2(-8, -3), Vector2(16, 13)), Color(colour, 0.9), true)
			draw_arc(c + Vector2(0, -5), 7, PI, TAU, 12, Color(colour, 0.9), 2.0, true)
		elif used:
			draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), Color(colour, 0.9), 2.0)
		else:
			draw_circle(c, 4.0, Color(colour, 0.9))
		var label := str(spot.get("name", "容器"))
		if used: label = "已搜空 · " + label
		elif locked: label = "上锁 · " + label
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, c + Vector2(-width * 0.5, 68), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(colour, 0.95))
		draw_string(font, c + Vector2(-width * 0.5, 86), "剩余 %d 次" % run.hotspot_uses(str(spot.id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.70, 0.66, 0.60))

class EnemyButton extends Control:
	signal pressed
	const Data = preload("res://scripts/hunt/hunt_data.gd")
	const Art = preload("res://scripts/hunt/hunt_art.gd")
	var run
	var enemy: Dictionary = {}
	var hover := false
	var font: Font
	var texture: Texture2D

	func _ready() -> void:
		size = Vector2(150, 190)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		font = ThemeDB.fallback_font
		var face := FontVariation.new()
		face.base_font = load("res://assets/NotoSansSC.ttf")
		if face.base_font: font = face
		texture = Art.enemy_texture(str(enemy.get("kind", "")))
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
		set_process(true)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		if run == null or enemy.is_empty(): return
		var c := size * 0.5
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.05
		draw_circle(c + Vector2(0, 10), 54.0 * pulse, Color(0.55, 0.12, 0.18, 0.18))
		draw_arc(c + Vector2(0, 10), 50.0, 0, TAU, 36, Color(0.85, 0.30, 0.34, 0.55), 2.0, true)
		if texture:
			draw_texture_rect(texture, Rect2(Vector2(15, -12), Vector2(120, 150)), false, Color(1, 1, 1, 0.95))
		var name := str(enemy.get("name", "敌人"))
		var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, c + Vector2(-width * 0.5, 158), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.78, 0.75))
		var hp_ratio := clampf(float(enemy.get("hp", 1.0)) / maxf(1.0, float(enemy.get("max_hp", 1.0))), 0.0, 1.0)
		draw_rect(Rect2(c + Vector2(-44, 168), Vector2(88, 6)), Color(0.12, 0.10, 0.12))
		draw_rect(Rect2(c + Vector2(-44, 168), Vector2(88 * hp_ratio, 6)), Color(0.80, 0.28, 0.32))
