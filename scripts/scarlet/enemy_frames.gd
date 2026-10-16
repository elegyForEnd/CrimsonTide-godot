extends RefCounted
## Three authored poses, anchored individually at the ground. No baked VFX.
const Roster=preload("res://scripts/scarlet/enemy_roster.gd")
static var frames: Dictionary={}
static func prepare(key: String) -> Array:
	if frames.has(key): return frames[key]
	var texture: Texture2D=preload("res://scripts/scarlet/art.gd").texture(Roster.atlas_path(key))
	if texture==null: return []
	var raw:=texture.get_image()
	var cell:=Vector2i(raw.get_width()/3,raw.get_height())
	var regions: Array=[]
	for i in 3:
		var bounds:=raw.get_region(Rect2i(Vector2i(i*cell.x,0),cell)).get_used_rect()
		regions.append(Rect2(Vector2(bounds.position+Vector2i(i*cell.x,0)),Vector2(bounds.size)))
	var height: float=Roster.profile(key).get("height",150)
	var factor:=height/maxf(1,regions[0].size.y)
	var result: Array=[]
	for region: Rect2 in regions:
		var extent: Vector2=region.size*factor
		result.append({"texture":texture,"region":region,"rect":Rect2(-extent.x*.5,-extent.y,extent.x,extent.y),"factor":factor})
	frames[key]=result
	return result
static func pose(e: Dictionary,clock: float) -> Dictionary:
	var clips:=prepare(str(e.get("key","")))
	if clips.is_empty(): return {}
	var frame:=0
	if float(e.get("windup",0))>0: frame=1
	elif float(e.get("release",0))>0: frame=2
	var result: Dictionary=clips[frame].duplicate()
	result.tint=Color("ffb7b7") if float(e.get("flash",0))>0 else Color.WHITE
	result.facing=-1.0 if Vector2(e.get("aim",Vector2.RIGHT)).x<0 else 1.0
	result.offset=Vector2(0,-sin(clock*3.2)*1.5)
	if e.get("moving",false): result.offset.y=-absf(sin(clock*9))*4
	if float(e.get("release",0))>0: result.offset.x=result.facing*sin(clampf(float(e.release)/.34,0,1)*PI)*7
	if float(e.get("stagger",0))>0: result.offset.x=sin(clock*48)*3
	if float(e.get("hp",1))<=0:
		result.tint=Color(.58,.56,.62,.45); result.offset.y=12
	return result
