extends RefCounted
## Blank VN bases plus transparent expression ink. Legacy v13 is a safe fallback.
const HERO_KEYS := ["feiyue","xueli","yayu"]
const EXPRESSIONS := ["neutral","smile","joy","shy","worried","sad","angry","determined","surprised","tired"]
const EXPRESSION_NAMES := ["平静","微笑","喜悦","害羞","担忧","悲伤","生气","坚定","惊讶","疲惫"]
const COSTUMES := ["regular","travel","ceremony"]
const COSTUME_NAMES := ["常服","旅行装","庆典礼装"]
const POSES := ["relaxed","crossed","clasped"]
const POSE_NAMES := ["放松站立","抱臂","胸前合手"]
static var manifest: Dictionary={}
static var textures: Dictionary={}
static var order: Array=[]
const CACHE_LIMIT := 18

static func description(hero: int) -> Dictionary:
	if manifest.is_empty():
		for path in ["res://assets/story/vn-portraits-v2/manifest.json","res://assets/story/portraits/manifest.json"]:
			if not FileAccess.file_exists(path): continue
			var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and parsed.get("heroes",{}).size()==3:
				var ready := true
				for entry in parsed.heroes.values(): ready=ready and entry.get("ready",false)
				if ready: manifest=parsed; break
	var entry: Dictionary=manifest.get("heroes",{}).get(HERO_KEYS[clampi(hero,0,2)],{})
	return entry if entry.get("ready",false) else {}

static func clear_cache() -> void:
	textures.clear(); order.clear(); manifest.clear()

static func texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path): return null
	if not textures.has(path):
		textures[path]=load(path); order.append(path)
		while order.size()>CACHE_LIMIT: textures.erase(order.pop_front())
	return textures[path]

static func layers(hero: int, expression: String = "neutral", costume: String = "regular", pose: String = "relaxed", blush_enabled: bool = true, blank: bool = false) -> Dictionary:
	hero=clampi(hero,0,2)
	var entry := description(hero)
	if entry.is_empty(): return {"body":texture("res://assets/portrait-%d.png" % hero),"face":null,"face_rect":Rect2()}
	if not expression in EXPRESSIONS: expression="neutral"
	if not costume in COSTUMES: costume="regular"
	if entry.has("bases"):
		if not pose in POSES: pose="relaxed"
		var base: Dictionary=entry.bases[costume][pose]
		var overlays: Array=[]
		if not blank:
			if blush_enabled:
				var name := "shy" if expression=="shy" else "natural"
				overlays.append({"kind":"blush","texture":texture("res://assets/story/vn-portraits-v2/blush-"+name+".png"),"rect":rect(base.rects.blush),"opacity":.5 if name=="shy" else .28})
			for kind in ["eyes","mouth"]:
				overlays.append({"kind":kind,"texture":texture(entry.features[expression][kind].path),"rect":rect(base.rects[kind]),"opacity":1.0})
		return {"body":texture(base.path),"overlays":overlays,"face":texture(entry.features[expression].eyes.path) if not blank else null,"face_rect":rect(base.rects.eyes)}
	var body: Texture2D=texture(entry.bodies.get(costume,entry.bodies.regular))
	var face: Texture2D=texture(entry.faces.get(expression,"")) if expression!="neutral" else null
	var rect: Array=entry.face_rect
	return {"body":body,"face":face,"face_rect":Rect2(rect[0],rect[1],rect[2],rect[3])}

static func rect(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])
