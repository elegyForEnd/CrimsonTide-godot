extends "res://tools/preview_weapon_world_vfx.gd"
## Close review of only the two samples, at one camera scale for all actions.
func run() -> void:
	var out := "res://build/vfx-samples/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size=Vector2i(1440,410); root.content_scale_size=root.size
	for weapon in [600,615]:
		var board := Board.new(); root.add_child(board)
		board.caption="%s · 左：普攻 / 中：重击 / 右：战技 · 实际引擎输出" % Catalog.weapon(weapon).name
		tiles.clear()
		for column in 3:
			var tile := create_tile(weapon,column,board)
			var camera: Camera3D=tile.view.get_camera_3d()
			# Reproject the same physical mount when changing the review camera.
			var old_grip: Dictionary=tile.fx.socket_provider.call(1)
			var points := {}
			for key in ["tip","grip","stroke_tip","stroke_pivot"]:
				var hit: Variant=Plane(Vector3.UP,.62).intersects_ray(camera.project_ray_origin(old_grip[key]),camera.project_ray_normal(old_grip[key]))
				points[key]=hit
			camera.size=2.7; camera.position=Vector3(-.55,7,5.5); camera.look_at(Vector3(-.55,.40,0))
			for key in points: old_grip[key]=camera.unproject_position(points[key])
			old_grip.charge_points=[]
			tile.fx.socket_provider=func(_id): return old_grip
			strike(tile,column==2,column==1)
			var at: float=(.05 if column==0 else .065 if column==1 else .10) if weapon==600 else (.065 if column==0 else .08 if column==1 else .10)
			for i in ceili(at/.01): step(tile,minf(.01,at-i*.01))
			tile.mode=["普攻","蓄力重击","战技"][column]
			tiles.append(tile)
		for frame in 5: board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
		var captured := root.get_texture().get_image()
		captured.save_png(out+"weapon-%d.png" % weapon)
		for column in 3:
			captured.get_region(Rect2i(column*480,54,480,340)).save_png(out+"%d-%s.png" % [weapon,["normal","heavy","art"][column]])
		for tile in tiles: tile.view.queue_free()
		board.queue_free(); await process_frame
	quit()
