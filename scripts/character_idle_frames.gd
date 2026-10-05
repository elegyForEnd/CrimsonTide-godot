extends RefCounted
const Idle = preload("res://scripts/character_idle.gd")
var clips: Dictionary={}
var manifest: Dictionary={}
func poses(hero: int, standing_height: float) -> Array:
	if clips.has(hero): return clips[hero]
	if manifest.is_empty():
		var path := "res://assets/combat/idle/manifest.json"
		if not FileAccess.file_exists(path): return []
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary: return []
		manifest=parser.data
	if not manifest.has(str(hero)): return []
	var spec: Dictionary=manifest[str(hero)]
	var sheet: Texture2D=load(spec.file)
	var scale := standing_height/float(spec.standing_height)
	var rows: Array=[]
	for row: Array in spec.rows:
		var frames: Array=[]
		for entry: Dictionary in row:
			var c: Array=entry.cell
			var pivot := Vector2(entry.pivot[0],entry.pivot[1])
			var texture := AtlasTexture.new()
			texture.atlas=sheet; texture.region=Rect2(c[0],c[1],c[2],c[3]); texture.filter_clip=true
			frames.append({"texture":texture,"rect":Rect2(CharacterMetrics.FOOT_OFFSET-pivot*scale,Vector2(c[2],c[3])*scale),"standing_height":standing_height,"idle_generated":true,"exclude":entry.get("exclude",[]),"hand_side":-1.0 if hero==1 and rows.size() in [0,2] else 1.0})
		rows.append(frames)
	clips[hero]=rows
	return rows

func frame(hero: int, weapon: int, standing_height: float, seconds: float) -> Dictionary:
	var family := Catalog.weapon_family(weapon)
	var row: int={1:0,2:1,3:2,0:3}[family]
	var order := [0,1,2,3,2,1]
	var index: int=order[posmod(int(seconds*6.0/float(Idle.profile(weapon)[0])),6)]
	var rows: Array=poses(hero,standing_height)
	if row>=rows.size() or index>=rows[row].size(): return {}
	var kind := "unarmed" if weapon>=600 else "rifle" if weapon==0 else "scythe" if hero==3 and weapon==20 else ""
	if kind.is_empty(): return rows[row][index]
	var key := "%d:%s" % [hero,kind]
	if not clips.has(key):
		var spec: Dictionary=manifest[str(hero)].get(kind,{})
		if spec.is_empty(): return rows[row][index]
		var sheet: Texture2D=load(spec.file)
		var scale := standing_height/float(spec.standing_height)
		var frames: Array=[]
		for entry: Dictionary in spec.frames:
			var c: Array=entry.cell
			var pivot := Vector2(entry.pivot[0],entry.pivot[1])
			var texture := AtlasTexture.new()
			texture.atlas=sheet; texture.region=Rect2(c[0],c[1],c[2],c[3]); texture.filter_clip=true
			frames.append({"texture":texture,"rect":Rect2(CharacterMetrics.FOOT_OFFSET-pivot*scale,Vector2(c[2],c[3])*scale),"standing_height":standing_height,"idle_generated":true,"exclude":entry.get("exclude",[]),"hand_side":1.0})
			if entry.has("grip"):
				frames.back()["grip"]=CharacterMetrics.FOOT_OFFSET+(Vector2(entry.grip[0],entry.grip[1])-pivot)*scale
		clips[key]=frames
	return clips[key][index]
