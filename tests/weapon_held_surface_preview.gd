extends SceneTree
const Glow=preload("res://scripts/weapon_held_glow.gd")
class Board extends Node2D:
	var frames := CharacterFrames.new()
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1000,400),Color("172230"))
		for col in 5:
			var weapon: int=[600,601,612,615,638][col]
			for row in 2:
				var at := Vector2(100+col*200,160+row*185)
				var pose := frames.weapon_atlases.frame(0,weapon,"idle",0,125)
				draw_set_transform(at)
				draw_texture_rect(pose.texture,pose.rect,false)
				if row==1:
					for glint in Glow.samples(pose,.6): draw_texture_rect(glint.texture,glint.rect,false,glint.tint)
				draw_set_transform(Vector2.ZERO)
				draw_string(font,Vector2(col*200+20,30+row*185),Catalog.weapon(weapon).name+(" 原图" if row==0 else " 持械微光"),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1000,400)
	root.content_scale_size=root.size
	root.add_child(Board.new())
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-held-surface-preview.png")
	quit()
