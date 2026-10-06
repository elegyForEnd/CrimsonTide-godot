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
const WeaponVfx = preload("res://scripts/weapon_vfx.gd")
var current_identity: Dictionary={}
var current_stage := 0
var current_route := -1
var current_upgrade: Dictionary={}
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
	current_identity={}
	current_stage=0
	current_route=-1
	current_upgrade={}
	impact_marks.clear()
	shards.clear()
	particles.reset()
	queue_redraw()
	if light: light.queue_redraw()

func emit(kind: String, at: Vector2, aim: Vector2, color: Color, radius: float,
		life: float, reverse: float = 1.0, delay: float = 0.0, priority: int = 1) -> bool:
	if effects.size()>=MAX_EFFECTS:
		var victim := -1
		for i in effects.size():
			if int(effects[i].priority)<=priority:
				victim=i
				break
		if victim<0: return false
		effects.remove_at(victim)
	var effect := {"kind":kind,"p":at,"aim":aim.normalized() if aim.length_squared()>.01 else Vector2.RIGHT,
		"color":color,"radius":radius,"life":maxf(.05,life),"age":-delay,"reverse":reverse,"priority":priority,"hero":current_hero,"source":current_source,"texture":current_texture if current_texture!="" else "hero_%d_%s" % [current_hero,"slash" if kind=="echo" else "sigil" if kind=="ring" else "dash" if kind=="lance" else kind]}
	if not current_identity.is_empty():
		effect["identity"]=current_identity.duplicate()
		effect["stage"]=current_stage
		effect["route"]=current_route
		effect["upgrade"]=current_upgrade.duplicate()
	if kind!="charge" and uses_weapon_socket(effect) and socket_provider.is_valid() and absf(get_global_transform().determinant())>.000001:
		var socket: Dictionary=socket_provider.call(current_source)
		if not socket.is_empty():
			# A painted slash is the whole stroke, stamped once in world space.
			# Capture immediately, including delayed echoes, before pose recovery.
			effect["socket_local"]=get_global_transform().affine_inverse()*socket.get("stroke_tip",socket.tip)
			effect["socket_aim"]=socket.aim
	effects.append(effect)
	return true

