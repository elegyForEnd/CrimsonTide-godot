extends Node2D
## A real bounded particle simulation: spawn regions, velocities, forces, color/size
## curves, ribbons and source-owned emitters. Decorative only; never changes damage.
const Geometry=preload("res://scripts/boss_geometry.gd")
const MAX_PARTICLES := 1400
const MAX_EMITTERS := 48
const WEAPON_STYLES := ["spark","spark","spark","ice","ember","ice","electric","petal","star","ember","soul","star","spark","petal","water","stone","feather","spark","ice","feather","soul"]
const BOSS_STYLES := {"bell":"star","thorn":"petal","queen":"petal","knight":"spark","hidden":"soul","mirror":"ice","ember":"ember","moon":"soul","earth":"stone","storm":"electric","abyss":"water","dragon":"ice","grove":"petal","furnace":"ember","astral":"star","wing":"feather","obsidian":"feather"}
var particles: Array[Dictionary]=[]
var emitters: Dictionary={}
var rng := RandomNumberGenerator.new()
var light: Node2D
var clock := 0.0
func _ready() -> void:
	rng.seed=731947
	material=CanvasItemMaterial.new()
	light=Node2D.new()
	var additive := CanvasItemMaterial.new(); additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	light.material=additive; add_child(light); light.draw.connect(func(): draw_particles(light,true))
func reset() -> void:
	particles.clear(); emitters.clear(); clock=0.0
	queue_redraw()
	if light: light.queue_redraw()
static func weapon_style(index: int) -> String: return WEAPON_STYLES[clampi(index,0,20)]
static func boss_style(key: String) -> String: return BOSS_STYLES.get(key,"spark")
func spawn(at: Vector2, velocity: Vector2, color: Color, style: String, power: float=1.0, source: String="", target: Vector2=Vector2.ZERO, gathering: bool=false) -> void:
	if particles.size()>=MAX_PARTICLES: particles.pop_front()
	var lifetime := rng.randf_range(.24,.48)
	var gravity := Vector2(0,70)
	var size := rng.randf_range(1.6,3.4)*sqrt(power)
	var drag := 2.0
	if style=="ember": lifetime=rng.randf_range(.38,.62); gravity=Vector2(0,-65); drag=1.4
	if style=="stone": gravity=Vector2(0,330); size*=1.05; drag=.8
	if style=="dust": lifetime=.65; size*=2.4; gravity=Vector2(0,-15); drag=3.2
	if style=="feather" or style=="petal": lifetime=.52; gravity=Vector2(0,28); drag=2.8
	if style=="soul": lifetime=.50; gravity=Vector2(0,-35); drag=1.0
	if style=="electric": lifetime=.19; gravity=Vector2.ZERO; drag=3.0
	if gathering: lifetime=.45; gravity=Vector2.ZERO; size*=.75; drag=.6
	particles.append({"p":at,"previous":at,"v":velocity,"age":0.0,"life":lifetime,"color":color,"style":style,"size":size,"gravity":gravity,"drag":drag,"angle":rng.randf()*TAU,"spin":rng.randf_range(-4,4),"source":source,"target":target,"gather":gathering,"seed":rng.randf()*10})
func burst(at: Vector2, aim: Vector2, color: Color, style: String="spark", count: int=16, power: float=1.0, fan: float=1.5) -> void:
	for i in count:
		var direction := aim.normalized().rotated(rng.randf_range(-fan,fan))
		var velocity := direction*rng.randf_range(45,125)*power
		if style in ["ember","soul"]: velocity.y-=35
		spawn(at+Vector2(rng.randf_range(-6,6),rng.randf_range(-4,4)),velocity,color,style,power)
		particles.back().age=-float(i)/maxi(1,count-1)*.075
	if style in ["stone","ember"]:
		for i in 3:
			spawn(at,Vector2(rng.randf_range(-45,45),rng.randf_range(-60,-20)),color.darkened(.35),"dust",power)
			particles.back().age=-.055-rng.randf_range(0,.04)
