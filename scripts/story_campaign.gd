extends RefCounted
## Standalone persistent campaign; no extraction currencies or raid lifecycle.
signal changed
signal location_changed
signal notice(text: String)
signal chapter_read(title: String, text: String)
signal audio_cue(kind: String)
const Map = preload("res://scripts/story_map.gd")
var content: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/story_content.json"))
var state: Dictionary={}
var map = Map.new()
var enemies: Array=[]
var effects: Array=[]
var hero_at := Vector2.ZERO
var allies := [Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
var facing := Vector2.DOWN
var moving := false
var attack_time := 0.0
var hurt_time := 0.0
var dodge_time := 0.0
var dodge_vector := Vector2.ZERO
var attack_cd := 0.0
var skill_cd := 0.0
var ultimate_cd := 0.0
var gate_cd := 1.0
var auto_save := 0.0
var clock := 0.0
var path := "user://story-campaign.json"
var save_enabled := true
var enemy_serial := 0
var rng := RandomNumberGenerator.new()
var region_enemies: Dictionary={}
var explored: Dictionary={}
var routes: Dictionary={}

func new_state() -> Dictionary:
	var initial := {"version":1,"act":1,"stage":0,"unlocked_act":1,"hero":0,"xp":0,"coins":100,"materials":0,"potions":5,"hp":150.0,"completed":[],"accepted":[],"steps":{},"discovered":["1:0"],"defeated":{},"visited_objects":{},"bag":[],"stash":[],"gear":{"blade":0,"armor":0,"charm":0},"kits":[{"blade":0,"armor":0,"charm":0},{"blade":0,"armor":0,"charm":0},{"blade":0,"armor":0,"charm":0}],"specialties":[[0,0,0],[0,0,0],[0,0,0]],"forged":0,"queen_rescued":false,"ending_seen":false,"final_started":false,"rescue_prepared_at_battle":false}

	initial["queen_choice_made"]=false
	initial["waypoints"]=["1:0"]
	initial["opened_chests"]={}
	initial["explored"]={}
	return initial

func load_campaign(save_path: String = "") -> void:
	if save_path!="": path=save_path
	state=new_state()
	state["queen_choice_made"]=false
	state["waypoints"]=["1:0"]
	state["explored"]={}
	state["opened_chests"]={}
	if FileAccess.file_exists(path):
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not valid_save(parsed) and FileAccess.file_exists(path+".bak"):
			parsed=JSON.parse_string(FileAccess.get_file_as_string(path+".bak"))
		if valid_save(parsed):
			for key in state:
				if parsed.has(key):
					if typeof(parsed[key])==typeof(state[key]): state[key]=parsed[key]
					elif typeof(state[key])==TYPE_INT and (parsed[key] is float or parsed[key] is int): state[key]=int(parsed[key])
			if not parsed.has("kits"): state.kits[clampi(int(state.hero),0,2)]=state.gear.duplicate()
		else:
			# A damaged save is preserved until the player explicitly chooses a new slot.
			save_enabled=false
			notice.emit("战役存档无法读取；原文件已保留，当前游玩不会覆盖它。")
	state.act=clampi(int(state.act),1,6)
	state.stage=clampi(int(state.stage),0,8)
	state.hero=clampi(int(state.hero),0,2)
	for id in state.steps: state.steps[id]=int(state.steps[id])
	if state.kits.size()!=3: state.kits=new_state().kits
	if state.specialties.size()!=3: state.specialties=new_state().specialties
	for i in 3:
		if not state.kits[i] is Dictionary: state.kits[i]=new_state().kits[i]
		for slot in ["blade","armor","charm"]: state.kits[i][slot]=maxi(0,int(state.kits[i].get(slot,0)))
		if not state.specialties[i] is Array or state.specialties[i].size()!=3: state.specialties[i]=[0,0,0]
		for rank in 3: state.specialties[i][rank]=clampi(int(state.specialties[i][rank]),0,10)
	state.gear=state.kits[int(state.hero)]
	state.hp=clampf(float(state.hp),1,max_hp())
	explored=state.get("explored",{}); region_enemies.clear()
	enter(int(state.act),int(state.stage))

func valid_save(value: Variant) -> bool:
	if not value is Dictionary or int(value.get("version",0))!=1: return false
	if not value.get("completed") is Array or not value.get("steps") is Dictionary or not value.get("gear") is Dictionary: return false
	for field in ["act","stage","hero","xp","coins","potions"]:
		if not value.get(field) is float and not value.get(field) is int: return false
	if int(value.act)<1 or int(value.act)>6 or int(value.stage)<0 or int(value.stage)>8: return false
	for field in ["completed","accepted"]:
		if not value.get(field,[]) is Array: return false
		for id in value.get(field,[]):
			if not id is String or not content.quests.has(id): return false
	for id in value.steps:
		if not content.quests.has(id) or (not value.steps[id] is float and not value.steps[id] is int): return false
	for field in ["bag","stash"]:
		if not value.get(field,[]) is Array: return false
		for item in value.get(field,[]):
			if not item is Dictionary or not str(item.get("slot","")) in ["blade","armor","charm"] or not item.get("name") is String: return false
	return true

func save_campaign() -> bool:
	if not save_enabled: return false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: notice.emit("战役保存失败，当前进度仍保留在内存。"); return false
	file.store_string(JSON.stringify(state,"\t")); file.close()
	if FileAccess.file_exists(path):
		var backup_err := DirAccess.copy_absolute(path,path+".bak")
		if backup_err!=OK: notice.emit("无法备份战役存档，本次保存已停止。"); return false
	var err := DirAccess.rename_absolute(path+".tmp",path)
	if err!=OK: notice.emit("战役写入失败：%s" % error_string(err)); return false
	return true

func level() -> int:
	return clampi(1+int(sqrt(maxf(0,float(state.get("xp",0))))*0.30),1,50)

func max_hp() -> float:
	return 150.0+level()*9.0+int(state.get("gear",{}).get("armor",0))*18.0+specialty(1)*8.0

func damage() -> float:
	return 24.0+level()*5.0+int(state.gear.blade)*11.0+int(state.forged)*6.0+int(state.gear.charm)*3.0+specialty(0)*4.0

func specialty(index: int) -> int:
	return int(state.get("specialties",[[0,0,0],[0,0,0],[0,0,0]])[int(state.get("hero",0))][index])

func skill_points() -> int:
	return maxi(0,level()-1-specialty(0)-specialty(1)-specialty(2))

func learn(index: int) -> bool:
	if state.stage!=0 or index<0 or index>2 or skill_points()<=0 or specialty(index)>=10: return false
	state.specialties[int(state.hero)][index]+=1
	changed.emit(); save_campaign(); return true

func reset_specialty() -> bool:
	if state.stage!=0 or state.coins<100 or not "A3-M05" in state.completed: return false
	state.coins-=100; state.specialties[int(state.hero)]=[0,0,0]
	state.hp=minf(state.hp,max_hp()); changed.emit(); save_campaign(); return true

func restore_before_finale() -> bool:
	var checkpoint := path+".before-finale"
	if not FileAccess.file_exists(checkpoint): return false
	if not valid_save(JSON.parse_string(FileAccess.get_file_as_string(checkpoint))): return false
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".after-finale")!=OK: return false
	if DirAccess.copy_absolute(checkpoint,path)!=OK: return false
	load_campaign(path); return true

