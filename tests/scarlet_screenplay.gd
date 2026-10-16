extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
var checks:=0
var failures:=0
var ending:="A"
var prepared:=true
var query_count:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func settle(c) -> void:
	var guard:=0
	while not c.state.pending.is_empty() and guard<100:
		guard+=1
		var p: Dictionary=c.state.pending
		if p.kind=="question":
			check(not c.choose((int(p.answer)+1)%p.options.size()),"incorrect evidence cannot progress")
			check(c.choose(int(p.answer)),"correct evidence progresses")
		elif not p.get("choices",[]).is_empty():
			check(not c.finish_presentation(),"skip never selects an answer")
			var slot:=0
			if p.id=="06-13":
				check(not c.state.choices.has("resolution"),"no ending chosen before answer")
				check(c.state.world.get("pre_choice",false),"stable checkpoint precedes answer")
				slot=0 if ending=="A" else 1
			elif p.id=="confirm-resolution":
				check(not c.state.choices.has("resolution"),"first click does not commit ending")
			elif p.id=="06-06":
				slot=query_count if query_count<3 else 3; query_count+=1
			elif p.id=="03-01": slot=0 if prepared else 1
			elif p.id=="01-03": slot=0 if prepared else 1
			elif p.id=="05-09": slot=0 if prepared else 1
			check(c.choose(slot),"explicit choice accepted: "+str(p.id))
		else: check(c.finish_presentation(),"scene continuation: "+str(p.get("id","")))
	check(guard<100,"presentation chain terminates")
func win(c) -> void:
	var guard:=0
	while c.combat.running and guard<25:
		guard+=1
		for g in c.combat.gadgets():
			if g.id=="crystal": continue
			if g.hero>=0: c.switch_hero(int(g.hero))
			c.hero_at=g.p
			if g.id=="shield": c.enemies[0].p=g.p
			check(c.combat.use_gadget(g.id),"boss/stealth gadget: "+str(g.id))
			if not c.combat.running: break
		settle(c)
		if not c.combat.running: break
		for e in c.enemies.duplicate():
			if e.hp>0: c.combat.hit(e,100000,0)
		settle(c)
	check(not c.combat.running,"boss terminates without damaging unchosen core")
func physical(c) -> void:
	if c.fieldwork.active.is_empty(): return
	check(not c.fieldwork.submit(),"partial physical work cannot submit")
	for part in 3:
		check(c.fieldwork.select_part(part),"physical part selectable")
		if c.fieldwork.calibration():
			for frame in 300:
				if c.fieldwork.challenge()=="alignment": c.fieldwork.adjust(.025)
				c.fieldwork.tick(.05,c.fieldwork.challenge()=="tension")
				var band: Vector2=c.fieldwork.band()
				if c.fieldwork.flash<=0 and c.fieldwork.needle()>band.x and c.fieldwork.needle()<band.y:
					if c.fieldwork.challenge()=="tension": c.fieldwork.tick(.05,false)
					else: c.fieldwork.press()
					break
		else:
			for frame in 26: c.fieldwork.tick(.05,true)
	check(c.fieldwork.submit(),"all three physical parts submit")
func perform(c,q: Dictionary) -> void:
	var n: Dictionary=c.current_node(q)
	if n.is_empty(): check(false,"unexpected exhausted quest "+q.id); return
	if n.zone!=c.state.zone:
		check(c.enter_zone(n.zone),"travel to actual objective "+str(n.zone))
	settle(c)
	if q.id in c.state.completed: return
	n=c.current_node(q)
	if n.is_empty(): return
	var expected: String=n.id if q.id in c.state.accepted else "offer:"+q.id
	var use_node: Dictionary={}
	for item in c.objective_nodes():
		if item.id==expected: use_node=item; break
	check(not use_node.is_empty(),"exposes objective "+expected)
	if use_node.is_empty(): return
	c.hero_at=use_node.p
	if int(n.get("hero",-1))>=0:
		check(c.switch_hero(int(n.hero)),"required hero present: "+str(n.hero)); c.hero_at=use_node.p
	check(c.use(use_node),"interact "+expected)
	settle(c); physical(c); settle(c)
	if c.combat.running: win(c)
	if not c.escort_group.is_empty():
		if c.escort_group.size()>1:
			c.hero_at=c.receive_at()
			for person in c.escort_group: person.p=c.receive_at()
			c.escort_group[-1].p=c.receive_at()+Vector2(300,0)
			check(not c.receive_escort(),"cannot handoff with one person missing")
		for person in c.escort_group: person.p=c.receive_at(); person.hp=80
		c.hero_at=c.receive_at(); check(c.receive_escort(),"all named people actually received")
	while not c.state.trial_task.is_empty():
		var point: Dictionary=c.objective_nodes()[0]; c.hero_at=point.p
		check(c.use(point),"visit actual sailing marker")
	settle(c)
