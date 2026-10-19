class_name MapShapes
extends RefCounted
## Baked, deterministic water silhouettes (see tools/build_water_shapes.py).
##
## P3 samples one outline per lake / one meander profile per river instead of
## rebuilding shapes procedurally. Every entry is authored data, so the same
## seed always picks the same shape and the layout hash stays stable.

const PATH := "res://resources/water_shapes.json"
const LAKE_COUNT := 50
const RIVER_COUNT := 50

static var _lakes: Array = []
static var _rivers: Array = []
static var _loaded := false

static func loaded() -> bool:
	_ensure()
	return not _lakes.is_empty() and not _rivers.is_empty()

static func lake_count() -> int:
	_ensure()
	return _lakes.size()

static func river_count() -> int:
	_ensure()
	return _rivers.size()

static func lake(rng: RandomNumberGenerator) -> Dictionary:
	_ensure()
	if _lakes.is_empty():
		return _fallback_lake()
	return _lakes[rng.randi_range(0, _lakes.size() - 1)]

static func river(rng: RandomNumberGenerator) -> Dictionary:
	_ensure()
	if _rivers.is_empty():
		return _fallback_river()
	return _rivers[rng.randi_range(0, _rivers.size() - 1)]

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		push_warning("MapShapes: missing " + PATH)
		return
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		push_warning("MapShapes: empty " + PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("MapShapes: malformed " + PATH)
		return
	var data: Dictionary = parsed
	var lake_rows: Array = data.get("lakes", [])
	for row: Variant in lake_rows:
		if not (row is Dictionary):
			continue
		var shape: Dictionary = row
		var points := PackedVector2Array()
		for pair: Variant in shape.get("points", []):
			if pair is Array and (pair as Array).size() >= 2:
				points.append(Vector2(float(pair[0]), float(pair[1])))
		if points.size() >= 8:
			_lakes.append({"family": str(shape.get("family", "lake")), "points": points})
	var river_rows: Array = data.get("rivers", [])
	for row: Variant in river_rows:
		if not (row is Dictionary):
			continue
		var shape: Dictionary = row
		var points := PackedVector2Array()
		for pair: Variant in shape.get("points", []):
			if pair is Array and (pair as Array).size() >= 2:
				points.append(Vector2(float(pair[0]), float(pair[1])))
		var widths := PackedFloat32Array()
		for value: Variant in shape.get("widths", []):
			widths.append(float(value))
		if points.size() >= 8:
			if widths.size() != points.size():
				widths.resize(points.size())
				widths.fill(1.0)
			_rivers.append({
				"family": str(shape.get("family", "river")),
				"points": points,
				"widths": widths,
			})

## Used only when the baked file is unavailable (editor import, broken build).
static func _fallback_lake() -> Dictionary:
	var points := PackedVector2Array()
	for i in 40:
		var angle := TAU * float(i) / 40.0
		points.append(Vector2(cos(angle), sin(angle)))
	return {"family": "fallback", "points": points}

static func _fallback_river() -> Dictionary:
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in 33:
		var t := float(i) / 32.0
		points.append(Vector2(-1.0 + 2.0 * t, sin(t * TAU) * 0.18))
		widths.append(1.0)
	return {"family": "fallback", "points": points, "widths": widths}
