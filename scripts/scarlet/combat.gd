extends RefCounted
## Fixed-step action encounter rules, authored phases and stable phase checkpoints.
var owner_ref: WeakRef
var campaign:
	get: return owner_ref.get_ref() if owner_ref else null
	set(value): owner_ref=weakref(value)
var enemies: Array=[]
var hazards: Array=[]
var effects: Array=[]
var running := false
var context: Dictionary={}
var phase := 0
var switches: Dictionary={}
var tick_time := 0.0
var companion_cd := 0.0
var speech_cd := 0.0
var opening_grace := 2.8
var phase_pending := false
var serial := 0

func clear() -> void:
	enemies.clear(); hazards.clear(); effects.clear(); running=false; context={}; switches={}; phase=0; phase_pending=false
	if campaign!=null: campaign.equipment_combat.reset()

func start(qid: String,node_id: String,boss_id: String,count: int,escort: bool = false) -> void:
	clear(); context={"qid":qid,"node":node_id,"boss":boss_id,"count":count,"escort":escort,"zone":campaign.state.zone}
	running=true; phase=0; opening_grace=2.8; tick_time=0; companion_cd=1.0; speech_cd=1
	campaign.state.checkpoint={"kind":"combat","context":context.duplicate(true),"phase":0}
	spawn_phase(); campaign.changed.emit(); campaign.save_campaign()

func spawn_phase() -> void:
	enemies.clear(); hazards.clear(); switches.clear(); phase_pending=false
	campaign.equipment_combat.reset()
	campaign.navigation_zone=""
	var boss_id: String=context.get("boss","")
	if boss_id!="":
		var info: Dictionary=campaign.content.bosses[boss_id]
		var hp: float=float(info.hp)*(1.0+phase*.12)
		enemies.append({"id":"boss:"+boss_id,"p":campaign.place(Vector2(900,550)),"hp":hp,"maxhp":hp,"boss":true,"key":boss_id,"name":info.name,"cd":2.5,"windup":0.0,"flash":0.0,"attack":0,"stagger":0.0})
		campaign.battle_speech.emit(info.name,info.lines[mini(phase,info.lines.size()-1)])
	else:
		for i in int(context.get("count",3)):
			var p:=Vector2(760+(i%3)*155,520+(i/3)*170)
			var hp:=80.0+int(campaign.state.act)*16
			enemies.append({"id":"guard:%d" % i,"p":campaign.place(p),"hp":hp,"maxhp":hp,"boss":false,"key":"guard","name":"王庭弩手" if i%2 else "近卫","cd":1.6+i*.4,"windup":0.0,"flash":0.0,"attack":0,"stagger":0.0})
	if boss_id=="queen":
		campaign.state.party=[0] if phase==0 else [0,1] if phase==1 else [0,1,2]
		if phase==0: campaign.state.hero=0
		if phase==2: switches={"stable":false,"clasp":false}
	opening_grace=2.8
	campaign.hero_at=campaign.safe_place(campaign.place(Vector2(900,550))+Vector2(0,440*campaign.terrain().speed_scale()))
	for i in 3: campaign.allies[i]=campaign.place(campaign.hero_at+Vector2((i-1)*65,75))

func snapshot() -> Dictionary:
	if not running: return {}
	# Resume from phase start, never from a windup or an unsafe HP threshold.
	return {"context":context.duplicate(true),"phase":phase,"phase_pending":phase_pending,"switches":switches.duplicate(true)}

func restore(data: Dictionary) -> void:
	clear()
	if not data.get("context") is Dictionary: return
	context=data.context.duplicate(true); phase=clampi(int(data.get("phase",0)),0,2)
	if context.get("zone","")!=campaign.state.zone: return
	running=true; spawn_phase()
	# Never resume halfway through a mechanism; checkpoints retain the phase only.