func current_main() -> Dictionary:
	for id in content.main_order:
		if not id in state.completed: return content.quests[id]
	return {}

func available(q: Dictionary) -> bool:
	if q.id=="E-M01" and not bool(state.get("queen_choice_made",false)): return false
	for id in q.requires:
		if not id in state.completed: return false
	return not q.id in state.completed

func key(a: int = -1, s: int = -1) -> String:
	return "%d:%d" % [state.act if a<0 else a,state.stage if s<0 else s]

func act_data() -> Dictionary:
	return content.acts[int(state.act)-1]

func enter(a: int, s: int, from_south: bool = false) -> void:
	if not state.is_empty() and not enemies.is_empty(): region_enemies[key()]=enemies
	state.act=a; state.stage=s
	var shape: String="camp" if s==0 else content.acts[a-1].maps[s-1].layout
	map.build(a,s,shape)
	hero_at=map.spawn if not from_south else map.regions[s].origin+map.regions[s].anchors[-1] if s>0 else Vector2(1100,1750)
	for i in 3: allies[i]=hero_at+Vector2((i-1)*75,-70)
	enemies=[]; effects.clear(); routes.clear(); gate_cd=1.0
	if not key() in state.discovered: state.discovered.append(key())
	if region_enemies.has(key()): enemies=region_enemies[key()]
	elif s>0: spawn_region()
	ensure_encounter()
	if a==6 and s==6 and not state.final_started and "A6-M05" in state.completed:
		state.final_started=true
		state.rescue_prepared_at_battle=prepared_rescue()
		if save_enabled and FileAccess.file_exists(path): DirAccess.copy_absolute(path,path+".before-finale")
	location_changed.emit(); changed.emit(); save_campaign()

