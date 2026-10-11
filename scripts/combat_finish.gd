extends Node2D
## Shared presentation: contact, airborne fragments, dust, residual energy and
## sampled real projectile wakes. Never creates targets, projectiles or damage.
const MAX_CONTACTS := 64
const MAX_TRAILS := 96
const Weapon = preload("res://scripts/weapon_vfx.gd")
const ATLAS = preload("res://assets/combat/finish/impact-atlas-v1.png")
var contacts: Array[Dictionary]=[]
var trails: Dictionary={}
var marks: Dictionary={}
var clock := 0.0
var projector: Callable
var glow: Node2D
var lights: Callable

func _ready() -> void:
	material=CanvasItemMaterial.new()
	glow=Node2D.new(); add_child(glow)
	var mat := CanvasItemMaterial.new(); mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	glow.material=mat; glow.draw.connect(func(): draw_layer(glow,true))

func reset() -> void:
	contacts.clear(); trails.clear(); marks.clear(); clock=0
	queue_redraw()
	if glow: glow.queue_redraw()

static func element(profile: Dictionary) -> int:
	match str(profile.get("motif","")):
		"blood": return 2
		"frost","mirror": return 3
		"ember","sun": return 4
		"soul","void","moon","feather": return 5
	return 0

func event(data: Dictionary) -> void:
	var kind: String=data.get("kind","")
	if kind not in ["impact","spell_burst","spell_arc","spell_beam","skill","story_skill"]: return
	if kind=="impact" and float(data.get("damage",1))<=0: return
	var key := "%s:%s" % [data.get("id",-1),data.get("enemy_id",data.get("p",Vector2.ZERO))]
	if kind=="impact":
		if clock-float(marks.get(key,-10))<.075: return
		marks[key]=clock
	var profile := Weapon.profile(int(data.get("weapon_index",data.get("weapon",1))))
	var p: Vector2=data.p
	var aim: Vector2=Vector2(data.get("aim",Vector2.RIGHT)).normalized()
	var heavy: bool=data.get("heavy",false)
	var radius := float(data.get("radius",36 if heavy else 24))
	var col: Color=profile.color
	if data.has("tone"): col=data.tone
	var fx := {"p":p,"aim":aim,"age":0.0,"life":.65 if kind=="impact" else .88,
		"cell":element(profile),"color":col,"radius":clampf(radius,12,670),"kind":kind,
		"lift":float(data.get("height",0)),"heavy":heavy,"seed":contacts.size()*2.39996,
		"end":Vector2(data.get("target",p+aim*float(data.get("reach",200)))),
		"contact":data.get("contact_p",p-Vector2(0,24)),"contact_lift":float(data.get("contact_lift",0)),"cone":float(data.get("cone",PI))}
	if contacts.size()>=MAX_CONTACTS: contacts.pop_front()
	contacts.append(fx)
	if lights.is_valid(): lights.call(p,col,1.15 if heavy or kind!="impact" else .5,.18 if kind=="impact" else .34)

func observe(bullets: Array, dt: float) -> void:
	var seen := {}
	for bullet in bullets:
		if not bullet.has("weapon_index"): continue
		var key: Variant=bullet.get("fx_id",null)
		if key==null: continue # Stable authoritative identity, never array position.
		seen[key]=true
		var p: Vector2=bullet.p
		if not trails.has(key):
			if trails.size()>=MAX_TRAILS: continue
			trails[key]={"points":[],"credit":0.0,"color":Weapon.profile(int(bullet.weapon_index)).color,
				"lift":float(bullet.get("height",0)),"gone":0.0}
		var trail: Dictionary=trails[key]
		trail.credit+=dt
		if not trail.points.is_empty() and p.distance_to(trail.points.back().p)>600: trail.points.clear()
		if trail.credit>=.016:
			trail.credit=fmod(float(trail.credit),.016)
			trail.points.append({"p":p,"at":clock})
			if trail.points.size()>10: trail.points.pop_front()
	for key in trails.keys():
		var trail: Dictionary=trails[key]
		while not trail.points.is_empty() and clock-float(trail.points[0].at)>.13: trail.points.pop_front()
		if not seen.has(key):
			trail.gone+=dt
			if trail.gone>.15: trails.erase(key)

func advance(dt: float) -> void:
	clock+=dt
	for i in range(contacts.size()-1,-1,-1):
		contacts[i].age+=dt
		if contacts[i].age>=contacts[i].life: contacts.remove_at(i)
	for key in marks.keys():
		if clock-float(marks[key])>1.0: marks.erase(key)
	queue_redraw()
	if glow: glow.queue_redraw()

func projected(p: Vector2) -> Vector2:
	return get_global_transform()*Vector2(projector.call(p)) if projector.is_valid() else get_global_transform()*p

