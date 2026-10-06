extends RefCounted

const BuildArt = preload("res://scripts/rogue_build_art.gd")
## The painted flask lives in the git-ignored generated folder, so a clean
## checkout must not preload it: preloading a missing file is a parse error for
## this script and for everything that depends on it.
const FLASK_ICON := "res://assets/rogue/build/blood-flask-v1.png"
var flask_icon: Texture2D=null
var monsters: Texture2D
var items: Texture2D
var props: Texture2D
var region_backgrounds: Dictionary={}
var monster_frames: Array=[]
var item_icons: Array[Texture2D]=[]
var prop_icons: Array[Texture2D]=[]
var region_manifest: Dictionary={}
var animation_cache: Dictionary={}
var packed_sheets: Dictionary={}

func packed_sheet(texture: Texture2D, columns: int, rows: int, key: String) -> Array:
	var filename: String=texture.resource_path.get_file()
	if not packed_sheets.has(filename): return slice_sheet(texture,columns,rows,key)
	var result: Array=[]
	var manifest: Array=[]
	for frame in packed_sheets[filename].frames:
		var b: Array=frame.content
		var c: Array=frame.cell
		var bounds := Rect2i(b[0],b[1],b[2],b[3])
		var cell := Rect2i(c[0],c[1],c[2],c[3])
		var atlas := AtlasTexture.new()
		atlas.atlas=texture
		atlas.region=Rect2(bounds)
		atlas.filter_clip=true
		result.append({"texture":atlas,"bounds":bounds,"cell":cell})
		manifest.append({"x":b[0],"y":b[1],"w":b[2],"h":b[3],"cell_x":c[0],"cell_y":c[1],"cell_w":c[2],"cell_h":c[3]})
	region_manifest[key]=manifest
	return result

func animation_sheet(key: String, path: String, columns: int, rows: int) -> Array:
	if animation_cache.has(key): return animation_cache[key]
	var texture: Texture2D=load(path)
	var entries: Array=packed_sheet(texture,columns,rows,key)
	if key.begins_with("boss-hd-") and not "-skill-" in key: entries=entries.slice(0,8)
	# A common local crop preserves scale and registration between all poses.
	var common := Rect2i()
	var reference_height := 1.0
	for i in mini(4,entries.size()): reference_height=maxf(reference_height,float(entries[i].bounds.size.y))
	for entry in entries:
		var local: Rect2i=entry.bounds
		local.position-=entry.cell.position
		common=local if common.size==Vector2i.ZERO else common.merge(local)
	for entry in entries:
		entry.texture.region=Rect2(Rect2i(entry.cell.position+common.position,common.size))
		entry["reference_height"]=reference_height
		entry["scale_ratio"]=float(common.size.y)/reference_height
	animation_cache[key]=entries
	return entries

func minion_animation(floor_index: int, variant: int, frame: int) -> Dictionary:
	var hd_key := "minion-hd-%d-%d" % [floor_index,variant]
	if packed_sheets.has(hd_key+".png"):
		return animation_sheet(hd_key,"res://assets/rogue/animations/"+hd_key+".png",4,4)[clampi(frame,0,15)]
	variant=mini(variant,3)
	var key := "minion-%d-%d" % [floor_index,variant]
	return animation_sheet(key,"res://assets/rogue/animations/"+key+".png",4,3)[clampi(frame,0,11)]

## `body_index` is the guardian identity (an ``Art.ROGUE`` index) when the caller
## knows it; `fallback_index` keeps the pre-pool behaviour for callers that only
## track the floor. Generated identities 5..7 ship their own packed sheets, so a
## pooled guardian no longer borrows the floor's body.
func boss_animation(body_index: int, frame: int, fallback_index: int = -1) -> Dictionary:
	var index := body_index
	if fallback_index>=0 and not packed_sheets.has("boss-hd-%d.png" % index): index=fallback_index
	var hd_key := "boss-hd-%d" % index
	if frame<8 and packed_sheets.has(hd_key+".png"):
		return animation_sheet(hd_key,"res://assets/rogue/animations/"+hd_key+".png",4,7)[frame]
	if frame>=8:
		hd_key="boss-hd-%d-skill-%d" % [index,(frame-8)/8]
		if packed_sheets.has(hd_key+".png"):
			var pose: Dictionary=animation_sheet(hd_key,"res://assets/rogue/animations/"+hd_key+".png",4,2)[(frame-8)%8]
			# Each independently generated clip uses its neutral anticipation pose as
			# the body reference; extra spell height must not shrink the character.
			var neutral: Array=packed_sheets[hd_key+".png"].frames[0].content
			pose.scale_ratio=float(pose.texture.get_height())/float(neutral[3])
			return pose
	var key := "boss-%d" % index
	if frame<8: return animation_sheet(key,"res://assets/rogue/animations/"+key+".png",4,2)[clampi(frame,0,7)]
	key="boss-skills-%d" % index
	return animation_sheet(key,"res://assets/rogue/animations/"+key+".png",4,5)[clampi(frame-8,0,19)]

