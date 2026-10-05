extends Node2D
## Event-driven, batched ribbons and hit shards. All coordinates are ground-local.
## Two passes keep a saturated silhouette beneath a brief additive white edge.
const MAX_EFFECTS := 96
const MAX_SHARDS := 192
const PALETTES := [Color("ff426c"), Color("72e5ff"), Color("ae86ff"), Color("d771ff")]
var effects: Array[Dictionary] = []
var shards: Array[Dictionary] = []
var particles=preload("res://scripts/combat_particles.gd").new()
var light: Node2D
var density := 1.0
const Motion = preload("res://scripts/effect_motion.gd")
const Library = preload("res://scripts/vfx_library.gd")
var impact_marks: Dictionary={}
var current_texture := ""
var current_hero := 0
var current_source := -1
var skin_colors: Dictionary={}
var socket_provider: Callable

func set_skin(hero: int, color: Color) -> void:
	skin_colors[hero]=color

func _ready() -> void:
	add_child(particles)
	light=Node2D.new()
	var glow := CanvasItemMaterial.new()
	glow.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	light.material=glow
	add_child(light)
	light.draw.connect(draw_light)
	var painted := ShaderMaterial.new()
	painted.shader=preload("res://resources/stylized_texture.gdshader")
	material=painted

func reset() -> void:
	effects.clear()
	impact_marks.clear()
	shards.clear()
	particles.reset()
	queue_redraw()
	if light: light.queue_redraw()

func emit(kind: String, at: Vector2, aim: Vector2, color: Color, radius: float,
		life: float, reverse: float = 1.0, delay: float = 0.0, priority: int = 1) -> void:
	if effects.size()>=MAX_EFFECTS:
		var victim := -1
		for i in effects.size():
			if int(effects[i].priority)<=priority:
				victim=i
				break
		if victim<0: return
		effects.remove_at(victim)
	var effect := {"kind":kind,"p":at,"aim":aim.normalized() if aim.length_squared()>.01 else Vector2.RIGHT,
		"color":color,"radius":radius,"life":maxf(.05,life),"age":-delay,"reverse":reverse,"priority":priority,"hero":current_hero,"source":current_source,"texture":current_texture if current_texture!="" else "hero_%d_%s" % [current_hero,"slash" if kind=="echo" else "sigil" if kind=="ring" else "dash" if kind=="lance" else kind]}
	if kind!="charge" and uses_weapon_socket(effect) and socket_provider.is_valid() and absf(get_global_transform().determinant())>.000001:
		var socket: Dictionary=socket_provider.call(current_source)
		if not socket.is_empty():
			# A painted slash is the whole stroke, stamped once in world space.
			# Capture immediately, including delayed echoes, before pose recovery.
			effect["socket_local"]=get_global_transform().affine_inverse()*socket.get("stroke_tip",socket.tip)
			effect["socket_aim"]=socket.aim
	effects.append(effect)

func uses_weapon_socket(effect: Dictionary) -> bool:
	var kind: String=effect.kind
	if kind=="eruption" and float(effect.radius)>100: return false
	return (kind in ["slash","echo","lance","spin","muzzle","cast","charge","vortex","eruption"] and Library.source_weapon(effect.texture)>=0) or kind=="charge" or (kind in ["slash","echo","judgment","soul"] and str(effect.texture).ends_with("_ultimate"))

func cancel_charge(source: int) -> void:
	particles.stop("charge:"+str(source))
	for i in range(effects.size()-1,-1,-1):
		if effects[i].source==source and effects[i].kind=="charge": effects.remove_at(i)

func shatter(at: Vector2, aim: Vector2, color: Color, count: int, power: float = 1.0) -> void:
	# Golden-angle distribution avoids random flicker and identical radial stars.
	for i in maxi(1,roundi(count*density)):
		if shards.size()>=MAX_SHARDS: shards.pop_front()
		var phase := float(i)*2.39996
		var direction := aim.rotated(sin(phase)*1.25)
		var speed := (95.0+fposmod(float(i)*71.0,220.0))*power
		shards.append({"p":at,"v":direction*speed,"age":0.0,"life":.22+fposmod(phase,.24),
			"color":color,"size":(4.0+fposmod(phase*9.0,8.0))*sqrt(power)})

