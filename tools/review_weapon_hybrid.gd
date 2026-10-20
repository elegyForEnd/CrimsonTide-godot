extends "res://tools/preview_weapon_world_vfx.gd"
func run() -> void:
	var out := "res://build/vfx-hybrid/review/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size=Vector2i(1440,770); root.content_scale_size=root.size
	var selected: Array=range(600,648)+[17,18,19,20]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="): selected=[int(arg.trim_prefix("--weapon="))]
	var report: Array=[]
	if FileAccess.file_exists("res://build/vfx-hybrid/review.json"):
		var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://build/vfx-hybrid/review.json"))
		if saved is Array: report=saved
	for weapon in selected:
		var distant: bool=Catalog.weapon_family(weapon) in [0,3]
		var max_reach := maxf(float(Catalog.weapon(weapon).reach),float(WeaponArts.of(weapon).reach))
		var board := Board.new(); root.add_child(board)
		board.caption="%d %s · 普攻 / 重击 / 战技 · 上：释放 / 下：命中后 · 实际渲染" % [weapon,Catalog.weapon(weapon).name]
		for row in 2:
			for column in 3:
				var tile := create_tile(weapon,column,board)
				tile.at=Vector2(column*480,54+row*350)
				var camera: Camera3D=tile.view.get_camera_3d()
				var socket: Dictionary=tile.fx.socket_provider.call(1)
				var points := {}
				for key in ["tip","grip","stroke_tip","stroke_pivot"]:
					points[key]=Plane(Vector3.UP,.62).intersects_ray(camera.project_ray_origin(socket[key]),camera.project_ray_normal(socket[key]))
				camera.size=maxf(3.4,max_reach*.01*340.0/480.0*1.45) if distant else 3.4
				var focus := (-145+max_reach*.42)*.01 if distant else -.55
				camera.position=Vector3(focus,7,5.5); camera.look_at(Vector3(focus,.4,0))
				for key in points: socket[key]=camera.unproject_position(points[key])
				socket.charge_points=[]
				tile.fx.socket_provider=func(_id): return socket
				strike(tile,column==2,column==1)
				if row==1:
					tile.fx.event({"kind":"impact","p":tile.origin+Vector2(85 if weapon<624 else 180,0),"aim":Vector2.RIGHT,"weapon_index":weapon,"damage":20,"id":1,"enemy_id":1,"vfx_action":["normal","heavy","art"][column]})
				var at: float=(.065 if column==0 else .095 if column==1 else .12)+(.055 if row==1 else 0)
				for i in ceili(at/.005): step(tile,minf(.005,at-i*.005))
				tile.mode=["普攻","蓄力重击","战技"][column]+(" · 接触" if row else " · 释放")
		for frame in 3: board.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out+"weapon-%d.png" % weapon)
		report=report.filter(func(item): return int(item.weapon)!=weapon)
		report.append({"weapon":weapon,"revision":"hybrid-v7-painted-bold-smoke-4","file":"review/weapon-%d.png" % weapon})
		for tile in board.tiles: tile.view.queue_free()
		board.queue_free(); await process_frame
		print("HYBRID REVIEW ",weapon)
	FileAccess.open("res://build/vfx-hybrid/review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()