func start(key: String, at: Vector2, aim: Vector2, color: Color, style: String, kind: String, life: float, radius: float=30, rate: float=30, inner: float=0) -> void:
	if emitters.size()>=MAX_EMITTERS and not emitters.has(key): emitters.erase(emitters.keys()[0])
	emitters[key]={"p":at,"aim":aim.normalized(),"color":color,"style":style,"kind":kind,"life":life,"age":0.0,"credit":0.0,"radius":radius,"inner":inner,"rate":rate,"width":18.0}
func move(key: String, at: Vector2, aim: Vector2=Vector2.ZERO) -> void:
	if not emitters.has(key): return
	emitters[key].p=at
	if aim.length_squared()>.01: emitters[key].aim=aim.normalized()
	for particle in particles:
		if particle.source==key and particle.gather: particle.target=at
func stop(key: String, clear_gather: bool=true) -> void:
	emitters.erase(key)
	if clear_gather:
		for i in range(particles.size()-1,-1,-1):
			if particles[i].source==key and particles[i].gather:
				particles[i].gather=false
				particles[i].v*=.25
				particles[i]["stopping"]=0.0
func advance(dt: float) -> void:
	clock+=dt
	for key in emitters.keys():
		var e: Dictionary=emitters[key]
		e.age+=dt
		if e.age>=e.life: emitters.erase(key); continue
		var envelope := smoothstep(0.0,minf(.10,e.life*.3),float(e.age))*(1.0-smoothstep(maxf(0,e.life-.14),float(e.life),float(e.age)))
		e.credit+=dt*e.rate*envelope
		for i in mini(12,int(e.credit)):
			e.credit-=1.0
			var at: Vector2=e.p
			var direction: Vector2=e.aim
			var velocity := direction*rng.randf_range(30,80)
			var gathering: bool=e.kind=="gather"
			if gathering:
				at+=Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(e.radius*.65,e.radius)
				velocity=(e.p-at).normalized()*rng.randf_range(55,90)
			elif e.kind=="stroke":
				var angle: float=e.aim.angle()+lerpf(-.9,.9,clampf(e.age/e.life,0,1))
				at=e.p-e.aim*e.radius+Vector2.from_angle(angle)*e.radius
				velocity=Vector2.from_angle(angle+PI*.5)*rng.randf_range(35,80)
			elif e.kind=="line":
				at+=e.aim*rng.randf_range(0,e.radius)+e.aim.orthogonal()*rng.randf_range(-e.width,e.width)
			elif e.kind=="ring":
				at+=Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(e.inner,e.radius)
				velocity=(at-e.p).normalized()*35
			elif e.kind=="trail": velocity=-e.aim*rng.randf_range(20,70)
			else: at+=Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0,e.radius); velocity=Vector2(rng.randf_range(-25,25),rng.randf_range(-70,-25))
			spawn(at,velocity,e.color,e.style,.8,key,e.p,gathering)
			if e.has("mask"): particles.back()["mask"]=e.mask
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary=particles[i]
		p.age+=dt
		if p.age>=p.life: particles.remove_at(i); continue
		if p.age<0: continue
		if p.has("stopping"):
			p.stopping+=dt
			if p.stopping>=.12: particles.remove_at(i); continue
		p.previous=p.p
		if p.gather:
			var delta: Vector2=p.target-p.p
			if delta.length()<3: particles.remove_at(i); continue
			p.v+=delta.normalized()*220*dt
		else: p.v+=p.gravity*dt
		p.v*=exp(-p.drag*dt)
		p.p+=p.v*dt
		p.angle+=p.spin*dt
		if p.has("mask") and not safe_particle(p.mask,p.p,float(p.size)): particles.remove_at(i)
	queue_redraw()
	if light: light.queue_redraw()