func event(data: Dictionary, hero: int = 0) -> void:
	current_source=int(data.get("id",-1))
	var at: Vector2=data.p
	var aim: Vector2=data.get("aim",Vector2.RIGHT)
	if aim.length_squared()<.01: aim=Vector2.RIGHT
	aim=aim.normalized()
	current_hero=clampi(hero,0,3)
	var hero_color: Color=skin_colors.get(current_hero,PALETTES[current_hero])
	var exact_weapon := int(data.get("weapon_index",data.get("weapon",0)))
	var color: Color=Library.weapon_color(exact_weapon).lerp(hero_color,.22)
	current_texture=Library.weapon_key(exact_weapon,"finisher" if int(data.get("combo",0))==2 else "release")
	var weapon := int(data.get("weapon",0))
	var reach := clampf(float(data.get("reach",150 if weapon==2 else 112)),48,650)
	var reverse := -1.0 if int(data.get("combo",0))%2==1 else 1.0
	var anchor: Vector2=data.get("contact_p",at-Vector2(0,24))
	var weapon_emitter := anchor
	if socket_provider.is_valid():
		var socket: Dictionary=socket_provider.call(current_source)
		if not socket.is_empty() and absf(get_global_transform().determinant())>.000001:
			weapon_emitter=get_global_transform().affine_inverse()*socket.get("stroke_tip",socket.tip)
	if data.kind=="impact":
		var mark := str(current_source)+":"+str(data.get("enemy_id",-1))
		if particles.clock-float(impact_marks.get(mark,-10))<.075: return
		impact_marks[mark]=particles.clock
	particle_event(data,weapon_emitter,aim,color,exact_weapon,reach)
	match str(data.kind):
		"strike":
			var finishing := int(data.get("combo",0))==2
			if weapon not in [1,2]:
				var form := "muzzle" if weapon==0 else "vortex" if exact_weapon==10 else "eruption" if exact_weapon==4 else "cast"
				emit(form,anchor+aim*30,aim,color,62 if weapon==0 else 54,.18 if weapon==0 else .26)
				shatter(weapon_emitter,aim,color,3,.45)
				return
			var heavy := weapon==2
			var pattern := str(data.get("pattern",""))
			if pattern=="thrust":
				emit("lance",anchor+aim*reach*.48,aim,color,reach*.62,.24)
			elif pattern=="spin":
				emit("spin",anchor,aim,color,reach,.34,reverse)
			elif pattern=="quake":
				emit("cast",anchor,aim,color,38,.2)
				emit("eruption",at-Vector2(0,reach*.28),Vector2.RIGHT,color,reach*.85,.4,1,0,2)
				emit("ring",at,aim,color,reach,.38,1,.025)
				shatter(at,Vector2.UP,color,10,1.15)
			else:
				emit("slash",anchor,aim,color,reach,.32 if heavy else .25,reverse,0,2 if heavy else 1)
			if finishing:
				emit("echo",anchor,aim.rotated(.32),color,reach*.94,.32,reverse,.065,0)
			shatter(weapon_emitter,aim,color,5 if heavy else 3,.6)
		"impact":
			var heavy: bool=data.get("heavy",false)
			current_texture="hit_flash"
			emit("impact",anchor,aim,color,28 if heavy else 18,.14 if heavy else .10,1,0,2)
		"dodge":
			current_texture="hero_%d_dash" % current_hero
			color=hero_color
			emit("dash",anchor,aim,color,112,.26)
			shatter(anchor,-aim,color,6,.55)
		"windup", "necromancer-cast":
			if float(data.get("windup",0))>0 or data.kind=="necromancer-cast":
				current_texture="hero_%d_charge" % current_hero
				emit("charge",at-Vector2(0,28),aim,color,40 if weapon==3 else 24,maxf(.04,float(data.get("windup",.25))))
		"skill":
			current_hero=clampi(int(data.get("hero",hero)),0,3)
			color=skin_colors.get(current_hero,PALETTES[current_hero])
			current_texture="hero_%d_ultimate" % current_hero
			match current_hero:
				0:
					emit("slash",anchor+aim*70,aim,color,205,.42,1,0,3)
					emit("echo",anchor+aim*145,aim,color,175,.36,-1,.12,3)
				1:
					emit("blessing",at,Vector2.RIGHT,color,180,.72,1,0,3)
				2:
					emit("judgment",anchor,aim,color,215,.48,1,0,3)
				3:
					# Ground rectangle and flame residues still follow the host's patch.
					emit("soul",anchor+aim*70-Vector2(0,70),Vector2.RIGHT,color,95,.46,1,0,3)
			shatter(anchor,Vector2.UP,color,12,1.0)

