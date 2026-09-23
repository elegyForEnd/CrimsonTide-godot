extends RefCounted
const Tactics = preload("res://scripts/boss_tactics.gd")
const Presentation = preload("res://scripts/boss_presentation.gd")

const NAMES := ["赤月葬钟主教", "荆棘誓约猎王", "血潮女王 · 永夜月冠"]
const COLORS := [Color("ba9aee"), Color("ea879d"), Color("f4cb83")]
const HEALTH := [1500.0,2700.0,4800.0]
const REWARDS := [150,300,650]

func reset(s) -> void:
	s.raid={"day":1,"phase":"explore","time":0.0,"center":Ruins.CENTER,"kind":0,"hazards":[],"choices":{},"kills":0}
	prepare_day(s,1)

func prepare_day(s, day: int) -> void:
	s.raid.day=day
	s.raid.time=0.0
	s.raid.phase="explore"
	s.raid.kind=s.rng.randi_range(0,1) if day<3 else 2
	s.raid.center=arena(s)
	s.raid.hazards=[]
	s.raid.choices={}
	s.bullets.clear()
	s.pending_ultimates.clear()
	for p in s.players.values():
		s.stop_search(p)
		p.pending_strike=false
		p.swing_time=0.0
		p.cast_time=0.0
		p.dodge_time=0.0
		p.channel=0.0
		p.target=""
		if day>1 and p.status in ["active","down"]:
			p.hp=minf(p.max_hp,p.hp+p.max_hp*0.35)
			p.sanity=minf(100,p.sanity+30)
			p.reserve+=48
	if day==3:
		for p in s.players.values():
			if p.status=="active":
				p.p=arena_entry(s,p.id)
				p.invuln=3.0
		spawn_boss(s)

func arena(s) -> Vector2:
	# Landmark centres lie on the connected road network. Require open dodge space.
	var candidates: Array[Vector2]=[]
	for site in s.ruins.sites:
		var at: Vector2=site.p
		var clear: bool=not s.ruins.blocked(at,36)
		for i in 16:
			var edge := at+Vector2.from_angle(TAU*i/16.0)*185
			if s.ruins.blocked(edge,22) or not s.ruins.clear_line(at,edge): clear=false
		if clear: candidates.append(at)
	if candidates.is_empty(): return Ruins.SPAWN
	var previous: Vector2=s.raid.center
	var alternatives := candidates.filter(func(at: Vector2): return at.distance_to(previous)>700)
	if not alternatives.is_empty(): return alternatives[s.rng.randi_range(0,alternatives.size()-1)]
	return candidates[s.rng.randi_range(0,candidates.size()-1)]

func arena_entry(s, id: int) -> Vector2:
	for i in 32:
		var at: Vector2=s.raid.center+Vector2.from_angle(TAU*(i+id%8)/32.0)*165
		if not s.ruins.blocked(at,20): return at
	return s.raid.center

func tick(s, dt: float) -> void:
	if s.raid.is_empty(): return
	if s.raid.phase=="choice":
		resolve_choices(s)
		return
	if s.raid.phase=="complete": return
	s.raid.time+=dt
	if s.raid.phase=="explore":
		# Close the optional dungeon before fog starts, so it cannot bypass dawn.
		if s.raid.time>=s.SHRINK_START and s.map_id=="city":
			s.travel_city(true)
		if s.raid.time>=s.duration:
			spawn_boss(s)
	update_hazards(s,dt)

func spawn_boss(s) -> void:
	if s.raid.phase=="boss": return
	s.raid.phase="boss"
	s.raid.time=s.duration
	s.bullets.clear()
	# No extra spawn pass: the boss must appear at exactly the marked centre.
	var count := 0
	for p in s.players.values():
		if p.status in ["active","down"]: count+=1
	var health: float=HEALTH[int(s.raid.day)-1]*(1+0.55*maxi(0,count-1))
	var kind: int=s.raid.kind
	s.enemies.append({"id":s.next_enemy,"p":s.raid.center,"type":[1,3,4][kind],"raid_boss":true,"boss_kind":kind,"boss_name":NAMES[kind],"hp":health,"max_hp":health,"cd":2.2,"last":1,"wander":Vector2.ZERO,"facing":1.0,"motion_phase":0.0,"moving":false,"attack_time":0.0,"attack_total":0.0,"attack_released":false,"attack_aim":Vector2.RIGHT,"sequence":0,"phase":1,"flash":0.0})
	s.next_enemy+=1
	Presentation.send(s,s.enemies.back(),"entrance")

