extends RefCounted
## Combat identities and timings belong to RPG mode only; never leak to raids.
static var cache: Dictionary={}
static func data() -> Dictionary:
	if cache.is_empty(): cache=JSON.parse_string(FileAccess.get_file_as_string("res://resources/scarlet/enemies.json"))
	return cache
static func profile(key: String) -> Dictionary:
	return data().minions.get(key,data().bosses.get(key,{}))
static func composition(act: int,qid: String,count: int,escort: bool=false) -> Array:
	var pool: Array=data().rosters[str(clampi(act,1,6))]
	if qid.begins_with("R-P"): pool=["tide_hound","crystal_husk"]
	elif qid=="R-1-03": pool=["royal_pikeman","royal_arbalist"]
	if escort and act==5: pool=["anchor_raider","royal_arbalist"]
	var result: Array=[]
	for i in count: result.append(pool[i%pool.size()])
	return result
static func moves(key: String,phase: int) -> Array:
	var info:=profile(key)
	if info.has("skills"): return info.skills
	if info.has("phases"): return info.phases[clampi(phase,0,info.phases.size()-1)]
	return []
static func atlas_path(key: String) -> String: return data().art_root+key+".png"
