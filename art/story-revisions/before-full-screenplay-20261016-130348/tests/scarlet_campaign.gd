extends SceneTree
const Campaign=preload("res://scripts/scarlet/campaign.gd")
var checks:=0
var failures:=0
func check(value: bool,text: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(text)
func _initialize() -> void: call_deferred("run")
func settle(c,prepared: bool,rescue: bool,side: bool) -> void:
	var loops:=0
	while not c.state.pending.is_empty() and loops<30:
		loops+=1
		var p: Dictionary=c.state.pending
		if p.kind=="question":
			check(not c.choose((int(p.answer)+1)%p.options.size()),"wrong evidence answer must not submit")
			check(c.choose(int(p.answer)),"correct evidence answer submits")
		elif not p.get("choices",[]).is_empty():
			check(not c.finish_presentation(),"skip cannot choose a branch")
			var slot:=0
			for i in p.choices.size():
				var choice: Dictionary=p.choices[i]
				if choice.key=="ambush_prepared" and choice.value==prepared: slot=i
				if choice.key=="queen_resolution" and choice.value==("rescue" if rescue else "leave"): slot=i
				if choice.key=="palace_approach" and choice.value==("side" if side else "front"): slot=i
			check(c.choose(slot),"explicit choice accepted")
		else: check(c.finish_presentation(),"presentation continuation commits")
	check(loops<30,"presentation chain terminates")
func win(c,prepared: bool,rescue: bool,side: bool) -> void:
	var loops:=0
	while c.combat.running and loops<20:
		loops+=1
		for g in c.combat.gadgets():
			if g.id=="crystal": continue
			if g.hero>=0: c.switch_hero(int(g.hero))
			c.hero_at=g.p
			if g.id=="shield":
				for frame in 900:
					if Vector2(c.enemies[0].p).distance_to(g.p)<=440: break
					c.combat.tick(.05)
			c.combat.use_gadget(g.id)
		if not c.state.pending.is_empty(): settle(c,prepared,rescue,side)
		if not c.combat.running: break
		for e in c.enemies.duplicate():
			if e.hp>0: c.combat.hit(e,100000,0)
		settle(c,prepared,rescue,side)
	check(not c.combat.running,"boss phase and finisher terminate")
func perform(c,q: Dictionary,prepared: bool,rescue: bool,side: bool) -> void:
	var n: Dictionary=c.current_node(q)
	if n.is_empty(): return
	if n.zone!=c.state.zone:
		check(n.zone in c.state.unlocked,"target zone is unlocked: "+n.zone)
		check(c.enter_zone(n.zone),"can visit target zone")
	settle(c,prepared,rescue,side)
	n=c.current_node(q)
	var visible: Array=c.objective_nodes()
	var use_node: Dictionary={}
	for item in visible:
		if item.get("id","")==n.id: use_node=item
	check(not use_node.is_empty(),"task exposes real authored node: "+str(n.id))
	if use_node.is_empty(): return
	c.hero_at=use_node.p
	if int(n.get("hero",-1))>=0: c.switch_hero(int(n.hero)); c.hero_at=use_node.p
	check(c.use(use_node),"interaction accepted: "+str(n.id))
	if not c.fieldwork.active.is_empty():
		for part in 3:
			check(c.fieldwork.select_part(part),"physical part can be selected: "+str(n.id))
			if c.fieldwork.calibration():
				for frame in 240:
					if c.fieldwork.challenge()=="alignment": c.fieldwork.adjust(.025)
					c.fieldwork.tick(.05,c.fieldwork.challenge()=="tension")
					var band: Vector2=c.fieldwork.band()
					if c.fieldwork.flash<=0 and c.fieldwork.needle()>band.x and c.fieldwork.needle()<band.y:
						if c.fieldwork.challenge()=="tension": c.fieldwork.tick(.05,false); check(part in c.fieldwork.done(),"tension settles when released inside safe interval")
						else: check(c.fieldwork.press(),"calibration accepted inside safe interval")
						break
			else:
				for frame in 26: c.fieldwork.tick(.05,true)
		check(c.fieldwork.submit(),"all physical steps are required before submitting")
	settle(c,prepared,rescue,side)
	if not c.interaction.is_empty():
		for i in 100: c.update(.05,Vector2.ZERO,true)
	if c.combat.running: win(c,prepared,rescue,side)
	if not c.escort_group.is_empty():
		for person in c.escort_group: person.p=c.receive_at(); person.hp=80
		c.hero_at=c.receive_at(); check(c.receive_escort(),"escort requires all people received")
	while not c.state.trial_task.is_empty():
		var point: Dictionary=c.objective_nodes()[0]; c.hero_at=point.p; check(c.use(point),"real trial sailing checkpoint is visited")
	settle(c,prepared,rescue,side)
func play(prepared: bool,rescue: bool,side: bool) -> void:
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state(); c.begin()
	check(c.content.main_order.size()==40 and c.content.quests.size()==46,"forty main and six optional tasks")
	var guard:=0
	while not c.current_main().is_empty() and guard<350:
		guard+=1
		var q: Dictionary=c.current_main()
		if q.act!=c.state.act:
			check(c.enter_zone("%d:0" % int(c.state.act)),"return to actual camp before chapter transport")
			check(c.next_act(),"explicit transport unlocks next chapter")
			settle(c,prepared,rescue,side)
		perform(c,q,prepared,rescue,side)
	check(guard<350,"all main tasks complete without deadlock: "+str(c.current_main().get("id","done"))+" step="+str(c.current_node().get("id","")))
	check(c.state.ending_seen and c.state.completed.size()==40,"epilogue really completed")
	check(c.state.world.get("tide_ended",false) and c.state.sword=="broken","contract destroyed in both endings")
	check(c.state.choices.get("queen_resolution","")==("rescue" if rescue else "leave"),"ending branch retained")
	check(c.state.party==[0,1,2],"all companions return")
	for sid in ["S01","S02","S03","S04","S05","S06"]:
		check(c.accept(sid),"postgame optional task remains available")
		var q: Dictionary=c.content.quests[sid]
		var count:=0
		while not sid in c.state.completed and count<15:
			count+=1; perform(c,q,prepared,rescue,side)
		check(sid in c.state.completed,"optional story can complete: "+sid)
	check(c.state.completed.size()==46,"all authored tasks complete")
	var coins: float=c.state.coins
	check(not c.commit_quest("R-E01") and c.state.coins==coins,"completion is idempotent")
	var snapshot: Dictionary=c.state.duplicate(true)
	c.request_scene("two-cups",{},true); c.finish_presentation()
	check(c.state.completed==snapshot.completed and c.state.choices==snapshot.choices and c.state.coins==snapshot.coins,"memory replay has no world consequences")
func run() -> void:
	for prepared in [false,true]:
		for rescue in [false,true]: play(prepared,rescue,prepared)
	var c=Campaign.new(); c.state=c.new_state(); c.path="user://scarlet-test-save.json"
	c.request_scene("conditions",{"kind":"intro","qid":"R-P03"}); c.update_page(3); check(c.save_campaign(),"atomic save succeeds")
	var d=Campaign.new(); check(d.load_campaign(c.path),"new schema loads")
	check(d.state.pending.page==3 and d.state.pending.id=="conditions","reading cursor and continuation survive reload")
	check(not d.enter_zone("6:6"),"locked region rejected by authority")
	check(not d.valid_save({"version":1}),"legacy records are not misread")
	d.state.party=[0,1]; check(not d.switch_hero(2),"absent Yayu cannot be controlled")
	for b in c.content.bosses:
		c.state.zone="6:6"; c.state.act=6; c.state.stage=6
		c.combat.start("R-6-06","R-6-06:0",b,1)
		for frame in 80: c.combat.tick(.05)
		check(c.enemies[0].attack>0,"each boss has actual attack patterns: "+b)
	print("SCARLET_CAMPAIGN %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
