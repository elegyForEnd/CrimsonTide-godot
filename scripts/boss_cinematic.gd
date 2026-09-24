extends Node2D
## Ultimate-inspired side cut-in; never pauses or covers the central dodge lane.
var field: Node2D
var active := false
var age := 0.0
var kind := 0
var action := "entrance"
var phase := 1
var mini_kind := -1
var final_form := false
var wild_kind := -1
var dragon_boss := false
var duration := 1.8
var light: Node2D
var atlas: Texture2D=preload("res://assets/combat/vfx-atlas.png")
var face: Font=preload("res://assets/NotoSerifSC.ttf")
const COLORS := [Color("c8a8ff"),Color("ff7799"),Color("ffcf88"),Color("b9e1ff")]
const TITLES := ["葬钟圣座", "荆棘王誓", "永夜月冠", "失乡之誓"]
const SPECIAL_ART := Battlefield.SPECIAL_BOSS_ART

func _ready() -> void:
	light=Node2D.new()
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://resources/combat_glow.gdshader")
	light.material=mat
	add_child(light)
	light.draw.connect(draw_light)

func play(data: Dictionary) -> void:
	kind=int(data.boss_kind)
	action=str(data.action)
	phase=int(data.get("phase",1))
	mini_kind=int(data.get("mini_kind",-1))
	final_form=bool(data.get("final_form",false))
	wild_kind=int(data.get("wild_kind",-1)) if data.get("wild_boss",false) else -1
	dragon_boss=bool(data.get("dragon_boss",false))
	age=0
	duration=2.1 if action=="fall" else 1.8
	active=true

func reset() -> void:
	active=false
	queue_redraw()
	if light: light.queue_redraw()

func _process(dt: float) -> void:
	visible=active and field.is_visible_in_tree() and not field.map_open
	if not active: return
	if active:
		age+=dt
		if age>=duration: active=false
	queue_redraw()
	light.queue_redraw()

func envelope() -> float:
	return smoothstep(0,.12,age)*(1-smoothstep(duration-.45,duration,age))

func _draw() -> void:
	if not active: return
	var size := get_viewport_rect().size
	var alpha := envelope()
	var color: Color=Color("9ce9ff") if dragon_boss else [Color("d9aa68"),Color("87dfff"),Color("b86bff")][clampi(wild_kind,0,2)] if wild_kind>=0 else Color("ff4a70") if final_form else (Color("a8dbff") if mini_kind==0 else Color("ff8d66") if mini_kind==1 else COLORS[kind])
	var unit := minf(size.x/1440,size.y/900)
	# Portrait stays left of the combat centre. Draw at its native aspect ratio.
	var at := Vector2(-35*(1-alpha),size.y-500*unit)
	for i in 18:
		draw_rect(Rect2(i*21*unit,at.y-10*unit,22*unit,380*unit),Color(.015,.007,.025,alpha*.72*(1-i/18.0)))
	if kind<3 or mini_kind>=0 or final_form or wild_kind>=0 or dragon_boss:
		var tex: Texture2D=SPECIAL_ART[6] if dragon_boss else SPECIAL_ART[3+wild_kind] if wild_kind>=0 else SPECIAL_ART[2] if final_form else SPECIAL_ART[mini_kind] if mini_kind>=0 else field.boss_frames.portraits[kind]
		var extent := tex.get_size()*(360*unit/tex.get_height())
		draw_texture_rect(tex,Rect2(at+Vector2(0,-14*unit)*smoothstep(0,1.8,age),extent),false,Color(1,1,1,alpha))
	var title_at := at+Vector2(22,316)*unit
	draw_rect(Rect2(title_at-Vector2(12,37)*unit,Vector2(280,81)*unit),Color(.015,.007,.025,alpha*.78))
	var title: String="霜骨古龙" if dragon_boss else ["裂地钻兽","雷骸巨鸟","吞月渊蛇"][clampi(wild_kind,0,2)] if wild_kind>=0 else "无名赤月" if final_form else "镜墓纺女" if mini_kind==0 else "余烬司祭" if mini_kind==1 else TITLES[kind]
	draw_string(face,title_at+Vector2(2,3),title,HORIZONTAL_ALIGNMENT_LEFT,-1,int(36*unit),Color(0,0,0,alpha))
	draw_string(face,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,int(36*unit),Color(1,.94,.86,alpha))
	var subtitle := "降临 · 黎明将尽" if action=="entrance" else "终幕 · 王誓崩解" if action=="fall" else "第 %d 阶段 · 力量解放" % phase
	draw_string(face,title_at+Vector2(0,30*unit),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,int(17*unit),Color(color,alpha))
	# Cinematic bars are confined to the edges, with a short apex flash.
	draw_rect(Rect2(0,0,size.x,18*unit*alpha),Color(.005,.003,.012,alpha*.8))
	draw_rect(Rect2(0,size.y-18*unit*alpha,size.x,18*unit*alpha),Color(.005,.003,.012,alpha*.8))

func stamp(cell: int, at: Vector2, diameter: float, angle: float, color: Color) -> void:
	var unit := atlas.get_size()/3.0
	light.draw_set_transform(at,angle)
	light.draw_texture_rect_region(atlas,Rect2(Vector2.ONE*-diameter*.5,Vector2.ONE*diameter),Rect2(Vector2(cell%3,cell/3)*unit+Vector2.ONE*4,unit-Vector2.ONE*8),color)
	light.draw_set_transform(Vector2.ZERO)

func draw_light() -> void:
	if not active: return
	var size := get_viewport_rect().size
	var alpha := envelope()
	var unit := minf(size.x/1440,size.y/900)
	var color := Color(COLORS[kind],alpha*.35)
	var at := Vector2(140*unit,size.y-320*unit)
	stamp(3,at,330*unit,age*.18,color)
	for i in 24:
		var t := fposmod(i*.618+age*.28,1)
		stamp(5,at+Vector2(sin(i*13.7)*130,150-t*390)*unit,(9+i%4*4)*unit,-.6,Color(color,alpha*sin(t*PI)*.7))
	var impact := exp(-absf(age-.32)*24)
	stamp(4,at,410*unit,age*.2,Color(color,impact*.7))
