extends RefCounted
## 血潮猎场的占位图与立绘工具。
##
## 正式素材还没画：这里按分类复用现有图标并允许 UI 用物品色做 modulate；
## 以后把同名的 SVG 放进 assets/icons/ 就会自动优先使用真图，不用改代码。
## 三位基础角色的立绘用 body + face 差分合成；隐藏角色没有差分，退回整张立绘。

const Data = preload("res://scripts/hunt/hunt_data.gd")
const StoryArt = preload("res://scripts/story_portrait_art.gd")
const CATEGORY_ICON := {
	"material": "res://assets/icons/scrap.svg",
	"recovery": "res://assets/icons/medicine.svg",
	"weapon": "res://assets/icons/sword.svg",
	"armor": "res://assets/icons/armor.svg",
	"tool": "res://assets/icons/relic.svg",
}
static var icon_cache: Dictionary = {}
static var texture_cache: Dictionary = {}

static func icon(kind: String) -> Texture2D:
	if icon_cache.has(kind):
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

## Enemy art is a 4×3 action sheet (same layout as the field's enemy_frames).
## The hunt markers/portrait need one readable pose, not the whole contact sheet.
static func enemy_texture(kind: String) -> Texture2D:
	var path := "res://assets/enemies/" + str(Data.enemy(kind).get("art", "banished-knight.png"))
	var cache_key := "enemy:" + kind
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]
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

## 三位基础角色用整张差分；隐藏角色用唯一整图。
## `StoryArt.layers()` 已经是 vn-full-v3 的唯一读取口，这里不另抄 manifest。
static func portrait_texture(hero: int, expression: String) -> Texture2D:
	if hero >= 3:
		return texture("res://assets/portrait-3.png")
	var layers: Dictionary = StoryArt.layers(hero, expression, "regular", "front")
	return layers.get("body", null)

static func body_texture(hero: int) -> Texture2D:
	return portrait_texture(hero, "neutral")

static func face_texture(hero: int, expression: String) -> Texture2D:
	# 旧 body+face 叠层已不用；保留空实现给外部误调用时一个稳定的返回值。
	return null
