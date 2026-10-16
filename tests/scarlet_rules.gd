extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func make():
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false; return c
func run() -> void:
	var c=make()
	# Verify event placement against original map collision and its reachable component.
	for key in c.content.zones:
		c.state.zone=key; c.state.act=int(key.get_slice(":",0)); c.state.stage=int(key.get_slice(":",1))
		var geography=c.terrain()
		check(c.walkable(c.spawn_at()),"original entrance is walkable "+key)
		check(not geography.cells.is_empty(),"original entrance has a reachable floor "+key)
		check(ResourceLoader.exists(geography.scene_path(true)),"original OpenGL scene exists "+key)
		check(ResourceLoader.exists(geography.scene_path(false)),"original Forward+ scene exists "+key)
		check(geography.ratio==geography.region.extent/1800.0,"original native dimensions retained "+key)
		for q in c.content.quests.values():
			for n in q.nodes:
				if n.zone!=key: continue
				var p: Vector2=c.place(Vector2(n.at[0],n.at[1]))
				check(c.walkable(p),"task object on original floor "+n.id)
				check(geography.reachable.has(Vector2i((p/20).round())),"original entrance can reach task object "+n.id)
	# Use the actual cabinet objective after the emergency ADV briefing.
	c=make(); c.state.completed=["R-P01"]; c.state.accepted=["R-P02"]; c.state.steps["R-P02"]=1
	var n: Dictionary=c.objective_nodes()[0]
	c.hero_at=Vector2(100,100); check(not c.use(n),"interactions are range gated")
	c.hero_at=n.p; check(c.use(n),"cabinet opens physical work")
	check(not c.fieldwork.submit(),"one click cannot complete cabinet")
	for part in 3:
		c.fieldwork.select_part(part)
		if c.fieldwork.calibration():
			for frame in 260:
				c.fieldwork.tick(.05,false)
				var band: Vector2=c.fieldwork.band()
				if c.fieldwork.needle()>band.x and c.fieldwork.needle()<band.y: c.fieldwork.press(); break
		else:
			for frame in 26: c.fieldwork.tick(.05,true)
	check(c.step_count(c.content.quests["R-P02"])==1,"physical work needs explicit submission")
	c.fieldwork.submit()
	check(c.step_count(c.content.quests["R-P02"])==2,"cabinet submits only completed procedure")
	c.hero_at=c.objective_nodes()[0].p; c.use(c.objective_nodes()[0]); c.attack_cd=0; c.action_time=0
	check(c.attack(Vector2.UP),"prologue battle works inside camp")
	c=make(); c.state.zone="1:6"; c.state.stage=6
	c.combat.start("R-1-06","R-1-06:1","inquisitor",1)
	c.combat.hit(c.enemies[0],100000,0)
	check(c.enemies[0].hp==1 and c.combat.phase==0,"cannot bypass required boss mechanisms by overdamage")
	for g in c.combat.gadgets(): c.hero_at=g.p; c.combat.use_gadget(g.id)
	c.combat.hit(c.enemies[0],100000,0)
	check(c.combat.phase==1,"mechanisms enable next boss phase")
	c.state.hp=0; c.update(.01,Vector2.ZERO)
	check(c.state.pending.kind=="death","death creates a stable retry decision")
	c.finish_presentation(); check(c.combat.phase==1 and c.state.hp==c.max_hp(),"retry retains phase with full health")
	check(c.combat.opening_grace>2,"retry provides a visible safe preparation window")
	# Independent save/read tests use the real on-disk schema, including JSON numeric conversion.
	c.save_enabled=true; c.path="user://scarlet-rules-fixture.json"; c.save_campaign()
	var d=Campaign.new(); check(d.load_campaign(c.path),"boss checkpoint reloads")
	check(d.combat.phase==1 and d.combat.running,"boss phase survives exit and reload")
	c=make(); c.save_enabled=true; c.path="user://scarlet-escort-fixture.json"
	var q: Dictionary=c.content.quests["R-5-02"]
	c.state.zone="5:2"; c.state.act=5; c.state.stage=2; c.state.steps[q.id]=2
	c.start_escort(q.id,q.nodes[2])
	check(c.escort_group.size()==7,"seven fixed survivors exist")
	c.escort_group[0].following=true; c.escort_group[0].p=Vector2(780,1000)
	c.escort_group[1].hp=0; c.save_campaign()
	d=Campaign.new(); check(d.load_campaign(c.path),"escort checkpoint reloads")
	check(d.escort_group.size()==7 and d.escort_group[0].p==Vector2(780,1000) and d.escort_group[0].following,"rescued person's actual state persists")
	check(d.escort_group[1].hp==0,"downed person remains recoverable after reload")
	check(not d.receive_escort(),"cannot finish rescue with people still missing")
	d.combat.clear(); d.hero_at=d.escort_group[1].p; d.update(.05,Vector2.ZERO,true)
	check(d.escort_group[1].hp>0,"downed survivor can be helped up")
	d.state.world.surge_clock=10.0; d.update(.05,Vector2.ZERO)
	check(not d.water_hazard.is_empty() and d.water_hazard.delay>5,"red tide has advance warning")
	c=make(); c.state.zone="2:6"; c.state.act=2; c.state.stage=6
	c.combat.start("R-2-06","R-2-06:1","judge",1)
	check(not c.walkable(Vector2(600,900)),"judge partition physically blocks movement")
	for g in c.combat.gadgets():
		if g.id=="verdict:0": c.hero_at=g.p; c.combat.use_gadget(g.id)
	check(c.combat.switches.get("verdict:0",false) and c.combat.barriers().size()==2,"releasing verdict removes its matching partition without removing original walls")
	c=make(); c.state.zone="5:1"; c.state.act=5; c.state.stage=1
	for id in c.content.main_order:
		if id=="R-5-01": break
		c.state.completed.append(id)
	c.state.accepted=["R-5-01"]; c.state.steps["R-5-01"]=2
	var trial: Dictionary=c.objective_nodes()[0]; c.hero_at=trial.p; c.use(trial)
	check(not c.state.trial_task.is_empty(),"sailing enters an actual controllable trial")
	check(c.walkable(Vector2(-450,1250)),"trial can sail over water beyond dock footprint")
	check(not c.attack(Vector2.UP),"sailing cannot trigger land attacks")
	c.save_enabled=true; c.path="user://scarlet-trial-fixture.json"; c.hero_at=Vector2(-450,1250); c.save_campaign()
	d=Campaign.new(); check(d.load_campaign(c.path),"trial state reloads")
	check(d.hero_at==Vector2(-450,1250) and not d.state.trial_task.is_empty(),"continuing a voyage does not reset to land")
	print("SCARLET_RULES %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