func retry() -> void:
	campaign.hurt_time=0
	campaign.pending_strike.clear(); campaign.action_time=0; campaign.attack_cd=0; campaign.dodge_time=0
	campaign.state.hp=campaign.max_hp(); campaign.invulnerable=3.0
	for person in campaign.escort_group: person.hp=80.0
	if running: spawn_phase()
	elif not campaign.escort_group.is_empty():
		for person in campaign.escort_group: person.hp=80.0; person.p=campaign.place(Vector2(850,900))
		campaign.hero_at=campaign.place(Vector2(900,1000))
	else: campaign.hero_at=campaign.spawn_at()
	campaign.save_campaign()

func resume_phase(next_phase: int) -> void:
	phase=next_phase; phase_pending=false
	campaign.state.hp=campaign.max_hp()
	campaign.state.checkpoint={"kind":"combat","context":context.duplicate(true),"phase":phase}
	spawn_phase(); campaign.save_campaign()

func gadget(id: String,label: String,p: Vector2,hero: int = -1) -> Dictionary:
	return {"id":id,"kind":"gadget","label":label,"p":campaign.safe_place(p),"hero":hero}

func barriers() -> Array:
	if not running or context.get("boss","")!="judge" or phase!=0: return []
	var result: Array=[]
	if not switches.get("verdict:0",false): result.append([580,280,40,900])
	if not switches.get("verdict:1",false): result.append([620,800,560,35])
	if not switches.get("verdict:2",false): result.append([1180,280,40,900])
	return result

func gadgets() -> Array:
	if not running or phase_pending: return []
	if context.get("stealth",false): return [gadget("quiet-door","悄悄卸下北侧门栓",Vector2(900,280))]
	if context.get("boss","")=="": return []
	var result: Array=[]
	var key: String=context.boss
	match key:
		"inquisitor":
			for i in 2:
				var id: String="turret:%d" % i
				if not switches.get(id,false): result.append(gadget(id,"拆除弩台 · 降低交叉火力",Vector2(300+i*1200,650)))
		"judge":
			for i in 3:
				var id: String="verdict:%d" % i
				if not switches.get(id,false): result.append(gadget(id,"解除宣判隔断 · 暴露本体",Vector2(300+i*600,850 if i%2 else 600)))
		"vein":
			if phase==1 and not switches.get("shield",false): result.append(gadget("shield","引盾撞上断柱 · 打开旧剑路",Vector2(900,1130)))
		"surgeon":
			for i in 2:
				var id: String="vent:%d" % i
				if not switches.get(id,false): result.append(gadget(id,"关闭示范厅局部麻醉阀 · 保留病房保障" if phase==0 else "切断手术偶承重索",Vector2(310+i*1180,1000)))
		"admiral":
			if phase==1 and not switches.get("helm",false): result.append(gadget("helm","锁住舰舵 · 阻止断链离港",Vector2(900,280)))
		"queen":
			if phase==1:
				for i in 3:
					var id: String="wing:%d" % i
					if not switches.get(id,false): result.append(gadget(id,"破坏翼根护晶 %d / 3" % (i+1),[Vector2(320,500),Vector2(1480,500),Vector2(900,1180)][i]))
			if phase==2:
				if not switches.get("stable",false): result.append(gadget("stable","雪璃 · 稳住晶潮",Vector2(450,950),1))
				elif not switches.get("clasp",false): result.append(gadget("clasp","鸦羽 · 切开王座内扣",Vector2(1350,950),2))
				elif enemies[0].hp<=enemies[0].maxhp*.04: result.append(gadget("finisher","绯月 · 解除外侧强制认证，不伤核心",Vector2(900,650),0))
				else: result.append(gadget("crystal","强制认证护架已暴露 · 绯月解除护架",Vector2(900,720),0))
	return result

