extends SceneTree
const Visual=preload("res://scripts/boss_damage_visual.gd")
const Design=preload("res://scripts/boss_attack_design.gd")
class Rogue extends RefCounted:
	func active(_s) -> bool: return false
class Session extends RefCounted:
	var raid: Dictionary={"hazards":[]}
	var bullets: Array=[]
	var enemies: Array=[]
	var roguelike=Rogue.new()
class Field extends Node2D:
	var session=Session.new()
	var camera=Vector2(720,420)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,720)
	root.content_scale_size=Vector2i(1440,720)
	var field=Field.new(); root.add_child(field)
	var bg := ColorRect.new(); bg.color=Color("131923"); bg.size=Vector2(1440,720); field.add_child(bg)
	var title := Label.new(); title.text="BOSS ACTION ATLAS / PREPARE → CONTACT → RECOVER"; title.position=Vector2(60,40); title.add_theme_font_size_override("font_size",26); field.add_child(title)
	var visual=Visual.new(); visual.field=field; field.add_child(visual); visual.set_process(false)
	var bodies := preload("res://scripts/enemy_body.gd").new()
	var fixtures: Array=[]
	var samples := [["thorn","bramble","whip",Vector2(230,480),80.0,1],["dragon","wings","claw",Vector2(700,480),40.0,3],["abyss","maw","bite",Vector2(1140,480),180.0,2]]
	for i in samples.size():
		var spec: Array=samples[i]
		var e := {"id":i+1,"p":spec[3],"hp":100.0,"attack_time":.64,"attack_total":.64,"windup":.30,"body_marks":[.30],"choreo_cast":true,"facing":1,"raid_boss":i==0,"mini_boss":i>0,"boss_kind":spec[5],"moving":false,"guard_time":0.0,"stagger":0.0}
		if i==1: e["dragon_boss"]=true
		if i==2: e["wild_boss"]=true; e["wild_kind"]=2
		var body := Sprite2D.new(); field.add_child(body)
		var h := {"p":spec[3],"origin":spec[3],"source":i+1,"shape":"cone","radius":205.0,"inner":0.0,"aim":Vector2.RIGHT,"arc":.75,"art_key":spec[0],"vfx_role":spec[1],"delivery":spec[2],"time":.30,"total":.30,"strike_duration":.18,"linger":.18,"socket_height":spec[4],"choreographed":true,"fired":false}
		h["socket_forward"]=[20.0,25.0,15.0][i]
		var caption := Label.new(); caption.position=spec[3]+Vector2(-130,100); caption.text=str(spec[2])+" / 8 frames / fixed source"; caption.add_theme_font_size_override("font_size",20); field.add_child(caption)
		fixtures.append({"e":e,"h":h,"body":body})
	visual.z_index=2
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/boss-action-states"))
	for frame in 48:
		var time := frame/48.0
		field.session.raid.hazards=[]
		for fixture in fixtures:
			fixture.e.attack_time=maxf(0,.64-time)
			fixture.h.time=.30-time; fixture.h.fired=time>=.30
			if time<.48: field.session.raid.hazards.append(fixture.h)
			var body: Dictionary=bodies.pose(fixture.e,time,false)
			fixture.body.texture=body.texture
			fixture.body.region_enabled=body.region.size!=Vector2.ZERO
			fixture.body.region_rect=body.region
			var size: Vector2=body.region.size if body.region.size!=Vector2.ZERO else body.texture.get_size()
			fixture.body.scale=body.rect.size/size
			fixture.body.position=fixture.e.p+body.rect.get_center()
		visual._process(1.0/48)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/boss-action-states/%03d.png" % frame)
	field.queue_free(); await process_frame
	print("BOSS ACTION STATES: 48 real render frames, three atlases + synchronized bodies")
	quit()
