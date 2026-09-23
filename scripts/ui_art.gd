class_name TideUIArt
extends RefCounted

# One shared generated atlas keeps equipment, drag previews and HUD consistent.
const KINDS := ["armor", "sight", "boots", "medicine", "crystal", "scrap", "relic", "charm", "ammo", "backpack", "rifle", "sword", "heavy", "staff", "heart", "skill"]
static var icons: Dictionary = {}

static func icon(kind: String) -> Texture2D:
	if icons.has(kind):
		return icons[kind]
	var collectible := Catalog.collectible_index(kind)
	if collectible>=0:
		var atlas := AtlasTexture.new()
		atlas.atlas=load("res://assets/icons/collectibles-%02d.png" % (floori(float(collectible)/9.0)+1))
		var cell := atlas.atlas.get_size()/3.0
		var local := collectible%9
		atlas.region=Rect2(Vector2(local%3,floori(float(local)/3.0))*cell,cell)
		atlas.filter_clip=true
		icons[kind]=atlas
		return atlas
	if kind.begins_with("staff_"):
		icons[kind]=load("res://assets/icons/"+kind+".png")
		return icons[kind]
	var index := KINDS.find(kind)
	if index < 0:
		return load("res://assets/icons/" + kind + ".svg")
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/reliquary-transparent.png")
	var cell := atlas.atlas.get_size() / 4.0
	atlas.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
	atlas.filter_clip = true
	icons[kind] = atlas
	return atlas
