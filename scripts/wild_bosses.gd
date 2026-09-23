extends RefCounted
## Additional non-humanoid encounters. All hit checks remain host authoritative.
const Presentation = preload("res://scripts/boss_presentation.gd")
const NAMES := ["裂地钻兽 · 断层", "雷骸巨鸟 · 风暴眼", "吞月渊蛇 · 无光潮"]
const HEALTH := [2000.0,2800.0,9200.0]
const BASE_DAMAGE := [31.0,37.0,51.0]

func spawn_mini(s, day: int, forced_kind: int = -1) -> void:
	if s.map_id!="border" or day not in [1,2]: return
	var occupied: Array=[]
	for e in s.enemies:
		if e.get("mini_boss",false): occupied.append(int(e.get("habitat",-1)))
	var choice := -1
	var best := -1.0
	for i in s.ruins.sites.size():
		var site: Dictionary=s.ruins.sites[i]
		var at: Vector2=site.p
		if site.get("cleared",false) or occupied.has(i) or s.ruins.blocked(at,55): continue
		var distance := at.distance_to(Ruins.SPAWN)
		if distance<500 or at.distance_to(s.raid.center)<480: continue
		if distance>best:
			best=distance
			choice=i
	if choice<0: return
	var at: Vector2=s.ruins.sites[choice].p
	var participants := 0
	for p in s.players.values():
		if p.status in ["active","down"]: participants+=1
	var kind := forced_kind if forced_kind in [0,1] else day-1
	var hp: float=HEALTH[kind]*(1.0+0.75*maxi(0,participants-1))
	s.enemies.append({"id":s.next_enemy,"p":at,"home":at,"habitat":choice,"type":4,
		"mini_boss":true,"wild_boss":true,"wild_kind":kind,"boss_kind":2 if kind==0 else 0,
		"boss_name":NAMES[kind],"hp":hp,"max_hp":hp,"cd":2.0,"last":1,
		"wander":Vector2.ZERO,"facing":1.0,"motion_phase":0.0,"moving":false,
		"attack_time":0.0,"attack_total":0.0,"attack_released":false,
		"attack_aim":Vector2.RIGHT,"sequence":0,"phase":1,"flash":0.0,
		"poise":0.0,"stagger":0.0})
	s.next_enemy+=1
	# Exploration cut-in is sent when the creature is first approached.

func spawn_final(s) -> void:
	s.raid.abyss_spawned=true
	s.raid.hazards.clear()
	s.bullets.clear()
	var participants := 0
	for p in s.players.values():
		if p.status in ["active","down"]: participants+=1
	var hp: float=HEALTH[2]*(1.0+0.80*maxi(0,participants-1))
	var at: Vector2=s.raid.center
	s.enemies.append({"id":s.next_enemy,"p":at,"type":4,"raid_boss":true,
		"wild_boss":true,"wild_kind":2,"abyss_final":true,"boss_kind":2,
		"boss_name":NAMES[2],"hp":hp,"max_hp":hp,"cd":2.5,"last":1,
		"wander":Vector2.ZERO,"facing":1.0,"motion_phase":0.0,"moving":false,
		"attack_time":0.0,"attack_total":0.0,"attack_released":false,
		"attack_aim":Vector2.RIGHT,"sequence":0,"phase":1,"flash":0.0,"stagger":0.0})
	s.next_enemy+=1
	Presentation.send(s,s.enemies.back(),"entrance")

func update(s, e: Dictionary, dt: float) -> void:
	e.flash=maxf(0.0,float(e.flash)-dt)
	e.stagger=maxf(0.0,float(e.get("stagger",0.0))-dt)
	e.attack_time=maxf(0.0,float(e.attack_time)-dt)
	e.cd=maxf(0.0,float(e.cd)-dt)
	if e.stagger>0:
		if e.has("travel_target"):
			for i in range(s.raid.hazards.size()-1,-1,-1):
				if int(s.raid.hazards[i].get("source",-1))==int(e.id): s.raid.hazards.remove_at(i)
			e.erase("travel_target")
			e.erase("travel_mark")
			e.attack_time=0.0
			e.cd=maxf(e.cd,0.9)
			Presentation.send(s,e,"break")
		return
	if e.has("travel_target") and e.attack_time<=e.attack_total-float(e.get("travel_mark",0.0)):
		e.p=e.travel_target
		e.erase("travel_target")
		e.erase("travel_mark")
	var phase := 3 if e.get("abyss_final",false) and e.hp<=e.max_hp*0.30 else 2 if e.hp<=e.max_hp*0.55 else 1
	if phase!=int(e.phase):
		e.phase=phase
		Presentation.send(s,e,"phase")
	var target: Dictionary={}
	var best := 900.0 if not e.get("abyss_final",false) else INF
	for p in s.players.values():
		if p.status=="active" and p.p.distance_to(e.p)<best:
			target=p
			best=p.p.distance_to(e.p)
	if target.is_empty() or e.cd>0 or e.attack_time>0: return
	if not e.get("revealed",false) and not e.get("abyss_final",false):
		e.revealed=true
		Presentation.send(s,e,"entrance")
	var aim: Vector2=(target.p-e.p).normalized()
	if aim.length_squared()<0.1: aim=Vector2.RIGHT
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	var moves: Array=["burrow","fault","molt","collapse"] if int(e.wild_kind)==0 else ["dive","front","feathers","thunder_eye"] if int(e.wild_kind)==1 else ["coil","undertow","maw","black_tide","devour"]
	var move: String=moves[int(e.sequence)%moves.size()]
	e.sequence+=1
	cast(s,e,target,move,aim)

