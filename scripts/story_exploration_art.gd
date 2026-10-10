extends RefCounted
## A single authored footprint/height source for rendering, movement and navigation.
const PATH := "res://resources/story-exploration.json"
static var data: Dictionary={}
static func settings(region) -> Dictionary:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data["dungeons" if region.indoor else "outdoor"].get("%d:%d" % [region.act,region.stage],{})
static func polygon(raw: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in raw: result.append(Vector2(p[0],p[1]))
	return result
static func contains(p: Vector2, outline: PackedVector2Array) -> bool:
	# Half-open ray crossings avoid unstable vertex hits on long concave voids.
	# Scalar arithmetic remains double precision even though Vector2 is float32.
	var inside := false
	for i in outline.size():
		var a: Vector2=outline[i]; var b: Vector2=outline[(i+1)%outline.size()]
		if (a.y>p.y)==(b.y>p.y): continue
		var cross_x: float=float(a.x)+(float(p.y)-float(a.y))*(float(b.x)-float(a.x))/(float(b.y)-float(a.y))
		if float(p.x)<cross_x: inside=not inside
	return inside
static func configure(region) -> void:
	var s := settings(region)
	if s.is_empty(): return
	region.floor_polygon=polygon(s.boundary)
	if not region.indoor:
		# Old isolated terraces become broad earthen shoulders with a walkable slope.
		for stair in region.stairs:
			region.landforms.append({"core":stair.terrace.grow(-160),"height":stair.top,"shoulder":700.0})
		region.landforms.append({"core":Rect2(650+(region.stage%3)*90,2050,520,650),"height":65.0+(region.act%3)*18,"shoulder":750.0,"clear_paths":true})
		region.landforms.append({"core":Rect2(3540,3200+(region.stage%2)*140,500,740),"height":-38.0 if region.act in [1,5] else 55.0,"shoulder":680.0,"clear_paths":true})
		region.stairs.clear()
		var retained: Array=[]; region.obstacles.clear()
		for item in region.props:
			if not region.floor_contains(item.p,80): continue
			retained.append(item)
			if item.blocking: region.obstacles.append(Rect2(item.p-Vector2(item.size.x,item.size.z)*.32,Vector2(item.size.x,item.size.z)*.64))
		region.props=retained
		return
	region.exploration_plan=s
	region.extent=Vector2(s.extent[0],s.extent[1])
	region.spawn=Vector2(s.spawn[0],s.spawn[1]); region.waypoint=Vector2(s.waypoint[0],s.waypoint[1])
	region.rooms.clear(); region.props.clear(); region.obstacles.clear(); region.structural_obstacles.clear()
	region.stairs.clear(); region.water.clear(); region.shorelines.clear(); region.terrain_samples.clear()
	region.floor_voids.clear()
	for raw in s.voids: region.floor_voids.append(polygon(raw))
	region.anchors.clear(); region.side_anchors.clear(); region.chests.clear(); region.trails.clear()
	for p in s.anchors: region.anchors.append(Vector2(p[0],p[1]))
	for p in s.side_anchors: region.side_anchors.append(Vector2(p[0],p[1]))
	for p in s.chests: region.chests.append(Vector2(p[0],p[1]))
	for line in s.trails: region.trails.append(polygon(line))
	for x in [-140,140]: region.structural_obstacles.append(Rect2(region.spawn+Vector2(x-23,-113),Vector2(46,46)))
	# Arch jambs share their real movement footprints, while their open span stays free.
	for item in s.dressing:
		if not str(item.model).ends_with("_portal"): continue
		var p := Vector2(item.at[0],item.at[1]); var scale: float=item.scale[0]
		var across := Vector2.RIGHT.rotated(-float(item.get("angle",0)))
		for sign_value in [-1,1]:
			var at: Vector2=p+across*sign_value*200*scale
			region.structural_obstacles.append(Rect2(at-Vector2.ONE*32*scale,Vector2.ONE*64*scale))
static func entries(region) -> Array:
	var result: Array=[]
	for raw in region.exploration_plan.dressing:
		var item: Dictionary=raw.duplicate(true)
		item.position=Vector2(item.at[0],item.at[1])
		var size: Array=item.get("footprint",[0,0])
		item.rect=Rect2(item.position-Vector2(size[0],size[1])*.5,Vector2(size[0],size[1]))
		result.append(item)
	return result
static func height(region, p: Vector2) -> float:
	var s: Dictionary=region.exploration_plan
	var level := 0.0
	var coordinate: float=p.x if s.get("grade_axis","y")=="x" else p.y
	for band in s.grade_bands:
		if coordinate<band.start: break
		if coordinate>=band.end: level=band.to; continue
		var t: float=(coordinate-float(band.start))/float(band.end-band.start)
		if band.kind=="stairs": t=floorf((coordinate-float(band.start))/50.0)*50.0/float(band.end-band.start)
		else: t=smoothstep(0,1,t)
		level=lerpf(band.from,band.to,t); break
	if s.natural:
		# Paths are worn into the same geology; no separate floating rock platform.
		level+=region.noise.get_noise_2d(p.x,p.y)*17*smoothstep(60,250,region.path_distance(p))
	return level
static func floor_pieces(region, input: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array]=Geometry2D.intersect_polygons(input,region.floor_polygon)
	for hole in region.floor_voids:
		var next: Array[PackedVector2Array]=[]
		for piece in pieces:
			for cut in Geometry2D.clip_polygons(piece,hole):
				if not Geometry2D.is_polygon_clockwise(cut): next.append(cut)
		pieces=next
	return pieces
