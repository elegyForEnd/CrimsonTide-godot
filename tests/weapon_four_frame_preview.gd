extends SceneTree
const Library=preload("res://scripts/weapon_atlas_frames.gd")
class Board extends Node2D:
	var library := Library.new()
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1320,800),Color("182436"))
		for row in 2:
			var state: String=["attack","art"][row]
			if library.count(0,600,state)!=4: continue
			draw_string(font,Vector2(20,30+row*390),"绯红单手剑 · "+("普攻" if row==0 else "武器技"),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
			for i in 4:
				var pose := library.frame(0,600,state,i,210)
				draw_set_transform(Vector2(160+i*320,335+row*390))
				draw_texture_rect(pose.texture,pose.rect,false,Color.WHITE)
				draw_set_transform(Vector2.ZERO)
				draw_string(font,Vector2(80+i*320,375+row*390),["1 准备","2 蓄力","3 命中","4 收招"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("d0d9e9"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1320,800); root.content_scale_size=root.size
	root.add_child(Board.new())
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-600-four-frame-review.png")
	print("FOUR FRAME preview through actual AtlasTexture regions")
	quit()
