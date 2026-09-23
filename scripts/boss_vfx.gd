extends Node2D
## Original art + moving shader volumes + textured particles + timed cut-ins.
## Source artwork is only scaled uniformly; telegraphs use untextured geometry.
const Presentation = preload("res://scripts/boss_presentation.gd")
const Tactics = preload("res://scripts/boss_tactics.gd")
const COLORS := [Color("c8a8ff"),Color("f987a4"),Color("ffe5ad"),Color("c4e9ff")]
var field: Node2D
var sheets: Array[Texture2D]=[]
var effects: Array[Dictionary]=[]
var energy = preload("res://scripts/energy_bursts.gd").new()
var cinematic = preload("res://scripts/boss_cinematic.gd").new()
var elapsed := 0.0

func _ready() -> void:
	z_index=2
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	add_child(energy)
	var layer := CanvasLayer.new()
	layer.layer=3
	add_child(layer)
	cinematic.field=field
	layer.add_child(cinematic)
	for key in Presentation.KEYS:
		sheets.append(load("res://assets/bosses/vfx/"+key+".png"))

func reset() -> void:
	effects.clear()
	energy.reset()
	cinematic.reset()
	queue_redraw()

func _exit_tree() -> void:
	effects.clear()
	sheets.clear()

func event(data: Dictionary) -> void:
	if data.kind!="boss-vfx" or data.p.distance_to(field.camera)>1400: return
	var fx := data.duplicate(true)
	fx["age"]=0.0
	fx["duration"]={"charge":0.5,"release":0.7,"entrance":1.8,"phase":1.65,"fall":1.9,"guard":0.35,"break":0.7}.get(data.action,0.6)
	if data.action=="charge": fx.duration=maxf(.35,float(data.get("total",.5)))
	if data.action in ["release","fall","break"]:
		for i in range(effects.size()-1,-1,-1):
			if effects[i].id==data.id and effects[i].action=="charge": effects.remove_at(i)
	if effects.size()>=100: effects.pop_front()
	effects.append(fx)
	animate_event(fx)
	if data.action in ["release","break","entrance","phase","fall"]:
		var strength := 0.26 if data.get("shape","")=="line" else 0.42
		if data.action in ["phase","fall"]: strength=0.62
		var proximity := clampf(1-data.p.distance_to(field.camera)/1000.0,0,1)
		field.combat.trauma=maxf(field.combat.trauma,strength*proximity)

func _process(dt: float) -> void:
	if not field.visible: return
	elapsed+=dt
	energy.advance(dt)
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
		if effects[i].age>=effects[i].duration: effects.remove_at(i)
	queue_redraw()

func region(kind: int, cell: int) -> Rect2:
	var unit := sheets[kind].get_size()/4.0
	return Rect2(Vector2(cell%4,cell/4)*unit+Vector2.ONE,unit-Vector2.ONE*2)

func stamp(target: CanvasItem, kind: int, cell: int, at: Vector2, size: Vector2, angle: float, opacity: float, brightness: float = 1.0) -> void:
	var origin: Vector2=field.offset if target==field else Vector2.ZERO
	target.draw_set_transform(origin+at,angle)
	var source := region(kind,cell)
	var fitted := source.size*minf(size.x/source.size.x,size.y/source.size.y)
	target.draw_texture_rect_region(sheets[kind],Rect2(-fitted/2,fitted),source,Color(brightness,brightness,brightness,opacity))
	target.draw_set_transform(origin)

func hazard(target: CanvasItem, h: Dictionary, kind: int = -1) -> void:
	kind=int(h.get("boss_kind",0)) if kind<0 else kind
	if h.p.distance_to(field.camera)>1400: return
	var progress := 1.0-clampf(float(h.time)/maxf(.01,float(h.total)),0,1)
	var fired: bool=h.get("fired",false)
	var shape: String=h.shape
	var alpha := .40+progress*.44
	if fired: alpha=.5+sin(elapsed*9.0)*.12 if h.has("pulse_interval") else .85*clampf(1+float(h.time)/.30,0,1)
	var direction: Vector2=h.aim
	var rotation := direction.angle() if shape in ["line","cone","lane","gap_ring","arc"] else 0.0
	var origin: Vector2=field.offset if target==field else Vector2.ZERO
	target.draw_set_transform(origin+h.p,rotation)
	var theme_color: Color=Presentation.theme_color(kind,h.get("hidden_final",false))
	if h.get("dragon_boss",false):
		theme_color=Color("9ce9ff")
	elif h.get("wild_boss",false):
		theme_color=[Color("d9aa68"),Color("87dfff"),Color("b86bff")][clampi(int(h.get("wild_kind",0)),0,2)]
	elif h.get("final_form",false):
		theme_color=Color("ff426c")
	elif int(h.get("mini_kind",-1))==0:
		theme_color=Color("a8dbff")
	elif int(h.get("mini_kind",-1))==1:
		theme_color=Color("ff8d66")
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
	target.draw_set_transform(origin)
	# A shrinking charged apparition signals timing, never a shrinking hitbox.
	if not fired and shape=="circle":
		var size := Vector2.ONE*minf(float(h.radius)*1.3,125)*(1.1-progress*.28)
		stamp(target,kind,3 if kind==2 else 12,h.p-Vector2(0,35+progress*15),size,0,.22+progress*.4)
	if h.get("perimeter",false):
		for i in 8:
			var at: Vector2=h.p+Vector2.from_angle(i*TAU/8)*((float(h.radius)+float(h.inner))*.5)
			stamp(target,kind,5,at-Vector2(0,32),Vector2(85,120),0,(.22+progress*.3) if not fired else alpha)