func use_gadget(id: String) -> bool:
	for n in gadgets():
		if n.id!=id or campaign.hero_at.distance_to(n.p)>campaign.INTERACT_RADIUS: continue
		if n.hero>=0 and campaign.state.hero!=n.hero:
			campaign.notice.emit("需要%s完成，按 %d 切换。" % [campaign.HERO_NAMES[n.hero],n.hero+1]); return false
		if id=="quiet-door":
			campaign.state.world["stealth:"+str(context.qid)]=true
			commit_victory(); return true
		if id=="shield" and Vector2(enemies[0].p).distance_to(n.p)>450:
			campaign.notice.emit("先把维恩的重盾引近断柱，再用断柱反制。"); return false
		if id=="crystal": campaign.notice.emit("只解除外侧强制认证护架。赤月之心、王冠与契印必须保留，等绯月回答。"); return true
		if id=="finisher":
			phase_pending=true; hazards.clear()
			campaign.state.world.finale_finisher_ready=true
			campaign.state.world.forced_array_disabled=true
			campaign.battle_speech.emit("女王","停。让她把回答说完。")
			campaign.request_scene("06-disarm",{"kind":"queen_finisher"}); return true
		switches[id]=true
		campaign.navigation_zone=""
		for e in enemies: e.stagger=1.6
		campaign.combat_event.emit({"kind":"mechanism","p":n.p})
		campaign.notice.emit("已完成："+n.label)
		var info: Dictionary=campaign.content.bosses.get(context.get("boss",""),{})
		var barks: Array=info.get("barks",[])
		if not barks.is_empty():
			var index:=2 if str(id).begins_with("turret:") else 1 if str(id).begins_with("verdict:") else 4 if str(id).begins_with("vent:") or id=="helm" else -1
			if index>=0 and index<barks.size(): campaign.battle_speech.emit(info.name,barks[index][1]); speech_cd=8
		if id=="stable": campaign.battle_speech.emit("雪璃","光稳住了。鸦羽，现在轮到你！")
		if id=="clasp": campaign.battle_speech.emit("鸦羽","外侧强制扣开了。核心没碰，绯月！")
		campaign.save_campaign(); return true
	return false

func armor() -> float:
	var key: String=context.get("boss","")
	match key:
		"inquisitor": return .40 if not (switches.get("turret:0",false) and switches.get("turret:1",false)) else 1.0
		"judge": return .18 if switches.size()<3 else 1.0
		"vein": return .3 if phase==1 and not switches.get("shield",false) else 1.0
		"surgeon": return .22 if switches.size()<2 else 1.0
		"admiral": return .35 if phase==1 and not switches.get("helm",false) else 1.0
		"queen":
			if phase==1 and switches.size()<3: return .16
			if phase==2: return 1.0 if switches.get("stable",false) and switches.get("clasp",false) else 0.0
	return 1.0

func hit(e: Dictionary,amount: float,hero: int,special: int=0,proc: bool=true) -> void:
	if e.hp<=0 or phase_pending: return
	if e.boss and context.boss=="queen" and phase==2 and hero!=0: return
	if proc: amount=campaign.equipment_combat.outgoing(e,amount,hero,special)
	var final_amount: float=amount*(armor() if e.boss else 1.0)
	var floor_hp: float=e.maxhp*.025 if e.boss and context.boss=="queen" and phase==2 else 1.0 if e.boss and armor()<.8 else 0.0
	var before := float(e.hp)
	e.hp=maxf(floor_hp,float(e.hp)-final_amount); e.flash=.16
	final_amount=maxf(0,before-float(e.hp))
	if proc: campaign.equipment_combat.after_hit(e,final_amount,hero,special)
	campaign.combat_event.emit({"kind":"hit","p":e.p,"damage":final_amount,"hero":hero})
	if e.hp<=0:
		hazards=hazards.filter(func(h): return h.owner!=e.id)
		campaign.combat_event.emit({"kind":"defeat","p":e.p})
		if not e.boss: campaign.enemy_weapon_drop(e,context,phase)
		if e.boss: phase_finished()
		elif enemies.all(func(foe): return foe.hp<=0): commit_victory()

func phase_finished() -> void:
	if phase_pending: return
	var info: Dictionary=campaign.content.bosses[context.boss]
	if phase>=int(context.get("last_phase",info.phases.size()-1)): commit_victory(); return
	phase_pending=true; hazards.clear()
	if context.boss=="queen":
		campaign.request_scene("06-08",{"kind":"boss_phase","phase":phase+1})
	else:
		phase+=1; spawn_phase(); campaign.state.checkpoint.phase=phase
		campaign.battle_speech.emit(info.name,info.lines[mini(phase,info.lines.size()-1)])
	campaign.save_campaign()

