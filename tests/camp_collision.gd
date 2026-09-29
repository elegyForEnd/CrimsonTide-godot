extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(1280, 800)
	var screen = preload("res://scripts/camp_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var site = screen.site
	screen.set_process(false)
	site.set_process(false)
	site.next_strike = 9999
	for station in site.stations:
		screen.warp_to(station.id)
		check(site.is_walkable(site.hero_at), "safe arrival: " + str(station.id))
		check(site.station_at(site.hero_at).get("id", "") == station.id, "arrival remains in interaction range: " + str(station.id))
	check(not site.is_walkable(site.CENTRE), "table blocks movement")
	var start: Vector2 = site.CENTRE + Vector2(450, 0)
	var stopped: Vector2 = site.move_actor(start, Vector2(-900, 0))
	check(stopped.x > site.CENTRE.x + 215, "large movement cannot tunnel through table")
	check(site.is_walkable(stopped), "collision leaves actor outside obstacle")
	site.hero_at = stopped
	screen.drive_hero(Vector2.LEFT, 1.0)
	check(site.hero_at.is_equal_approx(stopped), "pushing against obstacle does not move hero")
	check(site.hero_walking, "blocked directional input keeps walking animation active")
	var phase: float = site.hero_phase
	site._update_hero(0.1)
	check(site.hero_phase > phase, "blocked walking animation continues advancing")
	screen.drive_hero(Vector2.ZERO, 0.1)
	check(not site.hero_walking, "releasing directional input stops walking animation")
	check(is_equal_approx(site.ground_height(Vector2(3280, 2920)), 58.0), "chamfer corner is not an invisible raised floor")
	site.hero_at = site.SPAWN
	site.hero_facing = -1
	site.refresh_sprites()
	check(site.sprites[0].flip_h, "left input mirrors hero")
	site.hero_facing = 1
	site.refresh_sprites()
	check(not site.sprites[0].flip_h, "right input restores hero")
	check(site.shadows[0].scale.x < 1, "contact shadow is under one metre")
	for hero in Catalog.HEROES.size():
		site.hero = hero
		site.hero_walking = true
		site.hero_phase = 2
		site.refresh_sprites()
		check(site.sprites[0].texture == site.frames.motion_frame(hero, "run", 2, 0).texture, "walking uses run row")
	if DisplayServer.get_name() != "headless":
		screen.flash.color = Color.TRANSPARENT
		screen.hud.hide()
		screen.marker_layer.hide()
		site.hero = 0
		site.hero_walking = false
		site.hero_phase = 0
		site.hero_at = site.SPAWN
		site.refresh_sprites()
		site.set_camera_focus(site.hero_at + Vector2(0, -85))
		site.camp_camera.size = 3.8
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/camp-character-fixed.png")
	print("CAMP COLLISION: ", checks, " checks, ", failures, " failures")
	screen.queue_free()
	await process_frame
	quit(1 if failures else 0)
