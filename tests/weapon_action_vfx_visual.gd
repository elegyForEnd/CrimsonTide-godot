extends SceneTree
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func capture(view: SubViewport) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func run() -> void:
	var view := SubViewport.new(); view.size=Vector2i(320,240); view.own_world_3d=true; view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=5
	view.add_child(camera); camera.position=Vector3(0,6,7); camera.look_at(Vector3(0,.5,0)); camera.make_current()
	var fx=Combat.new(); fx.camera=camera; view.add_child(fx)
	for weapon in range(600,648):
		var images := {}
		for action in ["normal","heavy","art"]:
			fx.event({"kind":"strike","p":Vector2(-70,0),"weapon_index":weapon,"aim":Vector2.RIGHT,"reach":180,"vfx_action":action,"charged":action=="heavy","id":1})
			fx.advance(.055)
			var image := await capture(view)
			check(image.get_used_rect().has_area(),"Every weapon/action has visible native rendered pixels")
			images[action]=hash(image.get_data())
			if action=="normal":
				var effect=fx.effects.back()
				var designed_material: ShaderMaterial=effect.body_material
				var geometry_before := var_to_bytes(effect.ribbon.mesh.surface_get_arrays(0))
				var sample_surface := designed_material.shader.resource_path.ends_with("weapon_sample_surface.gdshader")
				var hybrid_surface := designed_material.shader.resource_path.ends_with("weapon_hybrid_surface.gdshader")
				var parameter := "painted_detail" if hybrid_surface else "surface_kind" if sample_surface else "ribbon_mode"
				var original_value: Variant=designed_material.get_shader_parameter(parameter)
				if hybrid_surface:
					var white := Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
					designed_material.set_shader_parameter(parameter,ImageTexture.create_from_image(white))
				else: designed_material.set_shader_parameter(parameter,1 if sample_surface else false)
				var without_material := await capture(view)
				check(image.get_data()!=without_material.get_data(),"Designed material changes actual release pixels for weapon "+str(weapon))
				check(geometry_before==var_to_bytes(effect.ribbon.mesh.surface_get_arrays(0)),"Material detail is independent of native trajectory")
				designed_material.set_shader_parameter(parameter,original_value)
			fx.reset(); await process_frame
		check(images.normal!=images.heavy and images.heavy!=images.art and images.normal!=images.art,"Each weapon's three releases differ on the actual renderer")
		fx.event({"kind":"hold_charge","p":Vector2.ZERO,"weapon_index":weapon,"aim":Vector2.RIGHT,"id":1,"hold_time":.6})
		fx.advance(.10); var early := await capture(view)
		fx.advance(.51); fx.event({"kind":"hold_ready","id":1}); fx.advance(.02)
		var ready := await capture(view)
		check(early.get_used_rect().has_area() and ready.get_used_rect().has_area() and early.get_data()!=ready.get_data(),"Gathering and full-charge feedback are visible and distinct")
		fx.advance(3); var held := await capture(view)
		check(held.get_used_rect().has_area(),"Full-charge holding remains visibly active")
		fx.event({"kind":"hold_cancel","id":1}); var clear := await capture(view)
		check(not clear.get_used_rect().has_area(),"Cancel leaves no charge pixels")
	view.queue_free(); await process_frame
	print("WEAPON ACTION VFX VISUAL ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
