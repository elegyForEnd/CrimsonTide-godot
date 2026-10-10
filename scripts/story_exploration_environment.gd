extends RefCounted
## Organic boundaries, connected changes of level, and dressed chamber thresholds.
const Art=preload("res://scripts/story_exploration_art.gd")
const Floors=preload("res://scripts/story_floor_palette.gd")
static func terrain(builder, r, material: Material) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plan: Dictionary=r.exploration_plan
	var count := 0
	for y in range(0,int(r.extent.y),50):
		for x in range(0,int(r.extent.x),50):
			var quad := PackedVector2Array([Vector2(x,y),Vector2(x+50,y),Vector2(x+50,y+50),Vector2(x,y+50)])
			var centre := Vector2(x+25,y+25)
			var stair_cell := false
			for band in plan.grade_bands:
				if band.kind=="stairs" and centre.y>=band.start and centre.y<band.end: stair_cell=true; break
			var accent := 0.0
			for room in plan.chambers:
				if int(room.index) not in [4,7,12]: continue
				var p := Vector2(room.center[0],room.center[1])
				if centre.distance_to(p)<450: accent=1.0
			for poly in Art.floor_pieces(r,quad):
				var indices := Geometry2D.triangulate_polygon(poly)
				for i in range(0,indices.size(),3):
					var a: Vector2=poly[indices[i]]; var b: Vector2=poly[indices[i+1]]; var c: Vector2=poly[indices[i+2]]
					var ordered: Array=[a,c,b] if (b-a).cross(c-a)<0 else [a,b,c]
					for p in ordered:
						var h: float=r.base_height_at(Vector2(p.x,centre.y) if stair_cell else p)
						st.set_color(Color(accent,1,1,1)); st.set_uv(p/100)
						st.add_vertex(builder.world.point(r.origin+p,h)); count+=1
	# Risers close the tread seams. Heights are from the same 50cm stair profile.
	for item in plan.steps:
		var y: float=item.y; var a := Vector2(item.x0,y); var b := Vector2(item.x1,y)
		append_riser(st,builder,r,a,b)
	for band in plan.grade_bands:
		if band.kind!="stairs": continue
		var y: float=band.end
		var strip := PackedVector2Array([Vector2(0,y),Vector2(r.extent.x,y),Vector2(r.extent.x,y+1),Vector2(0,y+1)])
		for piece in Art.floor_pieces(r,strip):
			var left := INF; var right := -INF
			for p in piece: left=minf(left,p.x); right=maxf(right,p.x)
			append_riser(st,builder,r,Vector2(left,y),Vector2(right,y))
	if count>0:
		st.generate_normals(); var mesh: MeshInstance3D=builder.world.mesh_node(st.commit(),Vector3.ZERO,material)
		mesh.name="AuthoredDungeonFloor"; mesh.set_meta("exploration_revision",1)
static func append_riser(st: SurfaceTool, builder, r, a: Vector2, b: Vector2) -> void:
	var before: float=r.base_height_at(a+Vector2(0,-1)); var after: float=r.base_height_at(a+Vector2(0,1))
	if is_equal_approx(before,after): return
	for v in [Vector3(a.x,before,a.y),Vector3(b.x,after,b.y),Vector3(b.x,before,b.y),Vector3(a.x,before,a.y),Vector3(a.x,after,a.y),Vector3(b.x,after,b.y)]:
		st.set_color(Color(0,1,1,1)); st.set_uv(Vector2(v.x,v.y)/100); st.add_vertex(builder.world.point(r.origin+Vector2(v.x,v.z),v.y))