func spawn_region() -> void:
	var types: Array=[[0,1,5],[6,12,13],[7,10,8],[2,8,11],[9,12,15],[4,11,16]][int(state.act)-1]
	var region=map.regions[int(state.stage)]
	for i in 22+int(state.act)*3:
		var pos: Vector2=region.origin+Vector2(850+(i*467)%3200,1000+(i*631)%3150)
		if not map.walkable(pos): continue
		spawn_enemy(pos,types[i%3],"mob-%d" % i)
	var q := current_main()
	if not q.is_empty() and q.id.ends_with("M06") and int(state.stage)==6 and int(q.act)==int(state.act):
		spawn_enemy(map.anchors[-1]+Vector2(0,-230),4,"boss",true)
	for id in state.accepted:
		var optional: Dictionary=content.quests[id]
		if optional.act==state.act and optional.stage==state.stage and id in ["A1-S04","A3-S02","A3-S03","A5-S03"]:
			spawn_enemy(map.side_anchors[-1],4,id,true)
	if state.stage>6: spawn_enemy(map.anchors[-1]+Vector2(0,-200),4,"exploration-guardian",true)

func spawn_enemy(pos: Vector2, type: int, id: String, boss: bool = false) -> void:
	var unique := key()+":"+id
	if state.defeated.has(unique): return
	var hp := (550.0+int(state.act)*300) if boss else (65.0+int(state.act)*30)
	var art: String=act_data().boss_art if boss else ""
	if id=="A1-S04": art="earthsplitter"
	if id=="A3-S02": art="storm-roc-v2"
	if id=="A3-S03": art="frostbone-dragon"
	if id=="A5-S03": art="moon-leviathan"
	if id=="exploration-guardian": art="earthsplitter" if state.act%2==1 else "thorn-huntsman"
	enemies.append({"id":unique,"quest":id,"p":pos,"type":type,"hp":hp,"maxhp":hp,"boss":boss,"art":art,"cd":1.4+float(enemies.size()%4)*0.3,"windup":0.0,"target":pos,"shape":"circle","radius":80.0,"phase":0,"flash":0.0})

func ensure_encounter() -> void:
	var q := current_main()
	if q.is_empty() or not q.id.ends_with("M06") or state.stage!=6 or q.act!=state.act: return
	for e in enemies:
		if e.quest=="boss": return
	spawn_enemy(map.anchors[-1]+Vector2(0,-230),4,"boss",true)

func accept(id: String) -> bool:
	if not content.quests.has(id): return false
	var q: Dictionary=content.quests[id]
	if not available(q): return false
	if not id in state.accepted:
		state.accepted.append(id)
		state.steps[id]=int(state.visited_objects.get(id,0))
		changed.emit(); save_campaign()
	return true

func step_count(q: Dictionary) -> int:
	return int(state.steps.get(q.id,0))

