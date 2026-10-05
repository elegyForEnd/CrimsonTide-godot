extends RefCounted
## Authored encounter timelines, inspired by the researched ActionLogicGroup chains.
## Collision primitives are shared; each boss owns its sequence, entities and counterplay.
const Art = preload("res://scripts/boss_effect_art.gd")
const Geometry = preload("res://scripts/boss_geometry.gd")
const Presentation = preload("res://scripts/boss_presentation.gd")
const MOVES := {
	"bell":["钟摆葬列","止声错拍","敲钟者","九刻终祷"],
	"thorn":["荆种追猎","根结囚庭","蛇行藤鞭","猎王播种"],
	"queen":["悬剑王庭","六瓣御令","棋盘处刑","落冠裁决"],
	"knight":["踏步返刃","残影易位","架剑破军","拔剑终誓"],
	"hidden":["裂隙鬼手","枯骨牢门","墓碑唤魂","冥府迁葬"],
	"mirror":["三镜折射","纺线缚影","倒映替身","碎镜雨幕"],
	"ember":["悬炉焚香","烬蛾扑灯","熄灯晚祷","三烛游火"],
	"moon":["血瞳凝视","凝血坠星","脉络倒流","赤月吞心"],
	"earth":["钻地折返","断层立壁","穹顶坠岩","蜕甲震穴"],
	"storm":["雷弧折返","连锁雷笼","风眼收束","雷骸超载"],
	"abyss":["潮汐吸引","错齿吞噬","蛇流换岸","噬月深潜"],
	"dragon":["霜息扫庭","冰骨遮城","双翼冻裂","霜华落骨"],
	"grove":["古根织网","孢荚播散","菌冠滋养","藤须迁行","菌林召生"],
	"furnace":["锁链拖拽","炽铆连射","泄压熔井","链锤摆荡","熔心过载"],
	"astral":["棱星折光","镜轨环游","三拍陨星","星棱换位","星镜碎界"],
	"wing":["逆风航道","折返雷矢","游走风眼","折线俯冲","天穹失速"],
	"obsidian":["墨影三易","悬剑落墨","禁庭四角","黑曜拔刀","绝剑留白"]}

static func names(e: Dictionary) -> Array: return MOVES[Art.identity(e)]
static func choose(e: Dictionary) -> String:
	var pool := names(e)
	var order := [0,1,0,2,3] if int(e.get("phase",1))<2 and not e.get("boss_enraged",false) else [2,0,3,1,4]
	return str(pool[int(order[int(e.get("sequence",e.get("move_cursor",0)))%order.size()])%pool.size()])

