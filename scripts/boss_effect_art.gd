extends RefCounted
## Original, independent ImageGen sprites. Identity survives snapshot and RPC.
const BASE := "res://assets/bosses/imagegen/"
const KEYS := ["bell","thorn","queen","knight","hidden","mirror","ember","moon","earth","storm","abyss","dragon","grove","furnace","astral","wing","obsidian"]
const ROLES := ["slash","lance","burst","crest"]
const MOTIFS := {"bell":["pendulum","score","fracture","dial"],"thorn":["bramble","seed","root","hunt"],"queen":["sabres","regalia","petals","crown"],"hidden":["rift","hands","ribcage","tomb"],"mirror":["frame","thread","glass","loom"],"ember":["censer","moths","pyre","vesper"],"moon":["eye","drop","artery","eclipse"],"earth":["furrow","plate","stalactite","fault"],"storm":["feather","chain","eye","plume"],"abyss":["maw","current","tide","devour"],"dragon":["icicle","breath","wings","frost"],"grove":["roots","spore","bloom","mycelium"],"furnace":["chain","rivets","hammer","kiln"],"astral":["prism","refraction","starfall","orrery"],"wing":["gust","return","cyclone","helm"],"obsidian":["scar","echo","rain","seal"],"knight":["slash","lance","burst","crest"]}
const ROGUE := ["grove","furnace","astral","wing","obsidian"]
const READABLE := {"bell_pendulum":"bell_clapper","queen_sabres":"royal_sabre","queen_crown":"royal_crown","earth_plate":"rock_wall","hidden_tomb":"gravestone","mirror_frame":"standing_mirror","furnace_kiln":"ground_vent","obsidian_rain":"black_sword","obsidian_echo":"black_sword"}
static var cache: Dictionary={}
static var pending: Dictionary={}
static func asset_path(key: String, motif: String) -> String:
	if motif=="electric_bolt": return BASE+"readable/thunder_impact.png"
	if motif in ["thunder_impact","flame_vent"] or motif in READABLE.values(): return BASE+"readable/"+motif+".png"
	if READABLE.has(key+"_"+motif): return BASE+"readable/"+str(READABLE[key+"_"+motif])+".png"
	return BASE+key+"_"+("lightning_sweep" if key=="storm" and motif=="feather" else motif)+".png"

static func warm(key: String) -> void:
	if not MOTIFS.has(key): return
	for motif in MOTIFS[key]:
		var path := asset_path(key,str(motif))
		if cache.has(path) or pending.has(path) or not ResourceLoader.exists(path): continue
		if ResourceLoader.load_threaded_request(path,"Texture2D")==OK: pending[path]=true

static func finish_warming() -> void:
	for path in pending.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			cache[path]=ResourceLoader.load_threaded_get(path)
			pending.erase(path)
		elif status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending.erase(path)

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
	var path := asset_path(key,motif)
	if not cache.has(path):
		# If an effect is needed immediately, preserve its original timing and image.
		# Normally the map's bosses were requested well before the first encounter.
		if pending.has(path):
			cache[path]=ResourceLoader.load_threaded_get(path)
			pending.erase(path)
		else: cache[path]=load(path)
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
