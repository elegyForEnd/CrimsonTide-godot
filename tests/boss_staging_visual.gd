extends SceneTree
const Visual = preload("res://scripts/boss_damage_visual.gd")
class Rogue extends RefCounted:
	func active(_s) -> bool: return false
class Session extends RefCounted:
	var raid: Dictionary={"hazards":[]}
	var bullets: Array=[]
	var enemies: Array=[]
	var roguelike=Rogue.new()
class Field extends Node2D:
	var session=Session.new()
	var camera=Vector2(800,500)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,1100)
	root.content_scale_size=Vector2i(1600,1100)
	var field=Field.new()
	root.add_child(field)
	var bg=ColorRect.new()
	bg.color=Color("171d29"); bg.size=Vector2(1600,1100)
	field.add_child(bg)
	for x in range(0,1600,40):
		var line=ColorRect.new(); line.color=Color("222a37"); line.position=Vector2(x,0); line.size=Vector2(1,1100); field.add_child(line)
	for y in range(0,1100,40):
		var line=ColorRect.new(); line.color=Color("222a37"); line.position=Vector2(0,y); line.size=Vector2(1600,1); field.add_child(line)
	var visual=Visual.new(); visual.field=field; field.add_child(visual); visual.set_process(false)
	var profiles=[["queen","sabres","circle"],["thorn","root","circle"],["earth","stalactite","circle"],["storm","chain","lane"]]
	for row in 4:
		for col in 4:
			var spec=profiles[row]
			var at=Vector2(180+col*400,210+row*245)
			var h={"p":at,"origin":at,"source":row,"part":col,"choreo_serial":1,"shape":spec[2],"radius":65.0 if row<3 else 280.0,"inner":0.0 if row<3 else 22.0,"aim":Vector2.RIGHT,"art_key":spec[0],"vfx_role":spec[1],"time":[.75,.30,-.035,-.18][col],"windup":1.0,"linger":.55,"choreographed":true,"fired":col>=2}
			if row==3: h.p.x-=120; h.origin=h.p
			field.session.raid.hazards.append(h)
			var label=Label.new(); label.text=spec[0]+" / "+["gather","approach","impact","settle"][col]; label.position=at+Vector2(-120,-195); label.add_theme_font_size_override("font_size",22); field.add_child(label)
	visual._process(.25)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/boss-staging-storyboard.png")
	field.queue_free(); await process_frame
	print("BOSS STAGING VISUAL: 16 panels")
	quit()
