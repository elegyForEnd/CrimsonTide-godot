extends SceneTree
const FX=preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var fx=FX.new(); root.add_child(fx)
	for weapon in 21:
		for heavy in [false,true]:
			fx.reset()
			var contact := Vector2(230,185)
			var event={"kind":"impact","p":Vector2(245,211),"contact_p":contact,"aim":Vector2.RIGHT,"id":1,"enemy_id":30,"weapon_index":weapon,"weapon":Catalog.weapon_family(weapon),"heavy":heavy}
			fx.event(event,0)
			check(fx.effects.size()==1 and fx.effects[0].kind=="impact","Only one contact flash, no duplicate ring")
			check(fx.effects[0].p==contact,"Contact flash uses torso-side point, not enemy feet")
			check(fx.shards.is_empty(),"The obsolete hit shards do not duplicate the particle response")
			check(fx.effects[0].radius<=28,"Hit response remains smaller than weapon silhouette")
			var count: int=fx.particles.particles.size()
			check(count<=8,"Contact releases only a few fragments, not a cloud")
			for bit in fx.particles.particles:
				check(bit.p.distance_to(contact)<8,"All fragments originate at the same contact point")
				check(bit.life<=.22 and bit.size<3,"Contact fragments remain short and small")
			fx.event(event,0)
			check(fx.effects.size()==1 and fx.particles.particles.size()==count,"Rapid pellet hits coalesce visually")
			fx.advance(.4)
			check(fx.effects.is_empty() and fx.particles.particles.is_empty(),"Contact response completes without hovering residue")
	fx.queue_free(); await process_frame
	print("WEAPON CONTACT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
