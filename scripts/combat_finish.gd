extends Node2D
## Shared presentation: contact, airborne fragments, dust, residual energy and
## sampled real projectile wakes. Never creates targets, projectiles or damage.
const MAX_CONTACTS := 64
const MAX_TRAILS := 96
const TRAIL_LIFE := .22
const TRAIL_HISTORY_POINTS := 24
const Ribbon=preload("res://scripts/weapon_projectile_ribbon.gd")
const Weapon = preload("res://scripts/weapon_vfx.gd")
const Curves = preload("res://scripts/vfx_curves.gd")
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const ImageArt=preload("res://scripts/weapon_image_art.gd")
const DENSITY_SHADER=preload("res://resources/weapon_density.gdshader")
const ATLAS = preload("res://assets/combat/finish/impact-atlas-v1.png")
var contacts: Array[Dictionary]=[]
var trails: Dictionary={}
var marks: Dictionary={}
var clock := 0.0
var projector: Callable
var glow: Node2D
var lights: Callable
var mist: Node2D
var wakes: Node2D

func _ready() -> void:
	material=CanvasItemMaterial.new()
	wakes=Node2D.new(); wakes.name="ProjectileRibbons"; wakes.z_index=-1; add_child(wakes)
	mist=Node2D.new(); mist.name="ContactMist"; mist.z_index=-1; add_child(mist)
	glow=Node2D.new(); add_child(glow)
	var mat := CanvasItemMaterial.new(); mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	glow.material=mat; glow.draw.connect(func(): draw_layer(glow,true))

func reset() -> void:
	for contact in contacts: clear_mist(contact)
	for trail in trails.values(): clear_ribbon(trail)
	contacts.clear(); trails.clear(); marks.clear(); clock=0
	queue_redraw()
	if glow: glow.queue_redraw()

func clear_ribbon(trail: Dictionary) -> void:
	var node: Node2D=trail.get("ribbon",null)
	if not is_instance_valid(node): return
	if node.get_parent(): node.get_parent().remove_child(node)
	node.queue_free(); trail.erase("ribbon")

func sync_ribbon(trail: Dictionary) -> void:
	if not is_instance_valid(wakes): return
	if not is_instance_valid(trail.get("ribbon",null)):
		var node=Ribbon.new(); node.host=self; node.trail=trail
		trail["ribbon"]=node; wakes.add_child(node)
	trail.ribbon.sync()

func clear_mist(contact: Dictionary) -> void:
	var node: Node2D=contact.get("mist_node",null)
	if not is_instance_valid(node): return
	if node.get_parent(): node.get_parent().remove_child(node)
	node.queue_free()
	contact.erase("mist_node")

func add_mist(contact: Dictionary) -> void:
	if not is_instance_valid(mist) or contact.kind!="impact": return
	var node := Node2D.new()
	var shader_material := ShaderMaterial.new()
	shader_material.shader=DENSITY_SHADER
	node.material=shader_material
	contact["mist_node"]=node
	node.draw.connect(func(): draw_mist(node,contact))
	mist.add_child(node)
	sync_mist(contact)

func sync_mist(contact: Dictionary) -> void:
	var node: Node2D=contact.get("mist_node",null)
	if not is_instance_valid(node): return
	var state := mist_state(contact)
	var shader_material: ShaderMaterial=node.material
	shader_material.set_shader_parameter("effect_phase",state.phase)
	shader_material.set_shader_parameter("flow",float(contact.profile.flow))
	shader_material.set_shader_parameter("shear",float(contact.profile.shear))
	shader_material.set_shader_parameter("opacity_gain",1.0)
	node.visible=state.opacity>.0001
	node.queue_redraw()

func mist_state(contact: Dictionary) -> Dictionary:
	var profile: Dictionary=contact.profile
	var age := maxf(0,float(contact.age))
	var duration := clampf(float(profile.impact.decay)+.08,.18,.42)
	var phase := clampf(age/duration,0,1)
	var peak := clampf(float(profile.attack.lead),.02,.06)
	var envelope := smoothstep(0,peak,age)*(1-smoothstep(peak,duration,age))
	var radius := minf(28,maxf(8,float(contact.radius)*.60))
	var compression := float(profile.impact.compression)
	var extent := Vector2(radius*(.85+float(profile.spread)*.60)*(1+phase*.45),radius*(.42+(1-compression)*.34)*(1+phase*.65))
	var point := projected(contact.contact)-Vector2(0,float(contact.lift)+float(contact.contact_lift))
	var direction := (projected(contact.contact+contact.aim)-projected(contact.contact)).normalized()
	if direction.length_squared()<.001: direction=Vector2.RIGHT
	# Drift is screen-local and small: the actual contact anchor owns all height.
	point+=direction*radius*phase*.16-Vector2(0,phase*4)
	return {"phase":phase,"opacity":envelope*float(profile.smoke_gain)*.32,"extent":extent,
		"point":point,"angle":direction.angle()+float(profile.shear)*phase*.10,"duration":duration}