static func start(s, e: Dictionary, move: String, aim: Vector2, point: Vector2) -> bool:
	var key := Art.identity(e)
	var index: int=MOVES[key].find(move)
	if index<0: return false
	# A previous sequence's delayed entities must not survive a new cast.
	e["choreo_sound_marks"]=[]
	e["choreo_steps"]=[]
	e["choreo_serial"]=int(e.get("choreo_serial",0))+1
	e["choreo_part"]=0
	e["choreo_elapsed"]=0.0
	e["choreo_active"]=true
	e["choreo_cast"]=true
	e["move_id"]=move
	e["move_name"]=move
	e["attack_aim"]=aim.normalized() if aim.length_squared()>.01 else Vector2.RIGHT
	if absf(aim.x)>.05: e.facing=signf(aim.x)
	var a: Vector2=e.attack_aim
	var side := a.orthogonal()
	var at: Vector2=e.p
	
	var damage := 20.0+minf(18,float(e.max_hp)*.003)
	if e.get("rogue_guardian",false): damage=float(e.get("build_base_damage",20.0+int(e.rogue_skin)*4.0))*float(e.get("build_damage_scale",1))
	
	e["choreo_marks"]=[]
	var roles: Array=Art.MOTIFS[key]
	match key:
		"bell":
			match index:
				0: # A swinging clapper crosses a fixed row; gaps lie between contacts.
					for i in 5: zone(s,e,"circle",at+a*125+side*(i-2)*115,a,58,.85+i*.20,damage,roles[0])
				1: # Rest beat is deliberately longer than the first beat.
					for i in 3:
						zone(s,e,"lane",at+side*((i-1)*180)-a*240,a,480,[.7,1.85,2.25][i],damage*.85,roles[1],38)
				2:
					construct(e,at+side*160,roles[2],"bell_tower",3.9)
					for i in 3: zone(s,e,"circle",point+side*(i-1)*105,a,75,1.0+i*.75,damage,roles[2],0,{"link":"bell_tower"})
				3:
					for i in 6:
						var ray := a.rotated(i*TAU/6)
						zone(s,e,"circle",at+ray*235,ray,75,1.15+(i%3)*.35,damage,roles[3])
		"thorn":
			match index:
				0:
					for i in 5: projectile(e,at,a.rotated((i-2)*.22),.65+i*.09,170,damage*.65,roles[1],{"plant":true,"plant_role":roles[2],"life":1.5})
				1:
					construct(e,point+side*105,roles[2],"root_knot",3.4)
					for i in 5: zone(s,e,"circle",point+Vector2.from_angle(i*TAU/5)*115,a,42,1.15,damage*.75,roles[2],0,{"linger":2.0,"slow":.35,"link":"root_knot"})
				2:
					for i in 7: zone(s,e,"circle",at+a*(70+i*65)+side*sin(i*1.3)*85,a,48,.7+i*.14,damage*.65,roles[0],0,{"linger":.45})
				3:
					for i in 3:
						construct(e,at+Vector2.from_angle(i*TAU/3)*170,roles[1],"seed_%d"%i,3.7)
						zone(s,e,"circle",at+Vector2.from_angle(i*TAU/3)*170,a,90,2.2+i*.22,damage,roles[2],0,{"link":"seed_%d"%i,"linger":1.4})
		"queen":
			match index:
				0:
					for i in 3:
						var pos := point+side*(i-1)*135
						construct(e,pos,roles[0],"sabre_%d"%i,3.8)
						zone(s,e,"circle",pos,a,62,1.05+i*.45,damage,roles[0],0,{"link":"sabre_%d"%i})
				1:
					for i in 6: projectile(e,at,a.rotated(i*TAU/6),.95,140,damage*.7,roles[2],{"orbit":.75,"life":2.6})
				2:
					for x in 3:
						for y in 3:
							if (x+y)%2==0: zone(s,e,"circle",point+Vector2(x-1,y-1)*135,a,56,1.0,damage*.8,roles[1])
					zone(s,e,"circle",point,a,58,2.3,damage,roles[2])
				3:
					construct(e,at+side*130,roles[3],"crown",4.3)
					for i in 4: zone(s,e,"circle",point+a*(i-1.5)*100,a,66,1.1+i*.5,damage,roles[0],0,{"link":"crown"})
		"knight":
			match index:
				0:
					zone(s,e,"cone",at,a,175,.65,damage*.7,roles[0])
					motion(e,at+a*90,.95)
					zone(s,e,"cone",at+a*90,-a,200,1.10,damage*.8,roles[0])
					zone(s,e,"cone",at+a*90,a,235,2.05,damage*1.1,roles[0])
				1:
					zone(s,e,"circle",at,a,45,.75,0,roles[3])
					motion(e,point-a*110,.9,true)
					zone(s,e,"cone",point-a*110,a,170,1.3,damage,roles[0])
				2:
					e["guard_time"]=.8
					e["guard_aim"]=a
					e["guard_load"]=0.0
					zone(s,e,"cone",at,a,215,1.35,damage,roles[0],0,{"cancel_on_break":true})
				3:
					zone(s,e,"lane",at,a,360,1.45,damage*1.15,roles[1],32)
					motion(e,at+a*300,1.45)
					zone(s,e,"cone",at+a*300,-a,180,2.1,damage*.75,roles[0])
		"hidden":
			match index:
				0:
					for i in 3:
						var pos := point+side*(i-1)*130
						zone(s,e,"circle",pos,a,55,.9+i*.45,damage,roles[1],0,{"pull":110,"linger":.6})
				1:
					construct(e,point-a*130,roles[3],"grave_lock",3.7)
					for i in 7: zone(s,e,"circle",point+Vector2.from_angle(i*TAU/7)*145,a,35,1.15,damage*.6,roles[2],0,{"linger":1.5,"link":"grave_lock"})
				2:
					for i in 3:
						var pos := at+Vector2.from_angle(i*TAU/3)*210
						construct(e,pos,roles[3],"tomb_%d"%i,4.2)
						projectile(e,pos,(point-pos).normalized(),1.8+i*.35,140,damage*.7,roles[1],{"link":"tomb_%d"%i,"homing":.45,"life":2.0})
				3:
					var landing := point+a*145
					zone(s,e,"circle",landing,a,70,1.1,damage,roles[0])
					motion(e,landing,1.0,true)
					for i in 4: projectile(e,landing,a.rotated(i*TAU/4),1.4,180,damage*.7,roles[1])
		"mirror":
			match index:
				0:
					for i in 3:
						var pos := at+a*(120+i*130)+side*(90 if i%2==0 else -90)
						construct(e,pos,roles[0],"mirror_%d"%i,4.0)
						projectile(e,at,a,1.0+i*.22,225,damage*.65,roles[1],{"path":[pos,point+side*(i-1)*90],"link":"mirror_%d"%i})
				1:
					for i in 3: zone(s,e,"lane",point+side*(i-1)*150-a*220,a,440,.9+i*.40,damage*.75,roles[1],18,{"linger":.4})
				2:
					construct(e,point+side*150,roles[0],"reflection",3.2)
					motion(e,at-side*170,.9,true)
					zone(s,e,"circle",point+side*150,a,100,2.0,damage,roles[2],0,{"link":"reflection"})
				3:
					for i in 7: zone(s,e,"circle",point+side*(i-3)*85+a*(40 if i%2==0 else -65),a,32,.8+i*.16,damage*.65,roles[2])
		"ember":
			match index:
				0:
					for i in 2:
						var pos := at+side*(i*2-1)*175
						construct(e,pos,roles[0],"censer_%d"%i,4.6)
						zone(s,e,"lane",pos-a*200,a,420,1.1,damage*.5,roles[2],42,{"link":"censer_%d"%i,"linger":2.8,"pulse_interval":.7})
				1:
					for i in 7: projectile(e,at,a.rotated((i-3)*.24),.75+i*.08,125,damage*.6,roles[1],{"homing":.55,"plant":true,"plant_role":roles[2],"life":1.6})
				2:
					construct(e,at+a*140,roles[0],"lamp",3.6)
					zone(s,e,"circle",at+a*140,a,170,2.15,damage*1.2,roles[2],0,{"link":"lamp"})
				3:
					for i in 3:
						var pos := point+Vector2.from_angle(i*TAU/3)*160
						zone(s,e,"circle",pos,a,62,.9+i*.7,damage*.7,roles[2],0,{"velocity":(point-pos).normalized()*45,"linger":1.2})
		"moon":
			match index:
				0:
					zone(s,e,"lane",at,a,540,1.55,damage,roles[0],28,{"rotate":.45,"linger":1.4,"pulse_interval":.6})
				1:
					for i in 5: projectile(e,point+side*(i-2)*100-a*170,a,1.0+i*.15,165,damage*.5,roles[1],{"plant":true,"plant_role":roles[2],"life":1.0})
				2:
					for i in 3: zone(s,e,"lane",at+side*(i-1)*180-a*200,a,450,1.1+i*.28,damage*.6,roles[2],30,{"pull":85,"linger":1.8})
				3:
					zone(s,e,"circle",at,a,380,.8,0,roles[3],95,{"pull":90,"linger":1.4,"pulse_interval":.25})
					zone(s,e,"circle",at,a,100,2.4,damage*1.2,roles[0])
		"earth":
			match index:
				0:
					for i in 5: zone(s,e,"circle",at+a*(70+i*90),a,42,.9+i*.18,damage*.7,roles[0],0,{"linger":1.5})
					motion(e,at+a*360,1.45)
					motion(e,at+side*120,2.1)
					zone(s,e,"circle",at+side*120,a,85,2.3,damage,roles[2])
				1:
					for i in 3:
						var pos := point+side*(i-1)*150
						construct(e,pos,roles[1],"plate_%d"%i,4.2,true)
						zone(s,e,"circle",pos,a,60,1.2+i*.2,damage*.7,roles[0])
				2:
					for i in 6: zone(s,e,"circle",point+side*(i-2.5)*100+a*(75 if i%2 else -75),a,42,1.0+i*.18,damage*.9,roles[2])
				3:
					for i in 4: projectile(e,at,a.rotated(i*PI*.5),1.2,140,damage*.8,roles[1],{"life":1.4,"plant":true,"plant_role":roles[0]})
		"storm":
			match index:
				0:
					for i in 5: projectile(e,at,a.rotated((i-2)*.25),.75,230,damage*.65,roles[0],{"return":true,"life":2.6})
				1:
					for i in 3: zone(s,e,"lane",point+side*(i-1)*165-a*220,a,440,.85+i*.35,damage*.8,roles[1],20,{"linger":.8,"pulse_interval":.5})
				2:
					zone(s,e,"gap_ring",at,a,330,1.2,damage*.75,roles[2],190,{"gap":.65,"rotate":.35,"linger":1.4,"pulse_interval":.7})
				3:
					for i in 8: zone(s,e,"circle",at+Vector2.from_angle(i*TAU/8)*230,a,50,1.5+(i%2)*.4,damage,roles[1])
					e["choreo_recovery"]=1.65
		"abyss":
			match index:
				0:
					zone(s,e,"circle",at,a,360,.7,0,roles[3],110,{"pull":100,"linger":1.8,"pulse_interval":.25})
					zone(s,e,"cone",at,a,220,2.65,damage*1.2,roles[0],0,{"arc":.65})
				1:
					for i in 4: zone(s,e,"circle",at+a*(110+i*65)+side*(80 if i%2 else -80),a,55,1.0+i*.25,damage*.75,roles[0])
				2:
					for i in 3: zone(s,e,"lane",point+side*(i-1)*180-a*250,a,500,1.0+i*.3,damage*.6,roles[1],35,{"velocity":side*(35 if i%2 else -35),"push":80,"linger":1.7})
				3:
					zone(s,e,"gap_ring",at,a,360,1.25,damage,roles[2],225,{"gap":.7,"rotate":-.3,"linger":1.4,"pulse_interval":.7})
					motion(e,point-a*160,2.8,true)
					zone(s,e,"cone",point-a*160,a,190,3.25,damage,roles[0],0,{"arc":.6})
		"dragon":
			match index:
				0:
					zone(s,e,"lane",at,a.rotated(-.35),470,1.1,damage*.55,roles[1],40,{"rotate":.32,"linger":2.2,"pulse_interval":.65,"slow":.25,"cover":true})
					for i in 3: zone(s,e,"circle",at+a*(120+i*110),a,46,1.6+i*.25,damage*.25,roles[3],0,{"slow":.35,"linger":2.2,"pulse_interval":.9})
				1:
					for i in 3:
						var pos := at+side*(i-1)*150+a*130
						construct(e,pos,roles[0],"ice_%d"%i,4.5,true)
						zone(s,e,"circle",pos,a,45,1.0+i*.15,damage*.7,roles[0])
				2:
					zone(s,e,"cone",at,side,230,.85,damage*.8,roles[2],0,{"arc":.55})
					zone(s,e,"cone",at,-side,230,1.55,damage,roles[2],0,{"arc":.55})
				3:
					for i in 6: zone(s,e,"circle",point+Vector2.from_angle(i*TAU/6)*140,a,38,1.05+i*.15,damage*.65,roles[0],0,{"slow":.35,"linger":1.6})
		"grove":
			match index:
				0:
					for i in 6: zone(s,e,"circle",at+a*(70+i*65)+side*sin(i)*55,a,35,.85+i*.18,damage*.65,roles[0],0,{"slow":.3,"linger":1.4})
				1:
					for i in 5: projectile(e,at,a.rotated((i-2)*.35),.8,125,damage*.4,roles[1],{"plant":true,"plant_role":roles[2],"life":1.5})
				2:
					construct(e,at-a*140,roles[2],"nurse",3.7)
					step(e,1.8,{"op":"heal","link":"nurse","amount":.045})
					zone(s,e,"circle",at-a*140,a,70,2.4,damage*.6,roles[2],0,{"link":"nurse","linger":.8})
				3:
					motion(e,at+a*250,1.1)
					for i in 4: zone(s,e,"circle",at+a*i*75,a,45,.9+i*.15,damage*.7,roles[0])
				4:
					step(e,1.4,{"op":"summon"})
					for i in 3: zone(s,e,"circle",at+side*(i-1)*125,a,45,1.1+i*.15,damage*.5,roles[2])
		"furnace":
			match index:
				0:
					zone(s,e,"lane",at,a,390,1.0,damage*.65,roles[0],23,{"pull":160,"linger":.75})
					zone(s,e,"circle",at+a*70,a,72,2.1,damage,roles[2])
				1:
					for i in 8: projectile(e,at,a.rotated((i%3-1)*.18),.7+i*.14,260,damage*.4,roles[1],{"life":1.8})
				2:
					for i in 3:
						var pos := point+side*(i-1)*150
						construct(e,pos,roles[3],"valve_%d"%i,3.7)
						zone(s,e,"circle",pos,a,62,1.9+i*.25,damage,roles[2],0,{"link":"valve_%d"%i,"linger":1.1})
				3:
					zone(s,e,"lane",at,a.rotated(-.7),340,1.1,damage*.75,roles[0],25,{"rotate":.6,"linger":1.5,"pulse_interval":.6})
				4:
					for i in 4: zone(s,e,"circle",at+side*(i-1.5)*130,a,65,1.6+(i%2)*.5,damage,roles[2])
					e["choreo_recovery"]=1.7
		"astral":
			match index:
				0:
					for i in 2: projectile(e,at,a,1.0+i*.3,240,damage*.65,roles[1],{"path":[at+a*170+side*(120 if i==0 else -120),point],"life":3.0})
				1:
					for i in 7: projectile(e,at,Vector2.from_angle(i*TAU/7),.9,125,damage*.55,roles[0],{"orbit":1.1,"life":3.0})
				2:
					for i in 3: zone(s,e,"circle",point+side*(i-1)*160,a,60,.85+i*.65,damage*.9,roles[2])
				3:
					construct(e,at+side*155,roles[0],"prism",3.3)
					motion(e,at-side*155,1.0,true)
					zone(s,e,"circle",at+side*155,a,85,2.0,damage,roles[2],0,{"link":"prism"})
				4:
					for i in 4: projectile(e,at,Vector2.from_angle(i*TAU/4),1.5,190,damage*.7,roles[2],{"return":true,"life":2.4})
					e["choreo_recovery"]=1.45
		"wing":
			match index:
				0:
					for i in 3: zone(s,e,"lane",point+side*(i-1)*145-a*240,a,480,1.0+i*.3,damage*.5,roles[0],25,{"push":130,"linger":1.3})
				1:
					for i in 3: projectile(e,at,a.rotated((i-1)*.4),.75,250,damage*.65,roles[1],{"return":true,"life":2.7})
				2:
					zone(s,e,"circle",at+a*120,a,75,1.2,damage*.45,roles[2],0,{"velocity":side*80,"pull":65,"linger":2.0,"pulse_interval":.7})
				3:
					for i in 3:
						var pos := at+a*(100+i*85)+side*(70 if i%2 else -70)
						zone(s,e,"circle",pos,a,48,.85+i*.45,damage*.8,roles[0])
						motion(e,pos,.85+i*.45)
				4:
					for i in 6: zone(s,e,"circle",point+side*(i-2.5)*95,a,40,1.45+(i%2)*.38,damage,roles[1])
					e["choreo_recovery"]=1.6
		"obsidian":
			match index:
				0:
					for i in 3:
						var pos := point+Vector2.from_angle(i*TAU/3)*150
						motion(e,pos,.7+i*.55,true)
						zone(s,e,"lane",pos,(point-pos).normalized(),300,1.05+i*.55,damage*.8,roles[0],22)
				1:
					for i in 5: zone(s,e,"circle",point+side*(i-2)*90,a,26,1.0+i*.18,damage*.75,roles[2])
				2:
					# Four corner seals leave the centre open; a second cast reverses timing.
					for i in 4: zone(s,e,"circle",point+Vector2(-1 if i%2==0 else 1,-1 if i<2 else 1)*115,a,66,1.2+(i%2)*.45,damage*.75,roles[3],0,{"linger":.8})
				3:
					zone(s,e,"lane",at,a,470,1.75,damage*1.15,roles[0],22)
					motion(e,at+a*330,1.75)
				4:
					construct(e,point+side*140,roles[1],"sword_echo",3.5)
					zone(s,e,"lane",point+side*140,-side,280,1.15,damage*.75,roles[0],22,{"link":"sword_echo"})
					zone(s,e,"lane",at,a,420,2.2,damage,roles[0],22)
					e["choreo_recovery"]=1.6
	resolve_positions(s,e)
	for action in e.choreo_steps:
		if action.op=="projectile":
			var heading: Vector2=action.aim
			var reach := 220.0
			if action.has("path") and not action.path.is_empty(): heading=(action.path[0]-action.p).normalized(); reach=action.p.distance_to(action.path[0])
			zone(s,e,"lane",action.p,heading,reach,float(action.at),0,str(action.role),18,{"preview_only":true,"linger":.04,"link":action.get("link","")})
	var marks: Array=e.choreo_marks
	for action in e.choreo_steps:
		if action.op!="construct" and not marks.has(action.at): marks.append(action.at)
	marks.sort()
	if marks.is_empty(): marks.append(.8)
	e["attack_marks"]=marks.duplicate()
	e["windup"]=marks[0]
	e["boss_windup"]=marks[0]
	e["boss_released"]=false
	e["attack_released"]=false
	var recovery := float(e.get("choreo_recovery",.7))
	e["choreo_recovery"]=.7
	e["attack_total"]=float(marks.back())+recovery
	e["attack_time"]=e.attack_total
	e["cd"]=e.attack_total+.45
	if e.get("rogue_guardian",false):
		s.broadcast_combat({"kind":"rogue-boss-charge","p":at,"id":e.id,"floor":e.rogue_skin,"duration":marks[0],"move":move})
		s.broadcast_audio(s.roguelike.combat.cue(e,int(e.get("boss_skill",0)),"charge"),e)
	else: Presentation.send(s,e,"charge",{"total":marks[0],"vfx_role":roles[3]})
	return true

