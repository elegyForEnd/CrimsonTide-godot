extends SceneTree
const Library=preload("res://scripts/weapon_atlas_frames.gd")
const Glow=preload("res://scripts/weapon_held_glow.gd")
class Board extends Node2D:
	var library := Library.new()
	func _init() -> void:
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Library.BASE+"manifest.json"))
		library.manifest["0/sword"]=source.atlases["0/600"]
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1320,1170),Color("111b2b"))
		draw_string(font,Vector2(25,34),"绯红单手剑 · 两张原始图集 · 支撑脚注册检查",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
		var states := ["idle","walk","run","dodge","attack","art"]
		var names := ["待机","行走","奔跑","闪避","普攻 · 短弧斩","武器技 · 绯红回旋"]
		for row in states.size():
			var state: String=states[row]
			draw_string(font,Vector2(18,73+row*178),names[row],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("c8d5eb"))
			for i in library.count(0,600,state):
				var at := Vector2(105+i*215,216+row*178)
				var pose := library.frame(0,600,state,i,95)
				draw_set_transform(at)
				draw_line(Vector2(-94,16),Vector2(94,16),Color("344961"),1)
				draw_texture_rect(pose.texture,pose.rect,false)
				var glow := Glow.sample(pose,0)
				if not glow.is_empty(): draw_texture_rect(glow.texture,glow.rect,false,glow.tint)
				if state in ["attack","art"]: draw_circle(Vector2(-60*95/float(library.manifest["0/sword"].page_heights[library.manifest["0/sword"].states[state][i].file]),16),2,Color("66edb4"))
				draw_set_transform(Vector2.ZERO)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1320,1170); root.content_scale_size=root.size
	root.add_child(Board.new())
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-600-two-page-review.png")
	print("SWORD PAIR PREVIEW captured all 26 states/keys through production atlas regions")
	quit()