func uses_weapon_socket(effect: Dictionary) -> bool:
	var kind: String=effect.kind
	if kind=="eruption" and float(effect.radius)>100: return false
	return (kind in ["slash","echo","lance","spin","muzzle","cast","charge","vortex","eruption","route","hero_combo"] and Library.source_weapon(effect.texture)>=0) or kind=="charge" or (kind in ["slash","echo","judgment","soul"] and str(effect.texture).ends_with("_ultimate"))

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
	current_identity=WeaponVfx.profile(exact_weapon)
	current_stage=clampi(int(data.get("combo",0)),0,2)
	current_route=int(data.get("combo_route",-1))
	current_upgrade=data.get("vfx",{}).duplicate()
	var color: Color=current_identity.color
	current_texture=Library.weapon_key(exact_weapon,"finisher" if current_stage==2 else "return" if current_stage==1 else "release")
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
	if data.kind in ["windup","necromancer-cast","strike"]: cancel_charge(current_source)
	particle_event(data,weapon_emitter,aim,color,exact_weapon,reach)
	match str(data.kind):
		"strike":
			var finishing := int(data.get("combo",0))==2
			var stroke := WeaponVfx.stroke(current_stage,weapon,int(current_identity.detail))
			if weapon not in [1,2]:
				var form := "muzzle" if weapon==0 else "vortex" if exact_weapon==10 else "eruption" if exact_weapon==4 else "cast"
				emit(form,anchor+aim*30,aim,color,(62 if weapon==0 else 54)*float(stroke.scale),float(stroke.life))
				# Ranged finishers amplify their own spell/muzzle, never borrow a sword slash.
				combo_route_fx(anchor,aim,color,minf(reach,120))
				shatter(weapon_emitter,aim,color,3,.45)
				return
			var heavy := weapon==2
			var pattern := str(data.get("pattern",""))
			if pattern=="thrust":
				emit("lance",anchor+aim*reach*.48,aim,color,reach*.62*float(stroke.scale),float(stroke.life))
			elif pattern=="spin":
				emit("spin",anchor,aim,color,reach*float(stroke.scale),float(stroke.life),reverse)
			elif pattern=="quake":
				emit("cast",anchor,aim,color,38*float(stroke.scale),float(stroke.life))
				emit("eruption",at-Vector2(0,reach*.28),Vector2.RIGHT,color,reach*.85*float(stroke.scale),.4,1,0,2)
				emit("ring",at,aim,color,reach*float(stroke.scale),.38,1,.025)
				shatter(at,Vector2.UP,color,10,1.15)
			else:
				emit("slash",anchor,aim,color,reach*float(stroke.scale),float(stroke.life),reverse,0,2 if heavy else 1)
			if finishing:
				emit("echo",anchor,aim,color,reach*.78,.24,-reverse,.065,0)
			combo_route_fx(anchor,aim,color,minf(reach,180))
			shatter(weapon_emitter,aim,color,5 if heavy else 3,.6)
		"impact":
			var heavy: bool=data.get("heavy",false)
			current_texture="hit_flash"
			emit("impact",anchor,aim,color,28 if heavy else 18,.14 if heavy else .10,1,0,2)
		"dodge":
			current_identity={}
			current_texture="hero_%d_dash" % current_hero
			color=hero_color
			emit("dash",anchor,aim,color,112,.26)
			shatter(anchor,-aim,color,6,.55)
		"windup", "necromancer-cast":
			if float(data.get("windup",0))>0 or data.kind=="necromancer-cast":
				current_texture=Library.weapon_key(exact_weapon,"charge")
				emit("charge",at-Vector2(0,28),aim,color,40 if weapon==3 else 24,maxf(.04,float(data.get("windup",.25))))
		"hero_combo":
			current_identity=current_identity.duplicate()
			current_identity.color=hero_color
			current_identity.motif=["blood","frost","feather","soul"][current_hero]
			current_identity.detail=clampi(int(data.get("hero_route",0)),0,3)
			emit("hero_combo",anchor,aim,hero_color,72+int(data.get("hero_route",0))*14,.36,1,0,2)
			particles.burst(weapon_emitter,aim,hero_color,["petal","ice","feather","soul"][current_hero],8,.7,.7)
		"weapon_core":
			if emit("core",anchor,aim,color,44 if int(data.get("core_rank",1))==1 else 52,.32,1,0,2):
				effects.back()["core_id"]=int(data.get("core_id",0))
				effects.back()["core_rank"]=int(data.get("core_rank",1))
		"spell_burst", "spell_beam", "spell_arc":
			if not current_identity.run: return
			var form := "detonation" if data.kind=="spell_burst" else "beam" if data.kind=="spell_beam" else "chain"
			current_texture=Library.weapon_key(exact_weapon,"finisher" if form=="detonation" else "release")
			var length := 110.0 if form=="detonation" else float(data.get("reach",200))
			if form=="chain":
				var delta: Vector2=data.get("target",at)-at
				length=delta.length(); aim=delta.normalized()
			emit(form,at,aim,color,length,.42 if form=="detonation" else .28,1,0,2)
			particles.burst(at,aim,color,str(current_identity.style),10,.9,PI if form=="detonation" else .6)
		"skill":
			current_identity={}
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