static func walls(builder, r) -> void:
	var group := Node3D.new(); group.name="CaveRockShell" if r.exploration_plan.natural else "CastleArchitecture" if r.layout=="castle" else "RegionalArchitecture"
	builder.world.scenery.add_child(group)
	var outlines: Array[PackedVector2Array]=[r.floor_polygon]; outlines.append_array(r.floor_voids)
	for boundary in outlines:
		for i in boundary.size():
			var a: Vector2=boundary[i]; var b: Vector2=boundary[(i+1)%boundary.size()]
			var normal_a := outward(r,boundary,i); var normal_b := outward(r,boundary,(i+1)%boundary.size())
			if maxf(a.y,b.y)<5: continue
			var distance := a.distance_to(b); var pieces := maxi(1,int(ceil(distance/220.0 if r.exploration_plan.natural else distance/300.0)))
			for j in pieces:
				var start := a.lerp(b,float(j)/pieces); var end := a.lerp(b,float(j+1)/pieces)
				var middle := (start+end)*.5; var at: Vector2=r.origin+middle
				var height: float=r.height_at(middle)
				var node: Node3D
				if r.exploration_plan.natural:
					var direction := (end-start).normalized(); var n := direction.orthogonal()
					if r.floor_contains(middle+n*8): n=-n
					var h0: float=r.height_at(start); var h1: float=r.height_at(end)
					var top0: float=275+35*sin(start.x*.007+start.y*.011)
					var top1: float=275+35*sin(end.x*.007+end.y*.011)
					var start_n: Vector2=normal_a if j==0 else n
					var end_n: Vector2=normal_b if j==pieces-1 else n
					var points: Array[Vector3]=[builder.world.point(r.origin+start,h0-35),builder.world.point(r.origin+end,h1-35),builder.world.point(r.origin+end+end_n*22,h1+top1),builder.world.point(r.origin+start+start_n*22,h0+top0),builder.world.point(r.origin+end+end_n*130,h1+top1+30),builder.world.point(r.origin+start+start_n*130,h0+top0+30)]
					var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
					for triangle in [[0,1,2],[0,2,3],[3,2,4],[3,4,5]]:
						var normal: Vector3=(points[triangle[1]]-points[triangle[0]]).cross(points[triangle[2]]-points[triangle[0]]).normalized().abs()
						for k in triangle:
							var uv: Vector2=Vector2(points[k].x,points[k].z) if normal.y>maxf(normal.x,normal.z) else Vector2(points[k].z,points[k].y) if normal.x>normal.z else Vector2(points[k].x,points[k].y)
							st.set_uv(uv*.6); st.add_vertex(points[k])
					st.generate_normals(); var mesh := MeshInstance3D.new(); mesh.mesh=st.commit(); group.add_child(mesh)
					var rock: StandardMaterial3D=builder.kit.pbr("rock" if r.act==1 else "a3_wall").duplicate(); rock.cull_mode=BaseMaterial3D.CULL_DISABLED
					mesh.material_override=rock; node=mesh
					if (i+j)%4==0:
						var model := "strata_outcrop" if r.act==1 else "a3_rock"
						var outcrop: Node3D=builder.kit.instance(model,group,builder.world.point(at+n*45,height-15),Vector3(.48,1.15,.48),-(end-start).angle())
						builder.kit.prepare_reveal(outcrop); outcrop.set_meta("occluder",{"p":at,"height":290.0})
						builder.occluders.append({"node":outcrop,"p":at,"height":290.0})
				else:
					var model := "castle_wall" if r.act==1 else "a%d_wall" % r.act
					node=builder.kit.instance(model,group,builder.world.point(at,height),Vector3(start.distance_to(end)/(300.0 if r.act==1 else 310.0),.90,1),-(end-start).angle())
					builder.kit.instance("d%d_retainer" % r.act,group,builder.world.point(at,height),Vector3(start.distance_to(end)/300,1,1),-(end-start).angle())
				builder.kit.prepare_reveal(node); node.set_meta("occluder",{"p":at,"height":290.0})
				builder.occluders.append({"node":node,"p":at,"height":290.0})
	# Placed lamps illuminate room use and thresholds rather than washing the whole map.
	for room in r.exploration_plan.chambers:
		var p := Vector2(room.center[0],room.center[1])+Vector2(-220,-330)
		var light := OmniLight3D.new(); group.add_child(light); light.position=builder.world.point(r.origin+p,r.height_at(p)+170)
		light.light_color=Color("ffc393") if r.act not in [3,6] else Color("b6d7eb") if r.act==3 else Color("d9adb1")
		light.light_energy=1.05; light.omni_range=6.3; light.shadow_enabled=false; light.light_bake_mode=Light3D.BAKE_DYNAMIC
		builder.lights.append(light)
	for item in r.dressing:
		if not str(item.id).ends_with("_chamber_feature"): continue
		var light := OmniLight3D.new(); group.add_child(light)
		light.position=builder.world.point(r.origin+item.position+Vector2(0,-180),r.height_at(item.position)+145)
		light.light_color=Color("ff9551") if r.act==2 else Color("94cdd7") if r.act in [3,5] else Color("e1b5ca")
		light.light_energy=1.9 if r.act==2 else 1.1; light.omni_range=4.8; light.shadow_enabled=false; light.light_bake_mode=Light3D.BAKE_DISABLED
		light.name="FacilityWorkLight"; builder.lights.append(light)
	void_structures(builder,r)
