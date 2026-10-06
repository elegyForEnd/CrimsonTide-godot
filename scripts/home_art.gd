class_name HomeArt
extends RefCounted
## Built-in ImageGen assets, kept in the project. Atlas regions preserve alpha.
const ATLAS := "res://assets/home/generated/items-v1.png"
const ICONS := {"wheat":0,"carrot":1,"herb":2,"seeds":3,"silver":4,"moon":5,"gold":6,"rod":7,"bread":8,"stew":9,"tea":10,"bait":11}
static var atlas: Texture2D
static var regions: Dictionary = {}
static func has_icon(key: String) -> bool:
	return ICONS.has(key)
static func icon(key: String) -> Texture2D:
	if not ICONS.has(key): return null
	if regions.has(key): return regions[key]
	if not atlas: atlas = load(ATLAS)
	var index: int = ICONS[key]
	var cell := Vector2(atlas.get_width()/4.0,atlas.get_height()/3.0)
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(index%4,int(index/4))*cell,cell)
	texture.filter_clip = true
	regions[key] = texture
	return texture
