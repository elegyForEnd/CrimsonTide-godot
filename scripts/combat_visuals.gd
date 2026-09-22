class_name CombatVisuals
extends Node2D
## Textured additive effects; no dependency on renderer-specific 2D bloom.
var field: Node2D
var atlas: Texture2D = preload("res://assets/combat/vfx-atlas.png")
var motes: Array = []
var trauma := 0.0
var numbers: Array = []
var elapsed := 0.0

func _ready() -> void:
	var additive := ShaderMaterial.new()
	additive.shader=preload("res://resources/combat_glow.gdshader")
	material=additive
	z_index=1

func reset() -> void:
	motes.clear()
	numbers.clear()
	trauma=0.0

func spawn(cell: int, at: Vector2, size: Vector2, duration: float, angle: float = 0.0, tint: Color = Color.WHITE, delay: float = 0.0, velocity: Vector2 = Vector2.ZERO) -> void:
	if motes.size()>=240:
		motes.pop_front()
	motes.append({"cell":cell,"p":at,"size":size,"duration":duration,"age":-delay,"angle":angle,"tint":tint,"velocity":velocity})

func event(data: Dictionary) -> void:
	var at: Vector2=data.p
	if at.distance_to(field.camera)>1100:
		return
	var aim_dir: Vector2=data.get("aim",Vector2.RIGHT)
	var angle := aim_dir.angle()
	var weapon := int(data.get("weapon",0))
	match data.kind:
		"dodge":
			spawn(7,at,Vector2(85,45),0.25,angle,Color(0.5,0.55,1,0.35))
		"windup":
			if weapon==3:
				spawn(6,at+aim_dir*27-Vector2(0,27),Vector2(62,62),0.26)
			elif weapon==2:
				spawn(5,at-Vector2(0,72),Vector2(44,70),0.30,0,Color(1,0.7,0.35))
		"strike":
			match weapon:
				0: spawn(5,at+aim_dir*34,Vector2(52,42),0.12,angle)
				1:
					var reverse := -1.0 if int(data.get("combo",0))==1 else 1.0
					spawn(0,at+aim_dir*38,Vector2(182,142*reverse),0.25,angle)
					spawn(0,at+aim_dir*42,Vector2(205,156*reverse),0.20,angle+0.18,Color(0.65,0.5,0.7),0.035)
				2:
					spawn(1,at+aim_dir*83-Vector2(0,30),Vector2(190,235),0.48)
					spawn(7,at+aim_dir*75,Vector2(240,110),0.45,angle,Color(1,0.65,0.4),0.04)
					trauma=maxf(trauma,0.36)
				3:
					spawn(3,at,Vector2(110,66),0.45,0,Color(0.6,0.8,1))
					spawn(6,at+aim_dir*40-Vector2(0,12),Vector2(80,80),0.23)
		"impact":
			var heavy: bool=data.get("heavy",false)
			spawn(5,at-Vector2(0,20),Vector2.ONE*(130 if heavy else 82),0.25,angle)
			spawn(4,at-Vector2(0,20),Vector2.ONE*(110 if heavy else 65),0.32,angle,Color(1,0.65,0.7))
			for i in 8 if heavy else 5:
				var ray := aim_dir.rotated(sin(i*17.1)*1.7)
				spawn(5,at-Vector2(0,14),Vector2(18,8),0.25+i*0.02,ray.angle(),Color(1,0.8,0.55),0,ray*(100+i*24))
			trauma=maxf(trauma,0.65 if heavy else 0.24)
			numbers.append({"p":at-Vector2(0,55),"age":0.0,"value":str(roundi(data.damage)),"heavy":heavy})
		"skill":
			var hero := int(data.hero)
			trauma=maxf(trauma,0.5)
			if hero==1:
				spawn(3,at,Vector2(590,350),1.2,0,Color(0.65,0.85,1,0.7))
				spawn(8,at-Vector2(0,105),Vector2(260,400),0.95,0,Color(0.7,0.9,1,0.42),0.1)
				for i in 9:
					spawn(6,at+Vector2.from_angle(i*TAU/9)*110,Vector2(28,55),0.9,0,Color(0.5,1,0.85),i*0.03,Vector2(0,-85))
			elif hero==2:
				spawn(4,at,Vector2(470,420),0.8)
				for i in 3:
					spawn(0,at,Vector2(425,310),0.4,angle+i*TAU/3,Color(0.6,0.55,1),i*0.09)
			else:
				spawn(7,at,Vector2(270,150),0.7)
				for i in 5:
					spawn(0,at+aim_dir*(75+i*70),Vector2(190,210),0.45,angle,Color.WHITE,i*0.055)

func legacy(kind: String, at: Vector2) -> void:
	if at.distance_to(field.camera)>1100:
		return
	match kind:
		"hit": spawn(4,at,Vector2(100,90),0.35,0,Color(1,0.45,0.55))
		"hurt":
			spawn(7,at,Vector2(105,90),0.25)
			trauma=maxf(trauma,0.35)
		"dash": spawn(4,at,Vector2(120,90),0.4,0,Color(0.6,0.65,1))
		"bell": spawn(8,at-Vector2(0,100),Vector2(210,330),1.0)
		"skill": spawn(3,at,Vector2(100,65),0.55,0,Color(0.6,1,0.8,0.5))
		"loot": spawn(5,at,Vector2(55,70),0.4)

func _process(dt: float) -> void:
	if not field.visible:
		return
	elapsed+=dt
	trauma=move_toward(trauma,0,dt*2.6)
	position=field.offset
	for i in range(motes.size()-1,-1,-1):
		motes[i].age+=dt
		if motes[i].age>motes[i].duration:
			motes.remove_at(i)
	for i in range(numbers.size()-1,-1,-1):
		numbers[i].age+=dt
		if numbers[i].age>0.7:
			numbers.remove_at(i)
	queue_redraw()

func stamp(cell: int, at: Vector2, size: Vector2, angle: float, tint: Color) -> void:
	var unit := atlas.get_size()/3.0
	# Inset removes sampling bleed between neighbouring atlas tiles.
	var source := Rect2(Vector2(cell%3,cell/3)*unit+Vector2.ONE*3,unit-Vector2.ONE*6)
	draw_set_transform(at,angle)
	draw_texture_rect_region(atlas,Rect2(-size/2,size),source,tint)

func _draw() -> void:
	for fx in motes:
		if fx.age<0:
			continue
		var t: float=fx.age/fx.duration
		var fade := minf(1,t*18)*pow(1-t,1.3)
		var tint: Color=fx.tint
		tint.a*=fade
		stamp(fx.cell,fx.p+fx.velocity*fx.age,fx.size*lerpf(0.72,1.18,t),fx.angle,tint)
	for bullet in field.session.bullets:
		var magic: bool=bullet.get("weapon",0)==3
		var tint := Color(1,0.45,0.65) if bullet.owner==0 else Color.WHITE
		stamp(2 if magic or bullet.owner==0 else 5,bullet.p-bullet.v.normalized()*13,Vector2(94,44) if magic else Vector2(36,16),bullet.v.angle(),tint)
	draw_set_transform(Vector2.ZERO)
