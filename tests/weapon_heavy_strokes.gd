extends SceneTree
const M=preload("res://scripts/weapon_mechanics.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var fx := FX.new(); root.add_child(fx)
	for id in range(612,624):
		var weapon := Catalog.weapon(id)
		var role := M.normal_role(id)
		var profile := M.heavy_stroke(id,role)
		fx.reset()
		fx.event({"kind":"strike","p":Vector2(100,200),"aim":Vector2.RIGHT,"weapon_index":id,"weapon":2,"combo":0,"reach":weapon.reach})
		check(fx.effects[0].art_role==role,"Changed damage role %d" % id)
		check(float(fx.effects[0].radius)==float(weapon.reach),"Changed hit reach %d" % id)
		if id in [615,619]:
			check(profile.get("plane","")=="drop","Hammer still uses ring %d" % id)
			check(Art.release_source(id,role,0)=="identity_%d_drop_v2" % id,"Hammer missing new painting %d" % id)
		elif id!=614:
			check(not profile.is_empty(),"Missing concrete stroke %d" % id)
			check(absf(float(profile.angle))>.2,"Still horizontal %d" % id)
	check(M.heavy_stroke(2,M.normal_role(2))==M.heavy_stroke(612,M.normal_role(612)),"Campaign heavy alias differs")
	check(M.heavy_stroke(614,"motion_heavy_spin").is_empty(),"Genuine spin lost circular coverage")
	fx.queue_free(); await process_frame
	print("HEAVY STROKES: 12 weapons; %d failures" % failures)
	quit(1 if failures else 0)