func victory(s) -> void:
	if s.raid.phase!="boss": return
	s.raid.kills+=1
	s.raid.hazards=[]
	s.bullets.clear()
	var day: int=s.raid.day
	for p in s.players.values():
		if p.status in ["active","down"]:
			p["boss_reward"]=int(p.get("boss_reward",0))+REWARDS[day-1]
			if p.status=="down":
				p.status="active"
				p.hp=p.max_hp*0.35
			p.invuln=5.0
	var chest: Dictionary=s.loot_container(s.raid.center,Vector2i(7,7),day+2,true)
	chest.merge({"fixed_loot":true,"reward_tier":day+2,"title":NAMES[int(s.raid.kind)]+" · 黎明遗赠","open":true})
	for item in ["medicine","medicine","ammo","ammo","relic","relic"]: s.place_entry(chest,item)
	s.place_entry(chest,Catalog.make_equipment("weapon",s.rng.randi_range(0,3),mini(5,day+2)))
	s.place_entry(chest,Catalog.make_equipment("gear",s.rng.randi_range(0,2),day+2))
	for i in day-1: s.place_entry(chest,"relic")
	s.place_entry(chest,{"kind":"backpack","key":["blue","gold","red"][day-1]})
	chest.searched=s.container_units(chest)
	s.append_chest(chest)
	if day==1:
		prepare_day(s,2)
	else:
		s.raid.phase="choice" if day==2 else "complete"
		# Intermission is safe and leaves time to collect the boss chest.
		s.enemies.clear()
		s.raid.choices={}

func choose(s, id: int, choice: String) -> void:
	if not s.authority() or s.raid.phase not in ["choice","complete"]: return
	var p: Dictionary=s.players.get(id,{})
	if p.is_empty() or p.status!="active": return
	if choice=="extract":
		p.status="extracted"
		s.cancel_ultimate(id)
	elif choice=="continue" and s.raid.phase=="choice":
		s.raid.choices[id]=true
	elif choice=="wait":
		s.raid.choices.erase(id)

func resolve_choices(s) -> void:
	var remaining := 0
	for p in s.players.values():
		if p.status=="down": return
		if p.status=="active":
			remaining+=1
			if not s.raid.choices.get(p.id,false): return
	if remaining>0: prepare_day(s,3)

func hazard(s, shape: String, at: Vector2, aim: Vector2, radius: float, delay: float, damage: float, inner: float = 0.0) -> void:
	s.raid.hazards.append({"shape":shape,"p":at,"aim":aim,"radius":radius,"inner":inner,"time":delay,"total":delay,"damage":damage,"fired":false,"linger":0.24})

func update_hazards(s, dt: float) -> void:
	for i in range(s.raid.hazards.size()-1,-1,-1):
		var h: Dictionary=s.raid.hazards[i]
		h.time-=dt
		if h.time<=0 and not h.fired:
			h.fired=true
			if h.has("boss_kind"):
				var event: Dictionary=h.duplicate(true)
				event.merge({"kind":"boss-vfx","action":"release","id":h.get("source",0)},true)
				s.broadcast_combat(event)
			else: s.emit_effect("hit",h.p)
			for p in s.players.values():
				if hazard_contains(h,p.p) and s.ruins.clear_line(h.p,p.p): s.hurt(p,h.damage)
		if h.time < -float(h.linger): s.raid.hazards.remove_at(i)

func hazard_contains(h: Dictionary, at: Vector2) -> bool:
	var v: Vector2=at-h.p
	if h.shape=="line":
		return v.dot(h.aim)>=-22 and v.dot(h.aim)<=h.radius and absf(v.dot(h.aim.orthogonal()))<=44
	if h.shape=="cone": return v.length()<=h.radius and absf(h.aim.angle_to(v))<=1.05
	return v.length()<=h.radius and v.length()>=h.inner

