class_name Ecology
extends RefCounted

# Each site is a habitat block, clipped to its actual biome polygon.
const POOLS := [[0,5],[1,6],[7,11,14],[2,3,8],[9,12,15],[10,13,16]]
# Stable habitat palette per species. Keeping this with the spawn pools avoids a
# colour jump if a monster briefly crosses a polygon boundary while pursuing.
const BIOMES := [0,1,3,3,1,0,1,2,3,4,5,2,4,5,2,4,5]
const HEALTH := [58.0,42.0,125.0,310.0,1800.0,55.0,82.0,150.0,115.0,95.0,210.0,185.0,120.0,260.0,680.0,590.0,760.0]
const WINDUP := [0.26,0.42,0.56,0.32,0.85,0.65,0.85,0.8,1.0,1.1,0.9,0.9,1.0,1.05,1.35,1.25,1.45]
const RADIUS := [19.0,19.0,25.0,27.0,31.0,19.0,21.0,24.0,22.0,22.0,27.0,29.0,24.0,31.0,42.0,44.0,43.0]
const RESIDENTS := ["食尸兔 · 丧钟蛾","哀钟灵 · 禁卷枭","骨鹿 · 石像鬼 · 月碑巨像","刑偶 · 灾狐 · 血棘妖","冥水母 · 溺钟灵 · 沉钟巨骸","腐羽狮鹫 · 刽子手 · 血棺守卫"]
const TRAITS := ["食尸兔 / 丧钟蛾 · 散射","哀钟灵 / 禁卷枭 · 三连咒","骨鹿 / 石像鬼 / 巨像 · 冲锋与晶脉","刑偶 / 灾狐 / 血棘妖 · 地刺","冥水母 / 溺钟灵 / 巨骸 · 回旋钟波","腐羽狮鹫 / 刽子手 / 血棺 · 轰击"]

static func block_at(world, pos: Vector2) -> int:
	for i in world.sites.size():
		var site: Dictionary=world.sites[i]
		if site.rect.grow(170).has_point(pos) and world.biome_at(pos)==int(site.biome):
			return i
	return -1

static func allowed(world, pos: Vector2, kind: int) -> bool:
	var block := block_at(world,pos)
	return block>=0 and kind in POOLS[int(world.sites[block].biome)]

static func difficulty(site: Dictionary) -> int:
	return clampi(int([1,1,2,2,2,3][int(site.biome)])+int(site.tier)-1,1,4)

static func reward_label(site: Dictionary) -> String:
	return ["","绿色","蓝色","紫色","金色"][difficulty(site)]+"清剿宝箱"

static func remaining(s, block: int) -> int:
	var count := 0
	for e in s.enemies:
		if int(e.get("habitat",-1))==block and e.hp>0: count+=1
	return count

static func site_status(s, block: int) -> String:
	var site: Dictionary=s.ruins.sites[block]
	if site.get("cleared",false): return "已清理 · 奖励已生成"
	return "%s · 守军 %d · %s" % ["交战中" if site.get("engaged",false) else "难度 %d" % difficulty(site),remaining(s,block),reward_label(site)]

static func random_kind(pool: Array, rng: RandomNumberGenerator) -> int:
	var regular: Array=pool.filter(func(kind: int): return kind<14)
	if pool.size()>regular.size() and rng.randf()<0.16:
		return int(pool[-1])
	return int(regular[rng.randi_range(0,regular.size()-1)])

