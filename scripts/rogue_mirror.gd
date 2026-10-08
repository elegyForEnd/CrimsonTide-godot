extends RefCounted
## A real, telegraphed enemy encounter. All state lives in the enemy snapshot.
const Catalog = preload("res://scripts/catalog.gd")

static func setup(s, p: Dictionary, at: Vector2) -> Dictionary:
	var floor_index := maxi(1,int(s.raid.floor))
	var health := 160.0+floor_index*65.0
	var e := {"id":s.next_enemy,"p":at,"home":at,"type":0,"hp":health,"max_hp":health,
		"last":int(p.id),"rogue_minion":true,"rogue_mirror":true,"rogue_skin":floor_index-1,
		"rogue_variant":0,"rogue_radius":18.0,"rogue_name":"镜像 · "+str(p.name),
		"hero":int(p.hero),"weapon":int(p.weapon),"mirror_owner":int(p.id),
		"mirror_damage":clampf(s.weapon_damage(p)*.65,12.0,35.0+floor_index*5.0),
		"mirror_speed":150.0+floor_index*8.0,"mirror_cursor":0,"cd":1.0,
		"facing":1.0,"motion_phase":0.0,"moving":false,"flash":0.0,"poise":0.0,
		"attack_time":0.0,"attack_total":.75,"attack_released":false,"attack_aim":Vector2.RIGHT,
		"attack_point":at,"minion_skill":0,"minion_windup":.75,"build_xp_reward":0,
		"damage_scale":1.0,"speed_scale":1.0}
	s.next_enemy+=1
	s.enemies.append(e)
	return e

static func update(s, combat, e: Dictionary, dt: float) -> void:
	e.flash=maxf(0,float(e.flash)-dt)
	e.moving=false
	var target: Dictionary=combat.nearest(s,e)
	if target.is_empty(): return
	if float(e.attack_time)>0:
		e.attack_time=maxf(0,float(e.attack_time)-dt)
		if float(e.attack_time)<=0:
			e.attack_released=true
			e.cd=1.2
		return
	e.cd=maxf(0,float(e.cd)-dt)
	var family := Catalog.weapon_family(int(e.weapon))
	var distance: float=e.p.distance_to(target.p)
	var reach := 290.0 if family==0 else 110.0
	if distance>reach or float(e.cd)>0:
		if distance>reach*.8:
			combat.move_towards(s,e,(target.p-e.p).normalized(),float(e.mirror_speed)*dt)
		return
	e.attack_aim=(target.p-e.p).normalized()
	e.facing=-1.0 if e.attack_aim.x<0 else 1.0
	e.attack_point=target.p
	e.attack_total=.9 if family==2 else .75
	e.attack_time=e.attack_total
	e.attack_released=false
	e.mirror_cursor+=1
	# Every third cast imitates a weapon art; aim is locked during the warning.
	if int(e.mirror_cursor)%3==0:
		combat.zone(e,"circle",target.p,70.0,float(e.attack_total),.2,float(e.mirror_damage)*1.2)
	elif family==0:
		combat.zone(e,"line",e.p,20.0,float(e.attack_total),.2,float(e.mirror_damage),e.attack_aim,0,e.p+e.attack_aim*360)
	else:
		combat.zone(e,"cone",e.p,125.0 if family==2 else 100.0,float(e.attack_total),.2,float(e.mirror_damage),e.attack_aim)