func objective_nodes() -> Array:
	var result: Array=[]
	if int(state.stage)==0:
		if not "E-M01" in state.completed and "A6-M06" in state.completed and state.act==6:
			result.append({"id":"E-M01","step":0,"p":Vector2(850,580),"label":"报平安 · 第一束光"})
		return result
	var ids: Array=state.accepted.duplicate()
	var main := current_main()
	if not main.is_empty() and main.act==state.act and main.stage==state.stage:
		if not main.id in ids: ids.push_front(main.id)
	for id in ids:
		var q: Dictionary=content.quests[id]
		if q.id in state.completed or q.act!=state.act or q.stage!=state.stage: continue
		var index := step_count(q)
		if index>=q.steps.size(): continue
		var positions: Array=map.anchors if q.kind=="main" else map.side_anchors
		var at: Vector2=positions[index%positions.size()]
		# Separate multiple optional objectives, without changing their authored room.
		if q.kind!="main": at+=Vector2((ids.find(id)%3)*85,0)
		result.append({"id":id,"step":index,"p":at,"label":q.steps[index]})
	return result

func interact_object(node: Dictionary) -> bool:
	if hero_at.distance_to(node.p)>110: return false
	var q: Dictionary=content.quests[node.id]
	if not available(q) or step_count(q)!=node.step: return false
	for e in enemies:
		if e.hp>0 and (e.p.distance_to(node.p)<260 or (e.boss and node.step>=q.steps.size()-1)):
			notice.emit("先解除附近威胁，再进行「%s」。" % node.label); return false
	state.steps[q.id]=node.step+1
	state.visited_objects[q.id]=node.step+1
	if step_count(q)>=q.steps.size(): complete(q.id)
	else:
		notice.emit("%s · %d/%d" % [q.title,step_count(q),q.steps.size()]); changed.emit(); save_campaign()
	audio_cue.emit("chest" if "取" in node.label or "箱" in node.label else "bell")
	return true

func complete(id: String, announce: bool = true) -> bool:
	if not content.quests.has(id) or id in state.completed: return false
	var q: Dictionary=content.quests[id]
	if not available(q): return false
	state.completed.append(id); state.accepted.erase(id)
	state.steps[id]=q.steps.size()
	state.xp+=260+int(q.act)*140
	state.coins+=35+int(q.act)*25
	state.materials+=2+int(q.act)
	state.potions=mini(15,int(state.potions)+1)
	state.hp=max_hp()
	if q.kind=="main" and id.ends_with("M06"):
		state.unlocked_act=maxi(int(state.unlocked_act),mini(6,int(q.act)+1))
		grant_equipment(int(q.act)+2,true)
	if id=="E-M01": state.ending_seen=true
	changed.emit(); save_campaign()
	if announce: chapter_read.emit(q.title,q.story+"\n\n【奖励】"+q.reward_text)
	audio_cue.emit("loot")
	return true

func south_gate() -> bool:
	var a := int(state.act); var s := int(state.stage)
	if s==0:
		if a==1:
			complete("P-M01",false); complete("P-M02",false); complete("P-M03",false)
		enter(a,1); notice.emit("进入%s · 北侧入口可返回%s。" % [act_data().maps[0].name,act_data().camp]); return true
	if s>=6: notice.emit("本幕尽头。回营地向地区联系人报告，使用跨幕交通。"); return false
	var id := "A%d-M%02d" % [a,s]
	if not id in state.completed:
		notice.emit("前方道路仍被封锁，先完成「%s」。" % content.quests[id].title); return false
	enter(a,s+1); return true

func next_act() -> bool:
	var a := int(state.act)
	if state.stage!=0 or a>=6 or not "A%d-M06" % a in state.completed: return false
	enter(a+1,0); return true

func travel(a: int, s: int) -> bool:
	if hero_at.distance_to(map.waypoint)>160 or not "%d:%d" % [a,s] in state.get("waypoints",["1:0"]): return false
	enter(a,s); hero_at=map.waypoint+Vector2(0,100)
	for i in 3: allies[i]=hero_at+Vector2((i-1)*50,65)
	location_changed.emit(); return true

func activate_waypoint() -> void:
	if hero_at.distance_to(map.waypoint)>160: return
	if not state.has("waypoints"): state["waypoints"]=["1:0"]
	if not key() in state.waypoints: state.waypoints.append(key()); notice.emit("传送阵已激活，可在任意已激活传送阵之间旅行。")
	save_campaign(); changed.emit()

