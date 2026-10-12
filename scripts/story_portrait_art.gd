extends RefCounted
## Whole generated portraits only. Expression changes select a different complete image.
const HERO_KEYS := ["feiyue","xueli","yayu"]
const EXPRESSIONS := ["neutral","smile","joy","shy","worried","sad","angry","surprised"]
const EXPRESSION_NAMES := ["平静","微笑","喜悦","害羞","担忧","悲伤","生气","惊讶"]
const COSTUMES := ["regular","home","travel"]
const COSTUME_NAMES := ["常服","家居服","旅行装"]
const POSES := ["front","turn","crossed"]
const POSE_NAMES := ["正面闲立","轻侧抚领","轻侧抱臂"]
const CACHE_LIMIT := 10
static var manifest: Dictionary={}
static var textures: Dictionary={}
static var order: Array=[]

static func description(hero: int) -> Dictionary:
	if manifest.is_empty():
		var path := "res://assets/story/vn-full-v3/manifest.json"
		if FileAccess.file_exists(path):
			var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and parsed.get("complete",false):manifest=parsed
	var entry: Dictionary=manifest.get("heroes",{}).get(HERO_KEYS[clampi(hero,0,2)],{})
	return entry if entry.get("ready",false) else {}

static func clear_cache() -> void:
	manifest.clear();textures.clear();order.clear()

static func texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):return null
	if not textures.has(path):
		textures[path]=load(path);order.append(path)
		while order.size()>CACHE_LIMIT:textures.erase(order.pop_front())
	return textures[path]

static func normalized_expression(value: String) -> String:
	if value=="determined":return "neutral"
	if value=="tired":return "worried"
	return value if value in EXPRESSIONS else "neutral"

static func layers(hero: int, expression: String = "neutral", costume: String = "regular", pose: String = "front") -> Dictionary:
	hero=clampi(hero,0,2);expression=normalized_expression(expression)
	if not costume in COSTUMES:costume="regular"
	if not pose in POSES:pose="front"
	var entry := description(hero)
	var path := "res://assets/portrait-%d.png" % hero
	if not entry.is_empty():path=entry.portraits[costume][pose][expression]
	return {"body":texture(path),"face":null,"face_rect":Rect2(),"path":path,"whole_portrait":true}
