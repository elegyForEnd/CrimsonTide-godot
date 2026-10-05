extends RefCounted
## The game adds world height separately; all poses share one grounded pivot/scale.
static var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rogue/build/jump-manifest.json"))
var frames: Dictionary={}

func poses(hero: int, standing_height: float) -> Array:
	if frames.has(hero): return frames[hero]
	var spec: Dictionary=manifest[str(hero)]
	var sheet: Texture2D=load(str(spec.file))
	var scale := standing_height/maxf(1,float(spec.standing_height))
	var result: Array=[]
	for entry in spec.frames:
		var c: Array=entry.cell
		var pivot := Vector2(entry.pivot[0],entry.pivot[1])
		var texture := AtlasTexture.new()
		texture.atlas=sheet; texture.region=Rect2(c[0],c[1],c[2],c[3]); texture.filter_clip=true
		result.append({"texture":texture,"rect":Rect2(CharacterMetrics.FOOT_OFFSET-pivot*scale,Vector2(c[2],c[3])*scale),"landmark":Vector3(c[0]+pivot.x,c[1]+pivot.y,CharacterMetrics.HEAD_PIXELS/scale),"standing_height":standing_height})
	frames[hero]=result
	return result

func frame(hero: int, standing_height: float, velocity: float, height: float, landing_time: float) -> Dictionary:
	var index := 4 if landing_time>.09 else 5 if landing_time>0 else 0 if height<18 and velocity>300 else 1 if velocity>110 else 2 if velocity>=-110 else 3
	return poses(hero,standing_height)[index]
