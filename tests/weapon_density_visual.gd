extends SceneTree
## GPU-only: --rendering-method gl_compatibility --script tests/weapon_density_visual.gd
const Art=preload("res://scripts/weapon_image_art.gd")
const Finish=preload("res://scripts/combat_finish.gd")
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const DENSITY=preload("res://resources/weapon_density.gdshader")
var checks := 0
var failures := 0
class DensityStamp extends Node2D:
	var texture: Texture2D
	func _draw() -> void:
		if texture: draw_texture_rect(texture,Rect2(40,40,256,256),false,Color(.6,.8,1,.8))
class MistOnly extends Finish:
	func _draw() -> void: pass # Deliberately exclude flash/body/fragments from the pixel test.
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func capture(viewport: SubViewport) -> Image:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func alpha_in(image: Image, bounds: Rect2i) -> float:
	var clipped := bounds.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var total := 0.0
	for y in range(clipped.position.y,clipped.end.y):
		for x in range(clipped.position.x,clipped.end.x): total+=image.get_pixel(x,y).a
	return total
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/vfx-v2"))
	var viewport := SubViewport.new()
	viewport.size=Vector2i(480,360); viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stamp := DensityStamp.new()
	var shader_material := ShaderMaterial.new(); shader_material.shader=DENSITY
	stamp.material=shader_material; viewport.add_child(stamp)
	Art.load_mechanic_manifest()
	for source in Profiles.DENSITIES:
		var texture := Art.mechanic_texture(source)
		check(texture!=null,"Registered density texture loads: "+source)
		if texture==null: continue
		var original_path := Art.MECHANICS_BASE+str(Art.mechanics[source].file)
		var original := Image.new()
		check(original.load_png_from_buffer(FileAccess.get_file_as_bytes(original_path))==OK,"Original RGB density PNG decodes without altering source pixels")
		check(original.get_format()==Image.FORMAT_RGB8,"Density remains the original RGB image without authored alpha: "+source)
		check(original.get_pixel(0,0).a==1.0,"Original black corner is opaque RGB; runtime must derive alpha")
		stamp.texture=texture; stamp.queue_redraw()
		shader_material.set_shader_parameter("effect_phase",.45)
		shader_material.set_shader_parameter("flow",0.0)
		shader_material.set_shader_parameter("shear",0.0)
		var baseline := await capture(viewport)
		check(baseline.get_used_rect().has_area(),"Grayscale density produces visible translucent pixels: "+source)
		for corner in [Vector2i(41,41),Vector2i(294,41),Vector2i(41,294),Vector2i(294,294)]:
			check(baseline.get_pixelv(corner).a==0.0,"Black density corner becomes fully transparent, never a black quad: "+source)
		var repeated := await capture(viewport)
		check(repeated.get_data()==baseline.get_data(),"Repeated phase is pixel deterministic: "+source)
		shader_material.set_shader_parameter("flow",1.2)
		var flowing := await capture(viewport)
		check(flowing.get_data()!=baseline.get_data(),"Flow changes material pixels: "+source)
		shader_material.set_shader_parameter("flow",0.0)
		shader_material.set_shader_parameter("shear",.8)
		var sheared := await capture(viewport)
		check(sheared.get_data()!=baseline.get_data(),"Shear independently changes material pixels: "+source)
		baseline.save_png("res://build/vfx-v2/"+source+"-shader.png")
	stamp.hide()
	var finish := MistOnly.new(); viewport.add_child(finish)
	finish.position=Vector2(17,23)
	finish.projector=func(p: Vector2): return p*Vector2(.8,.6)+Vector2(30,10)
	finish.glow.hide()
	var weapons := [600,627,614,646]
	for i in weapons.size():
		finish.event({"kind":"impact","weapon_index":weapons[i],"id":1,"enemy_id":i+1,"damage":15,
			"p":Vector2(90+i*120,300),"contact_p":Vector2(90+i*120,220),"contact_lift":12.0,"height":6.0,
			"aim":Vector2.RIGHT,"heavy":true})
	check(finish.contacts.size()==4 and finish.mist.get_child_count()==4,"Four valid impacts own four independent mist stamps")
	finish.advance(.045)
	var bindings := {}
	for contact in finish.contacts:
		check(contact.profile==Profiles.profile(contact.weapon_index),"Real contact retains exact material profile")
		var material: ShaderMaterial=contact.mist_node.material
		bindings[material.get_instance_id()]=true
		check(is_equal_approx(float(material.get_shader_parameter("flow")),float(contact.profile.flow)),"Each material owns its flow parameter")
		check(is_equal_approx(float(material.get_shader_parameter("shear")),float(contact.profile.shear)),"Each material owns its shear parameter")
		check(is_equal_approx(float(material.get_shader_parameter("effect_phase")),float(finish.mist_state(contact).phase)),"Each material owns its age and lifetime phase")
	check(bindings.size()==4,"Concurrent contacts never share mutable shader uniforms")
	var all := await capture(viewport)
	check(all.get_used_rect().has_area(),"Mist alone remains visible with white body and additive glow excluded")
	all.save_png("res://build/vfx-v2/density-mist-only.png")
	for contact in finish.contacts:
		for other in finish.contacts: other.mist_node.visible=other==contact
		var pixels := await capture(viewport)
		var state := finish.mist_state(contact)
		var anchor := finish.projected(contact.contact)-Vector2(0,18)
		var point: Vector2=state.point
		check(point.distance_to(anchor)<7,"Mist center honors elevated contact, real projection and bounded drift")
		check(alpha_in(pixels,Rect2i(Vector2i(point)-Vector2i(34,23),Vector2i(68,46)))>0,"Measured ink fitting makes each material visible at its real contact")
		var used := pixels.get_used_rect()
		check(used.has_area() and Vector2(used.get_center()).distance_to(point)<35,"Rendered material stays anchored near the projected contact")
		var foot := finish.projected(contact.p)-Vector2(0,float(contact.lift))
		check(is_zero_approx(alpha_in(pixels,Rect2i(Vector2i(foot)-Vector2i(10,10),Vector2i(20,20)))),"High contact fog does not fall back to the target feet")
	finish.reset()
	var cleared := await capture(viewport)
	check(not cleared.get_used_rect().has_area() and finish.mist.get_child_count()==0,"Reset clears every mist pixel and stamp without residue")
	viewport.queue_free(); await process_frame; await process_frame
	print("WEAPON DENSITY VISUAL ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
