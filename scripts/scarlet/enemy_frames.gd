extends RefCounted
## Three authored poses, anchored individually at the ground. No baked VFX.
const Roster=preload("res://scripts/scarlet/enemy_roster.gd")
static var frames: Dictionary={}
static var metadata: Dictionary={}
static func prepare(key: String) -> Array:
	if frames.has(key): return frames[key]
	if metadata.is_empty() and FileAccess.file_exists("res://assets/story/rpg-enemies-v1/manifest.json"):
		metadata=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/rpg-enemies-v1/manifest.json")).entries
	var entry: Dictionary=metadata.get(key,{})
	var texture: Texture2D=preload("res://scripts/scarlet/art.gd").texture(entry.get("path",Roster.atlas_path(key)))
	if texture==null: return []
	var regions: Array=[]
	if not entry.is_empty():
		for frame in entry.frames:
			var r: Array=frame.region
			regions.append(Rect2(r[0],r[1],r[2],r[3]))
	else:
		var raw:=texture.get_image()
		var cell:=Vector2i(raw.get_width()/3,raw.get_height())
		for i in 3:
			var bounds:=raw.get_region(Rect2i(Vector2i(i*cell.x,0),cell)).get_used_rect()
			regions.append(Rect2(Vector2(bounds.position+Vector2i(i*cell.x,0)),Vector2(bounds.size)))
	var height: float=Roster.profile(key).get("height",150)
	var factor:=height/maxf(1,regions[0].size.y)
	var result: Array=[]
	for i in regions.size():
		var region: Rect2=regions[i]
		var frame_texture: Texture2D=texture
		if not entry.is_empty() and entry.frames[i].has("path"):
			frame_texture=preload("res://scripts/scarlet/art.gd").texture(entry.frames[i].path)
		var extent: Vector2=region.size*factor
		var at:=Vector2(-extent.x*.5,-extent.y)
		if not entry.is_empty():
			var pivot: Array=entry.frames[i].pivot
			at=(region.position-Vector2(pivot[0],pivot[1]))*factor
		var pieces: Array=[]
		if not entry.is_empty():
			for uv: Array in entry.frames[i].get("pieces",[]):
				var source:=Rect2(uv[0],uv[1],uv[2],uv[3])
				pieces.append({"region":source,"rect":Rect2(at+(source.position-region.position)*factor,source.size*factor)})
		if pieces.is_empty(): pieces=[{"region":region,"rect":Rect2(at,extent)}]
		result.append({"texture":frame_texture,"region":region,"rect":Rect2(at,extent),"factor":factor,"pieces":pieces})
	frames[key]=result
	return result
static func pose(e: Dictionary,clock: float) -> Dictionary:
	var clips:=prepare(str(e.get("key","")))
	if clips.is_empty(): return {}
	var frame:=0
	if float(e.get("release",0))>0: frame=2
	elif float(e.get("windup",0))>0: frame=1
	var result: Dictionary=clips[frame].duplicate()
	result.tint=Color("ffb7b7") if float(e.get("flash",0))>0 else Color.WHITE
	result.facing=-1.0 if Vector2(e.get("aim",Vector2.RIGHT)).x<0 else 1.0
	result.offset=Vector2(0,-sin(clock*3.2)*1.5)
	result.shadow_width=110.0 if e.key in ["beast","crystal_stalker","tide_hound"] else 80.0 if e.get("boss",false) else 55.0
	if e.get("moving",false): result.offset.y=-absf(sin(clock*9))*4
	if float(e.get("release",0))>0: result.offset.x=result.facing*sin(clampf(float(e.release)/.34,0,1)*PI)*7
	if float(e.get("stagger",0))>0: result.offset.x=sin(clock*48)*3
	if float(e.get("hp",1))<=0:
		result.tint=Color(.58,.56,.62,.45); result.offset.y=12
	return result
