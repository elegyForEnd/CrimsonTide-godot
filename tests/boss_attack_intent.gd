extends SceneTree
const Choreo=preload("res://scripts/boss_choreography.gd")
const Design=preload("res://scripts/boss_attack_design.gd")
const Sequence=preload("res://scripts/boss_effect_sequence.gd")
const Geometry=preload("res://scripts/boss_geometry.gd")
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
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var move_count := 0
	for key in Choreo.MOVES:
		check(Design.PLANS.has(key) and Design.PLANS[key].size()==Choreo.MOVES[key].size(),"Every boss and move has authored intent: "+key)
		move_count+=Choreo.MOVES[key].size()
	check(move_count==104,"All 104 moves across 20 encounter tables are planned")
	for role in Sequence.specs():
		var unique: Dictionary={}
		var frame_count: int=Sequence.specs()[role].frames.size()
		for index in frame_count:
			var f := Sequence.frame(role,index)
			unique[str(f.texture.region)]=true
			check(f.texture is AtlasTexture and f.texture.filter_clip,"Original generated atlas is sampled without neighbour bleed")
			check(f.reach>100,"All frames share the contact frame's fixed scale")
		check(unique.size()==frame_count,"Every generated state has its own frame region: "+role)
		if str(role).ends_with("_v3"):
			check(frame_count==9 and Sequence.specs()[role].columns==3 and Sequence.specs()[role].rows==3,"One effect per independent nine-frame 3x3 atlas")
	var actor := {"attack_total":2.0,"attack_time":1.2,"body_marks":[.8,1.5]}
	check(Design.beat(actor).frame==4,"Body release starts at the real first contact")
	actor.attack_time=.5
	check(Design.beat(actor).frame==4,"Second swing restarts on its own actual contact")
	var swing := {"shape":"cone","p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":160.0,"inner":0.0,"arc":.8,"sweep":true,"time":-.02,"fired":true,"strike_duration":.18,"delivery":"blade","contact_dt":.02}
	check(Geometry.contains(swing,Vector2.from_angle(-.65)*100),"Blade's early contact is on the moving edge")
	check(not Geometry.contains(swing,Vector2.from_angle(.65)*100),"Blade does not damage the unswept far side")
	swing.time=-.16
	check(Geometry.contains(swing,Vector2.from_angle(.65)*100),"Blade traverses the opposite side at the late contact")
	swing.time=-.22
	check(not Geometry.contains(swing,Vector2(100,0)),"Recovering effect cannot hurt")
	var field=Field.new(); root.add_child(field)
	var visual=Visual.new(); visual.field=field; field.add_child(visual); visual.set_process(false)
	visual.transform=Transform2D(Vector2(1,.18),Vector2(.12,.65),Vector2.ZERO)
	var h={"p":Vector2.ZERO,"origin":Vector2.ZERO,"source":1,"shape":"cone","aim":Vector2.RIGHT,"radius":195.0,"inner":0.0,"arc":.75,"art_key":"thorn","vfx_role":"bramble","delivery":"whip","time":.15,"total":.78,"strike_duration":.18,"choreographed":true,"fired":false,"linger":.18,"socket_height":42.0}
	field.session.raid.hazards=[h]
	visual._process(.01)
	var item: Dictionary=visual.nodes.values()[0]
	check(not item.root.visible,"Physical anticipation has no filled ground sector")
	check(item.sequence_state=="prepare" and item.sequence_frame<4,"Windup samples real preparation frames")
	h.fired=true; h.time=-.02
	visual._process(.01)
	check(item.sequence_frame==2 and item.sequence_state=="contact","Actual contact selects the extended lash release frame")
	visual._process(.12)
	check(item.sequence_frame==2,"Paused / repeated simulation state cannot advance the contact animation independently")
	check(item.body.texture is AtlasTexture,"The generated multi-state atlas is used in the live renderer")
	check(not item.birth.get_shader_parameter("clip_ground"),"Painted action silhouette is independent of warning masks")
	var scale: float=item.body.global_transform.x.length()
	h.time=-.12; visual._process(.01)
	check(item.sequence_frame==3,"Actual follow-through uses a different deformed peak frame")
	check(is_equal_approx(item.body.global_transform.x.length(),scale),"Frame changes preserve scale instead of resizing each crop")
	field.session.raid.hazards=[]; visual._process(.08)
	check(item.sequence_state=="recover" and item.sequence_frame>=4,"Removal of damage enters non-damaging follow-through and recovery frames")
	for delivery in ["whip","claw","bite"]:
		h.delivery=delivery; h.time=-.03
		check(Geometry.contains(h,Vector2(120,-15)),"Contact path hits the painted forward reach: "+delivery)
		check(not Geometry.contains(h,Vector2(-90,0)),"Forward attack never damages behind the caster: "+delivery)
	var bind := {"source":7,"p":Vector2(80,0),"actor_offset":Vector2(5,0),"bind_after":.9}
	var breath := {"shape":"lane","p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":350.0,"inner":40.0,"stream_forward":80.0}
	check(not Geometry.contains(breath,Vector2(40,0)),"Breath starts at the mouth reach, not under the caster's feet")
	check(Geometry.contains(breath,Vector2(130,0)),"Breath contact and its forward warning share the real emission path")
	check(Geometry.shader_data(breath).source_x==80.0,"GPU warning receives the real emission-source offset")
	field.session.enemies=[{"id":7,"p":Vector2(130,40),"hp":10,"choreo_elapsed":1.0}]
	Choreo.bind_contact(field.session,bind,.03)
	check(bind.p==Vector2(135,40),"Melee hit origin follows the live actor after a step")
	field.queue_free(); await process_frame
	print("BOSS ATTACK INTENT ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
