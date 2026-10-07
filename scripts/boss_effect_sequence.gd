extends RefCounted
## Raw ImageGen atlases remain untouched. Measured regions prevent neighbour bleed.
const BASE := "res://assets/bosses/imagegen/actions/"
static var manifest: Dictionary={}
static var cache: Dictionary={}
static var pending: Dictionary={}
static func specs() -> Dictionary:
	if manifest.is_empty():
		manifest=JSON.parse_string(FileAccess.get_file_as_string(BASE+"atlas.json")).assets
		if FileAccess.file_exists(BASE+"atlas-3x3-v5.json"):
			manifest.merge(JSON.parse_string(FileAccess.get_file_as_string(BASE+"atlas-3x3-v5.json")).assets,true)
		if FileAccess.file_exists(BASE+"body-atlas-3x3-v5.json"):
			manifest.merge(JSON.parse_string(FileAccess.get_file_as_string(BASE+"body-atlas-3x3-v5.json")).assets,true)
	return manifest
static func has(role: String) -> bool: return specs().has(role)
static func warm(key: String) -> void:
	for role in specs():
		var spec: Dictionary=specs()[role]
		if str(spec.get("identity",""))!=key or cache.has(role) or pending.has(role): continue
		var path: String=BASE+str(spec.file)
		if ResourceLoader.load_threaded_request(path,"Texture2D")==OK: pending[role]=path
static func finish_warming() -> void:
	for role in pending.keys():
		if ResourceLoader.load_threaded_get_status(pending[role])==ResourceLoader.THREAD_LOAD_LOADED:
			frame(role,0)
		elif ResourceLoader.load_threaded_get_status(pending[role])==ResourceLoader.THREAD_LOAD_FAILED: pending.erase(role)
static func resolve(h: Dictionary, fallback: String) -> String:
	if h.get("semantic_only",false) or h.get("preview_only",false): return fallback
	var key := str(h.get("art_key","knight"))
	var role := str(h.get("vfx_role","slash"))
	if key=="furnace" and str(h.get("delivery",""))=="vent": role="kiln"
	if key=="storm" and h.shape in ["line","lane"]: role="feather"
	# The storm/wing electrical hit sprites are vertical, flight sprites are horizontal.
	if key=="storm" and h.shape=="circle" and role=="chain": role="chain"
	var candidate := key+"_"+role+"_v3"
	if str(h.get("delivery","")) in ["whip","bite"]:
		var physical_role := "thorn_vine_lash_v3" if h.delivery=="whip" else "abyss_jaw_snap_v3"
		return physical_role if has(physical_role) else fallback
	return candidate if has(candidate) else fallback
static func frame(role: String, index: int) -> Dictionary:
	if not cache.has(role):
		var spec: Dictionary=specs()[role]
		var sheet: Texture2D=ResourceLoader.load_threaded_get(pending[role]) if pending.has(role) else load(BASE+str(spec.file))
		pending.erase(role)
		var poses: Array=[]
		for entry in spec.frames:
			var r: Array=entry.region
			var atlas := AtlasTexture.new()
			atlas.atlas=sheet
			atlas.region=Rect2(r[0],r[1],r[2],r[3])
			atlas.filter_clip=true
			poses.append({"texture":atlas,"pivot":Vector2(entry.pivot[0],entry.pivot[1])-atlas.get_size()*.5,"reach":float(spec.reach),"height":float(spec.get("height",spec.reach)),"ink_height":float(spec.get("ink_height",spec.reach)),"style":str(spec.get("style","attached"))})
		cache[role]=poses
	return cache[role][clampi(index,0,cache[role].size()-1)]

static func state(h: Dictionary, age: float, role: String="", tail: float=0.0) -> Dictionary:
	if role.ends_with("_v3"): return staged_state(h,age,tail,role)
	if not h.get("fired",h.get("active",false)):
		var remaining := float(h.get("time",h.get("delay",0)))
		var progress := clampf(1.0-remaining/.30,0,1)
		return {"name":"prepare","frame":clampi(int(progress*4),0,3),"opacity":progress*.55}
	var duration := float(h.get("strike_duration",.18))
	if age<duration:
		return {"name":"contact","frame":4+clampi(int(age/maxf(.01,duration)*2),0,1),"opacity":1.0}
	var progress := clampf((age-duration)/.16,0,1)
	return {"name":"recover","frame":6+clampi(int(progress*2),0,1),"opacity":1.0-progress}

static func staged_state(h: Dictionary, age: float, tail: float, role: String="") -> Dictionary:
	var square: bool=bool(specs().get(role,{}).get("square",false))
	var recovery := 7 if square else 6
	var loops := 3 if square else 2
	if tail>0:
		var t := clampf(tail/.30,0,1)
		if str(h.get("delivery","")) in ["blade","whip","claw","bite","thrust"]:
			return {"name":"recover","frame":4+clampi(int(t*5),0,4),"opacity":1-t}
		return {"name":"recover","frame":recovery+clampi(int(t*2),0,1),"opacity":1-t}
	if h.get("construct_only",false):
		var lived := float(h.get("construct_age",0))
		if h.get("art_key","")=="furnace" and not h.get("vent_active",false):
			return {"name":"prepare","frame":int(lived*4)%2,"opacity":.8}
		if lived<.35: return {"name":"prepare","frame":clampi(int(lived/.35*2),0,1),"opacity":smoothstep(0,.15,lived)}
		return {"name":"sustain","frame":4+int(lived*9)%loops,"opacity":1.0}
	if not h.get("fired",h.get("active",false)):
		var lead := float(h.get("warning_lead",.65))
		var t := clampf(1.0-float(h.get("time",h.get("delay",0)))/maxf(.01,lead),0,1)
		return {"name":"prepare","frame":clampi(int(t*2),0,1),"opacity":smoothstep(0,.18,t)*.65}
	var duration := float(h.get("strike_duration",.16))
	if age<duration: return {"name":"contact","frame":2+clampi(int(age/maxf(.01,duration)*2),0,1),"opacity":1.0}
	if h.shape=="capsule" or float(h.get("linger",h.get("total",.28)))>.40:
		return {"name":"sustain","frame":4+int(age*12)%loops,"opacity":1.0}
	# Contact remains visible for the full authoritative hit window; disappear only
	# after the server removes it. Sparse fragments during a live trap would lie.
	return {"name":"contact","frame":3,"opacity":1.0}