static func zone(s, e: Dictionary, shape: String, at: Vector2, aim: Vector2, radius: float, delay: float, damage: float, role: String, inner: float = 0, extra: Dictionary = {}) -> void:
	var metadata := {"source":e.id,"art_key":Art.identity(e),"boss_kind":e.get("boss_kind",3),"move":e.move_id,"phase":e.get("phase",1),"vfx_role":role,"choreographed":true,"hit_ids":[],"part":e.choreo_part,"choreo_serial":e.choreo_serial,"origin":at,"aim":aim}
	for flag in ["mini_kind","final_form","hidden_final","dragon_boss","wild_boss","wild_kind","rogue_guardian","rogue_skin"]:
		if e.has(flag): metadata[flag]=e[flag]
	e.choreo_part+=1
	metadata.merge(extra,true)
	if not e.choreo_marks.has(delay): e.choreo_marks.append(delay)
	if e.get("rogue_guardian",false):
		s.roguelike.combat.zone(e,shape,at,radius,delay,float(extra.get("linger",.28)),damage,aim,inner,at+aim*radius)
		var fx: Dictionary=s.roguelike.combat.effects.back()
		fx.merge(metadata,true)
	else:
		s.expedition.hazard(s,shape,at,aim,radius,delay,damage,inner)
		var h: Dictionary=s.raid.hazards.back()
		h.merge(metadata,true)
		if h.has("pulse_interval"): h["next_pulse"]=h.pulse_interval

