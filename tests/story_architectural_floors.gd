extends SceneTree
const Campaign=preload("res://scripts/story_campaign.gd")
const Floors=preload("res://scripts/story_floor_palette.gd")
const Screen=preload("res://scripts/story_screen.gd")
const GROUND=preload("res://resources/story_ground.gdshader")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state()
	for act in range(1,7):
		c.enter(act,0)
		for r in c.map.regions.values():
			if not Floors.architectural(r): continue
			var mat := Floors.material(r)
			check(mat.shader!=GROUND,"architecture never inherits soil/road shader")
			var texture: Texture2D=mat.get_shader_parameter("base_albedo")
			check(not "soil_" in texture.resource_path and not "mud_" in texture.resource_path and not "paving_" in texture.resource_path,"dedicated architectural texture "+r.layout)
			for channel in ["albedo","normal","orm"]: check(mat.get_shader_parameter("base_"+channel)!=null,"complete architectural PBR "+channel)
	check(Floors.profile("crypt").base!=Floors.profile("castle").base,"crypt and castle have distinct floors")
	check(Floors.profile("library").base=="timber","library floor is wood")
	c.enter(1,7); check(not Floors.architectural(c.map.regions[7]),"natural cavern retains rock/soil floor")
	var packed: Node3D=load("res://scenes/story/opening-9.scn").instantiate()
	# This is a material inspection, not a GI test; don't allocate a second bake.
	for gi in packed.find_children("*","LightmapGI",true,false): gi.light_data=null; gi.free()
	for probe in packed.find_children("*","ReflectionProbe",true,false): probe.free()
	var authored := 0
	for mesh in packed.find_children("*","MeshInstance3D",true,false):
		var mat: Material=mesh.material_override
		if mat is ShaderMaterial and mat.shader==Floors.FLOOR: authored+=1
		check(not (mat is ShaderMaterial and mat.shader==GROUND),"packed castle has no outdoor ground")
	check(authored>=1,"castle continuous floor and integrated stairs use architectural palette")
	var actual_floor: MeshInstance3D=packed.get_node("AuthoredDungeonFloor")
	var vertices: PackedVector3Array=actual_floor.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bottom := INF; var top := -INF
	for p in vertices: bottom=minf(bottom,p.y); top=maxf(top,p.y)
	check(top-bottom>1.8,"actual architectural geometry includes connected level changes")
	packed.free()
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(3840,2160); DisplayServer.window_set_size(root.size)
		var screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false
		screen.start("user://floor-photo-unused.json"); screen.set_physics_process(false); screen.photo_mode=true; screen.hud.hide()
		for shot in [[1,9,Vector2(3200,3800),"castle-hall"],[1,9,Vector2(3200,5740),"castle-dais"],[1,8,Vector2(2300,2850),"crypt"],[1,5,Vector2(2400,2050),"chapel"],[2,4,Vector2(2400,1300),"library"]]:
			screen.campaign.enter(shot[0],shot[1]); screen.campaign.hero_at=screen.campaign.map.regions[shot[1]].origin+shot[2]
			screen.campaign.enemies=[]; screen.world.zoom=18
			for i in 3: screen.campaign.allies[i]=screen.campaign.hero_at+Vector2(0,450+i*70)
			for i in 25: screen.world.sync_story(Vector2(1440,900),.03); await process_frame
			var floors := 0; var outdoor := 0
			for mesh in screen.world.scenery.find_children("*","MeshInstance3D",true,false):
				if mesh.material_override is ShaderMaterial:
					if mesh.material_override.shader==Floors.FLOOR: floors+=1
					if mesh.material_override.shader==GROUND: outdoor+=1
			check(floors>0 and outdoor==0,"actual playable interior has architectural floors: "+shot[3])
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image(); check(picture.get_size()==Vector2i(3840,2160),"4K floor capture")
			var suffix := "compat-" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
			picture.save_png("res://build/story-floor-%s%s.png" % [suffix,shot[3]])
		screen.queue_free(); await process_frame
	print("architectural floors: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