func stamp(target: CanvasItem, cell: int, p: Vector2, extent: Vector2, angle: float, tint: Color) -> void:
	var ink := Rect2(Vector2(cell%3,cell/3)*Vector2(418,627),Vector2(418,627))
	# Atlas authored with portrait cells. Fit naturally, do not stretch splinters.
	var fit := ink.size*minf(extent.x/ink.size.x,extent.y/ink.size.y)
	target.draw_set_transform_matrix(target.get_global_transform().affine_inverse()*Transform2D(angle,p))
	target.draw_texture_rect_region(ATLAS,Rect2(-fit*.5,fit),ink,tint)
	target.draw_set_transform(Transform2D.IDENTITY.origin)

func draw_layer(target: CanvasItem, additive: bool) -> void:
	if absf(target.get_global_transform().determinant())<.000001: return
	var inverse := target.get_global_transform().affine_inverse()
	for fx in contacts:
		var t: float=fx.age/fx.life
		var color := Color(fx.color)
		var at := projected(fx.p)-Vector2(0,float(fx.lift))
		var contact := projected(fx.contact)-Vector2(0,float(fx.lift)+float(fx.contact_lift))
		var radius: float=fx.radius
		if fx.kind=="impact":
			var kick := (1.0-smoothstep(.015,.11,float(fx.age)))*smoothstep(0,.008,float(fx.age))
			if kick>.001: stamp(target,0,contact,Vector2.ONE*radius*2.8,fx.aim.angle()+fx.seed*.11,Color(1,1,1,kick*(.3 if additive else .85)))
			if not additive:
				stamp(target,1,at+Vector2(0,-t*17),Vector2.ONE*radius*(1.5+t*2),fx.seed,Color(.56,.52,.49,sin(t*PI)*.16))
				if fx.cell!=0: stamp(target,fx.cell,contact+Vector2(0,-t*11),Vector2.ONE*radius*(1.8+t*.6),fx.seed*.4,Color(1,1,1,pow(1-t,2)*.65))
			# Separate chips use ballistic motion and tapered streaks, not a second stamp.
			for i in (11 if fx.heavy else 6):
				var direction := Vector2.from_angle(float(fx.seed)+i*2.39996)
				var velocity := direction*(42+i*7)
				var end := contact+velocity*float(fx.age)+Vector2(0,90*fx.age*fx.age)
				var tail := end-velocity*.022*(1-t)
				var c := color.lerp(Color("fff0ce"),.35); c.a=pow(1-t,2)*(.27 if additive else .7)
				target.draw_line(inverse*tail,inverse*end,c,1.4 if fx.heavy else .9,true)
		elif fx.kind in ["spell_arc","spell_beam"]:
			var end := projected(fx.end)-Vector2(0,24+float(fx.lift))
			var start := at-Vector2(0,24)
			var points := PackedVector2Array()
			var delta := end-start
			for i in 13:
				var u := i/12.0
				var jag := sin(u*PI)*sin(i*2.1+floorf(fx.age*24)*1.7)*5*(1-t)
				points.append(inverse*(start+delta*u+delta.normalized().orthogonal()*jag))
			color.a=pow(1-t,2)*(.3 if additive else .7)
			if points.size()>1: target.draw_polyline(points,color,1.5 if additive else .9,true)
		else:
			# A broken pressure front on the ground, constrained to the true footprint.
			var sweep := minf(1.0,float(fx.age)/.20)
			var front := radius*(.14+.86*sweep)
			for band in 3:
				var points := PackedVector2Array()
				var opening: float=fx.cone/3*.75
				var start: float=fx.aim.angle()-fx.cone*.5+fx.cone*band/3.0
				for i in 25: points.append(inverse*projected(fx.p+Vector2.from_angle(start+opening*i/24)*front))
				color.a=pow(1-t,2)*(.13 if additive else .36)
				target.draw_polyline(points,color,2.4 if additive else 1.2,true)
			if not additive:
				stamp(target,fx.cell,at-Vector2(0,18+20*t),Vector2.ONE*minf(210,radius)*(.55+t*.7),fx.seed,Color(1,1,1,pow(1-t,1.8)*.58))
	for trail in trails.values():
		var points: Array=trail.points
		for i in range(1,points.size()):
			var fade := maxf(0,1-(clock-float(points[i].at))/.13)*i/points.size()
			var col := Color(trail.color,fade*(.16 if additive else .32))
			var a := projected(points[i-1].p)-Vector2(0,float(trail.lift))
			var b := projected(points[i].p)-Vector2(0,float(trail.lift))
			target.draw_line(inverse*a,inverse*b,col,3.0 if additive else 1.2,true)

func _draw() -> void: draw_layer(self,false)
