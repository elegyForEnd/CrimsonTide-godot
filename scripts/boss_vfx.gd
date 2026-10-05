extends Node2D
## Independent painted boss effects; authoritative hazard geometry stays readable.
## Source artwork is only scaled uniformly; telegraphs use untextured geometry.
const Presentation = preload("res://scripts/boss_presentation.gd")
const Tactics = preload("res://scripts/boss_tactics.gd")
var field: Node2D
const Art = preload("res://scripts/boss_effect_art.gd")
const Language=preload("res://scripts/boss_effect_language.gd")
var effects: Array[Dictionary]=[]
var energy = preload("res://scripts/energy_bursts.gd").new()
var cinematic = preload("res://scripts/boss_cinematic.gd").new()
var elapsed := 0.0
var damage_visual = preload("res://scripts/boss_damage_visual.gd").new()
var warmed: Dictionary={}

func _ready() -> void:
	z_index=2
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	add_child(energy)
	damage_visual.field=field
	add_child(damage_visual)
	var layer := CanvasLayer.new()
	layer.layer=3
	add_child(layer)
	cinematic.field=field
	layer.add_child(cinematic)
	warm_assets()

func warm_assets() -> void:
	var keys: Array=[]
	for e in field.session.enemies:
		if e.get("raid_boss",false) or e.get("mini_boss",false): keys.append(Art.identity(e))
	if not field.session.raid.is_empty() and not field.session.roguelike.active(field.session):
		keys.append(Art.KEYS[clampi(int(field.session.raid.get("kind",0)),0,2)])
	for key in keys:
		if warmed.has(key): continue
		warmed[key]=true
		Art.warm(key)
	Art.finish_warming()

func reset() -> void:
	damage_visual.reset()
	effects.clear()
	energy.reset()
	cinematic.reset()
	queue_redraw()

func _exit_tree() -> void:
	effects.clear()

func event(data: Dictionary) -> void:
	if data.kind!="boss-vfx" or data.p.distance_to(field.camera)>1400: return
	var fx := data.duplicate(true)
	fx["age"]=0.0
	fx["duration"]={"charge":0.5,"release":0.48,"entrance":1.8,"phase":1.65,"fall":1.9,"guard":0.35,"break":0.7}.get(data.action,0.6)
	if data.action=="charge": fx.duration=maxf(.35,float(data.get("total",.5)))
	if data.action in ["release","fall","break"]:
		for i in range(effects.size()-1,-1,-1):
			if effects[i].id==data.id and effects[i].action=="charge": effects.remove_at(i)
	if effects.size()>=96: effects.pop_front()
	effects.append(fx)
	animate_event(fx)
	if data.action in ["release","break","entrance","phase","fall"]:
		var strength := 0.26 if data.get("shape","")=="line" else 0.42
		if data.action in ["phase","fall"]: strength=0.62
		var proximity := clampf(1-data.p.distance_to(field.camera)/1000.0,0,1)
		field.combat.trauma=maxf(field.combat.trauma,strength*proximity)

func _process(dt: float) -> void:
	if not field.visible: return
	warm_assets()
	elapsed+=dt
	energy.advance(dt)
	if field.has_method("ground_transform"):
		transform=field.ground_transform()
	else:
		position=field.offset
	for i in range(effects.size()-1,-1,-1):
		effects[i].age+=dt
		if effects[i].action=="charge":
			var active := false
			for e in field.session.enemies:
				if e.id==effects[i].id and e.hp>0 and float(e.get("attack_time",0))>0: active=true
			if not active:
				energy.cancel_charge(int(effects[i].id))
				effects.remove_at(i)
				continue
			# Follow the live caster; a preparation effect must never hang at an old position.
			for caster in field.session.enemies:
				if caster.id==effects[i].id: effects[i].p=caster.p; break
		if effects[i].age>=effects[i].duration: effects.remove_at(i)
	queue_redraw()

func stamp(target: CanvasItem, data: Dictionary, role: String, at: Vector2, size: Vector2, angle: float, opacity: float) -> void:
	var tex := Art.texture(Art.identity(data),role)
	if tex==null: return
	set_target_transform(target,at,angle)
	var fitted := tex.get_size()*minf(size.x/tex.get_width(),size.y/tex.get_height())
	target.draw_texture_rect(tex,Rect2(-fitted*.5,fitted),false,Color(1,1,1,clampf(opacity,0,1)))
	set_target_transform(target)

