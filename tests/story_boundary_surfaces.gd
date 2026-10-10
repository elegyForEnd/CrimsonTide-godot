extends SceneTree
## Real cache geometry and exact port/shore cuts, including diagonal shore tips.
const Campaign=preload("res://scripts/story_campaign.gd")
const Surfaces=preload("res://scripts/story_surface_geometry.gd")
const Art=preload("res://scripts/story_exploration_art.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func area(pieces: Array[PackedVector2Array]) -> float:
	var result := 0.0
	for piece in pieces:
		var sum := 0.0
		var origin := piece[0]
		for i in piece.size():
			var a: Vector2=piece[i]-origin; var b: Vector2=piece[(i+1)%piece.size()]-origin
			sum+=float(a.x)*float(b.y)-float(a.y)*float(b.x)
		result+=absf(sum)*.5
	return result
func key(p: Vector2) -> Vector2i: return Vector2i(roundi(p.x*10),roundi(p.y*10))
func vertices(mesh: MeshInstance3D) -> PackedVector3Array:
	return mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
func run() -> void:
	if "--photos-only" in OS.get_cmdline_user_args():
		await photos(); print("boundary photos: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0); return
	if "--generated" in OS.get_cmdline_user_args():
		await generated(); print("generated boundaries: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0); return
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	var maps := 0; var matches := 0
	for act in range(1,7):
		c.enter(act,0)
		var original_outlines: Dictionary={}
		for s in c.map.outdoor: original_outlines[s]=c.map.regions[s].floor_polygon.duplicate()
		if "--packed" in OS.get_cmdline_user_args():
			var camp_stem := "opening-0" if act==1 else "act%d-0" % act
			var camp_suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
			var camp: Node3D=load("res://scenes/story/"+camp_stem+camp_suffix+".scn").instantiate()
			check(camp.has_node("BoundaryApron/ContinuousBoundaryGround"),"camp scenery also covers oblique boundary views")
			camp.get_node("BakedIndirectLight").light_data=null; camp.free()
		for stage in c.map.outdoor:
			var r=c.map.regions[stage]
			if stage==0: continue
			maps+=1
			for water in Surfaces.waters(r):
				for i in water.size():
					var p: Vector2=(water[i]+water[(i+1)%water.size()])*.5
					var cell := Surfaces.rectangle(Rect2(p-Vector2.ONE*50,Vector2.ONE*100))
					var whole: Array[PackedVector2Array]=Geometry2D.intersect_polygons(cell,r.floor_polygon)
					var wet := 0.0
					for piece in whole: wet+=area(Geometry2D.intersect_polygons(piece,water))
					check(absf(area(Surfaces.land_pieces(r,cell))+wet-area(whole))<2,"shore preserves partially wet cells %d:%d" % [act,stage])
			if "--packed" not in OS.get_cmdline_user_args(): continue
			var stem := "opening-%d" % stage if act==1 else "act%d-%d" % [act,stage]
			var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
			var node: Node3D=load("res://scenes/story/"+stem+suffix+".scn").instantiate()
			var floor_mesh: MeshInstance3D=node.get_node("AuthoredOutdoorFloor")
			var apron_mesh: MeshInstance3D=node.get_node("BoundaryApron/ContinuousBoundaryGround")
			check(floor_mesh.get_meta("surface_revision",0)==1 and node.get_node("BoundaryApron").get_meta("surface_revision",0)==1,"updated real land and apron cache")
			check(apron_mesh.gi_mode==GeometryInstance3D.GI_MODE_DISABLED,"nonwalkable cosmetic fill excluded from static GI")
			for water in node.get_children():
				if not water is MeshInstance3D or not str(water.name).begins_with("MatchedWaterSurface"): continue
				check(water.get_meta("water_world_space",false),"actual water occupies world coordinates")
				var good := true
				for v in vertices(water):
					var actual: Vector3=water.transform*v
					var p: Vector2=Vector2(actual.x,actual.z)*100-r.origin
					if not Rect2(Vector2.ZERO,r.extent).grow(1).has_point(p): good=false
				check(good,"cached water is located within its own region rather than at world origin")
			var floor_vertices: Dictionary={}
			for v in vertices(floor_mesh): floor_vertices[key(Vector2(v.x,v.z)*100)]=v.y
			var local_matches := 0; var seam_errors := 0; var bad_inside := 0
			for v in vertices(apron_mesh):
				var world_p := Vector2(v.x,v.z)*100; var p: Vector2=world_p-r.origin
				if Surfaces.nearest(r,p).distance_to(p)>.08: continue
				var lookup := key(world_p)
				if not floor_vertices.has(lookup): continue # water rim or a building foundation
				local_matches+=1
				if absf(v.y-float(floor_vertices[lookup]))>.002:
					seam_errors+=1
					if seam_errors<5: print("RIM_MISMATCH ",act,":",stage," p=",world_p," actual=",v.y," floor=",floor_vertices[lookup]," source=",Surfaces.apron_height(c.map,world_p)*.01)
			var arrays: Array=apron_mesh.mesh.surface_get_arrays(0)
			var vs: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for i in vs.size(): indices.append(i)
			for i in range(0,indices.size(),3):
				var midpoint: Vector3=(vs[indices[i]]+vs[indices[i+1]]+vs[indices[i+2]])/3
				if r.floor_contains(Vector2(midpoint.x,midpoint.z)*100-r.origin): bad_inside+=1
			check(local_matches>80 and seam_errors==0,"actual apron meets sampled terrain heights without an open rim %d:%d matched=%d errors=%d" % [act,stage,local_matches,seam_errors])
			check(bad_inside==0,"apron never covers playable land or adds coplanar ground")
			matches+=local_matches
			var gi: LightmapGI=node.get_node("BakedIndirectLight")
			check(gi.light_data!=null and gi.light_data.get_user_count()>0,"changed static land has an actual bake")
			for i in gi.light_data.get_user_count(): check(not str(gi.light_data.get_user_path(i)).begins_with("../BoundaryApron/"),"apron never baked as a hidden blocker")
			gi.light_data=null; node.free()
		for connector in c.map.connectors:
			for point in [connector.a,connector.b]:
				for offset in [Vector2(-190,-190),Vector2(190,-190),Vector2(-190,190),Vector2(190,190),Vector2.ZERO]:
					var cell := Surfaces.rectangle(Rect2(point+offset-Vector2.ONE*5,Vector2.ONE*10))
					var land := 0.0
					for s in c.map.outdoor:
						var r=c.map.regions[s]
						land+=area(Geometry2D.intersect_polygons(cell,Surfaces.shifted(Surfaces.outline(r),r.origin)))
					check(absf(area(Surfaces.connector_pieces(c.map,cell))+land-100)<.5,"connector fills curved footprint corner without overlapping ground")
		for s in c.map.outdoor: check(c.map.regions[s].floor_polygon==original_outlines[s],"connector rendering must never mutate movement footprints")
	check(maps==19,"all six acts' outdoor boundaries checked")
	print("boundary surfaces: %d checks, %d failures; actual rim vertices=%d" % [checks,failures,matches]); quit(1 if failures else 0)
func generated() -> void:
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	var w=preload("res://scripts/story_world.gd").new(); root.add_child(w); w.environment_builder.authoring=true
	for shot in [[1,4],[2,5],[3,2],[4,4],[5,5],[6,3]]:
		c.enter(shot[0],shot[1]); var outlines: Dictionary={}
		for s in c.map.outdoor: outlines[s]=c.map.regions[s].floor_polygon.duplicate()
		w.environment_builder.authoring_stage=shot[1]; w.geometry_key=""; w.build_story(c)
		for s in c.map.outdoor: check(outlines[s]==c.map.regions[s].floor_polygon,"actual generation preserves all movement footprints")
		check(w.scenery.find_child("ConnectedRoadBanks",true,false)!=null,"actual connections have closed sidewalls and a lower cap")
		var r=c.map.regions[shot[1]]
		for mesh in w.scenery.find_children("MatchedWaterSurface*","MeshInstance3D",true,false):
			var good := true
			for v in vertices(mesh):
				var p: Vector2=Vector2(v.x,v.z)*100-r.origin
				if not Rect2(Vector2.ZERO,r.extent).grow(1).has_point(p): good=false
			check(good,"source water uses the same world offset as source land")
		await process_frame
	w.queue_free(); await process_frame
func photos() -> void:
	root.size=Vector2i(3840,2160); DisplayServer.window_set_size(root.size)
	var screen=preload("res://scripts/story_screen.gd").new(); root.add_child(screen)
	screen.campaign.save_enabled=false; screen.start("user://boundary-photo-unused.json")
	screen.set_physics_process(false); screen.photo_mode=true; screen.hud.hide()
	var shots := [[1,2,4630,2380],[1,3,160,2340],[1,1,2380,4690],[1,4,2390,2490],[2,5,530,2200],[3,2,4640,2350],[4,4,2380,4690],[5,1,535,1650],[5,5,2390,2490],[6,3,4630,2300]]
	for shot in shots:
		screen.campaign.enter(shot[0],shot[1]); var r=screen.campaign.map.regions[shot[1]]
		var p := Vector2(shot[2],shot[3])
		if not r.walkable(p):
			var best := INF; var candidate := p
			for y in range(-900,901,60):
				for x in range(-900,901,60):
					var at := p+Vector2(x,y); var distance := at.distance_squared_to(p)
					if distance<best and r.walkable(at): best=distance; candidate=at
			p=candidate
		screen.campaign.hero_at=r.origin+p
		for i in 3:
			var at: Vector2=screen.campaign.hero_at+Vector2((i-1)*85,-120)
			screen.campaign.allies[i]=at if screen.campaign.map.walkable(at) else screen.campaign.hero_at
		check(r.walkable(p),"photo hero on playable ground")
		screen.campaign.enemies=[]; screen.world.zoom=21
		for i in 30: screen.world.build_story(screen.campaign); screen.world.sync_story(root.size,.016); await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image(); check(image.get_size()==Vector2i(3840,2160),"real 4K boundary capture")
		var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
		image.save_png("res://build/boundary-%d-%d%s.png" % [shot[0],shot[1],suffix]); print("BOUNDARY_PHOTO ",shot)
	screen.queue_free(); await process_frame
	preload("res://scripts/story_floor_palette.gd").cache.clear()
	for i in 8: await process_frame
