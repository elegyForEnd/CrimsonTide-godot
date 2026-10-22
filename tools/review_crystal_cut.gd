extends "res://tools/preview_weapon_world_vfx.gd"
func run() -> void:
	var out := "res://build/vfx-crystal/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size=Vector2i(1920,410); root.content_scale_size=root.size
	var board := Board.new(); root.add_child(board)
	board.caption="晶刃试作 · 战技 · 55 / 100 / 180 / 300 ms · 引擎实际输出"
	for column in 4:
		var tile := create_tile(600,column,board)
		var camera: Camera3D=tile.view.get_camera_3d()
		var socket: Dictionary=tile.fx.socket_provider.call(1)
		var points := {}
		for key in ["tip","grip","stroke_tip","stroke_pivot"]:
			points[key]=Plane(Vector3.UP,.62).intersects_ray(camera.project_ray_origin(socket[key]),camera.project_ray_normal(socket[key]))
		camera.size=3.1; camera.position=Vector3(-.7,7,5.5); camera.look_at(Vector3(-.7,.4,0))
		for key in points: socket[key]=camera.unproject_position(points[key])
		socket.charge_points=[]
		tile.fx.socket_provider=func(_id): return socket
		strike(tile,true)
		tile.fx.event({"kind":"impact","p":tile.origin+Vector2(135,0),"aim":Vector2.RIGHT,"weapon_index":600,"damage":20,"id":1,"enemy_id":1,"vfx_action":"art"})
		var age: float=[.055,.10,.18,.30][column]
		for i in ceili(age/.005): step(tile,minf(.005,age-i*.005))
		tile.mode="%d ms" % roundi(age*1000)
	for frame in 4: board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out+"phases.png")
	board.queue_free()
	for tile in board.tiles: tile.view.queue_free()
	await process_frame; quit()
