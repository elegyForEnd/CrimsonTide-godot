extends SceneTree
class Board extends Node2D:
	var frames := CharacterFrames.new()
	var hero := 0
	var key := 2
	var state := "attack"
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,1200),Color("172230"))
		for i in 48:
			var at := Vector2(100+(i%8)*200,150+(i/8)*200)
			var pose := frames.weapon_atlases.frame(hero,600+i,state,key,100)
			draw_set_transform(at)
			draw_texture_rect(pose.texture,pose.rect,false,Color.WHITE)
			var tip: Vector2=CharacterMetrics.FOOT_OFFSET+pose.socket
			var grip: Vector2=CharacterMetrics.FOOT_OFFSET+pose.grip
			draw_line(grip,tip,Color(0,1,0,.8),1)
			draw_circle(tip,3,Color.GREEN)
			draw_circle(grip,3,Color.YELLOW)
			draw_set_transform(Vector2.ZERO)
			draw_string(font,at+Vector2(-80,34),"%d %s" % [600+i,Catalog.weapon(600+i).name],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var board := Board.new()
	if args.size()>0: board.hero=int(args[0])
	if args.size()>1: board.key=int(args[1])
	if args.size()>2: board.state=args[2]
	root.size=Vector2i(1600,1200); root.content_scale_size=root.size
	root.add_child(board)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-mounts-%d-%s-%d.png" % [board.hero,board.state,board.key])
	print("Weapon mount preview saved"); quit()
