extends SceneTree
## Audit observations, not acceptance tests: CONFIRMED means current behavior disagrees with catalog.
const Build = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")
const Equipment = preload("res://scripts/rogue_equipment.gd")
const Actions = preload("res://scripts/rogue_actions.gd")
const Growth = preload("res://scripts/rogue_growth.gd")
var s: TideSession
var p: Dictionary
var e: Dictionary
var observations: Array = []
func _initialize() -> void: call_deferred("run")
func reset(weapon: int = 0) -> void:
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,431)
	p=s.players[1]; p.rogue_selection={}; p.build_reward_queue=[]
	s.raid.phase="rogue_exit"
	s.roguelike.equip(s,p,Content.make_weapon(weapon,0))
	p.build_forge_level=5; p.build_forge_bound=p.equipped.weapon.instance_id
	s.enemies.clear(); s.spawn_enemy(s.ruins.move(p.p,Vector2(50,0)),0)
	e=s.enemies.back(); s.roguelike.combat.setup_minion(e,0,0,false,s.rng)
	e.hp=100000; e.max_hp=e.hp; e.stagger=0
	s.raid.phase="rogue_combat"; s.elapsed=20
	p.attack=0; p.swing_time=0; p.pending_strike=false; p.cast_time=0
func gear(n: int) -> void:
	var item := Equipment.make_gear(n-1,0)
	p.equipped.gear[int(item.gear)]=item
func ctx(kind: String = "attack") -> Dictionary:
	var result := Build.context(s,p,kind)
	result["crit_targets"]={e.id:false}
	return result
func observe(id: String, confirmed: bool, detail: String) -> void:
	observations.append({"id":id,"confirmed":confirmed,"detail":detail})
	print(("CONFIRMED " if confirmed else "NOT REPRODUCED ")+id+" | "+detail)