static func step(e: Dictionary, at: float, data: Dictionary) -> void:
	var action := data.duplicate(true)
	action["at"]=at
	action["done"]=false
	e.choreo_steps.append(action)

## Resolve map collision before warnings are published: objects and follow-up attacks
## cannot silently jump to another point when their release arrives.
static func resolve_positions(s, e: Dictionary) -> void:
	var planned_origin: Vector2=e.p
	var records: Array=s.raid.get("hazards",[]) if not e.get("rogue_guardian",false) else s.roguelike.combat.effects
	for action in e.choreo_steps:
		if action.op not in ["construct","motion"]: continue
		var intended: Vector2=action.p if action.op=="construct" else action.to
		var resolved: Vector2=safe_point(s,intended) if action.op=="construct" or action.get("warp",false) else s.ruins.move(planned_origin,intended-planned_origin,30)
		if action.op=="construct": action.p=resolved
		else: action.to=resolved; planned_origin=resolved
		if resolved.distance_to(intended)<.01: continue
		for h in records:
			if h.get("source",-1)!=e.id or h.get("choreo_serial",-1)!=e.choreo_serial: continue
			if action.op=="construct" and h.get("link","")!=action.link: continue
			if h.p.distance_to(intended)<.01:
				h.p=resolved; h.origin=resolved
		for other in e.choreo_steps:
			if other.op!="projectile": continue
			if other.p.distance_to(intended)<.01: other.p=resolved
			for i in other.get("path",[]).size():
				if other.path[i].distance_to(intended)<.01: other.path[i]=resolved
