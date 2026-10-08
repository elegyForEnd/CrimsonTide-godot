extends SceneTree
const FX=preload("res://scripts/stylized_vfx.gd")
const WEAPONS=[600,613,615,621]
class Board extends Node2D:
	var frames := CharacterFrames.new()
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,880),Color("172230"))
		for column in 8:
			draw_string(font,Vector2(65+column*200,25),["右","右下","下","左下","左","左上","上","右上"][column],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		for row in 4:
			for column in 8:
				var at := Vector2(100+column*200,160+row*215)
				var aim := Vector2.RIGHT.rotated(column*TAU/8)
				var facing := Vector2(-1 if aim.x<0 else 1,1)
				var pose := frames.weapon_atlases.frame(0,WEAPONS[row],"attack",2,82)
				draw_set_transform(at,0,facing)
				draw_texture_rect(pose.texture,pose.rect,false,Color.WHITE)
				draw_set_transform(Vector2.ZERO)
				var grip: Vector2=at+(CharacterMetrics.FOOT_OFFSET+pose.grip)*facing
				draw_line(grip,grip+aim*90,Color(1,1,1,.20),1)
				draw_circle(grip+aim*90,2,Color("6f8795"))
				draw_string(font,at+Vector2(-90,42),Catalog.weapon(WEAPONS[row]).name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,880); root.content_scale_size=root.size
	var board := Board.new(); root.add_child(board)
	for row in 4:
		for column in 8:
			var at := Vector2(100+column*200,160+row*215)
			var aim := Vector2.RIGHT.rotated(column*TAU/8)
			var facing := Vector2(-1 if aim.x<0 else 1,1)
			var pose := board.frames.weapon_atlases.frame(0,WEAPONS[row],"attack",2,82)
			var grip: Vector2=at+(CharacterMetrics.FOOT_OFFSET+pose.grip)*facing
			var tip: Vector2=at+(CharacterMetrics.FOOT_OFFSET+pose.socket)*facing
			var mount := {"tip":tip,"grip":grip,"stroke_tip":grip+aim*grip.distance_to(tip),"aim":aim,"blade_axis":Vector2.RIGHT,"active":true}
			var fx := FX.new(); fx.position=at; root.add_child(fx)
			fx.socket_provider=func(_id): return mount
			fx.event({"kind":"strike","id":1,"p":Vector2.ZERO,"aim":aim,"weapon_index":WEAPONS[row],"weapon":Catalog.weapon_family(WEAPONS[row]),"combo":0,"reach":60})
			fx.set_process(false)
			for effect in fx.effects: effect.age=.065
			fx.queue_redraw(); fx.light.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-mouse-aim-preview.png")
	print("MOUSE AIM preview saved"); quit()
