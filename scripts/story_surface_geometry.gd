extends RefCounted
## Shared walkable land/water cuts; exterior composition is authored separately.
static func rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
static func outline(r) -> PackedVector2Array:
	return r.floor_polygon if not r.floor_polygon.is_empty() else rectangle(Rect2(Vector2.ZERO,r.extent))
static func waters(r) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=r.shorelines.duplicate()
	for rect in r.water: result.append(rectangle(rect))
	return result
static func subtract(pieces: Array[PackedVector2Array], hole: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for piece in pieces:
		for cut in Geometry2D.clip_polygons(piece,hole):
			if not Geometry2D.is_polygon_clockwise(cut): result.append(cut)
	return result
static func land_pieces(r, cell: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array]=[]
	if r.floor_polygon.is_empty(): pieces.append(cell)
	else: pieces=Geometry2D.intersect_polygons(cell,outline(r))
	for water in waters(r): pieces=subtract(pieces,water)
	return pieces
static func connector_pieces(map, cell: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array]=[cell]
	for stage in map.outdoor:
		var r=map.regions[stage]
		var polygon := outline(r).duplicate() # Packed arrays share storage on assignment.
		for i in polygon.size(): polygon[i]+=r.origin
		pieces=subtract(pieces,polygon)
	return pieces
static func nearest(r, p: Vector2) -> Vector2:
	var boundary := outline(r); var result := boundary[0]; var distance := INF
	for i in boundary.size():
		var candidate := Geometry2D.get_closest_point_to_segment(p,boundary[i],boundary[(i+1)%boundary.size()])
		var d := candidate.distance_squared_to(p)
		if d<distance: result=candidate; distance=d
	return result
static func edge_stops(a: Vector2, b: Vector2, step: int, map, origin: Vector2) -> Array[float]:
	var stops: Array[float]=[0,1]
	for axis in 2:
		if is_equal_approx(a[axis],b[axis]): continue
		for value in range(int(ceil(minf(a[axis],b[axis])/step))*step,int(maxf(a[axis],b[axis])),step):
			var t: float=(value-a[axis])/(b[axis]-a[axis])
			if t>0 and t<1: stops.append(t)
		for c in map.connectors:
			for value in [c.rect.position[axis]-origin[axis],c.rect.end[axis]-origin[axis]]:
				var t: float=(value-a[axis])/(b[axis]-a[axis])
				if t>0 and t<1: stops.append(t)
	stops.sort(); return stops
static func shifted(polygon: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var result := polygon.duplicate()
	for i in result.size(): result[i]+=origin
	return result
static func append(st: SurfaceTool, polygon: PackedVector2Array, height: Callable, origin: Vector2 = Vector2.ZERO, road: bool = false) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0,indices.size(),3):
		var a: Vector2=polygon[indices[i]]; var b: Vector2=polygon[indices[i+1]]; var c: Vector2=polygon[indices[i+2]]
		for p in [a,c,b] if (b-a).cross(c-a)<0 else [a,b,c]:
			var at: Vector2=p+origin
			st.set_color(Color(1,1,1,.9 if road else 0)); st.set_uv(at/100)
			st.add_vertex(Vector3(at.x,float(height.call(p)),at.y)*.01)
