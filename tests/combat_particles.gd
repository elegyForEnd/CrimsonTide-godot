extends SceneTree
const Particles=preload("res://scripts/combat_particles.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var engine=Particles.new(); root.add_child(engine)
	var styles: Dictionary={}
	for weapon in 21:
		engine.reset()
		var style := engine.weapon_style(weapon); styles[style]=true
		engine.burst(Vector2.ZERO,Vector2.RIGHT,Color.CYAN,style,16)
		check(engine.particles.size()>=16,"All weapons own a physical particle burst")
		var before: Vector2=engine.particles[0].p
		engine.advance(.05)
		check(engine.particles[0].p.distance_to(before)>1,"Particles move with velocity, not a texture stamp")
		check(engine.particles[0].age>0,"Life curve advances")
	check(styles.size()>=10,"Weapon materials have distinct particles")
	engine.reset(); engine.start("charge",Vector2.ZERO,Vector2.RIGHT,Color.CYAN,"ice","gather",1,40,100)
	engine.advance(.06)
	var dist: float=engine.particles[0].p.length()
	engine.advance(.05)
	check(engine.particles[0].p.length()<dist,"Charge fragments converge inward")
	engine.move("charge",Vector2(50,0))
	check(engine.particles[0].target==Vector2(50,0),"Charge follows its live source")
	engine.stop("charge")
	check(engine.emitters.is_empty() and engine.particles.all(func(p): return not p.gather),"Interrupt stops gathering and begins a short fade")
	engine.advance(.13)
	check(engine.particles.is_empty(),"Cancelled charge fades completely")
	engine.reset()
	var hazard={"p":Vector2.ZERO,"aim":Vector2.RIGHT,"shape":"gap_ring","radius":150.0,"inner":75.0,"gap":.6}
	engine.start("ring",Vector2.ZERO,Vector2.RIGHT,Color.CYAN,"electric","ring",1,150,180,75)
	engine.emitters.ring["mask"]=hazard
	for i in 15:
		engine.advance(.025)
		for particle in engine.particles: check(engine.safe_particle(hazard,particle.p,particle.size),"Particle including glow stays out of safe center and opening")
	check(not engine.particles.is_empty(),"Safety clipping still leaves visible ring particles")
	engine.reset()
	for i in 100: engine.start(str(i),Vector2.ZERO,Vector2.RIGHT,Color.WHITE,"spark","ambient",1)
	check(engine.emitters.size()<=engine.MAX_EMITTERS,"Emitter budget remains bounded")
	for i in 2000: engine.spawn(Vector2.ZERO,Vector2.RIGHT,Color.WHITE,"spark")
	check(engine.particles.size()<=engine.MAX_PARTICLES,"Particle budget remains bounded")
	engine.reset(); check(engine.emitters.is_empty() and engine.particles.is_empty(),"Area reset clears all channels")
	var fx=FX.new(); root.add_child(fx)
	for hero in 4:
		for weapon in 21:
			fx.reset()
			fx.event({"kind":"strike","p":Vector2(100,100),"aim":Vector2.DOWN,"id":1,"weapon":Catalog.weapon_family(weapon),"weapon_index":weapon,"combo":2,"reach":112.0},hero)
			check(not fx.particles.particles.is_empty(),"Four heroes and all 21 weapons emit particles from combat events")
		fx.reset(); fx.event({"kind":"skill","p":Vector2(100,100),"aim":Vector2.RIGHT,"id":1,"hero":hero},hero)
		check(fx.particles.particles.size()>=44,"Every hero ultimate owns its material burst")
	fx.queue_free(); engine.queue_free(); await process_frame
	print("COMBAT PARTICLES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
