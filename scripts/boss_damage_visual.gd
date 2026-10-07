extends Node2D
const Semantics = preload("res://scripts/effect_semantics.gd")
const Library = preload("res://scripts/vfx_library.gd")
const Art = preload("res://scripts/boss_effect_art.gd")
const Geometry = preload("res://scripts/boss_geometry.gd")
const SHAPE_SHADER = preload("res://resources/boss_damage_shape.gdshader")
const Staging = preload("res://scripts/boss_effect_staging.gd")
const Language=preload("res://scripts/boss_effect_language.gd")
const Contacts=preload("res://scripts/boss_entity_contacts.gd")
const Design=preload("res://scripts/boss_attack_design.gd")
const Sequence=preload("res://scripts/boss_effect_sequence.gd")
const BIRTH_SHADER = preload("res://resources/boss_entity_birth.gdshader")
const SHELL_SHADER = preload("res://resources/boss_projectile_shell.gdshader")
# Readability shell for live boss projectiles.  It is its own additive pass on a
# rect that covers the true footprint plus `shell` pixels of margin, so the
# damage boundary stays exactly where Geometry.contains() puts it: the shell has
# no colour inside the footprint and no reach beyond its own rect.
const PROJECTILE_SHELL := 13.0
const PROJECTILE_SHELL_LIFT := 0.16
# Matches RogueCombat.BULLET_VISUAL_BOUNDS: the variant factor can only grow a
# bolt, and a bolt with no factor draws exactly as before.
const BULLET_VISUAL_MAX := 3.0
# The sprite itself gets the same treatment: a saturated skin on its solid alpha
# and a bloom reaching PROJECTILE_SHELL_REACH source pixels beyond it.
const PROJECTILE_SHELL_STRENGTH := 0.85
const PROJECTILE_SHELL_REACH := 8.0
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
		if node.has("shell"): node.shell.queue_free()
		for copy in node.get("copies",[]): copy.queue_free()
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
		hazards.append({"shape":"capsule","p":previous,"aim":delta.normalized() if delta.length()>.001 else Vector2.RIGHT,"radius":delta.length(),"inner":float(b.get("hit_radius",18)),"choreographed":true,"vfx_role":b.vfx_role,"art_key":b.art_key,"fired":true,"source":b.boss_source,"token":b.boss_token,"time":-float(b.get("boss_age",0)),"flight_age":float(b.get("boss_age",0)),"linger":1.0,
			# Presentation-only variant factor: it grows the staged sprite in
			# boss_effect_staging.pose() and nothing else.  `inner` - and so both
			# the damage footprint and the shell drawn around it - stays exactly
			# the bolt's own hit radius, so a bigger bolt never means a bigger hurt.
			"bullet_visual":clampf(float(b.get("bullet_visual",1.0)),1.0,BULLET_VISUAL_MAX)})
	for prop in field.session.enemies:
		if not prop.get("boss_construct",false) or prop.hp<=0: continue
		var age := float(prop.get("construct_age",0))
		var drop_at := 1.05+int(str(prop.get("construct_link","")).get_slice("_",1))*.45 if prop.art_key=="queen" and prop.vfx_role=="sabres" else .40
		var vent_active := false
		for linked_hazard in hazards:
			if linked_hazard.get("link","")==prop.construct_link and linked_hazard.get("source",-1)==prop.construct_owner and linked_hazard.get("fired",linked_hazard.get("active",false)): vent_active=true
		hazards.append({"shape":"circle","p":prop.p,"aim":Vector2.RIGHT,"radius":65.0,"choreographed":true,"vfx_role":prop.vfx_role,"art_key":prop.art_key,"fired":age>=drop_at,"source":prop.construct_owner,"token":"construct:"+str(prop.id),"time":drop_at-age,"windup":drop_at,"linger":99.0,"construct_only":true,"construct_age":age,"construct_life":prop.construct_life,"vent_active":vent_active})
	for h in hazards:
		if not h.get("choreographed",false) or h.p.distance_to(field.camera)>1400: continue
		# Old network records also identify bosses through flags; normalize once for all stages.
		h=render_record(h)
		var physical: bool=str(h.get("delivery","")) in Design.PHYSICAL
		var waiting: bool=not h.get("fired",h.get("active",false))
		if h.get("preview_only",false) and h.get("fired",h.get("active",false)): continue
		var token := str(h.get("source",0))+":"+str(h.get("choreo_serial",0))+":"+str(h.get("part",0))+":"+str(h.get("vfx_role",""))+":"+str(h.get("origin",h.p))
		if h.has("token"): token="projectile:"+str(h.token)
		if not nodes.has(token):
			var container := Node2D.new()
			var rect := ColorRect.new()
			rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var mat := ShaderMaterial.new()
			mat.shader=SHAPE_SHADER
			var art_key := str(h.get("art_key",Art.identity(h)))
			var sprite_role := Language.sprite_role(art_key,str(h.vfx_role),str(h.shape),str(h.get("move","")),str(h.get("delivery","")))
			var texture: Texture2D=Library.texture(str(h.standalone_key)) if h.has("standalone_key") else Art.texture(art_key,sprite_role)
			mat.set_shader_parameter("art_texture",texture)
			mat.set_shader_parameter("art_size",texture.get_size())
			mat.set_shader_parameter("tone",Art.color(h))
			mat.set_shader_parameter("attack_family",int(h.get("attack_family",-1)))
			mat.set_shader_parameter("entity_style",Art.KEYS.find(str(h.get("art_key",Art.identity(h)))))
			mat.set_shader_parameter("motif",Art.MOTIFS[art_key].find(str(h.vfx_role)))
			rect.material=mat
			container.add_child(rect)
			add_child(container)
			# Live projectiles add one additive shell pass.  It is a sibling of the
			# damage rect, drawn after it and before the sprite, on a rect that is
			# the true footprint grown by a fixed margin - no scaling of the shape
			# inside it, so the boundary that hurts is still the boundary drawn.
			var shell: ColorRect=null
			var shell_mat: ShaderMaterial=null
			if str(h.shape)=="capsule":
				shell=ColorRect.new()
				shell.mouse_filter=Control.MOUSE_FILTER_IGNORE
				shell_mat=ShaderMaterial.new()
				shell_mat.shader=SHELL_SHADER
				shell.material=shell_mat
				add_child(shell)
			var body := Sprite2D.new()
			body.texture=texture
			body.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			var birth := ShaderMaterial.new()
			birth.shader=BIRTH_SHADER
			body.material=birth
			add_child(body)
			nodes[token]={"root":container,"rect":rect,"mat":mat,"body":body,"birth":birth,"seen":generation,"elapsed":0.0,"impact_age":0.0,"was_active":false,"tail":0.0,"hazard":h.duplicate()}
			if shell!=null: nodes[token].merge({"shell":shell,"shell_mat":shell_mat})
		var item: Dictionary=nodes[token]
		item.seen=generation
		item.elapsed+=dt
		item.tail=0.0
		var near_release: bool=float(h.get("time",0))<=float(h.get("warning_lead",99))
		item.root.visible=not physical and str(h.get("delivery",""))!="shadow" and not h.get("construct_only",false) and not h.get("cosmetic_only",false) and (not waiting or near_release)
		item.hazard=h.duplicate()
		item.root.position=h.p
		item.root.rotation=Geometry.aim(h).angle()
		var bounds := Geometry.bounds(h)
		item.rect.position=bounds.position
		item.rect.size=bounds.size
		if item.has("shell"):
			var margin := PROJECTILE_SHELL if str(h.shape)=="capsule" else 0.0
			item.shell.visible=item.root.visible and margin>0.0
			if margin>0.0:
				item.shell.rotation=Geometry.aim(h).angle()
				var extent := Vector2(float(h.radius)+float(h.inner)*2.0+margin*2.0,float(h.inner)*2.0+margin*2.0)
				# Positioned as a plain point in the same local frame as h.p, so a
				# rotated capsule gets a shell that lines up exactly with the bolt.
				item.shell.position=Vector2.ZERO
				item.shell.size=extent
				item.shell.position=-extent*0.5
			var shell_data := Geometry.shader_data(h)
			for key in shell_data: item.shell_mat.set_shader_parameter(key,shell_data[key])
			item.shell_mat.set_shader_parameter("tone",Art.color(h))
			item.shell_mat.set_shader_parameter("margin",margin)
			item.shell_mat.set_shader_parameter("clock",clock)
		var shape_data := Geometry.shader_data(h)
		for key in shape_data: item.mat.set_shader_parameter(key,shape_data[key])
		item.mat.set_shader_parameter("halo_strength",0.0)
		item.mat.set_shader_parameter("warning_style",int(h.get("warning_style",0)))
		item.mat.set_shader_parameter("contact_impact",str(h.get("delivery","")) in ["fall","pendulum","impact","slam","teeth"])
		var atlas_role := Sequence.resolve(h,Language.sprite_role(str(h.art_key),str(h.vfx_role),str(h.shape),str(h.get("move","")),str(h.get("delivery",""))))
		item.mat.set_shader_parameter("painted_body",Sequence.has(atlas_role))
		var active: bool=h.get("fired",h.get("active",false))
		particle_stage(token,item,h,active)
		if active:
			item.impact_age=maxf(0.0,-float(h.get("time",0))) # Every atlas uses simulation-authoritative state.
		item.was_active=active
		item.mat.set_shader_parameter("clock",clock)
		item.mat.set_shader_parameter("arrival",clampf(float(item.elapsed)/.22,0,1))
		item.mat.set_shader_parameter("impact_age",item.impact_age)
		item.mat.set_shader_parameter("stream_style",Language.stream_style(str(h.get("art_key","knight")),str(h.vfx_role)))
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
		if item.has("shell"): item.shell.visible=false
		item.tail+=dt
		if not item.was_active or item.tail>=.32:
			item.root.queue_free()
			item.body.queue_free()
			if item.has("shell"): item.shell.queue_free()
			for copy in item.get("copies",[]): copy.queue_free()
			nodes.erase(token)
		else:
			item.elapsed+=dt
			item.impact_age+=dt
			update_body(item,item.hazard)

	particles.advance(dt)

