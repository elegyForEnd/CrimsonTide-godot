extends SceneTree

class FrameGallery extends Node2D:
	var library: CharacterFrames
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,900),Color("20232f"))
		var font := ThemeDB.fallback_font
		for hero in 3:
			for row in 6:
				for frame in 4:
					var pose: Dictionary=library.attacks[hero][row][frame] if row<3 else library.movement[hero][row-3][frame]
					var at := Vector2(55+hero*480+frame*115,105+row*142)
					draw_set_transform(at)
					draw_texture_rect(pose.texture,pose.rect,false)
					draw_string(font,Vector2(-45,35),"H%d %s %d" % [hero,["sword","heavy","staff","walk","run","dodge"][row],frame],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.content_scale_size=Vector2i(1440,900)
	root.size=Vector2i(1440,900)
	var gallery := FrameGallery.new()
	gallery.library=CharacterFrames.new()
	root.add_child(gallery)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/animation-frames.png")
	print("ANIMATION GALLERY: 72 isolated poses captured")
	quit()
