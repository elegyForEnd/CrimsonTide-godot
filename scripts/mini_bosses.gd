extends RefCounted
## Optional exploration guardians. Their hazards use the authoritative raid hazard clock.
const Presentation = preload("res://scripts/boss_presentation.gd")
const NAMES := ["镜墓纺女 · 碎影", "余烬司祭 · 晚祷"]
const THEMES := [3, 1]
const HEALTH := [1300.0,2200.0]
const BASE_DAMAGE := [25.0,35.0]

func spawn(s, day: int, forced_index: int = -1) -> void:
	if s.map_id!="border" or day not in [1,2]: return
	var occupied: Array=[]
	for e in s.enemies:
		if e.get("mini_boss",false): occupied.append(int(e.get("habitat",-1)))
	var choice := -1
	var best := -1.0
	for i in s.ruins.sites.size():
		var site: Dictionary=s.ruins.sites[i]
		if site.get("cleared",false) or occupied.has(i): continue
		var at: Vector2=site.p
		if s.ruins.blocked(at,42): continue
		var distance := at.distance_to(Ruins.SPAWN)
		if distance<550 or at.distance_to(s.raid.center)<500: continue
		if distance>best:
			best=distance
			choice=i
	if choice<0: return
	var at: Vector2=s.ruins.sites[choice].p
	var index := forced_index if forced_index in [0,1] else day-1
	var participants := 0
	for p in s.players.values():
		if p.status in ["active","down"]: participants+=1
	var hp: float=HEALTH[index]*(1.0+0.75*maxi(0,participants-1))
	s.enemies.append({"id":s.next_enemy,"p":at,"home":at,"habitat":choice,"type":4,
		"mini_boss":true,"boss_kind":THEMES[index],"mini_kind":index,"boss_name":NAMES[index],
		"hp":hp,"max_hp":hp,"cd":2.0,"last":1,"wander":Vector2.ZERO,"facing":1.0,
		"motion_phase":0.0,"moving":false,"attack_time":0.0,"attack_total":0.0,
		"attack_released":false,"attack_aim":Vector2.RIGHT,"sequence":0,
		"phase":1,"flash":0.0,"poise":0.0,"stagger":0.0})
	s.next_enemy+=1
	Presentation.send(s,s.enemies.back(),"entrance")

func update(s, e: Dictionary, dt: float) -> void:
	e.flash=maxf(0.0,float(e.flash)-dt)
	e.stagger=maxf(0.0,float(e.get("stagger",0))-dt)
	e.attack_time=maxf(0.0,float(e.attack_time)-dt)
	e.cd=maxf(0.0,float(e.cd)-dt)
	if e.stagger>0: return
	var phase := 2 if e.hp<=e.max_hp*0.45 else 1
	if phase!=int(e.phase):
		e.phase=phase
		Presentation.send(s,e,"phase")
	var target: Dictionary={}
	var best := 820.0
	for p in s.players.values():
		if p.status=="active" and p.p.distance_to(e.p)<best:
			target=p
			best=p.p.distance_to(e.p)
	if target.is_empty() or e.cd>0 or e.attack_time>0: return
	if not e.get("revealed",false):
		e.revealed=true
		Presentation.send(s,e,"entrance")
	var aim: Vector2=(target.p-e.p).normalized()
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	var move: String=(["shard","reflection","mirror_cross","glass_rain"] if e.mini_kind==0 else ["cinder","pyre","ash_cross","last_vesper"])[int(e.sequence)%4]
	e.sequence+=1
	cast(s,e,target,move,aim)

