extends Node2D
## 开发者模式 · 判定框总览（**仅开发可见**；正式对局零可见、零行为影响）。
##
## 开关：环境变量 `CRIMSON_DEV_RANGES`（`开发者模式启动.cmd` 会设成 `all`）。
## 铁律：**只读**——只画 `session` 里已经存在的状态与公开常量，绝不改数值、不写 session、
## 不吃 `s.rng`、不碰任何命中判定（与 §11.9「权威端才做规则」同一条精神）。
##
## 本文件目前只挂**第一批**：魔境 2D 战场（灵体索敌四档 + 角色/怪物判定半径）。
## 剩余批次（营地设施交互框、搜打撤 3D、房型/地形/地形碰撞、UI 交互框）的清单、代码入口与
## 验收标准写在**工作区上一层**的 `任务.md` 里——加批次的写法见下面 `draw_*()` 三段的注释。
const Build = preload("res://scripts/rogue_build.gd")
const PLAYER_RADIUS := 15.0   # `ruins.gd move()` 的默认碰撞半径（角色地形判定）
const FALLBACK_ENEMY_RADIUS := 13.0  # `rogue_combat.setup_minion()` 的 `rogue_radius` 兜底值

const INK := Color(1, .97, .92, .95)
const C_SEEK := Color(.45, .85, 1, .55)
const C_NEAR := Color(.80, .60, 1, .45)
const C_RANGE := Color(1, .92, .45, .38)
const C_KEEP := Color(1, .72, .35, .28)
const C_PLAYER := Color(.50, 1, .60, .85)
const C_ENEMY := Color(1, .45, .45, .75)
const C_TARGET := Color(1, .42, .42, .70)

var main                      # main.gd（取 session；宿主由 main.gd 把这个节点挂进战场）
var show_labels := true       # F9 可切（见 _input）

func _ready() -> void:
	z_index = 4096            # 画在所有游戏内容之上
	set_process(true)

## 环境变量开了才算开发者模式；`0/off/false/no` 都当关。
static func enabled() -> bool:
	var flag := OS.get_environment("CRIMSON_DEV_RANGES").strip_edges().to_lower()
	return not (flag in ["", "0", "off", "false", "no"])

func _process(_dt: float) -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		show_labels = not show_labels

func _draw() -> void:
	var session = main.session if main != null else null
	if session == null:
		return
	var font := ThemeDB.fallback_font
	# 世界坐标：跟当前战场相机对齐（宿主是 `rogue_field`，它自己负责取景）。
	draw_set_transform(-camera())
	draw_souls(session, font)
	draw_actors(session, font)
	# 屏幕坐标：图例固定在左上角。
	draw_set_transform(Vector2.ZERO)
	draw_legend(font)

func camera() -> Vector2:
	var host := get_parent()
	if host != null and host.has_method("camera_offset"):
		return host.camera_offset()
	return Vector2.ZERO

# —— 批次 1：引魂灵体（四档半径＝设计规则本身；数值来源 `rogue_build.gd:19-27`）——
func draw_souls(session, font: Font) -> void:
	for p in session.players.values():
		var souls: Array = p.get("build_summons", [])
		var focus: Dictionary = Build.enemy_by_id(session, int(p.get("soul_focus", -1)))
		if souls.is_empty() and focus.is_empty():
			continue
		ring(p.p, Build.SOUL_SEEK, C_SEEK, 2.0)
		label(font, p.p + Vector2(-58, Build.SOUL_SEEK + 4), "主人索敌圈 %.0f" % Build.SOUL_SEEK, C_SEEK)
		if not focus.is_empty():
			ring(focus.p, 20.0, Color(1, .55, .55, .9), 2.0)
			label(font, focus.p + Vector2(-40, -26), "主人点名的目标", Color(1, .7, .7, .95))
		for soul in souls:
			ring(soul.p, Build.SOUL_NEAR, C_NEAR, 1.5)
			ring(soul.p, Build.SOUL_RANGE, C_RANGE, 1.0)
			ring(soul.p, Build.SOUL_KEEP, C_KEEP, 1.0)
			var target: Dictionary = Build.enemy_by_id(session, int(soul.get("target", -1)))
			if not target.is_empty():
				draw_line(soul.p, target.p, C_TARGET, 2.0)
			label(font, soul.p + Vector2(-46, -64), "灵体 · %s" % str(soul.get("tier", "?")), INK)

# —— 批次 1：角色 / 怪物的判定半径 ——
func draw_actors(session, font: Font) -> void:
	for p in session.players.values():
		ring(p.p, PLAYER_RADIUS, C_PLAYER, 2.0)
		if show_labels:
			label(font, p.p + Vector2(-58, -PLAYER_RADIUS - 6), "角色地形判定 %.0f" % PLAYER_RADIUS, C_PLAYER)
	for e in session.enemies:
		var radius := float(e.get("rogue_radius", FALLBACK_ENEMY_RADIUS))
		ring(e.p, radius, C_ENEMY, 2.0)

func draw_legend(font: Font) -> void:
	var rows := [
		"【开发者模式】判定框总览 · CRIMSON_DEV_RANGES=%s" % OS.get_environment("CRIMSON_DEV_RANGES"),
		"青 主人索敌圈 %.0f ｜ 紫 灵体索敌圈 %.0f ｜ 黄 灵体射程 %.0f ｜ 橙 停靠 %.0f" % [Build.SOUL_SEEK, Build.SOUL_NEAR, Build.SOUL_RANGE, Build.SOUL_KEEP],
		"绿 角色地形判定 %.0f ｜ 红 怪物半径 ｜ 红线 灵体当前目标 ｜ F9 收起文字" % PLAYER_RADIUS,
		"批次 2-4（营地交互框 / 搜打撤 3D / 房型地形）见工作区上一层 任务.md",
	]
	var box := Rect2(24, 132, 700, 22 * rows.size() + 16)
	draw_rect(box, Color(0, 0, 0, .55), true)
	draw_rect(box, Color(1, .85, .5, .45), false, 1.0)
	for i in rows.size():
		draw_string(font, box.position + Vector2(12, 24 + 22 * i), rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)

# —— 画框工具 ——
func ring(at: Vector2, radius: float, color: Color, width: float) -> void:
	if radius <= 0.0:
		return
	draw_arc(at, radius, 0, TAU, maxi(24, int(radius * 0.5)), color, width, true)

func label(font: Font, at: Vector2, text: String, color: Color) -> void:
	if not show_labels:
		return
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
