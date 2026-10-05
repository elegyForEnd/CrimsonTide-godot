extends RefCounted
## Original, independent ImageGen sprites. Identity survives snapshot and RPC.
const BASE := "res://assets/bosses/imagegen/"
const KEYS := ["bell","thorn","queen","knight","hidden","mirror","ember","moon","earth","storm","abyss","dragon","grove","furnace","astral","wing","obsidian"]
const ROLES := ["slash","lance","burst","crest"]
const MOTIFS := {"bell":["pendulum","score","fracture","dial"],"thorn":["bramble","seed","root","hunt"],"queen":["sabres","regalia","petals","crown"],"hidden":["rift","hands","ribcage","tomb"],"mirror":["frame","thread","glass","loom"],"ember":["censer","moths","pyre","vesper"],"moon":["eye","drop","artery","eclipse"],"earth":["furrow","plate","stalactite","fault"],"storm":["feather","chain","eye","plume"],"abyss":["maw","current","tide","devour"],"dragon":["icicle","breath","wings","frost"],"grove":["roots","spore","bloom","mycelium"],"furnace":["chain","rivets","hammer","kiln"],"astral":["prism","refraction","starfall","orrery"],"wing":["gust","return","cyclone","helm"],"obsidian":["scar","echo","rain","seal"],"knight":["slash","lance","burst","crest"]}
const ROGUE := ["grove","furnace","astral","wing","obsidian"]
static var cache: Dictionary={}

static func identity(data: Dictionary) -> String:
	if data.has("art_key"): return str(data.art_key)
	if data.get("rogue_guardian",false): return ROGUE[clampi(int(data.get("rogue_skin",data.get("floor",0))),0,4)]
	if data.get("dragon_boss",false): return "dragon"
	if data.get("wild_boss",false): return ["earth","storm","abyss"][clampi(int(data.get("wild_kind",0)),0,2)]
	if data.get("hidden_final",false): return "hidden"
	if data.get("final_form",false): return "moon"
	if int(data.get("mini_kind",-1))>=0: return ["mirror","ember"][clampi(int(data.mini_kind),0,1)]
	return KEYS[clampi(int(data.get("boss_kind",3)),0,3)]

static func texture(key: String, role: String) -> Texture2D:
	var motif: String=MOTIFS[key][ROLES.find(role)] if role in ROLES else role
	var path := BASE+key+"_"+motif+".png"
	if not cache.has(path): cache[path]=load(path)
	return cache[path]

static func color(data: Dictionary) -> Color:
	var key := identity(data)
	return Color(["c8a8ff","f987a4","ffe5ad","c4e9ff","c07ae0","a8dbff","ff8d66","ff426c","d9aa68","87dfff","b86bff","9ce9ff","6cedce","ff9b56","bfa1ff","83dcff","ff638a"][KEYS.find(key)])

## Whole image, uniform scaling, bounded opacity; no atlas regions.
static func draw(target: CanvasItem, key: String, role: String, at: Vector2, size: Vector2, angle: float, opacity: float) -> void:
	var tex := texture(key,role)
	if tex==null: return
	var fitted := tex.get_size()*minf(size.x/tex.get_width(),size.y/tex.get_height())
	target.draw_set_transform(at,angle)
	target.draw_texture_rect(tex,Rect2(-fitted*.5,fitted),false,Color(1,1,1,clampf(opacity,0,1)))
	target.draw_set_transform(Vector2.ZERO)
