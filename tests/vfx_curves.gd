extends SceneTree
const Curves=preload("res://scripts/vfx_curves.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
const Finish=preload("res://scripts/combat_finish.gd")
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for life in [.14,.19,.34,.42,.72]:
		for kind in ["slash","impact","beam","detonation","soul"]:
			for layer in ["body","flash","wake"]:
				check(Curves.envelope(-.01,life,layer,kind)==0,"Delayed layer is invisible")
				check(Curves.envelope(0,life,layer,kind)==0,"No full image at birth")
				check(Curves.envelope(life,life,layer,kind)==0,"All layers expire")
				for i in 21:
					var value := Curves.envelope(life*i/20,life,layer,kind)
					check(is_finite(value) and value>=0 and value<=1,"Energy remains bounded")
		check(Curves.envelope(.018,life,"body")>.8,"Contact silhouette reaches the actual release immediately")
		check(Curves.envelope(life*.7,life,"flash")<.001,"White flash cannot hover through recovery")
		check(Curves.envelope(life*.7,life,"body")>.01,"Colored material outlives the flash")
		check(Curves.envelope(life*.7,life,"body")<Curves.envelope(life*.25,life,"body"),"Material loses energy rather than holding a full stamp")
	check(Curves.envelope(.01,0)==0,"Zero lifespan is safe")
	var fx := FX.new(); root.add_child(fx)
	var finish := Finish.new(); root.add_child(finish)
	# Same hit identity, geometry and lifecycle across all material families.
	for weapon in [600,605,606,609,613,636,637,638,639,640,646]:
		var data := {"kind":"impact","p":Vector2(100,150),"contact_p":Vector2(102,126),"aim":Vector2.RIGHT,"id":1,"enemy_id":weapon,"weapon_index":weapon,"heavy":true,"damage":25}
		var original := data.duplicate(true)
		fx.event(data); finish.event(data)
		check(data==original,"Presentation cannot mutate authoritative hit data")
		check(fx.effects.back().p==data.contact_p,"Layered flash remains at the true contact")
		check(fx.effects.back().radius<=40,"Pressure accent remains within the contact budget")
		fx.advance(.4); finish.advance(1)
		check(fx.effects.is_empty() and finish.contacts.is_empty(),"No persistent flash or dust")
		fx.reset(); finish.reset()
	fx.queue_free(); finish.queue_free(); await process_frame
	print("VFX CURVES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
