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
var charged_ground: Node2D
var density := 1.0
const Motion = preload("res://scripts/effect_motion.gd")
const Library = preload("res://scripts/vfx_library.gd")
const WeaponVfx = preload("res://scripts/weapon_vfx.gd")
const Mechanics = preload("res://scripts/weapon_mechanics.gd")
const ImageArt = preload("res://scripts/weapon_image_art.gd")
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
	var glow := ShaderMaterial.new()
	glow.shader=preload("res://resources/weapon_edge_glow.gdshader")
	light.material=glow
	add_child(light)
	light.draw.connect(draw_light)
	charged_ground=Node2D.new()
	var ground_material := ShaderMaterial.new()
	ground_material.shader=preload("res://resources/charged_ground_clearance.gdshader")
	charged_ground.material=ground_material
	add_child(charged_ground)
	charged_ground.draw.connect(func(): draw_pass(charged_ground,false,true))
	var painted := ShaderMaterial.new()
	painted.shader=preload("res://resources/stylized_texture.gdshader")
	material=painted

func reset() -> void:
	effects.clear()
	current_charged=false
	current_weapon_art=false
	current_identity={}
	current_stage=0
	current_route=-1
	current_upgrade={}
	impact_marks.clear()
	shards.clear()
	particles.reset()
	queue_redraw()
	if light: light.queue_redraw()
	if charged_ground: charged_ground.queue_redraw()

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
			# The hand provides a release pivot, but mouse aim owns the strike.
			# Capture once so later fixed-facing poses cannot drag the released cut.
			effect["socket_local"]=get_global_transform().affine_inverse()*socket.get("stroke_tip",socket.tip)
			effect["socket_aim"]=socket.aim
			effect["socket_axis"]=socket.get("blade_axis",Vector2.ZERO)
			if socket.has("grip"): effect["socket_grip"]=get_global_transform().affine_inverse()*socket.get("stroke_pivot",socket.grip)
	effects.append(effect)
	return true

func uses_weapon_socket(effect: Dictionary) -> bool:
	var kind: String=effect.kind
	if kind=="eruption" and float(effect.radius)>100: return false
	return (kind in ["slash","echo","lance","spin","muzzle","cast","charge","vortex","eruption","route","hero_combo"] and Library.source_weapon(effect.texture)>=0) or kind=="charge" or (kind in ["slash","echo","judgment","soul"] and str(effect.texture).ends_with("_ultimate"))

func emit_mechanic(kind: String, role: String, at: Vector2, aim: Vector2, color: Color, radius: float, life: float, reverse: float=1.0, delay: float=0.0) -> bool:
	if not emit(kind,at,aim,color,radius,life,reverse,delay): return false
	effects.back()["art_role"]=role
	effects.back()["charged"]=current_charged
	if not current_identity.is_empty() and kind in ["slash","lance","spin","muzzle","cast","echo","route"]:
		effects.back()["art_source"]=ImageArt.release_source(int(current_identity.weapon),role,current_stage,current_weapon_art)
		if current_charged: effects.back().art_source=ImageArt.charged_source(int(current_identity.weapon),"release",effects.back().art_source)
	if not current_identity.is_empty() and kind in ["beam","detonation","chain"]:
		effects.back()["art_source"]=ImageArt.payload_source(int(current_identity.weapon),"beam" if kind=="beam" else "burst" if kind=="detonation" else "projectile",role)
		if current_charged: effects.back().art_source=ImageArt.charged_source(int(current_identity.weapon),"beam" if kind=="beam" else "burst" if kind=="detonation" else "projectile",effects.back().art_source)
	if kind=="beam" and socket_provider.is_valid():
		var socket: Dictionary=socket_provider.call(current_source)
		if not socket.is_empty() and absf(get_global_transform().determinant())>.000001:
			effects.back()["beam_start_local"]=get_global_transform().affine_inverse()*socket.tip
	return true

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

var current_weapon_art := false
var current_charged := false

