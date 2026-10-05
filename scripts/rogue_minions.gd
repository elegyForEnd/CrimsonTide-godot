extends RefCounted
## Individual species loadouts. Damage stays in RogueCombat's authoritative zones.
const NAMES := [
	["苔冠木灵","菌灵拳手","根面巫师","幽角灵","月露花灵","灯笼蕈客","苔石幼像","森影面灵"],
	["炉渣骑兵","煤焰小鬼","铸铁魔卫","火核灵","熔链狱卒","炉心祭师","焰晶幼魔","铸魂匠"],
	["星晶守卫","晶刃侍从","星眼法师","棱镜幼龙","镜面舞者","星砂瓶灵","共鸣晶簇","星缝织者"],
	["风咒祭司","云羽剑士","雷面萨满","风灵幼狮","云帆投手","风铃医灵","雷鼓魔童","空港翼卫"],
	["魔宫禁卫","影刃魔童","魔典侍僧","黑曜幼兽","血月侍医","禁印执事","魂灯提刑者","王庭傀儡"]]
const ROLES := [
	["front","melee","control","ranged","heal","throw","front","ambush"],
	["front","throw","front","ranged","control","buff","melee","summon"],
	["front","melee","ranged","ranged","ambush","throw","buff","summon"],
	["control","melee","ranged","melee","throw","heal","buff","ambush"],
	["front","ambush","summon","melee","heal","buff","throw","front"]]
const LOADOUTS := [
	[["枝臂横扫","sweep"],["盘根护体","guard"]],[["弹跳重拳","jump"],["左右摆拳","combo"]],[["缠根刺","roots"],["藤蔓牵引","pull"]],[["幽角飞叶","fan"],["灵角冲刺","dash"]],[["月露回春","heal"],["花瓣退散","burst"]],[["孢灯投掷","throw"],["幽光残雾","mist"]],[["苔石壁垒","shield"],["滚石肩撞","dash"]],[["影叶闪袭","blink"],["诱影分身","decoy"]],
	[["炉渣突刺","dash"],["熔盾反击","counter"]],[["煤球抛射","throw"],["连锁煤雷","mines"]],[["铸锤震地","wave"],["铁臂横拦","sweep"]],[["火核连弹","shots"],["余烬喷流","breath"]],[["锁链捕获","pull"],["灼链横扫","sweep"]],[["炽热鼓舞","haste"],["熔炉印记","trap"]],[["焰晶跃爆","jump"],["焦土裂缝","fissure"]],[["铸魂小像","summon"],["修补锻打","repair"]],
	[["晶盾猛推","bash"],["折射护罩","ward"]],[["棱刃交斩","combo"],["碎晶滑步","sidestep"]],[["星眼射线","beam"],["坠星点名","meteors"]],[["棱彩吐息","breath"],["折返晶球","boomerang"]],[["镜步反斩","counter"],["碎镜散花","burst"]],[["星砂瓶","mist"],["悬晶地雷","mines"]],[["共鸣连线","armor"],["晶脉脉冲","ring"]],[["星缝召影","summon"],["错位星门","rifts"]],
	[["横风刃","parallel"],["风旋牵引","vortex"]],[["燕返二连","return_dash"],["升风挑斩","sweep"]],[["链雷刻印","marks"],["雷针三射","shots"]],[["云鬃扑咬","jump"],["风鬃咆哮","roar"]],[["回旋风盘","boomerang"],["雷罐抛投","throw"]],[["回响疗铃","heal"],["清风庇护","shield"]],[["战鼓疾奏","speed"],["震鼓雷环","ring"]],[["俯冲掠袭","dash"],["羽刃封路","feathers"]],
	[["黑戟横扫","sweep"],["王庭架势","counter"]],[["影步背刺","blink"],["双影交刃","shadow_combo"]],[["禁书召灵","summon"],["墨咒飞页","double_fan"]],[["黑曜撕咬","jump"],["碎甲震吼","roar"]],[["血月缝合","sacrifice_heal"],["赤月退击","retreat_shot"]],[["恶契赐印","power"],["禁印陷阱","rifts"]],[["魂灯投掷","throw"],["缓行魂火","homing"]],[["重刃三段","triple"],["断线暴走","berserk"]]
]

