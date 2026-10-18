extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + file + ".png")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var profile := Profile.new()
	profile.path = "user://test-combat-text-hunt.json"
	var screen = preload("res://scripts/hunt/hunt_screen.gd").new()
	root.add_child(screen)
	screen.set_context(profile, null)
	screen.show_briefing()
	await process_frame
	screen.start_run(0)
	await process_frame
	var run = screen.run
	run.debug_spawn_enemy("scavenger")
	var enemy_uid := str(run.active_enemies()[0].uid)
	run.start_combat(enemy_uid)
	await process_frame
	run.combat.hp = 999.0
	run.attack_cd = 0.0
	run.stamina = 100.0
	screen.combat_attack.pressed.emit()
	await process_frame
	# A known heal item so the player-side green number is exercised too.
	run.hp = maxf(1.0, run.total_max_hp() - 20.0)
	run.add_item("bandage", 1)
	var index := -1
	for i in run.bag.size():
		if str(run.bag[i].kind) == "bandage":
			index = i
			break
	if index >= 0:
		run.use_item(index)
	await create_timer(0.12).timeout
	await capture("combat-text-hunt")
	print("COMBAT TEXT HUNT: 1 capture completed")
	quit()
