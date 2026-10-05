extends SceneTree

class RegistrationGallery extends Node2D:
	var library := CharacterFrames.new()
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,620),Color("252832"))
		for row in 2:
			for frame in 8:
				var at := Vector2(65+frame*178,210+row*290)
				var pose: Dictionary=library.movement[0][0][frame] if row==0 else library.attacks[0][0][frame]
				draw_set_transform(at,0,Vector2(1.8,1.8))
				draw_texture_rect(pose.texture,pose.rect,false)
				var origin := CharacterMetrics.FOOT_OFFSET
				draw_line(origin-Vector2(10,0),origin+Vector2(10,0),Color.CYAN,0.7)
				draw_line(origin-Vector2(0,5),origin+Vector2(0,5),Color.CYAN,0.7)
				draw_set_transform(Vector2.ZERO)
				draw_string(ThemeDB.fallback_font,at+Vector2(-20,65),"%s %d" % ["walk" if row==0 else "sword",frame+1],HORIZONTAL_ALIGNMENT_LEFT,-1,15)
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	root.hide()
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1440,620)
	root.add_child(RegistrationGallery.new())
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/hero-animation-v4/registration-fixed.png")
	quit()
