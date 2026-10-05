extends SceneTree
## Standalone capture of the enemy danger pass, independent of the full game
## scene so the paint can be judged on its own: an identity ground transform,
## no projection, no scenery, and every species at a known windup progress.
##
## Output: build/attack-telegraphs.png (all species) and
## build/attack-telegraph-timing.png (one species through the whole windup).
const Telegraph = preload("res://scripts/attack_telegraph.gd")
const Ecology = preload("res://scripts/ecology.gd")
const STAGES := [0.12, 0.42, 0.70, 0.96]
const CELL := Vector2(288.0, 210.0)
const SCALE := 0.34

class Board extends Node2D:
	var telegraph = preload("res://scripts/attack_telegraph.gd").new()
	var font: Font
	var grid_mode := true
	var solo_kind := 13

	func _draw() -> void:
		# Night field tone, close enough to the real biome palette to judge contrast.
		draw_rect(Rect2(Vector2.ZERO, Vector2(1600, 900)), Color("131720"))
		for i in 40:
			var at := Vector2(fmod(float(i) * 137.0, 1600.0), fmod(float(i) * 211.0, 900.0))
			draw_circle(at, 1.4, Color(1, 0.34, 0.42, 0.22))
		draw_string(font, Vector2(18, 30), "敌人攻击预警 · DANGER PASS" + ("  (全种类 / 各阶段混合)" if grid_mode else "  (提灯刽子手 · 完整前摇)"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffd9e2"))
		for index in (17 if grid_mode else 4):
			var kind := index % 17 if grid_mode else solo_kind
			var stage: float = STAGES[index % 4] if grid_mode else STAGES[index]
			var cell := Vector2(float(index % 5) * CELL.x + 8.0, float(index / 5) * CELL.y + 46.0)
			var origin := cell + Vector2(96.0, 150.0)
			var ground := Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, origin)
			draw_set_transform_matrix(ground)
			draw_rect(Rect2(Vector2(-96.0, -150.0) / SCALE, CELL / SCALE), Color(0.07, 0.08, 0.11, 0.85))
			draw_rect(Rect2(Vector2(-96.0, -150.0) / SCALE, CELL / SCALE), Color(0.24, 0.26, 0.34, 0.7), false, 2.0)
			var enemy := {"p": Vector2(-62.0, 34.0), "attack_aim": Vector2(0.94, 0.34).normalized(),
				"attack_total": 1.4, "attack_time": 1.4 - Telegraph.windup(kind) * stage,
				"attack_point": Vector2(-62.0, 34.0) + Vector2(0.94, 0.34).normalized() * 120.0,
				"attack_released": false}
			telegraph.paint(self, ground, font, enemy, kind, 1.7)
			draw_circle(enemy.p, 14.0, Color("2a2f3d"))
			draw_set_transform_matrix(Transform2D.IDENTITY)
			draw_string(font, cell + Vector2(10.0, 20.0), "%d %s  p=%.2f" % [kind, EnemyFrames.NAMES[kind], stage],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Telegraph.tint(kind))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var board := Board.new()
	board.font = load("res://assets/NotoSansSC.ttf")
	root.add_child(board)
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/attack-telegraphs.png")
	board.grid_mode = false
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/attack-telegraph-timing.png")
	report()
	board.queue_free()
	await process_frame
	await in_game()
	quit()

## The same danger pass inside the real 2.5D field, so the ground projection,
## the enemy sprites and the paint are judged together.
func in_game() -> void:
	var packed: Resource = load("res://scenes/main.tscn")
	if packed == null:
		print("TELEGRAPH VISUAL: main scene unavailable, in-game capture skipped")
		return
	var app: Node = packed.instantiate()
	root.add_child(app)
	app.profile.path = "user://test-attack-telegraph.json"
	app.session.solo({"hero": 0})
	app.session.launch(false, 1729)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	var centre := Vector2(1500, 1200)
	var player: Dictionary = app.session.players[1]
	player.p = centre
	app.field.camera = centre
	var progress := [0.20, 0.50, 0.78, 0.95]
	for kind in 17:
		var slot := Vector2(-660.0 + float(kind % 9) * 165.0, -170.0 + float(kind / 9) * 320.0)
		app.session.spawn_enemy(centre + slot, kind)
		var e: Dictionary = app.session.enemies[-1]
		e.p = centre + slot
		e.facing = 1.0
		e.attack_total = Ecology.WINDUP[kind] + 0.6
		e.attack_time = e.attack_total - Ecology.WINDUP[kind] * float(progress[kind % 4])
		e.attack_aim = Vector2.DOWN
		e["attack_point"] = e.p + Vector2(0, 150)
		e.attack_released = false
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/attack-telegraph-field.png")
	for e in app.session.enemies:
		e.attack_released = true
		e.attack_time = e.attack_total - Ecology.WINDUP[int(e.type)] - 0.07
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/attack-telegraph-release.png")
	app.queue_free()
	await process_frame
	print("TELEGRAPH VISUAL: in-game field and release frames captured")

## The readability contract: every danger hue has to stay saturated and bright
## enough to separate from a desaturated night field, and the burst radius has
## to stay a real footprint rather than a decoration.
func report() -> void:
	var dull := 0
	for kind in Telegraph.TINT.size():
		var colour: Color = Telegraph.tint(kind)
		var value := maxf(colour.r, maxf(colour.g, colour.b))
		var least := minf(colour.r, minf(colour.g, colour.b))
		var saturation := 0.0 if value <= 0.0 else (value - least) / value
		if saturation < 0.55 or value < 0.8: dull += 1
		if Telegraph.footprint(kind) < 40.0: dull += 1
	print("TELEGRAPH VISUAL: %d species captured over %d windup stages" % [Telegraph.TINT.size(), STAGES.size()])
	print("TELEGRAPH VISUAL: danger hues below the saturation/brightness floor: %d" % dull)
