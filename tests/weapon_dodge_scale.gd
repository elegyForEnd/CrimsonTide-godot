extends SceneTree
var checks:=0
var failures:=0
var library=preload("res://scripts/weapon_atlas_frames.gd").new()
var frames=preload("res://scripts/character_frames.gd").new()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for key in library.manifest:
		var atlas: Dictionary=library.manifest[key]
		if not atlas.states.has("dodge"): continue
		var hero:=int(key.get_slice("/",0)); var weapon:=int(key.get_slice("/",1))
		var standing: float=frames.walk_height(hero)
		var idle: Dictionary=library.frame(hero,weapon,"idle",0,standing)
		var idle_scale: float=idle.rect.size.y/idle.texture.get_height()
		var shared_scale:=-1.0
		for i in atlas.states.dodge.size():
			var pose: Dictionary=library.frame(hero,weapon,"dodge",i,standing)
			var scale: float=pose.rect.size.y/pose.texture.get_height()
			check(scale<=idle_scale+.00001,"dodge does not enlarge crouched actor "+key)
			if shared_scale<0: shared_scale=scale
			check(absf(shared_scale-scale)<.00001,"all dodge frames retain one body scale "+key)
			var entry: Dictionary=atlas.states.dodge[i]
			var ground: Vector2=pose.rect.position+Vector2(entry.pivot[0],entry.pivot[1])*scale
			check(ground.distance_to(CharacterMetrics.FOOT_OFFSET)<.0001,"rescale preserves grounded pivot "+key)
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1200,800)
		var gallery:=Node2D.new(); root.add_child(gallery)
		gallery.draw.connect(func():
			gallery.draw_rect(Rect2(0,0,1200,800),Color("192330"))
			var font:=ThemeDB.fallback_font
			for row in 6:
				var hero: int=row/2
				var weapon: int=600 if row%2==0 else 636 if hero==1 else 612
				gallery.draw_string(font,Vector2(20,60+row*120),"%d / %d" % [hero,weapon],HORIZONTAL_ALIGNMENT_LEFT,-1,18)
				for col in 5:
					var pose: Dictionary=library.frame(hero,weapon,"idle" if col==0 else "dodge",maxi(0,col-1),frames.walk_height(hero))
					var at:=Vector2(235+col*205,100+row*120)
					var rect: Rect2=pose.rect
					rect.position=(rect.position-CharacterMetrics.FOOT_OFFSET)*1.3+at; rect.size*=1.3
					gallery.draw_line(at-Vector2(70,0),at+Vector2(70,0),Color("69798c"))
					gallery.draw_texture_rect(pose.texture,rect,false)
					gallery.draw_string(font,at+Vector2(-38,23),"idle" if col==0 else "dodge %d" % col,HORIZONTAL_ALIGNMENT_LEFT,-1,15)
		)
		for i in 3: await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://output/weapon-dodge-scale.png")
		gallery.queue_free(); await process_frame
	print("WEAPON_DODGE_SCALE %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
