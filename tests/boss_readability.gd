extends SceneTree
const Language=preload("res://scripts/boss_effect_language.gd")
const Stage=preload("res://scripts/boss_effect_staging.gd")
const Particles=preload("res://scripts/combat_particles.gd")
var checks := 0
var failures := 0
class Obstacles extends RefCounted:
	func safe_point(at: Vector2) -> Vector2: return at+Vector2(30,0)
	func move(at: Vector2, delta: Vector2, _radius: float) -> Vector2: return at+delta*.5
class MockSession extends RefCounted:
	var ruins=Obstacles.new()
	var raid := {"hazards":[]}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	for key in Language.Art.KEYS:
		for role in Language.Art.MOTIFS[key]:
			for shape in ["circle","lane","ring","gap_ring","capsule"]:
				var h := {"shape":shape,"p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":60.0,"inner":0.0,"art_key":key,"vfx_role":role,"time":.8,"windup":2.0,"fired":false}
				var pose=Stage.pose(h,.2,0)
				if shape in ["lane","ring","gap_ring"]: check(pose.alpha==0,"Continuous fields never carry rotating painted objects")
				if shape=="circle" and key in ["storm","wing"]:
					h.fired=true; h.time=-.06
					pose=Stage.pose(h,.9,.06)
					check(pose.alpha==0 or (pose.kind=="strike" and pose.angle==0),"Thunder is a grounded vertical strike, never a spinning emblem")
	check(Language.sprite_role("wing","return","capsule")=="electric_bolt","Returning electrical projectiles never become feathers or crescent slashes")
	check(Language.sprite_role("furnace","hammer","circle","泄压熔井")=="flame_vent","Furnace pressure release is a ground vent")
	check(Language.sprite_role("furnace","hammer","circle","锁链拖拽")=="hammer","Chain follow-up retains its actual hammer")
	check(Language.stream_style("furnace","chain")==5,"Chain is continuous rails rather than a flame jet")
	check(Particles.boss_style("wing")=="electric" and Particles.boss_style("obsidian")=="spark","Particles correspond to lightning and blade contact")
	for flags in [{"wild_boss":true,"wild_kind":1},{"rogue_guardian":true,"rogue_skin":3}]:
		var old_record := {"shape":"circle","p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":60.0,"inner":0.0,"vfx_role":"chain" if flags.has("wild_boss") else "return","time":-.06,"windup":1.0,"fired":true}
		old_record.merge(flags)
		check(Stage.pose(old_record,.9,.06).kind=="strike","Legacy flags resolve storm / wing identity without defaulting to knight")
	var rogue_record := {"rogue_guardian":true,"rogue_skin":3,"active":true,"age":.17,"delay":0.0}
	var normalized=preload("res://scripts/boss_damage_visual.gd").render_record(rogue_record)
	check(normalized.art_key=="wing" and normalized.time==-.17,"Rogue release uses its authoritative active age, not a newly started client clock")
	check(not rogue_record.has("time") and not rogue_record.has("art_key"),"Presentation normalization does not mutate authoritative state")
	var vent := {"art_key":"furnace","vfx_role":"kiln","shape":"circle","radius":65.0,"construct_only":true,"construct_age":.5,"construct_life":2.0,"vent_active":false,"fired":true,"time":-.1}
	var smoke=Stage.pose(vent,.5,.1)
	vent.vent_active=true
	var fire=Stage.pose(vent,.5,.1)
	check(Language.sprite_role("furnace","kiln","circle")=="ground_vent","Summoned vent never uses the floating metal ring")
	check(smoke.kind=="vent_source" and smoke.lift==0 and smoke.angle==0,"Vent stays grounded and never spins around the player")
	check(fire.alpha>smoke.alpha,"Vent ignites only when its linked attack is active")
	var mock=MockSession.new()
	var caster := {"id":1,"p":Vector2.ZERO,"choreo_serial":1,"choreo_steps":[{"op":"construct","p":Vector2(100,100),"link":"test"},{"op":"motion","to":Vector2(200,0),"warp":false}]}
	mock.raid.hazards=[{"source":1,"choreo_serial":1,"p":Vector2(100,100),"origin":Vector2(100,100),"link":"test"},{"source":1,"choreo_serial":1,"p":Vector2(200,0),"origin":Vector2(200,0)}]
	preload("res://scripts/boss_choreography.gd").resolve_positions(mock,caster)
	check(mock.raid.hazards[0].p==caster.choreo_steps[0].p,"Summon relocates its warning before release, never after")
	check(mock.raid.hazards[1].p==caster.choreo_steps[1].to,"Blocked dash and follow-up warning resolve to one reachable point")
	check(EnemyFrames.pose({"id":1,"type":4,"hp":100,"attack_time":1,"choreo_cast":true},0) in [8,9],"Knight never includes its old baked slash alongside a choreographed attack")
	var particles=Particles.new(); root.add_child(particles)
	var lane := {"shape":"lane","p":Vector2.ZERO,"aim":Vector2.RIGHT,"radius":200.0,"inner":20.0}
	check(particles.safe_particle(lane,Vector2(80,0),2),"Particles can occupy the actual lane centre")
	check(not particles.safe_particle(lane,Vector2(80,19),2),"Particle bodies cannot leak across the actual lane edge")
	var cone := {"shape":"cone","p":Vector2.ZERO,"aim":Vector2.DOWN,"radius":120.0,"inner":0.0,"arc":.5}
	check(particles.safe_particle(cone,Vector2(0,60),2),"Directional particles occupy the actual downward attack")
	check(not particles.safe_particle(cone,Vector2(60,0),2),"Particles never decorate the wrong side of a downward attack")
	for name in ["thunder_impact","flame_vent"]:
		var texture=Language.Art.texture("storm",name)
		check(texture!=null and texture.resource_path.contains("readable/"),"Standalone new emission texture loads")
	for name in preload("res://scripts/boss_entity_contacts.gd").DATA:
		var texture=Language.Art.texture("knight",name)
		check(texture!=null and texture.resource_path.ends_with(name+".png"),"Each regenerated entity uses one independent PNG: "+name)
	particles.queue_free(); await process_frame
	print("BOSS READABILITY ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
