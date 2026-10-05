extends RefCounted
## Effects describe a source and a motion; encounter emblems are never attacks.
const Art=preload("res://scripts/boss_effect_art.gd")
const PHYSICAL := ["pendulum","fracture","bramble","seed","root","roots","sabres","crown","hands","ribcage","tomb","frame","censer","moths","drop","plate","stalactite","icicle","spore","bloom","hammer","kiln","prism","starfall","rain","rivets"]
static func body_allowed(key: String, role: String, shape: String, construct: bool=false) -> bool:
	if construct: return role in PHYSICAL or role=="echo"
	if shape in ["lane","line","ring","gap_ring","arc"]: return false
	if key in ["storm","wing"]: return shape=="capsule"
	return role in PHYSICAL or shape=="capsule" or (shape=="cone" and role in ["slash","scar","wings","maw"])

static func sprite_role(key: String, role: String, shape: String, move: String="") -> String:
	if key=="furnace" and role=="kiln": return "ground_vent"
	if key in ["storm","wing"] and shape=="capsule": return "electric_bolt"
	if key in ["storm","wing"] and shape=="circle" and role in ["chain","return"]: return "thunder_impact"
	if shape=="circle" and (role=="pyre" or (key=="furnace" and (move.contains("熔井") or move.contains("过载")))): return "flame_vent"
	return role

static func stream_style(key: String, role: String) -> int:
	if key=="storm": return 1
	if role in ["chain","thread","score"]: return 5
	if key in ["ember","dragon","furnace"]: return 2
	if key in ["wing","abyss"]: return 3
	if key in ["earth","thorn","grove"]: return 4
	return 0

static func particle_style(key: String) -> String:
	if key=="wing": return "electric"
	if key=="obsidian": return "spark"
	return ""

static func construct_health_lift(prop: Dictionary) -> float:
	return 25.0 if prop.get("art_key","")=="furnace" and prop.get("vfx_role","")=="kiln" else 85.0

## Small, attached preparation / collapse. No random attack PNG orbiting the boss.
static func actor(target: CanvasItem, key: String, at: Vector2, aim: Vector2, action: String, age: float, life: float) -> void:
	var t := clampf(age/maxf(life,.001),0,1)
	var envelope := smoothstep(0,.09,age)*(1-smoothstep(.72,1,t))
	if action=="charge": envelope=smoothstep(0,.14,age)*(.3+.7*t)
	var color := Color(Art.color({"art_key":key}),envelope*.65)
	var ground := at
	var chest := at-Vector2(0,48)
	if action=="fall":
		for i in 7:
			var offset := Vector2((i-3)*5,-30-35*t+(i%3)*9)
			target.draw_line(chest+offset,chest+offset+Vector2(0,9),Color(color,color.a*(1-t)),1,true)
		return
	if key in ["storm","wing"]:
		for i in 3:
			var start := chest+Vector2((i-1)*20,-4)
			var end := chest+Vector2((i-1)*29,15)
			var bend := sin(floor(age*15)+i*7)*4
			target.draw_polyline(PackedVector2Array([start,start.lerp(end,.3)+Vector2(bend,0),start.lerp(end,.7)-Vector2(bend,0),end]),color,1.4,true)
	elif key in ["ember","furnace"]:
		for i in 5:
			var x := (i-2)*7.0
			var h := 12+(sin(age*9+i)*.5+.5)*21
			target.draw_polyline(PackedVector2Array([chest+Vector2(x,17),chest+Vector2(x+sin(age*7+i)*4,0),chest+Vector2(x*.7,-h)]),color,2,true)
	elif key in ["knight","queen","obsidian"]:
		var hand := chest+aim*24
		target.draw_line(hand,hand+aim*(20+12*t),color,2,true)
		target.draw_line(hand-aim.orthogonal()*5,hand+aim.orthogonal()*5,Color(color,color.a*.5),1,true)
	elif key in ["earth","thorn","grove","dragon"]:
		for i in 4:
			var base := ground+Vector2((i-1.5)*19,0)
			var end := base+Vector2(sin(i*3.1)*8,-8-16*t)
			target.draw_line(base,end,color,1.5,true)
	elif key in ["mirror","astral"]:
		for i in 3:
			var p := chest+Vector2((i-1)*20,-12+i%2*9)
			target.draw_polyline(PackedVector2Array([p+Vector2(-4,0),p+Vector2(0,-7),p+Vector2(4,0),p+Vector2(0,7),p+Vector2(-4,0)]),color,1,true)
	elif key=="bell":
		for i in 2: target.draw_arc(chest,17+i*9,-.65, .65,20,Color(color,color.a*.6),1,true)
	elif key=="abyss":
		for i in 3: target.draw_arc(ground+Vector2(0,-i*3),20+i*9,.15,PI-.15,24,Color(color,color.a*.5),1,true)
	else:
		for i in 4:
			var p := chest+Vector2((i-1.5)*11,-fposmod(age*24+i*12,35))
			target.draw_line(p,p+Vector2(0,7),color,1,true)