func event(data: Dictionary, hero: int = 0) -> void:
	current_weapon_art=data.has("attack_kind")
	current_charged=bool(data.get("charged",false))
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
	if data.kind in ["windup","necromancer-cast","strike","hold_charge","hold_cancel"]: cancel_charge(current_source)
	particle_event(data,weapon_emitter,aim,color,exact_weapon,reach)
	match str(data.kind):
		"hold_charge":
			current_texture=Library.weapon_key(exact_weapon,"charge")
			if emit_mechanic("charge",Mechanics.cast_role(exact_weapon) if weapon==3 else "motion_thrust",at-Vector2(0,28),aim,color,24,30.0):
				effects.back()["hold_time"]=float(data.get("hold_time",.6))
		"hold_ready":
			if ImageArt.clean_charged(exact_weapon):
				for fx in effects:
					if fx.source==current_source and fx.kind=="charge": fx["ready_at"]=float(fx.age)
			else: particles.burst(weapon_emitter,aim,color,str(current_identity.get("style","spark")),8,.55,PI)
		"hold_cancel":
			pass
		"strike":
			var finishing := int(data.get("combo",0))==2
			var stroke := WeaponVfx.stroke(current_stage,weapon,int(current_identity.detail))
			var role := Mechanics.strike_role(exact_weapon,data)
			if weapon not in [1,2]:
				if current_charged:
					if ImageArt.clean_charged(exact_weapon): return
					# New ranged paintings belong to their actual payload, not the hand.
					current_texture="hit_flash"
					emit("impact",weapon_emitter,aim,color,14,.12)
					shatter(weapon_emitter,aim,color,5,.55)
					return
				# A release flash is small. Actual projectiles/beam/burst own the attack.
				emit_mechanic("muzzle" if weapon==0 else "cast",role,anchor,aim,color,(30 if weapon==0 else 27)*float(stroke.scale),.22)
				combo_route_fx(anchor,aim,color,minf(reach,120))
				if role=="muzzle_fire": shatter(weapon_emitter,aim,color,2,.25)
				return
			var heavy := weapon==2
			if role=="motion_thrust":
				if emit_mechanic("lance",role,anchor,aim,color,reach*.50,float(stroke.life)):
					effects.back()["attack_width"]=float(data.get("width",26))
			elif Mechanics.body_centered(role):
				if emit_mechanic("spin",role,at,aim,color,reach,float(stroke.life),reverse): effects.back()["height"]=float(data.get("height",0))
			else:
				emit_mechanic("slash",role,anchor,aim,color,reach,float(stroke.life),reverse)
			if bool(data.get("charged",false)): shatter(weapon_emitter,aim,color,9 if heavy else 6,.85)
			if finishing and not current_charged and not Mechanics.body_centered(role) and role!="motion_thrust":
				emit_mechanic("echo",role,anchor,aim,color,reach*.78,.24,-reverse,.065)
			combo_route_fx(anchor,aim,color,minf(reach,180))
			shatter(weapon_emitter,aim,color,5 if heavy else 3,.6)
		"impact":
			var heavy: bool=data.get("heavy",false)
			current_texture="hit_flash"
			emit("impact",anchor,aim,color,38 if heavy else 26,.18 if heavy else .14,1,0,2)
		"dodge":
			current_identity={}
			current_texture="hero_%d_dash" % current_hero
			color=hero_color
			emit("dash",anchor,aim,color,112,.26)
			shatter(anchor,-aim,color,6,.55)
		"windup", "necromancer-cast":
			if float(data.get("windup",0))>0 or data.kind=="necromancer-cast":
				current_texture=Library.weapon_key(exact_weapon,"charge")
				emit_mechanic("charge",Mechanics.cast_role(exact_weapon) if weapon==3 else "release_bow" if Catalog.weapon(exact_weapon).get("spell","")=="arrow" else "motion_thrust",at-Vector2(0,28),aim,color,10,maxf(.04,float(data.get("windup",.25))))
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
			var form := "detonation" if data.kind=="spell_burst" else "beam" if data.kind=="spell_beam" else "chain"
			current_texture=Library.weapon_key(exact_weapon,"finisher" if form=="detonation" else "release")
			var spell := str(data.get("spell",Catalog.weapon(exact_weapon).get("spell","star")))
			var length := float(data.get("radius",110)) if form=="detonation" else float(data.get("reach",200))
			if form=="chain":
				var delta: Vector2=data.get("target",at)-at
				length=delta.length(); aim=delta.normalized()
			if emit_mechanic(form,Mechanics.burst_role(exact_weapon,spell) if form=="detonation" else Mechanics.beam_role(spell) if form=="beam" else "projectile_lightning",at,aim,color,length,.42 if form=="detonation" else .28):
				effects.back()["beam_width"]=float(data.get("width",30))
				effects.back()["height"]=float(data.get("height",0))
			if not current_charged or not ImageArt.clean_charged(exact_weapon): particles.burst(at,aim,color,str(current_identity.style),10,.9,PI if form=="detonation" else .6)
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
	# Ranged route mechanics already change actual projectiles/cast events.
	# They must not additionally invent melee arcs or rising ice crystals.
	if int(current_identity.family) not in [1,2]: return
	var role := "motion_thrust" if current_route in [0,3] else Mechanics.normal_role(int(current_identity.weapon))
	var facing := -1.0 if current_route==1 else 1.0
	emit_mechanic("route",role,at,aim,color,radius*.58,.26,facing,.02)