static func projectile(e: Dictionary, at: Vector2, aim: Vector2, delay: float, speed: float, damage: float, role: String, extra: Dictionary = {}) -> void:
	var data := {"op":"projectile","p":at,"aim":aim,"speed":speed,"damage":damage,"role":role}
	data.merge(extra,true)
	step(e,delay,data)
static func motion(e: Dictionary, to: Vector2, at: float, warp: bool = false) -> void:
	step(e,at,{"op":"motion","to":to,"warp":warp})
static func construct(e: Dictionary, at: Vector2, role: String, link: String, life: float, cover: bool = false) -> void:
	step(e,0,{"op":"construct","p":at,"role":role,"link":link,"life":life,"cover":cover})

static func linked(s, source: int, link: String) -> bool:
	if link.is_empty(): return true
	for prop in s.enemies:
		if prop.get("boss_construct",false) and prop.get("construct_owner",-1)==source and prop.get("construct_link","")==link and prop.hp>0: return true
	return false

static func advance(s, dt: float) -> void:
	for e in s.enemies.duplicate():
		if e.get("boss_construct",false):
			e.construct_life-=dt
			e["construct_age"]=float(e.get("construct_age",0))+dt
			if e.art_key=="queen" and e.vfx_role=="sabres":
				var drop_at := 1.05+int(str(e.construct_link).get_slice("_",1))*.45
				e["visual_lift"]=maxf(0,105*(1-float(e.construct_age)/drop_at))
			var owner_alive := false
			for boss in s.enemies:
				if boss.id==e.construct_owner and boss.hp>0: owner_alive=true; break
			if e.construct_life<=0 or not owner_alive: e.hp=0
			continue
		if not e.get("choreo_active",false): continue
		if e.hp<=0 or float(e.get("stagger",0))>0:
			e.choreo_active=false
			e.choreo_steps=[]
			e.attack_time=0.0
			cancel(s,e.id)
			continue
		e.choreo_elapsed+=dt
		for action in e.choreo_steps:
			if action.done or e.choreo_elapsed<float(action.at): continue
			action.done=true
			if not linked(s,e.id,str(action.get("link",""))) and action.op!="construct": continue
			match str(action.op):
				"construct":
					var prop := {"id":s.next_enemy,"p":action.p,"type":0,"hp":65.0,"max_hp":65.0,"last":1,"facing":1.0,"flash":0.0,"moving":false,"motion_phase":0.0,"attack_time":0.0,"boss_construct":true,"construct_owner":e.id,"construct_link":action.link,"construct_life":action.life,"construct_cover":action.cover,"rogue_radius":26.0,"art_key":Art.identity(e),"vfx_role":action.role,"habitat":-1}
					s.next_enemy+=1
					s.enemies.append(prop)
				"projectile":
					var b := {"p":action.p,"v":action.aim*action.speed,"life":action.get("life",2.8),"damage":action.damage,"owner":0,"boss_projectile":true,"boss_source":e.id,"art_key":Art.identity(e),"vfx_role":action.role,"boss_age":0.0,"boss_origin":action.p,"boss_aim":action.aim,"boss_speed":action.speed,"boss_total":action.get("life",2.8),"hit_radius":18.0,"boss_token":str(e.id)+":"+str(e.choreo_serial)+":"+str(action.at)+":"+str(action.p)+":"+str(action.aim)}
					for flag in ["path","return","orbit","homing","plant","plant_role"]:
						if action.has(flag): b["boss_"+flag]=action[flag]
					if b.has("boss_path") and not b.boss_path.is_empty(): b.v=(b.boss_path[0]-b.p).normalized()*action.speed
					if e.get("rogue_guardian",false): b["rogue_tone"]=e.rogue_skin; b["rogue_guardian"]=true
					s.bullets.append(b)
					contact(s,e,action)
				"motion":
					if action.warp: e.p=safe_point(s,action.to)
					else: e["choreo_motion"]={"from":e.p,"to":action.to,"age":0.0,"duration":.18}
				"heal": e.hp=minf(e.max_hp,e.hp+e.max_hp*float(action.amount))
				"summon":
					for i in 3: s.roguelike.combat.summons.append({"floor":e.rogue_skin,"variant":i+1,"p":safe_point(s,e.p+Vector2((i-1)*90,60)),"owner":e.id})
			if action.op in ["motion","heal","summon"]: contact(s,e,action)
		if e.has("choreo_motion"):
			var motion_data: Dictionary=e.choreo_motion
			motion_data.age+=dt
			var before: Vector2=e.p
			var intended: Vector2=motion_data.from.lerp(motion_data.to,clampf(motion_data.age/motion_data.duration,0,1))
			e.p=s.ruins.move(e.p,intended-e.p,30)
			e.moving=e.p.distance_to(before)>.01
			e.motion_phase+=e.p.distance_to(before)/12
			if motion_data.age>=motion_data.duration: e.erase("choreo_motion")
		if e.choreo_elapsed>=e.attack_total: e.choreo_active=false
	# Motion and steering are host authoritative, serialized in the existing snapshots.
	for b in s.bullets:
		if not b.get("boss_projectile",false): continue
		b.boss_age+=dt
		var living := false
		for e in s.enemies:
			if e.id==b.boss_source and e.hp>0: living=true; break
		if not living: b.life=0; b["boss_plant"]=false; continue
		if b.has("boss_path") and not b.boss_path.is_empty():
			if b.p.distance_to(b.boss_path[0])<float(b.boss_speed)*dt+18: b.boss_path.pop_front()
			if not b.boss_path.is_empty(): b.v=(b.boss_path[0]-b.p).normalized()*b.boss_speed
		if b.get("boss_return",false) and b.boss_age>b.boss_total*.5: b.v=(b.boss_origin-b.p).normalized()*b.boss_speed
		elif b.has("boss_orbit") and b.boss_age<1.2: b.v=b.v.rotated(float(b.boss_orbit)*dt)
		elif b.has("boss_homing") and b.boss_age<float(b.boss_homing):
			var target := nearest(s,b.p)
			if not target.is_empty(): b.v=b.v.lerp((target.p-b.p).normalized()*b.boss_speed,clampf(dt*3,0,1))

