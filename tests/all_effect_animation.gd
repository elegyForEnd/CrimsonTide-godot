extends SceneTree
const FX = preload("res://scripts/stylized_vfx.gd")
var stage: Node2D
var fx: Node2D

class Board extends Node2D:
	var heroes := false
	var frames := CharacterFrames.new()
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,900),Color("10151f"))
		draw_string(font,Vector2(30,42),"角色专属特效" if heroes else "21 把武器 · 独立高清特效",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("e3eafa"))
		var names := ["绯月 · 赤刃", "雪璃 · 霜晶", "鸦羽 · 黑羽", "墓煜 · 冥火"]
		var count := 4 if heroes else 21
		for i in count:
			var at := Vector2(180+i*355,470) if heroes else Vector2(106+(i%7)*205,206+(i/7)*266)
			var index := Catalog.starter_index(i) if heroes else i
			draw_rect(Rect2(at-Vector2(96,126),Vector2(195,240)),Color("192130"))
			draw_line(at+Vector2(-90,42),at+Vector2(90,42),Color("344052"),1)
			draw_string(font,at+Vector2(-87,80),names[i] if heroes else Catalog.weapon(i).name,HORIZONTAL_ALIGNMENT_LEFT,185,16,Color("c9d4e5"))
			draw_string(font,at+Vector2(-87,104),"Q · 专属奥义" if heroes else "三段连招 · 第三段",HORIZONTAL_ALIGNMENT_LEFT,185,12,Color("8393ad"))
			var pose: Dictionary=frames.attack_frame(i if heroes else 0,Catalog.weapon_family(index),2)
			draw_set_transform(at,0,Vector2.ONE*.72)
			draw_texture_rect(pose.texture,pose.rect,false,Color(.75,.8,.9))
			draw_set_transform(Vector2.ZERO)

func _initialize() -> void: call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	root.size=Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	stage=Board.new()
	root.add_child(stage)
	fx=FX.new()
	stage.add_child(fx)
	for i in 21:
		var at := Vector2(106+(i%7)*205,206+(i/7)*266)
		var w: Dictionary=Catalog.weapon(i)
		fx.event({"kind":"strike","p":at,"weapon":Catalog.weapon_family(i),"weapon_index":i,"combo":2,"reach":minf(w.reach,80),"pattern":w.get("pattern",""),"aim":Vector2.RIGHT},0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/all-effect-frames"))
	for frame in 20:
		fx.advance(.02)
		await capture("res://build/all-effect-frames/%03d.png" % frame)
	fx.reset()
	stage.heroes=true
	stage.queue_redraw()
	for hero in 4:
		fx.event({"kind":"skill","p":Vector2(180+hero*355,470),"hero":hero,"aim":Vector2.RIGHT},hero)
	fx.advance(.16)
	await capture("res://build/standalone-heroes.png")
	print("STANDALONE PREVIEW: all 21 weapons and four hero ultimates rendered")
	quit()
