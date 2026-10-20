extends RefCounted
## 血潮深潜的取图口：正式素材（assets/hunt）优先，缺失时回退到旧占位图。
##
## 正式素材由 HUNT-ART-PROMPTS.md 的提示词逐张生成（gpt-image-2.5-sunburst，2K），
## 品红底版本用 tools 里的脚本抠成 `*_alpha.png`，图标/敌人再按格切成 individual。
## 本文件只做「kind → 路径」的解析与缓存，不持有节点、不写状态。
##
## 回退顺序：assets/hunt/... → 旧占位（assets/icons/*.svg、assets/enemies/*.png）。
## 这样素材目录被清掉时游戏仍能跑，只是退回旧观感。

const Data = preload("res://scripts/hunt/hunt_data.gd")
const StoryArt = preload("res://scripts/story_portrait_art.gd")

const HUNT := "res://assets/hunt/"
const BG_DIR := HUNT + "backgrounds/"
const ICON_DIR := HUNT + "icons/individual/"
const ENEMY_DIR := HUNT + "enemies/individual/"
const PORTRAIT_DIR := HUNT + "portraits/"
const EVENT_DIR := HUNT + "events/"
const UI_DIR := HUNT + "ui/"
const UI_CROP := UI_DIR + "crops/"

const CATEGORY_ICON := {
	"material": "res://assets/icons/scrap.svg",
	"recovery": "res://assets/icons/medicine.svg",
	"weapon": "res://assets/icons/sword.svg",
	"armor": "res://assets/icons/armor.svg",
	"tool": "res://assets/icons/relic.svg",
}

## 图标表：严格按生成提示词里的表格顺序（从左到右、从上到下）。
## 每张表 4 列；下标 i 的格子是 r(i/4+1)c(i%4+1)。
## 改提示词/重生成素材时，只改这里，不要在校验代码里抄第二份顺序。
const ICON_SHEETS := {
	"materials_a": [
		"branch", "stone", "cloth", "dirty_water",
		"clean_water", "honey", "wild_herb", "iron",
		"nail", "leather", "rope", "resin",
		"storm_phial", "glass", "paper", "oil",
	],
	"materials_b": [
		"brimstone", "bandage", "mead", "herbal_tea",
		"poppy_syrup", "blood_draught", "salve", "herbal_bandage",
		"frenzy_phial",
	],
	"weapons": [
		"stone_axe", "spear", "spiked_club", "iron_mace",
		"machete", "crossbow", "hand_cannon", "heavy_axe",
		"iron_maul",
	],
	"armor_tools_a": [
		"cloth_armor", "leather_armor", "ring_mail", "hunter_cloak",
		"armor_patch", "torch", "lockpick", "snare",
		"alchemist_flare", "smoke_pouch", "armor_kit", "lead_shot",
		"spirit_horn", "pack_straps", "plague_mask", "key",
	],
	"tools_b_ui": [
		"hunt_bait", "charcoal_filter", "blood_sigil", "ui_hp",
		"ui_stamina", "ui_attack", "ui_defense", "ui_day",
		"ui_dusk", "ui_night", "ui_search", "ui_map",
		"ui_craft", "ui_bag", "ui_extract",
	],
}

## 正式立绘只有 8 个表情；规则层仍会说 smile / determined / worried。
## 没做差分的表情就近映射，别让立绘在搜索成功时突然变回平静脸。
const HUNT_EXPRESSIONS := {
	"smile": "joy",
	"determined": "smirk",
	"worried": "afraid",
	"surprised": "afraid",
	"shy": "sad",
}

static var icon_cache: Dictionary = {}
static var texture_cache: Dictionary = {}
static var icon_index: Dictionary = {}
static var hunt_icon_flags: Dictionary = {}
static var style_cache: Dictionary = {}

static func _icon_index() -> Dictionary:
	if not icon_index.is_empty():
		return icon_index
	for sheet in ICON_SHEETS:
		var ids: Array = ICON_SHEETS[sheet]
		for i in ids.size():
			icon_index[str(ids[i])] = "%s%s_r%dc%d.png" % [ICON_DIR, sheet, i / 4 + 1, i % 4 + 1]
	return icon_index

static func hunt_icon_path(kind: String) -> String:
	var index := _icon_index()
	return str(index.get(kind, ""))

static func has_hunt_icon(kind: String) -> bool:
	if hunt_icon_flags.has(kind):
		return bool(hunt_icon_flags[kind])
	var path := hunt_icon_path(kind)
	var ok := not path.is_empty() and ResourceLoader.exists(path)
	hunt_icon_flags[kind] = ok
	return ok

static func icon(kind: String) -> Texture2D:
	if icon_cache.has(kind):
		return icon_cache[kind]
	var own_hunt := hunt_icon_path(kind)
	if not own_hunt.is_empty() and ResourceLoader.exists(own_hunt):
		icon_cache[kind] = load(own_hunt)
		return icon_cache[kind]
	var own := "res://assets/icons/" + kind + ".svg"
	if ResourceLoader.exists(own):
		icon_cache[kind] = load(own)
		return icon_cache[kind]
	var entry: Dictionary = Data.ITEMS.get(kind, {})
	var cat := str(entry.get("cat", "material"))
	var path: String = CATEGORY_ICON.get(cat, CATEGORY_ICON["material"])
	icon_cache[kind] = load(path)
	return icon_cache[kind]

