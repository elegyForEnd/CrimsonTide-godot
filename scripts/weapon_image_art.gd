extends RefCounted
## Independent original square ImageGen sprites; no sheets or pixel modification.
const BASE := "res://assets/combat/imagegen-square/"
const CAMPAIGN_MAP := [624,600,612,636,637,638,639,640,641,642,643,644,601,602,613,614,625,17,18,19,20]
static var cells: Dictionary={}

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
