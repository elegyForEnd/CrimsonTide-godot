extends RefCounted
## A grounded, four-legged lair guardian. Frost patches continue to pulse after impact.
const Presentation = preload("res://scripts/boss_presentation.gd")
const NAME := "霜骨古龙 · 苍殒"
const HEALTH := 3500.0
const BASE_DAMAGE := 40.0

func spawn(s, day: int) -> void:
	if day not in [1,2] or s.map_id!="border": return
	var occupied: Array=[]
	for e in s.enemies:
		if e.get("mini_boss",false): occupied.append(int(e.get("habitat",-1)))
	var choice := -1
	var best := -1.0
	for i in s.ruins.sites.size():
		var site: Dictionary=s.ruins.sites[i]
		var at: Vector2=site.p
		if site.get("cleared",false) or occupied.has(i) or s.ruins.blocked(at,58): continue
		var distance := at.distance_to(Ruins.SPAWN)
		if distance<480 or at.distance_to(s.raid.center)<470: continue
		if distance>best:
			best=distance
			choice=i
	if choice<0: return
	var at: Vector2=s.ruins.sites[choice].p
	var participants := 0
	for p in s.players.values():
		if p.status in ["active","down"]: participants+=1
	var hp: float=HEALTH*(1.0+0.75*maxi(0,participants-1))
	s.enemies.append({"id":s.next_enemy,"p":at,"home":at,"habitat":choice,"type":4,
		"mini_boss":true,"dragon_boss":true,"boss_kind":3,"boss_name":NAME,
		"hp":hp,"max_hp":hp,"cd":2.1,"last":1,"wander":Vector2.ZERO,
		"facing":1.0,"motion_phase":0.0,"moving":false,"attack_time":0.0,
		"attack_total":0.0,"attack_released":false,"attack_aim":Vector2.RIGHT,
		"sequence":0,"phase":1,"flash":0.0,"poise":0.0,"stagger":0.0})
	s.next_enemy+=1

func update(s, e: Dictionary, dt: float) -> void:
	e.flash=maxf(0.0,float(e.flash)-dt)
	e.stagger=maxf(0.0,float(e.get("stagger",0.0))-dt)
	e.attack_time=maxf(0.0,float(e.attack_time)-dt)
	e.cd=maxf(0.0,float(e.cd)-dt)
	if e.stagger>0: return
	var phase := 2 if e.hp<=e.max_hp*0.50 else 1
	if phase!=int(e.phase):
		e.phase=phase
		Presentation.send(s,e,"phase")
	var target: Dictionary={}
	var best := 900.0
	for p in s.players.values():
		if p.status=="active" and p.p.distance_to(e.p)<best:
			target=p
			best=p.p.distance_to(e.p)
	if target.is_empty() or e.cd>0 or e.attack_time>0: return
	if not e.get("revealed",false):
		e.revealed=true
		Presentation.send(s,e,"entrance")
	var aim: Vector2=(target.p-e.p).normalized()
	if aim.length_squared()<0.1: aim=Vector2.RIGHT
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	var moves := ["breath","tail","wings","ice_bloom"]
	var move: String=moves[int(e.sequence)%moves.size()]
	e.sequence+=1
	cast(s,e,target,move,aim)

func cast(s, e: Dictionary, target: Dictionary, move: String, aim: Vector2) -> void:
	var phase: int=e.phase
	var damage: float=BASE_DAMAGE*(1.0+0.12*(phase-1))
	var first: int=s.raid.hazards.size()
	e.attack_aim=aim
	e.move_id=move
	match move:
		"breath":
			e.move_name="苍白吐息 · 随龙头方向扫掠，冰痕会残留"
			var count := 4 if phase==2 else 3
			for i in count:
				var angle: float=-0.65+1.30*float(i)/float(count-1)
				var direction: Vector2=aim.rotated(angle)
				s.expedition.hazard(s,"cone",e.p,direction,350,0.72+i*0.34,damage)
				s.raid.hazards.back().arc=0.35
				frost_pool(s,e.p+direction*245,1.05+i*0.34,damage*0.36)
		"tail":
			e.move_name="古龙摆尾 · 躲开身后弧带"
			arc(s,e.p,-aim,310,95,1.20,0.78,damage*1.15)
			if phase==2: arc(s,e.p,(-aim).rotated(0.90),335,120,0.90,1.43,damage)
		"wings":
			e.move_name="霜翼拍地 · 两翼先后压下，中轴留空"
			for side in [-1.0,1.0]:
				s.expedition.hazard(s,"cone",e.p,aim.rotated(side*PI*0.52),320,0.74 if side<0 else 1.23,damage)
				s.raid.hazards.back().arc=0.52
			if phase==2: frost_pool(s,target.p,1.82,damage*0.42)
		"ice_bloom":
			e.move_name="霜华绽裂 · 观察交错落冰，避开残留寒域"
			for i in 6:
				var point: Vector2=e.p+Vector2.from_angle(aim.angle()+TAU*i/6.0)*215
				frost_pool(s,point,0.94+(i%2)*0.62,damage*0.42)
			if phase==2: s.expedition.hazard(s,"circle",target.p,aim,105,2.12,damage)
	var marks: Array=[]
	for i in range(first,s.raid.hazards.size()):
		var h: Dictionary=s.raid.hazards[i]
		h.merge({"source":e.id,"boss_kind":int(e.boss_kind),"move":move,"part":i-first,
			"phase":phase,"dragon_boss":true},true)
		h.tempo="快" if h.total<=0.8 else "慢" if h.total>=1.4 else ""
		if not marks.has(h.total): marks.append(h.total)
	marks.sort()
	if marks.is_empty(): return
	e.attack_marks=marks
	e.windup=marks[0]
	e.attack_total=float(marks.back())+0.4
	e.attack_time=e.attack_total
	e.cd=maxf(e.attack_total+0.7,3.0 if phase==1 else 2.65)
	Presentation.send(s,e,"charge",{"total":marks[0]})

func arc(s, at: Vector2, direction: Vector2, radius: float, inner: float, half_angle: float, delay: float, damage: float) -> void:
	s.expedition.hazard(s,"arc",at,direction,radius,delay,damage,inner)
	s.raid.hazards.back().arc=half_angle

func frost_pool(s, at: Vector2, delay: float, damage: float) -> void:
	s.expedition.hazard(s,"circle",at,Vector2.RIGHT,78,delay,damage)
	var h: Dictionary=s.raid.hazards.back()
	h.linger=2.8
	h.pulse_interval=0.75
	h.next_pulse=0.75

func defeated(s, e: Dictionary) -> void:
	s.expedition.record_map_boss_defeat(s,e)
	for i in range(s.raid.hazards.size()-1,-1,-1):
		if int(s.raid.hazards[i].get("source",-1))==int(e.id): s.raid.hazards.remove_at(i)
	s.raid.dragon_slain=true
	var chest: Dictionary=s.loot_container(e.p,Vector2i(6,6),4,true)
	chest.merge({"fixed_loot":true,"reward_tier":4,"title":NAME+" · 龙巢遗珍","open":true},true)
	for item in ["medicine","medicine","ammo","relic","relic","relic"]: s.place_entry(chest,item)
	s.place_entry(chest,"frost_teardrop")
	s.place_entry(chest,Catalog.make_equipment("weapon",Catalog.roll_weapon(s.rng),4))
	chest.searched=s.container_units(chest)
	s.append_chest(chest)