static func contact(s, e: Dictionary, action: Dictionary) -> void:
	e["boss_released"]=true
	if e.get("rogue_guardian",false):
		s.broadcast_audio(s.roguelike.combat.cue(e,int(e.get("boss_skill",0)),"release"),e)
	else: Presentation.send(s,e,"release",{"shape":"projectile","choreographed":true,"radius":18,"p":action.get("p",e.p),"vfx_role":action.get("role","crest")})

static func nearest(s, at: Vector2) -> Dictionary:
	var result: Dictionary={}
	var best := INF
	for p in s.players.values():
		if p.status=="active" and p.p.distance_squared_to(at)<best: best=p.p.distance_squared_to(at); result=p
	return result
static func cancel(s, source: int) -> void:
	for i in range(s.raid.get("hazards",[]).size()-1,-1,-1):
		if s.raid.hazards[i].get("source",-1)==source and s.raid.hazards[i].get("choreographed",false): s.raid.hazards.remove_at(i)
	for i in range(s.roguelike.combat.effects.size()-1,-1,-1):
		if s.roguelike.combat.effects[i].source==source and s.roguelike.combat.effects[i].get("choreographed",false): s.roguelike.combat.effects.remove_at(i)
static func cover_blocks(s, h: Dictionary, at: Vector2) -> bool:
	if not h.get("cover",false): return false
	var count := 0
	for prop in s.enemies:
		if not prop.get("boss_construct",false) or not prop.get("construct_cover",false) or prop.hp<=0: continue
		if count>=8: break
		count+=1
		var nearest_point := Geometry2D.get_closest_point_to_segment(prop.p,h.p,at)
		if nearest_point.distance_to(prop.p)<35 and prop.p.distance_to(h.p)<at.distance_to(h.p)-25: return true
	return false
