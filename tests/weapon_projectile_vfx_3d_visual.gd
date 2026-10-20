extends SceneTree
## Native-depth GPU verification; use --rendering-method gl_compatibility.
const VFX=preload("res://scripts/weapon_projectile_vfx_3d.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func capture(viewport: SubViewport) -> Image:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func difference(a: Image, b: Image) -> int:
	var left := a.get_data(); var right := b.get_data()
	var total := 0
	for i in left.size(): total+=absi(int(left[i])-int(right[i]))
	return total
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/vfx-v3"))
	var viewport := SubViewport.new()
	viewport.size=Vector2i(640,480); viewport.transparent_bg=true; viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var world := Node3D.new(); viewport.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=7.0; camera.near=.05; camera.far=50
	camera.position=Vector3(2.5,4.8,8); camera.look_at(Vector3(2.5,.6,1)); camera.current=true
	var original_camera := camera.transform
	var wall := MeshInstance3D.new(); world.add_child(wall)
	var wall_mesh := BoxMesh.new(); wall_mesh.size=Vector3(8,3,.4); wall.mesh=wall_mesh
	wall.position=Vector3(2.5,.7,1)
	var wall_material := StandardMaterial3D.new()
	wall_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; wall_material.albedo_color=Color("263640")
	wall.material_override=wall_material
	var fx=VFX.new(); world.add_child(fx); fx.camera=camera
	fx.height_at=func(_p: Vector2): return 10.0
	var baseline := await capture(viewport)
	fx.observe([{"fx_id":99,"p":Vector2(80,0),"height":40,"weapon_index":637,"v":Vector2(1280,0)}],.025)
	await capture(viewport)
	check(fx.flights[99].ribbon.mesh==null and not fx.flights[99].ribbon.visible,"First rendered projectile frame never binds an empty mesh RID")
	fx.reset()
	for sample in 8:
		fx.advance(.025)
		fx.observe([{"fx_id":1,"p":Vector2(80+sample*32,0),"height":40,"weapon_index":637,"spell":"meteor","v":Vector2(1280,0)}],.025)
		await capture(viewport)
	var occluded := await capture(viewport)
	check(occluded.get_data()==baseline.get_data(),"Opaque world wall occludes ribbon, projectile body and particles through native depth")
	occluded.save_png("res://build/vfx-v3/projectile-occluded.png")
	fx.reset()
	var weapons := [624,637,638,646]
	var spells := ["bullet","meteor","needle","vortex"]
	for sample in 8:
		var snapshot: Array=[]
		for i in 4:
			snapshot.append({"fx_id":20+i,"p":Vector2(70+sample*36,215+i*45+sin(sample*.5)*6),"height":38+i*4,"weapon_index":weapons[i],"spell":spells[i],"v":Vector2(1440,0)})
		fx.advance(.025); fx.observe(snapshot,.025)
		await capture(viewport)
	var front := await capture(viewport)
	check(front.get_data()!=baseline.get_data(),"Native projectiles in front of the wall remain visibly rendered")
	front.save_png("res://build/vfx-v3/projectile-native-3d.png")
	var materials := {}
	for flight in fx.flights.values():
		materials[flight.material.get_instance_id()]=true
		check(flight.ribbon.mesh.get_surface_count()==1,"Each observed world trajectory produces a triangle mesh surface")
		check(flight.body.visible!=flight.silhouette.visible and flight.native_body,"Painted head and sculpted fallback cannot duplicate each other")
		check(flight.body.visible and flight.body.material_override.get_shader_parameter("painted_texture") is Texture2D,"Weapon-specific payload painting is a real depth-tested world mesh")
		flight.body.hide(); flight.core.hide(); flight.silhouette.hide()
		if is_instance_valid(flight.get("vapor",null)): flight.vapor.hide()
	fx.particle_batch.hide()
	var ribbon_only := await capture(viewport)
	check(ribbon_only.get_data()!=baseline.get_data(),"3D UV ribbon remains visible without body planes or particles")
	check(materials.size()==4,"Concurrent physical materials retain independent spatial uniforms")
	ribbon_only.save_png("res://build/vfx-v3/projectile-world-ribbons-only.png")
	for entry in fx.flights.values(): entry.material.set_shader_parameter("wake_opacity",.25)
	var fading := await capture(viewport)
	check(difference(fading,baseline)>0 and difference(fading,baseline)<difference(ribbon_only,baseline),"Native ribbon shader progressively attenuates surviving wake pixels")
	for entry in fx.flights.values(): entry.material.set_shader_parameter("wake_opacity",0.0)
	var extinguished := await capture(viewport)
	check(extinguished.get_data()==baseline.get_data(),"Wake reaches zero pixels smoothly before bounded root cleanup")
	for entry in fx.flights.values(): entry.material.set_shader_parameter("wake_opacity",1.0)
	var flight: Dictionary=fx.flights[23]
	var centers: PackedVector3Array=flight.geometry.centers.duplicate()
	fx.advance(.025)
	for entry in fx.flights.values(): entry.body.hide(); entry.core.hide(); entry.silhouette.hide()
	var flowing := await capture(viewport)
	check(flowing.get_data()!=ribbon_only.get_data(),"World ribbon has changing density transport and age taper, not a static body sticker")
	check(is_equal_approx(float(flight.material.get_shader_parameter("phase")),float(fx.clock)),"Procedural material transport follows explicit simulation clock")
	camera.position+=Vector3(.6,.2,-.1); camera.look_at(Vector3(2.5,.6,1))
	fx.advance(0)
	check(flight.geometry.centers==centers,"Camera movement does not change real-world history positions")
	var parallax := await capture(viewport)
	check(parallax.get_data()!=flowing.get_data(),"Camera3D movement produces actual world parallax")
	camera.transform=original_camera
	fx.reset()
	var cleared := await capture(viewport)
	check(cleared.get_data()==baseline.get_data(),"Reset removes all native VFX pixels and leaves the world unchanged")
	viewport.queue_free(); await process_frame; await process_frame
	print("WEAPON PROJECTILE VFX 3D VISUAL ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
