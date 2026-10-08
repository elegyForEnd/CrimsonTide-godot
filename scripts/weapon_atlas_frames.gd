extends RefCounted
## Four authored keys per concrete weapon/action; same-name campaign aliases share.
const BASE := "res://assets/combat/weapon-atlases/"
const Art=preload("res://scripts/weapon_image_art.gd")
var manifest: Dictionary={}
var poses: Dictionary={}
func atlas_key(hero: int, weapon: int) -> String:
	return "%d/%d" % [hero,Art.canonical(weapon)]

func count(hero: int, weapon: int, state: String) -> int:
	var atlas: Dictionary=manifest.get(atlas_key(hero,weapon),{})
	if state=="idle" and not atlas.get("states",{}).has("idle") and atlas.get("states",{}).has("attack"): return 1
	return atlas.get("states",{}).get(state,[]).size()

func rate(hero: int, weapon: int, state: String, fallback: float) -> float:
	var atlas: Dictionary=manifest.get(atlas_key(hero,weapon),{})
	return float(atlas.get("fps",{}).get(state,fallback))

func attack_index(p: Dictionary, state: String) -> int:
	var key := atlas_key(int(p.hero),int(p.weapon))
	if not manifest.has(key): return 0
	var total := maxf(.001,float(p.get("swing_total",.23)))
	var remaining := float(p.get("swing_time",0))
	var elapsed := total-remaining
	var hit := float(p.get("build_strike_windup",Catalog.weapon(int(p.weapon)).windup))
	if p.has("build_pending_art"): hit=elapsed+float(p.build_pending_art.remaining)
	if remaining<=0 and float(p.get("cast_time",0))>0:
		total=.75
		elapsed=total-float(p.cast_time)
		hit=.55
	var clip: Dictionary=manifest[key]
	var size := count(int(p.hero),int(p.weapon),state)
	if size==0: return 0
	var contact := int(clip.get("contact_frames",{}).get(state,mini(3,size-1)))
	if elapsed+.00001<hit:
		return clampi(int(maxf(0,elapsed)/maxf(.001,hit)*contact),0,contact-1)
	var recovery := size-contact
	return clampi(contact+int((elapsed-hit)/maxf(.001,total-hit)*recovery),contact,size-1)
func _init() -> void:
	if FileAccess.file_exists(BASE+"manifest.json"):
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json"))
		if parsed is Dictionary:
			for key: String in parsed.get("atlases",{}):
				var atlas: Dictionary=parsed.atlases[key]
				if atlas.get("enabled",true): manifest[key]=atlas

func frame(hero: int, weapon: int, state: String, index: int, standing_height: float) -> Dictionary:
	var key := atlas_key(hero,weapon)
	if not manifest.has(key): return {}
	var atlas: Dictionary=manifest[key]
	var states: Dictionary=atlas.states
	# The authored preparation key is also a valid held resting pose; reuse
	# that one key instead of inventing four almost identical idle pictures.
	var clip_state := "attack" if state=="idle" and not states.has(state) else state
	if not states.has(clip_state): return {}
	var phase := 0 if state=="idle" and clip_state=="attack" else posmod(index,states[clip_state].size())
	var cache_key := "%s:%d:%s:%d:%.3f" % [key,Art.canonical(weapon),state,phase,standing_height]
	if not poses.has(cache_key):
		var entry: Dictionary=states[clip_state][phase]
		var texture := AtlasTexture.new()
		texture.atlas=load(BASE+str(entry.get("file",atlas.get("file",""))))
		texture.region=Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3])
		texture.filter_clip=true
		var pivot := Vector2(entry.pivot[0],entry.pivot[1])
		# Packing density can differ between action rows on the same page.
		# Each clip uses one scale; never resize individual limbs/keys to fit.
		var source_file := str(entry.get("file",atlas.get("file","")))
		var scale := standing_height/float(atlas.get("clip_heights",{}).get(clip_state,atlas.get("page_heights",{}).get(source_file,atlas.standing_height)))
		poses[cache_key]={"texture":texture,"rect":Rect2(CharacterMetrics.FOOT_OFFSET-pivot*scale,texture.region.size*scale),
			"socket":(Vector2(entry.socket[0],entry.socket[1])-pivot)*scale,
			"grip":(Vector2(entry.get("grip",entry.socket)[0],entry.get("grip",entry.socket)[1])-pivot)*scale,
			"weapon_atlas":true,"weapon_identity":Art.canonical(weapon),"state":state,"frame":phase,
			"standing_height":standing_height,"landmark":Vector3(pivot.x,pivot.y,CharacterMetrics.HEAD_PIXELS/scale)}
	return poses[cache_key]