func change_sector(s: int) -> void:
	# Crossing a region preserves the exact position, camera, combat and companions.
	region_enemies[key()]=enemies
	state.stage=s; map.activate(s); enemies=[]; routes.clear()
	if region_enemies.has(key()): enemies=region_enemies[key()]
	elif s>0: spawn_region()
	ensure_encounter()
	if not key() in state.discovered: state.discovered.append(key())
	if state.act==1 and s>0:
		complete("P-M01",false); complete("P-M02",false); complete("P-M03",false)
	location_changed.emit(); changed.emit(); save_campaign()
	notice.emit("进入 "+(act_data().camp if s==0 else act_data().maps[s-1].name))

func use_entrance(door: Dictionary) -> void:
	if hero_at.distance_to(door.p)>150: return
	if door.kind=="exit":
		var destination: Dictionary=map.return_door(int(state.stage))
		if destination.is_empty(): return
		enter(int(state.act),int(destination.source)); hero_at=destination.p+Vector2(0,150)
	else: enter(int(state.act),int(door.stage))
	for i in 3: allies[i]=hero_at+Vector2((i-1)*50,65)
	location_changed.emit()

func nearby_chests() -> Array:
	var result: Array=[]
	var region=map.regions[int(state.stage)]
	for i in region.chests.size():
		var id := key()+":cache:"+str(i)
		if not state.get("opened_chests",{}).has(id): result.append({"id":id,"p":region.origin+region.chests[i],"label":"探索宝箱"})
	return result

func open_cache(item: Dictionary) -> bool:
	if hero_at.distance_to(item.p)>130 or state.get("opened_chests",{}).has(item.id): return false
	if not state.has("opened_chests"): state["opened_chests"]={}
	state.opened_chests[item.id]=true; state.coins+=30+int(state.act)*12; grant_equipment(int(state.act))
	changed.emit(); audio_cue.emit("chest"); save_campaign(); return true

func grant_equipment(tier: int, fixed: bool = false) -> void:
	var slot: String=["blade","armor","charm"][rng.randi_range(0,2)]
	var item := {"slot":slot,"tier":tier,"name":["赤晶锋刃","晨钟护衣","守望护符"][["blade","armor","charm"].find(slot)]+" +%d" % tier}
	if state.bag.size()<24: state.bag.append(item)
	else: state.stash.append(item)
	if fixed: notice.emit("章节装备已放入行囊；行囊满时自动存入仓库。")

func equip(index: int) -> void:
	if index<0 or index>=state.bag.size(): return
	var item: Dictionary=state.bag[index]
	var previous := int(state.gear.get(item.slot,0))
	state.gear[item.slot]=int(item.tier)
	state.kits[int(state.hero)]=state.gear
	state.bag.remove_at(index)
	if previous>0: state.bag.append({"slot":item.slot,"tier":previous,"name":"卸下的%s +%d" % [item.slot,previous]})
	state.hp=minf(state.hp,max_hp()); changed.emit(); save_campaign()

func store(index: int, withdraw: bool = false) -> bool:
	var source: Array=state.stash if withdraw else state.bag
	var target: Array=state.bag if withdraw else state.stash
	if index<0 or index>=source.size() or (withdraw and target.size()>=24): return false
	target.append(source[index]); source.remove_at(index); changed.emit(); save_campaign(); return true

func service(kind: String) -> bool:
	if int(state.stage)!=0: return false
	match kind:
		"heal": state.hp=max_hp(); state.potions=maxi(5,int(state.potions))
		"trade":
			if state.coins<20 or state.potions>=15: return false
			state.coins-=20; state.potions+=1
		"forge":
			var cost := 40+int(state.forged)*25
			if state.coins<cost or state.materials<3 or state.forged>=10: return false
			state.coins-=cost; state.materials-=3; state.forged+=1
		_: return false
	changed.emit(); save_campaign(); return true

func prepared_routes() -> bool:
	for id in ["A1-S03","A2-S04","A3-S04","A4-S04","A5-S02","A6-S04"]:
		if not id in state.completed: return false
	return true

func prepared_rescue() -> bool:
	for id in ["C-F01","C-F02","C-F03","C-X01","C-X02","C-X03","C-Y01","C-Y02","C-Y03","A6-S02"]:
		if not id in state.completed: return false
	return true

