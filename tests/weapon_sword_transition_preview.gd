extends SceneTree
const Library=preload("res://scripts/weapon_atlas_frames.gd")
class Board extends Node2D:
	var library := Library.new()
	func _init() -> void:
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Library.BASE+"manifest.json"))
		library.manifest["0/sword"]=source.atlases["0/600"]
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1200,420),Color("131e30"))
		draw_string(font,Vector2(22,30),"绯红单手剑 · 准备 → 抬剑 → 蓄力",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
		for i in 3:
			var at := Vector2(175+i*390,348)
			var pose := library.frame(0,600,"attack",i,200)
			draw_set_transform(at)
			draw_line(Vector2(-140,16),Vector2(200,16),Color("425c7b"),1)
			draw_texture_rect(pose.texture,pose.rect,false)
			draw_set_transform(Vector2.ZERO)
			draw_string(font,Vector2(70+i*390,395),["1 · 准备","2 · 抬剑","3 · 蓄力"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("d1deef"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,420); root.content_scale_size=root.size
	root.add_child(Board.new())
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-600-lift-transition.png")
	print("SWORD LIFT TRANSITION preview captured from actual atlas regions")
	quit()
