extends SceneTree

class Stage extends Node2D:
	var camera := Vector2(720,450)
	var offset := Vector2.ZERO
	var session := TideSession.new()
	var library := CharacterFrames.new()
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,900),Color("20232f"))
		for row in 3:
			for column in 4:
				var at := Vector2(170+column*355,170+row*280)
				var direction := Vector2.from_angle(column*PI/2)
				var pose: Dictionary=library.attack_frame(0,1,2)
				draw_set_transform(at,0,Vector2(-1 if direction.x<0 else 1,1))
				draw_texture_rect(pose.texture,pose.rect,false)
				draw_set_transform(Vector2.ZERO)
				draw_arc(at,112,0,TAU,64,Color(0.5,0.5,0.5,0.3),1)
				draw_string(ThemeDB.fallback_font,at+Vector2(-100,130),"Combo %d / direction %d" % [row+1,column],HORIZONTAL_ALIGNMENT_LEFT,-1,17)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	var stage := Stage.new()
	root.add_child(stage)
	var fx := CombatVisuals.new()
	fx.field=stage
	stage.add_child(fx)
	fx.set_process(false)
	for combo in 3:
		for column in 4:
			fx.event({"kind":"strike","weapon":1,"combo":combo,"id":1,"p":Vector2(170+column*355,170+combo*280),"aim":Vector2.from_angle(column*PI/2)})
	fx.stylized.advance(.08)
	fx.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/slash-alignment.png")
	print("SLASH ALIGNMENT: three combo stages x four directions rendered")
	stage.session.free()
	quit()