func commit_victory() -> void:
	if not running: return
	var qid: String=context.qid
	var node_id: String=context.node
	var escort: bool=context.get("escort",false)
	var boss_id: String=context.get("boss","")
	if boss_id!="":
		if boss_id!="queen":
			var info: Dictionary=campaign.content.bosses[boss_id]
			var barks: Array=info.get("barks",[])
			if not barks.is_empty(): campaign.battle_speech.emit(info.name,barks[-1][1])
		if boss_id!="queen":
			campaign.state.world["boss_defeated:"+boss_id]=true
			campaign.boss_equipment_drop(boss_id,campaign.hero_at)
		else: campaign.state.world["queen_control_stage:"+str(phase)]=true
	clear(); campaign.state.encounter={}
	if not escort:
		campaign.state.checkpoint={}
		campaign.advance_step(qid,node_id)
	else: campaign.notice.emit("护送段威胁已解除。继续引导同行者去接收点。")
	campaign.changed.emit(); campaign.save_campaign()

func add_hazard(e: Dictionary,shape: String,at: Vector2,radius: float,delay: float,direction: Vector2=Vector2.UP) -> void:
	serial+=1
	hazards.append({"id":serial,"owner":e.id,"origin":e.p,"shape":shape,"p":at,"radius":radius*campaign.terrain().speed_scale(),"reach":(520 if shape=="line" else 470)*campaign.terrain().speed_scale(),"inner":135*campaign.terrain().speed_scale(),"delay":delay,"total":delay,"direction":direction,"damage":18.0+int(campaign.state.act)*2.5,"resolved":false,"after":.3})

func attack_pattern(e: Dictionary) -> void:
	var target: Vector2=campaign.hero_at
	var direction: Vector2=Vector2(e.p).direction_to(target)
	e.attack+=1
	if not e.boss:
		add_hazard(e,"line" if e.name=="王庭弩手" else "circle",target,95,.85,direction); return
	var key: String=context.boss
	var which: int=int(e.attack)%3
	match key:
		"inquisitor":
			add_hazard(e,"line",target,170,1.15,direction)
			if phase==1 or not switches.get("turret:0",false): add_hazard(e,"line",target+Vector2(-180,0),85,1.65,Vector2.RIGHT)
			if phase==1 or not switches.get("turret:1",false): add_hazard(e,"line",target+Vector2(180,0),85,1.65,Vector2.DOWN)
		"judge":
			add_hazard(e,"rect",Vector2(420+which*480,860),200,1.35)
			if phase==1: add_hazard(e,"line",target,130,.95,direction)
		"vein":
			add_hazard(e,"cone",e.p,340,.85,direction)
			if phase==1: add_hazard(e,"line",target,100,1.4,direction)
		"surgeon":
			add_hazard(e,"line",target,135,1.2,Vector2.RIGHT.rotated(which*PI/3))
			if not switches.get("vent:0",false) or phase==1: add_hazard(e,"circle",target+Vector2(180,70),210,1.8)
		"admiral":
			add_hazard(e,"ring" if which==0 else "line",e.p if which==0 else target,340,1.3,direction)
			if phase==1: add_hazard(e,"rect",Vector2(500+which*400,850),150,1.8)
		"queen":
			if phase==0: add_hazard(e,"cone",e.p,390,1.15,direction)
			elif phase==1:
				add_hazard(e,"ring",e.p,420,1.35)
				add_hazard(e,"line",target,140,1.6,Vector2.RIGHT)
			else:
				add_hazard(e,"circle",target,210,1.65)
				if not switches.get("stable",false): add_hazard(e,"line",Vector2(900,950),180,2,Vector2.DOWN)
		_:
			add_hazard(e,"circle",target,240,1.1)
			if phase==1: add_hazard(e,"ring",e.p,370,1.6)
	if speech_cd<=0:
		var info: Dictionary=campaign.content.bosses[key]
		var barks: Array=info.get("barks",[])
		var line: String=info.lines[mini(phase,info.lines.size()-1)]
		if not barks.is_empty(): line=barks[mini(1+int(e.attack)%2,barks.size()-1)][1]
		campaign.battle_speech.emit(info.name,line); speech_cd=8.0

