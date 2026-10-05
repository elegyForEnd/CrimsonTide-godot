extends Node2D
const Library = preload("res://scripts/vfx_library.gd")
const Art = preload("res://scripts/boss_effect_art.gd")
const Geometry = preload("res://scripts/boss_geometry.gd")
const SHAPE_SHADER = preload("res://resources/boss_damage_shape.gdshader")
const Staging = preload("res://scripts/boss_effect_staging.gd")
const BIRTH_SHADER = preload("res://resources/boss_entity_birth.gdshader")
var particles=preload("res://scripts/combat_particles.gd").new()
var clock := 0.0
var field
var nodes: Dictionary={}
var generation := 0
func _ready() -> void:
	add_child(particles)
func reset() -> void:
	particles.reset()
	for node in nodes.values():
		node.root.queue_free()
		node.body.queue_free()
	nodes.clear()
func _process(dt: float) -> void:
	if not field.visible or absf(get_global_transform().determinant())<.000001: return
	generation+=1
	clock+=dt
	var hazards: Array=field.session.raid.get("hazards",[]).duplicate()
	if field.session.roguelike.active(field.session):
		hazards=[]
		for fx in field.session.roguelike.combat.effects:
			hazards.append(fx if fx.get("choreographed",false) else minion_hazard(fx))
	for b in field.session.bullets:
		if not b.get("boss_projectile",false): continue
		var previous: Vector2=b.get("boss_previous",b.p)
		var delta: Vector2=b.p-previous
		hazards.append({"shape":"capsule","p":previous,"aim":delta.normalized() if delta.length()>.001 else Vector2.RIGHT,"radius":delta.length(),"inner":float(b.get("hit_radius",18)),"choreographed":true,"vfx_role":b.vfx_role,"art_key":b.art_key,"fired":true,"source":b.boss_source,"token":b.boss_token,"time":0.0,"linger":1.0})
	for prop in field.session.enemies:
		if not prop.get("boss_construct",false) or prop.hp<=0: continue
		var age := float(prop.get("construct_age",0))
		var drop_at := 1.05+int(str(prop.get("construct_link","")).get_slice("_",1))*.45 if prop.art_key=="queen" and prop.vfx_role=="sabres" else .40
		hazards.append({"shape":"circle","p":prop.p,"aim":Vector2.RIGHT,"radius":65.0,"choreographed":true,"vfx_role":prop.vfx_role,"art_key":prop.art_key,"fired":age>=drop_at,"source":prop.construct_owner,"token":"construct:"+str(prop.id),"time":drop_at-age,"windup":drop_at,"linger":99.0,"construct_only":true,"construct_age":age,"construct_life":prop.construct_life})
	for h in hazards:
		if not h.get("choreographed",false) or h.p.distance_to(field.camera)>1400: continue
		if h.get("preview_only",false) and h.get("fired",h.get("active",false)): continue
		var token := str(h.get("source",0))+":"+str(h.get("choreo_serial",0))+":"+str(h.get("part",0))+":"+str(h.get("vfx_role",""))+":"+str(h.get("origin",h.p))
		if h.has("token"): token="projectile:"+str(h.token)
		if not nodes.has(token):
			var container := Node2D.new()
			var rect := ColorRect.new()
			rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var mat := ShaderMaterial.new()
			mat.shader=SHAPE_SHADER
			var texture: Texture2D=Library.texture(str(h.standalone_key)) if h.has("standalone_key") else Art.texture(str(h.get("art_key",Art.identity(h))),str(h.vfx_role))
			mat.set_shader_parameter("art_texture",texture)
			mat.set_shader_parameter("art_size",texture.get_size())
			mat.set_shader_parameter("tone",Art.color(h))
			mat.set_shader_parameter("entity_style",Art.KEYS.find(str(h.get("art_key",Art.identity(h)))))
			rect.material=mat
			container.add_child(rect)
			add_child(container)
			var body := Sprite2D.new()
			body.texture=texture
			body.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			var birth := ShaderMaterial.new()
			birth.shader=BIRTH_SHADER
			body.material=birth
			add_child(body)
			nodes[token]={"root":container,"rect":rect,"mat":mat,"body":body,"birth":birth,"seen":generation,"elapsed":0.0,"impact_age":0.0,"was_active":false,"tail":0.0,"hazard":h.duplicate()}
		var item: Dictionary=nodes[token]
		item.seen=generation
		item.elapsed+=dt
		item.tail=0.0
		item.root.visible=not h.get("construct_only",false) and not h.get("cosmetic_only",false)
		item.hazard=h.duplicate()
		item.root.position=h.p
		item.root.rotation=Geometry.aim(h).angle()
		var bounds := Geometry.bounds(h)
		item.rect.position=bounds.position
		item.rect.size=bounds.size
		for key in Geometry.shader_data(h): item.mat.set_shader_parameter(key,Geometry.shader_data(h)[key])
		var active: bool=h.get("fired",h.get("active",false))
		particle_stage(token,item,h,active)
		if active:
			item.impact_age=maxf(float(item.impact_age)+dt,maxf(0.0,-float(h.get("time",0)))) if item.was_active else maxf(0.0,-float(h.get("time",0)))
		item.was_active=active
		item.mat.set_shader_parameter("clock",clock)
		item.mat.set_shader_parameter("arrival",clampf(float(item.elapsed)/.22,0,1))
		item.mat.set_shader_parameter("impact_age",item.impact_age)
		item.mat.set_shader_parameter("stream_style",Staging.stream_style(str(h.get("art_key","knight"))))
		update_body(item,h)
		var total := float(h.get("windup",h.get("total",1)))
		var time := float(h.get("time",h.get("delay",0)))
		item.mat.set_shader_parameter("active",active)
		item.mat.set_shader_parameter("progress",clampf(1-time/maxf(.001,total),0,1))
		var life := float(h.get("linger",h.get("life",.25)))
		item.mat.set_shader_parameter("opacity",clampf(1+time/maxf(.001,life),.18,1) if active and h.has("time") else 1.0)
		var covers := PackedVector3Array()
		if h.get("cover",false):
			for prop in field.session.enemies:
				if prop.get("boss_construct",false) and prop.get("construct_cover",false) and prop.hp>0 and covers.size()<8:
					var local: Vector2=(prop.p-h.p).rotated(-item.root.rotation)
					covers.append(Vector3(local.x,local.y,35))
		item.mat.set_shader_parameter("cover_count",covers.size())
		while covers.size()<8: covers.append(Vector3.ZERO)
		item.mat.set_shader_parameter("covers",covers)
	for token in nodes.keys():
		var item: Dictionary=nodes[token]
		if item.seen==generation: continue
		particles.stop(token)
		item.root.visible=false # No damage footprint survives the authoritative hazard.
		item.tail+=dt
		if not item.was_active or item.tail>=.32:
			item.root.queue_free()
			item.body.queue_free()
			nodes.erase(token)
		else:
			item.elapsed+=dt
			item.impact_age+=dt
			update_body(item,item.hazard)

	particles.advance(dt)

