extends SceneTree
const Idle = preload("res://scripts/character_idle.gd")
class Preview extends Node2D:
	var frames := CharacterFrames.new()
	var seconds := .0
	var right := true
	var meshes: Array=[]
	const Idle = preload("res://scripts/character_idle.gd")
	func _draw() -> void:
		meshes.clear()
		draw_rect(Rect2(0,0,1280,720),Color("282732"))
		for hero in 4:
			for col in 7:
				var weapon: int=[17,1,12,13,2,15,18][col] if hero<2 else [19,14,16,3,6,11,20][col]
				var pose := frames.held_idle_frame(hero,weapon,seconds)
				var side: float=float(pose.get("hand_side",1.0))
				var data := Idle.geometry(pose,weapon,seconds,1.0,side)
				var at := Vector2(100+col*178,145+hero*170)
				draw_set_transform(at,0,Vector2(1 if right else -1,1)*1.25)
				meshes.append(Idle.mesh(data))
				draw_mesh(meshes.back(),data.texture)
				draw_set_transform(Vector2.ZERO)
				draw_line(at+Vector2(-40,20),at+Vector2(40,20),Color("5c606c"),1)
				draw_string(ThemeDB.fallback_font,at+Vector2(-70,47),Catalog.weapon_name(weapon),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var preview := Preview.new(); root.add_child(preview)
	for i in 3:
		preview.seconds=[.0,.9,3.0][i]; preview.right=i<2; preview.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/character-idle-%d.png" % i)
	preview.queue_free(); await process_frame
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-character-idle-visual.json"
	root.add_child(app); await process_frame
	var s=app.session
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1737); s.set_physics_process(false)
	s.enemies.clear(); s.roguelike.combat.reset()
	var p: Dictionary=s.players[1]
	p.rogue_selection={}; p.weapon=17; p.motion="idle"; p.swing_time=0; p.cast_time=0; p.height=0
	await create_timer(.9).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/character-idle-game.png")
	p.weapon=614; p.hero=1
	p.equipped.weapon={"kind":"weapon","weapon":614,"tier":1,"build_id":"W015"}
	await create_timer(.9).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/character-idle-equipped.png")
	app.queue_free(); await process_frame; await process_frame
	print("CHARACTER IDLE VISUAL PASS: 28 poses, both facings, live game")
	quit()
