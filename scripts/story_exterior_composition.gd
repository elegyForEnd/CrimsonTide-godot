extends RefCounted
## Nonwalkable terrain is a dressed landscape, with a river at the south gate.
const Surface=preload("res://scripts/story_surface_geometry.gd")
const MARGIN := 2400.0
static func bounds(map, r) -> Rect2:
	var low: Vector2=r.origin-Vector2.ONE*MARGIN; var high: Vector2=r.origin+r.extent+Vector2.ONE*MARGIN
	var own := Rect2(r.origin,r.extent)
	for stage in map.outdoor:
		var other=map.regions[stage]
		if other==r: continue
		var adjacent := Rect2(other.origin,other.extent)
		var vertical_overlap := own.position.y<adjacent.end.y and own.end.y>adjacent.position.y
		var horizontal_overlap := own.position.x<adjacent.end.x and own.end.x>adjacent.position.x
		var delta := adjacent.get_center()-own.get_center()
		if vertical_overlap or (not horizontal_overlap and absf(delta.x)>=absf(delta.y)):
			if own.end.x<=adjacent.position.x: high.x=minf(high.x,(own.end.x+adjacent.position.x)*.5)
			elif adjacent.end.x<=own.position.x: low.x=maxf(low.x,(adjacent.end.x+own.position.x)*.5)
		else:
			if own.end.y<=adjacent.position.y: high.y=minf(high.y,(own.end.y+adjacent.position.y)*.5)
			elif adjacent.end.y<=own.position.y: low.y=maxf(low.y,(adjacent.end.y+own.position.y)*.5)
	return Rect2(low,high-low)
static func gate_river(map) -> Dictionary:
	if map.act!=1: return {}
	var c: Dictionary=map.connectors[0]
	return {"x":c.a.x,"y":(c.a.y+c.b.y)*.5,"range":Vector2(-2400,5900)}
static func river_middle(river: Dictionary, x: float) -> float:
	var distance: float=x-river.x
	return river.y+(sin(distance*.0014)*65+sin(distance*.0031)*27)*smoothstep(220,650,absf(distance))
static func river_width(river: Dictionary, x: float) -> float:
	return 108+22*sin((x-river.x)*.0021)
static func river_outline(map) -> PackedVector2Array:
	var river := gate_river(map); var result := PackedVector2Array()
	if river.is_empty(): return result
	for x in range(int(river.range.x),int(river.range.y)+1,100): result.append(Vector2(x,river_middle(river,x)-river_width(river,x)))
	for x in range(int(river.range.y),int(river.range.x)-1,-100): result.append(Vector2(x,river_middle(river,x)+river_width(river,x)))
	return result
static func river_distance(map, p: Vector2) -> float:
	var river := gate_river(map)
	if river.is_empty() or p.x<river.range.x or p.x>river.range.y: return INF
	return absf(p.y-river_middle(river,p.x))-river_width(river,p.x)
static func height(map, p: Vector2) -> float:
	var first := INF; var second := INF; var h0 := 0.0; var h1 := 0.0
	for stage in map.outdoor:
		var r=map.regions[stage]; var local: Vector2=p-r.origin
		if local.distance_to(local.clamp(Vector2.ZERO,r.extent))>second: continue
		var edge := Surface.nearest(r,local); var distance := local.distance_to(edge)
		var h: float=r.base_height_at(edge)
		if distance<first: second=first; h1=h0; first=distance; h0=h
		elif distance<second: second=distance; h1=h
	var blend := 0.0 if is_inf(second) else first*first/maxf(1,first*first+second*second)
	var base := lerpf(h0,h1,blend)
	var relief := (38*sin(p.x*.0035+p.y*.0018)+24*sin(p.y*.007)+18*sin(p.x*.013)*sin(p.y*.010))*smoothstep(0,200,first)
	var hill := 115*(.5+.5*sin(p.x*.0019+p.y*.0012))*smoothstep(250,900,first)
	base+=relief+hill
	var distance := river_distance(map,p)
	if distance<155:
		var riverbank := lerpf(-96,base,smoothstep(0,155,distance))
		base=lerpf(base,riverbank,smoothstep(0,60,first))
	return base
static func land_pieces(map, r, cell: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array]=Geometry2D.intersect_polygons(cell,Surface.rectangle(bounds(map,r)))
	pieces=Surface.subtract(pieces,Surface.shifted(Surface.outline(r),r.origin))
	for c in map.connectors: pieces=Surface.subtract(pieces,Surface.rectangle(c.rect))
	var river := river_outline(map)
	if not river.is_empty(): pieces=Surface.subtract(pieces,river)
	return pieces