func update_body(item: Dictionary, h: Dictionary) -> void:
	var pose := Staging.pose(h,float(item.elapsed),float(item.impact_age),float(item.tail))
	var sprite_role := Language.sprite_role(str(h.art_key),str(h.vfx_role),str(h.shape),str(h.get("move","")),str(h.get("delivery","")))
	sprite_role=Sequence.resolve(h,sprite_role)
	var sequence: Dictionary={}
	if Sequence.has(sprite_role):
		var state := Sequence.state(h,float(item.impact_age),sprite_role,float(item.tail))
		sequence=Sequence.frame(sprite_role,int(state.frame))
		item.body.texture=sequence.texture
		pose.alpha=state.opacity
		if str(sequence.style)=="attached":
			pose.size=float(h.radius)
			pose.angle=0.0
		else: pose=sequence_pose(h,pose,sequence)
		pose["stroke_mode"]=false
		item["sequence_state"]=state.name
		item["sequence_frame"]=state.frame
		item["sequence_key"]=sprite_role
	if h.get("semantic_only",false): pose.alpha=0.0
	if not h.get("construct_only",false) and h.has("link"):
		for prop in field.session.enemies:
			if prop.get("boss_construct",false) and prop.hp>0 and prop.get("construct_link","")==h.link and prop.art_key==h.get("art_key","") and prop.p.distance_to(h.p)<10:
				var prop_record := {"art_key":prop.art_key,"vfx_role":prop.vfx_role,"shape":"circle","construct_only":true}
				var prop_role := Sequence.resolve(prop_record,str(prop.vfx_role))
				if prop.vfx_role==h.get("vfx_role","") or prop_role==sprite_role:
					pose.alpha=0.0 # One linked object owns its physical body, including a furnace vent.
	var anchor: Vector2=h.p
	if pose.kind=="projectile": anchor+=Geometry.aim(h)*float(h.radius)
	if pose.kind=="stream": anchor+=Geometry.aim(h)*float(h.get("stream_forward",0))
	anchor+=pose.offset
	var screen_point := get_global_transform()*anchor
	screen_point.y-=float(pose.lift)
	var native: Vector2=item.body.texture.get_size()
	var uniform_scale := float(pose.size)/maxf(native.x,native.y)
	if not sequence.is_empty(): uniform_scale=float(pose.get("uniform_scale",maxf(1.0,float(h.radius)-float(h.get("socket_forward",0)))/float(sequence.reach)))
	if pose.kind=="attached":
		var projected := get_global_transform().basis_xform(Geometry.aim(h)).normalized()
		pose.angle+=projected.angle()
		screen_point+=get_global_transform().basis_xform(Geometry.aim(h)*float(h.get("socket_forward",0)))
		var pivot: Vector2=sequence.pivot if not sequence.is_empty() else pose.pivot*native
		screen_point-=pivot.rotated(float(pose.angle))*uniform_scale
	if not sequence.is_empty() and pose.kind!="attached": screen_point-=sequence.pivot.rotated(float(pose.angle))*uniform_scale
	if pose.kind=="stream" and str(h.get("delivery","")) in ["breath","beam","chain","thread"]:
		screen_point.y-=float(h.get("stream_lift",0))
	if sequence.is_empty() and pose.kind in ["strike","vent","vent_source"]: screen_point.y-=native.y*uniform_scale*(.424 if pose.kind=="strike" else .438)
	var contact_key: String=item.body.texture.resource_path.get_file().get_basename()
	if sequence.is_empty() and pose.kind!="attached" and Contacts.DATA.has(contact_key):
		# New physical entities use their measured contact point, not a generic sprite centre.
		if pose.kind=="vent_source": screen_point.y+=native.y*uniform_scale*.438
		else: screen_point.y+=float(pose.size)*.27
		var contact: Vector2=Contacts.DATA[contact_key]*native
		screen_point-=contact.rotated(float(pose.angle))*uniform_scale
	if sequence.is_empty() and pose.kind=="projectile" and str(h.get("art_key","")) in ["storm","wing"]:
		var projected := get_global_transform().basis_xform(Geometry.aim(h)).normalized()
		pose.angle=projected.angle()-PI*.5 # The new bolt points down in its native image.
		screen_point-=projected*native.y*uniform_scale*.424 # Bolt tip is the authoritative live projectile.
	# Screen-space upright entities: ground projection never squashes falling art.
	item.body.global_transform=Transform2D(float(pose.angle),Vector2.ONE*uniform_scale,0,screen_point)
	# Clip continuous ground materials to gameplay geometry; airborne entities keep their silhouette.
	var clip: bool=not h.get("construct_only",false) and pose.kind in ["sweep","orbit","vortex","portal","projectile"]
	item.birth.set_shader_parameter("clip_ground",clip)
	if clip:
		var ground_pose := get_global_transform()*Transform2D(Geometry.aim(h).angle(),h.p)
		var body_to_ground: Transform2D=ground_pose.affine_inverse()*item.body.global_transform
		item.birth.set_shader_parameter("mask_x",body_to_ground.x)
		item.birth.set_shader_parameter("mask_y",body_to_ground.y)
		item.birth.set_shader_parameter("mask_origin",body_to_ground.origin)
		var dimensions := Geometry.shader_data(h)
		for key in ["shape","radius","inner","arc","gap"]: item.birth.set_shader_parameter(key,dimensions[key])
	for key in ["reveal","opacity","flash","from_ground"]:
		item.birth.set_shader_parameter(key,pose.alpha if key=="opacity" else pose[key])
	item.birth.set_shader_parameter("stroke_mode",bool(pose.get("stroke_mode",false)))
	item.birth.set_shader_parameter("stroke_phase",float(pose.get("stroke_phase",0)))
	item.birth.set_shader_parameter("stroke_arc",float(pose.get("stroke_arc",1.05)))
	item.birth.set_shader_parameter("stroke_reverse",bool(pose.get("stroke_reverse",false)))
	# Live projectiles carry their own outline plus bloom, in the boss's own tone.
	# Everything else keeps a zeroed shell, so no other staged entity changes.
	var shell: float=PROJECTILE_SHELL if pose.kind=="projectile" else 0.0
	item.birth.set_shader_parameter("rim_strength",shell)
	# Source-art pixels in UV; the bloom reaches PROJECTILE_SHELL_REACH of them
	# outward.  canvas_item shaders have no TEXEL_SIZE builtin.
	item.birth.set_shader_parameter("rim_step",Vector2.ONE/maxf(1.0,native.x)*PROJECTILE_SHELL_REACH)
	item.birth.set_shader_parameter("rim_tone",Art.color(h))
	update_sequence_copies(item,h,pose,sequence)

