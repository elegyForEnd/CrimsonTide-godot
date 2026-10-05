extends RefCounted
## Attack semantics are captured at emission; floor alone never selects an attack.
static func family(move: String, floor_index: int) -> int:
	if move in ["heal","sacrifice_heal","repair"]: return 8
	if move in ["shield","guard","counter","ward","haste","armor","speed","power","summon","decoy"]: return 9
	if move in ["breath","mines","throw"] and floor_index==1: return 1
	if move in ["roots","fissure"]: return 4
	if move in ["mist","trap"]: return 5
	if move in ["marks","feathers"]: return 2
	if move in ["vortex","boomerang","parallel"]: return 3
	if move in ["rifts","meteors"]: return 6
	if move in ["roar","bash","jump","ring","burst","wave"]: return 7
	if move in ["sweep","combo","triple","shadow_combo","dash","return_dash","berserk","blink","sidestep"]: return 0
	return [4,1,10,2,11][clampi(floor_index,0,4)]

static func style(move: String, floor_index: int) -> String:
	return ["spark","ember","electric","water","stone","soul","star","dust","star","star","ice","soul"][family(move,floor_index)]

static func mote_texture() -> Texture2D:
	return load("res://assets/combat/particles/mote.png")

static func projectile(target: CanvasItem, at: Vector2, aim: Vector2, floor_index: int, move: String, clock: float) -> void:
	var color: Color=[Color("6cedce"),Color("ff9b56"),Color("bfa1ff"),Color("83dcff"),Color("ff638a")][clampi(floor_index,0,4)]
	target.draw_set_transform(at,aim.angle())
	var kind := family(move,floor_index)
	if move=="throw":
		target.draw_circle(Vector2.ZERO,6,Color(color,.65))
		target.draw_arc(Vector2.ZERO,8,0,TAU,20,Color(color,.4),1,true)
	elif kind==2:
		target.draw_polyline(PackedVector2Array([Vector2(-19,1),Vector2(-11,-3),Vector2(-6,3),Vector2(3,-2),Vector2(9,0)]),color,2,true)
	elif kind==3:
		target.draw_arc(Vector2.ZERO,9,-1.1,1.1,18,Color(color,.85),2,true)
		target.draw_line(Vector2(-18,0),Vector2(5,0),Color(color,.3),1,true)
	elif kind==10:
		target.draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(-6,-4),Vector2(-2,0),Vector2(-6,4)]),color)
	elif kind==1:
		for i in 3:
			var y := sin(clock*12+i*2)*2
			target.draw_line(Vector2(-18-i*3,y),Vector2(5-i*2,0),Color(color,.25+i*.16),float(5-i),true)
	else:
		target.draw_line(Vector2(-16,0),Vector2(6,0),Color(color,.5),3,true)
		target.draw_circle(Vector2(5,0),3,Color(color,.85))
	target.draw_set_transform(Vector2.ZERO)

static func reward(target: CanvasItem, at: Vector2, tone: Color, progress: float, clock: float, opening: bool) -> void:
	var fade := smoothstep(0,.10,progress)*(1.0-smoothstep(.35,1.0,progress)) if opening else .32
	var height := 65.0+progress*65 if opening else 72.0
	for i in 5:
		var width := 3.0+i*4
		target.draw_line(at,at-Vector2(0,height),Color(tone,fade*.045),width,true)
	for i in 9:
		var phase := fposmod(clock*.55+i*.113,1)
		var point := at+Vector2(sin(i*2.4)*24,-phase*height)
		target.draw_circle(point,1.0+(i%3)*.4,Color(tone,fade*sin(phase*PI)))
