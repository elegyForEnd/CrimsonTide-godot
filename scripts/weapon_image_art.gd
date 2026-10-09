extends RefCounted
## Independent original square ImageGen sprites; no sheets or pixel modification.
const BASE := "res://assets/combat/imagegen-square/"
const MECHANICS_BASE := "res://assets/combat/imagegen-mechanics/"
const CAMPAIGN_MAP := [624,600,612,636,637,638,639,640,641,642,643,644,601,602,613,614,625,17,18,19,20]
static var cells: Dictionary={}
static var mechanics: Dictionary={}
static var weapon_manifest: Dictionary={}
static var mechanic_contacts: Dictionary={}
const REDRAWN := ["motion_slash","motion_double_slash","motion_thrust","motion_heavy_slash","motion_spin","motion_heavy_spin","motion_scythe","motion_narrow_sweep","projectile_moon","projectile_arrow","projectile_needle","projectile_bullet","projectile_lightning","release_bow"]

static func mechanic_source(role: String) -> String:
	if role in ["motion_quake","motion_hammer_spin"]: return "motion_quake_v2"
	if role=="motion_heavy_slash": return "motion_heavy_slash_v3"
	if role=="motion_double_slash": return "motion_double_slash_v3"
	if role=="motion_heavy_overhead": return "motion_heavy_overhead_v2"
	var source: String={"cast_star":"projectile_star","cast_light":"projectile_star","cast_ice":"projectile_needle","cast_fire":"projectile_feather","cast_storm":"projectile_lightning","cast_moon":"projectile_moon","cast_void":"projectile_vortex","cast_soul":"projectile_soul","cast_bell":"projectile_star","beam_eclipse":"beam_light","beam_moon":"beam_light"}.get(role,role)
	return source+"_v2" if source in REDRAWN else source

static func mechanic_texture(role: String) -> Texture2D:
	var source := mechanic_source(role)
	var key := "mechanic:"+source
	if cells.has(key): return cells[key]
	var path := (BASE if source.begins_with("weapon_") else MECHANICS_BASE)+source+".png"
	if source.begins_with("authored_") or source.begins_with("audit_") or source.begins_with("charged_"):
		load_mechanic_manifest()
		path=MECHANICS_BASE+str(mechanics.get(source,{}).get("file",""))
	if not ResourceLoader.exists(path): return null
	cells[key]=load(path)
	return cells[key]

static func load_mechanic_manifest() -> void:
	if not mechanics.is_empty(): return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(MECHANICS_BASE+"manifest.json"))
	if parsed is Dictionary: mechanics=parsed.get("assets",{})

## Payload selection changes the painting, never the spell's collision rules.
static func payload_source(index: int, payload: String, fallback: String) -> String:
	load_mechanic_manifest()
	var revised := "audit_%d_%s_v2" % [canonical(index),payload]
	if mechanics.has(revised): return revised
	var key := "authored_%d_%s" % [canonical(index),payload]
	return key if mechanics.has(key) else mechanic_source(fallback)

## Charged originals are selected only by a host-tagged charged attack.
## A flight sprite must never become a held glow or a ground explosion.
static func charged_source(index: int, payload: String, fallback: String) -> String:
	load_mechanic_manifest()
	var key := "charged_%d_v1" % canonical(index)
	if mechanics.get(key,{}).get("payload","")==payload: return key
	return fallback

static func clean_charged(index: int) -> bool:
	load_mechanic_manifest()
	return str(mechanics.get("charged_%d_v1" % canonical(index),{}).get("style","")).begins_with("clean")

static func mechanic_ink(role: String) -> Rect2:
	if role.begins_with("weapon_"):
		if weapon_manifest.is_empty():
			var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json"))
			if parsed is Dictionary: weapon_manifest=parsed.get("assets",{})
		var entry: Dictionary=weapon_manifest.get(role,{})
		var frames: Array=entry.get("frames",[])
		var ink: Array=frames[0].get("ink",[0,0,1254,1254]) if not frames.is_empty() else [0,0,1254,1254]
		return Rect2(ink[0],ink[1],ink[2]-ink[0],ink[3]-ink[1])
	if mechanics.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(MECHANICS_BASE+"manifest.json"))
		if parsed is Dictionary: mechanics=parsed.get("assets",{})
	var entry: Dictionary=mechanics.get(mechanic_source(role),{})
	var ink: Array=entry.get("ink",[0,0,1254,1254])
	return Rect2(ink[0],ink[1],ink[2]-ink[0],ink[3]-ink[1])

static func stamp_mechanic(target: CanvasItem, role: String, bounds: Vector2, tint: Color) -> void:
	var art := mechanic_texture(role)
	if art==null: return
	var ink := mechanic_ink(role)
	var scale := minf(bounds.x/ink.size.x,bounds.y/ink.size.y)
	# Thickness comes from the original ImageGen body; fit without warping its aspect.
	target.draw_texture_rect(art,Rect2(-ink.get_center()*scale,art.get_size()*scale),false,tint)

