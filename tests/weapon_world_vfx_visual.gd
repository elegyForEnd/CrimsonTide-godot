extends SceneTree
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func capture(view: SubViewport) -> Image:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func energy(a: Image,b: Image) -> float:
	var total := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var c := a.get_pixel(x,y); var d := b.get_pixel(x,y)
			total+=absf(c.r-d.r)+absf(c.g-d.g)+absf(c.b-d.b)
	return total
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/vfx-3d"))
	var view := SubViewport.new(); view.size=Vector2i(640,480); view.own_world_3d=true; view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var world := Node3D.new(); view.add_child(world)
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=6
	world.add_child(camera); camera.position=Vector3(0,5,8); camera.look_at(Vector3(0,.5,0)); camera.make_current()
	var wall := MeshInstance3D.new(); var box := BoxMesh.new(); box.size=Vector3(10,4,.25); wall.mesh=box
	wall.position=Vector3(0,1.2,2.5); var mat := StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color=Color("263640")
	wall.material_override=mat; world.add_child(wall)
	var fx=Combat.new(); fx.camera=camera; world.add_child(fx)
	var baseline := await capture(view)
	var event := {"kind":"strike","weapon_index":615,"p":Vector2(-100,0),"aim":Vector2.RIGHT,"reach":170,"id":1}
	fx.event(event); fx.advance(.065)
	var hidden := await capture(view)
	check(hidden.get_data()==baseline.get_data(),"World wall occludes all blade/mist/debris layers through native depth")
	wall.hide(); var empty := await capture(view)
	fx.advance(.065) # Isolate all layers during the actual post-contact overlap.
	var visible := await capture(view)
	check(energy(visible,baseline)>1,"World scene changes when the wall is removed")
	# Isolate all layers, including the sample hammer's separate heat plume.
	for child in fx.effects[0].get_children():
		if child is MeshInstance3D: child.hide()
	empty=await capture(view)
	fx.effects[0].authored.heat.show()
	var heat_only := await capture(view)
	check(energy(heat_only,empty)>.1,"Heat plume is an independent layer and cannot masquerade as the empty baseline")
	fx.effects[0].authored.heat.hide()
	fx.effects[0].ribbon.show(); var ribbon_only := await capture(view)
	check(energy(ribbon_only,empty)>1,"Blade motion exists without smoke or particles or full-skill artwork")
	fx.effects[0].ribbon.hide(); fx.effects[0].smoke.show()
	var smoke_only := await capture(view)
	check(energy(smoke_only,empty)>.1,"Ground contact owns independent procedural dust after landing")
	fx.effects[0].smoke.hide(); fx.effects[0].debris.show()
	var fragments := await capture(view)
	check(energy(fragments,empty)>.1,"Detached three-dimensional particles exist without the blade")
	fx.effects[0].ribbon.show(); fx.effects[0].smoke.show()
	fx.effects[0].age=.11; fx.effects[0].rebuild(); var changed := await capture(view)
	var stable := await capture(view)
	check(changed.get_data()==stable.get_data(),"Seeking identical event phase gives identical pixels")
	check(changed.get_data()!=visible.get_data(),"Geometry, material flow and particle positions evolve with event time")
	var center: Vector3=fx.effects[0].origin
	camera.position.x+=.65; camera.look_at(Vector3(0,.5,0)); fx.advance(0)
	var parallax := await capture(view)
	check(parallax.get_data()!=changed.get_data() and fx.effects[0].origin==center,"Camera movement changes parallax but leaves the release in world space")
	parallax.save_png("res://build/vfx-3d/release-native-depth.png")
	fx.reset(); var clear := await capture(view)
	check(energy(clear,empty)<.01,"Reset leaves no blade, smoke or particle pixels")
	var timings: Array=[]
	for i in 96: fx.event({"kind":"strike","weapon_index":600+i%48,"p":Vector2((i%12-6)*35,(i/12-4)*35),"aim":Vector2.RIGHT,"reach":130,"id":i})
	for frame in 16:
		var start := Time.get_ticks_usec(); fx.advance(.008); timings.append((Time.get_ticks_usec()-start)/1000.0)
		await process_frame; await RenderingServer.frame_post_draw
	check(fx.effects.size()<=96 and fx.get_child_count()<=96,"96 concurrent layered releases retain node budget on real renderer")
	fx.reset(); await process_frame
	check(fx.get_child_count()==0,"High-load reset removes all mesh instances")
	timings.sort(); print("WORLD VFX STRESS 96 concurrent: median CPU rebuild ",timings[timings.size()/2]," ms, max ",timings.back()," ms; includes cold allocations")
	view.queue_free(); await process_frame
	print("WEAPON WORLD VFX VISUAL ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
