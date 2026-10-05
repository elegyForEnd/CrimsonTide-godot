extends SceneTree
const Art = preload("res://scripts/boss_effect_art.gd")
class Board extends Node2D:
	var start := 0
	var textures: Array[Texture2D]=[]
	var font: Font=preload("res://assets/NotoSerifSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,900),Color("101827"))
		draw_string(font,Vector2(35,40),"Boss 独立招式素材 · 17 种身份 / 68 张原创透明图",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color.WHITE)
		for i in mini(6,Art.KEYS.size()-start):
			var key: String=Art.KEYS[start+i]
			var row := Vector2(40,70+i*135)
			draw_string(font,row+Vector2(0,60),key,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("b7c9e9"))
			for j in 4:
				Art.draw(self,key,Art.ROLES[j],row+Vector2(270+j*300,65),Vector2.ONE*115,0,1)
				draw_string(font,row+Vector2(225+j*300,126),str(Art.MOTIFS[key][j]),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8da5cb"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	for page in 3:
		var board := Board.new()
		board.start=page*6
		root.add_child(board)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/boss-effects-%d.png" % (page+1))
		board.queue_free()
		await process_frame
	quit()