func _init() -> void:
	var packed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rogue/animations/packed-manifest.json"))
	if packed is Dictionary:
		for sheet in packed.assets: packed_sheets[sheet.file]=sheet
	if FileAccess.file_exists("res://assets/rogue/animations/hd-packed-manifest.json"):
		var hd: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rogue/animations/hd-packed-manifest.json"))
		if hd is Dictionary:
			for sheet in hd.assets: packed_sheets[sheet.file]=sheet
	monsters=load("res://assets/rogue/monsters_v3.png")
	items=load("res://assets/rogue/items_v3.png")
	props=load("res://assets/rogue/props.png")
	monster_frames=slice_sheet(monsters,4,5,"monsters")
	for entry in slice_sheet(items,4,4,"items"): item_icons.append(entry.texture)
	for entry in slice_sheet(props,4,3,"props"): prop_icons.append(entry.texture)
	# The generated flask is absent on a clean checkout; the inherited heal cell
	# (item_icons[9], the same mapping offer_icon uses) keeps it readable.
	if ResourceLoader.exists(FLASK_ICON): flask_icon=load(FLASK_ICON)
	if flask_icon==null and item_icons.size()>9: flask_icon=item_icons[9]

func slice_sheet(texture: Texture2D, columns: int, rows: int, key: String) -> Array:
	var source := texture.get_image()
	var result: Array=[]
	var manifest: Array=[]
	for y in rows:
		for x in columns:
			var left: int=int(float(x)*source.get_width()/columns)
			var top: int=int(float(y)*source.get_height()/rows)
			var right: int=int(float(x+1)*source.get_width()/columns)
			var bottom: int=int(float(y+1)*source.get_height()/rows)
			# Each cut is bounded by its cell; never sample a neighboring icon.
			var bounds := Rect2i(right,bottom,0,0)
			var min_x := right
			var min_y := bottom
			var max_x := left
			var max_y := top
			for py in range(top,bottom):
				for px in range(left,right):
					if source.get_pixel(px,py).a<0.12: continue
					min_x=mini(min_x,px); min_y=mini(min_y,py)
					max_x=maxi(max_x,px); max_y=maxi(max_y,py)
			bounds=Rect2i(min_x,min_y,maxi(1,max_x-min_x+1),maxi(1,max_y-min_y+1))
			var atlas := AtlasTexture.new()
			atlas.atlas=texture
			atlas.region=Rect2(bounds)
			atlas.filter_clip=true
			result.append({"texture":atlas,"bounds":bounds,"cell":Rect2i(left,top,right-left,bottom-top)})
			manifest.append({"x":bounds.position.x,"y":bounds.position.y,"w":bounds.size.x,"h":bounds.size.y,"cell_x":left,"cell_y":top,"cell_w":right-left,"cell_h":bottom-top})
	region_manifest[key]=manifest
	return result

func monster(skin: int, pose: int) -> Dictionary:
	return monster_frames[clampi(skin,0,4)*4+clampi(pose,0,3)]

func offer_icon(offer: Dictionary) -> Texture2D:
	if offer.has("attribute_points"): return BuildArt.icon("I016")
	if offer.has("flask_refill"): return flask_icon
	if offer.has("talent_id"): return BuildArt.icon(str(offer.talent_id))
	if offer.has("item"):
		var item: Dictionary=offer.item
		var unique: Texture2D=BuildArt.item_icon(item)
		if unique!=null: return unique
		if item.kind=="medicine": return flask_icon
		if item.kind=="gear": return item_icons[4+Catalog.gear_slot(item)]
		var family: int=Catalog.weapon_family(int(item.weapon))
		return item_icons[{0:3,1:0,2:1,3:2}.get(family,0)]
	var stat: String=offer.get("boon",{}).get("stat","")
	return item_icons[{"rogue_damage":12,"rogue_hp":7,"rogue_speed":14,"rogue_defense":13,"heal":9}.get(stat,10)]


func region_background(floor_index: int, area: int, room: String = "") -> Texture2D:
	var key := preload("res://scripts/rogue_map.gd").region_key(floor_index,area,room)
	if region_backgrounds.has(key): return region_backgrounds[key]
	var path := preload("res://scripts/rogue_map.gd").texture_path(key)
	var texture: Texture2D=load(path)
	region_backgrounds[key]=texture
	return texture
