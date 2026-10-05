extends SceneTree
const Visual=preload("res://scripts/boss_damage_visual.gd")
const Language=preload("res://scripts/boss_effect_language.gd")
class Rogue extends RefCounted:
	func active(_s) -> bool: return false
class Session extends RefCounted:
	var raid: Dictionary={"hazards":[]}
	var bullets: Array=[]
	var enemies: Array=[]
	var roguelike=Rogue.new()
class Field extends Node2D:
	var session=Session.new()
	var camera=Vector2(640,400)
class Casters extends Node2D:
	var time := 0.0
	func _draw() -> void:
		for i in 8:
			var at := Vector2(160+i%4*320,355+i/4*370)
			Language.actor(self,["storm","ember","knight","mirror","earth","grove","abyss","obsidian"][i],at-Vector2(95,0),Vector2.RIGHT,"charge",time,1.5)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,820); root.content_scale_size=Vector2i(1280,820)
	var field=Field.new(); root.add_child(field)
	var bg=ColorRect.new(); bg.color=Color("151c28"); bg.size=Vector2(1280,820); field.add_child(bg)
	var profiles := [["storm","chain","circle","雷骸超载"],["ember","pyre","circle","熄灯晚祷"],["knight","slash","cone","踏步返刃"],["mirror","thread","lane","纺线缚影"],["earth","stalactite","circle","穹顶坠岩"],["grove","roots","circle","古根织网"],["abyss","tide","gap_ring","噬月深潜"],["obsidian","scar","lane","黑曜拔刀"]]
	for i in profiles.size():
		var spec=profiles[i]
		var at=Vector2(160+i%4*320,355+i/4*370)
		var h := {"shape":spec[2],"p":at,"origin":at,"aim":Vector2.RIGHT,"radius":65.0,"inner":0.0,"art_key":spec[0],"vfx_role":spec[1],"move":spec[3],"time":1.0,"windup":1.0,"linger":.6,"source":i,"part":i,"choreographed":true,"fired":false}
		if spec[2]=="lane": h.radius=210.0; h.inner=18.0; h.p-=Vector2(105,0)
		if spec[2]=="gap_ring": h.radius=110.0; h.inner=65.0; h.gap=.65
		field.session.raid.hazards.append(h)
		var label=Label.new(); label.text=str(spec[0])+" / "+str(spec[3]); label.position=at-Vector2(145,290); label.add_theme_font_override("font",load("res://assets/NotoSerifSC.ttf")); label.add_theme_font_size_override("font_size",18); field.add_child(label)
	var visual=Visual.new(); visual.field=field; field.add_child(visual); visual.set_process(false)
	var casters=Casters.new(); field.add_child(casters)
	for frame in 38:
		var t=frame/24.0
		for h in field.session.raid.hazards: h.time=1.0-t; h.fired=t>=1.0
		visual._process(1.0/24.0); casters.time=t; casters.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		if frame in [10,23,26,32]: root.get_texture().get_image().save_png("res://build/boss-readable-%02d.png" % frame)
	field.queue_free(); await process_frame
	print("BOSS READABILITY VISUAL: 8 identities, 4 stages")
	quit()
