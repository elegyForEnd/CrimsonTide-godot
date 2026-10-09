extends SceneTree
const Hold=preload("res://scripts/weapon_hold_attack.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,700)
	var s := TideSession.new(); root.add_child(s)
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729); s.set_physics_process(false)
	var p: Dictionary=s.players[1]; p.weapon=600; p.motion="run"; p.swing_time=0; p.cast_time=0
	var frames := CharacterFrames.new()
	var poses: Array=[]
	for ratio in [.25,.6,1.0]:
		p.weapon_hold={"shown":true,"time":Hold.TAP_TIME+(.65-Hold.TAP_TIME)*ratio,"full_time":.65}
		poses.append(frames.charge_frame(p))
	var board := Node2D.new(); root.add_child(board)
	board.draw.connect(func():
		board.draw_rect(Rect2(0,0,1440,700),Color("161b28"))
		for i in 3:
			var at := Vector2(240+i*480,450)
			var pose: Dictionary=poses[i]
			board.draw_set_transform(at,0,Vector2.ONE*3)
			board.draw_texture_rect(pose.texture,pose.rect,false)
			board.draw_set_transform(Vector2.ZERO)
			var progress: float=[.25,.6,1.0][i]
			var actor := {"weapon":600,"weapon_hold":{"shown":true,"time":Hold.TAP_TIME+(.65-Hold.TAP_TIME)*progress,"full_time":.65}}
			Hold.draw_bar(board,actor,at-Vector2(0,270))
			board.draw_string(ThemeDB.fallback_font,at+Vector2(-90,70),"CHARGE %d%%" % int(progress*100),HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	)
	var fx := FX.new(); root.add_child(fx)
	fx.socket_provider=func(id):
		var pose: Dictionary=poses[id-1]
		var origin := Vector2(240+(id-1)*480,450)+CharacterMetrics.FOOT_OFFSET*3
		var points: Array=[]
		for site in preload("res://scripts/weapon_held_glow.gd").charge_sites(pose): points.append(origin+site*3)
		var tracks: Array=[]
		for path in preload("res://scripts/weapon_held_glow.gd").charge_paths(pose):
			var track: Array=[]
			for point in path: track.append(origin+point*3)
			tracks.append(track)
		return {"tip":origin+preload("res://scripts/weapon_held_glow.gd").charge_anchor(pose)*3,"aim":Vector2.RIGHT,"charge_points":points,"charge_paths":tracks}
	for i in 3:
		fx.event({"kind":"hold_charge","p":Vector2(240+i*480,450),"id":i+1,"weapon_index":600,"hold_time":.47})
		fx.effects.back().age=[.12,.28,.47][i]
	for step in 30:
		fx.advance(.016)
		for i in 3: fx.effects[i].age=[.12,.28,.47][i]
	board.queue_redraw(); fx.queue_redraw()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/weapon-charge-ui")
	root.get_texture().get_image().save_png("res://build/weapon-charge-ui/preview.png")
	print("Charge bar preview saved")
	s.queue_free(); board.queue_free(); fx.queue_free(); await process_frame; quit()