func hazard_contains(h: Dictionary,p: Vector2) -> bool:
	if h.shape in ["line","cone"] and not campaign.sight(h.get("origin",h.p),p): return false
	var diff: Vector2=p-h.p
	match h.shape:
		"ring": return diff.length()>float(h.get("inner",135)) and diff.length()<h.radius
		"line": return absf(diff.dot(Vector2(-h.direction.y,h.direction.x)))<h.radius*.40 and absf(diff.dot(h.direction))<float(h.get("reach",520))
		"rect": return absf(diff.x)<h.radius and absf(diff.y)<float(h.get("reach",470))
		"cone": return diff.length()<h.radius and diff.normalized().dot(h.direction)>.35
	return diff.length()<h.radius

func tick(dt: float) -> void:
	if not running or phase_pending: return
	tick_time+=dt; companion_cd-=dt; speech_cd-=dt
	opening_grace=maxf(0,opening_grace-dt)
	for e in enemies:
		e.flash=maxf(0,float(e.flash)-dt); e.stagger=maxf(0,float(e.stagger)-dt)
		if e.hp<=0 or e.stagger>0: continue
		if context.get("stealth",false):
			var origin: Vector2=e.get("patrol_origin",e.p)
			e.watch=Vector2.UP.rotated(sin(tick_time*.7)*1.4)
			var target: Vector2=origin+Vector2(sin(tick_time*.55)*210,cos(tick_time*.4)*90)
			e.p=campaign.move_point(e.p,Vector2(e.p).direction_to(target)*65*campaign.terrain().speed_scale()*dt)
			var diff: Vector2=campaign.hero_at-e.p
			if diff.length()<330*campaign.terrain().speed_scale() and diff.normalized().dot(e.watch)>.55 and campaign.sight(e.p,campaign.hero_at):
				context.stealth=false; opening_grace=1.5
				campaign.battle_speech.emit(e.name,"后巷有人！关门！")
			else: continue
		e.cd-=dt
		if opening_grace<=0 and e.cd<=0 and Vector2(e.p).distance_to(campaign.hero_at)<950*campaign.terrain().speed_scale():
			attack_pattern(e); e.cd=2.6 if e.boss else 2.1
		var toward: Vector2=campaign.navigate(e.p,campaign.hero_at)
		if Vector2(e.p).distance_to(campaign.hero_at)>220*campaign.terrain().speed_scale() and not (e.boss and context.boss=="queen" and phase==2):
			var slow := float(e.get("rpg_slow",0))*(.35 if e.boss else 1.0) if float(e.get("rpg_slow_time",0))>0 else 0.0
			e.p=campaign.move_point(e.p,toward*(65 if e.boss else 95)*campaign.terrain().speed_scale()*dt*(1.0-slow/100.0))
	if companion_cd<=0:
		companion_cd=.8
		for hero in campaign.state.party:
			if hero==campaign.state.hero: continue
			for e in enemies:
				if e.hp>0 and Vector2(campaign.allies[hero]).distance_to(e.p)<450*campaign.terrain().speed_scale() and campaign.sight(campaign.allies[hero],e.p):
					hit(e,campaign.damage(hero)*.38,hero,3)
					if not running or phase_pending: return
					break
	for h in hazards:
		h.delay-=dt
		if h.delay<=0 and not h.resolved:
			h.resolved=true
			if campaign.invulnerable<=0 and hazard_contains(h,campaign.hero_at):
				var element: String=campaign.Equipment.data().chapters[clampi(int(campaign.state.act)-1,0,5)].element
				campaign.take_damage(float(h.damage),element,.65)
			for person in campaign.escort_group:
				if person.hp>0 and hazard_contains(h,person.p): person.hp=maxf(0,person.hp-campaign.equipment_combat.incoming(float(h.damage)*.65,"physical",true))
	hazards=hazards.filter(func(h): return h.delay>-.32)
