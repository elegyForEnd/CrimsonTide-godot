extends SceneTree
## Real renderer captures; no audio/autoload dependencies from the main menu.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1440,900)
	var session := TideSession.new()
	root.add_child(session)
	session.solo({"hero":0})
	session.launch(false,1729)
	session.set_physics_process(false)
	session.enemies.clear()
	var field := Battlefield.new()
	field.session=session
	root.add_child(field)
	for i in [0,1,5,6,9,10,12,15]:
		var at: Vector2=session.ruins.sites[i].p+Vector2(0,80)
		session.players[1].p=at
		field.camera=at
		field.smooth_positions.clear()
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/asset-region-%d.png" % i)
	var bridge := Vector2(Ruins.river_x(2400),2400)
	session.players[1].p=bridge
	field.camera=bridge
	field.smooth_positions.clear()
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/asset-bridge.png")
	var camp: Vector2=session.ruins.sites[2].p
	session.players[1].p=camp+Vector2(0,60)
	field.camera=camp
	field.smooth_positions.clear()
	session.ruins.chests=[
		{"p":camp+Vector2(-130,0),"open":false,"items":[{"kind":"heal","count":1}],"cache_tier":1},
		{"p":camp,"open":true,"items":[{"kind":"heal","count":1}],"cache_tier":4},
		{"p":camp+Vector2(130,0),"open":true,"items":[],"cache_tier":0}]
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/asset-chests.png")
	session.players[1].p=session.CITY_GATE
	session.travel_city()
	session.enemies.clear()
	session.players[1].p=Vector2(1400,680)
	field.camera=session.players[1].p
	field.smooth_positions.clear()
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/asset-city.png")
	field.queue_free()
	session.queue_free()
	await process_frame
	print("SCENE ASSET VISUAL: eight landmarks, bridge, chest states and royal hall captured")
	quit()
