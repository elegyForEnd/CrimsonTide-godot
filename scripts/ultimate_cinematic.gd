class_name UltimateCinematic
extends Control
## Independent viewport layer: never inherits the HUD's fixed-size letterboxing.
signal burst
const LENGTH := 2.6
var age := 0.0
var duration := LENGTH
var hero := 0
var active := false
var owns_pause := false
var fired := false
var art: Array[AtlasTexture] = []
var face: Font = preload("res://assets/NotoSerifSC.ttf")
var fx: Texture2D = preload("res://assets/combat/vfx-atlas.png")
var light: Node2D

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents=true
	var sheet: Texture2D=load("res://assets/combat/ultimate-cg.png")
	var row := sheet.get_height()/3.0
	for i in 3:
		var frame := AtlasTexture.new()
		frame.atlas=sheet
		frame.region=Rect2(0,i*row+2,sheet.get_width(),row-4)
		frame.filter_clip=true
		art.append(frame)
	light=Node2D.new()
	var additive := ShaderMaterial.new()
	additive.shader=preload("res://resources/combat_glow.gdshader")
	light.material=additive
	light.draw.connect(draw_light)
	add_child(light)
	visible=false

func play(character: int, online: bool) -> void:
	if active:
		return
	hero=clampi(character,0,2)
	duration=0.85 if online else LENGTH
	age=0.0
	fired=false
	active=true
	visible=true
	owns_pause=not online and not get_tree().paused
	if owns_pause:
		get_tree().paused=true
	queue_redraw()
	light.queue_redraw()

func stop() -> void:
	active=false
	visible=false
	if owns_pause:
		get_tree().paused=false
	owns_pause=false

func _exit_tree() -> void:
	if owns_pause:
		get_tree().paused=false

func _input(event: InputEvent) -> void:
	if not active:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		stop()
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not active:
		return
	age+=dt
	if age/duration>=0.72 and not fired:
		fired=true
		burst.emit()
	if age>=duration:
		stop()
	queue_redraw()
	light.queue_redraw()

func _draw() -> void:
	if not active:
		return
	var t := age/duration
	var fade := 1.0-smoothstep(0.86,1.0,t)
	var tint := Catalog.HEROES[hero].color as Color
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.008,0.004,0.02,fade))
	var tex := art[hero]
	var base := maxf(size.x/tex.get_width(),size.y/tex.get_height())
	var zoom := 1.12-0.10*smoothstep(0,0.72,t)+0.06*smoothstep(0.72,1,t)
	var extent := tex.get_size()*base*zoom
	var shake := Vector2(sin(age*82),cos(age*67))*8*exp(-absf(t-0.73)*45)
	var origin := (size-extent)*0.5+Vector2(42*(1-smoothstep(0,0.18,t)),0)+shake
	draw_texture_rect(tex,Rect2(origin,extent),false,Color(1,1,1,fade))
	# Iris-like opening and cinematic bars frame the portrait without cropping atlas rows.
	var bars := size.y*lerpf(0.48,0.055,smoothstep(0,0.13,t))
	draw_rect(Rect2(0,0,size.x,bars),Color(0.008,0.004,0.015,fade))
	draw_rect(Rect2(0,size.y-bars,size.x,bars),Color(0.008,0.004,0.015,fade))
	var reveal := smoothstep(0.10,0.26,t)*fade
	var unit := minf(size.x/1440,size.y/900)
	var at := Vector2(size.x*0.065-35*(1-reveal),size.y*0.77)
	var title := str(Catalog.HEROES[hero].skill)
	draw_string(face,at+Vector2(3,4),title,HORIZONTAL_ALIGNMENT_LEFT,-1,int(66*unit),Color(0.02,0,0.03,reveal))
	draw_string(face,at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,int(66*unit),Color(1,0.96,0.91,reveal))
	draw_string(face,at-Vector2(0,70*unit),str(Catalog.HEROES[hero].name)+"  /  奥义解放",HORIZONTAL_ALIGNMENT_LEFT,-1,int(22*unit),Color(tint, reveal))
	draw_string(face,Vector2(size.x-240*unit,size.y-22*unit),"任意键 / 点击跳过",HORIZONTAL_ALIGNMENT_LEFT,-1,int(16*unit),Color(0.9,0.9,1,fade*0.75))
	var flash := 0.48*exp(-absf(t-0.035)*100)+0.65*exp(-absf(t-0.74)*95)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.85,0.92,1,flash*fade))

func stamp(cell: int, at: Vector2, extent: Vector2, angle: float, tint: Color) -> void:
	var unit := fx.get_size()/3.0
	light.draw_set_transform(at,angle)
	light.draw_texture_rect_region(fx,Rect2(-extent/2,extent),Rect2(Vector2(cell%3,cell/3)*unit+Vector2.ONE*4,unit-Vector2.ONE*8),tint)
	light.draw_set_transform(Vector2.ZERO)

func draw_light() -> void:
	if not active:
		return
	var t := age/duration
	var envelope := smoothstep(0,0.12,t)*(1-smoothstep(0.8,1,t))
	var color: Color=Catalog.HEROES[hero].color
	var unit := size.x/1440
	# Textured moving layers add depth beyond the painted CG: rotating sigil,
	# expanding shockwave, sweeping flares, drifting embers and an impact bloom.
	stamp(3,size*Vector2(0.72,0.48),Vector2.ONE*size.y*0.95,age*0.12,Color(color,0.16*envelope))
	stamp(7,size*0.5,Vector2(size.x*1.8,size.y*1.3)*lerpf(0.3,1.5,t),-0.2,Color(color,0.3*envelope))
	for i in 42:
		var phase := fposmod(i*0.618+age*(0.09+0.015*(i%5)),1.0)
		var at := Vector2(fposmod(i*197.3+age*40,size.x),size.y*(1-phase))
		stamp(5,at,Vector2(16+float(i%4)*7,9)*unit,-0.6,Color(color,envelope*sin(phase*PI)*0.7))
	for i in 3:
		stamp(2,Vector2(size.x*(t*1.6-0.3),size.y*(0.25+i*0.26)),Vector2(size.x*0.85,36*unit),-0.22,Color(color,0.35*envelope))
	var impact := exp(-absf(t-0.74)*28)
	stamp(4,size*Vector2(0.66,0.46),Vector2.ONE*size.y*(0.9+t),age*0.2,Color(color,impact*0.8))