func knight(target: CanvasItem, e: Dictionary) -> void:
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

func _draw() -> void:
	if sheets.size()!=4: return
	# Live, cancellable posture layer: small enough to keep silhouettes readable.
	for e in field.session.enemies:
		if not e.get("raid_boss",false) and int(e.type)!=4: continue
		if e.p.distance_to(field.camera)>1150: continue
		var kind: int=Presentation.theme(e)
		if float(e.get("guard_time",0))>0:
			var direction: Vector2=e.get("guard_aim",Vector2.RIGHT)
			stamp(self,kind,14,e.p+direction*42-Vector2(0,28),Vector2(105,145),0,.65+sin(elapsed*9)*.1)
		elif float(e.get("attack_time",0))>0:
			var passed: float=e.attack_total-e.attack_time
			var next := 99.0
			for mark in e.get("attack_marks",[]):
				if float(mark)>passed: next=minf(next,float(mark)-passed)
			if next<1.8:
				var charge := 1-clampf(next/1.8,0,1)
				stamp(self,kind,12,e.p-Vector2(0,55),Vector2(105,165)*(1+charge*.18),0,.16+charge*.35)
	for fx in effects:
		var kind: int=fx.boss_kind
		var t: float=fx.age/fx.duration
		var fade := pow(1-t,1.3)
		var at: Vector2=fx.p
		var aim: Vector2=fx.get("aim",Vector2.RIGHT)
		match str(fx.action):
			"release":
				var shape: String=fx.get("shape","circle")
				var radius: float=fx.get("radius",150.0)
				if shape in ["line","lane"]:
					# Repeat native-aspect lance fragments; never stretch a square tile into a beam.
					for segment in maxi(1,ceili(radius/150)):
						var travel := minf(radius,70+segment*150+t*100)
						stamp(self,kind,9 if t<.34 else 10,at+aim*travel,Vector2.ONE*170,aim.angle(),fade*.65,1.5)
				elif shape=="cone":
					# Keep the hand-painted slash facing the attack direction while its
					# center follows the outward-moving wave; never spin it over time.
					var travel := 1-pow(1-t,2.4)
					var cell := 7 if kind==0 else 11
					stamp(self,kind,cell,at+aim*radius*lerpf(.12,.72,travel),Vector2.ONE*radius*1.05,
						aim.angle()+(PI if kind==3 else 0),fade*.72,1.2)
				elif shape in ["ring","gap_ring","arc"]:
					# Ring burst remains on its annulus. Never flash the safe center.
					var h := fx.duplicate()
					h["time"]=-t*.24
					h["total"]=1.0
					h["fired"]=true
					hazard(self,h,kind)
				else:
					stamp(self,kind,5 if t<.55 else 6,at-Vector2(0,radius*.45),Vector2(radius*2.1,radius*2.5)*(1+t*.15),0,fade*.9,1.25)
				if int(fx.get("part",0))==0 and shape not in ["ring","gap_ring","arc"]:
					stamp(self,kind,13,at-Vector2(0,24),Vector2.ONE*120*(1+t),0,fade*.6,1.25)
			"charge":
				var move: String=fx.get("move","")
				var charged := sin(t*PI*.5)
				stamp(self,kind,12,at-Vector2(0,40),Vector2(115,175),0,charged*.4)
				if move in ["slow_bell","bell","crown","coronation","eclipse","delayed","storm"]:
					var cell := 14 if move=="eclipse" else 3
					stamp(self,kind,cell,at-Vector2(0,120+charged*25),Vector2(160,195)*(1+charged*.2),0,charged*.48)
			"guard", "break":
				stamp(self,kind,13,at-Vector2(0,35),Vector2.ONE*(190 if fx.action=="break" else 90)*(1+t*.5),0,fade)
			"entrance", "phase":
				var cell := 14 if kind==2 and int(fx.get("phase",1))>=3 else 3
				stamp(self,kind,cell,at-Vector2(0,160+t*50),Vector2(310,370)*(1+t*.25),0,sin(t*PI)*.82,1.15)
				stamp(self,kind,12,at-Vector2(0,40),Vector2(250,300),0,fade*.7)
			"fall":
				stamp(self,kind,6,at-Vector2(0,75+t*80),Vector2.ONE*(230+t*180),t*.3,fade*.9)
				stamp(self,kind,15,at-Vector2(0,90+t*160),Vector2.ONE*(240+t*260),-t*.2,sin(t*PI)*.75)
		if fx.get("shape","") not in ["ring","gap_ring","arc"] and fx.action in ["release","phase","fall"] and (int(fx.get("part",0))==0 or fx.get("shape","")=="circle"):
			for i in 4:
				var ray := Vector2.from_angle(float(i)*TAU/4+float(fx.id))
				stamp(self,kind,15,at+ray*(35+t*100)-Vector2(0,30+t*45),Vector2.ONE*(28+t*18),ray.angle(),fade*.7)