static func outward(r, boundary: PackedVector2Array, i: int) -> Vector2:
	var p: Vector2=boundary[i]; var before: Vector2=boundary[(i+boundary.size()-1)%boundary.size()]; var after: Vector2=boundary[(i+1)%boundary.size()]
	var first := (p-before).normalized().orthogonal(); var second := (after-p).normalized().orthogonal()
	if r.floor_contains((p+before)*.5+first*8): first=-first
	if r.floor_contains((p+after)*.5+second*8): second=-second
	var average := (first+second).normalized()
	return average/maxf(.55,average.dot(first))
static func void_structures(builder, r) -> void:
	var group := Node3D.new(); group.name="CentralStructures"; builder.world.scenery.add_child(group)
	for outline in r.floor_voids:
		var indices := Geometry2D.triangulate_polygon(outline)
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0,indices.size(),3):
			var a: Vector2=outline[indices[i]]; var b: Vector2=outline[indices[i+1]]; var c: Vector2=outline[indices[i+2]]
			var ordered: Array=[a,c,b] if (b-a).cross(c-a)<0 else [a,b,c]
			for p in ordered:
				var h: float=r.height_at(p)+(215+35*sin(p.x*.008+p.y*.007) if r.exploration_plan.natural else -95)
				st.set_uv(p/120); st.add_vertex(builder.world.point(r.origin+p,h))
		st.generate_normals()
		var mat: StandardMaterial3D=builder.kit.pbr("rock" if r.act==1 and r.exploration_plan.natural else "masonry" if r.act==1 else "a%d_wall" % r.act,Color("787d7d") if r.exploration_plan.natural else Color("778284")).duplicate()
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		var mesh := MeshInstance3D.new(); mesh.mesh=st.commit(); mesh.material_override=mat; group.add_child(mesh)
		mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED; mesh.set_meta("blocked_core",true)
static func outdoor_edge(builder, r) -> void:
	var group := Node3D.new(); group.name="ErodedRegionEdge"; builder.world.scenery.add_child(group)
	var stone: StandardMaterial3D=builder.kit.pbr("rock" if r.act==1 else "a%d_ground" % r.act)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var boundary: PackedVector2Array=r.floor_polygon
	for i in boundary.size():
		var a: Vector2=boundary[i]; var b: Vector2=boundary[(i+1)%boundary.size()]
		var middle := (a+b)*.5
		if r.path_distance(middle)<260 or r.submerged(middle): continue
		# Curved bank skirt hides the grid edge. Height varies with the actual shoulder.
		var n := (b-a).normalized().orthogonal()
		if r.floor_contains(middle+n*10): n=-n
		var h0: float=r.height_at(a); var h1: float=r.height_at(b)
		var verts: Array[Vector3]=[builder.world.point(r.origin+a,h0-2),builder.world.point(r.origin+b,h1-2),builder.world.point(r.origin+b+n*110,h1-140),builder.world.point(r.origin+a+n*110,h0-140)]
		for k in [0,1,2,0,2,3]: st.set_uv(Vector2(verts[k].x+verts[k].z,verts[k].y)); st.add_vertex(verts[k])
		var count := maxi(1,int(a.distance_to(b)/180))
		for j in count:
			var p := a.lerp(b,(j+.5)/count)
			if r.path_distance(p)<260 or r.submerged(p): continue
			var model := "strata_outcrop" if r.act==1 else "a%d_rock" % r.act
			var node: Node3D=builder.kit.instance(model,group,builder.world.point(r.origin+p+n*140,r.height_at(p)-20),Vector3(1.2,.65+.2*sin(i*2+j),.70),-(b-a).angle()+.2*sin(i+j))
			builder.kit.prepare_reveal(node); node.set_meta("occluder",{"p":r.origin+p,"height":180.0})
			builder.occluders.append({"node":node,"p":r.origin+p,"height":180.0})
	st.generate_normals(); builder.world.mesh_node(st.commit(),Vector3.ZERO,stone)
