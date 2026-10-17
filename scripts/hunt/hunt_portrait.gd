extends Control
## 左下角角色立绘。
##
## 三位基础角色直接使用 `assets/story/vn-full-v3/` 的整张差分立绘（8 种表情，
## 常服 / 正面），不再做 body+face 叠层——那套 face 图只有五官、没有皮肤底色，
## 盖不住 body 自带的平静脸，表情切了也看不出来。隐藏角色没有 vn-full 差分，
## 退回 `portrait-3.png`，表情切换会安静地保持不变。
## 这是展示层：不读规则、不写存档，只响应 set_hero / set_expression。

const Art = preload("res://scripts/hunt/hunt_art.gd")
const BOX := Vector2(316, 474)

var hero := 0
var expression := "neutral"
var body: TextureRect

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size == Vector2.ZERO:
		size = BOX
	body = TextureRect.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	body.z_index = 0
	add_child(body)
	refresh()
	resized.connect(refresh)

func set_hero(value: int) -> void:
	hero = clampi(value, 0, 3)
	refresh()

func set_expression(value: String) -> void:
	if value == expression:
		return
	expression = value
	refresh()

func refresh() -> void:
	if not is_instance_valid(body):
		return
	var box := size if size.x > 1.0 and size.y > 1.0 else BOX
	var tex := Art.portrait_texture(hero, expression)
	body.texture = tex
	if tex == null:
		return
	if hero >= 3:
		# 隐藏角色只有一张整图：按高度铺满，水平居中裁切。
		var scale := box.y / float(tex.get_height())
		var body_size := Vector2(tex.get_width(), tex.get_height()) * scale
		body.position = Vector2((box.x - body_size.x) * 0.5, 0)
		body.size = body_size
	else:
		# vn-full-v3 是 2160×3840 的整张全身立绘：按宽度铺满，从头顶开始裁出胸像。
		var scale := box.x / float(tex.get_width())
		var body_size := Vector2(tex.get_width(), tex.get_height()) * scale
		body.position = Vector2(0, 0)
		body.size = body_size
