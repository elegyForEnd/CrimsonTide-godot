extends RefCounted
## Every new build ID resolves to its own painted cell, with cached textures.
## assets/rogue/build/ is a git-ignored generated folder, so a clean checkout has
## no atlas at all: the manifest is read defensively and absent art yields no icon
## instead of stopping the whole project from compiling.
const ATLAS_MANIFEST := "res://assets/rogue/build/atlas-manifest.json"
static var manifest: Dictionary={}
static var manifest_read := false
static var textures: Dictionary={}
static var icons: Dictionary={}

static func atlas_regions() -> Dictionary:
	if not manifest_read:
		manifest_read=true
		if FileAccess.file_exists(ATLAS_MANIFEST):
			var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(ATLAS_MANIFEST))
			if parsed is Dictionary: manifest=parsed
	var regions: Variant=manifest.get("regions",{})
	return regions if regions is Dictionary else {}

static func icon(id: String) -> Texture2D:
	if icons.has(id): return icons[id]
	var entry: Dictionary=atlas_regions().get(id,{})
	if entry.is_empty() or not entry.has("file"): return null
	var path: String=entry.file
	if not textures.has(path): textures[path]=load(path) if ResourceLoader.exists(path) else null
	var atlas: Texture2D=textures[path]
	if atlas==null: return null
	var result := AtlasTexture.new()
	result.atlas=atlas
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
