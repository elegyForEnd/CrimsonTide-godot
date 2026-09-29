extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/camp-occlusion-" + name + ".png")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var screen = preload("res://scripts/camp_screen.gd").new()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var site = screen.site
	site.set_process(false)
	screen.hud.hide()
	screen.marker_layer.hide()
	screen.flash.color = Color.TRANSPARENT
	var building = site.prop("halloween/crypt", Vector2(800, 800), Vector3(0, 310, 0))
	var entry: Dictionary = site.occluders.back()
	var neighbor = site.prop("halloween/crypt", Vector2(1400, 800), Vector3(0, 310, 0))
	var other: Dictionary = site.occluders.back()
	site.hero_at = Vector2(800, 680)
	site.refresh_sprites()
	site.set_camera_focus(Vector2(800, 700))
	site.camp_camera.size = 6
	check(site.occludes_actor(entry), "building behind-player view is detected")
	check(not site.occludes_actor(other), "nearby non-occluding building remains solid")
	await capture("before")
	site.update_occlusion(0.1)
	check(entry.opacity < 1.0 and entry.opacity > 0.25, "fade transitions gradually")
	site.update_occlusion(0.2)
	check(is_equal_approx(entry.opacity, 0.25), "occluder reaches 25 percent opacity")
	check(is_equal_approx(other.opacity, 1.0), "shared model neighbor stays opaque")
	check(entry.parts[0].faded[0] != entry.parts[0].materials[0], "fade uses a separate material")
	check(entry.parts[0].faded[0].get_shader_parameter("occlusion_opacity") == 0.25, "render material receives opacity")
	await capture("after")
	site.hero_at = Vector2(800, 800)
	check(site.occludes_actor(entry), "actor inside building also triggers fade")
	site.hero_at = Vector2(800, 1250)
	check(not site.occludes_actor(entry), "building behind actor does not trigger fade")
	site.update_occlusion(0.3)
	check(is_equal_approx(entry.opacity, 1.0), "building restores opacity after actor leaves")
	check(entry.parts[0].mesh.get_active_material(0) == entry.parts[0].materials[0], "original material restored")
	site.refresh_sprites()
	await capture("restored")
	print("CAMP OCCLUSION: ", checks, " checks, ", failures, " failures")
	screen.queue_free()
	await process_frame
	quit(1 if failures else 0)
