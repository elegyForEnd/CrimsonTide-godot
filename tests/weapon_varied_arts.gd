extends SceneTree
const Choreo=preload("res://scripts/weapon_batch_choreography.gd")
const Hold=preload("res://scripts/weapon_hold_attack.gd")
var checks := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var rhythms := {}; var counts := {}
	for weapon in range(600,648):
		if not Choreo.enabled(weapon): continue
		var spec: Dictionary=Choreo.of(weapon)
		var share := 0.0
		var rhythm := []
		counts[spec.steps.size()]=true
		for step in spec.steps:
			share+=float(step[1]); rhythm.append([step[0],step[3],step[5],step[7],step[8]])
		check(is_equal_approx(share,1.0),"Damage budget sums to one cast: "+str(weapon))
		rhythms[str(rhythm)]=true
		check(not str(spec.name).ends_with("三式"),"No generic three-stage naming")
		if weapon>=636:
			var heavy := Hold.profile(weapon)
			var original: Dictionary=preload("res://scripts/rogue_content.gd").weapon(weapon).art
			check(float(heavy.reach)<=maxf(float(Catalog.weapon(weapon).reach),float(original.reach)*.85)*.65+.001,"Staff charged reach is reduced")
			check(float(heavy.radius)<=float(original.radius)*.65,"Staff charged blast radius is reduced")
			for step in spec.steps:
				check(float(step[2])<=430 and float(step[9])<=82,"Staff art has bounded length and area")
	check(counts.has(1) and counts.has(2) and counts.has(3) and counts.has(4) and counts.has(5),"One through five release rhythms are authored")
	check(rhythms.size()>=40,"At least forty distinct timing, movement and attack patterns")
	print("VARIED ARTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
