extends SceneTree
const Probe = preload("res://output/rogue_effect_audit_probe.gd")
const Build = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")
var fixture
var checks := 0
var failures := 0
var records: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func hit() -> float:
	var e: Dictionary=fixture.e
	e.hp=e.max_hp
	e.build_status={}; e.build_break_time=0
	var before: float=e.hp
	var context: Dictionary=fixture.ctx()
	# Isolate upgrade damage from weapon on-hit status/proc accumulation.
	context.seen={e.id:true}; context.counted=true
	fixture.s.damage_enemy(e,fixture.s.weapon_damage(fixture.p),fixture.p.id,Vector2.RIGHT,0,-1,-1,context)
	return before-e.hp
func run() -> void:
	# Reuse setup helpers without calling the audit SceneTree's run/initialize.
	fixture=Probe.new()
	fixture.s=TideSession.new(); root.add_child(fixture.s); fixture.s.set_physics_process(false)
	for n in 48:
		fixture.reset(n)
		var p: Dictionary=fixture.p
		p.build_attributes={"strength":20,"dexterity":20,"intelligence":20,"arcane":20}
		p.build_forge_level=0
		var base := hit()
		var pool: float=fixture.s.rogue_damage_pool(p)
		var qualities: Array=[]
		for tier in 6:
			p.equipped.weapon.tier=tier
			var damage := hit()
			check(is_equal_approx(damage/base,float(Content.QUALITY[tier])),"W%03d quality %d real damage" % [n+1,tier])
			qualities.append(snappedf(damage,.001))
		p.equipped.weapon.tier=0
		var forging: Array=[]
		for level in 6:
			p.build_forge_level=level
			var damage := hit()
			check(is_equal_approx(damage/base,(1+pool+level*.03)/(1+pool)),"W%03d forge +%d real damage" % [n+1,level])
			forging.append(snappedf(damage,.001))
		p.build_forge_level=3
		var before_temper := hit()
		p.build_temper="steady"
		var steady := hit()
		check(is_equal_approx(steady/before_temper,(1+pool+.09+.04)/(1+pool+.09)),"W%03d steady real damage" % [n+1])
		p.build_temper=""
		var grade_key := ""
		for key in Catalog.weapon(p.weapon).scaling:
			if str(Catalog.weapon(p.weapon).scaling[key]) not in ["-","S"]: grade_key=key; break
		if grade_key!="":
			p.build_temper=grade_key
			check(hit()>before_temper,"W%03d scaling grade raises real damage" % [n+1])
		p.build_temper=""; p.build_forge_bound="different-instance"
		check(is_equal_approx(hit(),base),"W%03d forge inactive when weapon instance isn't bound" % [n+1])
		records.append({"id":"W%03d" % [n+1],"base_damage":snappedf(base,.001),"quality_damage":qualities,"forge_damage":forging,"steady_damage":snappedf(steady,.001),"grade_checked":grade_key})
	var file := FileAccess.open("res://output/rogue-weapon-upgrade-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t")); file.close()
	fixture.free()
	print("WEAPON UPGRADE AUDIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