func choose_rescue(rescue: bool) -> bool:
	if not "A6-M06" in state.completed or "E-M01" in state.completed: return false
	if rescue and not prepared_rescue(): return false
	if rescue and not state.rescue_prepared_at_battle: return false
	state.queen_rescued=rescue
	state["queen_choice_made"]=true
	save_campaign(); changed.emit(); return true

func switch_hero(index: int) -> void:
	if index<0 or index>2: return
	var old := int(state.hero)
	allies[old]=hero_at; hero_at=allies[index]; state.hero=index
	state.gear=state.kits[index]
	state.hp=minf(state.hp,max_hp())
	changed.emit()

func heal() -> bool:
	if state.potions<=0 or state.hp>=max_hp(): return false
	state.potions-=1; state.hp=minf(max_hp(),float(state.hp)+max_hp()*0.5)
	audio_cue.emit("heal")
	changed.emit(); save_campaign(); return true

func attack(aim: Vector2, special: int = 0) -> bool:
	if state.stage==0 or state.hp<=0: return false
	if special==0 and attack_cd>0: return false
	if special==1 and skill_cd>0: return false
	if special==2 and ultimate_cd>0: return false
	facing=aim.normalized() if aim.length()>0.01 else facing
	attack_time=0.38
	if special==0: attack_cd=0.42
	if special==1:
		skill_cd=maxf(2.0,5.0-int(state.gear.charm)*0.15-specialty(2)*0.2)
		if state.hero==1: hurt_time=1.5; state.hp=minf(max_hp(),float(state.hp)+max_hp()*0.08)
		if state.hero==2: hero_at=map.move(hero_at,facing*180.0)
	if special==2: ultimate_cd=24.0
	audio_cue.emit("magic" if state.hero==1 else "slash")
	var radius: float=200.0 if state.hero==0 else 580.0 if state.hero==1 else 245.0
	if special==1: radius=430.0
	if special==2: radius=670.0
	effects.append({"p":hero_at,"aim":facing,"time":0.36 if special<2 else 0.9,"total":0.36 if special<2 else 0.9,"kind":"attack","hero":state.hero,"special":special,"radius":radius})
	if special==2:
		var target := hero_at+facing*400
		for e in enemies:
			if e.hp>0 and e.boss and e.p.distance_to(hero_at)<radius: target=e.p; break
		for i in 3: effects.append({"p":allies[i],"target":target,"aim":facing,"time":0.9,"total":0.9,"kind":"converge","hero":i,"special":2,"radius":radius})
	for e in enemies:
		if e.hp<=0: continue
		var delta: Vector2=e.p-hero_at
		var in_arc: bool=special==2 or delta.length()<80 or delta.normalized().dot(facing)>(-0.1 if special==1 else 0.25)
		if delta.length()<=radius and in_arc and map.sight(hero_at,e.p):
			hit(e,damage()*([1.0,2.3,5.0][special]))
	return true

func hit(e: Dictionary, amount: float) -> void:
	if e.hp<=0: return
	e.hp=maxf(0,e.hp-amount); e.flash=0.15
	if e.hp<=0:
		audio_cue.emit("death")
		state.defeated[e.id]=true
		state.xp+=30 if not e.boss else 300
		state.coins+=6 if not e.boss else 100
		state.materials+=1 if e.boss else 0
		if e.boss or rng.randf()<0.20: grant_equipment(int(state.act)+(2 if e.boss else 0))
		changed.emit(); save_campaign()

