extends SceneTree
class Board extends Node2D:
	var page := 0
	var textures: Array=[]
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1500,2740),Color("101722"))
		for col in 5: draw_string(font,Vector2(col*300+20,28),["普攻起手","普攻第三段","武器技","普攻飞行","战技弹体/爆发"][col],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		for row in 12:
			for col in 5:
				var state: int=[0,2,3,4,5][col]
				var y := 42+row*224
				draw_texture_rect_region(textures[row],Rect2(col*300,y,300,232.0/350*300),Rect2(5,50+state*237,350,232))
				draw_string(font,Vector2(col*300+8,y+218),"%d %s"%[600+page*12+row,Catalog.weapon(600+page*12+row).name],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1500,2740); root.content_scale_size=root.size
	for page in 4:
		var board := Board.new(); board.page=page
		for row in 12:
			var img := Image.load_from_file("res://build/weapon-full-audit/weapon-%03d.png"%(600+page*12+row))
			board.textures.append(ImageTexture.create_from_image(img))
		root.add_child(board)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/weapon-full-audit/overview-%d.png"%page)
		board.queue_free(); await process_frame
	quit()
