extends SceneTree
## Run with a real renderer: --rendering-method gl_compatibility --script tests/vfx_release_visual.gd
const Surface=preload("res://scripts/vfx_release_surface.gd")
var checks := 0
var failures := 0
class Host extends Node2D:
	var texture: ImageTexture
	func draw_mechanic(target: CanvasItem, _effect: Dictionary, additive: bool) -> void:
		target.draw_set_transform(Vector2(90,85),.25,Vector2(.9,.7))
		target.draw_texture_rect(texture,Rect2(-64,-64,128,128),false,Color(1,1,1,.14 if additive else 1.0))
		target.draw_set_transform(Vector2.ZERO)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func capture() -> Image:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func alpha_sum(frame: Image) -> float:
	var total := 0.0
	for y in frame.get_height():
		for x in frame.get_width(): total+=frame.get_pixel(x,y).a
	return total
func run() -> void:
	root.size=Vector2i(192,192); root.content_scale_size=root.size
	root.transparent_bg=true
	var host=Host.new(); root.add_child(host)
	var ink=Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var energy=maxf(0,1-Vector2(x-64,y-64).length()/64.0)
			# Asymmetric lobes expose any accidental UV, pivot or size changes.
			energy*=.6 if x<50 and y>64 else 1.0
			ink.set_pixel(x,y,Color(energy,energy*.8,energy,energy))
	host.texture=ImageTexture.create_from_image(ink)
	var surface=Surface.new()
	surface.host=host; surface.effect={"age":0.0,"life":1.0}
	surface.sync() # Public sync is safe before entering the tree.
	host.add_child(surface)
	var release_shader: Shader=surface.surface_material.shader
	var release_glow: Shader=surface.glow_material.shader
	surface.surface_material.shader=load("res://resources/stylized_texture.gdshader")
	surface.glow_material.shader=load("res://resources/weapon_edge_glow.gdshader")
	surface.sync()
	var reference := await capture()
	surface.surface_material.shader=release_shader
	surface.glow_material.shader=release_glow
	surface.sync()
	var early := await capture()
	check(early.get_data()==reference.get_data(),"Release shader preserves source UV, anchor, size, white core and initial glow")
	surface.effect.age=.25; surface.sync()
	var quarter := await capture()
	check(quarter.get_data()==early.get_data(),"First quarter of release has no erosion")
	surface.effect.age=.55; surface.sync()
	var recovery := await capture()
	check(alpha_sum(recovery)<alpha_sum(early) and alpha_sum(recovery)>0,"Recovery erodes peripheral ink while retaining a visible core")
	var repeated := await capture()
	check(repeated.get_data()==recovery.get_data(),"Identical phase produces identical pixels without TIME noise")
	surface.effect.age=.8; surface.sync()
	var tail := await capture()
	check(alpha_sum(tail)<alpha_sum(recovery),"Later recovery continues eroding the surface and glow")
	surface.effect.age=1.0; surface.sync()
	check(not surface.visible,"Expired surface hides itself")
	surface.visible=true # Exercise the shader endpoint independently of lifetime hiding.
	var expired := await capture()
	check(is_zero_approx(alpha_sum(expired)),"Phase one is fully transparent including halo samples")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	early.save_png("res://build/vfx-release-early.png")
	recovery.save_png("res://build/vfx-release-recovery.png")
	tail.save_png("res://build/vfx-release-tail.png")
	print("VFX RELEASE VISUAL ",checks," checks, ",failures," failures")
	host.queue_free(); await process_frame
	quit(1 if failures else 0)
