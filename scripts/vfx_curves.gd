extends RefCounted
## Independent flash, material and wake envelopes. Original timings for this
## game's immediate contacts; local reference findings are in docs/lol-vfx-study.md.

static func envelope(age: float, life: float, layer: String="body", kind: String="slash") -> float:
	if age<=0 or age>=life or life<=0: return 0.0
	var t := clampf(age/life,0,1)
	var birth := smoothstep(0.0,minf(.008,life*.08),age)
	if layer=="flash":
		return birth*pow(1.0-smoothstep(.012,minf(.085,life*.65),age),2)
	if layer=="wake":
		return smoothstep(0.0,.025,age)*pow(1.0-t,1.8)
	# A fast readable apex followed by a low-energy material tail. Long spells
	# retain their silhouette longer than short melee contacts.
	var knee := .26 if kind in ["detonation","blessing","soul"] else .18
	var settle := 1.0-.35*smoothstep(.12,knee,t)
	return birth*settle*(1.0-smoothstep(knee,1.0,t))

static func weapon_envelope(age: float, life: float, design: Dictionary, layer: String, kind: String) -> float:
	if design.is_empty() or kind=="charge": return envelope(age,life,layer,kind)
	if age<=0 or age>=life or life<=0: return 0.0
	var timing: Dictionary=design.attack
	var t := clampf(age/life,0,1)
	var birth := smoothstep(0.0,minf(.008,life*.08),age)
	var peak := clampf(float(timing.peak),.07,.28)
	if layer=="flash":
		var end := minf(.085,maxf(.028,life*(peak+.12)))
		return birth*pow(1-smoothstep(.008,end,age),1.4)
	if layer=="wake": return envelope(age,life,"wake",kind)
	var settle := 1.0-.32*smoothstep(peak,peak+.18,t)
	return birth*settle*(1-smoothstep(peak,1.0,t))

static func tapered_segment(target: CanvasItem, a: Vector2, b: Vector2,
		width_a: float, width_b: float, color_a: Color, color_b: Color) -> void:
	if a.distance_squared_to(b)<.0001: return
	var normal := (b-a).normalized().orthogonal()
	target.draw_polygon(PackedVector2Array([a+normal*width_a*.5,b+normal*width_b*.5,
		b-normal*width_b*.5,a-normal*width_a*.5]),PackedColorArray([color_a,color_b,color_b,color_a]))

static func contact(target: CanvasItem, radius: float, age: float, life: float,
		color: Color, glow: bool) -> void:
	var flash := envelope(age,life,"flash","impact")
	var body := envelope(age,life,"body","impact")
	var t := clampf(age/maxf(.001,life),0,1)
	# The directional streak owns the contact. A tiny hot core dies first;
	# the colored pressure slash moves forward and breaks apart afterwards.
	var center := Vector2(radius*t*.24,0)
	var gain := .24 if glow else 1.0
	var edge := Color(color,body*.75*gain)
	var hot := Color(color.lerp(Color.WHITE,.82),flash*gain)
	var length := radius*(.72-.38*t)
	target.draw_polygon(PackedVector2Array([center-Vector2(length*.45,0),
		center-Vector2(0,radius*.12*body),center+Vector2(length,0),
		center+Vector2(0,radius*.12*body)]),PackedColorArray([Color(edge,0),edge,hot,edge]))
	if flash>.001:
		target.draw_circle(center,radius*.075*flash,hot)
		for side in [-1,1]:
			tapered_segment(target,center,center+Vector2(radius*.14,side*radius*.36*flash),
				radius*.055*flash,0.0,hot,Color(hot,0))
	if t>.14:
		for i in 3:
			var dir := Vector2.from_angle(-.75+i*.75)
			var end := dir*radius*(.18+t*.58)
			tapered_segment(target,end-dir*radius*.16*(1-t),end,
				maxf(.2,radius*.025*(1-t)),0.0,Color(edge,edge.a*.65),Color(edge,0))
