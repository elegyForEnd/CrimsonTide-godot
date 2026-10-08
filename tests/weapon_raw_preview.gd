extends SceneTree
class Board extends Node2D:
	var frames := CharacterFrames.new()
	var font: Font=load("res://assets/NotoSansSC.ttf")
	var weapons := [600,615,625,636]
	func _draw() -> void:
		draw_rect(Rect2(0,0,1500,920),Color("172230"))
		var states := ["idle","walk","run","dodge","attack","art"]
		for col in 6:
			draw_string(font,Vector2(70+col*245,35),["待机","行走","奔跑","闪避","普攻","武器技"][col],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
		for hero in 4:
			for col in 6:
				var pose := frames.weapon_atlases.frame(hero,weapons[hero],states[col],2,140)
				draw_set_transform(Vector2(120+col*245,210+hero*218))
				draw_texture_rect(pose.texture,pose.rect,false,Color.WHITE)
				draw_set_transform(Vector2.ZERO)
				draw_line(Vector2(20+col*245,226+hero*218),Vector2(220+col*245,226+hero*218),Color("4b5b69"))
			draw_string(font,Vector2(20,260+hero*218),"角色 %d · 武器 %d"%[hero,weapons[hero]],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b8c5d7"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1500,920); root.content_scale_size=root.size
	root.add_child(Board.new())
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-raw-integration-preview.png")
	print("RAW ATLAS six-state preview saved")
	quit()
