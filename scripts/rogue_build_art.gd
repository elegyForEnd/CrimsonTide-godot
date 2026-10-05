extends RefCounted
## Every new build ID resolves to its own painted cell, with cached textures.
static var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rogue/build/atlas-manifest.json"))
static var textures: Dictionary={}
static var icons: Dictionary={}

static func icon(id: String) -> Texture2D:
	if icons.has(id): return icons[id]
	var entry: Dictionary=manifest.get("regions",{}).get(id,{})
	if entry.is_empty(): return null
	var path: String=entry.file
	if not textures.has(path): textures[path]=load(path)
	var result := AtlasTexture.new()
	result.atlas=textures[path]
	var r: Array=entry.region
	result.region=Rect2(r[0],r[1],r[2],r[3])
	result.filter_clip=true
	icons[id]=result
	return result

static func item_icon(item: Dictionary) -> Texture2D:
	var id := str(item.get("build_id",""))
	if id.is_empty() and item.get("kind","")=="weapon" and int(item.get("weapon",0))>=600: id="W%03d" % (int(item.weapon)-599)
	if id.is_empty() and item.get("kind","")=="gear" and item.has("rogue_id"): id="E%03d" % (int(item.rogue_id)+1)
	return icon(id)