func sequence_pose(h: Dictionary, pose: Dictionary, frame: Dictionary) -> Dictionary:
	var style := str(frame.style)
	var physical: bool=str(h.get("delivery","")) in Design.PHYSICAL
	pose.angle=0.0; pose.offset=Vector2.ZERO; pose.reveal=1.0; pose.from_ground=false
	var projected := get_global_transform().basis_xform(Geometry.aim(h)).normalized()
	if physical:
		pose.kind="attached"; pose.lift=float(h.get("socket_height",55))
		pose.pivot=Vector2.ZERO
		var projection := get_global_transform().basis_xform(Geometry.aim(h)).length()
		pose["uniform_scale"]=maxf(1.0,float(h.radius)-float(h.get("socket_forward",0)))*projection/float(frame.reach)
	elif h.shape=="capsule":
		pose.kind="projectile"; pose.lift=0.0; pose.angle=projected.angle()
		# Keep the projectile's forward tip at its authoritative live position.
		pose["uniform_scale"]=float(h.inner)*2.0/maxf(1,float(frame.ink_height))
		pose.offset=-Geometry.aim(h)*float(frame.reach)*float(pose.uniform_scale)
	elif h.shape in ["lane","line"]:
		pose.kind="stream"; pose.lift=0.0; pose.angle=projected.angle()
		var width := 44.0 if h.shape=="line" else float(h.inner)
		pose["uniform_scale"]=minf(240.0/float(frame.reach),width*1.5/maxf(1,float(frame.ink_height)))
	elif h.shape in ["ring","gap_ring","arc"] or float(h.get("inner",0))>0:
		pose.kind="orbit"; pose.lift=0.0
		pose["uniform_scale"]=minf(110.0/float(frame.reach),(float(h.radius)-float(h.inner))*.55/maxf(1,float(frame.ink_height)))
		pose.alpha=0.0 # Authored ribbons around the perimeter are drawn below, safe centre stays empty.
	else:
		pose.kind="fall" if style=="fall" else "grow" if style in ["ground","entity"] else "impact"
		pose.lift=0.0
		if style=="fall" and not h.get("fired",h.get("active",false)):
			var lead := clampf(1-float(h.get("time",0))/maxf(.01,float(h.get("windup",h.get("total",1)))),0,1)
			pose.lift=(1-lead)*(1-lead)*140
		pose["uniform_scale"]=clampf(float(h.radius)*1.7,60,200)/float(frame.height)
		if h.get("construct_only",false): pose["uniform_scale"]=110.0/float(frame.height)
		if style in ["field","projectile","blade","directional","flow"]:
			pose.offset=-Geometry.aim(h)*float(frame.reach)*float(pose.uniform_scale)*.5
			pose.angle=projected.angle()
			pose.kind="vortex" # These are horizontal flowing fields, not upright shrines.
	return pose

