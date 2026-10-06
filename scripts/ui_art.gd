class_name TideUIArt
extends RefCounted

# Homestead produce lives in its own generated atlas. Referenced by script, not
# by global class name: in a headless --script run the class-name cache may not
# be warm yet, and a plain preload always resolves.
const HomeArt = preload("res://scripts/home_art.gd")

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
	# Homestead produce keeps its own generated atlas. The camp economy, the
	# carried backpack and the ground drops all draw the same six cells, so route
	# those kinds to the home art instead of falling through to a missing SVG.
	if HomeArt.has_icon(kind):
		var home := HomeArt.icon(kind)
		if home != null:
			icons[kind]=home
			return home
	# A seed packet has no art of its own: it shows the crop it grows. Without this the
	# three seeds were the only homestead kinds with no icon at all, and every run asked
	# the loader for a file that was never drawn.
	if kind.ends_with("_seed"):
		var crop := kind.trim_suffix("_seed")
		if HomeArt.has_icon(crop):
			var crop_art := HomeArt.icon(crop)
			if crop_art != null:
				icons[kind]=crop_art
				return crop_art
	if kind in SOLO_SVG:
		icons[kind]=load("res://assets/icons/"+kind+".svg")
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
	if kind in SOLO_PNG or kind.begins_with("staff_"):
		icons[kind]=load("res://assets/icons/"+kind+".png")
		return icons[kind]
	var index := KINDS.find(kind)
	if index < 0:
		# The last resort is a bespoke SVG, and whether one exists is asked *before*
		# loading it: a missing file used to print "Resource file not found" for every kind
		# the tables do not know, which is noise rather than information. Returning null
		# lets the caller draw its own fallback.
		var svg := "res://assets/icons/" + kind + ".svg"
		if not ResourceLoader.exists(svg):
			return null
		icons[kind]=load(svg)
		return icons[kind]
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/reliquary-transparent.png")
	var cell := atlas.atlas.get_size() / 4.0
	atlas.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
	atlas.filter_clip = true
	icons[kind] = atlas
	return atlas
