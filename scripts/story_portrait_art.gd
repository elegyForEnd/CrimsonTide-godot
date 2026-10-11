extends RefCounted
## Original user designs; registered 4K bodies and API-authored facial layers.
const HERO_KEYS := ["feiyue","xueli","yayu"]
const EXPRESSIONS := ["neutral","smile","joy","shy","worried","sad","angry","determined","surprised","tired"]
const EXPRESSION_NAMES := ["平静","微笑","喜悦","害羞","担忧","悲伤","生气","坚定","惊讶","疲惫"]
const COSTUMES := ["regular","travel","rest","ceremony"]
const COSTUME_NAMES := ["常服","旅行披风","营地休息服","庆典礼装"]
static var manifest: Dictionary={}
static var textures: Dictionary={}
static var order: Array=[]
const CACHE_LIMIT := 18

static func description(hero: int) -> Dictionary:
	if manifest.is_empty() and FileAccess.file_exists("res://assets/story/portraits/manifest.json"):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/portraits/manifest.json"))
		if parsed is Dictionary: manifest=parsed
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

static func layers(hero: int, expression: String = "neutral", costume: String = "regular") -> Dictionary:
	hero=clampi(hero,0,2)
	var entry := description(hero)
	if entry.is_empty(): return {"body":texture("res://assets/portrait-%d.png" % hero),"face":null,"face_rect":Rect2()}
	if not expression in EXPRESSIONS: expression="neutral"
	if not costume in COSTUMES: costume="regular"
	var body: Texture2D=texture(entry.bodies.get(costume,entry.bodies.regular))
	var face: Texture2D=texture(entry.faces.get(expression,"")) if expression!="neutral" else null
	var rect: Array=entry.face_rect
	return {"body":body,"face":face,"face_rect":Rect2(rect[0],rect[1],rect[2],rect[3])}