## Several small flowing cells follow the real path, all at uniform scale.
## No square image is stretched across the entire lane or enlarged into a seal.
func update_sequence_copies(item: Dictionary, h: Dictionary, pose: Dictionary, frame: Dictionary) -> void:
	if not item.has("copies"): item["copies"]=[]
	for copy in item.copies: copy.visible=false
	if frame.is_empty() or str(frame.style)=="attached": return
	var placements: Array=[]
	var scale := float(pose.get("uniform_scale",1))
	var alpha := float(pose.alpha)
	if pose.kind=="stream":
		var segment := maxf(35.0,float(frame.reach)*scale*.80)
		var source_x := float(h.get("stream_forward",0))
		var count := clampi(ceili((float(h.radius)-source_x)/segment),1,14)
		for i in range(1,count): placements.append({"p":h.p+Geometry.aim(h)*(source_x+segment*i),"angle":pose.angle})
	elif pose.kind=="orbit":
		var middle := (float(h.radius)+float(h.inner))*.5
		var count := clampi(ceili(TAU*middle/90),8,24)
		alpha=Sequence.state(h,float(item.impact_age),str(item.sequence_key),float(item.tail)).opacity*.7
		for i in count:
			var angle := i*TAU/count
			var at: Vector2=h.p+Vector2.from_angle(angle)*middle
			if Geometry.contains(h,at): placements.append({"p":at,"angle":get_global_transform().basis_xform(Vector2.from_angle(angle+PI*.5)).angle()})
	for i in placements.size():
		if item.copies.size()<=i:
			var copy := Sprite2D.new(); copy.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			var mat := ShaderMaterial.new(); mat.shader=BIRTH_SHADER; copy.material=mat
			add_child(copy); item.copies.append(copy)
		var copy: Sprite2D=item.copies[i]
		copy.visible=true; copy.texture=frame.texture
		var at: Vector2=get_global_transform()*placements[i].p
		if pose.kind=="stream": at.y-=float(h.get("stream_lift",0))*maxf(0.0,1.0-placements[i].p.distance_to(h.p)/maxf(1,float(h.radius)))
		at-=frame.pivot.rotated(float(placements[i].angle))*scale
		copy.global_transform=Transform2D(float(placements[i].angle),Vector2.ONE*scale,0,at)
		copy.material.set_shader_parameter("opacity",alpha)
		copy.material.set_shader_parameter("clip_ground",pose.kind=="orbit")
		var ground_pose := get_global_transform()*Transform2D(Geometry.aim(h).angle(),h.p)
		var mask := ground_pose.affine_inverse()*copy.global_transform
		copy.material.set_shader_parameter("mask_x",mask.x); copy.material.set_shader_parameter("mask_y",mask.y)
		copy.material.set_shader_parameter("mask_origin",mask.origin)
		for key in ["shape","radius","inner","arc","gap"]: copy.material.set_shader_parameter(key,Geometry.shader_data(h)[key])