func advance(dt: float) -> void:
	if socket_provider.is_valid() and absf(get_global_transform().determinant())>.000001:
		for key in particles.emitters.keys():
			if not str(key).begins_with("charge:"): continue
			var socket: Dictionary=socket_provider.call(int(str(key).get_slice(":",1)))
			if not socket.is_empty(): particles.move(key,get_global_transform().affine_inverse()*socket.tip)
	particles.advance(dt)
	for i in range(effects.size()-1,-1,-1):
		effects[i].age+=dt
		if effects[i].age>=effects[i].life: effects.remove_at(i)
	for i in range(shards.size()-1,-1,-1):
		var s: Dictionary=shards[i]
		s.age+=dt
		if s.age>=s.life:
			shards.remove_at(i)
		else:
			s.p+=s.v*dt
			s.v*=exp(-dt*4.5)
	queue_redraw()
	if light: light.queue_redraw()

func diamond(target: CanvasItem, extent: Vector2, color: Color) -> void:
	target.draw_colored_polygon(PackedVector2Array([Vector2(-extent.x,0),Vector2(0,-extent.y),
		Vector2(extent.x,0),Vector2(0,extent.y)]),color)

func draw_pass(target: CanvasItem, additive: bool) -> void:
	if absf(get_global_transform().determinant())<.000001: return
	for fx in effects:
		if fx.age<0: continue
		var t: float=clampf(fx.age/fx.life,0,1)
		var profile := Motion.profile(fx.texture,str(fx.kind))
		var birth := Motion.coverage(float(fx.age),float(fx.life),float(profile.birth))
		var fade := smoothstep(0.0,.025,float(fx.age))*pow(1.0-t,1.25)
		if fx.kind=="charge": fade=smoothstep(0.0,.12,t)*(1.0-smoothstep(.85,1.0,t))
		var r: float=fx.radius
		var kind: String=fx.kind
		var extent := Vector2.ONE*r*2
		var at: Vector2=fx.p
		var angle: float=fx.aim.angle()
		var mirror := Vector2(Library.facing_scale(fx.texture),float(fx.reverse))
		match kind:
			"slash", "echo":
				angle+=float(fx.reverse)*lerpf(-.28,.36,1.0-pow(1.0-t,3.0))
			"spin": angle+=t*TAU*float(fx.reverse)
			"lance", "muzzle": at+=fx.aim*t*12
			"dash": at-=fx.aim*t*r*.6
			"cast": extent*=.75+t*.35
			"charge": angle=t*.35; extent*=.7+t*.3
			"vortex": angle+=t*1.4
			"eruption": angle=0
			"blessing": angle=0; extent*=.85+t*.2
			"judgment": at+=fx.aim*t*28
			"soul": angle=0; at.y+=t*100
			"impact": extent*=.6+t*.5; fade=pow(1.0-t,2.2)
			"sigil", "ring":
				if additive: continue
				target.draw_set_transform(fx.p,0,Vector2(1,.45))
				var radius := r*(.8+t*.2 if kind=="sigil" else .25+.75*(1.0-pow(1.0-t,3.0)))
				target.draw_arc(Vector2.ZERO,radius,0,TAU,48,Color(fx.color,fade*.38),1.5,true)
				target.draw_set_transform(Vector2.ZERO)
				continue
		extent=Library.fitted_size(fx.texture,extent)
		var socket: Dictionary={}
		if kind=="charge" and socket_provider.is_valid():
			socket=socket_provider.call(int(fx.source))
			if not socket.is_empty():
				fx["socket_local"]=get_global_transform().affine_inverse()*socket.tip
				fx["socket_aim"]=socket.aim
		if socket.is_empty() and fx.has("socket_local"):
			socket={"tip":get_global_transform()*fx.socket_local,"aim":fx.socket_aim}
		if not socket.is_empty():
			# Cancel ground foreshortening: the blade and this image share screen space.
			angle=socket.aim.angle()
			var painted_contact := Library.blade_contact(fx.texture) if kind in ["slash","echo","spin"] and Library.source_weapon(fx.texture)>=0 else Vector2(-.35*Library.facing_scale(fx.texture),0) if kind=="lance" else Vector2.ZERO
			var contact := (painted_contact*extent*mirror).rotated(angle)
			var screen_pose := Transform2D(angle,mirror,0,socket.tip-contact)
			target.draw_set_transform_matrix(get_global_transform().affine_inverse()*screen_pose)
		else:
			target.draw_set_transform(at,angle,mirror)
		var opacity := fade*(.08 if additive else .92)
		if kind=="echo": opacity*=.22
		if kind=="impact": opacity*=.55
		# Keep ImageGen's painted white edge and dark interior intact.
		# Optional skin tint is authored per hero; default preserves source RGB.
		var color := Color.WHITE
		if skin_colors.has(int(fx.hero)): color=Color(fx.color).lerp(Color.WHITE,.7)
		color.a=opacity
		Motion.draw(target,Library.texture(fx.texture),Rect2(-extent*.5,extent),birth,str(profile.form),color,Library.facing_scale(fx.texture)<0)
		target.draw_set_transform(Vector2.ZERO)
	if not additive: return
	for s in shards:
		var fade: float=pow(1.0-s.age/s.life,1.4)
		target.draw_set_transform(s.p,s.v.angle())
		diamond(target,Vector2(s.size*fade*.65,maxf(.4,1.2*fade)),Color(s.color.lerp(Color.WHITE,.55),fade*.30))
	target.draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	draw_pass(self,false)