func combo_route_fx(at: Vector2, aim: Vector2, color: Color, radius: float) -> void:
	if current_route<0: return
	emit("route",at,aim,color,radius,.30,1,.02,2)

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
		var identity: Dictionary=fx.get("identity",{})
		if not identity.is_empty() and int(fx.get("stage",0))==1 and preload("res://scripts/weapon_image_art.gd").distinct_stage(int(identity.weapon),1):
			mirror.y=1 # A separately painted counter-cut already carries its own direction.
		var native: bool=not identity.is_empty() and ((identity.procedural and kind not in ["dash","ring","sigil"]) or kind in ["charge","impact","route","hero_combo","core","beam","chain"])
		if native: mirror.x=1.0
		match kind:
			"core":
				if int(fx.get("core_id",0)) in [4,5,9,10,11,12]: angle=0
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
		if not native: extent=Library.fitted_size(fx.texture,extent)
		var socket: Dictionary={}
		if kind=="charge" and socket_provider.is_valid():
			socket=socket_provider.call(int(fx.source))
			if not socket.is_empty():
				fx["socket_local"]=get_global_transform().affine_inverse()*socket.tip
				fx["socket_aim"]=socket.aim
		if socket.is_empty() and fx.has("socket_local"):
			socket={"tip":get_global_transform()*fx.socket_local,"aim":fx.socket_aim}
		var draw_pose := Transform2D(angle,mirror,0,at)
		if not socket.is_empty():
			# Cancel ground foreshortening: the blade and this image share screen space.
			angle=socket.aim.angle()
			var painted_contact := Vector2.ZERO if native else Library.blade_contact(fx.texture) if kind in ["slash","echo","spin"] and Library.source_weapon(fx.texture)>=0 else Vector2(-.35*Library.facing_scale(fx.texture),0) if kind=="lance" else Vector2.ZERO
			var contact := (painted_contact*extent*mirror).rotated(angle)
			if native:
				contact=(Vector2(r*.94,0) if kind in ["slash","echo","spin"] else Vector2.ZERO).rotated(angle)
			draw_pose=get_global_transform().affine_inverse()*Transform2D(angle,mirror,0,socket.tip-contact)
			target.draw_set_transform_matrix(draw_pose)
		else:
			target.draw_set_transform(at,angle,mirror)
		if not identity.is_empty() and kind not in ["dash","ring","sigil"]:
			if not native:
				# The painted crescent may face left in its PNG. Geometry is authored
				# forward and must not inherit that source-image correction.
				var decor := Transform2D(angle,Vector2(1,float(fx.reverse)),0,at)
				if not socket.is_empty():
					decor=get_global_transform().affine_inverse()*Transform2D(angle,Vector2(1,float(fx.reverse)),0,socket.tip-Vector2(r*.94,0).rotated(angle))
				target.draw_set_transform_matrix(decor)
			WeaponVfx.draw(target,fx,additive)
			if not native: target.draw_set_transform_matrix(draw_pose)
		if native:
			target.draw_set_transform(Vector2.ZERO)
			continue
		var upgrade: Dictionary=fx.get("upgrade",{})
		var forge := clampi(int(upgrade.get("forge",0)),0,5)
		var quality := clampi(int(upgrade.get("quality",0)),0,5)
		# Forging changes attack power, not hit reach. Increase edge light subtly;
		# actual unlocks have separate authoritative events and their own artwork.
		var opacity := fade*(.045+forge*.006+quality*.003 if additive else .86+forge*.012)
		if kind=="echo": opacity*=.22
		if kind=="impact": opacity*=.55
		# Keep ImageGen's painted white edge and dark interior intact.
		# Optional skin tint is authored per hero; default preserves source RGB.
		var color := Color.WHITE
		if skin_colors.has(int(fx.hero)): color=Color(fx.color).lerp(Color.WHITE,.7)
		color.a=opacity
		Motion.draw(target,Library.texture(fx.texture),Rect2(-extent*.5,extent),birth,str(profile.form),color,Library.facing_scale(fx.texture)<0)
		var extra := preload("res://scripts/weapon_image_art.gd").overlay(int(identity.get("weapon",-1)),int(fx.get("stage",0))) if not identity.is_empty() else null
		if extra and kind in ["slash","spin","lance","muzzle","cast","eruption","vortex"]:
			var extra_size := extra.get_size()*minf(extent.x/extra.get_width(),extent.y/extra.get_height())
			Motion.draw(target,extra,Rect2(-extra_size*.5,extra_size),birth,"sweep" if kind in ["slash","spin"] else "forward",Color(fx.color,opacity*(.14 if additive else .48)))
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
	var style: String=WeaponVfx.profile(weapon).style
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
