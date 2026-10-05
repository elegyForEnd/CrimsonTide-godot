extends SceneTree
const Build = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")
const Art = preload("res://scripts/rogue_build_art.gd")
var checks := 0
var failures := 0
var s: TideSession
var p: Dictionary
var e: Dictionary
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func reset() -> void:
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,431)
	p=s.players[1]; p.rogue_selection={}; p.build_reward_queue=[]
	s.raid.phase="rogue_exit"
	s.roguelike.equip(s,p,Content.make_weapon(0,0))
	p.build_forge_level=5; p.build_forge_bound=p.equipped.weapon.instance_id
	s.enemies.clear(); s.spawn_enemy(s.ruins.move(p.p,Vector2(50,0)),0)
	e=s.enemies.back(); s.roguelike.combat.setup_minion(e,0,0,false,s.rng)
	e.hp=100000; e.max_hp=e.hp; e.stagger=9999
	s.raid.phase="rogue_combat"; p.attack=0; p.swing_time=0; p.pending_strike=false; p.cast_time=0
func sequence(tokens: String) -> void:
	p.build_inputs=[]; p.build_hero_cd=0; p.build_combo_time=0
	for token in tokens:
		if token in ["<",">"]:
			if token=="<": p.build_back_time=s.elapsed
			elif token==">": s.inputs[p.id]={"move":p.aim}
			continue
		s.elapsed+=.35
		Build.action_event(s,p,token)
		if token=="A":
			var ctx := Build.context(s,p,"attack")
			Build.hit_event(s,p,e,10,false,ctx)
			p["rules_last_route"]=int(ctx.get("route",-1))
		elif token in ["S","U"]:
			var ctx := Build.context(s,p,"art" if token=="S" else "skill")
			if ctx.get("hero_route",-1)>=0: Build.hit_event(s,p,e,10,false,ctx)
			p["rules_last_route"]=int(ctx.get("route",-1))
		else: p["rules_last_route"]=int(p.get("build_next_route",-1))