func update_boss(s, e: Dictionary, dt: float) -> void:
	e.flash=maxf(0,float(e.flash)-dt)
	e.attack_time=maxf(0,float(e.attack_time)-dt)
	e.moving=false
	e["stagger"]=maxf(0,float(e.get("stagger",0))-dt)
	e.cd=maxf(0,e.cd-dt)
	Tactics.tick(s,e,dt)
	if e.stagger>0 or Tactics.update_guard(e,dt): return
	var phase := 1
	if e.hp<=e.max_hp*0.60: phase=2
	if e.boss_kind==2 and e.hp<=e.max_hp*0.30: phase=3
	if phase!=int(e.get("phase",1)):
		e.phase=phase
		Presentation.send(s,e,"phase")
	e.phase=phase
	var target: Dictionary={}
	var best := INF
	for p in s.players.values():
		if p.status=="active" and p.p.distance_to(e.p)<best:
			target=p
			best=p.p.distance_to(e.p)
	if target.is_empty(): return
	var response: Dictionary=Tactics.response(s,e)
	if not response.is_empty():
		if response.kind=="attack" and Tactics.start_guard(e,response.aim,s): return
		if response.kind!="attack":
			cast_boss(s,e,target,str(response.kind),response.aim,response.point)
			return
	if e.attack_time<=0 and not e.get("reaction",{}).is_empty(): return
	var aim: Vector2=(target.p-e.p).normalized()
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	# Reposition between casts; all telegraphs keep their original origin and aim.
	if e.attack_time<=0 and (int(e.sequence)>0 or best>230):
		var preferred: float=[190.0,130.0,165.0][int(e.boss_kind)]
		var side := 1.0 if (int(e.sequence)+int(e.id))%2==0 else -1.0
		var direction := aim.orthogonal()*side
		if best>preferred+30: direction=(aim+direction*0.25).normalized()
		elif best<preferred-45: direction=(-aim+direction*0.6).normalized()
		move_boss(s,e,direction,180.0+18.0*phase,dt)
		aim=(target.p-e.p).normalized()
		best=target.p.distance_to(e.p)
	if e.cd>0 or e.attack_time>0 or not s.ruins.clear_line(e.p,target.p): return
	var seq: int=e.sequence
	var moves: Array=["bell","marks","quick_bell","slow_bell","cross"] if e.boss_kind==0 else (["spear","cleave","feint","guard","fan","reap"] if e.boss_kind==1 else ["crown","lances","coronation","execution","eclipse"])
	var move: String=moves[seq%moves.size()]
	if e.boss_kind==0 and move in ["bell","quick_bell"] and best>340: move="marks"
	if e.boss_kind==1 and move in ["cleave","feint","reap"] and best>260: move="spear"
	e.sequence+=1
	if move=="guard":
		if Tactics.start_guard(e,aim,s): return
		move="feint"
	cast_boss(s,e,target,move,aim,target.p)

