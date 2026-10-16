extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
var checks:=0
var failures:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func setup(id: String):
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	var qid:=id.get_slice(":",0); var q: Dictionary=c.content.quests[qid]
	for previous in c.content.main_order:
		if previous==qid: break
		c.state.completed.append(previous)
	c.state.accepted=[qid]
	c.state.steps[qid]=int(id.get_slice(":",1)); c.state.pending={}
	var n: Dictionary=c.current_node(q).duplicate(true)
	c.state.zone=n.zone; c.state.act=int(n.zone.get_slice(":",0)); c.state.stage=int(n.zone.get_slice(":",1))
	c.state.party=[0,1,2]; c.state.hero=maxi(0,int(n.get("hero",0)))
	c.state.choices.palace_approach="side"; c.state.choices.ambush_prepared=true; c.state.world.tide_ended=true
	n.qid=qid; n.p=c.place(Vector2(n.at[0],n.at[1])); c.hero_at=n.p
	return {"c":c,"n":n}
func operate(f,part: int) -> void:
	check(f.select_part(part),"select authored part")
	if f.calibration():
		var success:=false
		for frame in 260:
			if f.challenge()=="alignment": f.adjust(.02)
			f.tick(.05,f.challenge()=="tension")
			var band: Vector2=f.band()
			if f.flash<=0 and f.needle()>band.x+.01 and f.needle()<band.y-.01:
				if f.challenge()=="tension": f.tick(.05,false); success=part in f.done()
				else: success=f.press()
				break
		check(success,"physical calibration must be solvable")
	else:
		for frame in 26: f.tick(.05,true)
	check(part in f.done(),"operation actually records one part")
func run() -> void:
	var fixture=setup("R-P02:1"); var c=fixture.c; var f=c.fieldwork
	check(c.use(fixture.n),"normal interaction opens fieldwork")
	check(not f.submit(),"single E cannot finish a mechanism")
	for frame in 100: f.tick(.05,true)
	check(f.done().is_empty(),"holding E without selecting a part cannot skip procedure")
	check(not f.select_part(2),"unsafe order is rejected")
	check(f.select_part(0),"first operation accepted")
	for frame in 8: f.tick(.05,true)
	var partial: float=f.progress
	f.tick(.05,false); check(f.progress<partial,"releasing sustained action loses unstable partial progress")
	operate(f,0); f.cancel()
	check(c.state.steps["R-P02"]==1 and c.state.fieldwork[fixture.n.id].done==[0],"cancel preserves finished part without advancing quest")
	check(c.use(fixture.n),"reopen current interaction")
	check(f.done()==[0],"reopening does not repeat completed work")
	check(not c.switch_hero(1) and not c.attack(Vector2.UP) and not c.dodge(Vector2.UP),"work blocks incompatible actor actions")
	check(not c.enter_zone("1:0"),"work cannot be stranded by travel")
	check(f.select_part(0) and f.feedback_good,"completed parts can be reread")
	c.save_enabled=true; c.path="user://fieldwork-resume-test.json"; check(c.save_campaign(),"partial work saves")
	var d=Campaign.new(); check(d.load_campaign(c.path),"work survives real JSON round trip")
	d.save_enabled=false; check(d.state.fieldwork[fixture.n.id].done==[0],"saved numeric part IDs normalize")
	check(d.fieldwork.start(fixture.n),"saved work resumes at the same physical object")
	operate(d.fieldwork,1); operate(d.fieldwork,2)
	check(d.step_count(d.content.quests["R-P02"])==1,"finished parts still require explicit confirmation")
	check(d.fieldwork.submit(),"explicit confirm advances one node")
	check(not d.fieldwork.submit() and d.step_count(d.content.quests["R-P02"])==2,"duplicate submit is harmless")
	# Old records remain valid, malformed fieldwork cannot be loaded.
	var old: Dictionary=c.state.duplicate(true); old.erase("fieldwork"); old.erase("fieldwork_relaxed")
	check(c.valid_save(old),"pre-feature saves remain valid")
	var broken: Dictionary=c.state.duplicate(true); broken.fieldwork[fixture.n.id].done=[0,0]
	check(not c.valid_save(broken),"duplicate completed parts rejected")
	broken=c.state.duplicate(true); broken.fieldwork[fixture.n.id].done=[2]
	check(not c.valid_save(broken),"impossible saved procedure rejected")
	# Canonical coordinates and hero restrictions are checked by the authority itself.
	f.cancel(); c.hero_at+=Vector2(1000,1000)
	var spoof: Dictionary=fixture.n.duplicate(); spoof.p=c.hero_at
	check(not f.start(spoof),"spoofed UI coordinates cannot bypass proximity")
	fixture=setup("R-1-04:4"); c=fixture.c; c.state.hero=0
	check(not c.fieldwork.start(fixture.n),"required hero cannot be bypassed through activity API")
	# Every authored physical object can finish, including all three challenge types.
	var challenge_types: Dictionary={}
	for id in c.fieldwork.profiles:
		fixture=setup(id); c=fixture.c; f=c.fieldwork
		check(c.use(fixture.n),"campaign opens authored object "+id)
		check(not f.active.is_empty(),"physical gameplay exists for "+id)
		if f.active.is_empty(): continue
		if f.profile().mode=="survey":
			check(not c.state.facts.has(fixture.n.fact),"clue not granted on opening")
			for part in [2,0,1]: operate(f,part)
			check(not c.state.facts.has(fixture.n.fact),"unsubmitted evidence stays uncommitted")
		else:
			for part in 3: operate(f,part)
			if int(f.profile().calibrate)>=0: challenge_types[f.challenge()]=true
		check(f.ready() and f.submit(),"all authored objects have a completion path "+id)
		check(c.state.fieldwork[id].finished,"world state retains physical result")
		if fixture.n.kind=="clue": check(c.state.facts.has(fixture.n.fact) and c.state.pending.kind=="scene","survey returns to original clue narrative")
	check(challenge_types.size()==3,"tension, alignment and timing are all exercised")
	fixture=setup("R-1-04:1"); c=fixture.c; f=c.fieldwork; f.start(fixture.n); operate(f,0); f.select_part(1)
	for frame in 60: f.tick(.05,true)
	check(not 1 in f.done(),"over-tightening a rope never auto-succeeds")
	var width: float=f.band().y-f.band().x; f.set_relaxed(true)
	check(f.band().y-f.band().x>width,"accessibility mode expands success interval")
	f.cancel()
	print("SCARLET_FIELDWORK %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