func draw_particles(target: CanvasItem, glow: bool) -> void:
	var world := get_global_transform()
	if absf(world.determinant())<.000001: return
	var inverse := world.affine_inverse()
	for p in particles:
		if p.age<0: continue
		var t: float=p.age/p.life
		var fade := smoothstep(0.0,.055,float(p.age))*pow(1.0-t,1.4)*float(p.color.a)*.72
		if p.has("stopping"): fade*=1.0-smoothstep(0,.12,float(p.stopping))
		var color: Color=p.color.lerp(Color.WHITE,maxf(0,1.0-t*4.0)*.12)
		color.a=fade
		var size: float=p.size*(.65+.35*sin(t*PI))
		var screen: Vector2=world*p.p
		target.draw_set_transform_matrix(inverse*Transform2D(float(p.angle),screen))
		var style: String=p.style
		if glow:
			if style in ["dust","stone","feather","petal"]: continue
			target.draw_circle(Vector2.ZERO,size*1.8,Color(color,color.a*.025))
			target.draw_circle(Vector2.ZERO,maxf(.5,size*.25),Color(Color.WHITE,color.a*.08))
		elif style=="dust":
			target.draw_circle(Vector2.ZERO,size*(.7+t),Color(color,color.a*.12))
			target.draw_circle(Vector2(size*.4,0),size*.6,Color(color,color.a*.08))
		elif style in ["ice","star","stone"]:
			var points := PackedVector2Array([Vector2(-size,0),Vector2(0,-size*.60),Vector2(size,0),Vector2(0,size*.60)])
			if style=="stone": points=PackedVector2Array([Vector2(-size,size*.3),Vector2(-size*.2,-size*.65),Vector2(size,size*.5)])
			target.draw_colored_polygon(points,color)
			target.draw_line(points[0],points[1],Color(Color.WHITE,fade*.22),1,true)
		elif style in ["feather","petal"]:
			var points := PackedVector2Array([Vector2(-size*1.6,0),Vector2(-size*.2,-size*.6),Vector2(size*1.3,0),Vector2(0,size*.4)])
			target.draw_colored_polygon(points,Color(color,fade*.75))
			target.draw_line(points[0],points[2],Color(Color.WHITE,fade*.14),1,true)
		elif style=="electric":
			var bend := sin(p.seed+clock*12)*size*.5
			target.draw_polyline(PackedVector2Array([Vector2(-size*2,0),Vector2(-size*.6,bend),Vector2(size*.5,-bend),Vector2(size*2,0)]),color,1.0,true)
		elif style in ["soul","water"]:
			target.draw_polyline(PackedVector2Array([Vector2(-size*1.6,size*.3),Vector2(-size*.5,-size*.2),Vector2(size*.7,0)]),Color(color,fade*.55),1.0,true)
		else:
			var tail := clampf(p.v.length()*.025,2,9)
			target.draw_line(Vector2(-tail*.5,0),Vector2(tail*.5,0),color,1.0 if style=="spark" else 1.3,true)
	target.draw_set_transform(Vector2.ZERO)
func _draw() -> void: draw_particles(self,false)

func safe_particle(h: Dictionary, at: Vector2, size: float) -> bool:
	if not Geometry.contains(h,at): return false
	var world := get_global_transform()
	var margin := size*2.2/maxf(.35,minf(world.x.length(),world.y.length()))
	var delta: Vector2=at-h.p
	var distance := delta.length()
	if distance<float(h.get("inner",0))+margin or distance>float(h.radius)-margin: return false
	var angular_margin := asin(clampf(margin/maxf(1,distance),0,1))
	var angle := absf(Geometry.aim(h).angle_to(delta))
	if h.shape=="gap_ring" and angle<=float(h.get("gap",.5))+angular_margin: return false
	if h.shape=="arc" and angle>=float(h.get("arc",1.05))-angular_margin: return false
	return true