func run() -> void:
	s=TideSession.new(); root.add_child(s); s.set_physics_process(false)
	reset()
	# Every runtime ID has a nonempty, distinct painted atlas region.
	var seen: Dictionary={}
	for category in ["weapons","gear","talents","engravings","cores"]:
		for def in Content.data[category]:
			var icon: Texture2D=Art.icon(str(def.id))
			check(icon!=null and icon.get_width()>4 and icon.get_height()>4,"Painted icon exists: "+str(def.id))
			var key := str(icon.atlas.resource_path)+str(icon.region)
			check(not seen.has(key),"Independent painted region: "+str(def.id)); seen[key]=true
	# Test32 input routes, using accepted hit edges, not held-input frame counting.
	for family_index in 4:
		reset(); p.weapon=600+[0,12,24,36][family_index]
		for i in 4:
			p.rules_last_route=-1; s.inputs[p.id]={}
			sequence(Build.CM_ROUTES[family_index][i])
			check(int(p.rules_last_route)==i or int(p.get("build_next_route",-1))==i,"Family combo CM%02d" % (family_index*4+i+1))
	for hero in 4:
		reset(); p.hero=hero
		for i in 4:
			s.inputs[p.id]={}; sequence(Build.HC_ROUTES[hero][i])
			check(p.build_hero_cd>0,"Hero combo HC%02d" % (hero*4+i+1))
	reset()
	Build.action_event(s,p,"A"); Build.context(s,p,"attack")
	Build.action_event(s,p,"S")
	check(p.build_inputs.size()==1,"Missed/canceled attack cannot extend combo")
	p.build_inputs=[]; p.build_hero_cd=0
	for i in 40:
		s.attack(p); p.attack=0; p.swing_time=0; p.pending_strike=false
	check(p.build_inputs.is_empty(),"Held attacks do not fabricate combo key edges")
	reset()
	p.build_talents={"T007":2,"T031":2,"T015":2}
	Build.add_status(s,p,e,"bleed",3,100); Build.add_status(s,p,e,"burn",3,100)
	var ctx := Build.context(s,p,"attack"); var initial: float=e.hp
	Build.hit_event(s,p,e,10,false,ctx)
	check(Build.status(e,1,"bleed")==0 and Build.status(e,1,"burn")==0 and e.hp<initial,"Bloodfire consumes3 preexisting layers")
	e.build_status={}; p.build_cd={}; p.build_talents={"T025":3,"T033":3,"T031":2}
	Build.add_status(s,p,e,"burn",1,100); Build.add_status(s,p,e,"frost",1,100)
	ctx=Build.context(s,p,"attack"); initial=e.hp
	Build.hit_event(s,p,e,10,false,ctx)
	check(e.hp==initial and Build.status(e,1,"burn")==3 and Build.status(e,1,"frost")==3,"Newly added stacks cannot react on same hit")
	s.elapsed+=2; ctx=Build.context(s,p,"attack"); Build.hit_event(s,p,e,10,false,ctx)
	check(e.hp<initial,"Preexisting stacks react on later root")
	reset(); p.hp=p.max_hp*.1
	for i in 20: Build.heal(s,p,p,.05)
	check(is_equal_approx(p.hp,p.max_hp*.2),"Passive self-heal budget capped10%/5s")
	Build.heal(s,p,p,.12,false)
	check(is_equal_approx(p.hp,p.max_hp*.25),"All incoming healing capped15%/5s")
	s.elapsed+=5.01; Build.heal(s,p,p,.12,false)
	check(is_equal_approx(p.hp,p.max_hp*.37),"Active Q healing isn't restricted by passive self-heal subcap")
	Build.shield(s,p,.2,4,"source-one"); Build.shield(s,p,.2,4,"source-one")
	check(is_equal_approx(p.build_shield,p.max_hp*.2),"Same shield source refreshes rather than stacking")
	Build.shield(s,p,.2,4,"source-two")
	check(is_equal_approx(p.build_shield,p.max_hp*.35),"Different shields share35% cap")
	p.mana=0
	for i in 20: Build.mana(s,p,2)
	check(p.mana==4,"Extra mana returns capped4/s")
	ctx={"cost":20.0,"refunded":0.0}; s.elapsed+=1.1
	Build.refund(s,p,ctx,.2); Build.refund(s,p,ctx,.3)
	check(is_equal_approx(ctx.refunded,7),"Refunds limited35% actual spend per action")
	reset(); p.build_talents={"T080":1,"T076":3,"T077":2}; p.invuln=0; p.dash=0
	s.perform(1,"dash"); s.hurt(p,20,e)
	check(Build.buff(p,"haste",s.elapsed)==.25 and p.build_shield>0,"Actual avoided collision triggers perfect dodge")
	var first: float=p.build_shield; s.hurt(p,20,e)
	check(p.build_shield==first,"One dodge does not generate repeated perfect events")
	reset(); var initial_hp: float=e.hp
	check(s.release_weapon_art(p),"Art begins when ready")
	check(e.hp==initial_hp,"Art waits for windup contact")
	s.perform(1,"dash"); s.simulate(.5)
	check(e.hp==initial_hp and p.art_cd>0 and p.mana<p.max_mana,"Cancel keeps spent mana/cooldown without art hit")
	reset(); p.build_talents={}; s.raid.phase="rogue_exit"; p.build_library=["T065"]; p.build_cultivation=3; p.hp=20
	Build.activate(s,p,"T065",1); var once: float=p.hp
	Build.activate(s,p,"T065",-1); Build.activate(s,p,"T065",1)
	check(p.hp==once,"First talent health grant cannot be farmed by respec")
	reset(); s.raid.phase="rogue_shop"; p.flask=25; p.rogue_gold=500; s.roguelike.roll_offers(s,true,p)
	s.perform(1,"rogue_take",{"revision":s.raid.revision,"index":5}); s.roguelike.roll_offers(s,true,p)
	p.flask=25; var gold: int=p.rogue_gold
	s.perform(1,"rogue_take",{"revision":s.raid.revision,"index":5})
	check(p.flask==25 and p.rogue_gold==gold,"Reroll cannot duplicate once-per-floor flask purchase")
	reset(); var bound: String=p.equipped.weapon.instance_id
	s.down(p)
	check(p.equipped.weapon.get("instance_id","")==bound and p.weapon==600 and Build.forge_level(p)==5,"Downing preserves rogue build instead of spilling into campaign loot")
	check(s.world_drops.is_empty(),"Run gear doesn't enter disabled campaign containers")
	p.status="active"; p.hp=20; s.raid.phase="rogue_reward"
	for n in 12: p.rogue_stash.append(Content.make_weapon(0,0))
	s.raid.reward_drops=[]
	s.roguelike.add_reward_drop(s,p.p,0,{"name":"shared","item":Content.make_weapon(2,0),"tier":0})
	s.roguelike.loot_interact(s,p)
	check(s.raid.reward_drops.size()==1,"Full reserve cannot destroy a shared ground offer")
	reset(); p.hp=2; p.invuln=0; p.flask=100
	Build.drink(s,p); Build.tick(s,p,.46)
	s.hurt(p,50,e); Build.commit_flask(s,p)
	check(p.status=="down" and p.hp==0 and p.flask==100,"Same-frame lethal hit wins over flask commit without spending capacity")
	reset(); p.hp=20; p.flask=100
	Build.drink(s,p); Build.tick(s,p,.8); Build.commit_flask(s,p)
	check(p.flask==75 and is_equal_approx(p.hp,20+p.max_hp*.3),"Low frame rate crossing complete drink still commits once")
	reset(); p.build_talents={"T025":3,"T026":2}; p.build_library=["T025","T026"]
	var directions: Array=s.roguelike.build_directions(p)
	var offers: Array=s.roguelike.reward_offers(s,0,"core",p)
	check(int(offers[0].school)==int(directions[0]) and int(offers[1].school)==int(directions[1]),"Guaranteed core offers follow invested build directions")
	offers=s.roguelike.reward_offers(s,0,"talent",p)
	check(str(offers[2].talent_id) in p.build_talents,"Third cultivation candidate offers an owned upgrade when available")
	var all_seeds := true
	for sample in 50:
		s.rng.seed=sample+1; offers=s.roguelike.reward_offers(s,0,"talent",p)
		all_seeds=all_seeds and str(offers[2].talent_id) in p.build_talents
	check(all_seeds,"Early new candidates preserve upgrade guarantee across50 seeded rolls")
	reset(); p.ammo=0; p.reserve=40
	s.roguelike.equip(s,p,Content.make_weapon(24,0))
	check(p.ammo==0 and p.reserve==40,"Picking a shared weapon cannot refill an empty magazine")
	p.ammo=12; p.reserve=20
	s.roguelike.equip(s,p,Content.make_weapon(30,0))
	check(p.ammo==1 and p.reserve==31,"Single-shot weapon conserves total carried ammunition")
	print("BUILD RULES: %d checks, %d failures" % [checks,failures])
	s.queue_free(); quit(1 if failures else 0)
