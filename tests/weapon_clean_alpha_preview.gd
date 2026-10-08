extends SceneTree
class Board extends Node2D:
	var texture: Texture2D
	func _draw() -> void:
		draw_rect(Rect2(0,0,1448,1086),Color("182436"))
		draw_texture_rect(texture,Rect2(0,0,1448,1086),false,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var original := Image.load_from_file(args[0])
	root.size=Vector2i(1448,1086); root.content_scale_size=root.size
	var board := Board.new(); board.texture=ImageTexture.create_from_image(original); root.add_child(board)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-600-clean-alpha-review.png")
	print("CLEAN ALPHA preview composited untouched RGBA through Godot")
	quit()