static func render_record(record: Dictionary) -> Dictionary:
	var h := record.duplicate()
	h["art_key"]=Art.identity(h)
	if not h.has("time"):
		h["time"]=-float(h.get("age",0)) if h.get("active",false) else float(h.get("delay",0))
	return h

static func minion_hazard(fx: Dictionary) -> Dictionary:
	var h := fx.duplicate()
	var floor_index := clampi(int(fx.floor),0,4)
	h["choreographed"]=true
	h["art_key"]=["grove","furnace","astral","storm","obsidian"][floor_index]
	h["vfx_role"]=["roots","pyre","starfall","chain","scar"][floor_index]
	h["semantic_only"]=true
	h["attack_family"]=Semantics.family(str(fx.get("fx_move","")),floor_index)
	h["standalone_key"]="spark"
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
	if h.get("preview_only",false): return
	if str(h.get("delivery","")) in Design.PHYSICAL: return # The original attached artwork carries the strike.
	if h.get("construct_only",false):
		if h.get("art_key","")=="furnace" and h.vfx_role=="kiln":
			var burning: bool=h.get("vent_active",false)
			if item.get("vent_burning",null)!=burning:
				particles.stop(token)
				particles.start(token,h.p,Vector2.UP,Color("ffba73") if burning else Color("868078"),"ember" if burning else "dust","ambient",99,8,10 if burning else 4)
				item["vent_burning"]=burning
		return
	var style := Semantics.style(str(h.get("fx_move","")),int(h.get("floor",0))) if h.get("semantic_only",false) else particles.boss_style(str(h.get("art_key","knight")))
	var color := Art.color(h)
	var aim := Geometry.aim(h)
	var at: Vector2=h.p
	var projectile: bool=h.shape=="capsule" and not h.get("semantic_only",false)
	if projectile: at+=aim*float(h.radius)
	if not item.get("particle_started",false):
		item["particle_started"]=true
		if projectile:
			particles.start(token,at,aim,color,style,"trail",99,4,24)
		elif not active:
			if h.shape in ["ring","gap_ring","arc"] or float(h.get("inner",0))>0:
				particles.start(token,at,aim,Color(color,.5),style,"ring",maxf(.1,float(h.get("time",.6))),float(h.radius),18,float(h.get("inner",0)))
				particles.emitters[token]["mask"]=h
			else:
				particles.start(token,at,aim,Color(color,.35),style,"ambient",maxf(.1,float(h.get("time",h.get("delay",.6)))),clampf(float(h.radius)*.18,8,24),8)
				particles.emitters[token]["mask"]=h
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
		else:
			var before: int=particles.particles.size()
			particles.burst(at,aim,color,style,clampi(int(h.radius*.10),5,14),.55,PI)
			for n in range(before,particles.particles.size()): particles.particles[n]["mask"]=h
		if h.shape in ["line","lane","capsule"]:
			particles.start(token,at,aim,color,style,"line",99,float(h.radius),28)
			particles.emitters[token].width=minf(24,float(h.get("inner",44)))
		elif h.shape in ["ring","gap_ring","arc"] or float(h.get("inner",0))>0:
			# Ring particles stay in the actual annulus; the safe opening is respected below.
			particles.start(token,at,aim,color,style,"ring",99,float(h.radius),28,float(h.get("inner",0)))
			particles.emitters[token]["mask"]=h
		else:
			particles.start(token,at,aim,color,style,"ambient",99,minf(45,float(h.radius)*.4),10)
			particles.emitters[token]["mask"]=h
	if active: particles.move(token,at,aim)
	if particles.emitters.has(token) and particles.emitters[token].has("mask"):
		particles.emitters[token].mask=h
		particles.update_mask(token,h)
