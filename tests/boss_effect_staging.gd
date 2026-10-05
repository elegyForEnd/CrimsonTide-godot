extends SceneTree
const Stage=preload("res://scripts/boss_effect_staging.gd")
const Art=preload("res://scripts/boss_effect_art.gd")
const Visual=preload("res://scripts/boss_damage_visual.gd")
var checks := 0
var failures := 0
class Rogue extends RefCounted:
	func active(_s) -> bool: return false
class Session extends RefCounted:
	var raid: Dictionary={"hazards":[]}
	var bullets: Array=[]
	var enemies: Array=[]
	var roguelike=Rogue.new()
class Field extends Node2D:
	var session=Session.new()
	var camera=Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var births: Dictionary={}
	for key in Art.KEYS:
		for role in Art.MOTIFS[key]:
			var h={"p":Vector2.ZERO,"shape":"circle","aim":Vector2.RIGHT,"radius":70.0,"art_key":key,"vfx_role":role,"time":.6,"fired":false}
			var start=Stage.pose(h,.1,0.0)
			births[start.kind]=true
			check(start.alpha<=.001,"No instant painted stamp at telegraph creation: "+key+role)
			h.time=.30
			var approach=Stage.pose(h,.4,0.0)
			if start.kind=="fall": check(approach.lift<start.lift,"Falling object approaches impact anchor")
			h.time=0.0; h.fired=true
			var impact=Stage.pose(h,.7,0.0)
			var after=Stage.pose(h,.9,.20)
			if start.kind=="fall": check(impact.lift<approach.lift,"Fall lands exactly at attack mark")
			if start.kind=="grow": check(after.reveal>impact.reveal,"Ground entity reveals upward through release")
			var tail=Stage.pose(h,1.0,.20,.25)
			check(tail.alpha<=after.alpha,"Afterimage fades instead of instant deletion")
			check(impact.size>0 and is_finite(impact.size),"Valid entity dimensions")
	check(births.size()>=6,"Distinct spatial birth languages across boss identities")
	check(Stage.stream_style("storm")!=Stage.stream_style("dragon"),"Lightning and breath are different continuous materials")
	var field=Field.new(); root.add_child(field)
	var visual=Visual.new(); visual.field=field; field.add_child(visual); visual.set_process(false)
	visual.transform=Transform2D(Vector2(1,.25),Vector2(.20,.65),Vector2.ZERO)
	var h={"p":Vector2(110,100),"origin":Vector2(110,100),"shape":"circle","aim":Vector2.RIGHT,"radius":60.0,"inner":0.0,"art_key":"earth","vfx_role":"stalactite","source":1,"part":0,"time":.30,"total":1.0,"choreographed":true,"fired":false,"linger":.3}
	field.session.raid.hazards=[h]
	visual._process(.1)
	var item: Dictionary=visual.nodes.values()[0]
	check(is_equal_approx(item.body.global_transform.x.length(),item.body.global_transform.y.length()),"Elevated PNG remains uniformly scaled under ground projection")
	check(absf(item.body.global_transform.x.dot(item.body.global_transform.y))<.000001,"No inherited shear on elevated artwork")
	check(item.mat.get_shader_parameter("arrival")<1.0,"Warning fades in on first sight")
	h.fired=true; h.time=-.05
	visual._process(.1)
	check(item.was_active and item.impact_age>=.05,"Release uses authoritative impact clock")
	field.session.raid.hazards=[]
	visual._process(.05)
	check(not item.root.visible,"Damage footprint disappears exactly with server hazard")
	check(visual.nodes.size()==1 and item.tail>0,"Entity has a separate non-damaging fade tail")
	visual._process(.4)
	check(visual.nodes.is_empty(),"Completed tails free both render nodes")
	field.queue_free(); await process_frame
	print("BOSS EFFECT STAGING ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
