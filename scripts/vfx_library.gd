extends RefCounted
## Every key is a standalone PNG, with its own importer and transparent padding.
const BASE := "res://assets/combat/standalone/"
const IMAGE_BASE := "res://assets/combat/imagegen/"
const ImageArt=preload("res://scripts/weapon_image_art.gd")
const SPELL_WEAPONS := [4,5,6,7,8,9,10,11]
const WEAPON_COLORS := [Color("ffd795"),Color("ff426c"),Color("ffb861"),Color("9be3ff"),
	Color("ff713d"),Color("85f0ff"),Color("acacff"),Color("d5b6ff"),Color("fff0a3"),
	Color("ffae6c"),Color("b57cff"),Color("ed86d2"),Color("ece1ff"),Color("ff87af"),
	Color("71d6ec"),Color("ffcc8a"),Color("b7dfaa"),Color("e1a0b0"),Color("9ee8d9"),
	Color("c1a5ef"),Color("d771ff")]
static var cache: Dictionary={}
static var blade_contacts: Dictionary={}

## Find the painted blade's bright contact point near its transverse middle.
## Stored in native UV; source PNG and aspect ratio remain untouched.
static func blade_contact(key: String) -> Vector2:
	if blade_contacts.has(key): return blade_contacts[key]
	var image := texture(key).get_image()
	var size := image.get_size()
	var best := -1.0
	var point := Vector2(size)*.5
	for x in range(int(size.x*.1),int(size.x*.95),2):
		if (float(x)/size.x-.5)*facing_scale(key)<.08: continue
		var strength := 0.0
		var weighted_y := 0.0
		for y in range(int(size.y*.46),int(size.y*.54),2):
			var c := image.get_pixel(x,y)
			var weight := c.a*(c.r+c.g+c.b)
			strength+=weight
			weighted_y+=y*weight
		if strength>best and strength>0:
			best=strength
			point=Vector2(x,weighted_y/strength)
	blade_contacts[key]=point/Vector2(size)-Vector2.ONE*.5
	return blade_contacts[key]
## Inspected source silhouettes: these crescents have their solid blade at LEFT.
const LEFT_FACING_WEAPONS := [7,14,17,19]

static func source_weapon(key: String) -> int:
	if key.begins_with("weapon_"): return int(key.get_slice("_",1))
	if key.begins_with("spell_"): return SPELL_WEAPONS[clampi(int(key.get_slice("_",1)),0,7)]
	if key.begins_with("common_"):
		return -1 # Utility signals are not weapon attacks.
	return -1

static func facing_scale(key: String) -> float:
	if source_weapon(key)>=0 and ImageArt.available(source_weapon(key)): return 1.0
	return -1.0 if source_weapon(key) in LEFT_FACING_WEAPONS else 1.0

static func fitted_size(key: String, bounds: Vector2) -> Vector2:
	var native := texture(key).get_size()
	return native*minf(absf(bounds.x)/native.x,absf(bounds.y)/native.y)

static func texture(key: String) -> Texture2D:
	if not cache.has(key):
		var source := key
		if key.begins_with("weapon_"):
			var index := int(key.get_slice("_",1))
			var phase := key.get_slice("_",2)
			var art := ImageArt.texture(index,2 if phase=="finisher" else 1 if phase=="return" else 0)
			if art:
				cache[key]=art
				return art
			source="weapon_%02d_release" % Catalog.visual_weapon_index(index)
		elif key.begins_with("spell_"):
			var art := ImageArt.texture(SPELL_WEAPONS[clampi(int(key.get_slice("_",1)),0,7)],0)
			if art:
				cache[key]=art
				return art
			source="weapon_%02d_release" % SPELL_WEAPONS[clampi(int(key.get_slice("_",1)),0,7)]
		elif key.begins_with("hero_"):
			source=key if key.ends_with("_dash") or key.ends_with("_charge") or key.ends_with("_ultimate") else "hero_%d_ultimate" % int(key.get_slice("_",1))
		elif key.begins_with("common_"):
			cache[key]=load(BASE+key+".png")
			return cache[key]
		elif key=="spark":
			source="hit_flash"
		var image_path := IMAGE_BASE+source+".png"
		cache[key]=load(image_path if ResourceLoader.exists(image_path) else BASE+key+".png")
	return cache[key]

static func weapon_key(index: int, phase: String = "release") -> String:
	return "weapon_%02d_%s" % [index,phase]

static func weapon_color(index: int) -> Color:
	return preload("res://scripts/weapon_vfx.gd").profile(index).color