func play(route: String,prep: bool) -> void:
	ending=route; prepared=prep; query_count=0
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state(); c.begin()
	check(c.content.revision=="scarlet-screenplay-2","new narrative version")
	check(c.content.main_order.size()==40 and c.content.quests.size()==46,"40 main / 6 side")
	check(not c.accept("S01"),"cannot accept locked or remote task from journal")
	settle(c)
	var guard:=0
	while not c.current_main().is_empty() and guard<450:
		guard+=1
		var q: Dictionary=c.current_main()
		if int(q.act)!=int(c.state.act):
			check(c.enter_zone("%d:0" % int(c.state.act)),"return to camp before transport")
			check(c.next_act(),"explicit chapter transport")
			settle(c)
		perform(c,q)
	check(guard<450,"main route completes: "+str(c.current_main().get("id","done"))+" "+str(c.current_node().get("id","")))
	check(c.state.ending_seen and c.state.completed.size()==40,"ending handoff complete")
	check(c.state.choices.get("resolution","")==route,"only confirmed branch persists")
	check(c.state.world.get("forced_array_disabled",false),"forced array disarmed before choosing")
	check(not c.state.choices.has("queen_resolution"),"retired rescue/leave ending cannot leak")
	check(c.state.party==[0,1,2],"companions remain")
	check(c.state.facts.has("DOC-10") and c.state.facts.has("DOC-11"),"authentication and medical cost explained before ending")
	if route=="A":
		check(c.state.sword=="contract" and c.state.world.get("heart_intact",false),"acceptance preserves heart and seal")
		check(c.state.world.get("city_power",false) and not c.state.world.get("queen_alive",true),"acceptance restores utility at established medical cost")
	else:
		check(c.state.sword=="broken" and not c.state.world.get("heart_intact",true),"refusal breaks heart and seal only after ordered operations")
		check(not c.state.world.get("city_power",true) and c.state.world.get("queen_in_custody",false),"refusal loses utility and rescues Queen to custody")
	for sid in ["S01","S02","S03","S04","S05","S06"]:
		var q: Dictionary=c.content.quests[sid]
		var count:=0
		while not sid in c.state.completed and count<30:
			count+=1; perform(c,q)
		check(sid in c.state.completed,"optional story completes: "+sid)
		var xp: float=c.state.xp
		check(not c.commit_quest(sid) and c.state.xp==xp,"repeat handoff cannot grant reward twice")
	check(c.valid_save(c.state),"new state can roundtrip")
func run() -> void:
	play("A",true); play("R",false)
	persistence()
	print("SCREENPLAY: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func persistence() -> void:
	var path: String="user://screenplay-choice-%d.json" % OS.get_process_id()
	var c=Campaign.new(); c.state=c.new_state(); c.path=path
	for qid in c.content.main_order:
		if qid=="R-6-06": break
		c.state.completed.append(qid)
	c.state.accepted=["R-6-06"]; c.state.zone="6:6"; c.state.act=6; c.state.stage=6
	c.state.world.pre_choice=true; c.hero_at=c.spawn_at(); c.save_checkpoint(".pre-choice")
	c.request_scene("06-13",{"kind":"step","qid":"R-6-06","node":"R-6-06:0"})
	check(c.choose(0),"first click opens acceptance confirmation")
	check(not c.state.choices.has("resolution"),"confirmation pending does not select route")
	check(c.save_campaign(),"confirmation persists to disk")
	var d=Campaign.new(); check(d.load_campaign(path),"confirmation reloads")
	check(d.state.pending.id=="confirm-resolution" and not d.state.choices.has("resolution"),"reload preserves uncommitted confirmation")
	check(d.choose(1) and d.state.pending.id=="06-13","reconsider returns to both answers")
	check(d.choose(2),"both costs can be reviewed without selecting")
	while d.state.pending.get("kind","")=="scene": d.finish_presentation()
	check(d.state.pending.id=="06-13" and not d.state.choices.has("resolution"),"cost review returns to safe decision")
	check(d.choose(1) and d.choose(0),"refusal commits only at second confirmation")
	check(d.state.choices.resolution=="R" and not d.state.world.get("tide_ended",false),"answer alone does not destroy heart")
	d.state.ending_collection=["A"]; d.state.gallery=["cg-01a"]
	check(d.restore_snapshot(".pre-choice"),"stable answer snapshot restores")
	check(not d.state.choices.has("resolution") and not d.state.world.get("tide_ended",false),"restoring clears branch world flags")
	check(d.state.ending_collection==["A"] and "cg-01a" in d.state.gallery,"restoring retains only collection metadata")
	var old_path: String="user://screenplay-old-slot-%d.json" % OS.get_process_id()
	var old: Dictionary=c.new_state(); old.revision="scarlet-1"
	var file:=FileAccess.open(old_path,FileAccess.WRITE); file.store_string(JSON.stringify(old)); file.close()
	var original:=FileAccess.get_file_as_string(old_path)
	var e=Campaign.new(); check(e.load_campaign(old_path),"old narrative opens an independent new slot")
	check(e.path.ends_with(".crown-city.json") and e.state.completed.is_empty(),"old step numbers never migrate into new quest sequence")
	check(FileAccess.get_file_as_string(old_path)==original,"old save bytes are untouched")
	for base in [path,old_path]:
		for suffix in ["",".bak",".tmp",".pre-choice",".branch-R",".after-finale",".crown-city.json"]:
			if FileAccess.file_exists(base+suffix): DirAccess.remove_absolute(base+suffix)