static func projectile_end(s, b: Dictionary) -> void:
	if not b.get("boss_plant",false): return
	b.boss_plant=false
	for e in s.enemies:
		if e.id==b.boss_source and e.hp>0:
			zone(s,e,"circle",b.p,b.boss_aim,52,.45,float(b.damage)*.8,str(b.get("boss_plant_role",b.vfx_role)),0,{"linger":1.3,"slow":.25})
			break

static func modifiers(s, h: Dictionary, dt: float) -> void:
	if not h.get("fired",h.get("active",false)): return
	for p in s.players.values():
		if p.status!="active" or float(p.get("dodge_time",0))>0: continue
		if s.roguelike.active(s) and not s.RogueActions.height_hit(float(p.get("height",0)),str(h.get("height_tag","ground" if h.shape in ["ring","roots","cross"] else "normal"))): continue
		var inside: bool=Geometry.contains(h,p.p)
		if not inside or cover_blocks(s,h,p.p): continue
		p["boss_slow"]=maxf(float(p.get("boss_slow",0)),float(h.get("slow",0))*(.75 if s.roguelike.active(s) and s.RogueBuild.gear(p,64) else 1.0))
		var force := float(h.get("pull",0))-float(h.get("push",0))
		if force!=0: p.p=s.ruins.move(p.p,(h.p-p.p).normalized()*force*dt*(.7 if s.roguelike.active(s) and s.RogueBuild.gear(p,56) else 1.0),15)

static func safe_point(s, at: Vector2) -> Vector2:
	if s.ruins.has_method("safe_point"): return s.ruins.safe_point(at)
	if not s.ruins.blocked(at,26): return at
	for radius in [40,80,120]:
		for i in 12:
			var candidate: Vector2=at+Vector2.from_angle(i*TAU/12)*radius
			if not s.ruins.blocked(candidate,26): return candidate
	return at