## Circumscribed sprites fit entirely inside an annulus and outside its safe gap.
func ring_points(fx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var radius := float(fx.get("radius",150))
	var inner := float(fx.get("inner",0))
	var mid := (radius+inner)*.5
	var diameter := minf(100,(radius-inner)*.62)
	if diameter<=0 or mid<=0: return result
	var margin := asin(clampf(diameter*.7072/mid,0,1))
	var shape := str(fx.get("shape","ring"))
	var aim: Vector2=fx.get("aim",Vector2.RIGHT)
	var start := 0.0
	var end := TAU
	if shape=="gap_ring":
		start=float(fx.get("gap",.5))+margin
		end=TAU-float(fx.get("gap",.5))-margin
	elif shape=="arc":
		start=-float(fx.get("arc",1.05))+margin
		end=float(fx.get("arc",1.05))-margin
	if end<=start: return result
	var count := clampi(ceili((end-start)*mid/100),3,24)
	for i in count:
		var angle := lerpf(start,end,(i+.5)/count)+(aim.angle() if shape!="ring" else 0.0)
		result.append({"p":Vector2.from_angle(angle)*mid,"size":diameter,"angle":angle+PI*.5})
	return result

func hazard(target: CanvasItem, h: Dictionary, kind: int = -1) -> void:
	if h.get("choreographed",false): return
	var art_data := with_theme(h,int(h.get("boss_kind",0)) if kind<0 else kind)
	if h.p.distance_to(field.camera)>1400: return
	var progress := 1.0-clampf(float(h.time)/maxf(.01,float(h.total)),0,1)
	var fired: bool=h.get("fired",false)
	var shape: String=h.shape
	var alpha := .40+progress*.44
	if fired: alpha=.5+sin(elapsed*9.0)*.12 if h.has("pulse_interval") else .85*clampf(1+float(h.time)/.30,0,1)
	var direction: Vector2=h.aim
	var rotation := direction.angle() if shape in ["line","cone","lane","gap_ring","arc"] else 0.0
	set_target_transform(target,h.p,rotation)
	var theme_color: Color=Art.color(art_data)
	var color := Color(theme_color,alpha)
	var radius := float(h.radius)
	var inner := float(h.get("inner",0))
	if shape in ["line","lane"]:
		var half_width: float=inner if shape=="lane" else 44.0
		target.draw_rect(Rect2(-22,-half_width,radius+22,half_width*2),Color(color,alpha*.09))
		target.draw_rect(Rect2(-22,-half_width,radius+22,half_width*2),color,false,2,true)
		for i in 6:
			var x := lerpf(0,radius,(i+.5)/6.0)
			target.draw_line(Vector2(x,-half_width),Vector2(x,-half_width+8),color,2,true)
			target.draw_line(Vector2(x,half_width-8),Vector2(x,half_width),color,2,true)
	elif shape=="gap_ring":
		var gap: float=float(h.get("gap",0.5))
		for i in 72:
			var a := lerpf(gap,TAU-gap,float(i)/72.0)
			var b := lerpf(gap,TAU-gap,float(i+1)/72.0)
			target.draw_colored_polygon(PackedVector2Array([Vector2.from_angle(a)*inner,Vector2.from_angle(a)*radius,Vector2.from_angle(b)*radius,Vector2.from_angle(b)*inner]),Color(color,alpha*.13))
		target.draw_arc(Vector2.ZERO,radius,gap,TAU-gap,96,color,2,true)
		target.draw_arc(Vector2.ZERO,inner,gap,TAU-gap,96,color,2,true)
		for a in [-gap,gap]: target.draw_line(Vector2.from_angle(a)*inner,Vector2.from_angle(a)*radius,Color("a5ffdb",alpha),3,true)
	else:
		var arc := float(h.get("arc",1.05)) if shape in ["cone","arc"] else PI
		for i in 48:
			var a := Vector2.from_angle(lerpf(-arc,arc,i/48.0))
			var b := Vector2.from_angle(lerpf(-arc,arc,(i+1)/48.0))
			var points := PackedVector2Array([a*inner,a*radius,b*radius])
			if inner>0: points.append(b*inner)
			target.draw_colored_polygon(points,Color(color,alpha*.10))
		target.draw_arc(Vector2.ZERO,radius,-arc,arc,65,color,2,true)
		if inner>0: target.draw_arc(Vector2.ZERO,inner,-arc,arc,65,color,2,true)
		if shape in ["cone","arc"]:
			for a in [-arc,arc]: target.draw_line(Vector2.from_angle(a)*inner,Vector2.from_angle(a)*radius,color,2,true)
		if not fired: target.draw_arc(Vector2.ZERO,radius-5,-arc,lerpf(-arc,arc,maxf(.001,progress)),65,Color(color,alpha*.6),3,true)
	set_target_transform(target)
	# A shrinking charged apparition signals timing, never a shrinking hitbox.
	if not fired and shape=="circle":
		var size := Vector2.ONE*minf(float(h.radius)*1.3,125)*(1.1-progress*.28)
		stamp(target,art_data,"crest",h.p-Vector2(0,35+progress*15),size,0,.22+progress*.4)
	if h.get("perimeter",false):
		for i in 8:
			var at: Vector2=h.p+Vector2.from_angle(i*TAU/8)*((float(h.radius)+float(h.inner))*.5)
			stamp(target,art_data,"burst",at-Vector2(0,32),Vector2(85,120),0,(.22+progress*.3) if not fired else alpha)

func knight(target: CanvasItem, e: Dictionary) -> void:
	if e.get("choreo_cast",false): return
	if float(e.get("attack_time",0))<=0: return
	var move: String=e.get("move_name","combo")
	var spec: Dictionary=Tactics.KNIGHT_MOVES.get(move,Tactics.KNIGHT_MOVES.combo)
	var passed: float=e.attack_total-e.attack_time
	var mark := -1.0
	var previous := 0.0
	for hit in spec.marks:
		if passed<float(hit)+.16:
			mark=float(hit)
			break
		previous=float(hit)
	if mark<0: return
	var shape := "line" if move=="thrust" else "circle" if move=="storm" else "cone"
	hazard(target,{"p":e.p,"aim":e.attack_aim,"shape":shape,"radius":340.0 if shape=="line" else spec.reach,
		"arc":spec.arc,"inner":0,"time":mark-passed,"total":mark-previous,"fired":passed>=mark},3)

func with_theme(data: Dictionary, kind: int) -> Dictionary:
	var copy := data.duplicate()
	copy["boss_kind"]=kind
	return copy

func _draw() -> void:
	for prop in field.session.enemies:
		if prop.get("boss_construct",false) and prop.hp>0:
			var lift := Language.construct_health_lift(prop)
			draw_rect(Rect2(prop.p+Vector2(-25,-lift),Vector2(50,4)),Color("211b30"))
			draw_rect(Rect2(prop.p+Vector2(-25,-lift),Vector2(50*prop.hp/prop.max_hp,4)),Color("b6f4df"))
	for e in field.session.enemies:
		if not e.get("raid_boss",false) and not e.get("mini_boss",false) and int(e.type)!=4: continue
		if e.p.distance_to(field.camera)>1150: continue
		if float(e.get("guard_time",0))>0:
			var direction: Vector2=e.get("guard_aim",Vector2.RIGHT)
			Language.actor(self,Art.identity(e),e.p,direction,"charge",elapsed,.8)
	for fx in effects:
		if fx.action=="release" and fx.get("choreographed",false): continue
		var t: float=fx.age/fx.duration
		var fade := pow(1-t,1.6)
		var at: Vector2=fx.p
		var aim: Vector2=fx.get("aim",Vector2.RIGHT)
		if fx.action!="release":
			Language.actor(self,Art.identity(fx),at,aim,str(fx.action),float(fx.age),float(fx.duration))
			continue
		match str(fx.action):
			"release":
				var shape: String=fx.get("shape","circle")
				var radius: float=fx.get("radius",150.0)
				if shape in ["line","lane"]:
					var width := float(fx.get("inner",44)) if shape=="lane" else 44.0
					stamp(self,fx,"lance",at+aim*minf(radius*.25,70),Vector2.ONE*minf(150,width*2),aim.angle(),fade*.9)
				elif shape=="cone":
					var travel := 1-pow(1-t,2.4)
					var turn := -.12 if int(fx.get("part",0))%2==0 else .12
					stamp(self,fx,"slash",at+aim*radius*lerpf(.30,.56,travel),Vector2.ONE*radius*1.35,aim.angle()+turn*(1-t),fade*.92)
				elif shape in ["ring","gap_ring","arc"]:
					for point in ring_points(fx):
						stamp(self,fx,"lance",at+point.p,Vector2.ONE*point.size,point.angle,fade*.85)
				else:
					stamp(self,fx,"burst",at-Vector2(0,radius*.48),Vector2.ONE*radius*2.0*(1+t*.10),0,fade*.92)

func animate_event(fx: Dictionary) -> void:
	if fx.action=="release" and fx.get("choreographed",false): return
	var action := str(fx.action)
	var at: Vector2=fx.p
	var col := Art.color(fx)
	var source := int(fx.id)
	if action in ["release","break","fall"]: energy.cancel_charge(source)
	# Painted bodies carry the attack; a few brief particles accent the apex.
	if action in ["entrance","phase","fall"]:
		cinematic.play(fx)
		energy.particles(at-Vector2(0,45),col,18,Vector2.UP,100,.6)
	elif action=="release" and fx.get("shape","") not in ["ring","gap_ring","arc"]:
		energy.particles(at-Vector2(0,15),col,6,fx.get("aim",Vector2.RIGHT),25,.35)
	elif action=="break":
		energy.particles(at-Vector2(0,30),col,12,Vector2.UP,120,.5)

func set_target_transform(target: CanvasItem, at: Vector2 = Vector2.ZERO, angle: float = 0.0) -> void:
	if target==field and field.has_method("set_world_transform"):
		field.set_world_transform(at,angle)
	else:
		target.draw_set_transform((field.offset if target==field else Vector2.ZERO)+at,angle)