func cast(s, e: Dictionary, target: Dictionary, move: String, aim: Vector2) -> void:
	var kind: int=e.wild_kind
	var phase: int=e.phase
	var damage: float=BASE_DAMAGE[kind]*(1.0+0.12*(phase-1))
	var first: int=s.raid.hazards.size()
	e.attack_aim=aim
	e.move_id=move
	match move:
		"burrow":
			e.move_name="钻地突袭 · 离开沙脊，避开出土点"
			var origin: Vector2=e.p
			var destination: Vector2=target.p-aim*115
			if s.ruins.blocked(destination,40): destination=origin+aim*minf(260,origin.distance_to(target.p))
			var path: Vector2=destination-origin
			if path.length()>40: lane(s,origin,path.normalized(),path.length(),72,1.05,damage)
			s.expedition.hazard(s,"circle",destination,aim,95,1.35,damage*1.15)
			e.travel_target=destination
			e.travel_mark=1.05
			if phase>=2: s.expedition.hazard(s,"ring",destination,aim,255,1.85,damage*0.8,120)
		"fault":
			e.move_name="断层裂谷 · 在裂缝之间穿行"
			for i in (5 if phase>=2 else 3):
				var angle: float=(i-(2 if phase>=2 else 1))*0.42
				lane(s,e.p,aim.rotated(angle),480,39,0.75+absf(angle)*0.75,damage)
		"molt":
			e.move_name="岩甲蜕壳 · 追随缺口脱离震波"
			gap_ring(s,e.p,aim.rotated(0.8),320,105,0.58,1.25,damage)
			if phase>=2: gap_ring(s,e.p,aim.rotated(-0.8),420,300,0.58,2.0,damage)
		"collapse":
			e.move_name="地穴塌陷 · 远离落点，回身穿缝"
			for p in s.players.values():
				if p.status=="active": s.expedition.hazard(s,"circle",p.p,aim,120,0.92,damage)
			lane(s,e.p,aim.orthogonal(),440,57,1.65,damage)
		"dive":
			e.move_name="裂空俯冲 · 横穿飞行路线"
			var origin: Vector2=e.p
			var landing: Vector2=target.p+aim*150
			if s.ruins.blocked(landing,40): landing=target.p
			var path: Vector2=landing-origin
			if path.length()>40: lane(s,origin,path.normalized(),path.length(),62,0.82,damage*1.1)
			e.travel_target=landing
			e.travel_mark=0.82
			if phase>=2: lane(s,origin,path.normalized(),path.length(),82,1.55,damage*0.75)
		"front":
			e.move_name="雷暴锋面 · 寻找未落雷的通道"
			var side: Vector2=aim.orthogonal()
			for i in [-2,-1,1,2]:
				lane(s,e.p+side*i*100,aim,520,39,1.1+abs(i)*0.17,damage)
		"feathers":
			e.move_name="雷羽散射 · 看准羽隙绕翼"
			for i in 5+phase:
				var fan: Vector2=aim.rotated((i-(4+phase)*0.5)*0.26)
				lane(s,e.p,fan,480,20,0.7+i*0.13,damage*0.76)
		"thunder_eye":
			e.move_name="风暴眼 · 外侧闪电向内收束"
			s.expedition.hazard(s,"ring",e.p,aim,440,0.9,damage,270)
			s.expedition.hazard(s,"ring",e.p,aim,285,1.52,damage,110)
			if phase>=2: s.expedition.hazard(s,"circle",target.p,aim,85,2.1,damage)
		"coil":
			e.move_name="噬月盘绕 · 沿亮起的扇区穿过潮墙"
			gap_ring(s,e.p,aim,330,95,0.45,1.15,damage)
			gap_ring(s,e.p,aim.rotated(1.15),420,205,0.45,2.05,damage)
			if phase==3: gap_ring(s,e.p,aim.rotated(-1.15),470,300,0.45,2.85,damage)
		"undertow":
			e.move_name="深渊逆流 · 利用水道间的空隙"
			var side: Vector2=aim.orthogonal()
			for i in [-2,-1,1,2]: lane(s,e.p+side*i*125,aim,610,48,0.9+abs(i)*0.18,damage)
			if phase>=2: lane(s,e.p-aim*520,side,1040,45,1.95,damage)
		"maw":
			e.move_name="吞月之口 · 躲到头部侧后方"
			s.expedition.hazard(s,"cone",e.p,aim,490,1.45,damage*1.25)
			s.raid.hazards.back().arc=0.72
			if phase>=2: s.expedition.hazard(s,"circle",target.p,aim,110,2.0,damage)
		"black_tide":
			e.move_name="无光潮汐 · 缺口随潮流转动"
			for i in 3:
				gap_ring(s,e.p,aim.rotated(i*0.85),260+i*80,80+i*75,0.52,0.95+i*0.76,damage)
		"devour":
			e.move_name="终夜吞噬 · 穿越潮墙后躲开噬咬"
			gap_ring(s,e.p,aim.rotated(0.6),420,100,0.4,1.45,damage)
			s.expedition.hazard(s,"cone",e.p,aim.rotated(-0.6),490,2.25,damage*1.35)
			s.raid.hazards.back().arc=0.75
			s.expedition.hazard(s,"circle",target.p,aim,130,2.85,damage)
	var marks: Array=[]
	for i in range(first,s.raid.hazards.size()):
		var h: Dictionary=s.raid.hazards[i]
		h.merge({"source":e.id,"boss_kind":int(e.boss_kind),"move":move,"part":i-first,
			"phase":phase,"wild_boss":true,"wild_kind":kind,"abyss_final":e.get("abyss_final",false)},true)
		h.tempo="快" if h.total<=0.8 else "慢" if h.total>=1.45 else ""
		if not marks.has(h.total): marks.append(h.total)
	marks.sort()
	if marks.is_empty(): return
	e.attack_marks=marks
	e.windup=marks[0]
	e.attack_total=float(marks.back())+0.4
	e.attack_time=e.attack_total
	e.cd=maxf(e.attack_total+0.55,2.8 if phase==1 else 2.4)
	Presentation.send(s,e,"charge",{"total":marks[0]})