func draw_mist(target: CanvasItem, contact: Dictionary) -> void:
	if absf(target.get_global_transform().determinant())<.000001: return
	var state := mist_state(contact)
	if state.opacity<=.0001: return
	var texture := ImageArt.mechanic_texture(str(contact.profile.density_source))
	if texture==null: return # Missing density cannot become an opaque placeholder quad.
	var color := Color(contact.color).lerp(Color("8e929a"),.72)
	color.a=state.opacity
	var inverse := target.get_global_transform().affine_inverse()
	target.draw_set_transform_matrix(inverse*Transform2D(float(state.angle),state.point))
	var ink := ImageArt.mechanic_ink(str(contact.profile.density_source))
	if ink.size.x<=0 or ink.size.y<=0:
		target.draw_set_transform(Vector2.ZERO); return
	# Fit the measured visible density, retaining the unmodified padded source UV.
	var fit := minf(float(state.extent.x)/ink.size.x,float(state.extent.y)/ink.size.y)
	target.draw_texture_rect(texture,Rect2(-ink.get_center()*fit,texture.get_size()*fit),false,color)
	target.draw_set_transform(Vector2.ZERO)

static func trail_behavior(profile: Dictionary) -> Dictionary:
	var shape: Array={"blood":[.78,.55,1.45],"metal":[.48,1.20,2.45],"cloth":[.90,.45,1.45],
		"frost":[.62,.90,1.85],"storm":[.40,1.50,3.0],"tide":[1.0,.42,1.25],
		"stone":[.68,1.10,2.15],"feather":[.72,.68,1.55],"void":[.82,1.35,2.20],
		"bell":[.56,.72,1.70],"sun":[.66,.88,2.10],"star":[.58,1.0,1.95],
		"mirror":[.52,1.25,2.65],"soul":[.92,.48,1.20]}.get(str(profile.material),[.65,.85,1.8])
	return {"width":float(shape[0])*(.8+float(profile.spread)*.20),"taper":float(shape[1]),
		"decay":float(shape[2])+.15*float(profile.impact.compression)}

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
	var weapon_index := int(data.get("weapon_index",data.get("weapon",1)))
	var profile := Weapon.profile(weapon_index)
	var layers := Profiles.profile(weapon_index)
	var p: Vector2=data.p
	var aim: Vector2=Vector2(data.get("aim",Vector2.RIGHT)).normalized()
	var heavy: bool=data.get("heavy",false)
	var radius := float(data.get("radius",36 if heavy else 24))
	var col: Color=profile.color
	if data.has("tone"): col=data.tone
	var fx := {"p":p,"aim":aim,"age":0.0,"life":.65 if kind=="impact" else .88,
		"weapon_index":weapon_index,"profile":layers,
		"cell":element(profile),"color":col,"radius":clampf(radius,12,670),"kind":kind,
		"lift":float(data.get("height",0)),"heavy":heavy,"seed":contacts.size()*2.39996,
		"end":Vector2(data.get("target",p+aim*float(data.get("reach",200)))),
		"contact":data.get("contact_p",p-Vector2(0,24)),"contact_lift":float(data.get("contact_lift",0)),"cone":float(data.get("cone",PI))}
	if contacts.size()>=MAX_CONTACTS: clear_mist(contacts.pop_front())
	contacts.append(fx)
	add_mist(fx)
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
				"weapon_index":int(bullet.weapon_index),"profile":Profiles.profile(int(bullet.weapon_index)),
				"lift":float(bullet.get("height",0)),"gone":0.0}
		var trail: Dictionary=trails[key]
		trail.gone=0.0
		trail.credit+=dt
		if not trail.points.is_empty() and p.distance_to(trail.points.back().p)>600: trail.points.clear()
		if trail.credit>=.016:
			trail.credit=fmod(float(trail.credit),.016)
			trail.points.append({"p":p,"at":clock,"height":float(bullet.get("height",0))})
			if trail.points.size()>TRAIL_HISTORY_POINTS: trail.points.pop_front()
	for key in trails.keys():
		var trail: Dictionary=trails[key]
		while not trail.points.is_empty() and clock-float(trail.points[0].at)>TRAIL_LIFE: trail.points.pop_front()
		if not seen.has(key):
			trail.gone+=dt
			if trail.gone>.15:
				clear_ribbon(trail); trails.erase(key); continue
		sync_ribbon(trail)

func advance(dt: float) -> void:
	clock+=dt
	for i in range(contacts.size()-1,-1,-1):
		contacts[i].age+=dt
		if contacts[i].age>=contacts[i].life:
			clear_mist(contacts[i]); contacts.remove_at(i)
		else: sync_mist(contacts[i])
	for key in marks.keys():
		if clock-float(marks[key])>1.0: marks.erase(key)
	for trail in trails.values(): sync_ribbon(trail)
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

func _draw() -> void: draw_layer(self,false)