static func update(s, e: Dictionary, dt: float) -> void:
	var kind: int=e.type
	e.flash=maxf(0,float(e.get("flash",0))-dt)
	e["stagger"]=maxf(0,float(e.get("stagger",0))-dt)
	e.moving=false
	e.cd=maxf(0,e.cd-dt)
	if e.stagger>0:
		e.attack_time=0.0
		return
	var before: Vector2=e.p
	if e.attack_time>0:
		e.attack_time=maxf(0,e.attack_time-dt)
		var elapsed: float=e.attack_total-e.attack_time
		if kind==11:
			# The dive is a swept ground path to a locked point, never a teleport.
			var advance: float=maxf(0,minf(elapsed,WINDUP[kind]+0.48)-maxf(elapsed-dt,WINDUP[kind]))
			var velocity: Vector2=(e.attack_point-e.attack_start)/0.48
			while advance>0:
				var step := minf(advance,0.02)
				e.p=s.ruins.move(e.p,velocity*step)
				advance-=step
			if elapsed>=WINDUP[kind]+0.48 and not e.attack_released:
				e.attack_released=true
				for p in s.players.values():
					if p.status=="active" and p.p.distance_to(e.p)<60 and s.ruins.clear_line(e.p,p.p): s.hurt(p,26)
				s.emit_effect("seal",e.p)
		elif kind==7 and elapsed>=WINDUP[kind] and elapsed-dt<WINDUP[kind]+0.42:
			var advance: float=maxf(0,minf(elapsed,WINDUP[kind]+0.42)-maxf(elapsed-dt,WINDUP[kind]))
			while advance>0:
				var step := minf(advance,0.02)
				e.p=s.ruins.move(e.p,e.attack_aim*560*step)
				advance-=step
			for p in s.players.values():
				if not e.attack_released and p.status=="active" and Geometry2D.get_closest_point_to_segment(p.p,before,e.p).distance_to(p.p)<40 and s.ruins.clear_line(e.p,p.p):
					s.hurt(p,24)
					e.attack_released=true
		elif kind==6:
			# Three timed bolts keep the original aim; no tracking after windup.
			for shot in 3:
				if elapsed>=WINDUP[kind]+shot*0.18 and int(e.get("shots",0))==shot:
					bolt(s,e,e.attack_aim.rotated((shot-1)*0.13),300,12)
					e.shots=shot+1
					e.attack_released=true
		elif not e.attack_released and elapsed>=WINDUP[kind]:
			e.attack_released=true
			if kind==5:
				for angle in [-0.28,0.0,0.28]: bolt(s,e,e.attack_aim.rotated(angle),230,10)
			elif kind==9:
				for n in 8: bolt(s,e,Vector2.from_angle(n*TAU/8+e.attack_aim.angle()),170,14)
			elif kind==12:
				for angle in [-0.5,-0.25,0.0,0.25,0.5]:
					s.bullets.append({"p":e.p,"v":e.attack_aim.rotated(angle)*260,"life":1.55,"damage":15.0,"owner":0,"return_after":0.75,"age":0.0,"reversed":false,"enemy_type":12})
			elif kind==13:
				for p in s.players.values():
					var delta: Vector2=p.p-e.p
					if p.status=="active" and delta.length()<190 and absf(e.attack_aim.angle_to(delta))<1.05 and s.ruins.clear_line(e.p,p.p): s.hurt(p,32)
			elif kind==14:
				for p in s.players.values():
					if p.status=="active" and p.p.distance_to(e.p)<135 and s.ruins.clear_line(e.p,p.p): s.hurt(p,34)
				for n in 12: bolt(s,e,Vector2.from_angle(n*TAU/12),185,18)
				s.emit_effect("seal",e.p)
			elif kind==15:
				for n in 16: bolt(s,e,Vector2.from_angle(n*TAU/16+e.attack_aim.angle()),155,20)
			elif kind==16:
				for p in s.players.values():
					if p.status=="active" and p.p.distance_to(e.attack_point)<145 and s.ruins.clear_line(e.p,p.p): s.hurt(p,40)
				s.emit_effect("seal",e.attack_point)
			elif kind in [8,10]:
				var radius := 76.0 if kind==8 else 100.0
				for p in s.players.values():
					if p.status=="active" and p.p.distance_to(e.attack_point)<radius and s.ruins.clear_line(e.p,p.p): s.hurt(p,19 if kind==8 else 28)
				s.emit_effect("seal",e.attack_point)
	else:
		var target: Dictionary={}
		var distance := 470.0
		for p in s.players.values():
			if p.status=="active" and e.p.distance_to(p.p)<distance:
				target=p
				distance=e.p.distance_to(p.p)
		if not target.is_empty():
			var direction: Vector2=(target.p-e.p).normalized()
			if absf(direction.x)>0.05: e.facing=signf(direction.x)
			var reach := 280.0 if kind==7 else 340.0
			if kind==11: reach=260.0
			elif kind==12: reach=210.0
			elif kind==13: reach=185.0
			elif kind==14: reach=145.0
			elif kind==15: reach=285.0
			elif kind==16: reach=230.0
			if distance<reach and e.cd<=0 and s.ruins.clear_line(e.p,target.p):
				e.attack_total=WINDUP[kind]+(0.9 if kind>=14 else (0.75 if kind==11 else 0.6))
				e.attack_time=e.attack_total
				e.attack_aim=direction
				e["attack_point"]=target.p
				e["attack_start"]=e.p
				e.attack_released=false
				e["shots"]=0
				e.cd=e.attack_total+1.25
			elif distance>reach-40:
				var speed := 48.0 if kind>=14 else (110.0 if kind==7 else 76.0)
				e.p=s.ruins.move(e.p,direction*speed*dt,RADIUS[kind])
			elif distance<130 and kind in [5,6,9,12]:
				e.p=s.ruins.move(e.p,-direction*55*dt)
	var travelled: float=e.p.distance_to(before)
	e.moving=travelled>0.01
	e.motion_phase+=travelled/12.0

static func bolt(s, e: Dictionary, direction: Vector2, speed: float, damage: float) -> void:
	s.bullets.append({"p":e.p,"v":direction*speed,"life":2.4,"damage":damage,"owner":0})