func cast_boss(s, e: Dictionary, _target: Dictionary, move: String, aim: Vector2, point: Vector2) -> void:
	var phase := int(e.get("phase",1))
	e.attack_aim=aim
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	var damage: float=(23+int(s.raid.day)*6)*(1.0+0.12*(phase-1))
	var delay: float=[1.05,0.85,0.75][phase-1]
	var first: int=s.raid.hazards.size()
	e["move_id"]=move
	match move:
		"dodge":
			e.move_name="截断退路 · 翻滚落点已锁定"
			if e.boss_kind==1: hazard(s,"line",e.p,aim,520,0.90,damage)
			else: hazard(s,"circle",point,aim,90,0.90,damage)
		"reload":
			e.move_name="破绽追击 · 装填时注意闪避"
			if e.boss_kind==0: hazard(s,"circle",point,aim,80,0.65,damage*0.85)
			else: hazard(s,"line",e.p,aim,560,0.65,damage*0.85)
		"counter":
			e.move_name="招架反击 · 快刺接慢扫"
			hazard(s,"line",e.p,aim,390,0.55,damage*0.75)
			hazard(s,"cone",e.p,aim,245,1.45,damage*1.10)
		"bell":
			e["move_name"]="葬钟回响 · 离开紫环"
			hazard(s,"ring",e.p,aim,295,delay,damage,95)
			if s.raid.day==2: hazard(s,"ring",e.p,aim,440,delay+0.85,damage,295)
		"marks":
			e["move_name"]="月蚀祷告 · 离开脚下印记"
			for p in s.players.values():
				if p.status=="active": hazard(s,"circle",p.p,aim,85,delay,damage)
			if phase>=2: hazard(s,"circle",e.p,aim,110,delay+0.6,damage)
		"quick_bell":
			e.move_name="急鸣丧钟 · 快震后退"
			hazard(s,"circle",e.p,aim,180,0.55,damage*0.75)
			hazard(s,"ring",e.p,aim,340,1.35,damage,180)
		"slow_bell":
			e.move_name="停钟再鸣 · 慢拍，先内后外"
			hazard(s,"ring",e.p,aim,380,1.55,damage*1.15,115)
			hazard(s,"circle",e.p,aim,130,2.20,damage)
		"cross":
			e.move_name="十字葬仪 · 穿过交错钟线"
			hazard(s,"line",point-aim*260,aim,520,0.65,damage*0.8)
			hazard(s,"line",point-aim.orthogonal()*260,aim.orthogonal(),520,1.55,damage)
		"spear":
			e["move_name"]="猎王血矛 · 横向闪避"
			hazard(s,"line",e.p,aim,520,delay,damage+5)
			if s.raid.day==2:
				for angle in [-0.32,0.32]: hazard(s,"line",e.p,aim.rotated(angle),520,delay+0.55,damage)
		"cleave":
			e["move_name"]="荆棘断誓 · 绕到背后"
			hazard(s,"cone",e.p,aim,240,delay,damage)
			if phase>=2: hazard(s,"cone",e.p,-aim,240,delay+0.75,damage)
		"feint":
			e.move_name="猎誓虚晃 · 快刺接蓄力斩"
			hazard(s,"line",e.p,aim,330,0.55,damage*0.65)
			hazard(s,"cone",e.p,aim,255,1.65,damage*1.20)
		"fan":
			e.move_name="三棘追猎 · 快矛接侧翼慢矛"
			hazard(s,"line",e.p,aim,520,0.60,damage*0.8)
			for angle in [-0.45,0.45]: hazard(s,"line",e.p,aim.rotated(angle),520,1.50,damage)
		"reap":
			e.move_name="回身收割 · 前快后慢"
			hazard(s,"cone",e.p,aim,220,0.60,damage*0.8)
			hazard(s,"cone",e.p,-aim,260,1.60,damage*1.1)
		"crown":
			e["move_name"]="月冠审判 · 先入内环再远离"
			hazard(s,"ring",e.p,aim,450,delay,damage,130)
			hazard(s,"circle",e.p,aim,155,delay+0.8,damage+6)
		"lances":
			e["move_name"]="血潮王令 · 穿过王矛间隙"
			for i in 6+phase*2:
				hazard(s,"line",e.p,Vector2.from_angle(aim.angle()+TAU*i/(6+phase*2)),560,delay,damage)
		"coronation":
			e["move_name"]="永夜加冕 · 持续移动"
			for p in s.players.values():
				if p.status!="active": continue
				for i in phase:
					var at: Vector2=p.p+Vector2.from_angle(TAU*i/3)*float(i)*95
					hazard(s,"circle",at,aim,95,delay+i*0.55,damage)
		"execution":
			e.move_name="女王处刑 · 两快一慢"
			hazard(s,"cone",e.p,aim,220,0.55,damage*0.65)
			hazard(s,"cone",e.p,-aim,220,1.00,damage*0.65)
			hazard(s,"ring",e.p,aim,380,1.95,damage*1.15,110)
		"eclipse":
			e.move_name="蚀月错拍 · 慢环接快爆"
			hazard(s,"ring",e.p,aim,450,1.50,damage,145)
			hazard(s,"circle",point,aim,95,1.95,damage)
	if e.boss_kind==2 and phase==3: hazard(s,"ring",s.raid.center,aim,620,delay+1.1,damage,460)
	var marks: Array=[]
	for i in range(first,s.raid.hazards.size()):
		var h: Dictionary=s.raid.hazards[i]
		h["source"]=e.id
		h["boss_kind"]=int(e.boss_kind)
		h["move"]=move
		h["part"]=i-first
		h["phase"]=phase
		h["perimeter"]=int(e.boss_kind)==2 and phase==3 and i==s.raid.hazards.size()-1
		h["tempo"]="快" if h.total<=0.70 else ("慢" if h.total>=1.4 else "")
		if not marks.has(h.total): marks.append(h.total)
	marks.sort()
	if marks.is_empty(): return
	e["attack_marks"]=marks
	e["windup"]=marks[0]
	e.attack_total=float(marks.back())+0.35
	e.attack_time=e.attack_total
	e.cd=maxf(e.attack_total+0.45,2.8 if phase==1 else 2.35)
	Presentation.send(s,e,"charge",{"total":marks[0]})

func move_boss(s, e: Dictionary, direction: Vector2, speed: float, dt: float) -> void:
	var before: Vector2=e.p
	var remaining := dt
	while remaining>0:
		var step := minf(remaining,0.025)
		var next: Vector2=s.ruins.move(e.p,direction*speed*step,31)
		# Leave a dodge corridor at the edge of the fixed arena.
		if next.distance_to(s.raid.center)>390 or next.distance_to(e.p)<speed*step*0.2:
			for side in [1.0,-1.0]:
				var alternate: Vector2=s.ruins.move(e.p,direction.orthogonal()*side*speed*step,31)
				if alternate.distance_to(s.raid.center)<=390 and alternate.distance_to(e.p)>=speed*step*0.2:
					next=alternate
					break
		if next.distance_to(s.raid.center)<=390: e.p=next
		remaining-=step
	var travelled: float=e.p.distance_to(before)
	e.moving=travelled>0.01
	e.motion_phase+=travelled/12.0