func update(dt: float, motion: Vector2) -> void:
	clock+=dt; auto_save+=dt
	for field in ["attack_time","hurt_time","attack_cd","skill_cd","ultimate_cd","gate_cd"]:
		set(field,maxf(0,float(get(field))-dt))
	moving=motion.length()>0.01
	if moving and attack_time<=0: facing=motion.normalized()
	if dodge_time>0:
		dodge_time=maxf(0,dodge_time-dt); motion=dodge_vector*2.8
	hero_at=map.move(hero_at,motion*310.0*dt)
	allies[int(state.hero)]=hero_at
	for i in 3:
		if i==state.hero: continue
		var target := hero_at+Vector2(-90 if i==1 else 90,-95)
		if allies[i].distance_to(target)>80: allies[i]=map.move(allies[i],steer("ally-%d" % i,allies[i],target)*300*dt)
	# Companions contribute steadily; their attacks do not bypass geometry.
	if int(clock*2)!=int((clock-dt)*2):
		for i in 3:
			if i==state.hero: continue
			for e in enemies:
				if e.hp>0 and e.p.distance_to(allies[i])<350 and map.sight(allies[i],e.p):
					hit(e,damage()*0.30); break
	for e in enemies:
		if e.hp<=0: continue
		e.flash=maxf(0,e.flash-dt)
		var distance: float=e.p.distance_to(hero_at)
		if distance>900: continue
		if e.windup>0:
			e.windup-=dt
			if e.windup<=0:
				var diff: Vector2=hero_at-e.target
				var caught: bool=diff.length()<e.radius
				if e.shape=="ring": caught=diff.length()>100 and diff.length()<e.radius
				if e.shape=="cross": caught=(absf(diff.x)<65 or absf(diff.y)<65) and diff.length()<e.radius
				if caught and hurt_time<=0 and dodge_time<=0:
					state.hp-=maxf(3,(25 if e.boss else 9)+int(state.act)*4-int(state.gear.armor)*2)
					hurt_time=0.55; changed.emit()
					effects.append({"p":e.target,"time":0.3,"total":0.3,"kind":"impact","radius":e.radius,"hero":0,"special":0,"aim":Vector2.RIGHT})
		else:
			e.cd-=dt
			if distance>(300 if e.boss else 80):
				var direction: Vector2=steer(e.id,e.p,hero_at)
				for other in enemies:
					if other==e or other.hp<=0: continue
					var separation: Vector2=e.p-other.p
					if separation.length()<95 and separation.length()>0.1: direction+=separation.normalized()*(1.0-separation.length()/95)*2.0
				e.p=map.move(e.p,direction.limit_length(1.0)*(65 if e.boss else 105)*dt)
			if e.cd<=0 and distance<(650 if e.boss else 120):
				e.cd=2.8 if e.boss else 1.7
				e.windup=1.15 if e.boss else 0.55
				e.target=hero_at; e.radius=380.0 if e.boss else 100.0
				if e.boss:
					e.phase=mini(2,int((1.0-e.hp/e.maxhp)*3))
					e.shape=["circle","ring","cross"][(int(clock/2)+int(e.phase))%3]
					if e.shape=="ring": e.target=e.p
	for i in range(effects.size()-1,-1,-1):
		effects[i].time-=dt
		if effects[i].time<=0: effects.remove_at(i)
	if state.hp<=0:
		state.hp=max_hp(); enter(int(state.act),0)
		notice.emit("小队将你带回营地。已完成任务和物品保留，未完成交战从入口继续。")
	if map.layer==0:
		var sector: int=map.region_at(hero_at)
		if sector>=0 and sector!=state.stage: change_sector(sector)
	for y in range(-2,3):
		for x in range(-2,3):
			var p := hero_at+Vector2(x,y)*240
			if p.distance_to(hero_at)>520 or not map.sight(hero_at,p): continue
			var cell := "%d:%d:%d:%d" % [state.act,map.layer,int(floor(p.x/240)),int(floor(p.y/240))]
			explored[cell]=true
	state["explored"]=explored
	if auto_save>15:
		auto_save=0; save_campaign()

func dodge(direction: Vector2) -> void:
	if dodge_time>0 or state.stage==0: return
	dodge_vector=direction.normalized() if direction.length()>0.1 else facing
	dodge_time=0.22
	audio_cue.emit("dash")

func steer(id: String, from: Vector2, goal: Vector2) -> Vector2:
	if map.sight(from,goal): return from.direction_to(goal)
	var cached: Dictionary=routes.get(id,{})
	if cached.is_empty() or float(cached.until)<clock or Vector2(cached.goal).distance_to(goal)>180:
		cached={"points":map.route(from,goal),"goal":goal,"until":clock+1.1}; routes[id]=cached
	var points: PackedVector2Array=cached.points
	while not points.is_empty() and from.distance_to(points[0])<45: points.remove_at(0)
	cached.points=points
	return from.direction_to(points[0]) if not points.is_empty() else Vector2.ZERO
