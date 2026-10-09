extends SceneTree
const Hold=preload("res://scripts/weapon_hold_attack.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
const WEAPONS=[600,615,634,637]
class Board extends Node2D:
	var frames := CharacterFrames.new()
	var weapon := 600
	var phase := 0
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,700,700),Color("172230"))
		var pose := frames.weapon_atlases.frame(0,weapon,"art",2 if phase==2 else 1,120)
		draw_set_transform(Vector2(290,460))
		draw_texture_rect(pose.texture,pose.rect,false)
		draw_set_transform(Vector2.ZERO)
		draw_string(font,Vector2(24,35),Catalog.weapon(weapon).name,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
		draw_string(font,Vector2(24,670),["蓄力中","蓄满：松开释放","释放瞬间"][phase],HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
class Overview extends Node2D:
	var tiles: Array=[]
	func _draw() -> void:
		for i in tiles.size(): draw_texture_rect(tiles[i],Rect2((i%4)*350,(i/4)*350,350,350),false)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1400,1050); root.content_scale_size=root.size
	var overview := Overview.new(); root.add_child(overview)
	var viewports: Array=[]
	for phase in 3:
		for weapon in WEAPONS:
			var v := SubViewport.new(); v.size=Vector2i(700,700); v.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(v)
			var board := Board.new(); board.weapon=weapon; board.phase=phase; v.add_child(board)
			var fx := FX.new(); v.add_child(fx); fx.set_process(false); fx.particles.set_process(false)
			var at := Vector2(290,460)
			var pose := board.frames.weapon_atlases.frame(0,weapon,"art",2 if phase==2 else 1,120)
			var aimed := CharacterMetrics.aimed_mount(at+CharacterMetrics.FOOT_OFFSET,pose.grip,pose.socket,Vector2.RIGHT)
			var mount := {"tip":at+CharacterMetrics.FOOT_OFFSET+pose.socket,"grip":at+CharacterMetrics.FOOT_OFFSET+pose.grip,"stroke_tip":aimed.tip,"stroke_pivot":aimed.pivot,"aim":Vector2.RIGHT}
			fx.socket_provider=func(_id): return mount
			var move := Hold.profile(weapon)
			if phase<2:
				fx.event({"kind":"hold_charge","p":at,"id":1,"weapon_index":weapon,"hold_time":move.hold_time-Hold.TAP_TIME})
				fx.advance((float(move.hold_time)-Hold.TAP_TIME)*(.5 if phase==0 else 1.1))
			else:
				fx.event({"kind":"strike","p":at,"id":1,"aim":Vector2.RIGHT,"weapon_index":weapon,"weapon":Catalog.weapon_family(weapon),"combo":2,"attack_kind":move.kind,"reach":move.reach,"width":move.get("width",35),"charged":true})
				if move.kind=="burst":
					fx.event({"kind":"spell_burst","p":at+Vector2(160,0),"id":1,"aim":Vector2.RIGHT,"weapon_index":weapon,"spell":move.spell,"radius":move.radius})
				fx.advance(.075)
			viewports.append(v); overview.tiles.append(v.get_texture())
	overview.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-hold-preview.png")
	print("HOLD PREVIEW saved"); quit()
