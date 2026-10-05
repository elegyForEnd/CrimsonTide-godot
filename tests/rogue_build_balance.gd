extends SceneTree
const Content = preload("res://scripts/rogue_content.gd")
const Build = preload("res://scripts/rogue_build.gd")
var s: TideSession
var records: Array=[]
func _initialize() -> void: call_deferred("run")
func measure(index: int, talents: Dictionary = {}, gear_ids: Array = [], grown: bool = false) -> Dictionary:
	var family := int(Content.data.weapons[index].family)
	s.solo({"hero":{1:0,2:2,0:0,3:1}[family],"mode":"roguelike"}); s.launch(false,914)
	var p: Dictionary=s.players[1]; p.rogue_selection={}; p.build_reward_queue=[]; s.raid.phase="rogue_exit"
	s.roguelike.equip(s,p,Content.make_weapon(index,4 if grown else 0)); p.rogue_stash=[]
	for id in gear_ids: s.roguelike.equip(s,p,s.RogueEquipment.make_gear(id-1,3))
	p.build_talents=talents; p.build_cultivation=18
	if grown:
		p.build_forge_level=5; p.build_forge_bound=p.equipped.weapon.instance_id; p.build_temper="steady"
		p.build_attributes={"strength":20} if family==2 else {"intelligence":20} if family==3 else {"dexterity":20}
	s.refresh_max_hp(p); p.hp=p.max_hp; p.mana=p.max_mana; p.invuln=9999
	s.enemies.clear(); s.spawn_enemy(s.ruins.move(p.p,Vector2(270 if family==0 else 50,0)),0)
	var e: Dictionary=s.enemies.back(); s.roguelike.combat.setup_minion(e,0,0,false,s.rng)
	e.hp=1000000.0; e.max_hp=e.hp; e.stagger=99999.0
	s.raid.phase="rogue_combat"
	s.inputs[1]={"move":Vector2.ZERO,"aim":Vector2.RIGHT,"fire":true}
	var start_hp: float=e.hp
	var burst := 0.0
	for step in 3600:
		e.p=s.ruins.move(p.p,Vector2(270 if family==0 else 50,0)); e.stagger=9999
		if grown:
			if p.skill<=0: s.perform(1,"skill")
			elif p.art_cd<=0: s.perform(1,"weapon_art")
		s.simulate(1.0/60.0)
		if step==599: burst=(start_hp-e.hp)/10
	return {"id":"W%03d" % (index+1),"family":family,"grown":grown,"dps_10":snappedf(burst,.01),"dps_60":snappedf((start_hp-e.hp)/60,.01),"remaining_mana":snappedf(p.mana,.01)}
func run() -> void:
	s=TideSession.new(); root.add_child(s); s.set_physics_process(false)
	for i in 48: records.append(measure(i))
	var builds: Array=[
		[0,[5,30,53],{"T001":3,"T002":3,"T003":3,"T004":2,"T006":2,"T008":1,"T066":2}],
		[19,[1,31,55],{"T009":3,"T010":3,"T011":3,"T013":2,"T014":2,"T016":1,"T066":2}],
		[25,[23,33,49],{"T017":3,"T018":3,"T019":3,"T020":2,"T021":2,"T024":1,"T066":2}],
		[37,[8,35,60],{"T025":3,"T026":3,"T027":3,"T030":2,"T031":2,"T032":1,"T066":2}],
		[38,[9,37,62],{"T033":3,"T034":3,"T035":3,"T037":2,"T038":2,"T040":1,"T066":2}],
		[39,[11,39,63],{"T041":3,"T042":3,"T044":3,"T045":2,"T046":2,"T048":1,"T066":2}],
		[36,[13,43,65],{"T049":3,"T050":3,"T051":3,"T052":2,"T053":2,"T056":1,"T066":2}],
		[10,[17,42,66],{"T057":3,"T058":3,"T059":3,"T060":2,"T062":2,"T064":1,"T066":2}],
		[20,[2,44,67],{"T065":3,"T066":3,"T067":3,"T068":2,"T069":2,"T072":1,"T057":2}],
		[4,[18,40,69],{"T073":3,"T074":3,"T075":3,"T076":2,"T078":2,"T080":1,"T066":2}],
		[46,[19,45,71],{"T081":3,"T082":3,"T083":3,"T084":2,"T087":2,"T088":1,"T066":2}],
		[47,[21,47,72],{"T089":3,"T090":3,"T091":3,"T093":2,"T094":2,"T096":1,"T066":2}]]
	for build in builds: records.append(measure(build[0],build[2],build[1],true))
	var out := FileAccess.open("res://output/rogue-build-balance.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(records,"\t")); out.close()
	print("BALANCE: measured48 weapons and12 builds using actual attacks, projectiles, mana, reload and casts")
	for result in records:
		if result.grown: print(result.id," build DPS60=",result.dps_60)
	s.queue_free(); quit()
