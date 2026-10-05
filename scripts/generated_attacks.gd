class_name GeneratedAttacks
extends RefCounted
## Individual PNGs share a canvas and an audited support-foot pivot.
var manifest: Dictionary = {}
var cache: Dictionary = {}

func _init(manifest_path: String="res://assets/combat/generated-attacks/manifest.json") -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))

func frames(key: String) -> Array:
	if not manifest.has(key): return []
	if cache.has(key): return cache[key]
	var spec: Dictionary = manifest[key]
	var r: Array = spec.rect
	var rect := Rect2(r[0],r[1],r[2],r[3])
	var poses: Array = []
	for index in int(spec.frame_count):
		var texture: Texture2D = load("%s/%03d.png" % [spec.path,index])
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2.ZERO,texture.get_size())
		atlas.filter_clip = true
		var scale: float = rect.size.y/texture.get_height()
		poses.append({"texture":atlas,"rect":rect,"facing":spec.get("facing",1),"standing_height":spec.get("standing_height",90.0),"landmark":Vector3(spec.pivot[0],spec.pivot[1],26.0/scale)})
	cache[key] = poses
	return poses

static func timeline_frame(elapsed: float, total: float, impact: float) -> int:
	var hit := clampf(impact,0.001,maxf(0.001,total-0.001))
	if elapsed+0.00001<hit:
		return clampi(int(maxf(0,elapsed)/hit*4.0),0,3)
	return 4+clampi(int(maxf(0,elapsed-hit)/maxf(0.001,total-hit)*4.0),0,3)