func lane(s, at: Vector2, aim: Vector2, length: float, half_width: float, delay: float, damage: float) -> void:
	s.expedition.hazard(s,"lane",at,aim,length,delay,damage,half_width)

func gap_ring(s, at: Vector2, gap_aim: Vector2, radius: float, inner: float, gap_half_angle: float, delay: float, damage: float) -> void:
	s.expedition.hazard(s,"gap_ring",at,gap_aim,radius,delay,damage,inner)
	s.raid.hazards.back().gap=gap_half_angle

func defeated(s, e: Dictionary) -> void:
	for i in range(s.raid.hazards.size()-1,-1,-1):
		if int(s.raid.hazards[i].get("source",-1))==int(e.id): s.raid.hazards.remove_at(i)
	if e.get("abyss_final",false):
		var final_chest: Dictionary=s.loot_container(e.p,Vector2i(7,7),5,true)
		final_chest.merge({"fixed_loot":true,"reward_tier":5,"title":str(e.boss_name)+" · 海母遗珍","open":true},true)
		s.place_entry(final_chest,"abyss_shedding")
		s.place_entry(final_chest,"abyssal_motherheart")
		for item in ["medicine","ammo","relic","relic"]: s.place_entry(final_chest,item)
		final_chest.searched=s.container_units(final_chest)
		s.append_chest(final_chest)
		return
	s.expedition.record_map_boss_defeat(s,e)
	s.raid.wild_seals[int(e.wild_kind)]=true
	var quality := 3 if int(e.wild_kind)==0 else 4
	var chest: Dictionary=s.loot_container(e.p,Vector2i(7,7),quality,true)
	chest.merge({"fixed_loot":true,"reward_tier":quality,
		"title":str(e.boss_name)+" · 异兽遗藏","open":true},true)
	s.place_entry(chest,["fault_scale","storm_feather"][int(e.wild_kind)])
	s.place_entry(chest,"fault_pulse_fossil" if int(e.wild_kind)==0 else "thunder_coffin_nail")
	if int(e.wild_kind)==1: s.place_entry(chest,"storm_roc_sunheart")
	s.place_entry(chest,Catalog.make_equipment("weapon",Catalog.roll_weapon(s.rng),quality))
	for item in ["medicine","medicine","ammo","relic","relic"]: s.place_entry(chest,item)
	chest.searched=s.container_units(chest)
	s.append_chest(chest)
