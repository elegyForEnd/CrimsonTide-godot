extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + file + ".png")

func run() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://test-combat-text-scene.json"
	app.session.solo({"hero": 0})
	app.session.launch(false, 1729)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	var player: Dictionary = app.session.players[1]
	player.attack = 0.0
	player.swing_time = 0.0
	player.invuln = 0.0
	player.hp = player.max_hp
	app.field.camera = player.p
	var enemy := {"id": 900, "p": player.p + Vector2(130, 0), "hp": 500.0, "max_hp": 500.0, "type": 0, "cd": 99.0, "last": 1, "wander": Vector2.ZERO, "facing": -1.0, "motion_phase": 0.0, "moving": false, "attack_time": 0.0, "attack_total": 0.0, "attack_released": false, "attack_aim": Vector2.LEFT, "sequence": 0, "phase": 1, "flash": 0.0}
	app.session.enemies.append(enemy)
	app.session.damage_enemy(enemy, 128.0, 1, Vector2.RIGHT, 12.0)
	app.session.damage_enemy(enemy, 246.0, 1, Vector2.RIGHT, 48.0)
	app.session.hurt(player, 13.0)
	player.hp = player.max_hp - 20.0
	app.session.apply_medkit(player)
	await create_timer(0.12).timeout
	await capture("combat-text-scene")
	print("COMBAT TEXT SCENE: 1 capture completed")
	quit()