func skill(e: Dictionary, index: int) -> Dictionary:
	var pair: Array=LOADOUTS[int(e.rogue_skin)*8+int(e.rogue_variant)][index]
	var kind: String=pair[1]
	var range_value := 300.0
	if kind in ["sweep","combo","bash","triple","counter","guard","ward","roar","burst"]: range_value=85.0
	if kind in ["dash","return_dash","jump","blink","berserk","sidestep"]: range_value=210.0
	var windup := 0.55
	var cooldown := 2.1+float(e.rogue_variant%4)*.15
	if kind in ["heal","sacrifice_heal","repair"]: windup=1.3; cooldown=7.0
	if kind in ["shield","haste","armor","speed","power","summon"]: windup=.8; cooldown=8.0
	if kind in ["beam","triple","berserk","fissure"]: windup=.85; cooldown=3.8
	return {"name":pair[0],"kind":kind,"range":range_value,"windup":windup,"cooldown":cooldown}

func ally(s, e: Dictionary, injured: bool = false, summoned: bool = false) -> Dictionary:
	var best: Dictionary={}
	var value := INF
	for other in s.enemies:
		if other.id==e.id or other.hp<=0 or other.get("rogue_guardian",false) or other.get("rogue_decoy",false): continue
		if summoned and int(other.get("summon_owner",-1))!=int(e.id): continue
		if e.p.distance_to(other.p)>360: continue
		var ratio: float=other.hp/other.max_hp
		if injured and (ratio>=.88 or float(other.get("heal_lock",0))>0): continue
		var priority: float=ratio if injured else e.p.distance_to(other.p)
		if priority<value: value=priority; best=other
	return best

func available(s, e: Dictionary, index: int, distance: float) -> bool:
	if float(e.skill_cds[index])>0: return false
	var move: Dictionary=skill(e,index)
	var kind: String=move.kind
	if kind in ["heal","sacrifice_heal","repair"]: return not ally(s,e,true,kind=="repair").is_empty()
	if kind in ["shield","haste","armor","speed","power"]: return not ally(s,e).is_empty()
	if kind=="summon":
		var own := 0
		var total := 0
		for other in s.enemies:
			if other.hp>0 and other.get("rogue_summoned",false):
				total+=1
				if int(other.get("summon_owner",-1))==int(e.id): own+=1
		return own<2 and total<4
	if kind=="berserk" and (e.hp>e.max_hp*.5 or e.get("berserk_used",false)): return false
	return distance<move.range

func update(s, c, e: Dictionary, dt: float) -> void:
	if e.get("rogue_decoy",false):
		e.decoy_life-=dt
		if e.decoy_life<=0: e.hp=0.0
		return
	e.minion_age+=dt
	e.stagger=maxf(0,e.stagger-dt)
	e.cd=maxf(0,e.cd-dt)
	for i in 2: e.skill_cds[i]=maxf(0,float(e.skill_cds[i])-dt)
	for status in ["shield_time","guard_time","buff_time","heal_lock"]: e[status]=maxf(0,float(e.get(status,0))-dt)
	if e.shield_time<=0: e.rogue_shield=0.0
	if e.buff_time<=0: e.buff_kind=""
	if int(e.get("buff_source",-1))>=0:
		var source_alive := false
		for other in s.enemies:
			if other.id==e.buff_source and other.hp>0: source_alive=true; break
		if not source_alive: e.buff_time=0.0; e.buff_kind=""
	if e.stagger>0:
		if e.attack_time>0: c.minion_event(s,e,"interrupt")
		e.attack_time=0.0
		return
	var target: Dictionary=c.nearest(s,e)
	if target.is_empty(): return
	var direction: Vector2=(target.p-e.p).normalized()
	var facing_direction: Vector2=e.attack_aim if e.attack_time>0 else direction
	if absf(facing_direction.x)>.05: e.facing=signf(facing_direction.x)
	if e.attack_time>0:
		e.attack_time=maxf(0,e.attack_time-dt)
		if not e.attack_released and e.attack_total-e.attack_time>=e.minion_windup:
			e.attack_released=true
			release(s,c,e)
			c.minion_event(s,e,"release")
			s.broadcast_audio("rogue-minion-%d-%d-%d" % [e.rogue_skin,e.rogue_variant,e.minion_skill],e)
		return
	var distance: float=e.p.distance_to(target.p)
	var choices: Array=[]
	for i in 2:
		if available(s,e,i,distance) and s.ruins.clear_line(e.p,target.p): choices.append(i)
	var ready := not choices.is_empty()
	if ready and not e.in_attack_range: e.cd=maxf(e.cd,s.rng.randf_range(.18,.72))
	e.in_attack_range=ready
	if ready and e.cd<=0 and c.minion_start_gap<=0:
		var chosen: int=choices[s.rng.randi_range(0,choices.size()-1)]
		# Select contextual support before its attack alternative when useful.
		if available(s,e,0,distance) and e.role in ["heal","buff","summon"]: chosen=0
		var move: Dictionary=skill(e,chosen)
		e.minion_skill=chosen
		e.minion_windup=move.windup
		e.attack_total=move.windup+(.9 if move.kind in ["triple","return_dash","breath"] else .55)
		e.attack_time=e.attack_total
		e.attack_aim=direction
		e.attack_point=target.p
		e.attack_released=false
		e.support_target=-1
		if move.kind in ["heal","sacrifice_heal","repair","shield","haste","armor","speed","power"]:
			var recipient: Dictionary=ally(s,e,move.kind in ["heal","sacrifice_heal","repair"],move.kind=="repair")
			if not recipient.is_empty(): e.support_target=recipient.id; e.attack_point=recipient.p
		e.skill_cds[chosen]=move.cooldown*e.attack_tempo+s.rng.randf_range(-.15,.3)
		e.cd=(1.6 if e.buff_kind=="haste" else 2.0)*e.attack_tempo+s.rng.randf_range(-.15,.3)
		c.minion_start_gap=s.rng.randf_range(.12,.22)
		c.minion_event(s,e,"charge")
		return
	var separation := Vector2.ZERO
	for other in s.enemies:
		var offset: Vector2=e.p-other.p
		if other.id!=e.id and offset.length_squared()>0.01 and offset.length_squared()<65*65:
			separation+=offset.normalized()*(1.0-offset.length()/65)*1.8
	var desired := direction
	if e.role in ["ranged","throw","control","heal","buff","summon"]:
		if distance<170: desired=-direction
		elif distance<260: desired=Vector2.ZERO
	else:
		# Distinct approach angles reduce packs converging on one exact coordinate.
		var slot: Vector2=target.p+Vector2.from_angle(float(e.id)*2.39996)*55.0
		desired=(slot-e.p).normalized() if e.p.distance_to(slot)>14 else Vector2.ZERO
	if (desired+separation).length()>.05:
		c.move_towards(s,e,(desired+separation).normalized(),(86.0+(int(e.rogue_variant)%4)*9)*(1.2 if e.buff_kind=="speed" else 1.0)*dt)

