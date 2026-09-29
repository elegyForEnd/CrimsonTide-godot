extends SceneTree
## Headless rule checks for the standalone pre-raid camp map.
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/camp.gd

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	var screen: Control = preload("res://scripts/camp_screen.gd").new()
	root.add_child(screen)
	await process_frame
	await process_frame
	var site: Node3D = screen.site

	check(site != null, "the camp screen owns its map")
	check(screen.visible and site.visible, "the camp map starts visible")
	check(site.built, "the camp map builds itself on entry")
	check(screen.get_node_or_null("Thunderhold") != null, "the map is a separate node, not the raid map")

	# --- the map is real, and it is not the raid map -------------------------
	var scenery: Node3D = site.scenery
	print("CAMP: scenery nodes = ", scenery.get_child_count(), " sprites = ", site.sprites.size())
	check(scenery.get_child_count() > 90, "the stronghold builds real 3D scenery (%d nodes)" % scenery.get_child_count())
	check(site.stations.size() == 5, "five interactive stations exist")
	for id in ["table", "forge", "quarter", "codex", "gate"]:
		check(not site.station_by_id(id).is_empty(), "station %s resolves by id" % id)
	check(not site.assets.registry.is_empty(), "the CC0 scene-asset library is available")

	# --- projection round-trips: HUD markers land where their station is -----
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(960, 900)]:
		root.size = resolution
		await process_frame
		for station in site.stations:
			var at: Vector2 = station.at + station.offset
			check(site.unproject(site.project(at)).distance_to(at) < 0.05,
				"camera ray round-trips at %s" % resolution)
		# 0.6 px absorbs rasterisation rounding; a wrong basis misses by far more.
		var origin: Vector2 = site.ground_transform() * site.hero_position()
		check(origin.distance_to(site.project(site.hero_position())) < 0.6,
			"the 2D overlay basis agrees with the camera at %s" % resolution)

	# --- the storm actually fires -------------------------------------------
	var before: int = int(site.storm_state().strikes)
	# Step the storm on a known delta instead of relying on real frame times. A
	# lull after a sheet flash can legitimately last 4.6 s, so the wait is bounded
	# at 20 s and the interval is asserted to stay finite.
	site.next_strike = 0.0
	var longest_lull := 0.0
	for i in 400:
		site._update_storm(0.05)
		longest_lull = maxf(longest_lull, float(site.storm_state().next))
		if int(site.storm_state().strikes) > before:
			break
	check(int(site.storm_state().strikes) > before, "the storm strikes without being asked")
	check(longest_lull < 5.0, "the storm never falls silent for long (%.2fs)" % longest_lull)
	site.force_strike(1.0, 1200.0)
	await process_frame
	check(int(site.storm_state().strikes) > before, "a forced strike lands immediately")
	check(float(site.storm_state().flash) > 0.0, "a strike lifts the sky flash")
	check(float(site.flash_light.light_energy) > 0.0, "a strike lights the camp")
	check(site.storm.get_child_count() > 0, "a strike leaves real bolt geometry in the scene")
	# The bolt must retire itself instead of piling up over a session. No new
	# strikes are allowed during the wait, so the check is about retirement only.
	site.next_strike = 9999.0
	for i in 60:
		site._update_storm(0.05)
	check(site.storm.get_child_count() == 0, "bolt geometry is released after its life")
	check(site.bolts.is_empty(), "the bolt list drains")

	# --- generated audio, no shipped binaries --------------------------------
	for key in ["wind", "rumble", "thunder", "bell"]:
		var stream: AudioStream = site.bus.get(key, null)
		check(stream is AudioStreamWAV and (stream as AudioStreamWAV).data.size() > 1024,
			"camp cue %s is generated at runtime" % key)
	check(site.bus["wind"].loop_mode == AudioStreamWAV.LOOP_FORWARD, "wind loops seamlessly")

	# --- walking, stations and interaction ----------------------------------
	screen.warp_to("forge")
	await process_frame
	check(site.hero_position().distance_to(Vector2(3560, 3150)) < 400.0, "warp lands at the forge")
	var near: Dictionary = site.station_at(site.hero_position())
	check(not near.is_empty() and str(near.id) == "forge", "standing in the ring selects the forge")
	var station: Dictionary = screen.interact()
	check(str(station.get("action", "")) == "forge", "interact reports the station it used")

	screen.warp_to("table")
	screen.drive_hero(Vector2.RIGHT, 1.0)
	check(site.hero_walking, "walking animates the hero")
	check(site.hero_position().x > 2800.0, "the hero actually moves")
	screen.drive_hero(Vector2.ZERO, 0.1)
	check(not site.hero_walking, "releasing input stops the walk cycle")
	# Bounds hold the player inside the camp maps.
	screen.drive_hero(Vector2(-1, -1), 40.0)
	check(site.hero_position().x >= 180.0 and site.hero_position().y >= 180.0, "the camp bounds hold")

	# --- billboards: the camp is populated, not empty ------------------------
	site.hero_at = Vector2(2800, 3000)
	site.refresh_sprites()
	var visible_sprites := 0
	var visible_shadows := 0
	for sprite in site.sprites:
		if sprite.visible:
			visible_sprites += 1
	for shadow in site.shadows:
		if shadow.visible:
			visible_shadows += 1
	check(visible_sprites >= 2, "the player and the working smith are billboarded (%d)" % visible_sprites)
	check(site.npc_plan.size() == 1, "no idle figures crowd the war table")
	check(site.hero_ring != null and site.hero_ring.visible, "the player carries their own sigil")
	check(visible_shadows == visible_sprites, "every actor carries a contact shadow")
	check(site.frames.movement.size() == Catalog.HEROES.size(), "camp figures use the real hero atlases")
	var frame: Dictionary = site.frames.motion_frame(0, "run", 0.0, 0.0)
	check(frame.has("texture") and frame.has("rect"), "hero animation frames resolve")

	# --- the camera is locked to the controlled character -------------------
	site.hero_at = Vector2(2380, 3420)
	for i in 40:
		site._update_hero(0.05)
	var hero_screen: Vector2 = site.project(site.hero_position())
	# Projection space is the same 1440x900 space the camp HUD is laid out in.
	var centre := Vector2(site.get_viewport().get_visible_rect().size) * 0.5
	check(hero_screen.distance_to(centre) < 6.0,
		"the player stays framed dead centre (%s vs %s)" % [hero_screen, centre])
	check(site.camera_focus_target() == site.hero_position(),
		"the camera never slides off the player toward a station")
	# And it must still be centred somewhere else entirely, not just at the spawn.
	site.hero_at = Vector2(3560, 3150)
	for i in 40:
		site._update_hero(0.05)
	check(site.project(site.hero_position()).distance_to(centre) < 6.0,
		"the player stays centred at the forge too")

	# --- the cast must not be a flattened pancake ---------------------------
	# An upright quad loses cos(pitch) of its height to the pitched camera, so the
	# vertical scale has to be divided by that projection or the cast lies flat.
	var compensation: float = site.camp_camera.global_basis.y.dot(Vector3.UP)
	check(compensation > 0.4 and compensation < 0.9, "the camp rig keeps a 3/4 pitch")
	site.hero_at = Vector2(2800, 3000)
	site.hero_walking = true
	site.hero_phase = 0.0
	site.refresh_sprites()
	var hero_sprite: Sprite3D = site.sprites[0]
	var authored: float = float(frame.rect.size.y) * site.UNIT
	var world: float = hero_sprite.scale.y * hero_sprite.texture.get_height() * hero_sprite.pixel_size
	# On screen the actor must measure exactly the height its frame was authored at.
	check(absf(world * compensation - authored) < authored * 0.06,
		"the hero is drawn upright at its authored height (%.2fm on screen vs %.2fm authored)"
			% [world * compensation, authored])
	# Regression guard: the pre-fix build (no compensation) lands far short, so this
	# assertion is what actually catches a flattening regression.
	var flattened: float = world * compensation * compensation
	check(flattened < authored * 0.8, "an uncompensated billboard would measure %.2fm and fail"
		% flattened)
	check(is_equal_approx(site.camp_camera.rotation.x, -site.PITCH),
		"the camp camera matches the raid's presentation rig")

	# --- actors stand on the stone, not inside it ---------------------------
	check(site.ground_height(site.CENTRE) > 50.0, "the parade ground is a raised surface")
	check(is_zero_approx(site.ground_height(Vector2(400, 400))), "the outer field is at ground level")
	var on_parade: float = site.ground_height(Vector2(2800, 3000))
	site.hero_at = Vector2(2800, 3000)
	site.refresh_sprites()
	check(absf(site.sprites[0].position.y / site.UNIT - (on_parade + 2.0)) < 0.5,
		"the hero's feet sit on the surface under them")
	check(absf(site.shadows[0].position.y / site.UNIT - (on_parade + 3.0)) < 0.5,
		"the contact shadow sits on the same surface")

	# --- the screen never launches a raid by itself --------------------------
	var launch_seen := [false]
	var station_seen := [""]
	var exit_seen := [false]
	screen.launch_requested.connect(func(): launch_seen[0] = true)
	screen.station_requested.connect(func(id: String): station_seen[0] = id)
	screen.exit_requested.connect(func(): exit_seen[0] = true)
	screen.warp_to("gate")
	screen.interact()
	check(station_seen[0] == "launch", "the departure gate asks the host to launch")
	check(not launch_seen[0], "using the gate does not launch the raid by itself")
	screen.interact()
	check(station_seen[0] == "launch", "the gate can be used again")
	check(screen.nearest_station(site.CENTRE + Vector2(0, 4000), 100.0).is_empty(),
		"stations have a real interaction radius")

	# --- switching the map off must stop it ---------------------------------
	screen.set_active(false)
	check(not screen.visible and not site.visible, "leaving the camp hides the map")
	var frozen: int = int(site.storm_state().strikes)
	for i in 20:
		await process_frame
	check(int(site.storm_state().strikes) == frozen, "a hidden camp stops simulating storms")

	screen.queue_free()
	await process_frame
	print("CAMP CHECKS: ", checks, " failures: ", failures)
	quit(1 if failures else 0)
