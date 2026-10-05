extends SceneTree
# Runs real campaign simulation and VFX, with component-level CPU timings.
var session: TideSession
var field: Battlefield
var template: Dictionary
var stage := -1
var started := 0
var previous := 0
var simulation_us := 0
var samples: Dictionary = {}
var peak_particles := 0
var peak_hazards := 0
var peak_nodes := 0
class ReferenceParticles extends "res://output/performance-reference/combat_particles.gd":
	func update_mask(key: String,mask: Dictionary) -> void:
		for particle in particles:
			if particle.source==key and particle.has("mask"): particle.mask=mask
var cases: Array = [
	{"name":"large_idle_fx_on", "kind":14, "count":1, "mode":"full", "fight":false},
	{"name":"large_fighting", "kind":14, "count":1, "mode":"full", "fight":true},
	{"name":"40_large_fighting", "kind":14, "count":40, "mode":"full", "fight":true},
	{"name":"40_large_no_particle_draw", "kind":14, "count":40, "mode":"no_particle_draw", "fight":true},
	{"name":"40_large_no_combat_vfx", "kind":14, "count":40, "mode":"no_combat", "fight":true},
	{"name":"40_large_budget_400", "kind":14, "count":40, "mode":"budget_400", "fight":true},
	{"name":"bell_full", "boss":0, "mode":"full"},
	{"name":"queen_full", "boss":2, "mode":"full"},
	{"name":"storm_full", "boss":4, "mode":"full"},
	{"name":"dragon_full", "boss":6, "mode":"full"},
	{"name":"queen_no_damage_visual", "boss":2, "mode":"no_damage"},
	{"name":"storm_no_damage_visual", "boss":4, "mode":"no_damage"},
	{"name":"dragon_no_damage_visual", "boss":6, "mode":"no_damage"},
]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var requested := OS.get_cmdline_user_args()
	if not requested.is_empty():
		cases=cases.filter(func(c): return c.name==requested[0])
		if cases.is_empty(): quit(2); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,800)
	session=TideSession.new(); root.add_child(session)
	session.solo({"hero":0}); session.launch(false,1729)
	session.set_physics_process(false)
	for candidate in session.enemies:
		if not candidate.get("mini_boss",false) and not candidate.get("raid_boss",false):
			template=candidate.duplicate(true)
			break
	assert(not template.is_empty())
	field=Battlefield.new(); field.session=session; root.add_child(field)
	if "reference" in requested:
		for owner in [field.combat,field.combat.stylized,field.boss_fx.damage_visual]:
			var old: Node=owner.particles
			var index := old.get_index()
			owner.remove_child(old); old.queue_free()
			owner.particles=ReferenceParticles.new()
			owner.add_child(owner.particles); owner.move_child(owner.particles,index)
	for node in [field,field.combat,field.boss_fx,field.boss_fx.damage_visual]: node.set_process(false)
	next_case()
func next_case() -> void:
	stage+=1
	if stage>=cases.size(): quit(); return
	field.combat.reset(); field.boss_fx.reset()
	session.enemies.clear(); session.bullets.clear(); session.fire_zones.clear()
	session.raid.hazards=[]; session.raid.phase="boss"; session.raid.time=0.0
	var c: Dictionary=cases[stage]
	var center: Vector2=session.ruins.sites[0].p
	if c.has("boss"):
		var e := template.duplicate(true)
		e.id=10000; e.type=4; e.boss_kind=mini(int(c.boss),2)
		e.boss_name="Performance probe"; e.phase=1; e.sequence=0
		e.hp=100000.0; e.max_hp=100000.0; e.cd=0.0; e.p=center; e.home=center
		if int(c.boss)<3: e["raid_boss"]=true
		else:
			e["mini_boss"]=true; e["mini_kind"]=0
			if c.boss==6: e["dragon_boss"]=true
			else: e["wild_boss"]=true; e["wild_kind"]=1
		session.enemies.append(e)
	else:
		for i in int(c.count):
			var e := template.duplicate(true)
			e.id=10000+i; e.type=int(c.kind); e.hp=100000.0; e.max_hp=100000.0
			e.p=center+Vector2(20+(i%10)*18,30+(i/10)*18); e.home=e.p
			e.cd=0.0 if c.fight else 10000.0
			session.enemies.append(e)
	session.players[1].p=center+Vector2(90,30)
	session.players[1].invuln=10000.0; session.players[1].hp=1000.0
	field.camera=session.players[1].p
	field.boss_fx.damage_visual.visible=c.mode!="no_damage"
	field.combat.visible=c.mode!="no_combat"
	field.combat.particles.visible=c.mode!="no_particle_draw"
	session.running=true; session.rng.seed=1729
	samples={"frame":[],"simulation":[],"field":[],"combat":[],"boss":[],"damage":[]}
	peak_particles=0; peak_hazards=0; peak_nodes=0; simulation_us=0
	started=Time.get_ticks_usec(); previous=started
	print("START "+c.name)
func _physics_process(dt: float) -> bool:
	if stage<0: return false
	var begin := Time.get_ticks_usec()
	session.simulate(dt)
	simulation_us+=Time.get_ticks_usec()-begin
	return false
func measure(node: Node, dt: float, key: String, collect: bool) -> void:
	var begin := Time.get_ticks_usec()
	node._process(dt)
	if collect: samples[key].append((Time.get_ticks_usec()-begin)/1000.0)
func _process(dt: float) -> bool:
	if stage<0: return false
	var now := Time.get_ticks_usec()
	var collect := now-started>1500000
	if collect:
		samples.frame.append((now-previous)/1000.0)
		samples.simulation.append(simulation_us/1000.0)
	previous=now; simulation_us=0
	measure(field,dt,"field",collect)
	if cases[stage].mode!="no_combat": measure(field.combat,dt,"combat",collect)
	if cases[stage].mode=="budget_400" and field.combat.particles.particles.size()>400:
		# Diagnostic ablation only: retain the newest decorative particles.
		var excess: int=field.combat.particles.particles.size()-400
		field.combat.particles.particles.assign(field.combat.particles.particles.slice(excess))
	measure(field.boss_fx,dt,"boss",collect)
	if cases[stage].mode!="no_damage": measure(field.boss_fx.damage_visual,dt,"damage",collect)
	var particles: int=field.combat.particles.particles.size()+field.combat.stylized.particles.particles.size()+field.boss_fx.damage_visual.particles.particles.size()
	peak_particles=maxi(peak_particles,particles)
	peak_hazards=maxi(peak_hazards,session.raid.hazards.size())
	peak_nodes=maxi(peak_nodes,field.boss_fx.damage_visual.nodes.size())
	if now-started>=9000000:
		var report := {"case":cases[stage].name,"particles_peak":peak_particles,"hazards_peak":peak_hazards,"damage_nodes_peak":peak_nodes,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		for key in samples:
			var values: Array=samples[key]
			if values.is_empty(): continue
			values.sort()
			report[key+"_median_ms"]=values[values.size()/2]
			report[key+"_p95_ms"]=values[int(values.size()*.95)]
			report[key+"_max_ms"]=values.back()
		print(JSON.stringify(report))
		if "capture" in OS.get_cmdline_user_args(): root.get_texture().get_image().save_png("res://output/performance-"+str(cases[stage].name)+".png")
		next_case()
	return false
