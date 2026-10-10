extends SceneTree
const Campaign=preload("res://scripts/story_campaign.gd")
const Screen=preload("res://scripts/story_screen.gd")
const Art=preload("res://scripts/story_exploration_art.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func follow(c, target: Vector2) -> bool:
	var route: PackedVector2Array=c.map.route(c.map.spawn,target)
	if route.is_empty(): return false
	var at: Vector2=c.map.spawn
	for point in route:
		for i in 100:
			if at.distance_to(point)<5: break
			at=c.map.move(at,(point-at).limit_length(8))
	return at.distance_to(target)<90
func run() -> void:
	if "--photos-only" in OS.get_cmdline_user_args():
		await photos(); print("story exploration photos: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0); return
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	var dungeon_count := 0; var outdoors := 0
	for a in range(1,7):
		c.enter(a,0)
		for stage in c.map.regions:
			var r=c.map.regions[stage]
			if stage==0: continue
			c.enter(a,stage)
			if r.indoor:
				dungeon_count+=1
				check(r.exploration_plan.area_m2>=3500,"large connected playable area")
				check(r.exploration_plan.chambers.size()>=8,"named functional spaces follow each typology")
				check(r.exploration_plan.get("layout_revision",0)==2,"identity layout replaces the old chamber lattice")
				check(r.dressing.size()>=60,"functional dressing exists in actual space")
				check(r.stairs.is_empty(),"no isolated block terrace remains")
				var profile: Array=r.exploration_plan.grade_bands
				var variation := 0.0
				for band in profile: variation=maxf(variation,absf(float(band.to)-float(band.from)))
				check(variation>=50,"height profile belongs to this dungeon's circulation")
				for room in r.exploration_plan.chambers:
					var target: Array=room.get("visit",room.center)
					var p := Vector2(target[0],target[1])
					check(follow(c,p),"actual movement reaches named room %d:%d:%s" % [a,stage,room.name])
				for p in r.anchors+r.side_anchors+r.chests+[r.waypoint]: check(follow(c,p),"movement reaches gameplay target %d:%d %s" % [a,stage,p])
				for hole in r.floor_voids:
					var triangles := Geometry2D.triangulate_polygon(hole)
					if triangles.size()>=3:
						var p: Vector2=(hole[triangles[0]]+hole[triangles[1]]+hole[triangles[2]])/3
						check(not r.walkable(p,1),"central rock/service void is genuinely blocked")
				for e in c.enemies: check(c.map.walkable(e.p),"encounter on reachable physical ground")
				check(c.enemies.size()>=20,"encounters continue throughout functional spaces")
				if "--packed" in OS.get_cmdline_user_args():
					var stem := "opening-%d" % stage if a==1 else "act%d-%d" % [a,stage]
					var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
					var scene: Node3D=load("res://scenes/story/"+stem+suffix+".scn").instantiate()
					var gi: LightmapGI=scene.get_node("BakedIndirectLight")
					check(gi.light_data!=null,"updated actual GI bake exists")
					gi.light_data=null; gi.free()
					var floor_node: MeshInstance3D=scene.get_node("AuthoredDungeonFloor")
					check(floor_node.get_meta("exploration_revision",0)==2 and floor_node.get_meta("layout_family","")==r.exploration_plan.layout_family,"packed geometry identifies its authored typology")
					var arrays: Array=floor_node.mesh.surface_get_arrays(0)
					var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
					var outside := 0; var faces := 0
					for i in range(0,indices.size(),3):
						var p: Vector3=(vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3
						var normal: Vector3=(vertices[indices[i+1]]-vertices[indices[i]]).cross(vertices[indices[i+2]]-vertices[indices[i]])
						if absf(normal.y)<.0001: continue
						faces+=1
						if not r.floor_contains(Vector2(p.x,p.z)*100): outside+=1
					check(faces>10000 and outside==0,"rendered floor never fills voids or outside footprint")
					for item in r.dressing: check(scene.get_node("CraftedSetDressing").has_node(item.id),"dressing cache matches authored logical layout")
					scene.free()
			else:
				outdoors+=1
				check(r.floor_polygon.size()>25,"organic visible outdoor boundary")
				check(r.stairs.is_empty() and not r.landforms.is_empty(),"old outdoor block replaced by continuous shoulder")
				check(not r.walkable(Vector2(50,50)),"square corner outside real landscape")
				for p in r.anchors+r.side_anchors+r.chests+[r.spawn,r.waypoint]: check(r.walkable(p),"outdoor targets survive organic boundary")
	check(dungeon_count==30 and outdoors==19,"entire six-act scope checked")
	if "--packed" in OS.get_cmdline_user_args():
		for stage in range(5):
			var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
			var scene: Node3D=load("res://scenes/story/opening-%d%s.scn" % [stage,suffix]).instantiate()
			for gi in scene.find_children("*","LightmapGI",true,false): gi.light_data=null; gi.free()
			for probe in scene.find_children("*","ReflectionProbe",true,false): probe.free()
			var groups := 0
			for cover in scene.find_children("*","MultiMeshInstance3D",true,false):
				groups+=1
				check(cover.has_method("prepare_capture") and cover.source_transforms.size()>0,"serialized foliage has authoritative CPU transforms")
				check(cover.multimesh.instance_count==0,"capture never persists an uninitialized Dummy instance buffer")
				for transform in cover.source_transforms: check(transform.origin.is_finite() and transform.origin.length()<300 and transform.basis.determinant()>.01 and transform.basis.determinant()<4,"safe finite vegetation transform")
			check(groups>0,"actual outdoor cache contains spatial vegetation groups")
			scene.free()
	if "--photos" in OS.get_cmdline_user_args(): await photos()
	print("story exploration: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
func photos() -> void:
	root.size=Vector2i(3840,2160); DisplayServer.window_set_size(root.size)
	var screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false
	screen.start("user://exploration-photo-unused.json"); screen.set_physics_process(false); screen.photo_mode=true; screen.hud.hide()
	var shots: Array=[[1,7,3],[1,7,7],[1,8,3],[1,9,7],[2,7,3],[2,7,7],[3,7,7],[4,7,7],[5,7,7],[6,7,7],[1,1,-1],[3,1,-1]]
	var identity_photos: bool="--identity-photos" in OS.get_cmdline_user_args()
	if identity_photos: shots=[[1,8,1],[1,7,3],[1,9,1],[1,6,3],[2,7,2],[2,8,3],[3,5,2],[3,7,3],[4,6,3],[4,7,2],[5,7,3],[6,7,3]]
	for shot in shots:
		var selected := 0
		var selected_stage := -1
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--photo-act="): selected=int(arg.trim_prefix("--photo-act="))
			if arg.begins_with("--photo-stage="): selected_stage=int(arg.trim_prefix("--photo-stage="))
		if selected>0 and shot[0]!=selected: continue
		if selected_stage>=0 and shot[1]!=selected_stage: continue
		print("EXPLORATION_PHOTO ",shot)
		screen.campaign.enter(shot[0],shot[1])
		var r=screen.campaign.map.regions[shot[1]]
		var p := Vector2(3350,1350)
		if shot[2]>=0:
			var room: Dictionary=r.exploration_plan.chambers[shot[2]]
			p=Vector2(room.center[0],room.center[1])+Vector2(-430,-230) if not identity_photos else Vector2(room.visit[0],room.visit[1])
		screen.campaign.hero_at=r.origin+p; screen.campaign.enemies=[]; screen.world.zoom=48 if identity_photos else 22
		for i in 3:
			var ally_at: Vector2=screen.campaign.hero_at+Vector2(0,900+i*100)
			if not screen.campaign.map.walkable(ally_at): ally_at=screen.campaign.hero_at+Vector2((i-1)*70,-100)
			if not screen.campaign.map.walkable(ally_at): ally_at=screen.campaign.hero_at
			screen.campaign.allies[i]=ally_at
		check(screen.campaign.map.walkable(screen.campaign.hero_at) and screen.campaign.allies.all(func(at): return screen.campaign.map.walkable(at)),"photo party stands on actual walkable ground")
		for i in 24: screen.world.build_story(screen.campaign); screen.world.sync_story(root.size,.016); await process_frame
		await RenderingServer.frame_post_draw
		var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
		var picture := root.get_texture().get_image(); check(picture.get_size()==Vector2i(3840,2160),"actual 4K scene capture")
		var colours: Dictionary={}
		for y in range(1,10):
			for x in range(1,16):
				var colour := picture.get_pixel(x*240,y*200)
				colours[Vector3i(int(colour.r*60),int(colour.g*60),int(colour.b*60))]=true
		check(colours.size()>12,"rendered scene has spatial detail, not a uniform occluding plane")
		picture.save_png("res://build/%s-%d-%d-room%d%s.png" % ["identity" if identity_photos else "exploration",shot[0],shot[1],shot[2],suffix])
		check(screen.world.scenery.find_child("AuthoredDungeonFloor",true,false)!=null if shot[2]>=0 else screen.world.scenery.find_child("ErodedRegionEdge",true,false)!=null,"actual new scene loaded")
	screen.queue_free(); await process_frame
	preload("res://scripts/story_floor_palette.gd").cache.clear()
	for i in 6: await process_frame