func run() -> void:
	s=TideSession.new(); root.add_child(s); s.set_physics_process(false)
	reset(); p.build_talents={"T072":1}
	var penalized := Build.hit_multiplier(s,p,e,ctx("art"))
	observe("T072",is_equal_approx(penalized,1),"art penalty multiplier="+str(penalized)+"; catalog requires x0.88")
	reset(); p.build_talents={"T095":2}; p.hp=p.max_hp*.5
	Build.heal(s,p,p,.01)
	var art_bonus := Build.hit_multiplier(s,p,e,ctx("art"))
	observe("T095",is_equal_approx(art_bonus,1),"healed buff="+str(Build.buff(p,"healed",s.elapsed))+"; art multiplier="+str(art_bonus))
	reset(); gear(54); Build.add_status(s,p,e,"bleed",1,100)
	Build.hit_event(s,p,e,10,false,ctx("art"))
	observe("E054",is_zero_approx(Build.buff(p,"defense",s.elapsed)),"art hitting own bleed gives no defense buff")
	reset(); gear(6); p.weapon=636
	Build.incoming(s,p,p.max_hp*.1,e,"direct")
	observe("E006",Build.hit_multiplier(s,p,e,ctx())>1,"heavy-only counter also amplifies staff normal attack")
	reset(); p.build_talents={"T038":2}
	var hp_before: float=e.hp
	Build.add_status(s,p,e,"frost",5,100)
	observe("T038",e.hp<hp_before and e.stagger>0,"damage occurs immediately on freeze start, before freeze ends")
	reset(); p.build_talents={"T040":1}; gear(9)
	Build.add_status(s,p,e,"frost",5,100)
	p.build_shields={}; p.build_shield=0; s.elapsed+=6.01
	Build.add_status(s,p,e,"frost",1,100)
	observe("E009/T037/E062",p.build_shield>0,"shared frost timer shortened to 6s also shortens stated 8s proc interval")
	reset(); p.build_talents={"T075":3}
	Build.action_event(s,p,"D"); Build.hit_event(s,p,e,10,false,ctx())
	s.elapsed+=2.01; Build.action_event(s,p,"D")
	observe("T075/I020/W005",Build.buff(p,"dodge_strike",s.elapsed)>0,"dodge bonus regranted after 2s; no catalog 4s interval check")
	reset(4); Build.action_event(s,p,"D")
	var hit1 := Build.hit_multiplier(s,p,e,ctx()); Build.hit_event(s,p,e,10,false,ctx())
	var hit2 := Build.hit_multiplier(s,p,e,ctx())
	observe("W005",hit1>1 and is_equal_approx(hit1,hit2),"first and second attacks within dodge window both amplified")
	reset(); gear(11); Build.action_event(s,p,"D"); s.elapsed+=2.5
	Build.hit_event(s,p,e,10,false,ctx())
	observe("E011",Build.status(e,p.id,"shock")==0,"catalog 3s window but implementation expires after 2s")
	reset(); p.build_talents={"T024":1}; Build.add_status(s,p,e,"mark",1,100)
	Build.hit_event(s,p,e,10,false,ctx())
	Build.add_status(s,p,e,"mark",1,100)
	observe("T024",Build.hit_multiplier(s,p,e,ctx())>1.3,"extra +22% remains during 3s secondary-attack cooldown")
	reset(36); p.build_core="WC010"; p.height=.01; p.height_velocity=-1; p.air_art=true; p.air_attacks=0
	Build.tick(s,p,.02)
	observe("WC010",is_zero_approx(Build.buff(p,"landing_cost",s.elapsed)),"air art alone then landing grants no mana-cost reduction")
	reset(); Build.shield(s,p,.04,3); Build.shield(s,p,.06,3)
	observe("SHIELD_SOURCES",is_equal_approx(p.build_shield,p.max_hp*.06),"two default-source effects total 6%, not 10%")
	reset(); p.build_talents={"T086":2}; p.soul_focus=-1; Build.action_event(s,p,"U")
	observe("T086",is_zero_approx(Build.buff(p,"soul_target",s.elapsed)),"Q grants soul_order damage buff but no aim-target hard lock")
	reset(); s.raid.variant="blood_moon"; Build.enemy_budget(s,e)
	observe("VARIANT_DAMAGE",is_equal_approx(e.build_damage_scale,float(s.raid.build_enemy_damage)),"blood_moon +15% missing from enemy damage scale")
	reset(); s.raid.variant="bedrock"; s.roguelike.combat.setup_boss(e,0,s)
	Build.enemy_budget(s,e)
	observe("BOSS_VARIANT_HP",is_equal_approx(e.max_hp,2600*float(s.raid.build_enemy_hp)) and e.get("variant_stats_applied",false),"bedrock +20% applied during setup then overwritten; marker prevents reapply")
	reset(); s.raid.variant="frenzy"; Build.enemy_budget(s,e)
	var before_variant: float=e.hp
	s.roguelike.combat.apply_variant_stats(s,e)
	observe("MINION_VARIANT_HP",is_equal_approx(before_variant,150*float(s.raid.build_enemy_hp)*.92) and is_equal_approx(e.hp,before_variant*.92),"frenzy minion HP reduced twice: x0.92 in budget then x0.92 in variant setup")
	reset(); s.raid.phase="rogue_reward"; p.build_cultivation=18
	var reason := s.roguelike.apply_offer_reason(s,p,{"talent_id":"T007"})
	observe("TALENT_CLAIM",reason=="" and "T007" in p.build_library and not p.build_talents.has("T007"),"claim returns success while activation fails (missing basic prerequisite)")
	reset(); p.build_talents={"T055":2}; Build.spend_event(s,p,40); s.elapsed+=1
	Build.hit_event(s,p,e,10,false,ctx()); s.elapsed+=1; Build.spend_event(s,p,80)
	observe("T055",float(p.build_counts.spent)>39,"spending 80 during ICD leaves progress="+str(p.build_counts.spent)+" despite stated 39 cap")
	reset(); gear(48)
	var ally: Dictionary=p.duplicate(true); ally.id=2; ally.mana=0; ally.equipped.gear=[{},{},{}]
	s.players[2]=ally; p.mana=0
	Build.hit_event(s,p,e,10,false,ctx("art"))
	observe("E048",p.mana>0,"wearer own art returns mana in multiplayer; catalog only permits own art in solo")
	reset(36); p.build_talents={"T056":1}
	observe("T056",Build.hit_multiplier(s,p,e,ctx("skill"))>1.17,"catalog excludes Q damage but high-mana skill receives +18%")
	reset(); var profile_data := {"ashes":0,"growth":{}}
	s.set_meta("profile_data",profile_data); p.rogue_ash_run=50
	var grant := Growth.grant(s,p)
	observe("ROOM_ASH_BANK",int(profile_data.ashes)==grant and int(p.rogue_ash_run)==grant+50,"room-earned 50 shown in run total but omitted from profile ash bank")
	var file := FileAccess.open("res://output/rogue-effect-audit-observations.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(observations,"\t")); file.close()
	var confirmed := observations.filter(func(o): return o.confirmed).size()
	print("AUDIT OBSERVATIONS: %d/%d reproduced" % [confirmed,observations.size()])
	quit(0 if confirmed==observations.size() else 1)
