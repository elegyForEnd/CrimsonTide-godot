extends SceneTree
## One-time footprint authoring. The JSON is editable and shared by all systems.
var shapes: Array[PackedVector2Array]=[]
func ellipse(at: Vector2, radius: Vector2) -> void:
	var p := PackedVector2Array()
	for i in 32:
		var a := i*TAU/32
		var noise := 1.0+.065*sin(a*5+at.x)+.025*sin(a*9+at.y)
		p.append(at+Vector2(cos(a),sin(a))*radius*noise)
	shapes.append(p)
func passage(points: Array, width: float) -> void:
	for at in points: ellipse(at,Vector2.ONE*width)
	for i in range(points.size()-1):
		var a: Vector2=points[i]; var b: Vector2=points[i+1]
		var n := (b-a).normalized().orthogonal()*width
		shapes.append(PackedVector2Array([a+n,b+n,b-n,a-n]))
func _initialize() -> void:
	var path := "res://resources/story-cave-footprint.json"
	if FileAccess.file_exists(path) and not "--replace-generated" in OS.get_cmdline_user_args(): print("PRESERVED cave boundary"); quit(); return
	passage([Vector2(2400,0),Vector2(2400,1000),Vector2(1650,1400),Vector2(960,1530),Vector2(860,2300),Vector2(1000,3000),Vector2(890,3750)],210)
	passage([Vector2(1650,1400),Vector2(2500,1600),Vector2(2810,2550),Vector2(2660,3100),Vector2(2400,3260),Vector2(2400,4250)],235)
	passage([Vector2(1000,3000),Vector2(2400,3050),Vector2(2660,3100)],195)
	passage([Vector2(2400,4170),Vector2(3300,4210)],185)
	passage([Vector2(2810,2550),Vector2(3400,3500),Vector2(3300,4210)],185)
	ellipse(Vector2(3300,4210),Vector2(380,355))
	for chamber in [[Vector2(2400,580),Vector2(425,720)],[Vector2(960,1530),Vector2(560,410)],[Vector2(760,2300),Vector2(370,480)],[Vector2(2810,2550),Vector2(550,620)],[Vector2(890,3750),Vector2(520,470)],[Vector2(2400,4300),Vector2(650,600)]]: ellipse(chamber[0],chamber[1])
	# Keep the existing stairs/platform and lower-floor doorway fully accessible.
	shapes.append(PackedVector2Array([Vector2(2110,3480),Vector2(2840,3480),Vector2(2840,4800),Vector2(2110,4800)]))
	var union: PackedVector2Array=shapes.pop_front()
	while not shapes.is_empty():
		var changed := false
		for i in range(shapes.size()-1,-1,-1):
			if Geometry2D.intersect_polygons(union,shapes[i]).is_empty(): continue
			var merged := Geometry2D.merge_polygons(union,shapes[i])
			if not merged.is_empty():
				# Fill enclosed micro-islands; the cave has one connected floor.
				for p in merged:
					if not Geometry2D.is_polygon_clockwise(p): union=p; break
				shapes.remove_at(i); changed=true
		if not changed: push_error("Disconnected cave authoring shapes"); quit(1); return
	var clipped := Geometry2D.intersect_polygons(union,PackedVector2Array([Vector2.ZERO,Vector2(4800,0),Vector2(4800,4800),Vector2(0,4800)]))
	if clipped.size()!=1: push_error("Cave footprint must be connected without holes"); quit(1); return
	var values: Array=[]
	for p in clipped[0]: values.append([snappedf(p.x,.1),snappedf(p.y,.1)])
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"units":"100 logical units = 1 metre","boundary":values},"\t")+"\n")
	print("AUTHORED_CAVE_BOUNDARY points=",values.size()); quit()