func draw_light() -> void:
	draw_pass(light,true)

func particle_event(data: Dictionary, at: Vector2, aim: Vector2, color: Color, weapon: int, reach: float) -> void:
	var style := particles.weapon_style(weapon)
	var source := "charge:"+str(current_source)
	match str(data.kind):
		"windup","necromancer-cast":
			var life := float(data.get("windup",.25))
			if life>0: particles.start(source,at,aim,color,style,"gather",life,32 if weapon>=3 else 23,32)
		"strike":
			particles.stop(source)
			var finishing := int(data.get("combo",0))==2
			particles.burst(at,aim,color,style,7 if finishing else 4,.85 if finishing else .6,.9)
			if int(data.get("weapon",0)) in [1,2]:
				particles.start("stroke:"+str(current_source)+":"+str(particles.clock),at,aim,color,style,"stroke",.18,minf(80,reach*.4),45)
			if data.get("pattern","")=="quake": particles.burst(data.p,Vector2.UP,color,"stone",12,.9,PI)
		"impact":
			var before: int=particles.particles.size()
			particles.burst(data.get("contact_p",data.p-Vector2(0,24)),aim,Color(color,.7),style,5 if data.get("heavy",false) else 3,.5,.35)
			for index in range(before,particles.particles.size()):
				var bit: Dictionary=particles.particles[index]
				bit.size=minf(2.5,bit.size*.65); bit.life=minf(bit.life,.22); bit.drag=5.0
				bit.gravity=Vector2(0,15)
		"dodge": particles.burst(data.p-Vector2(0,24),-aim,color,["petal","ice","feather","soul"][current_hero],9,.65,.45)
		"skill":
			style=["petal","ice","feather","soul"][current_hero]
			particles.burst(data.p-Vector2(0,35),Vector2.UP,color,style,44,1.35,PI)
			particles.start("ultimate:"+str(current_source),data.p,aim,color,style,"ambient",.70,45,24)
