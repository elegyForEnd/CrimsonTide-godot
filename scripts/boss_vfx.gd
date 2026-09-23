extends Node2D
## Generated texture meshes preserve the authoritative footprint. Airborne effects
## are separate, short-lived layers so they never replace the ground warning.
const Presentation = preload("res://scripts/boss_presentation.gd")
const Tactics = preload("res://scripts/boss_tactics.gd")
const COLORS := [Color("c8a8ff"),Color("f987a4"),Color("ffe5ad"),Color("c4e9ff")]
var field: Node2D
var sheets: Array[Texture2D]=[]
var effects: Array[Dictionary]=[]
var meshes: Dictionary={}
var elapsed := 0.0

func _ready() -> void:
	z_index=2
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	for key in Presentation.KEYS:
		sheets.append(load("res://assets/bosses/vfx/"+key+".png"))

func reset() -> void:
	effects.clear()
	queue_redraw()

func _exit_tree() -> void:
	effects.clear()
	meshes.clear()
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
	if data.action in ["release","break","entrance","phase","fall"]:
		var strength := 0.26 if data.get("shape","")=="line" else 0.42
		if data.action in ["phase","fall"]: strength=0.62
		var proximity := clampf(1-data.p.distance_to(field.camera)/1000.0,0,1)
		field.combat.trauma=maxf(field.combat.trauma,strength*proximity)

func _process(dt: float) -> void:
	if not field.visible: return
	elapsed+=dt
	position=field.offset
	for i in range(effects.size()-1,-1,-1):
		effects[i].age+=dt
		if effects[i].action=="charge":
			var active := false
			for e in field.session.enemies:
				if e.id==effects[i].id and e.hp>0 and float(e.get("attack_time",0))>0: active=true
			if not active:
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
	target.draw_texture_rect_region(sheets[kind],Rect2(-size/2,size),region(kind,cell),Color(brightness,brightness,brightness,opacity))
	target.draw_set_transform(origin)

func mesh(shape: String, radius: float, inner: float, cell: int, arc: float = 1.05) -> ArrayMesh:
	var key := "%s:%.2f:%.2f:%d:%.2f" % [shape,radius,inner,cell,arc]
	if meshes.has(key): return meshes[key]
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var tile := Vector2(cell%4,cell/4)
	if shape=="line":
		points=PackedVector2Array([Vector2(-22,-44),Vector2(radius,-44),Vector2(radius,44),Vector2(-22,44)])
		for uv in [Vector2(.015,.26),Vector2(.985,.26),Vector2(.985,.74),Vector2(.015,.74)]: uvs.append((tile+uv)/4.0)
		indices=PackedInt32Array([0,1,2,0,2,3])
	else:
		var opening: float=arc if shape=="cone" else PI
		for i in 65:
			var angle := lerpf(-opening,opening,float(i)/64)
			var ray := Vector2.from_angle(angle)
			points.append(ray*inner)
			points.append(ray*radius)
			# The painted ring's empty core maps to the real safe inner radius.
			var uv_inner := 0.19 if inner>0 else 0.0
			uvs.append((tile+Vector2(.5,.5)+ray*uv_inner)/4.0)
			uvs.append((tile+Vector2(.5,.5)+ray*.485)/4.0)
			if i<64:
				var n := i*2
				indices.append_array(PackedInt32Array([n,n+1,n+3,n,n+3,n+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	meshes[key]=result
	return result

func hazard(target: CanvasItem, h: Dictionary, kind: int = -1) -> void:
	kind=int(h.get("boss_kind",0)) if kind<0 else kind
	if h.p.distance_to(field.camera)>1400: return
	var progress := 1.0-clampf(float(h.time)/maxf(.01,float(h.total)),0,1)
	var fired: bool=h.get("fired",false)
	var shape: String=h.shape
	var cell := 8 if shape=="line" else 0 if float(h.get("inner",0))>0 else 4
	if fired: cell=9 if shape=="line" else 1 if float(h.get("inner",0))>0 else 7
	var alpha := .40+progress*.44
	if fired: alpha=.85*clampf(1+float(h.time)/.30,0,1)
	var brightness := 1.15+progress*.65
	var direction: Vector2=h.aim
	var rotation := direction.angle() if shape in ["line","cone"] else 0.0
	var transform := Transform2D(rotation,h.p)
	target.draw_mesh(mesh(shape,float(h.radius),float(h.get("inner",0)),cell,float(h.get("arc",1.05))),sheets[kind],transform,Color(brightness,brightness,brightness,alpha))
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
				if shape=="line":
					stamp(self,kind,9 if t<.34 else 10,at+aim*(radius*.5),Vector2(radius+30,190),aim.angle(),fade*.88,1.4)
				elif shape=="cone":
					var sweep := lerpf(-.3,.35,minf(1,t*3))
					stamp(self,kind,11,at+aim*radius*.45,Vector2.ONE*radius*1.55,aim.angle()+sweep+(PI if kind==3 else 0),fade*.9,1.35)
				elif shape=="ring":
					# Ring burst remains on its annulus. Never flash the safe center.
					var h := fx.duplicate()
					h["time"]=-t*.24
					h["total"]=1.0
					h["fired"]=true
					hazard(self,h,kind)
				else:
					stamp(self,kind,5 if t<.55 else 6,at-Vector2(0,radius*.45),Vector2(radius*2.1,radius*2.5)*(1+t*.15),0,fade*.9,1.25)
				if int(fx.get("part",0))==0:
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
		if fx.action in ["release","phase","fall"] and (int(fx.get("part",0))==0 or fx.get("shape","")=="circle"):
			for i in 4:
				var ray := Vector2.from_angle(float(i)*TAU/4+float(fx.id))
				stamp(self,kind,15,at+ray*(35+t*100)-Vector2(0,30+t*45),Vector2.ONE*(28+t*18),ray.angle(),fade*.7)
