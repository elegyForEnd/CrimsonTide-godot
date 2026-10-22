extends "res://tools/preview_weapon_world_vfx.gd"
func run() -> void:
	var out := "res://output/weapon-batch-01/review/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size=Vector2i(1440,770); root.content_scale_size=root.size
	for weapon in [607,608,612,614,617]:
		var board := Board.new(); root.add_child(board)
		board.caption="%d %s · 普攻 / 重击 / 战技 · 上：出刀与地面 / 下：命中 · 原人物精灵" % [weapon,Catalog.weapon(weapon).name]
		for row in 2:
			for column in 3:
				var tile := create_tile(weapon,column,board)
				tile.at=Vector2(column*480,54+row*350)
				var camera: Camera3D=tile.view.get_camera_3d()
				var socket: Dictionary=tile.fx.socket_provider.call(1)
				var points := {}
				for key in ["tip","grip","stroke_tip","stroke_pivot"]:
					points[key]=Plane(Vector3.UP,.62).intersects_ray(camera.project_ray_origin(socket[key]),camera.project_ray_normal(socket[key]))
				camera.size=3.4; camera.position=Vector3(-.55,7,5.5); camera.look_at(Vector3(-.55,.4,0))
				for key in points: socket[key]=camera.unproject_position(points[key])
				socket.charge_points=[]
				tile.fx.socket_provider=func(_id): return socket
				strike(tile,column==2,column==1)
				if row==1: tile.fx.event({"kind":"impact","p":tile.origin+Vector2(85,0),"aim":Vector2.RIGHT,"weapon_index":weapon,"damage":20,"id":1,"enemy_id":1,"vfx_action":["normal","heavy","art"][column]})
				var at: float=.055 if row else (.060 if weapon==607 else .105 if weapon==608 else .17)
				for i in ceili(at/.005): step(tile,minf(.005,at-i*.005))
				tile.mode=["普攻","蓄力重击","战技"][column]+(" · 命中" if row else " · 释放")
		for frame in 3: board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out+"weapon-%d.png" % weapon)
		for tile in board.tiles: tile.view.queue_free()
		board.queue_free(); await process_frame
		print("BATCH REVIEW ",weapon)
	quit()
