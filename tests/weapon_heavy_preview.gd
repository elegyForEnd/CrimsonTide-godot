extends SceneTree
const FX=preload("res://scripts/stylized_vfx.gd")
class Board extends Node2D:
	var frames := CharacterFrames.new()
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1500,800),Color("172230"))
		for i in 12:
			var at := Vector2(125+(i%6)*250,255+(i/6)*380)
			var pose := frames.weapon_atlases.frame(0,612+i,"attack",2,110)
			draw_set_transform(at)
			draw_texture_rect(pose.texture,pose.rect,false,Color.WHITE)
			draw_set_transform(Vector2.ZERO)
			draw_string(font,at+Vector2(-100,90),Catalog.weapon(612+i).name,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1500,800); root.content_scale_size=root.size
	root.add_child(Board.new())
	for i in 12:
		var fx := FX.new(); root.add_child(fx)
		fx.position=Vector2(125+(i%6)*250,255+(i/6)*380)
		fx.event({"kind":"strike","p":Vector2.ZERO,"aim":Vector2.RIGHT,"weapon_index":612+i,"weapon":2,"combo":0,"reach":70})
		fx.set_process(false)
		for effect in fx.effects: effect.age=.065
		fx.queue_redraw(); fx.light.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-heavy-strokes-preview.png")
	print("HEAVY STROKES preview saved"); quit()