func support(s, e: Dictionary, kind: String) -> void:
	var count := 0
	for other in s.enemies:
		if other.hp<=0 or other.get("rogue_guardian",false): continue
		if kind in ["heal","sacrifice_heal","repair","shield"] and other.id!=e.support_target: continue
		if other.id==e.id or e.p.distance_to(other.p)>360: continue
		if kind in ["heal","sacrifice_heal","repair"]:
			if float(other.get("heal_lock",0))>0: continue
			other.hp=minf(other.max_hp,other.hp+other.max_hp*.12)
			other.heal_lock=5.0
			if kind=="sacrifice_heal": e.hp=maxf(1,e.hp-e.max_hp*.06)
		elif kind=="shield": other.rogue_shield=other.max_hp*.15; other.shield_time=4.0
		else: other.buff_kind=kind; other.buff_time=4.0; other.buff_source=e.id
		s.broadcast_combat({"kind":"rogue-support","p":e.p,"target":other.p,"floor":e.rogue_skin,"style":kind,"id":e.id,"target_id":other.id})
		count+=1
		if count>=(1 if kind in ["heal","sacrifice_heal","repair","shield","power"] else 2): break

func release(s, c, e: Dictionary) -> void:
	var move: Dictionary=skill(e,int(e.minion_skill))
	var kind: String=move.kind
	var aim: Vector2=e.attack_aim
	var damage: float=(9.0+int(e.rogue_skin)*2)*(1.2 if e.buff_kind=="power" else 1.0)*float(e.get("build_damage_scale",1))
	var point: Vector2=e.attack_point
	if kind in ["heal","sacrifice_heal","repair","shield","haste","armor","speed","power"]:
		support(s,e,kind); return
	match kind:
		"guard","counter","ward":
			e.guard_time=1.2
			e.guard_kind=kind
			e.guard_aim=aim
			c.zone(e,"aura",e.p,46,0,1.2,0)
		"sweep","bash":
			c.zone(e,"cone",e.p,80 if kind=="sweep" else 60,0,.15,damage,aim)
			if kind=="bash": c.effects.back()["push"]=35.0
		"combo","triple","shadow_combo":
			for i in (3 if kind=="triple" else 2):
				c.zone(e,"cone",e.p,78+i*8,i*.3,.13,damage*.75,aim.rotated((i%2*2-1)*.23))
		"dash","return_dash","berserk","sidestep":
			if kind=="berserk": e.berserk_used=true; e.vulnerable=true
			if kind=="sidestep": c.move_towards(s,e,aim.orthogonal(),45)
			var start: Vector2=e.p
			c.move_towards(s,e,aim,140 if kind in ["berserk","dash"] else 90)
			c.zone(e,"line",start,22,0,.15,damage,aim,0,e.p+aim*28)
			if kind=="return_dash": c.zone(e,"line",e.p,18,.45,.15,damage*.8,-aim,0,start)
		"jump","blink":
			var landing: Vector2=point+aim*35 if kind=="blink" else point-aim*25
			c.move_towards(s,e,(landing-e.p).normalized(),minf(210,e.p.distance_to(landing)))
			c.zone(e,"circle" if kind=="jump" else "cone",e.p,48 if kind=="jump" else 65,.22,.15,damage,aim)
		"fan","double_fan","burst":
			var count := 6 if kind=="burst" else 3
			for i in count:
				var direction: Vector2=Vector2.from_angle(i*TAU/count) if kind=="burst" else aim.rotated((i-1)*.23)
				c.bolt(s,e,direction,210,damage*.7)
			if kind=="double_fan":
				for i in 3: c.missile(e,"shot",e.p,e.p+aim.rotated((i-1)*.32)*470,.3,2.0,damage*.65)
		"shots","parallel","retreat_shot":
			if kind=="retreat_shot": c.move_towards(s,e,-aim,55)
			for i in (2 if kind=="parallel" else 3):
				var origin: Vector2=e.p+aim.orthogonal()*(i*48-24) if kind=="parallel" else e.p
				c.missile(e,"shot",origin,origin+aim*620,i*.18,1.7,damage*.7)
		"boomerang","homing": c.missile(e,kind,e.p,e.p+aim*340,0,2.0,damage)
		"throw","mist": c.missile(e,kind,e.p,point,0,.85,damage)
		"mines","trap","rifts","marks","meteors","feathers":
			for i in (3 if kind=="feathers" else 2):
				var at: Vector2=s.ruins.safe_point(point+aim.orthogonal()*(i*80-40))
				c.zone(e,"circle",at,36 if kind=="mines" else 44,.65+i*.32,.2,damage)
		"roots","fissure","beam","wave":
			if kind=="beam": c.zone(e,"line",e.p,14,.2,.15,damage,aim,0,s.ruins.move(e.p,aim*430,10))
			else:
				for i in 4: c.zone(e,"circle",s.ruins.move(e.p,aim*(55+i*55),10),28,.1+i*.12,.18,damage*.8)
		"pull":
			c.zone(e,"line",e.p,16,.15,.12,damage*.65,aim,0,s.ruins.move(e.p,aim*290,10))
			c.effects.back()["pull"]=45.0
		"breath": c.zone(e,"cone",e.p,155,.1,.75,damage*.7,aim)
		"vortex":
			c.zone(e,"circle",point,72,.5,1.2,damage*.4)
			c.effects.back()["pull"]=28.0
		"ring":
			c.zone(e,"ring",e.p,40,.35,.75,damage,aim,15)
			c.effects.back()["ring_expand"]=true
		"roar":
			c.zone(e,"circle",e.p,78,.1,.18,damage*.8)
			c.effects.back()["push"]=30.0
			if int(e.rogue_skin)==4: e.vulnerable=true
		"summon":
			var variant: int=[0,2,1,1,1][int(e.rogue_skin)]
			c.summons.append({"p":s.ruins.safe_point(e.p+aim.orthogonal()*85),"floor":e.rogue_skin,"variant":variant,"owner":e.id})
		"decoy": c.summons.append({"p":s.ruins.safe_point(e.p+aim.orthogonal()*65),"floor":e.rogue_skin,"variant":e.rogue_variant,"owner":e.id,"decoy":true})

func absorb(s, c, e: Dictionary, damage: float, direction: Vector2) -> float:
	if e.get("vulnerable",false): damage*=1.15
	if float(e.get("buff_time",0))>0 and e.get("buff_kind","")=="armor": damage*=.8
	if float(e.get("guard_time",0))>0 and direction.dot(e.get("guard_aim",Vector2.RIGHT))<-.25:
		var kind: String=e.get("guard_kind","")
		damage*=.35
		if kind=="counter":
			c.zone(e,"cone",e.p,90,.25,.15,12+int(e.rogue_skin)*2,e.guard_aim)
			c.minion_event(s,e,"counter")
		if kind in ["counter","ward"]: e.guard_time=0.0
	var shield: float=float(e.get("rogue_shield",0))
	if shield>0:
		var extra: float=clampf(float(e.get("build_shield_bonus",0)),0,.6)
		var absorbed := minf(shield,damage*(1+extra))
		e.rogue_shield=shield-absorbed
		damage-=absorbed/(1+extra)
		if e.rogue_shield<=0: s.broadcast_combat({"kind":"rogue-support","style":"shield-break","p":e.p,"target":e.p,"id":e.id,"floor":e.rogue_skin})
	return damage
