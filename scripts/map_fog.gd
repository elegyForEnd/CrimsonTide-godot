class_name MapFog
extends RefCounted
## Team exploration bitmap. One bit per 16x16 world pixels. The reveal radius is
## fixed in world units and never reads the viewport or a pre-rendered bubble.

const CELL := 16.0
const REVEAL_RADIUS := 900.0

var cols: int = 0
var rows: int = 0
var bits := PackedByteArray()
var revision: int = 0

var _texture: ImageTexture
var _texture_revision: int = -1
var _texture_ms: int = 0

func configure(extent: Vector2) -> void:
	cols = int(ceil(extent.x / CELL))
	rows = int(ceil(extent.y / CELL))
	bits.resize(maxi(1, int(ceil(float(cols * rows) / 8.0))))
	bits.fill(0)
	revision = 0
	_texture = null
	_texture_revision = -1
	_texture_ms = 0

func clear() -> void:
	bits.fill(0)
	revision += 1
	_texture_revision = -1

func reveal(pos: Vector2, radius: float = REVEAL_RADIUS) -> void:
	if cols <= 0 or rows <= 0:
		return
	var x0 := maxi(0, int(floor((pos.x - radius) / CELL)))
	var y0 := maxi(0, int(floor((pos.y - radius) / CELL)))
	var x1 := mini(cols - 1, int(floor((pos.x + radius) / CELL)))
	var y1 := mini(rows - 1, int(floor((pos.y + radius) / CELL)))
	var changed := false
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var at := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
			if at.distance_to(pos) > radius:
				continue
			var index := y * cols + x
			var byte := index >> 3
			var mask := 1 << (index & 7)
			if (bits[byte] & mask) == 0:
				bits[byte] = bits[byte] | mask
				changed = true
	if changed:
		revision += 1

func reveal_capsule(from: Vector2, to: Vector2, radius: float = REVEAL_RADIUS) -> void:
	var distance := from.distance_to(to)
	var steps := maxi(1, int(ceil(distance / (CELL * 0.75))))
	for i in range(steps + 1):
		reveal(from.lerp(to, float(i) / float(steps)), radius)

func is_revealed(p: Vector2) -> bool:
	var x := int(floor(p.x / CELL))
	var y := int(floor(p.y / CELL))
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return false
	var index := y * cols + x
	return (bits[index >> 3] & (1 << (index & 7))) != 0

func region_coverage(t: TerrainMap, region_id: int) -> float:
	if region_id < 0 or region_id >= t.regions.size():
		return 0.0
	var region: Dictionary = t.regions[region_id]
	var polygon: PackedVector2Array = region.get("polygon", PackedVector2Array())
	var bounds := Rect2(region.center, Vector2.ZERO)
	if polygon.size() >= 3:
		bounds = Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 0.0
	var walkable := 0
	var seen := 0
	for y in 12:
		for x in 12:
			var at := bounds.position + Vector2(
				(float(x) + 0.5) / 12.0 * bounds.size.x,
				(float(y) + 0.5) / 12.0 * bounds.size.y)
			if t.region_at(at) != region_id:
				continue
			if t.blocked(at, 10.0):
				continue
			walkable += 1
			if is_revealed(at):
				seen += 1
	if walkable == 0:
		return 0.0
	return float(seen) / float(walkable)

func refresh_names(t: TerrainMap) -> void:
	for region in t.regions:
		if bool(region.get("named", false)):
			continue
		if region_coverage(t, int(region.id)) >= 0.80:
			region.named = true

func texture() -> ImageTexture:
	if _texture != null and _texture_revision == revision:
		return _texture
	var now := Time.get_ticks_msec()
	if _texture != null and now - _texture_ms < 250:
		return _texture
	_texture_ms = now
	var image := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	for y in rows:
		for x in cols:
			var index := y * cols + x
			var explored := (bits[index >> 3] & (1 << (index & 7))) != 0
			image.set_pixel(x, y, Color(0.02, 0.03, 0.05, 0.0 if explored else 0.82))
	_texture = ImageTexture.create_from_image(image)
	_texture_revision = revision
	return _texture

func serialize() -> PackedByteArray:
	return bits.duplicate()

func merge(other: PackedByteArray) -> void:
	if other.size() != bits.size():
		return
	var changed := false
	for i in bits.size():
		var next := bits[i] | other[i]
		if next != bits[i]:
			bits[i] = next
			changed = true
	if changed:
		revision += 1
		_texture_revision = -1
