extends SceneTree
const Build = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")
var failures := 0
var checks := 0
var s: TideSession
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func select(p: Dictionary) -> void:
	var selection: Dictionary=p.rogue_selection
	if selection.is_empty(): return
	s.perform(p.id,"rogue_selection_take",{"id":selection.id,"version":selection.version,"index":0})
func manage(p: Dictionary, verb: String, id: String = "") -> void:
	s.perform(p.id,"rogue_build",{"verb":verb,"id":id,"version":p.rogue_inventory_revision})
func launch(hero: int = 0) -> Dictionary:
	s.solo({"hero":hero,"mode":"roguelike"})
	s.launch(false,731)
	var p: Dictionary=s.players[1]
	select(p); s.roguelike.tick(s,.01)
	return p
func dummy(p: Dictionary) -> Dictionary:
	s.enemies.clear()
	s.spawn_enemy(s.ruins.move(p.p,Vector2(70,0)),0)
	var e: Dictionary=s.enemies.back()
	s.roguelike.combat.setup_minion(e,0,0,false,s.rng)
	e.hp=100000; e.max_hp=100000; e.stagger=9999.0
	return e
func run() -> void:
	s=TideSession.new(); root.add_child(s); s.set_physics_process(false)
	check(Content.data.weapons.size()==48 and Content.data.gear.size()==72 and Content.data.talents.size()==96 and Content.data.engravings.size()==24 and Content.data.cores.size()==12,"252 unique build entries")
	var ids: Dictionary={}
	for category in ["weapons","gear","talents","engravings","cores"]:
		for def in Content.data[category]:
			check(not ids.has(def.id),"Stable ID unique: "+str(def.id)); ids[def.id]=true
	for hero in 4:
		var p := launch(hero)
		check(Build.attributes(p).vigor==Build.HERO_BASE[hero][0],"Per-hero initial attributes")
		check(is_equal_approx(p.max_mana,WatcherAttributes.max_mana(Build.attributes(p))),"Mind scales maximum mana")
	var p := launch()
	check(p.flask==100 and s.raid.phase=="rogue_combat","Starts with 100% personal flask and weapon choice")
	s.roguelike.equip(s,p,Content.make_weapon(0,0))
	check(is_equal_approx(s.weapon_scaling(p),.215),"Fey STR15 DEX21 C/B scaling equals21.5%")
	check(is_equal_approx(s.weapon_damage(p),43.74),"Actual attack formula includes role weapon scaling")
	p.build_attribute_points=1; s.raid.phase="rogue_exit"; p.hp=40; p.mana=30
	manage(p,"attribute","vigor")
	check(p.max_hp==134 and p.hp==40 and p.mana==30,"Attribute ceiling gains cannot create health/mana")
	check(int(p.attributes.get("vigor",10))==10,"Run points never alter permanent allocation")
	var before: int=p.rogue_inventory_revision
	s.perform(1,"rogue_build",{"verb":"attribute","id":"strength","version":before-1})
	check(p.rogue_inventory_revision==before,"Reject stale management version")
	p.flask=100; p.flask_cd=0; p.hp=20; p.flask_time=0
	s.perform(1,"heal"); Build.tick(s,p,.44)
	check(p.hp==20 and p.flask==100,"Flask doesn't heal before commit")
	Build.tick(s,p,.02)
	Build.commit_flask(s,p)
	check(is_equal_approx(p.hp,20+p.max_hp*.3) and p.flask==75,"Flask spends25% for30% maximum health")
	Build.tick(s,p,3); p.invuln=0; p.hp=20
	s.perform(1,"heal"); Build.tick(s,p,.2); s.hurt(p,5)
	check(p.flask==75 and p.flask_time==0,"Precommit interruption doesn't spend flask")
	p.status="down"; p.soul_lamp=true; p.hp=0; s.inputs[1]={"flask_held":true}
	Build.tick(s,p,1); Build.tick(s,p,1.01)
	check(p.status=="active" and not p.soul_lamp and p.flask==75,"Separate soul lamp self revival consumes no flask")
	s.inputs[1]={}; p.height=0; p.jump_cd=0; p.pending_strike=false; p.cast_time=0; p.swing_time=0; p.dodge_time=0; p.flask_time=0
	check(Build.jump(s,p),"Jump accepted")
	var ground: Vector2=p.p
	Build.tick(s,p,.35)
	check(absf(p.height-73.51)<.02 and p.p==ground,"Jump apex independent of ground XY")
	p.invuln=0; var hp: float=p.hp; s.hurt(p,20,{},"ground")
	check(p.hp==hp,"Height avoids tagged ground hazards")
	s.hurt(p,20)
	check(p.hp<hp,"Default normal attacks can hit aerial heroes")
	Build.tick(s,p,.36); check(p.height==0,"Jump lands")
	p.build_library=["T001","T002","T005","T008"]; p.build_cultivation=18; p.build_talents={}
	check(not Build.activate(s,p,"T008",1),"Core requires same-school investment")
	check(Build.activate(s,p,"T001",1) and Build.activate(s,p,"T002",1) and Build.activate(s,p,"T008",1),"School core with valid prerequisites")
	check(Build.talent_cost(p)==5,"Core costs3 budget")
	Build.activate(s,p,"T001",-1)
	check(not p.build_talents.has("T008"),"Removing prerequisite deactivates dependent core")
	p.build_forge_points=8; s.raid.floor=5; p.attack=0; p.swing_time=0; p.cast_time=0; p.invuln=0
	for i in 5: manage(p,"forge")
	check(Build.forge_level(p)==5 and p.build_forge_points==0,"Forge +5 uses exactly8 points")
	manage(p,"core","WC001"); check(Build.core(p,1)==2,"+4 upgrades equipped core")
	manage(p,"temper","dexterity")
	check(Build.grades(p,p.weapon).dexterity=="A","+3 increases selected scaling grade")
	var old: Dictionary=p.equipped.weapon.duplicate(true)
	s.roguelike.equip(s,p,Content.make_weapon(12,0))
	check(Build.forge_level(p)==5 and p.build_core=="" and old.get("forge_level",0)==0,"Forge transfers without copying to old weapon")
	manage(p,"core","WC001"); check(p.build_core=="","Reject wrong-family core")
	p.build_forge_level=0; p.build_talents={"T025":3,"T033":3,"T031":2}; p.build_cultivation=18
	s.raid.phase="rogue_combat"; p.attack=0; p.cast_time=0; p.swing_time=0; p.hp=p.max_hp; p.mana=p.max_mana
	var e := dummy(p)
	var ctx := Build.context(s,p,"attack")
	s.damage_enemy(e,40,1,Vector2.RIGHT,0,1,p.weapon,ctx)
	s.damage_enemy(e,40,1,Vector2.RIGHT,0,1,p.weapon,ctx)
	check(Build.status(e,1,"burn")==2 and Build.status(e,1,"frost")==2 and p.build_counts.attacks==1,"Multi-hit root applies status and holder counter once")
	var count: int=p.build_counts.attacks
	Build.proc(s,p,e,.2)
	check(p.build_counts.attacks==count,"Proc damage cannot recursively trigger roots")
	p.build_talents={}; p.build_cd={}; p.build_counts={}; p.build_library=[]
	for n in 48:
		s.roguelike.equip(s,p,Content.make_weapon(n,0))
		p.build_counts={}; p.build_cd={}; p.attack=0; p.swing_time=0; p.pending_strike=false; p.cast_time=0; p.height=0; p.air_attacks=0; p.air_art=false; p.flask_time=0; p.mana=p.max_mana; p.ammo=16
		e=dummy(p)
		ctx=Build.context(s,p,"attack")
		s.damage_enemy(e,s.weapon_damage(p),1,Vector2.RIGHT,0,Catalog.weapon_family(p.weapon),p.weapon,ctx)
		check(e.hp<e.max_hp,"Weapon damages actual enemy: W%03d" % (n+1))
		p.art_cd=0; p.cast_time=0
		check(s.release_weapon_art(p),"All48 weapon arts execute: W%03d" % (n+1))
		s.bullets.clear(); p.rogue_stash=[]
	# Award all25 room keys; duplicates cannot inflate budgets.
	p=launch(); p.build_reward_queue=[]; p.rogue_selection={}
	for f in range(1,6):
		s.raid.floor=f
		if f>1: Build.floor_enter(p)
		check(p.build_attribute_points==0,"Floor entry grants no attributes")
		for area in range(1,6):
			s.raid.area=area; s.raid.room="combat"
			Build.award(s,p); Build.award(s,p)
			check(p.build_attribute_points==0,"Room completion grants no attributes")
			check(p.build_reward_queue.is_empty(),"Cultivation alone does not create talent choices")
	check(p.build_cultivation==18 and p.build_forge_points==8 and p.build_attribute_points==0,"Fixed cultivation/forge budgets are independent of XP and attribute drops")
	# Campaign attributes remain unchanged with run mode disabled.
	s.solo({"hero":0,"attributes":{"strength":15}}); s.launch(false,111)
	check(not s.roguelike.active(s) and s.attributes_of(s.players[1]).strength==15,"Campaign permanent attributes preserve old behavior")
	print("ROGUE BUILD: %d checks, %d failures" % [checks,failures])
	s.queue_free(); quit(1 if failures>0 else 0)
