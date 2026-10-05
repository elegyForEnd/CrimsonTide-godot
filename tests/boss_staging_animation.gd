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
	root.size=Vector2i(1280,600)
	root.content_scale_size=Vector2i(1280,600)
	var field=Field.new()
	root.add_child(field)
	var bg=ColorRect.new()
	bg.color=Color("171d29"); bg.size=Vector2(1280,600)
	field.add_child(bg)
	for x in range(0,1280,40):
		var line=ColorRect.new(); line.color=Color("222a37"); line.position=Vector2(x,0); line.size=Vector2(1,600); field.add_child(line)
	for y in range(0,600,40):
		var line=ColorRect.new(); line.color=Color("222a37"); line.position=Vector2(0,y); line.size=Vector2(1280,1); field.add_child(line)
	var visual=Visual.new(); visual.field=field; field.add_child(visual); visual.set_process(false)
	var profiles=[["queen","sabres","circle"],["thorn","root","circle"],["earth","stalactite","circle"],["storm","chain","lane"]]
	for row in 4:
		for col in 1:
			var spec=profiles[row]
			var at=Vector2(160+row*320,370)
			var h={"p":at,"origin":at,"source":row,"part":row,"choreo_serial":1,"shape":spec[2],"radius":65.0 if row<3 else 270.0,"inner":0.0 if row<3 else 22.0,"aim":Vector2.RIGHT,"art_key":spec[0],"vfx_role":spec[1],"time":.9,"windup":1.0,"linger":.55,"choreographed":true,"fired":false}
			if row==3: h.p.x-=120; h.origin=h.p
			field.session.raid.hazards.append(h)
			var label=Label.new(); label.text=spec[0]+" / "+spec[1]; label.position=at+Vector2(-120,-270); label.add_theme_font_size_override("font_size",22); field.add_child(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/staging-frames"))
	var hazards: Array=field.session.raid.hazards.duplicate()
	for frame in 48:
		var time=frame/24.0
		if time>=1.35: field.session.raid.hazards=[]
		for h in hazards:
			h.time=.9-time; h.fired=time>=.9
		visual._process(1.0/24.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/staging-frames/%03d.png" % frame)
	field.queue_free(); await process_frame
	print("BOSS STAGING VISUAL: 48 animation frames")
	quit()