## Contact in the same fitted coordinates as stamp_mechanic, cached per source.
## Crescents meet the blade at their luminous forward edge; thrusts start there.
static func mechanic_contact(role: String, bounds: Vector2, painted_source: String = "") -> Vector2:
	var source := mechanic_source(role if painted_source.is_empty() else painted_source)
	var ink := mechanic_ink(source)
	var contact_key := source+":"+role
	if not mechanic_contacts.has(contact_key):
		var point := ink.get_center()
		var authored_contact: Array=mechanics.get(source,{}).get("contact",[])
		if source.begins_with("weapon_"):
			var frames: Array=weapon_manifest.get(source,{}).get("frames",[])
			if not frames.is_empty(): authored_contact=frames[0].get("contact",[])
		if authored_contact.size()==2:
			point=Vector2(authored_contact[0],authored_contact[1])
		elif role=="motion_thrust":
			point.x=ink.position.x+ink.size.x*.12
		elif role.begins_with("motion_") and not preload("res://scripts/weapon_mechanics.gd").body_centered(role):
			var image := mechanic_texture(source).get_image()
			var best := -1.0
			for x in range(int(ink.position.x+ink.size.x*.60),int(ink.end.x),2):
				var strength := 0.0
				var weighted_y := 0.0
				for y in range(int(ink.position.y+ink.size.y*.45),int(ink.position.y+ink.size.y*.55),2):
					var c := image.get_pixel(x,y)
					var weight := c.a*minf(c.r,minf(c.g,c.b))
					strength+=weight
					weighted_y+=y*weight
				if strength>best and strength>0:
					best=strength
					point=Vector2(x,weighted_y/strength)
		mechanic_contacts[contact_key]=point-ink.get_center()
	return mechanic_contacts[contact_key]*minf(bounds.x/ink.size.x,bounds.y/ink.size.y)

## The semantic role still controls hit geometry; the source owns weapon identity.
## A different weapon art (e.g. quake instead of cleave) must keep its own role.
static func release_source(index: int, role: String, stage: int, weapon_art: bool = false) -> String:
	if canonical(index) in [615,619] and role=="motion_hammer_spin":
		var hammer_source := "identity_%d_drop_v2" % canonical(index)
		if ResourceLoader.exists(MECHANICS_BASE+hammer_source+".png"): return hammer_source
	if weapon_art:
		var source := payload_source(index,"art",role)
		if source.begins_with("authored_"): return source
	var normal := preload("res://scripts/weapon_mechanics.gd").normal_role(index)
	if role==normal and canonical(index) in [610,612,618,623]:
		var revised := "identity_%d_cut_v2" % canonical(index)
		if ResourceLoader.exists(MECHANICS_BASE+revised+".png"): return revised
	# A named circular weapon art may differ from its normal linear cut.
	if preload("res://scripts/weapon_mechanics.gd").body_centered(role):
		var special := "identity_%d_%s" % [15 if index==15 else canonical(index),"quake" if role=="motion_quake" else "spin"]
		if ResourceLoader.exists(MECHANICS_BASE+special+".png"): return special
	if role!=normal: return mechanic_source(role)
	if canonical(index)==600:
		if ResourceLoader.exists(MECHANICS_BASE+"identity_600_compact_v2.png"): return "identity_600_compact_v2"
		var sword_source: String=["identity_600_slash","identity_600_return","identity_600_finisher"][clampi(stage,0,2)]
		if ResourceLoader.exists(MECHANICS_BASE+sword_source+".png"): return sword_source
	var authored: String={600:"identity_600_slash",601:"identity_601_thrust",603:"identity_603_double_slash",604:"identity_604_slash",605:"identity_605_slash",606:"identity_606_slash",607:"identity_607_slash",608:"identity_608_slash",609:"identity_609_slash",610:"identity_610_slash",611:"identity_611_slash",621:"identity_621_sweep"}.get(canonical(index),"")
	if not authored.is_empty() and ResourceLoader.exists(MECHANICS_BASE+authored+".png"): return authored
	if preload("res://scripts/weapon_mechanics.gd").body_centered(role):
		var key := "identity_%d_%s" % [15 if index==15 else canonical(index),"quake" if role=="motion_quake" else "spin"]
		return key if ResourceLoader.exists(MECHANICS_BASE+key+".png") else mechanic_source(role)
	var key := "weapon_%d_%s" % [canonical(index),["release","return","finisher"][clampi(stage,0,2)]]
	if not ResourceLoader.exists(BASE+key+".png"): key="weapon_%d_release" % canonical(index)
	return key if ResourceLoader.exists(BASE+key+".png") else mechanic_source(role)


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