func animate_event(fx: Dictionary) -> void:
	var at: Vector2=fx.p
	var kind := int(fx.boss_kind)
	var col: Color=Presentation.theme_color(kind,fx.get("hidden_final",false))
	if fx.get("dragon_boss",false):
		col=Color("9ce9ff")
	elif fx.get("wild_boss",false):
		col=[Color("d9aa68"),Color("87dfff"),Color("b86bff")][clampi(int(fx.get("wild_kind",0)),0,2)]
	elif fx.get("final_form",false):
		col=Color("ff426c")
	elif int(fx.get("mini_kind",-1))==0:
		col=Color("a8dbff")
	elif int(fx.get("mini_kind",-1))==1:
		col=Color("ff8d66")
	var source := int(fx.id)
	var aim: Vector2=fx.get("aim",Vector2.RIGHT)
	var action := str(fx.action)
	if action in ["release","break","fall"]: energy.cancel_charge(source)
	if action=="charge":
		energy.cancel_charge(source)
		energy.spawn(at-Vector2(0,45),Vector2.ONE*230,Color(col,.55),4,fx.duration,0,0,1.05,source)
	elif action=="release":
		var radius := float(fx.get("radius",150))
		var shape := str(fx.get("shape","circle"))
		match shape:
			"line", "lane":
				energy.spawn(at+aim*radius*.5,Vector2(radius+24,140),col,1,.62,aim.angle(),0,1.05,source)
				energy.particles(at+aim*radius,col,18,aim,35,1.1)
			"cone":
				energy.spawn(at,Vector2.ONE*radius*2,col,3,.65,aim.angle(),0,float(fx.get("arc",1.05)),source)
				var half_angle := float(fx.get("arc",1.05))
				for fraction in [-0.65,0.0,0.65]:
					var ray := aim.rotated(half_angle*fraction)
					energy.particles(at+ray*radius*.68,col,10,ray,28,1.2)
			"ring":
				var inner := float(fx.get("inner",0))
				energy.spawn(at,Vector2.ONE*radius*2,col,2,.9,0,inner/radius,1.05,source)
				for i in 8:
					var ray := Vector2.from_angle(i*TAU/8)
					energy.particles(at+ray*(inner+radius)*.5,col,7,ray,10,.55)
			"gap_ring":
				var inner := float(fx.get("inner",0))
				for i in 9:
					var angle: float=aim.angle()+float(fx.get("gap",0.5))+(TAU-2*float(fx.get("gap",0.5)))*float(i)/8.0
					var ray := Vector2.from_angle(angle)
					energy.particles(at+ray*(inner+radius)*.5,col,8,ray,28,.7)
			"arc":
				var half_angle: float=float(fx.get("arc",1.05))
				for i in 9:
					var ray := aim.rotated(lerpf(-half_angle,half_angle,float(i)/8.0))
					energy.particles(at+ray*(float(fx.get("inner",0))+radius)*.5,col,8,ray,35,.65)
			_:
				energy.spawn(at-Vector2(0,radius*.7),Vector2(radius*2,radius*2.8),Color(col,.9),0,.95,0,0,1.05,source)
				energy.spawn(at,Vector2.ONE*radius*2,col,2,.7,0,0,1.05,source)
				energy.particles(at-Vector2(0,20),col,36,Vector2.UP,160,1.3)
	elif action in ["entrance","phase","fall"]:
		cinematic.play(fx)
		energy.spawn(at-Vector2(0,115),Vector2(440,560),Color(col,.7),0,1.6,0,0,1.05,source)
		energy.spawn(at,Vector2.ONE*640,Color(col,.65),2,1.2,0,0,1.05,source)
		energy.particles(at-Vector2(0,65),col,64,Vector2.UP,140,1.8)
	elif action=="break":
		energy.particles(at-Vector2(0,30),col,40,aim,150,1.0)