func advance(dt: float) -> void:
	if socket_provider.is_valid() and absf(get_global_transform().determinant())>.000001:
		for fx in effects:
			if fx.kind!="charge": continue
			var live: Dictionary=socket_provider.call(int(fx.source))
			if not live.is_empty():
				fx.p=get_global_transform().affine_inverse()*live.tip
				fx["socket_local"]=fx.p
				if fx.has("hold_time"):
					var sites: Array=[]
					for point in live.get("charge_points",[live.tip]): sites.append(get_global_transform().affine_inverse()*Vector2(point))
					if sites.is_empty(): sites.append(fx.p)
					var source := "charge:"+str(fx.source)
					particles.follow_charge(source,sites)
					var progress := clampf(float(fx.age)/maxf(.01,float(fx.hold_time)),0.0,1.0)
					fx["particle_credit"]=float(fx.get("particle_credit",0))+dt*lerpf(45.0,150.0,progress)
					for n in mini(12,int(fx.particle_credit)):
						fx.particle_credit-=1.0
						var phase: float=particles.rng.randf()
						var target: Vector2=sites[mini(sites.size()-1,int(phase*sites.size()))]
						var radial := Vector2.from_angle(particles.rng.randf()*TAU)
						var start: Vector2=target+radial*particles.rng.randf_range(8,18+progress*12)
						var color := Color(fx.color).lerp(Color.WHITE,.3+progress*.3)
						particles.spawn(start,-radial*38+radial.orthogonal()*30,color,"charge",.8+progress,source,target,true)
						particles.particles.back()["weapon_charge"]=true
						particles.particles.back()["site_phase"]=phase
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
	if charged_ground: charged_ground.queue_redraw()

func diamond(target: CanvasItem, extent: Vector2, color: Color) -> void:
	target.draw_colored_polygon(PackedVector2Array([Vector2(-extent.x,0),Vector2(0,-extent.y),
		Vector2(extent.x,0),Vector2(0,extent.y)]),color)

func draw_pass(target: CanvasItem, additive: bool, ground_only: bool = false) -> void:
	if absf(get_global_transform().determinant())<.000001: return
	for fx in effects:
		if fx.age<0: continue
		var ground_fx: bool=fx.get("art_source","") in ["charged_614_v1","charged_615_v1","charged_619_v1"]
		if ground_fx!=ground_only: continue
		if fx.has("art_role"):
			draw_mechanic(target,fx,additive)
			continue
		var t: float=clampf(fx.age/fx.life,0,1)
		var profile := Motion.profile(fx.texture,str(fx.kind))
		var birth := Motion.coverage(float(fx.age),float(fx.life),float(profile.birth))
		var fade := smoothstep(0.0,.025,float(fx.age))*pow(1.0-t,1.25)
		if fx.kind=="charge": fade=smoothstep(0.0,.12,t)*(1.0-smoothstep(.85,1.0,t))
		if fx.has("hold_time"):
			t=clampf(float(fx.age)/maxf(.01,float(fx.hold_time)),0,1)
			fade=smoothstep(0,.08,float(fx.age))*(.88+.12*sin(float(fx.age)*12))
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
	if not additive or ground_only: return
	for s in shards:
		var fade: float=pow(1.0-s.age/s.life,1.4)
		target.draw_set_transform(s.p,s.v.angle())
		diamond(target,Vector2(s.size*fade*.65,maxf(.4,1.2*fade)),Color(s.color.lerp(Color.WHITE,.55),fade*.30))
	target.draw_set_transform(Vector2.ZERO)