func update_body(item: Dictionary, h: Dictionary) -> void:
	var pose := Staging.pose(h,float(item.elapsed),float(item.impact_age),float(item.tail))
	if not h.get("construct_only",false) and h.has("link"):
		for prop in field.session.enemies:
			if prop.get("boss_construct",false) and prop.hp>0 and prop.get("construct_link","")==h.link and prop.art_key==h.get("art_key","") and prop.vfx_role==h.get("vfx_role","") and prop.p.distance_to(h.p)<10:
				pose.alpha=0.0 # A linked suspended blade is the attack body, not a second stamp.
	var anchor: Vector2=h.p
	if pose.kind=="projectile": anchor+=Geometry.aim(h)*float(h.radius)
	if pose.kind=="stream": anchor+=Geometry.aim(h)*minf(25.0,float(h.radius)*.06)
	anchor+=pose.offset
	var screen_point := get_global_transform()*anchor
	screen_point.y-=float(pose.lift)
	var native: Vector2=item.body.texture.get_size()
	var uniform_scale := float(pose.size)/maxf(native.x,native.y)
	# Screen-space upright entities: ground projection never squashes falling art.
	item.body.global_transform=Transform2D(float(pose.angle),Vector2.ONE*uniform_scale,0,screen_point)
	for key in ["reveal","opacity","flash","from_ground"]:
		item.birth.set_shader_parameter(key,pose.alpha if key=="opacity" else pose[key])


