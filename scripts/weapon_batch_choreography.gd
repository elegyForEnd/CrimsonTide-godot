extends RefCounted
## Per-weapon cast rhythms; authoritative distances are shared with the VFX.
## duration, damage share, range, forward travel, jump height, aim turn, source
static var additional: Dictionary=_additional()

static func _additional() -> Dictionary:
	var path := "res://resources/weapon_choreography_v2.json"
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}

static func of(weapon: int) -> Dictionary:
	return additional.get(str(weapon),{})

static func enabled(weapon: int) -> bool: return additional.has(str(weapon))

static func phase_reach(step: Array,_index: int) -> float:
	return float(step[2])

static func describe(weapon: int,base: Dictionary) -> Dictionary:
	if not enabled(weapon): return base
	var result := base.duplicate(true)
	var spec := of(weapon)
	result.name=spec.name; result.desc=spec.desc
	result.reach=0.0
	for step in spec.steps: result.reach=maxf(result.reach,float(step[2]))
	result["choreography"]=true
	return result

static func duration(weapon: int) -> float:
	var result := .22
	for step in of(weapon).steps: result+=float(step[0])
	return result
