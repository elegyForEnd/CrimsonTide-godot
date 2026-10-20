extends SceneTree
## Fixed-time render gallery; use -- --out=res://build/lol-vfx-study/after.png.
const FX=preload("res://scripts/stylized_vfx.gd")
const Finish=preload("res://scripts/combat_finish.gd")
const TIMES=[.012,.045,.11,.23]
class Board extends Node2D:
	var font: Font=load("res://assets/NotoSansSC.ttf")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,1000),Color("101923"))
		draw_string(font,Vector2(32,42),"技能特效 · 固定时刻实机渲染",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("e4e9ed"))
		for col in 4:
			draw_string(font,Vector2(220+col*330,86),"%d ms" % roundi(TIMES[col]*1000),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("9caebb"))
		for row in 5:
			draw_string(font,Vector2(24,153+row*173),["血刃斩击","火焰爆发","光束释放","寒冰命中","真实弹道尾迹"][row],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("9caebb"))
			for col in 4:
				var p := Vector2(245+col*330,191+row*173)
				draw_line(p-Vector2(115,0),p+Vector2(115,0),Color("24313b"),1)
				draw_arc(p,44,0,TAU,48,Color("1d2b36"),1,true)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,1000); root.content_scale_size=root.size
	root.add_child(Board.new())
	for row in 5:
		for col in 4:
			var p := Vector2(245+col*330,191+row*173)
			var age: float=TIMES[col]
			if row<4:
				var fx := FX.new(); root.add_child(fx)
				var data := {"kind":"strike","p":p,"aim":Vector2.RIGHT,"id":1,"weapon":1,"weapon_index":600,"reach":92.0,"combo":0}
				if row==1: data.merge({"kind":"spell_burst","weapon_index":637,"spell":"meteor","radius":70.0},true)
				if row==2: data.merge({"kind":"spell_beam","p":p-Vector2(95,0),"weapon_index":640,"spell":"prism","reach":190.0,"width":26.0},true)
				if row==3: data.merge({"kind":"impact","weapon_index":638,"contact_p":p,"heavy":true,"enemy_id":1,"damage":24},true)
				fx.event(data); fx.advance(age)
			else:
				var finish := Finish.new(); root.add_child(finish)
				for i in 9:
					finish.advance(.012)
					finish.observe([{"fx_id":42,"p":p-Vector2(110-i*23,0),"weapon_index":638,"height":0}],.02)
				finish.advance(age)
				finish.observe([],.001)
	# Allow dynamic font glyph textures to reach the render thread as well.
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://build/lol-vfx-study/after.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): path=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error := root.get_texture().get_image().save_png(path)
	print("VFX LAYERS PREVIEW ",path," error=",error)
	quit(0 if error==OK else 1)
