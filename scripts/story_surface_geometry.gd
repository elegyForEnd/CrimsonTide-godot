extends RefCounted
## Shared visible land, water, connector cuts and the nonwalkable scenery apron.
const MARGIN := 3600.0 # Covers 21m zoom, oblique projection and offset camp joins.
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
static func territory(map, r) -> Rect2:
	# Meet neighbouring scenery halfway. Never stack two coplanar aprons.
	var minimum: Vector2=r.origin-Vector2.ONE*MARGIN
	var maximum: Vector2=r.origin+r.extent+Vector2.ONE*MARGIN
	for stage in map.outdoor:
		var other=map.regions[stage]
		if other==r: continue
		var own := Rect2(r.origin,r.extent); var adjacent := Rect2(other.origin,other.extent)
		if own.position.y<adjacent.end.y and own.end.y>adjacent.position.y:
			if own.end.x<=adjacent.position.x: maximum.x=minf(maximum.x,(own.end.x+adjacent.position.x)*.5)
			elif adjacent.end.x<=own.position.x: minimum.x=maxf(minimum.x,(adjacent.end.x+own.position.x)*.5)
		if own.position.x<adjacent.end.x and own.end.x>adjacent.position.x:
			if own.end.y<=adjacent.position.y: maximum.y=minf(maximum.y,(own.end.y+adjacent.position.y)*.5)
			elif adjacent.end.y<=own.position.y: minimum.y=maxf(minimum.y,(adjacent.end.y+own.position.y)*.5)
		elif own.position.y>=adjacent.end.y or own.end.y<=adjacent.position.y:
			# L-shaped overworld turns can also bring two diagonal aprons together.
			var delta := adjacent.get_center()-own.get_center()
			if absf(delta.x)>=absf(delta.y):
				if own.end.x<=adjacent.position.x: maximum.x=minf(maximum.x,(own.end.x+adjacent.position.x)*.5)
				elif adjacent.end.x<=own.position.x: minimum.x=maxf(minimum.x,(adjacent.end.x+own.position.x)*.5)
			else:
				if own.end.y<=adjacent.position.y: maximum.y=minf(maximum.y,(own.end.y+adjacent.position.y)*.5)
				elif adjacent.end.y<=own.position.y: minimum.y=maxf(minimum.y,(adjacent.end.y+own.position.y)*.5)
	return Rect2(minimum,maximum-minimum)
static func nearest(r, p: Vector2) -> Vector2:
	var boundary := rectangle(Rect2(Vector2.ZERO,r.extent).grow(1000)) if r.stage==0 else outline(r)
	var result := boundary[0]; var distance := INF
	for i in boundary.size():
		var candidate := Geometry2D.get_closest_point_to_segment(p,boundary[i],boundary[(i+1)%boundary.size()])
		var d := candidate.distance_squared_to(p)
		if d<distance: result=candidate; distance=d
	return result
static func apron_height(map, p: Vector2) -> float:
	# A common world-space height on both sides of a scenery territory join.
	var first := INF; var second := INF; var h0 := 0.0; var h1 := 0.0
	for stage in map.outdoor:
		var r=map.regions[stage]; var local: Vector2=p-r.origin
		if stage==0:
			# Camp margin meshes are cut out of the neighbouring region rectangles.
			# Their virtual outer rim cannot take ownership of a real field vertex.
			var cut_out := false
			for other_stage in map.outdoor:
				if other_stage==0: continue
				var other=map.regions[other_stage]
				if Rect2(other.origin,other.extent).grow(.05).has_point(p): cut_out=true; break
			if cut_out: continue
		var closest := local.clamp(Vector2.ZERO,r.extent)
		if local.distance_to(closest)>second: continue
		var edge := nearest(r,local); var d := local.distance_to(edge)
		var h: float=r.base_height_at(edge)
		if d<first: second=first; h1=h0; first=d; h0=h
		elif d<second: second=d; h1=h
	var weight := 0.0 if is_inf(second) else first*first/maxf(1,first*first+second*second)
	var relief := (sin(p.x*.008)*sin(p.y*.011)*18+sin((p.x+p.y)*.019)*8)*smoothstep(0,160,first)
	return lerpf(h0,h1,weight)-140*smoothstep(0,170,first)+relief
static func apron_pieces(map, r, cell: PackedVector2Array) -> Array[PackedVector2Array]:
	# Existing camps already have a 10m nonwalkable ground margin.
	var occupied := rectangle(Rect2(r.origin,r.extent).grow(1000)) if r.stage==0 else shifted(outline(r),r.origin)
	var pieces := subtract(Geometry2D.intersect_polygons(cell,rectangle(territory(map,r))),occupied)
	for connector in map.connectors: pieces=subtract(pieces,rectangle(connector.rect))
	return pieces
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
static func apron(builder, r, ground: Material) -> void:
	var group := Node3D.new(); group.name="BoundaryApron"; group.set_meta("surface_revision",1)
	builder.world.scenery.add_child(group)
	var map=builder.world.campaign.map; var bounds := territory(map,r)
	var step := 50 if r.act==1 and r.stage==1 else 100
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights: Dictionary={}
	for y in range(int(floor(bounds.position.y/step))*step,int(ceil(bounds.end.y/step))*step,step):
		for x in range(int(floor(bounds.position.x/step))*step,int(ceil(bounds.end.x/step))*step,step):
			for piece in apron_pieces(map,r,rectangle(Rect2(x,y,step,step))):
				append(st,piece,func(p):
					if not heights.has(p): heights[p]=apron_height(map,p)
					return heights[p])
	st.generate_normals()
	var mesh := MeshInstance3D.new(); mesh.name="ContinuousBoundaryGround"; mesh.mesh=st.commit(); mesh.material_override=ground
	mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED; group.add_child(mesh)
