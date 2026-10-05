extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-reward-semantics-visual.json"
	root.add_child(app); await process_frame
	var s=app.session
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729); s.set_physics_process(false)
	s.enemies.clear(); s.roguelike.combat.reset()
	var p: Dictionary=s.players[1]
	p.rogue_selection={}
	var at: Vector2=p.p+Vector2(80,0)
	s.raid.reward_chest={"p":at,"tier":3,"opened":true,"opened_at":s.elapsed-.25}
	s.raid.reward_drops=[{"id":101,"p":at+Vector2(-60,80),"born":s.elapsed-2.0,"delay":.3,"tier":3,"category":"gear","offer":{}},{"id":102,"p":at+Vector2(60,80),"born":s.elapsed-2.0,"delay":.3,"tier":2,"category":"weapon","offer":{}}]
	await create_timer(.35).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/reward-semantics.png")
	app.queue_free(); await process_frame; await process_frame
	print("REWARD SEMANTICS VISUAL PASS"); quit()