static func mesh(group: Node3D, name: String, surface: SurfaceTool, material: Material) -> MeshInstance3D:
	surface.generate_normals()
	var node := MeshInstance3D.new(); node.name=name; node.mesh=surface.commit(); node.material_override=material
	node.gi_mode=GeometryInstance3D.GI_MODE_DISABLED; group.add_child(node); return node
static func build(builder, r) -> void:
	var map=builder.world.campaign.map; var region_bounds := bounds(map,r)
	var group := Node3D.new(); group.name="DressedExteriorLandscape"; group.set_meta("composition_revision",1); group.set_meta("nonwalkable",true)
	builder.world.scenery.add_child(group)
	var material: ShaderMaterial=builder.ground_material(map.regions[1] if r.stage==0 else r).duplicate()
	material.set_shader_parameter("paving",0.0)
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights: Dictionary={}
	for y in range(int(floor(region_bounds.position.y/100))*100,int(ceil(region_bounds.end.y/100))*100,100):
		for x in range(int(floor(region_bounds.position.x/100))*100,int(ceil(region_bounds.end.x/100))*100,100):
			for piece in land_pieces(map,r,Surface.rectangle(Rect2(x,y,100,100))):
				Surface.append(surface,piece,func(p):
					if not heights.has(p): heights[p]=height(map,p)
					return heights[p])
	mesh(group,"SculptedExteriorGround",surface,material)
	var river := river_outline(map)
	if not river.is_empty():
		var water := SurfaceTool.new(); water.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pieces: Array[PackedVector2Array]=Geometry2D.intersect_polygons(river,Surface.rectangle(region_bounds))
		for piece in pieces: Surface.append(water,piece,func(_p): return -94.0)
		if not pieces.is_empty():
			var water_mat := ShaderMaterial.new(); water_mat.shader=builder.WATER; water_mat.set_shader_parameter("water_tint",Color("143b3a"))
			mesh(group,"SouthGateRiver",water,water_mat)
	var rng := RandomNumberGenerator.new(); rng.seed=7137+r.act*197+r.stage*41
	var dressing := Node3D.new(); dressing.name="NonwalkableDressing"; group.add_child(dressing)
	var clusters := 0; var placed := 0
	for i in 110:
		var centre := Vector2(rng.randf_range(region_bounds.position.x,region_bounds.end.x),rng.randf_range(region_bounds.position.y,region_bounds.end.y))
		for j in range(2+rng.randi_range(0,3)):
			var p := centre+Vector2(rng.randf_range(-110,110),rng.randf_range(-110,110))
			if not region_bounds.has_point(p) or Surface.nearest(r,p-r.origin).distance_to(p-r.origin)<100: continue
			if r.floor_contains(p-r.origin) or (r.stage==0 and Rect2(r.origin,r.extent).has_point(p)): continue
			var wet := river_distance(map,p)
			if wet<30: continue
			var road := false
			for c in map.connectors:
				if c.rect.grow(160).has_point(p): road=true; break
			if road: continue
			var model := "strata_outcrop" if r.act==1 and j==0 else "woodland_tree" if r.act==1 and j==1 else "grass_tuft" if r.act==1 and j==2 else "woodland_fern" if r.act==1 else "a%d_rock" % r.act if j==0 else "a%d_tree" % r.act
			var scale := rng.randf_range(.35,.70) if j==0 else rng.randf_range(.55,.90) if j==1 else rng.randf_range(.70,1.10)
			var node: Node3D=builder.kit.instance(model,dressing,builder.world.point(p,height(map,p)-8),Vector3.ONE*scale,rng.randf()*TAU)
			node.set_meta("exterior_decoration",true)
			for part in builder.kit.mesh_nodes(node): part.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
			placed+=1
		clusters+=1
	if r.act==1:
		var river_data := gate_river(map)
		for x in range(-1800,5001,170):
			for sign_value in [-1,1]:
				var p := Vector2(x,river_middle(river_data,x)+sign_value*(river_width(river_data,x)+38))
				if not region_bounds.has_point(p) or r.floor_contains(p-r.origin): continue
				if absf(p.x-river_data.x)<330: continue
				var node: Node3D=builder.kit.instance("grass_tuft" if x%3 else "rock_formation",dressing,builder.world.point(p,height(map,p)-5),Vector3.ONE*(.45 if x%3 else .28),x*.07)
				for part in builder.kit.mesh_nodes(node): part.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
				node.set_meta("riverbank_decoration",true); placed+=1
	group.set_meta("decoration_count",placed); group.set_meta("cluster_count",clusters)