static func minion_hazard(fx: Dictionary) -> Dictionary:
	var h := fx.duplicate()
	var floor_index := clampi(int(fx.floor),0,4)
	h["choreographed"]=true
	h["art_key"]=["grove","furnace","astral","storm","obsidian"][floor_index]
	h["vfx_role"]=["roots","pyre","starfall","chain","scar"][floor_index]
	h["standalone_key"]="weapon_%02d_release" % [4,9,5,6,7][floor_index]
	h["token"]="minion:"+str(fx.get("visual_token",str(fx.source)+str(fx.p)+str(fx.shape)+str(fx.windup)))
	h["aim"]=fx.direction
	h["fired"]=fx.active
	h["time"]=-float(fx.age) if fx.active else float(fx.delay)
	h["linger"]=fx.total
	h["radius"]=float(fx.radius)+15.0 # Existing collision padding is visible, not hidden.
	if fx.shape=="line":
		var delta: Vector2=fx.end-fx.p
		h.shape="capsule"; h.radius=delta.length(); h.inner=float(fx.radius)+15.0
		h.aim=delta.normalized() if delta.length()>.001 else Vector2.RIGHT
		h["birth_style"]="stream"
	elif fx.shape=="cone": h["arc"]=.85; h.inner=0.0
	elif fx.shape=="ring": h.inner=maxf(0,float(fx.inner)-15.0)
	else:
		h.shape="circle"; h.inner=0.0
		if fx.shape=="aura": h["cosmetic_only"]=true
	return h

func particle_stage(token: String, item: Dictionary, h: Dictionary, active: bool) -> void:
	if h.get("preview_only",false) or h.get("construct_only",false): return
	var style := particles.boss_style(str(h.get("art_key","knight")))
	var color := Art.color(h)
	var aim := Geometry.aim(h)
	var at: Vector2=h.p
	var projectile: bool=h.shape=="capsule" and not h.has("standalone_key")
	if projectile: at+=aim*float(h.radius)
	if not item.get("particle_started",false):
		item["particle_started"]=true
		if projectile:
			particles.start(token,at,aim,color,style,"trail",99,4,24)
		elif not active:
			if h.shape in ["ring","gap_ring","arc"] or float(h.get("inner",0))>0:
				particles.start(token,at,aim,Color(color,.5),style,"ring",maxf(.1,float(h.get("time",.6))),float(h.radius),18,float(h.get("inner",0)))
				particles.emitters[token]["mask"]=h
			else: particles.start(token,at,aim,Color(color,.6),style,"gather",maxf(.1,float(h.get("time",h.get("delay",.6)))),clampf(float(h.radius)*.35,18,60),22)
	if projectile:
		particles.move(token,at,aim)
		return
	if active and not item.was_active:
		particles.stop(token)
		if h.shape in ["ring","gap_ring","arc"] or float(h.get("inner",0))>0:
			for i in 12:
				var mark := at+Vector2.from_angle(i*TAU/12)*((float(h.radius)+float(h.get("inner",0)))*.5)
				if Geometry.contains(h,mark):
					var before: int=particles.particles.size()
					particles.burst(mark,(mark-at).normalized(),color,style,2,.7,.4)
					for n in range(before,particles.particles.size()): particles.particles[n]["mask"]=h
		else: particles.burst(at,aim,color,style,clampi(int(h.radius*.16),8,22),.75,PI)
		if h.shape in ["line","lane","capsule"]:
			particles.start(token,at,aim,color,style,"line",99,float(h.radius),28)
			particles.emitters[token].width=minf(24,float(h.get("inner",44)))
		elif h.shape in ["ring","gap_ring","arc"] or float(h.get("inner",0))>0:
			# Ring particles stay in the actual annulus; the safe opening is respected below.
			particles.start(token,at,aim,color,style,"ring",99,float(h.radius),28,float(h.get("inner",0)))
			particles.emitters[token]["mask"]=h
		else: particles.start(token,at,aim,color,style,"ambient",99,minf(45,float(h.radius)*.4),14)
	if active: particles.move(token,at,aim)
	if particles.emitters.has(token) and particles.emitters[token].has("mask"):
		particles.emitters[token].mask=h
		for particle in particles.particles:
			if particle.source==token and particle.has("mask"): particle.mask=h