func cast(s, e: Dictionary, target: Dictionary, move: String, aim: Vector2) -> void:
	var first: int=s.raid.hazards.size()
	var damage: float=BASE_DAMAGE[e.mini_kind]*(1.12 if e.phase==2 else 1.0)
	e.attack_aim=aim
	e.move_id=move
	match move:
		"shard":
			e.move_name="折镜穿刺 · 横向闪避"
			s.expedition.hazard(s,"line",e.p,aim,540,0.85,damage)
			s.expedition.hazard(s,"line",e.p,aim.rotated(0.34),500,1.48,damage*0.9)
		"reflection":
			e.move_name="镜面倒影 · 先外后内"
			s.expedition.hazard(s,"ring",e.p,aim,350,1.15,damage,115)
			s.expedition.hazard(s,"circle",e.p,aim,125,1.85,damage)
		"mirror_cross":
			e.move_name="碎影十字 · 两拍交错"
			s.expedition.hazard(s,"line",target.p-aim*260,aim,520,0.7,damage*0.75)
			s.expedition.hazard(s,"line",target.p-aim.orthogonal()*260,aim.orthogonal(),520,1.55,damage)
		"glass_rain":
			e.move_name="千镜坠落 · 离开脚下光斑"
			for p in s.players.values():
				if p.status=="active":
					s.expedition.hazard(s,"circle",p.p,aim,95,1.0,damage)
					if e.phase==2: s.expedition.hazard(s,"circle",p.p+aim*130,aim,95,1.65,damage)
		"cinder":
			e.move_name="焚香裂焰 · 绕到背后"
			s.expedition.hazard(s,"cone",e.p,aim,275,0.9,damage)
			if e.phase==2: s.expedition.hazard(s,"cone",e.p,-aim,245,1.55,damage)
		"pyre":
			e.move_name="灰烬晚祷 · 躲入内环"
			s.expedition.hazard(s,"ring",e.p,aim,385,1.2,damage,130)
			s.expedition.hazard(s,"ring",e.p,aim,460,1.85,damage,385)
		"ash_cross":
			e.move_name="烬火审判 · 快刺接慢扫"
			s.expedition.hazard(s,"line",e.p,aim,530,0.62,damage*0.75)
			s.expedition.hazard(s,"cone",e.p,aim,310,1.56,damage*1.15)
		"last_vesper":
			e.move_name="终末弥撒 · 连续落焰"
			for p in s.players.values():
				if p.status=="active":
					for i in (3 if e.phase==2 else 2):
						s.expedition.hazard(s,"circle",p.p+Vector2.from_angle(TAU*i/3.0)*i*115,aim,92,0.72+i*0.55,damage)
	var marks: Array=[]
	for i in range(first,s.raid.hazards.size()):
		var h: Dictionary=s.raid.hazards[i]
		h.merge({"source":e.id,"boss_kind":int(e.boss_kind),"move":move,"part":i-first,
			"phase":int(e.phase),"mini_boss":true,"mini_kind":int(e.mini_kind)},true)
		h.tempo="快" if h.total<=0.7 else ("慢" if h.total>=1.4 else "")
		if not marks.has(h.total): marks.append(h.total)
	marks.sort()
	if marks.is_empty(): return
	e.attack_marks=marks
	e.windup=marks[0]
	e.attack_total=float(marks.back())+0.35
	e.attack_time=e.attack_total
	e.cd=maxf(e.attack_total+0.65,3.0 if e.phase==1 else 2.55)
	Presentation.send(s,e,"charge",{"total":marks[0]})

func defeated(s, e: Dictionary) -> void:
	s.expedition.record_map_boss_defeat(s,e)
	for i in range(s.raid.hazards.size()-1,-1,-1):
		if int(s.raid.hazards[i].get("source",-1))==int(e.id):
			s.raid.hazards.remove_at(i)
	var quality := 3 if int(e.mini_kind)==0 else 4
	var chest: Dictionary=s.loot_container(e.p,Vector2i(6,6),quality,true)
	chest.merge({"fixed_loot":true,"reward_tier":quality,
		"title":str(e.boss_name)+" · 守卫秘藏","open":true},true)
	s.place_entry(chest,["mirror_thread","ember_heart"][int(e.mini_kind)])
	s.place_entry(chest,["mirror_fate_ledger","vesper_last_page"][int(e.mini_kind)])
	s.place_entry(chest,Catalog.make_equipment("weapon",Catalog.roll_weapon(s.rng),quality))
	for item in ["medicine","ammo","relic","relic"]:
		s.place_entry(chest,item)
	chest.searched=s.container_units(chest)
	s.append_chest(chest)
