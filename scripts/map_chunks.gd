class_name MapChunks
extends RefCounted
## Chunk index / interest-set interface. P1 only builds the authoritative solid
## index; P2 adds incremental meshes and simulation bubbles behind the same API.

static func build_index(t: TerrainMap) -> void:
	t.build_solid_index()

static func chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TerrainMap.CHUNK)), int(floor(p.y / TerrainMap.CHUNK)))

static func rect(chunk: Vector2i) -> Rect2:
	return Rect2(Vector2(chunk) * TerrainMap.CHUNK, Vector2.ONE * TerrainMap.CHUNK)

static func interest_set(cameras: Array, radius_chunks: int) -> Array[Vector2i]:
	var seen := {}
	for camera in cameras:
		var center := chunk_of(camera)
		for y in range(-radius_chunks, radius_chunks + 1):
			for x in range(-radius_chunks, radius_chunks + 1):
				seen[center + Vector2i(x, y)] = true
	var out: Array[Vector2i] = []
	for key in seen.keys():
		out.append(key)
	return out
