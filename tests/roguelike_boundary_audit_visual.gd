extends SceneTree

class AuditCanvas extends Node2D:
	var entries: Array=[]
	func _draw() -> void:
		for i in entries.size():
			var entry: Dictionary=entries[i]
			var map=entry.map
			var offset := Vector2(0,i*480)
			var factor: float=1440.0/map.width
			draw_texture_rect(entry.texture,Rect2(offset,Vector2(1440,480)),false)
			var outline := PackedVector2Array()
			for p in map.floor_polygon: outline.append(offset+p*factor)
			outline.append(outline[0])
			draw_polyline(outline,Color(1,.85,.15),2,true)
			for x in range(330,int(map.width*.8),60):
				var start := Vector2(x,map.lane_center(x))
				if map.blocked(start,15): continue
				for direction in [-1,1]:
					var stopped: Vector2=map.move(start,Vector2(0,direction*map.extent.y),15)
					draw_circle(offset+stopped*factor,2,Color(.2,1,.6))
			for index in 2: draw_circle(offset+map.exit_position(index)*factor,5,Color(.4,.8,1))
			draw_string(ThemeDB.fallback_font,offset+Vector2(12,25),entry.label,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,2400)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := AuditCanvas.new()
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	viewport.add_child(canvas)
	DirAccess.make_dir_recursive_absolute("res://build/boundary-audit")
	for floor_index in 5:
		canvas.entries.clear()
		for area in range(1,6):
			var map=preload("res://scripts/rogue_map.gd").new()
			map.generate(1729)
			map.configure(floor_index,area,true)
			var path := "res://assets/rogue/regions/f%d-a%d-original-wide-3x.png" % [floor_index+1,area]
			canvas.entries.append({"map":map,"texture":load(path),"label":"f%d-a%d" % [floor_index+1,area]})
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://build/boundary-audit/f%d.png" % (floor_index+1))
	viewport.queue_free()
	await process_frame
	print("ALL 25 BOUNDARY AUDIT IMAGES SAVED")
	quit()