## 正式图标是彩色厚涂，不能再拿物品色去乘；只有回退到旧单色 SVG 时才染色。
static func icon_modulate(kind: String) -> Color:
	if has_hunt_icon(kind):
		return Color.WHITE
	return tint(kind)

static func tint(kind: String) -> Color:
	var entry: Dictionary = Data.ITEMS.get(kind, {})
	return entry.get("color", Color("cbb087"))

static func texture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	if not ResourceLoader.exists(path):
		return null
	texture_cache[path] = load(path)
	return texture_cache[path]

## 地区背景：8 区 × day/dusk/night。缺时段就先退回白昼，再退回 null（老 3D 箱庭）。
static func background(area: String, phase: String) -> Texture2D:
	var key := "bg:%s:%s" % [area, phase]
	if texture_cache.has(key):
		return texture_cache[key]
	var path := "%s%s_%s.png" % [BG_DIR, area, phase]
	if not ResourceLoader.exists(path):
		path = "%s%s_day.png" % [BG_DIR, area]
	if not ResourceLoader.exists(path):
		return null
	texture_cache[key] = load(path)
	return texture_cache[key]

static func map_texture() -> Texture2D:
	return texture(HUNT + "map/region_map.png")

## 互动事件的物件插图：黑底生图，暗色面板上直接铺；缺图返回 null（只显示文字）。
static func event_texture(key: String) -> Texture2D:
	if key.is_empty():
		return null
	return texture("%s%s.png" % [EVENT_DIR, key])

static func ui_texture(name: String) -> Texture2D:
	return texture(UI_DIR + name)

static func crop_texture(name: String) -> Texture2D:
	return texture(UI_CROP + name)

## 九宫格面板：用的是正式面板图里「石板 + 细金边」的内圈，不是外面那圈厚木框。
## 厚木框有 140px，塞进 340×196 的 HUD 条会把内容全吃掉，留给以后专门的 UI 版式。
static func panel_style(alpha: float = 1.0, warm: bool = false) -> StyleBoxTexture:
	var tex := crop_texture("panel.png")
	if tex == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.set_texture_margin_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.modulate_color = Color(1.0, 0.86, 0.82, alpha) if warm else Color(0.86, 0.89, 0.96, alpha)
	return style

## 按钮只切左右两端（上下跟着控件高度缩），否则 40px 高的按钮会被木框吃掉。
static func button_style(accent: bool, state: String, disabled: bool = false) -> StyleBoxTexture:
	var file := "button_%s_set_%s.png" % ["accent" if accent else "normal", state]
	var tex := crop_texture(file)
	if tex == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = 46
	style.texture_margin_right = 46
	style.texture_margin_top = 0
	style.texture_margin_bottom = 0
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if disabled:
		style.modulate_color = Color(0.48, 0.48, 0.54, 0.86)
	return style

static func toast_style() -> StyleBoxTexture:
	var tex := crop_texture("toast.png")
	if tex == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = 44
	style.texture_margin_right = 44
	style.texture_margin_top = 0
	style.texture_margin_bottom = 0
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

## 互动点圆环：ready / used / locked 三态。
static func hotspot_texture(state: String) -> Texture2D:
	var file := "hotspot_%s.png" % state
	return crop_texture(file)

## 敌人：正式动作表的第一格（正面待机）当静态图；没有就退回旧 4×3 表的第一格。
static func enemy_texture(kind: String) -> Texture2D:
	var cache_key := "enemy:" + kind
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]
	var hunt_path := "%s%s_sheet_r1c1.png" % [ENEMY_DIR, kind]
	if ResourceLoader.exists(hunt_path):
		texture_cache[cache_key] = load(hunt_path)
		return texture_cache[cache_key]
	var path := "res://assets/enemies/" + str(Data.enemy(kind).get("art", "banished-knight.png"))
	if not ResourceLoader.exists(path):
		return null
	var sheet := load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, sheet.get_width() / 4.0, sheet.get_height() / 3.0)
	texture_cache[cache_key] = atlas
	return atlas

static func portrait_data(hero: int) -> Dictionary:
	return Data.PORTRAITS.get(clampi(hero, 0, 3), Data.PORTRAITS[3])

## 三位基础角色沿用 vn-full-v3 整张差分；隐藏角色（墓煜）用深潜新画的 8 表情立绘。
## `StoryArt.layers()` 已经是 vn-full-v3 的唯一读取口，这里不另抄 manifest。
static func portrait_texture(hero: int, expression: String) -> Texture2D:
	if hero >= 3:
		var name := str(HUNT_EXPRESSIONS.get(expression, expression))
		var path := "%sportrait_%s_alpha.png" % [PORTRAIT_DIR, name]
		if not ResourceLoader.exists(path):
			path = "%sportrait_neutral_alpha.png" % PORTRAIT_DIR
		var own := texture(path)
		if own != null:
			return own
		return texture("res://assets/portrait-3.png")
	var layers: Dictionary = StoryArt.layers(hero, expression, "regular", "front")
	return layers.get("body", null)

static func body_texture(hero: int) -> Texture2D:
	return portrait_texture(hero, "neutral")

static func face_texture(_hero: int, _expression: String) -> Texture2D:
	# 旧 body+face 叠层已不用；保留空实现给外部误调用时一个稳定的返回值。
	return null
