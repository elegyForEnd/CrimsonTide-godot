extends RefCounted
## New ImageGen work animations, with audited frame regions and planted feet.
const ROOT := "res://assets/home/animations/"
var sheets: Dictionary = {}
var manifest: Dictionary = {}

func _init() -> void:
	if FileAccess.file_exists(ROOT+"manifest.json"):
		manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))

func frame(hero: int, action: String, progress: float, standing_height: float = 90.0) -> Dictionary:
	var key := str(hero)
	if not manifest.has(key) or not manifest[key].has(action): return {}
	if not sheets.has(hero): sheets[hero] = load(ROOT+"hero-%d-v1.png" % hero)
	var spec: Dictionary = manifest[key][action]
	var poses: Array = spec.frames
	var index := clampi(int(progress*poses.size()),0,poses.size()-1)
	var entry: Dictionary = poses[index]
	var r: Array = entry.region
	var pivot: Array = entry.pivot
	var scale: float = spec.scale*standing_height
	var size := Vector2(r[2],r[3])
	return {"texture":sheets[hero],"region":Rect2(r[0],r[1],r[2],r[3]),
		"rect":Rect2(Vector2(-pivot[0]*scale,-pivot[1]*scale)+CharacterMetrics.FOOT_OFFSET,size*scale),"index":index}
