extends SceneTree
const Fixture = preload("res://output/rogue_effect_audit_probe.gd")
const Build = preload("res://scripts/rogue_build.gd")
const Actions = preload("res://scripts/rogue_actions.gd")
const Growth = preload("res://scripts/rogue_growth.gd")
var f
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func reset(n: int = 0) -> void:
	f.s.set_meta("profile_data",{})
	f.reset(n)
	f.s.raid.variant=""
func run() -> void:
	f=Fixture.new(); f.s=TideSession.new(); root.add_child(f.s); f.s.set_physics_process(false)
	reset(); f.p.build_talents={"T072":1}
	for kind in ["attack","art","skill"]:
		check(is_equal_approx(Build.hit_multiplier(f.s,f.p,f.e,f.ctx(kind)),.88),"T072 penalty includes "+kind)
	check(Build.hit_multiplier(f.s,f.p,f.e,{"kind":"proc","depth":1})==1,"T072 does not penalize thorns/proc")
	reset(); f.p.build_talents={"T095":2}; f.p.hp=f.p.max_hp*.5
	Build.heal(f.s,f.p,f.p,.01)
	var direct_context: Dictionary=f.ctx("art")
	check(is_equal_approx(Build.hit_multiplier(f.s,f.p,f.e,direct_context),1.15),"T095 buffs art")
	Build.hit_event(f.s,f.p,f.e,10,false,direct_context)
	check(Build.buff(f.p,"healed",f.s.elapsed)==0,"T095 consumed by first valid direct hit")
	check(is_equal_approx(Build.hit_multiplier(f.s,f.p,f.e,direct_context),1.15),"Same root retains buff for its other targets/segments")
	reset(36); f.p.build_talents={"T056":1}
	check(is_equal_approx(Build.hit_multiplier(f.s,f.p,f.e,f.ctx("skill")),1),"T056 excludes Q")
	check(is_equal_approx(Build.hit_multiplier(f.s,f.p,f.e,f.ctx()),1.18),"T056 still buffs high mana staff normal")
	reset(); f.gear(54); Build.add_status(f.s,f.p,f.e,"bleed",1,100)
	Build.hit_event(f.s,f.p,f.e,10,false,f.ctx("art"))
	check(Build.buff(f.p,"defense",f.s.elapsed)==.06,"E054 triggers on art")
	reset(36); f.gear(6); Build.incoming(f.s,f.p,f.p.max_hp*.1,f.e,"direct")
	check(is_equal_approx(Build.hit_multiplier(f.s,f.p,f.e,f.ctx()),1),"E006 doesn't buff staff")
	f.p.weapon=613
	check(is_equal_approx(Build.hit_multiplier(f.s,f.p,f.e,f.ctx()),1.2),"E006 buffs heavy normal")
	reset(); f.p.build_talents={"T038":2}
	var before: float=f.e.hp
	Build.add_status(f.s,f.p,f.e,"frost",5,100)
	check(f.e.hp==before,"T038 waits until normal enemy freeze ends")
	Build.tick_enemies(f.s,.3)
	check(f.e.hp==before,"T038 not released halfway through freeze")
	Build.tick_enemies(f.s,.31)
	check(f.e.hp<before,"T038 releases at freeze end")
	reset(); f.e.rogue_guardian=true; f.p.build_talents={"T038":2}; before=f.e.hp
	Build.add_status(f.s,f.p,f.e,"frost",5,100)
	check(f.e.hp<before,"T038 Boss full frost remains immediate")
	reset(); f.p.build_talents={"T040":1,"T037":2}; f.gear(9)
	Build.add_status(f.s,f.p,f.e,"frost",5,100)
	f.p.build_shields={}; f.p.build_shield=0; f.s.elapsed+=6.01
	Build.add_status(f.s,f.p,f.e,"frost",1,100)
	check(f.p.build_shield==0,"E009/T037 maintain independent 8s ICD with 6s CC")
	f.s.elapsed+=6.01; Build.add_status(f.s,f.p,f.e,"frost",1,100)
	check(f.p.build_shield>0,"Frozen shield procs become ready again")
	reset(); f.p.build_talents={"T075":3}
	Build.action_event(f.s,f.p,"D"); Build.hit_event(f.s,f.p,f.e,10,false,f.ctx())
	f.s.elapsed+=2.01; Build.action_event(f.s,f.p,"D")
	check(Build.buff(f.p,"dodge_strike",f.s.elapsed)==0,"T075 respects 4s ICD")
	reset(4); Build.action_event(f.s,f.p,"D")
	check(Build.hit_multiplier(f.s,f.p,f.e,f.ctx())>1,"W005 first attack amplified")
	Build.hit_event(f.s,f.p,f.e,10,false,f.ctx())
	check(is_equal_approx(Build.hit_multiplier(f.s,f.p,f.e,f.ctx()),1),"W005 second attack not amplified")
	reset(); f.gear(11); Build.action_event(f.s,f.p,"D"); f.s.elapsed+=2.5
	Build.hit_event(f.s,f.p,f.e,10,false,f.ctx())
	check(Build.status(f.e,f.p.id,"shock")==2,"E011 retains 3s window")
	reset(36); f.p.build_core="WC010"; f.p.height=35; f.p.height_velocity=-1; f.p.air_art=true
	check(Actions.start_art(f.s,f.p)==false,"second air art rejected")
	f.p.air_art=false
	check(Actions.start_art(f.s,f.p),"first air art accepted")
	Actions.resolve_art(f.s,f.p,f.p.build_pending_art,1)
	f.p.height=.01; f.p.height_velocity=-1
	Build.tick(f.s,f.p,.02)
	check(Build.buff(f.p,"landing_cost",f.s.elapsed)>0,"WC010 air art alone grants landing reduction")
	f.p.attack=0; f.p.cast_time=0; f.p.swing_time=0; f.p.pending_strike=false
	f.s.attack(f.p)
	check(Build.buff(f.p,"landing_cost",f.s.elapsed)==0,"WC010 consumed when staff normal pays mana, even if it misses")
	reset(); f.p.build_talents={"T086":2}; f.s.inputs[f.p.id]={"aim_point":f.e.p}
	Build.action_event(f.s,f.p,"U")
	check(int(Build.buff(f.p,"soul_target",f.s.elapsed))==int(f.e.id),"T086 locks aimed target immediately")
	reset(); f.p.build_talents={"T094":2,"T096":1}; f.p.equipped.weapon.rogue_id=20
	Build.action_event(f.s,f.p,"U"); Build.spend_event(f.s,f.p,12); Build.action_event(f.s,f.p,"S")
	check(is_equal_approx(f.p.build_shield,f.p.max_hp*.14),"T094/T096/I021 independent shields stack to 14%")
	check(f.p.build_shields.size()==3,"Three distinct shield sources")
	reset(); f.p.build_talents={"T055":2}; Build.spend_event(f.s,f.p,40); f.s.elapsed+=1
	Build.hit_event(f.s,f.p,f.e,10,false,f.ctx()); Build.spend_event(f.s,f.p,80)
	check(f.p.build_counts.spent==39,"T055 excess progress capped during ICD")
	reset(); f.gear(48); f.p.mana=0
	var ally: Dictionary=f.p.duplicate(true); ally.id=2; ally.equipped.gear=[{},{},{}]; f.s.players[2]=ally
	Build.hit_event(f.s,f.p,f.e,10,false,f.ctx("art"))
	check(f.p.mana==0,"E048 cannot self-proc in multiplayer")
	Build.hit_event(f.s,ally,f.e,10,false,Build.context(f.s,ally,"art"))
	check(f.p.mana==2,"E048 still responds to ally art")
	reset(); f.gear(8); f.p.build_talents={"T026":3}; Build.add_status(f.s,f.p,f.e,"burn",1,100)
	check(f.e.build_status[str(f.p.id)].burn.time==5,"E008 burn duration obeys 5s cap")
	reset(); f.gear(7); f.p.build_talents={"T028":3}
	check(is_equal_approx(Build.incoming(f.s,f.p,100,{},"burn","fire"),70),"T028/E007 reduce enemy burn by capped 30%")
	check(is_equal_approx(Build.incoming(f.s,f.p,100,{},"direct","fire"),100),"Special burn resistance excludes direct fire hits")
	reset(); f.p.build_talents={"T029":2}; Build.add_status(f.s,f.p,f.e,"burn",1,100,true)
	f.e.hp=0; f.e.build_last_kind="dot"
	f.s.spawn_enemy(f.s.ruins.move(f.e.p,Vector2(55,0)),0)
	var secondary: Dictionary=f.s.enemies.back()
	Build.killed(f.s,f.p,f.e)
	check(Build.status(secondary,f.p.id,"burn")==0,"T029 propagated burn kill cannot propagate again")
	reset(); f.gear(60); Build.field(f.p,f.p.p,3,90,.1,100,3,"Q"); Build.field(f.p,f.p.p,3,90,.1,100,3,"T032")
	Build.action_event(f.s,f.p,"D"); f.p.dodge_time=.2
	f.p.p=f.s.ruins.move(f.p.p,Vector2(45,0)); Build.tick(f.s,f.p,.01)
	f.p.p=f.s.ruins.move(f.p.p,Vector2(45,0)); Build.tick(f.s,f.p,.01)
	var trail: Array=f.p.build_fields.filter(func(z): return z.get("source","")=="E060")
	check(trail.size()==2 and trail[0].p!=trail[1].p,"E060 lays two path points independently of other fields")
	reset(); f.s.raid.variant="blood_moon"; Build.enemy_budget(f.s,f.e)
	check(is_equal_approx(f.e.build_damage_scale,float(f.s.raid.build_enemy_damage)*1.15),"Blood moon enemy damage +15%")
	reset(); f.s.raid.variant="bedrock"; f.s.roguelike.combat.setup_boss(f.e,0,f.s); Build.enemy_budget(f.s,f.e)
	check(is_equal_approx(f.e.hp,2600*float(f.s.raid.build_enemy_hp)*1.2),"Bedrock Boss HP +20%")
	reset(); f.s.raid.variant="frenzy"; Build.enemy_budget(f.s,f.e); before=f.e.hp
	f.s.roguelike.combat.apply_variant_stats(f.s,f.e)
	check(is_equal_approx(before,150*float(f.s.raid.build_enemy_hp)*.92) and f.e.hp==before,"Frenzy minion HP -8% applied once")
	reset(); var notices: Array=[]; f.s.message.connect(func(text): notices.append(text))
	f.s.raid.phase="rogue_reward"; f.p.build_cultivation=18
	check(f.s.roguelike.apply_offer_reason(f.s,f.p,{"talent_id":"T007"})=="","Missing prerequisite still permits collection")
	check(not f.p.build_talents.has("T007") and notices.any(func(t): return "未激活" in t and "普通天赋" in t),"Collection clearly explains failed activation")
	reset(); var profile := {"ashes":0,"growth":{}}; f.s.set_meta("profile_data",profile)
	f.s.roguelike.apply_room_delta(f.s,f.p,{"ash":50})
	var base := Growth.ashes_on_settle(f.s,f.p)
	Growth.grant(f.s,f.p)
	check(profile.ashes==base+50 and f.p.rogue_ash_run==profile.ashes,"Room ash banked with base reward")
	reset(); f.p.rogue_growth={"coin_purse":2,"hunt_instinct":2}; ally=f.p.duplicate(true); ally.id=2; ally.rogue_growth={"scholar":3}; f.s.players[2]=ally
	check(is_equal_approx(f.s.rogue_mods(f.p).player_damage,.08) and f.s.rogue_mods(ally).player_damage==0,"Personal growth doesn't leak to ally")
	check(is_equal_approx(f.s.rogue_mods(ally).xp_gain,.3) and f.s.rogue_mods(f.p).xp_gain==0,"Ally scholarship independent")
	f.e.hp=0; f.e.build_xp_reward=20; Build.enemy_experience(f.s,f.e)
	check(f.p.build_xp_total==20 and ally.build_xp_total==26,"Shared kill XP uses each personal scholarship")
	reset(); f.gear(70); Build.action_event(f.s,f.p,"D"); Build.perfect(f.s,f.p)
	check(Build.buff(f.p,"perfect_strike",f.s.elapsed)==.18,"E070 first perfect dodge grants strike")
	f.p.build_buffs.erase("perfect_strike"); f.s.elapsed+=3.1; Build.action_event(f.s,f.p,"D"); Build.perfect(f.s,f.p)
	check(Build.buff(f.p,"perfect_strike",f.s.elapsed)==0,"E070 obeys its own 5s ICD")
	reset(); f.p.build_talents={"T079":2}; Build.action_event(f.s,f.p,"D")
	check(Actions.start_art(f.s,f.p),"T079 first art accepted")
	check(is_equal_approx(f.p.build_pending_art.remaining,.2975),"T079 shortens first light art windup 15%")
	f.p.erase("build_pending_art"); f.p.attack=0; f.p.cast_time=0; f.p.swing_time=0; f.p.art_cd=0
	check(Actions.start_art(f.s,f.p) and is_equal_approx(f.p.build_pending_art.remaining,.35),"T079 does not shorten second art in same dodge window")
	reset(24); f.p.build_core="WC007"; Build.action_event(f.s,f.p,"D")
	check(Build.buff(f.p,"reload_haste",f.s.elapsed)==0,"WC007 no reload haste without sliding shot")
	Build.action_event(f.s,f.p,"A"); f.s.elapsed+=6
	check(Build.buff(f.p,"reload_haste",f.s.elapsed)==.08,"WC007 sliding shot haste persists until reload")
	Build.reload_event(f.s,f.p)
	check(Build.buff(f.p,"reload_haste",f.s.elapsed)==0,"WC007 haste consumed by one completed reload")
	reset(); f.gear(18); f.p.swing_time=1; var origin: Vector2=f.p.p
	f.s.move_player(f.p,Vector2.RIGHT,false,.05,100)
	var plain_distance: float=f.p.p.distance_to(origin)
	f.p.p=origin; Build.action_event(f.s,f.p,"D"); f.s.move_player(f.p,Vector2.RIGHT,false,.05,100)
	check(f.p.p.distance_to(origin)>plain_distance,"E018 reduces penalty during its dodge window")
	f.p.p=origin; f.s.elapsed+=2.01; f.s.move_player(f.p,Vector2.RIGHT,false,.05,100)
	check(is_equal_approx(f.p.p.distance_to(origin),plain_distance),"E018 movement benefit expires after 2s")
	reset(36); var art_move: Dictionary=WeaponArts.of(f.p.weapon).duplicate(true)
	var target_origin: Vector2=f.s.ruins.move(f.p.p,Vector2(120,0),8)
	f.s.inputs[f.p.id]={"aim_point":f.s.ruins.move(target_origin,Vector2(230,0),8)}
	var pending := {"move":art_move,"aim":Vector2.RIGHT,"ctx":{"family":3,"route":1,"target_origin":target_origin}}
	check(Actions.art_target(f.s,f.p,pending).distance_to(target_origin)<=120.01,"CM14 target correction capped at 120")
	reset(); f.p.build_talents={"T040":1}
	check(Build.cc_interval(f.p)==6,"Freeze and launch share shortened CC interval")
	f.p.build_temper="strength"
	check(Catalog.scaling_text(f.p.weapon,Build.grades(f.p,f.p.weapon))!=Catalog.scaling_text(f.p.weapon),"Displayed scaling includes actual temper upgrade")
	reset(); f.s.raid.variant="apocalypse"; before=f.e.hp
	f.s.damage_enemy(f.e,100,f.p.id,Vector2.ZERO,0,-1,-1,{"kind":"attack","depth":1})
	var normal_damage: float=before-f.e.hp; before=f.e.hp
	f.s.damage_enemy(f.e,100,f.p.id,Vector2.ZERO,0,-1,-1,{"kind":"art","depth":1})
	check(is_equal_approx(normal_damage,115) and is_equal_approx(before-f.e.hp,100),"Apocalypse affects only normal attack, not art")
	reset(); f.e.build_damage_scale=1.15; f.e.minion_skill=0; f.e.attack_aim=Vector2.RIGHT; f.e.attack_point=f.e.p
	f.s.roguelike.combat.minions.release(f.s,f.s.roguelike.combat,f.e)
	check(is_equal_approx(f.s.roguelike.combat.effects.back().damage,9*1.15),"Minion zone damage budget multiplied exactly once")
	f.s.roguelike.combat.missile(f.e,"shot",f.e.p,f.e.p+Vector2(100,0),0,1,9)
	check(is_equal_approx(f.s.roguelike.combat.missiles.back().damage,9*1.15),"Minion missile budget multiplied once")
	f.s.roguelike.combat.bolt(f.s,f.e,Vector2.RIGHT,200,9)
	check(is_equal_approx(f.s.bullets.back().damage,9*1.15),"Minion bolt budget multiplied once")
	reset(); f.s.raid.room="combat"; f.s.raid.wave=1; f.s.raid.variant=""
	f.s.roguelike.spawn_wave(f.s)
	check(not f.s.enemies.any(func(enemy): return enemy.get("build_elite",false)),"Ordinary room has no elites without chance modifier")
	var elite_count := 0
	var monster_count := 0
	for sample in 20:
		f.s.enemies.clear(); f.s.raid.variant="wolves"; f.s.rng.seed=1000+sample
		f.s.roguelike.spawn_wave(f.s)
		monster_count+=f.s.enemies.size()
		for enemy in f.s.enemies:
			if enemy.get("build_elite",false): elite_count+=1
	check(elite_count>0 and elite_count<monster_count,"Wolves adds actual elite chance in ordinary combat rooms")
	var summary := {"checks":checks,"failures":failures}
	var file := FileAccess.open("res://output/rogue-effect-fixes-result.json",FileAccess.WRITE); file.store_string(JSON.stringify(summary)); file.close()
	f.free()
	print("ROGUE EFFECT FIXES: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
