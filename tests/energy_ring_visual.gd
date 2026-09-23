extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(400,400)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var energy := preload("res://scripts/energy_bursts.gd").new()
	viewport.add_child(energy)
	energy.spawn(Vector2(200,200),Vector2.ONE*360,Color("c8a8ff"),2,1,0,.55)
	energy.advance(.35)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var safe_alpha := 0.0
	var effect_alpha := 0.0
	for y in range(400):
		for x in range(400):
			var distance := Vector2(x-200,y-200).length()
			if distance<90: safe_alpha=maxf(safe_alpha,image.get_pixel(x,y).a)
			if distance>110 and distance<170: effect_alpha=maxf(effect_alpha,image.get_pixel(x,y).a)
	image.save_png("res://build/energy-ring-alpha.png")
	var passed := safe_alpha<.005 and effect_alpha>.05
	print("RING VISUAL: safe alpha=",safe_alpha," annulus alpha=",effect_alpha," PASS=" ,passed)
	viewport.queue_free()
	await process_frame
	quit(0 if passed else 1)