func draw_mechanic(target: CanvasItem, fx: Dictionary, additive: bool) -> void:
	var role: String=fx.art_role
	var source: String=fx.get("art_source",ImageArt.mechanic_source(role))
	var authored := source.begins_with("weapon_") or source.begins_with("identity_") or source.begins_with("authored_") or source.begins_with("audit_") or source.begins_with("charged_")
	var t := clampf(float(fx.age)/float(fx.life),0,1)
	# Hold a crisp luminous attack through its contact, then fade during recovery.
	var fade := smoothstep(0,.008,float(fx.age))*(1-smoothstep(.56,1.0,t))
	if fx.has("hold_time"):
		t=clampf(float(fx.age)/maxf(.01,float(fx.hold_time)),0,1)
		fade=smoothstep(0,.08,float(fx.age))*(.88+.12*sin(float(fx.age)*12))
	var upgrade: Dictionary=fx.get("upgrade",{})
	var light_gain := clampi(int(upgrade.get("forge",0)),0,5)*.008+clampi(int(upgrade.get("quality",0)),0,5)*.004
	var tint := Color(fx.color)
	# Preserve the painted white core instead of tinting and clipping it to neon.
	tint=tint.lerp(Color.WHITE,.18)
	tint.v=1.0
	if authored: tint=Color.WHITE # Each original has its own materials and palette.
	tint.a=fade*(.14+light_gain if additive else .94)
	if fx.kind=="echo": tint.a*=.36
	if fx.kind=="charge":
		var point: Vector2=get_global_transform()*fx.p
		var held: Dictionary={}
		if socket_provider.is_valid():
			held=socket_provider.call(int(fx.source))
			if not held.is_empty():
				point=held.tip
				fx["socket_local"]=get_global_transform().affine_inverse()*point
		var progress := t if fx.has("hold_time") else t*.6
		var energy := smoothstep(0.0,1.0,progress)
		var breath := 1.0+sin(float(fx.age)*9)*.035*energy
		var sites: Array=held.get("charge_points",[point])
		if sites.is_empty(): sites=[point]
		if sites.size()>1:
			var line := PackedVector2Array()
			for site in sites: line.append(get_global_transform().affine_inverse()*Vector2(site))
			target.draw_set_transform(Vector2.ZERO)
			var veil := Color(fx.color).lerp(Color.WHITE,.3)
			veil.a=lerpf(.1,.55,energy)*(.8 if additive else 1.0)
			target.draw_polyline(line,Color(veil,veil.a*.3),lerpf(3.0,8.0,energy),true)
			target.draw_polyline(line,veil,lerpf(.8,2.1,energy),true)
		var color := Color(fx.color).lerp(Color.WHITE,.15+.45*energy)
		color.a=smoothstep(0,.06,float(fx.age))*lerpf(.12,.72,energy)*breath*(.75 if additive else 1.0)
		var radius := lerpf(4.0,10.0,energy)
		for site in sites:
			target.draw_set_transform_matrix(get_global_transform().affine_inverse()*Transform2D(0,site))
			target.draw_texture_rect(preload("res://scripts/weapon_held_glow.gd").surface_light(),Rect2(-Vector2.ONE*radius,Vector2.ONE*radius*2),false,color)
		# A broader glow grows around the blade, rather than flooding the character.
		var size := Vector2.ONE*float(fx.radius)*lerpf(.65,1.8,energy)
		var halo := Color(color); halo.a*=.45
		target.draw_set_transform_matrix(get_global_transform().affine_inverse()*Transform2D(0,point))
		target.draw_texture_rect(preload("res://scripts/weapon_held_glow.gd").surface_light(),Rect2(-size*.5,size),false,halo)
		target.draw_set_transform(Vector2.ZERO)
		return
	# Restore a readable attack silhouette; release flashes/charges stay compact.
	var r: float=fx.radius*(1.22 if role.begins_with("motion_") and fx.kind!="charge" else 1.0)
	var bounds := Vector2(r*1.8,r*1.5)
	var angle: float=fx.aim.angle()
	var at: Vector2=fx.p
	var stroke := Mechanics.heavy_stroke(int(fx.get("identity",{}).get("weapon",-1)),role) if fx.has("identity") else {}
	if source.begins_with("charged_"):
		var plane: String=ImageArt.mechanics.get(source,{}).get("plane","")
		stroke={} if plane=="radial" else {"plane":plane,"angle":0.0,"aspect":Vector2(1.4,1.8) if plane=="overhead" else Vector2(1.8,1.4)} if plane in ["overhead","diagonal"] else {}
	if source in ["identity_612_cut_v2","identity_618_cut_v2","identity_623_cut_v2"]:
		# These originals already paint a descending plane facing right.
		# Rotate by mouse aim once; the old sweep correction would tilt it twice.
		stroke={"plane":"overhead","angle":0.0,"aspect":Vector2(1.25,1.8)}
	if stroke.get("plane","")=="drop":
		# Downward weight and grounded fragments, instead of a spinning shockwave.
		bounds=Vector2(stroke.aspect)*r
		var mirror := Vector2(-1 if fx.aim.x<0 else 1,1)
		var landing: Vector2=at+fx.aim*r*.12
		landing.y-=float(fx.get("height",0))
		var contact := ImageArt.mechanic_contact(role,bounds,source)
		if fx.has("socket_local"):
			var point: Vector2=get_global_transform()*fx.socket_local
			target.draw_set_transform_matrix(get_global_transform().affine_inverse()*Transform2D(0,mirror,0,point-contact*mirror))
		else: target.draw_set_transform(landing-contact*mirror,0,mirror)
	elif Mechanics.body_centered(role):
		# Full circle attacks are centered on the captured body, never on a blade tip.
		bounds=Vector2.ONE*r*2
		angle=float(fx.stage)*.25 if role=="motion_quake" else t*.7*float(fx.reverse)
		var body_pose := get_global_transform()*Transform2D(angle,at)
		body_pose.origin.y-=float(fx.get("height",0))
		if role!="motion_quake" and fx.has("socket_grip") and fx.has("socket_local"):
			var grip: Vector2=get_global_transform()*fx.socket_grip
			var tip: Vector2=get_global_transform()*fx.socket_local
			var blade_length := grip.distance_to(tip)
			if blade_length>4:
				bounds=Vector2.ONE*maxf(r,blade_length)*2
		target.draw_set_transform_matrix(get_global_transform().affine_inverse()*body_pose)
	elif fx.kind in ["beam","chain"]:
		var start: Vector2=get_global_transform()*fx.beam_start_local if fx.has("beam_start_local") else get_global_transform()*at-Vector2(0,float(fx.get("height",0))+24 if fx.kind=="beam" else 24)
		var end: Vector2=get_global_transform()*(at+fx.aim*r)-Vector2(0,float(fx.get("height",0))+24 if fx.kind=="beam" else 24)
		var delta: Vector2=end-start
		bounds=Vector2(delta.length(),float(fx.get("beam_width",30)) if fx.kind=="beam" else 12)
		# The painted straight beam fills the authoritative segment; alpha is
		# cropped to its ink before mapping onto that segment, never a wave stamp.
		target.draw_set_transform_matrix(get_global_transform().affine_inverse()*Transform2D(delta.angle(),(start+end)*.5))
		var art := ImageArt.mechanic_texture(source)
		if art: target.draw_texture_rect_region(art,Rect2(-bounds*.5,bounds),ImageArt.mechanic_ink(source),tint)
		if role=="beam_eclipse":
			target.draw_set_transform_matrix(get_global_transform().affine_inverse()*Transform2D(delta.angle(),end-delta.normalized()*20))
			ImageArt.stamp_mechanic(target,"projectile_eclipse",Vector2(54,12),tint)
		target.draw_set_transform(Vector2.ZERO)
		return
	elif fx.kind=="detonation":
		bounds=Vector2.ONE*r*2*(.62+.38*(1-pow(1-t,3)))
		target.draw_set_transform(at,0)
	else:
		var socket: Dictionary={}
		if fx.kind=="charge" and socket_provider.is_valid():
			socket=socket_provider.call(int(fx.source))
			if not socket.is_empty():
				fx["socket_local"]=get_global_transform().affine_inverse()*socket.tip
				fx["socket_aim"]=socket.aim
				fx["socket_axis"]=socket.get("blade_axis",Vector2.ZERO)
		if socket.is_empty() and fx.has("socket_local"): socket={"tip":get_global_transform()*fx.socket_local,"aim":fx.socket_aim,"blade_axis":fx.get("socket_axis",Vector2.ZERO)}
		if role=="motion_thrust": bounds=Vector2(r*1.8,float(fx.get("attack_width",r*.36)))
		elif role in ["muzzle_fire","release_bow"]: bounds=Vector2(r*2,r*1.2)
		elif role.begins_with("cast_"): bounds=Vector2.ONE*r*1.7
		if not stroke.is_empty(): bounds=Vector2(stroke.aspect)*r
		if source=="identity_600_compact_v2":
			var width := minf(r*1.15,125.0)*(1.08 if int(fx.stage)==2 else 1.0)
			bounds=Vector2(width,width*.70)
		if fx.kind=="lance": bounds.x*=[.78,.90,1.0][clampi(int(fx.stage),0,2)]
		if fx.kind=="charge":
			tint.a*=smoothstep(0,.1,t)*.42
			bounds*=.5+t*.5
		if not socket.is_empty():
			angle=socket.aim.angle()
			# This compact arc is painted bowing downward; its outward edge owns
			# the attack direction, not the line between its two tapered ends.
			if source=="identity_600_compact_v2": angle-=PI*.5
			if not stroke.is_empty(): angle+=clampf(float(stroke.angle),-PI*.12,PI*.12)*(1 if socket.aim.x>=0 else -1)
			var offset := Vector2.ZERO
			if fx.kind=="route":
				tint.a*=.55
				if int(fx.route)==0: offset=Vector2(-r*.9,0)
				elif int(fx.route)==2: angle-=PI*.45; offset=Vector2(0,-r*.25)
				elif int(fx.route)==3: offset=Vector2(-r*.3,r*.55); bounds*=.72
			var mirror := Vector2(1,float(fx.reverse))
			if source=="identity_600_compact_v2": mirror=Vector2(float(fx.reverse),1)
			if authored and source!="identity_600_compact_v2" and ImageArt.distinct_stage(int(fx.identity.weapon),int(fx.stage)): mirror.y=1
			var contact := ImageArt.mechanic_contact(role,bounds,source) if fx.kind!="charge" else Vector2.ZERO
			var release: Vector2=socket.tip+offset.rotated(angle)-(contact*mirror).rotated(angle)
			if role.begins_with("motion_") and fx.kind!="charge" and fx.has("socket_grip"):
				# Fixed-facing blade contacts cannot position a freely aimed slash.
				# Center its painted body ahead of the virtual hand, along mouse aim.
				var pivot: Vector2=get_global_transform()*fx.socket_grip
				release=pivot+socket.aim.normalized()*maxf(pivot.distance_to(socket.tip)*.65,bounds.x*.22)+offset.rotated(angle)
				if source.begins_with("charged_") and role=="motion_thrust": release=pivot+socket.aim.normalized()*bounds.x*.5
			target.draw_set_transform_matrix(get_global_transform().affine_inverse()*Transform2D(angle,mirror,0,release))
		else:
			if source=="identity_600_compact_v2": angle-=PI*.5
			if not stroke.is_empty(): angle+=clampf(float(stroke.angle),-PI*.12,PI*.12)*(1 if fx.aim.x>=0 else -1)
			var mirror := Vector2(float(fx.reverse),1) if source=="identity_600_compact_v2" else Vector2(1,float(fx.reverse))
			if source.begins_with("charged_") and role=="motion_thrust": at+=fx.aim*bounds.x*.5
			target.draw_set_transform(at,angle,mirror)
	if source.begins_with("charged_") and role=="motion_thrust":
		# The narrow thrust painting spans the actual forward reach, rather than
		# shrinking a decorated shoulder until the attack becomes a tiny arrow.
		var art := ImageArt.mechanic_texture(source)
		if art: target.draw_texture_rect_region(art,Rect2(-bounds*.5,bounds),ImageArt.mechanic_ink(source),tint)
	else: ImageArt.stamp_mechanic(target,source,bounds,tint)
	# Preserve the weapon's primary silhouette in all three stages. A faint,
	# fitted counter-cut/finishing wake supports it without widening hit reach.
	if authored and not source.begins_with("charged_") and not role.begins_with("motion_") and fx.kind in ["cast","muzzle"]:
		var extra := ImageArt.overlay(int(fx.identity.weapon),int(fx.stage))
		if extra:
			var extra_size := extra.get_size()*minf(bounds.x/extra.get_width(),bounds.y/extra.get_height())*.72
			target.draw_texture_rect(extra,Rect2(-extra_size*.5,extra_size),false,Color(fx.color,tint.a*.18))
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
			if data.get("charged",false) and ImageArt.clean_charged(weapon): return
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
