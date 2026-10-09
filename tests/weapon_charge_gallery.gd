extends SceneTree
const FX=preload("res://scripts/stylized_vfx.gd")
const Glow=preload("res://scripts/weapon_held_glow.gd")
var frames := CharacterFrames.new()
var poses: Array=[]
var first := 600
var hero := 0
var font: Font=load("res://assets/NotoSansSC.ttf")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(2400,1500); root.content_scale_size=root.size
	DirAccess.make_dir_recursive_absolute("res://build/weapon-charge-review")
	var records: Array=[]
	for h in 4:
		for page in 4:
			hero=h; first=600+page*12; poses=[]
			for i in 12:
				var p := {"hero":hero,"weapon":first+i,"swing_time":0.0,"cast_time":0.0,"weapon_hold":{"shown":true,"time":1.1,"full_time":1.05}}
				var pose := frames.charge_frame(p); poses.append(pose)
				var sites := Glow.charge_sites(pose)
				var span: float= sites.front().distance_to(sites.back())
				records.append({"hero":hero,"weapon":first+i,"frame":pose.get("frame",0),"sites":sites.size(),"span":span,"short":sites.size()<3 or span<=5,"rect":[pose.rect.position.x,pose.rect.position.y,pose.rect.size.x,pose.rect.size.y],"region":[pose.texture.region.position.x,pose.texture.region.position.y,pose.texture.region.size.x,pose.texture.region.size.y],"file":pose.texture.atlas.resource_path})
			var board := Node2D.new(); root.add_child(board)
			board.draw.connect(func():
				board.draw_rect(Rect2(0,0,2400,1500),Color("161b28"))
				for i in 12:
					var cell := Vector2((i%4)*600,(i/4)*500)
					board.draw_rect(Rect2(cell+Vector2(8,8),Vector2(584,484)),Color("1b2534"))
					board.draw_string(font,cell+Vector2(25,45),"%d · %s · 角色 %d" % [first+i,Catalog.weapon(first+i).name,hero],HORIZONTAL_ALIGNMENT_LEFT,560,24,Color.WHITE)
					var pose: Dictionary=poses[i]
					board.draw_set_transform(cell+Vector2(310,390),0,Vector2.ONE*3.5)
					board.draw_texture_rect(pose.texture,pose.rect,false)
					board.draw_set_transform(Vector2.ZERO)
					var sites := Glow.charge_sites(pose)
					board.draw_string(font,cell+Vector2(25,465),"表面点 %d · 覆盖 %.1fpx" % [sites.size(),sites.front().distance_to(sites.back())],HORIZONTAL_ALIGNMENT_LEFT,560,22,Color("b5cbde"))
			)
			var fx := FX.new(); root.add_child(fx)
			fx.socket_provider=func(id):
				var pose: Dictionary=poses[id-1]
				var i: int=id-1
				var origin := Vector2((i%4)*600+310,(i/4)*500+390)+CharacterMetrics.FOOT_OFFSET*3.5
				var points: Array=[]
				for site in Glow.charge_sites(pose): points.append(origin+site*3.5)
				var tracks: Array=[]
				for path in Glow.charge_paths(pose):
					var track: Array=[]
					for point in path: track.append(origin+point*3.5)
					tracks.append(track)
				return {"tip":origin+Glow.charge_anchor(pose)*3.5,"aim":Vector2.RIGHT,"charge_points":points,"charge_paths":tracks}
			for i in 12:
				fx.event({"kind":"hold_charge","p":Vector2.ZERO,"id":i+1,"weapon_index":first+i,"hold_time":.5})
				fx.effects.back().age=.5
			for step in 30:
				fx.advance(.016)
				for effect in fx.effects: effect.age=.5
			board.queue_redraw(); fx.queue_redraw()
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/weapon-charge-review/hero-%d-page-%d.png" % [hero,page])
			board.queue_free(); fx.queue_free(); await process_frame
	var file := FileAccess.open("res://build/weapon-charge-review/coverage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"  "))
	print("Charge review: 192 weapon/hero previews saved")
	quit()
