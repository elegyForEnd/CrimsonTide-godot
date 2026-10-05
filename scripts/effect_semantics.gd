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

## Enemy shots in the mirror realm are hand-drawn vectors, not PNGs, so their
## readability is only these numbers.  They were tuned against an 18px sweep
## (session.gd hit_radius) and read as hairlines beside it; the multipliers below
## grow the same silhouettes until the widest body and the two solid dots sit
## inside that sweep, and the halo only ever spills outside it at low alpha.
const SHOT_SCALE := 2.0
const SHOT_HALO := 0.22
## The deep-abyss variants ("fog" +25%, "surge" +10%) reach these vectors as the
## bullet's `bullet_visual`.  Absent means 1.0, and the bounds match
## RogueCombat.BULLET_VISUAL_BOUNDS: a mirrored shot can grow, never shrink.
const SHOT_VISUAL_MIN := 1.0
const SHOT_VISUAL_MAX := 3.0

## The bolt's presentation-only size factor, read from the same key every other
## draw path reads: 1.0 whenever the field is absent.
static func visual_of(source: Dictionary) -> float:
	return clampf(float(source.get("bullet_visual",1.0)),SHOT_VISUAL_MIN,SHOT_VISUAL_MAX)

## The same silhouette at the readability scale, as a typed vertex list.
static func shot(points: Array, scale: float = SHOT_SCALE) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in points: scaled.append(point*scale)
	return scaled

static func projectile(target: CanvasItem, at: Vector2, aim: Vector2, floor_index: int, move: String, clock: float,
		visual: float = 1.0) -> void:
	var color: Color=[Color("6cedce"),Color("ff9b56"),Color("bfa1ff"),Color("83dcff"),Color("ff638a")][clampi(floor_index,0,4)]
	target.draw_set_transform(at,aim.angle())
	var kind := family(move,floor_index)
	# One unit drives every dimension, so a variant bolt is the same silhouette
	# at a larger size rather than a differently shaped one.
	var unit := SHOT_SCALE*visual
	# Every mirrored shot arrives inside the same soft shell, so the five floor
	# palettes stay distinguishable without any of them reading as a stray spark.
	target.draw_circle(Vector2(-4,-2)*unit,17.0*unit,Color(color,SHOT_HALO*0.45))
	target.draw_circle(Vector2(4,2)*unit,11.0*unit,Color(color,SHOT_HALO))
	if move=="throw":
		target.draw_circle(Vector2.ZERO,14.0*visual,Color(color,.72))
		target.draw_arc(Vector2.ZERO,18.0*visual,0,TAU,28,Color(color,.5),3.0*visual,true)
	elif kind==2:
		target.draw_polyline(shot([Vector2(-19,1),Vector2(-11,-3),Vector2(-6,3),Vector2(3,-2),Vector2(9,0)],unit),
			color,4.0*visual,true)
	elif kind==3:
		target.draw_arc(Vector2.ZERO,18.0*visual,-1.1,1.1,18,Color(color,.85),4.0*visual,true)
		target.draw_line(Vector2(-18,0)*unit,Vector2(5,0)*unit,Color(color,.3),2.0*visual,true)
	elif kind==10:
		target.draw_colored_polygon(shot([Vector2(10,0),Vector2(-6,-4),Vector2(-2,0),Vector2(-6,4)],unit),color)
	elif kind==1:
		for i in 3:
			var y := sin(clock*12+i*2)*4*visual
			target.draw_line(Vector2(-18-i*3,y)*unit,Vector2(5-i*2,0)*unit,Color(color,.25+i*.16),float(10-i*2)*visual,true)
	else:
		target.draw_line(Vector2(-16,0)*unit,Vector2(6,0)*unit,Color(color,.55),6.0*visual,true)
		target.draw_circle(Vector2(5,0)*unit,6.0*visual,Color(color,.9))
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
