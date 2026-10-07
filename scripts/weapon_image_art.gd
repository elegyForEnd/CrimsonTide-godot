extends RefCounted
## Independent original square ImageGen sprites; no sheets or pixel modification.
const BASE := "res://assets/combat/imagegen-square/"
const MECHANICS_BASE := "res://assets/combat/imagegen-mechanics/"
const CAMPAIGN_MAP := [624,600,612,636,637,638,639,640,641,642,643,644,601,602,613,614,625,17,18,19,20]
static var cells: Dictionary={}
static var mechanics: Dictionary={}

static func mechanic_source(role: String) -> String:
	return {"cast_star":"projectile_star","cast_light":"projectile_star","cast_ice":"projectile_needle","cast_fire":"projectile_feather","cast_storm":"projectile_lightning","cast_moon":"projectile_moon","cast_void":"projectile_vortex","cast_soul":"projectile_soul","cast_bell":"projectile_star","beam_eclipse":"beam_light","beam_moon":"beam_light"}.get(role,role)

static func mechanic_texture(role: String) -> Texture2D:
	var source := mechanic_source(role)
	var key := "mechanic:"+source
	if cells.has(key): return cells[key]
	var path := MECHANICS_BASE+source+".png"
	if not ResourceLoader.exists(path): return null
	cells[key]=load(path)
	return cells[key]

static func mechanic_ink(role: String) -> Rect2:
	if mechanics.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(MECHANICS_BASE+"manifest.json"))
		if parsed is Dictionary: mechanics=parsed.get("assets",{})
	var entry: Dictionary=mechanics.get(mechanic_source(role),{})
	var ink: Array=entry.get("ink",[0,0,1254,1254])
	return Rect2(ink[0],ink[1],ink[2]-ink[0],ink[3]-ink[1])

static func stamp_mechanic(target: CanvasItem, role: String, bounds: Vector2, tint: Color, min_thickness: float = 0.0) -> void:
	var art := mechanic_texture(role)
	if art==null: return
	var ink := mechanic_ink(role)
	var scale := minf(bounds.x/ink.size.x,bounds.y/ink.size.y)
	# Preserve length and center; presentation can thicken a narrow stroke in flight.
	var ink_scale := Vector2(scale,maxf(scale,min_thickness/ink.size.y))
	target.draw_texture_rect(art,Rect2(-ink.get_center()*ink_scale,art.get_size()*ink_scale),false,tint)

static func canonical(index: int) -> int:
	return index if index>=600 and index<648 else CAMPAIGN_MAP[clampi(index,0,20)]

static func available(index: int) -> bool:
	return ResourceLoader.exists(BASE+"weapon_%d_release.png" % canonical(index))

static func distinct_stage(index: int, stage: int) -> bool:
	var phase: String=["release","return","finisher"][clampi(stage,0,2)]
	return ResourceLoader.exists(BASE+"weapon_%d_%s.png" % [canonical(index),phase])

static func texture(index: int, stage: int) -> Texture2D:
	var id := canonical(index)
	var key := "%d:%d" % [id,clampi(stage,0,2)]
	if cells.has(key): return cells[key]
	if not available(index): return null
	var phase: String=["release","return","finisher"][clampi(stage,0,2)]
	var path := BASE+"weapon_%d_%s.png" % [id,phase]
	if not ResourceLoader.exists(path): path=BASE+"weapon_%d_release.png" % id
	if not ResourceLoader.exists(path): return null
	cells[key]=load(path)
	return cells[key]

static func hero_texture(hero: int, route: int) -> Texture2D:
	var key := "hero:%d:%d" % [hero,route]
	if cells.has(key): return cells[key]
	# Existing original ImageGen hero art remains square and matches the character.
	var cue: String=["dash","charge","ultimate","ultimate"][clampi(route,0,3)]
	var path := "res://assets/combat/imagegen/hero_%d_%s.png" % [hero,cue]
	if not ResourceLoader.exists(path): return null
	cells[key]=load(path)
	return cells[key]

static func overlay(index: int, stage: int) -> Texture2D:
	if stage<=0: return null
	var phase: String=["release","return","finisher"][clampi(stage,0,2)]
	if ResourceLoader.exists(BASE+"weapon_%d_%s.png" % [canonical(index),phase]): return null
	var key := "combo_%d_%s" % [Catalog.weapon_family(index),phase]
	if cells.has(key): return cells[key]
	if not ResourceLoader.exists(BASE+key+".png"): return null
	cells[key]=load(BASE+key+".png")
	return cells[key]

static func core_texture(id: int) -> Texture2D:
	var key := "core_%02d" % id
	if cells.has(key): return cells[key]
	if not ResourceLoader.exists(BASE+key+".png"): return null
	cells[key]=load(BASE+key+".png")
	return cells[key]
