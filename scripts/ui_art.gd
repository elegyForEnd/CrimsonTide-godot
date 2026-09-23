class_name TideUIArt
extends RefCounted

# One shared generated atlas keeps equipment, drag previews and HUD consistent.
const KINDS := ["armor", "sight", "boots", "medicine", "crystal", "scrap", "relic", "charm", "ammo", "backpack", "rifle", "sword", "heavy", "staff", "heart", "skill"]
# Kinds whose art is a standalone PNG instead of a cell of the shared reliquary
# atlas: the eight field staves, plus the recruit's trinket and issue weapon.
const SOLO_PNG := ["staff_meteor","staff_needle","staff_chain","staff_moon",
	"staff_prism","staff_scatter","staff_vortex","staff_eclipse"]
# Kinds drawn as vector art beside the atlas's kind icons.
const SOLO_SVG := ["amulet","soul_scythe","grimoire_staff"]
static var icons: Dictionary = {}

static func icon(kind: String) -> Texture2D:
	if icons.has(kind):
		return icons[kind]
	if kind in SOLO_SVG:
		icons[kind]=load("res://assets/icons/"+kind+".svg")
		return icons[kind]
	if kind in SOLO_PNG or kind.begins_with("staff_"):
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
